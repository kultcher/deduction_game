using System;
using System.Collections.Generic;
using System.Numerics;
using System.Runtime.CompilerServices;
using System.Runtime.InteropServices;

namespace Demonologist.Workshop;

/// <summary>
/// Slice C2 1:1 port of workshop/live_activity.gd.
/// Covers:
///   - Night route bitmask enumeration, Lamplighter counts (routes / _paths)
///   - Persistent night-walk / habitual evening block likelihoods (_likelihood / _profile_paths / _observed)
///   - Scene crossing probabilities (crossing_probability)
///   - Three-valued structured trace evaluation (evaluate_trace_for_person: locations, quarter, connection)
///   - Joint movement & two-trace passer likelihood contractions + Scion succession splits (score)
/// Preserves exact IEEE-754 double summation and multiplication order (--tol 0).
/// </summary>
internal static class LiveActivityKernel
{
    // GDScript parses the literal 1e-30 one ULP low (0x39B4484BFEEBC29F; IEEE nearest is
    // ...C2A0). GDScript is the oracle, so the floor uses Godot's bits, not C#'s 1e-30.
    // 1e-12 and 1e-20 parse identically in both and need no such constant.
    private static readonly double GdFloor1e30 = BitConverter.Int64BitsToDouble(0x39B4484BFEEBC29FL);

    // Canonical block order matching C.BLOCKS = {"square", "market", "docks", "hill"}:
    public const int BlockSquare = 0;
    public const int BlockMarket = 1;
    public const int BlockDocks = 2;
    public const int BlockHill = 3;
    public const int BlockCount = 4;

    // LiveCard packed int stride (20 int32s per card; 2 doubles per card in cardDoubles):
    public const int CardStride = 20;

    // Card kind codes (slot 0):
    public const int KindOther = 0;
    public const int KindSighting = 1;
    public const int KindEvening = 2;
    public const int KindTrace = 3;
    public const int KindCoverage = 4;

    // Tuning values from sim/tuning.gd, injected at bridge init via SolverBridge.ConfigureTuning().
    // Initialized to NaN so any unconfigured access fails loudly in debug and release builds.
    private static double _vigilMiss = double.NaN;
    private static double _walkerClaimGift = double.NaN;
    private static double _walkerClaimHome = double.NaN;
    private static double _walkerClaimSecret = double.NaN;

    private static double RequireTuning(double value, string name)
    {
        if (double.IsNaN(value))
            throw new InvalidOperationException(
                $"LiveActivityKernel.{name} was read before SolverBridge.ConfigureTuning() initialized it from sim/tuning.gd.");
        return value;
    }

    public static double VigilMiss => RequireTuning(_vigilMiss, nameof(VigilMiss));
    public static double WalkerClaimGift => RequireTuning(_walkerClaimGift, nameof(WalkerClaimGift));
    public static double WalkerClaimHome => RequireTuning(_walkerClaimHome, nameof(WalkerClaimHome));
    public static double WalkerClaimSecret => RequireTuning(_walkerClaimSecret, nameof(WalkerClaimSecret));

    public static bool IsTuningConfigured =>
        !double.IsNaN(_vigilMiss) && !double.IsNaN(_walkerClaimGift)
        && !double.IsNaN(_walkerClaimHome) && !double.IsNaN(_walkerClaimSecret);

    public static void ConfigureTuning(double vigilMiss, double walkerClaimGift, double walkerClaimHome, double walkerClaimSecret)
    {
        if (double.IsNaN(vigilMiss) || double.IsInfinity(vigilMiss))
            throw new ArgumentOutOfRangeException(nameof(vigilMiss), "VigilMiss must be finite.");
        if (double.IsNaN(walkerClaimGift) || double.IsInfinity(walkerClaimGift))
            throw new ArgumentOutOfRangeException(nameof(walkerClaimGift), "WalkerClaimGift must be finite.");
        if (double.IsNaN(walkerClaimHome) || double.IsInfinity(walkerClaimHome))
            throw new ArgumentOutOfRangeException(nameof(walkerClaimHome), "WalkerClaimHome must be finite.");
        if (double.IsNaN(walkerClaimSecret) || double.IsInfinity(walkerClaimSecret))
            throw new ArgumentOutOfRangeException(nameof(walkerClaimSecret), "WalkerClaimSecret must be finite.");
        _vigilMiss = vigilMiss;
        _walkerClaimGift = walkerClaimGift;
        _walkerClaimHome = walkerClaimHome;
        _walkerClaimSecret = walkerClaimSecret;
    }

    internal static void ClearTuningForTest()
    {
        _vigilMiss = double.NaN;
        _walkerClaimGift = double.NaN;
        _walkerClaimHome = double.NaN;
        _walkerClaimSecret = double.NaN;
    }
    public const int KindAlibi = 5;
    // 6 was KindDropped (drops removed, Nov 19).
    public const int KindReport = 7;
    public const int KindClaim = 8;
    public const int KindSecretClaim = 9;

    // Card flag bits (slot 1):
    public const int FlagQuoted = 1 << 0;
    public const int FlagTestimonyOnly = 1 << 1;
    public const int FlagHasRelaySource = 1 << 2;
    public const int FlagHasHearingWeight = 1 << 3;
    public const int FlagComplete = 1 << 4;
    public const int FlagHasGuardClaim = 1 << 5;
    public const int FlagDutyOnly = 1 << 6;
    // 1 << 7 was FlagItemDrop (drops removed, Nov 19).
    public const int FlagTraceHasFamily = 1 << 8;
    public const int FlagRoleIsNightWalk = 1 << 9;
    /// The listener's own knowledge of a night it spent at home (WorkshopBridge, the listener's
    /// view): out has likelihood 1 - cardDoubles[c * 2] (packed as 1 - its self-doubt).
    public const int FlagKnownSelf = 1 << 10;
    /// A person's own "I was out" (LiveAssessment.activity_card): only their word, so it binds
    /// only where they're good, and it's no hard route constraint.
    public const int FlagAdmitted = 1 << 11;
    /// A sighting that places its teller (LiveActivity.teller_place; Michael, Nov 20): where the
    /// teller is good, a street sighting puts them out on that block that night, and one from
    /// their window (FlagTellerAtHome: their own block) at home or out on their own block.
    /// Heard at cardDoubles[c * 2]: a path that doesn't fit has likelihood 1 - that.
    public const int FlagTellerAt = 1 << 12;
    public const int FlagTellerAtHome = 1 << 13;
    /// The sighting was told while the Revenant's curse could have converted its teller (its
    /// statement time inside the curse window): in a world where the teller is the converted
    /// person, it is an evil teller's word, whatever night it is about (Codex on #474).
    public const int FlagTellerToldCursed = 1 << 14;
    /// A burden claim that explains its claimant's night walks (burdens prototype: Unrequited).
    public const int FlagClaimWalks = 1 << 15;
    /// The listener's own night out (live_activity_profiles.gd own_home_cards): the blocks it
    /// walked, as a mask in slot 17 (reading-note gap 2).
    public const int FlagKnownRoute = 1 << 16;

    /// The generic secret errand (every good person ~10% likely to walk on an errand): retired
    /// with the flavour secrets (Michael, Nov 21); the switch is for measuring it.
    public static bool SecretErrand = false;

    // Movement role codes (slot 7):
    public const int MoveRoleEmpty = 0;
    public const int MoveRoleNightwatch = 1;
    public const int MoveRoleWarden = 2;
    public const int MoveRoleLamplighter = 3;
    public const int MoveRoleVeteran = 4;
    public const int MoveRoleMedium = 5;
    public const int MoveRoleOther = 6;
    public const int MoveRoleMonitor = 7;
    /// The Sexton: it walks every block on the night it tolls (Michael, Nov 21), told by its
    /// own toll report, whose night is in slot 17.
    public const int MoveRoleSexton = 8;

    // Profile kind codes:
    private const int ProfOrdinary = 0;
    private const int ProfGift = 1;
    private const int ProfSecret = 2;
    private const int ProfMinion = 3;
    private const int ProfDemon = 4;

    // Alignment codes:
    public const int AlignGood = 0;
    public const int AlignMinion = 1;
    public const int AlignDemon = 2;
    public const int AlignConverted = 3;

    /// <summary>
    /// Compact representation of a night path on the 4-block pairwise-connected map.
    /// StayHome: BlockMask = 0, FirstBlock = LastBlock = -1, IsLampTour = false.
    /// Direct / Detour: BlockMask != 0, FirstBlock = home, LastBlock = destination (0..3), IsLampTour = false.
    /// LampTour (C.BLOCKS.keys()): BlockMask = 0xF, FirstBlock = the walker's home (where they
    /// leave their house; the tour itself runs in block order), LastBlock = 3 ("hill"), IsLampTour = true.
    /// </summary>
    internal readonly struct PathSpec
    {
        public readonly int BlockMask;
        public readonly int FirstBlock;
        public readonly int LastBlock;
        public readonly bool IsLampTour;
        public readonly double Weight;

        [MethodImpl(MethodImplOptions.AggressiveInlining)]
        public PathSpec(int blockMask, int firstBlock, int lastBlock, bool isLampTour, double weight = 1.0)
        {
            BlockMask = blockMask;
            FirstBlock = firstBlock;
            LastBlock = lastBlock;
            IsLampTour = isLampTour;
            Weight = weight;
        }

        public bool Out
        {
            [MethodImpl(MethodImplOptions.AggressiveInlining)]
            get => LastBlock >= 0;
        }

        [MethodImpl(MethodImplOptions.AggressiveInlining)]
        public bool HasBlock(int blockCode) =>
            blockCode >= 0 && blockCode < BlockCount && (BlockMask & (1 << blockCode)) != 0;

        /// <summary>
        /// Matches C.vigil_sees_path(block, path, home): a vigil sees only people leaving home
        /// on its block (Nov 17), the Lamplighter's and Sexton's tours included (Nov 19).
        /// FirstBlock is the walker's home for every path that leaves it.
        /// </summary>
        [MethodImpl(MethodImplOptions.AggressiveInlining)]
        public bool VigilSees(int blockCode) =>
            LastBlock >= 0 && blockCode >= 0 && FirstBlock == blockCode;

        public static PathSpec StayHome(double weight = 1.0) => new(0, -1, -1, false, weight);

        public static PathSpec LampTour(int home, double weight = 1.0) => new(0xF, home, BlockHill, true, weight);

        [MethodImpl(MethodImplOptions.AggressiveInlining)]
        public static PathSpec Route(int home, int dest, double weight = 1.0) =>
            new((1 << home) | (1 << dest), home, dest, false, weight);
    }

    internal sealed class SceneTableData
    {
        public int VictimIdx;
        public int SceneTraceCount;
        public bool TwoCited;
        public double[] W1 = Array.Empty<double>();
        public double[] W2 = Array.Empty<double>();
        public double[] CrossGood = Array.Empty<double>();
        public double[] CrossMinion = Array.Empty<double>();
        public double[] CrossConverted = Array.Empty<double>();
    }

    internal sealed class ScionSplitData
    {
        public int ExecutedIdx;
        public int AliveDemonMask;
        /// <summary>The quiet-night guards for each side of the succession (AttachGuards), or null.</summary>
        public GuardSet PreGuards;
        public GuardSet PostGuards;
        public double[] PreGood = Array.Empty<double>();
        public double[] PreMinion = Array.Empty<double>();
        public double[] PreDemon = Array.Empty<double>();
        public double[] PostGood = Array.Empty<double>();
        public double[] PostMinion = Array.Empty<double>();
        public double[] PostDemon = Array.Empty<double>();
        public SceneTableData[] PreScenes = Array.Empty<SceneTableData>();
        public SceneTableData[] PostScenes = Array.Empty<SceneTableData>();
        /// <summary>The divisors for PreGood and PostGood in BaseScore, or null for those (a
        /// Night Watch list's broken branch takes its sound branch's; SetListNorm).</summary>
        public double[] NormPreGood;
        public double[] NormPostGood;
    }

    internal sealed class CompiledMovementFactor
    {
        public int PeopleCount;
        public bool HasConvertedProfiles;
        public double TracePasserEps;
        public double TraceUnknownWeight;
        public double[] ProfGood = Array.Empty<double>();
        public double[] ProfMinion = Array.Empty<double>();
        public double[] ProfDemon = Array.Empty<double>();
        public double[] ProfConverted = Array.Empty<double>();
        /// <summary>A good person's profile in worlds where they hold Unrequited (burdens
        /// prototype; ComputeUnrequitedProfiles). Empty when the script doesn't deal it.</summary>
        public double[] ProfUnrequited = Array.Empty<double>();
        public SceneTableData[] SceneTables = Array.Empty<SceneTableData>();
        public ScionSplitData[] ScionSplits = Array.Empty<ScionSplitData>();
        /// <summary>Share of the script's possible demons that never walk at night (0 = walking only).
        /// Above 0, every profile is the walking one and ScoreWorldCore mixes whole-world scores:
        /// (1-s)*walk + s*day*HexFactor, a day demon moving like a minion.</summary>
        public double DayDemonShare;
        /// <summary>The Hexer's kills (docs/demon_types_plan.md, step 3): for each demon kill or
        /// attack, the victim's regular places with each person's chance of having hexed them
        /// that day. Empty unless DayDemonShare &gt; 0. See HexFactor.</summary>
        public HexKill[] HexKills = Array.Empty<HexKill>();
        public double HexFloor;
        /// <summary>Executions that could be a Scion succession: in such a world the kills
        /// before ExecDay are scored against the executed demon (see ScoreDayType).</summary>
        public HexSuccession[] HexSuccessions = Array.Empty<HexSuccession>();
        /// <summary>Sightings that could be invented (AttachContests): per person, null or the
        /// sighters whose word about them is weighed by their alignment in each world.</summary>
        public SightingContest[] Contests = Array.Empty<SightingContest>();
        public double ContestTruth;
        /// <summary>Warden guards on quiet nights (AttachGuards), or null.</summary>
        public GuardSet Guards;
        /// <summary>A Night Watch list that is sound or broken as a whole (AttachListMix;
        /// BACKLOG "A Night Watch list that wrongly names the listener", Michael, Nov 18).
        /// -1 for none. Otherwise, in a world where the watcher is good, the list is sound with
        /// chance 1 - ListMixBroken (scored as ListMixNext, every name at its small error) or
        /// broken (ListMixAlt, the same evidence without the list: it says nothing about who
        /// walked). In a world where the watcher is evil, ListMixNext, whose sighting contest
        /// already lets an evil teller say anything. The factor's own profiles go unused.</summary>
        public int ListMixWatcher = -1;
        public double ListMixBroken;
        public CompiledMovementFactor ListMixNext;
        public CompiledMovementFactor ListMixAlt;
        /// <summary>The chance a broken list says these words, as often as an honest one would,
        /// from what an outsider could know (the contests' balance), computed in
        /// LiveActivity._list_mix. The branches already score on one scale (NormGood).</summary>
        public double ListMixAltScale = 1.0;
        /// <summary>The divisor for ProfGood in BaseScore, or null for ProfGood. A broken branch
        /// (and every factor under it) divides by its sound branch's good profiles, so the two
        /// branches score on one scale in every component (Codex on #273).</summary>
        public double[] NormGood;
        /// <summary>The list was told while the curse could have converted its watcher
        /// (LiveActivity._told_cursed): in a world where the watcher is the converted person, it
        /// takes the evil-teller path, as the sighting contest does (Codex on #273).</summary>
        public bool ListMixToldCursed;
        /// <summary>A Lamplighter's count mixed the same way (Michael, Nov 19, the Lamplighter fix
        /// (b), step 1): unlike a list, a count has no sighting contest, so in a world where its
        /// teller is evil (or the converted person, told while cursed) it takes the broken branch
        /// outright: an evil Lamplighter can give any number. False for a Night Watch list, whose
        /// path is unchanged.</summary>
        public bool ListMixEvilTakesAlt;
        /// <summary>The sound branch is impossible: the count fits no route mask of the other
        /// movement evidence (LiveActivity._list_mix). It scores 0, so a good teller's world keeps
        /// only the broken branch, weighed by its chance, and the count tells against the
        /// teller by fit, as a contradicted list does. False for a Night Watch list.</summary>
        public bool ListMixSoundZero;
        /// <summary>The hanged Ill-Omened claimants whose omen window covers this list or count
        /// (card.omen_claimants, LiveAssessment.omen_windows). In a world where one of them truly
        /// holds Ill-Omened, every good reader's gift was poisoned that night, so a good teller's
        /// list or count takes the broken branch outright (Codex on #547). 0 for none.</summary>
        public int ListMixOmenMask;
    }

    /// <summary>A Warden's guard of a door on a night the Demon killed nobody. In a world where
    /// the Warden and the guarded person are both good, the guard held with chance R: the
    /// Demon's walk that night ended at that door. The Demon's profile mixes over which of
    /// those guards held: AltDemon[T - 1] is its profile with an attack at the door of each
    /// guard in the non-empty subset T.</summary>
    internal sealed class GuardSet
    {
        public int[] Sources = Array.Empty<int>();
        public int[] Targets = Array.Empty<int>();
        public int[] Nights = Array.Empty<int>();
        public double[] R = Array.Empty<double>();
        /// <summary>The curse window: a converted person is evil only on nights inside it.</summary>
        public bool HasCurse;
        public int CurseFrom;
        public int CurseUntil;
        public double[][] AltDemon = Array.Empty<double[]>();
    }

    /// <summary>A person's evidence with some sighters' sightings of them removed. In a world
    /// where any of those sighters is evil, their sightings may be invented: the person's
    /// profile is Truth * the usual profile + (1 - Truth) * C * the profile without them.
    /// C is the honest sightings' prior-weighted mean likelihood ratio, so an invented
    /// sighting is as likely as an honest one on average and the priors decide.</summary>
    internal sealed class SightingContest
    {
        public int[] Sighters = Array.Empty<int>();
        /// <summary>Per non-empty subset m of Sighters (index m - 1): good, minion, demon, converted.</summary>
        public double[][] Alt = Array.Empty<double[]>();
        public double[] C = Array.Empty<double>();
        /// <summary>Per sighter j: null, or (when j told some of these sightings while
        /// converted by the curse) per subset m containing j, indexed m - 1, the profile with
        /// the other sighters' sightings removed and only j's cursed ones. Used in a world
        /// where j is the converted person and not originally evil.</summary>
        public double[][][] ConvAlt = Array.Empty<double[][]>();
        public double[][] ConvC = Array.Empty<double[]>();
        /// <summary>With quiet-night guards (AttachGuards): per subset m (index m - 1), the
        /// demon profile without those sightings for each guard subset T (index T - 1); and
        /// the same per converted sighter j. Null without guards.</summary>
        public double[][] GuardAlt;
        public double[][][] ConvGuardAlt;
    }

    internal sealed class HexSuccession
    {
        public int ExecutedIdx;
        public int ExecDay;
        public int AliveDemonMask;
    }

    internal sealed class HexKill
    {
        public int AliveMask;        // living at that night
        public int Night;            // the night of the kill
        public int[] RegMasks = Array.Empty<int>();       // per place: its regulars (known work and haunts)
        public double[][] Shares = Array.Empty<double[]>(); // per place: P(person i hexed it that day)
    }

    [MethodImpl(MethodImplOptions.AggressiveInlining)]
    private static bool IsRelevantCard(int kind, int moveRoleCode) =>
        kind == KindSighting
        || kind == KindEvening
        || kind == KindTrace
        || kind == KindCoverage
        || kind == KindAlibi
        || (kind == KindReport && ((moveRoleCode >= MoveRoleNightwatch && moveRoleCode <= MoveRoleMedium) || moveRoleCode == MoveRoleMonitor));

    /// <summary>
    /// 1:1 port of LiveActivity.role_of(cards, person, knowledge).
    /// Returns (moveRoleCode, roleToken, isNightWalk).
    /// </summary>
    private static (int MoveRoleCode, int RoleToken, bool IsNightWalk) RoleOf(
        int personIdx,
        int selfIdx,
        int ownMoveRoleCode,
        int ownRoleToken,
        bool ownRoleNightWalk,
        int[] cardInts,
        int cardCount)
    {
        if (selfIdx >= 0 && personIdx == selfIdx)
        {
            return (ownMoveRoleCode, ownRoleToken, ownRoleNightWalk);
        }
        for (int c = 0; c < cardCount; c++)
        {
            int off = c * CardStride;
            int flags = cardInts[off + 1];
            if ((flags & FlagHasRelaySource) != 0 && (flags & FlagQuoted) == 0 && cardInts[off + 12] == personIdx)
            {
                // "medium": MoveRoleMedium, fixed token 5, night_walk = true
                return (MoveRoleMedium, -5, true);
            }
            int kind = cardInts[off];
            if ((flags & FlagQuoted) == 0 && (flags & FlagTestimonyOnly) == 0
                && cardInts[off + 2] == personIdx
                && (kind == KindClaim || kind == KindReport))
            {
                return (cardInts[off + 7], cardInts[off + 8], (flags & FlagRoleIsNightWalk) != 0);
            }
        }
        return (MoveRoleEmpty, 0, false);
    }

    private static double RoleHearing(
        int personIdx,
        int roleToken,
        int moveRoleCode,
        int[] cardInts,
        double[] cardDoubles,
        int cardCount)
    {
        double strength = 0.0;
        for (int c = 0; c < cardCount; c++)
        {
            int off = c * CardStride;
            int flags = cardInts[off + 1];
            int kind = cardInts[off];
            if ((flags & FlagQuoted) == 0 && (flags & FlagTestimonyOnly) == 0
                && cardInts[off + 2] == personIdx
                && (kind == KindClaim || kind == KindReport))
            {
                bool sameRole = roleToken == -5
                    ? cardInts[off + 7] == MoveRoleMedium
                    : (cardInts[off + 8] == roleToken && moveRoleCode != MoveRoleEmpty);
                if (sameRole)
                {
                    double hw = cardDoubles[c * 2];
                    if (hw > strength)
                    {
                        strength = hw;
                    }
                }
            }
        }
        return strength;
    }

    // --- 1. LiveActivity.routes(...) ---

    /// <summary>
    /// Evaluates LiveActivity.routes(...) across all movement nights.
    /// headerInts:
    ///   [0] peopleCount
    ///   [1] strictReports (0/1)
    ///   [2] selfPersonIdx (-1 if none)
    ///   [3] ownMoveRoleCode
    ///   [4] ownRoleToken
    ///   [5] ownRoleNightWalk (0/1)
    /// ownOutingsInts: pairs [night0, outBool0 (0/1), night1, outBool1, ...]
    /// Returns int[] packed output:
    ///   [0] okay (0/1)
    ///   [1] forcedLampCount (L)
    ///   [2 .. 2+L-1] forcedLamp person indices (in exact discovery order)
    ///   [2+L] nightsCount (M)
    ///   followed by M triples: [nightInt, compatibleCount, forcedOutMask]
    /// </summary>
    public static int[] EvaluateRoutes(
        int[] headerInts,
        int[] personHomes,
        int[] personDeathBeforeNight,
        int[] ownOutingsInts,
        int[] cardInts,
        double[] cardDoubles)
    {
        int n = headerInts[0];
        bool strictReports = headerInts[1] != 0;
        int selfIdx = headerInts[2];
        int ownMoveRoleCode = headerInts[3];
        int ownRoleToken = headerInts[4];
        bool ownRoleNightWalk = headerInts[5] != 0;
        int cardCount = cardInts.Length / CardStride;

        // Collect nights in exact insertion order (lines 111-117)
        var nightsOrder = new List<int>(8);
        for (int c = 0; c < cardCount; c++)
        {
            int off = c * CardStride;
            int kind = cardInts[off];
            int roleCode = cardInts[off + 7];
            if (!IsRelevantCard(kind, roleCode))
            {
                continue;
            }
            int night = cardInts[off + 9];
            if (night >= 0 && kind != KindEvening && kind != KindTrace && !nightsOrder.Contains(night))
            {
                nightsOrder.Add(night);
            }
        }
        for (int c = 0; c < cardCount; c++)
        {
            int off = c * CardStride;
            int flags = cardInts[off + 1];
            if ((flags & FlagHasRelaySource) != 0 && (flags & FlagQuoted) == 0)
            {
                int rNight = cardInts[off + 13];
                if (!nightsOrder.Contains(rNight))
                {
                    nightsOrder.Add(rNight);
                }
            }
        }

        bool okay = true;
        var forcedLamp = new List<int>(4);
        int mCount = nightsOrder.Count;
        int[] nightResults = new int[mCount * 3];

        // Precompute role_of(cards, person, knowledge) once per person
        int[] personMoveRole = new int[n];
        for (int i = 0; i < n; i++)
        {
            personMoveRole[i] = RoleOf(i, selfIdx, ownMoveRoleCode, ownRoleToken, ownRoleNightWalk, cardInts, cardCount).MoveRoleCode;
        }

        Span<PathSpec> candBuf = stackalloc PathSpec[6];
        var personOptions = new List<PathSpec>[n];
        for (int i = 0; i < n; i++)
        {
            personOptions[i] = new List<PathSpec>(6);
        }

        for (int ni = 0; ni < mCount; ni++)
        {
            int night = nightsOrder[ni];
            int forced = 0;
            int possible = 0;

            for (int i = 0; i < n; i++)
            {
                var opts = personOptions[i];
                opts.Clear();

                if (night >= personDeathBeforeNight[i])
                {
                    opts.Add(PathSpec.StayHome());
                }
                else
                {
                    int home = personHomes[i];
                    int roleCode = personMoveRole[i];
                    int candCount = 5;
                    candBuf[0] = PathSpec.StayHome();
                    candBuf[1] = PathSpec.Route(home, BlockSquare);
                    candBuf[2] = PathSpec.Route(home, BlockMarket);
                    candBuf[3] = PathSpec.Route(home, BlockDocks);
                    candBuf[4] = PathSpec.Route(home, BlockHill);
                    if (roleCode == MoveRoleEmpty || roleCode == MoveRoleLamplighter
                        || (roleCode == MoveRoleSexton && SextonTolled(i, night, cardInts, cardCount)))
                    {
                        candBuf[5] = PathSpec.LampTour(home);
                        candCount = 6;
                    }

                    int ownOutConstraint = -1; // -1 = none, 0 = false, 1 = true
                    if (i == selfIdx)
                    {
                        for (int oi = 0; oi + 1 < ownOutingsInts.Length; oi += 2)
                        {
                            if (ownOutingsInts[oi] == night)
                            {
                                ownOutConstraint = ownOutingsInts[oi + 1];
                                break;
                            }
                        }
                    }

                    for (int pIdx = 0; pIdx < candCount; pIdx++)
                    {
                        PathSpec path = candBuf[pIdx];
                        bool isOut = path.Out;
                        if (ownOutConstraint >= 0 && isOut != (ownOutConstraint != 0))
                        {
                            continue;
                        }

                        bool pathOk = true;
                        for (int c = 0; c < cardCount; c++)
                        {
                            int off = c * CardStride;
                            int flags = cardInts[off + 1];
                            bool quoted = (flags & FlagQuoted) != 0;

                            if (strictReports && (flags & FlagHasRelaySource) != 0 && !quoted
                                && cardInts[off + 12] == i && cardInts[off + 13] == night)
                            {
                                int hearth = cardInts[off + 14];
                                pathOk = pathOk && isOut && hearth >= 0 && path.LastBlock == hearth;
                            }

                            if (cardInts[off + 9] != night || quoted)
                            {
                                if (!pathOk) break;
                                continue;
                            }

                            int kind = cardInts[off];
                            if (kind == KindSighting && (cardDoubles[c * 2] < 1.0 || (flags & FlagAdmitted) != 0))
                            {
                                if (!pathOk) break;
                                continue;
                            }

                            if (kind == KindSighting && (cardInts[off + 4] & (1 << i)) != 0)
                            {
                                int blk = cardInts[off + 10];
                                bool complete = (flags & FlagComplete) != 0;
                                bool blkOk = (blk == -1) || (complete ? path.VigilSees(blk) : path.HasBlock(blk));
                                pathOk = pathOk && isOut && blkOk;
                                if ((flags & FlagHasGuardClaim) != 0)
                                {
                                    pathOk = pathOk && isOut && blk >= 0 && path.LastBlock == blk;
                                }
                            }
                            else if (kind == KindSighting && (flags & FlagComplete) != 0 && (cardInts[off + 5] & (1 << i)) == 0)
                            {
                                // Logical consistency (both cards true): the vigil rules the route out. The
                                // probabilistic score is softer (VigilMiss): the town allows a missed sighting.
                                pathOk = pathOk && !path.VigilSees(cardInts[off + 10]);
                            }
                            else if (kind == KindAlibi && cardInts[off + 3] == i && (cardInts[off + 1] & FlagKnownSelf) == 0)
                            {
                                // (The listener's own home night is soft: a Sleepwalker may walk.)
                                pathOk = pathOk && !isOut;
                            }
                            else if (kind == KindCoverage && (cardInts[off + 5] & (1 << i)) == 0)
                            {
                                pathOk = pathOk && !path.VigilSees(cardInts[off + 10]);
                            }
                            else if (kind == KindReport && cardInts[off + 7] == MoveRoleNightwatch)
                            {
                                int watchBlk = cardInts[off + 11];
                                if (strictReports && cardInts[off + 2] == i)
                                {
                                    pathOk = pathOk && isOut && watchBlk >= 0 && path.LastBlock == watchBlk;
                                }
                                else if (strictReports && (flags & FlagDutyOnly) == 0)
                                {
                                    bool inPath = path.HasBlock(watchBlk);
                                    bool inSeen = (cardInts[off + 6] & (1 << i)) != 0;
                                    pathOk = pathOk && (inPath == inSeen);
                                }
                            }
                            else if (strictReports && kind == KindReport && cardInts[off + 7] == MoveRoleMonitor
                                && cardInts[off + 2] != i && (flags & FlagDutyOnly) == 0 && cardInts[off + 17] == 0)
                            {
                                // "No one walked by my house": nobody else's route crossed the Monitor's block.
                                pathOk = pathOk && !path.HasBlock(cardInts[off + 11]);
                            }
                            else if (strictReports && kind == KindReport && cardInts[off + 7] == MoveRoleWarden && cardInts[off + 2] == i)
                            {
                                int wBlk = cardInts[off + 10];
                                pathOk = pathOk && isOut && wBlk >= 0 && path.LastBlock == wBlk;
                            }
                            else if (strictReports && kind == KindReport && cardInts[off + 7] == MoveRoleMedium && cardInts[off + 2] == i)
                            {
                                int mBlk = cardInts[off + 11];
                                pathOk = pathOk && isOut && mBlk >= 0 && path.LastBlock == mBlk;
                            }
                            else if (strictReports && kind == KindReport && cardInts[off + 7] == MoveRoleLamplighter && cardInts[off + 2] == i)
                            {
                                pathOk = pathOk && path.IsLampTour;
                            }

                            if (!pathOk)
                            {
                                break;
                            }
                        }

                        if (pathOk)
                        {
                            opts.Add(path);
                        }
                    }
                }

                if (opts.Count == 0)
                {
                    okay = false;
                }
                else
                {
                    bool allOut = true;
                    bool anyOut = false;
                    bool allLamp = true;
                    for (int k = 0; k < opts.Count; k++)
                    {
                        bool o = opts[k].Out;
                        allOut = allOut && o;
                        anyOut = anyOut || o;
                        allLamp = allLamp && opts[k].IsLampTour;
                    }
                    if (allOut) forced |= (1 << i);
                    if (anyOut) possible |= (1 << i);
                    // A Sexton's toll walk covers every block too, but it's no sign of a Lamplighter
                    // (Codex on #562): only a walker the routes force onto the tour is inferred one.
                    if (allLamp && personMoveRole[i] != MoveRoleSexton && !forcedLamp.Contains(i))
                    {
                        forcedLamp.Add(i);
                    }
                }
            }

            // Collect active Lamplighter count cards on this night
            var lampSources = new List<int>(2);
            var lampCounts = new List<int>(2);
            var lampPosMasks = new List<int>(2);
            for (int c = 0; c < cardCount; c++)
            {
                int off = c * CardStride;
                int flags = cardInts[off + 1];
                if (cardInts[off] != KindReport || (flags & FlagDutyOnly) != 0
                    || cardInts[off + 9] != night || (flags & FlagQuoted) != 0
                    || cardInts[off + 7] != MoveRoleLamplighter)
                {
                    continue;
                }
                lampSources.Add(cardInts[off + 2]);
                lampCounts.Add(cardInts[off + 17]);
                lampPosMasks.Add(cardInts[off + 6]);
            }

            int compatibleCount = 0;
            int commonForcedOut = (1 << n) - 1;
            int maskLimit = 1 << n;

            for (int mask = 0; mask < maskLimit; mask++)
            {
                if ((mask & forced) != forced || (mask & ~possible) != 0)
                {
                    continue;
                }
                bool valid = true;
                for (int lc = 0; lc < lampSources.Count; lc++)
                {
                    int src = lampSources[lc];
                    int otherMask = src >= 0 ? (mask & ~(1 << src)) : mask;
                    int posReq = lampPosMasks[lc];
                    if (BitOperations.PopCount((uint)otherMask) != lampCounts[lc]
                        || posReq < 0
                        || (mask & posReq) != posReq)
                    {
                        valid = false;
                        break;
                    }
                }
                if (valid)
                {
                    compatibleCount++;
                    commonForcedOut &= mask;
                }
            }

            if (compatibleCount == 0)
            {
                okay = false;
                commonForcedOut = 0;
            }

            nightResults[ni * 3] = night;
            nightResults[ni * 3 + 1] = compatibleCount;
            nightResults[ni * 3 + 2] = commonForcedOut;
        }

        okay = okay && forcedLamp.Count <= 1;

        int outLen = 2 + forcedLamp.Count + 1 + nightResults.Length;
        int[] result = new int[outLen];
        result[0] = okay ? 1 : 0;
        result[1] = forcedLamp.Count;
        for (int i = 0; i < forcedLamp.Count; i++)
        {
            result[2 + i] = forcedLamp[i];
        }
        int baseN = 2 + forcedLamp.Count;
        result[baseN] = mCount;
        Array.Copy(nightResults, 0, result, baseN + 1, nightResults.Length);
        return result;
    }

    // --- 2. LiveActivity._likelihood & crossing_probability ---

    private static void BuildProfileWeights(
        int personIdx,
        int alignCode,
        int[] cardInts,
        double[] cardDoubles,
        int cardCount,
        Span<int> outProfKinds,
        Span<double> outProfWeights,
        out int profCount,
        out int roleCode)
    {
        var roleInfo = RoleOf(personIdx, -1, MoveRoleEmpty, 0, false, cardInts, cardCount);
        roleCode = roleInfo.MoveRoleCode;
        int roleToken = roleInfo.RoleToken;
        bool gift = roleInfo.IsNightWalk;

        if (alignCode != AlignGood && alignCode != AlignConverted)
        {
            outProfKinds[0] = alignCode == AlignDemon ? ProfDemon : ProfMinion;
            outProfWeights[0] = 1.0;
            profCount = 1;
            return;
        }

        bool hasSourceHw = false;
        if (roleCode != MoveRoleEmpty)
        {
            for (int c = 0; c < cardCount; c++)
            {
                int off = c * CardStride;
                if (cardInts[off + 2] == personIdx && (cardInts[off + 1] & FlagHasHearingWeight) != 0)
                {
                    hasSourceHw = true;
                    break;
                }
            }
        }

        if (roleCode != MoveRoleEmpty && hasSourceHw)
        {
            double strength = RoleHearing(personIdx, roleToken, roleCode, cardInts, cardDoubles, cardCount);
            outProfKinds[0] = ProfOrdinary;
            outProfWeights[0] = SolverBridge.GodotLerpf(0.75, gift ? WalkerClaimHome : 0.9, strength);
            outProfKinds[1] = ProfGift;
            outProfWeights[1] = SolverBridge.GodotLerpf(0.15, gift ? WalkerClaimGift : 0.0, strength);
            outProfKinds[2] = ProfSecret;
            outProfWeights[2] = SolverBridge.GodotLerpf(0.1, gift ? WalkerClaimSecret : 0.1, strength);
            profCount = 3;
        }
        else if (roleCode != MoveRoleEmpty && !gift)
        {
            outProfKinds[0] = ProfOrdinary;
            outProfWeights[0] = 0.9;
            outProfKinds[1] = ProfSecret;
            outProfWeights[1] = 0.1;
            profCount = 2;
        }
        else
        {
            outProfKinds[0] = ProfOrdinary;
            outProfWeights[0] = gift ? WalkerClaimHome : 0.75;
            outProfKinds[1] = ProfGift;
            outProfWeights[1] = gift ? WalkerClaimGift : 0.15;
            outProfKinds[2] = ProfSecret;
            outProfWeights[2] = gift ? WalkerClaimSecret : 0.1;
            profCount = 3;
        }
        if (!SecretErrand)
        {
            // Retired: the errand's share stays home. An Unrequited claim still raises its
            // claimant's ordinary walk rate (FlagClaimWalks, in BuildProfilePaths).
            for (int p = 0; p < profCount; p++)
            {
                if (outProfKinds[p] == ProfSecret)
                {
                    outProfWeights[0] += outProfWeights[p];
                    outProfKinds[p] = outProfKinds[profCount - 1];
                    outProfWeights[p] = outProfWeights[profCount - 1];
                    profCount -= 1;
                    break;
                }
            }
        }
    }

    /// Whether the person's own (unquoted) Sexton report says it tolled on this night.
    private static bool SextonTolled(int personIdx, int night, int[] cardInts, int cardCount)
    {
        for (int c = 0; c < cardCount; c++)
        {
            int off = c * CardStride;
            if (cardInts[off] == KindReport && (cardInts[off + 1] & FlagQuoted) == 0
                && cardInts[off + 7] == MoveRoleSexton && cardInts[off + 2] == personIdx
                && cardInts[off + 17] == night)
            {
                return true;
            }
        }
        return false;
    }

    private static List<PathSpec> BuildProfilePaths(
        int personIdx,
        int night,
        int profKind,
        int roleCode,
        int[] personHomes,
        int[] personDeathBeforeNight,
        int[] demonAttackEvents,
        int[] cardInts,
        double[] cardDoubles,
        int cardCount,
        bool skipClaimBump = false)
    {
        double rate = profKind switch
        {
            ProfDemon => night > 0 ? 1.0 : 0.0,
            ProfMinion => 0.25,
            // The Warden has no guard on night 0 (triage 7.1), so a night-0 outing isn't its gift.
            ProfGift => roleCode == MoveRoleWarden && night < 1 ? 0.0 : 1.0,
            ProfSecret => 0.55,
            _ => 0.05
        };

        if (profKind == ProfOrdinary && !skipClaimBump)
        {
            for (int c = 0; c < cardCount; c++)
            {
                int off = c * CardStride;
                int flags = cardInts[off + 1];
                if (cardInts[off] == KindSecretClaim && (flags & FlagQuoted) == 0
                    && (SecretErrand || (flags & FlagClaimWalks) != 0)
                    && cardInts[off + 3] == personIdx
                    && night >= cardInts[off + 18] && night <= cardInts[off + 19])
                {
                    double candRate = SolverBridge.GodotLerpf(0.05, 0.55, cardDoubles[c * 2]);
                    if (candRate > rate)
                    {
                        rate = candRate;
                    }
                }
            }
        }

        var result = new List<PathSpec>(16);
        if (night >= personDeathBeforeNight[personIdx])
        {
            result.Add(PathSpec.StayHome(1.0));
            return result;
        }
        // A good Sexton walks every block on the night it says it tolled (Michael, Nov 21), so a
        // sighting of it anywhere that night fits; a lying one walks as its evil profile has it.
        if (roleCode == MoveRoleSexton && profKind != ProfDemon && profKind != ProfMinion
            && SextonTolled(personIdx, night, cardInts, cardCount))
        {
            result.Add(PathSpec.LampTour(personHomes[personIdx], 1.0));
            return result;
        }

        int nPeople = personHomes.Length;
        Span<int> destStack = stackalloc int[Math.Max(4, nPeople)];
        int destCount = 0;

        if (profKind == ProfGift && roleCode == MoveRoleMedium)
        {
            // Demon victims' hearths only (not the hanged): a victim of night d is dead from night d + 1.
            for (int p = 0; p < nPeople; p++)
            {
                if (night < personDeathBeforeNight[p])
                {
                    continue;
                }
                bool demonVictim = false;
                for (int e = 0; e + 1 < demonAttackEvents.Length; e += 2)
                {
                    if (demonAttackEvents[e + 1] == p && demonAttackEvents[e] + 1 == personDeathBeforeNight[p])
                    {
                        demonVictim = true;
                        break;
                    }
                }
                if (demonVictim)
                {
                    destStack[destCount++] = personHomes[p];
                }
            }
            if (destCount == 0)
            {
                rate = 0.0;
            }
        }
        else if (profKind == ProfGift && roleCode == MoveRoleWarden)
        {
            for (int p = 0; p < nPeople; p++)
            {
                if (p != personIdx && night < personDeathBeforeNight[p])
                {
                    destStack[destCount++] = personHomes[p];
                }
            }
            if (destCount == 0)
            {
                rate = 0.0;
            }
        }
        else if (profKind == ProfDemon)
        {
            bool foundScene = false;
            for (int e = 0; e + 1 < demonAttackEvents.Length; e += 2)
            {
                if (demonAttackEvents[e] == night)
                {
                    foundScene = true;
                    int victimIdx = demonAttackEvents[e + 1];
                    if (victimIdx >= 0 && victimIdx < nPeople)
                    {
                        destStack[destCount++] = personHomes[victimIdx];
                    }
                    break;
                }
            }
            if (!foundScene)
            {
                destStack[0] = BlockSquare;
                destStack[1] = BlockMarket;
                destStack[2] = BlockDocks;
                destStack[3] = BlockHill;
                destCount = 4;
            }
        }
        else
        {
            destStack[0] = BlockSquare;
            destStack[1] = BlockMarket;
            destStack[2] = BlockDocks;
            destStack[3] = BlockHill;
            destCount = 4;
        }

        result.Add(PathSpec.StayHome(1.0 - rate));
        bool unknownLamp = profKind == ProfGift && roleCode == MoveRoleEmpty;
        int home = personHomes[personIdx];
        if (unknownLamp)
        {
            result.Add(PathSpec.LampTour(home, rate * 0.1));
        }

        double denom = Math.Max(destCount, 1);
        double baseWeight = rate * (unknownLamp ? 0.9 : 1.0) / denom;

        for (int d = 0; d < destCount; d++)
        {
            int dest = destStack[d];
            if (profKind == ProfDemon)
            {
                // demon_routes(home, dest): the direct way only. The Demon never detours.
                result.Add(PathSpec.Route(home, dest, baseWeight));
            }
            else
            {
                PathSpec path = (profKind == ProfGift && roleCode == MoveRoleLamplighter)
                    ? PathSpec.LampTour(home, baseWeight)
                    : PathSpec.Route(home, dest, baseWeight);
                result.Add(path);
            }
        }

        return result;
    }

    [MethodImpl(MethodImplOptions.AggressiveInlining)]
    private static double Observed(
        int cardIdx,
        int[] cardInts,
        double[] cardDoubles,
        int personIdx,
        int eveningBlock,
        PathSpec path,
        int currentAlign,
        int baseAlign)
    {
        int off = cardIdx * CardStride;
        int kind = cardInts[off];
        int flags = cardInts[off + 1];
        bool quoted = (flags & FlagQuoted) != 0;
        if (quoted && kind != KindAlibi)
        {
            return 1.0;
        }
        bool isOut = path.Out;
        int personBit = 1 << personIdx;

        switch (kind)
        {
            case KindSighting:
            {
                if ((flags & FlagTellerAt) != 0 && cardInts[off + 2] == personIdx)
                {
                    if (currentAlign != AlignGood || (baseAlign == AlignConverted && (flags & FlagTellerToldCursed) != 0))
                    {
                        return 1.0;   // an evil teller's word (evil when told) says nothing of where it was
                    }
                    int at = cardInts[off + 10];
                    bool fits = (flags & FlagTellerAtHome) != 0
                        ? (!isOut || path.LastBlock == at || path.IsLampTour)
                        : (isOut && (path.IsLampTour ? path.HasBlock(at) : path.LastBlock == at));
                    return fits ? 1.0 : (1.0 - cardDoubles[cardIdx * 2]);
                }
                if ((cardInts[off + 4] & personBit) != 0)
                {
                    int blk = cardInts[off + 10];
                    bool complete = (flags & FlagComplete) != 0;
                    bool matchesBlock = (blk == -1) || (complete ? path.VigilSees(blk) : path.HasBlock(blk));
                    if ((flags & FlagAdmitted) != 0 && currentAlign != AlignGood)
                    {
                        // An evil teller owns the outing but may lie about where (Codex on #372):
                        // a place it truly went, or one picked among the blocks, weighed by how
                        // far the listener credits hearing it.
                        double hw = cardDoubles[cardIdx * 2];
                        double told = !isOut ? 0.0 : (matchesBlock ? 1.0 : 1.0 / BlockCount);
                        return hw * told + (1.0 - hw);
                    }
                    return (isOut && matchesBlock) ? 1.0 : (1.0 - cardDoubles[cardIdx * 2]);
                }
                if ((flags & FlagComplete) != 0 && (cardInts[off + 5] & personBit) == 0)
                {
                    return !path.VigilSees(cardInts[off + 10]) ? 1.0 : VigilMiss;
                }
                return 1.0;
            }
            case KindEvening:
            {
                if ((cardInts[off + 4] & personBit) != 0)
                {
                    return cardInts[off + 10] == eveningBlock ? 1.0 : 0.0;
                }
                return 1.0;
            }
            case KindCoverage:
            {
                if ((cardInts[off + 5] & personBit) == 0)
                {
                    return !path.VigilSees(cardInts[off + 10]) ? 1.0 : VigilMiss;
                }
                return 1.0;
            }
            case KindAlibi:
            {
                if ((flags & FlagKnownSelf) != 0)
                {
                    if (cardInts[off + 3] != personIdx)
                    {
                        return 1.0;
                    }
                    if ((flags & FlagKnownRoute) != 0)
                    {
                        // "I know where I walked": out on exactly those blocks.
                        return isOut && path.BlockMask == cardInts[off + 17] ? 1.0 : 1.0 - cardDoubles[cardIdx * 2];
                    }
                    // "I know I was home": only its tiny self-doubt leaves room for being out.
                    return !isOut ? 1.0 : 1.0 - cardDoubles[cardIdx * 2];
                }
                if (cardInts[off + 3] == personIdx)
                {
                    // Someone else's word on a person's night (a witness) stays hard.
                    if (!quoted && cardInts[off + 2] != personIdx)
                    {
                        return !isOut ? 1.0 : 0.0;
                    }
                    // A person's own word: a good one out on a hidden gift or a secret (or a
                    // Sleepwalker) may still say "home"; an evil one may be covering a night out.
                    if (!quoted && currentAlign == AlignGood)
                    {
                        // The card's own good out-rate: GoodOwnAlibiOut, higher while an excuse
                        // for a caught lie stands (LiveAssessment._mark_excuses, packed second).
                        return !isOut ? 1.0 : cardDoubles[cardIdx * 2 + 1];
                    }
                    return isOut ? (currentAlign != AlignGood ? 0.7 : 0.3) : 0.9;
                }
                return 1.0;
            }
            case KindReport:
            {
                int roleCode = cardInts[off + 7];
                int src = cardInts[off + 2];
                if (roleCode == MoveRoleWarden && src == personIdx)
                {
                    int blk = cardInts[off + 10];
                    return currentAlign == AlignGood ? ((isOut && blk >= 0 && path.LastBlock == blk) ? 1.0 : 0.0) : 1.0;
                }
                if (roleCode == MoveRoleMedium && src == personIdx)
                {
                    int blk = cardInts[off + 11];
                    return currentAlign == AlignGood ? ((isOut && blk >= 0 && path.LastBlock == blk) ? 1.0 : 0.0) : 1.0;
                }
                if (roleCode == MoveRoleLamplighter && src == personIdx && (flags & FlagDutyOnly) != 0)
                {
                    return currentAlign == AlignGood ? (path.IsLampTour ? 1.0 : 0.0) : 1.0;
                }
                if (roleCode == MoveRoleMonitor && src != personIdx && (flags & FlagDutyOnly) == 0 && cardInts[off + 17] == 0)
                {
                    double monErr = cardDoubles[cardIdx * 2 + 1];
                    return path.HasBlock(cardInts[off + 11]) ? monErr : (1.0 - monErr);
                }
                if (roleCode == MoveRoleNightwatch)
                {
                    int blk = cardInts[off + 11];
                    if (src == personIdx)
                    {
                        return currentAlign == AlignGood ? ((isOut && blk >= 0 && path.LastBlock == blk) ? 1.0 : 0.0) : 1.0;
                    }
                    if ((flags & FlagDutyOnly) != 0)
                    {
                        return 1.0;
                    }
                    double nwErr = cardDoubles[cardIdx * 2 + 1];
                    bool inPath = path.HasBlock(blk);
                    bool inSeen = (cardInts[off + 6] & personBit) != 0;
                    return (inPath == inSeen) ? (1.0 - nwErr) : nwErr;
                }
                return 1.0;
            }
            case KindTrace:
            {
                if (currentAlign == AlignDemon)
                {
                    if ((flags & FlagTraceHasFamily) != 0)
                    {
                        return 1.0;
                    }
                    return (cardInts[off + 11] == eveningBlock ? 0.6 : 0.0) + (0.4 / BlockCount);
                }
                return 1.0;
            }
            default:
                return 1.0;
        }
    }

    public static double ComputeSingleLikelihood(
        int personIdx,
        int alignCode,
        int[] personHomes,
        int[] personDeathBeforeNight,
        int[] demonAttackEvents,
        bool hasCurse,
        int curseFrom,
        int curseUntil,
        int[] cardInts,
        double[] cardDoubles)
    {
        int cardCount = cardInts.Length / CardStride;
        var nights = new List<int>(8);
        var relevantIndices = new List<int>(cardCount);
        for (int c = 0; c < cardCount; c++)
        {
            int off = c * CardStride;
            if (IsRelevantCard(cardInts[off], cardInts[off + 7]))
            {
                relevantIndices.Add(c);
                int night = cardInts[off + 9];
                if (night >= 0 && !nights.Contains(night))
                {
                    nights.Add(night);
                }
            }
        }

        var reportsByNight = BuildReportsByNight(nights, relevantIndices, cardInts);
        return ComputePersonLikelihoodCore(
            personIdx,
            alignCode,
            nights,
            reportsByNight,
            personHomes,
            personDeathBeforeNight,
            demonAttackEvents,
            hasCurse,
            curseFrom,
            curseUntil,
            cardInts,
            cardDoubles,
            cardCount);
    }

    /// <summary>
    /// Computes (good, minion, demon, [converted]) likelihoods for ALL N people in one pass.
    /// Stride is 4 doubles per person if includeConverted is true, else 3 doubles per person.
    /// </summary>
    public static double[] ComputeAllProfiles(
        bool includeConverted,
        int[] personHomes,
        int[] personDeathBeforeNight,
        int[] demonAttackEvents,
        bool hasCurse,
        int curseFrom,
        int curseUntil,
        int[] cardInts,
        double[] cardDoubles)
    {
        int nPeople = personHomes.Length;
        int stride = includeConverted ? 4 : 3;
        double[] outBuf = new double[nPeople * stride];
        int cardCount = cardInts.Length / CardStride;

        var nights = new List<int>(8);
        var relevantIndices = new List<int>(cardCount);
        for (int c = 0; c < cardCount; c++)
        {
            int off = c * CardStride;
            if (IsRelevantCard(cardInts[off], cardInts[off + 7]))
            {
                relevantIndices.Add(c);
                int night = cardInts[off + 9];
                if (night >= 0 && !nights.Contains(night))
                {
                    nights.Add(night);
                }
            }
        }

        var reportsByNight = BuildReportsByNight(nights, relevantIndices, cardInts);

        for (int p = 0; p < nPeople; p++)
        {
            int b = p * stride;
            outBuf[b] = ComputePersonLikelihoodCore(
                p, AlignGood, nights, reportsByNight, personHomes, personDeathBeforeNight,
                demonAttackEvents, hasCurse, curseFrom, curseUntil, cardInts, cardDoubles, cardCount);
            outBuf[b + 1] = ComputePersonLikelihoodCore(
                p, AlignMinion, nights, reportsByNight, personHomes, personDeathBeforeNight,
                demonAttackEvents, hasCurse, curseFrom, curseUntil, cardInts, cardDoubles, cardCount);
            outBuf[b + 2] = ComputePersonLikelihoodCore(
                p, AlignDemon, nights, reportsByNight, personHomes, personDeathBeforeNight,
                demonAttackEvents, hasCurse, curseFrom, curseUntil, cardInts, cardDoubles, cardCount);
            if (includeConverted)
            {
                outBuf[b + 3] = ComputePersonLikelihoodCore(
                    p, AlignConverted, nights, reportsByNight, personHomes, personDeathBeforeNight,
                    demonAttackEvents, hasCurse, curseFrom, curseUntil, cardInts, cardDoubles, cardCount);
            }
        }

        return outBuf;
    }

    /// <summary>
    /// Each person's movement likelihood as a good holder of Unrequited (burdens prototype;
    /// sim/burdens.gd unrequited_visit). Their good profiles as usual, but the ordinary one also
    /// visits the beloved: a visit on visitChance of nights, forced the night after a missed
    /// one (once they've visited at all), run forward over every night from the first to the
    /// last one any card is about (a night with no card weighs 1). A visit is the way to the
    /// beloved's block, home when it is theirs, the hill once the beloved is dead; any other
    /// night the ordinary paths, without a claimed walk's raised rate (the visits are what
    /// explain it here). The beloved is anyone else, equally likely, or the one the person's
    /// own Unrequited claim names (slot 16). Summed over the beloved and the evening haunt.
    /// </summary>
    public static double[] ComputeUnrequitedProfiles(
        double visitChance,
        int[] personHomes,
        int[] personDeathBeforeNight,
        int[] demonAttackEvents,
        int[] cardInts,
        double[] cardDoubles)
    {
        int nPeople = personHomes.Length;
        double[] outBuf = new double[nPeople];
        int cardCount = cardInts.Length / CardStride;
        var nights = new List<int>(8);
        var relevantIndices = new List<int>(cardCount);
        for (int c = 0; c < cardCount; c++)
        {
            int off = c * CardStride;
            if (IsRelevantCard(cardInts[off], cardInts[off + 7]))
            {
                relevantIndices.Add(c);
                int night = cardInts[off + 9];
                if (night >= 0 && !nights.Contains(night))
                {
                    nights.Add(night);
                }
            }
        }
        var reportsByNight = BuildReportsByNight(nights, relevantIndices, cardInts);
        for (int p = 0; p < nPeople; p++)
        {
            outBuf[p] = UnrequitedLikelihood(p, visitChance, nights, reportsByNight, personHomes, personDeathBeforeNight,
                demonAttackEvents, cardInts, cardDoubles, cardCount);
        }
        return outBuf;
    }

    public static double UnrequitedLikelihood(
        int personIdx,
        double visitChance,
        List<int> nights,
        int[][] reportsByNight,
        int[] personHomes,
        int[] personDeathBeforeNight,
        int[] demonAttackEvents,
        int[] cardInts,
        double[] cardDoubles,
        int cardCount)
    {
        Span<int> profKinds = stackalloc int[3];
        Span<double> profWeights = stackalloc double[3];
        BuildProfileWeights(personIdx, AlignGood, cardInts, cardDoubles, cardCount, profKinds, profWeights, out int profCount, out int roleCode);
        int nPeople = personHomes.Length;
        int nNights = nights.Count;
        int home = personHomes[personIdx];

        // The beloved: the one the person's own unquoted Unrequited claim names, else anyone.
        int named = -1;
        for (int c = 0; c < cardCount; c++)
        {
            int off = c * CardStride;
            int flags = cardInts[off + 1];
            if (cardInts[off] == KindSecretClaim && (flags & FlagQuoted) == 0 && (flags & FlagClaimWalks) != 0
                && cardInts[off + 2] == personIdx && cardInts[off + 3] == personIdx
                && cardInts[off + 16] >= 0 && cardInts[off + 16] < nPeople && cardInts[off + 16] != personIdx)
            {
                named = cardInts[off + 16];
                break;
            }
        }
        // An announced spell break (Burdens.spell_breaks, slot 17: the meeting's day) stops the
        // visits from that night on: the holder walks as anyone does (Codex, #547).
        int breakNight = int.MaxValue;
        for (int c = 0; c < cardCount; c++)
        {
            int off = c * CardStride;
            if (cardInts[off] == KindSecretClaim && (cardInts[off + 1] & FlagQuoted) == 0
                && cardInts[off + 2] == personIdx && cardInts[off + 3] == personIdx && cardInts[off + 17] >= 0)
            {
                breakNight = Math.Min(breakNight, cardInts[off + 17]);
            }
        }
        var beloveds = new List<int>(nPeople);
        if (named >= 0)
        {
            beloveds.Add(named);
        }
        else
        {
            for (int b = 0; b < nPeople; b++)
            {
                if (b != personIdx)
                    beloveds.Add(b);
            }
        }
        int nB = beloveds.Count;
        int maxNight = -1;
        for (int n = 0; n < nNights; n++)
        {
            maxNight = Math.Max(maxNight, nights[n]);
        }

        double total = 0.0;
        for (int pr = 0; pr < profCount; pr++)
        {
            int profKind = profKinds[pr];
            double profW = profWeights[pr];
            bool visits = profKind == ProfOrdinary;
            // [night][evening] sums: the profile's paths, and (visits) each beloved's visit.
            double[][] ord = new double[nNights][];
            double[][][] vis = visits ? new double[nNights][][] : null;
            for (int n = 0; n < nNights; n++)
            {
                int night = nights[n];
                int[] nightCards = reportsByNight[n];
                var paths = BuildProfilePaths(personIdx, night, profKind, roleCode, personHomes, personDeathBeforeNight,
                    demonAttackEvents, cardInts, cardDoubles, cardCount, visits);
                ord[n] = new double[BlockCount];
                for (int e = 0; e < BlockCount; e++)
                {
                    double sum = 0.0;
                    for (int pi = 0; pi < paths.Count; pi++)
                    {
                        double pv = paths[pi].Weight;
                        for (int ci = 0; ci < nightCards.Length; ci++)
                            pv *= Observed(nightCards[ci], cardInts, cardDoubles, personIdx, e, paths[pi], AlignGood, AlignGood);
                        sum += pv;
                    }
                    ord[n][e] = sum;
                }
                if (!visits)
                    continue;
                vis![n] = new double[nB][];
                for (int bi = 0; bi < nB; bi++)
                {
                    int b = beloveds[bi];
                    PathSpec path = night >= personDeathBeforeNight[personIdx] ? PathSpec.StayHome(1.0)
                        : night >= personDeathBeforeNight[b] ? PathSpec.Route(home, BlockHill, 1.0)
                        : personHomes[b] == home ? PathSpec.StayHome(1.0)
                        : PathSpec.Route(home, personHomes[b], 1.0);
                    vis[n][bi] = new double[BlockCount];
                    for (int e = 0; e < BlockCount; e++)
                    {
                        double pv = 1.0;
                        for (int ci = 0; ci < nightCards.Length; ci++)
                            pv *= Observed(nightCards[ci], cardInts, cardDoubles, personIdx, e, path, AlignGood, AlignGood);
                        vis[n][bi][e] = pv;
                    }
                }
            }
            for (int haunt = 0; haunt < BlockCount; haunt++)
            {
                double w0 = profW / (double)BlockCount;
                if (!visits)
                {
                    double weight = w0;
                    for (int n = 0; n < nNights; n++)
                    {
                        double sum = 0.0;
                        for (int e = 0; e < BlockCount; e++)
                            sum += (e == haunt ? 0.7 : 0.1) * ord[n][e];
                        weight *= sum;
                    }
                    total += weight;
                    continue;
                }
                double[] foN = new double[nNights];
                for (int n = 0; n < nNights; n++)
                {
                    double sum = 0.0;
                    for (int e = 0; e < BlockCount; e++)
                        sum += (e == haunt ? 0.7 : 0.1) * ord[n][e];
                    foN[n] = sum;
                }
                double acc = 0.0;
                for (int bi = 0; bi < nB; bi++)
                {
                    // Forward over nights 0..maxNight: never visited yet, visited last night,
                    // missed last night after a visit (so tonight's visit is forced).
                    double sN = 1.0, sV = 0.0, sM = 0.0;
                    for (int night = 0; night <= maxNight; night++)
                    {
                        int n = nights.IndexOf(night);
                        double fo = 1.0, fv = 1.0;
                        if (n >= 0)
                        {
                            fo = foN[n];
                            fv = 0.0;
                            for (int e = 0; e < BlockCount; e++)
                                fv += (e == haunt ? 0.7 : 0.1) * vis![n][bi][e];
                        }
                        if (night >= breakNight)
                        {
                            sN = (sN + sV + sM) * fo;
                            sV = 0.0;
                            sM = 0.0;
                            continue;
                        }
                        if (roleCode == MoveRoleSexton && SextonTolled(personIdx, night, cardInts, cardCount))
                        {
                            // The toll walk comes first (world_night.gd), and a holder already out
                            // doesn't visit (Burdens.unrequited_visit): no visit tonight, and a
                            // visit that was due stays due (Codex on #562).
                            double tN = sN * fo;
                            double tM = (sV + sM) * fo;
                            sN = tN;
                            sV = 0.0;
                            sM = tM;
                            continue;
                        }
                        double nN = sN * (1.0 - visitChance) * fo;
                        double nV = (sN * visitChance + sV * visitChance + sM) * fv;
                        double nM = sV * (1.0 - visitChance) * fo;
                        sN = nN;
                        sV = nV;
                        sM = nM;
                    }
                    acc += sN + sV + sM;
                }
                total += w0 * acc / nB;
            }
        }
        return total;
    }

    private static int[][] BuildReportsByNight(List<int> nights, List<int> relevantIndices, int[] cardInts)
    {
        int nNights = nights.Count;
        int[][] reportsByNight = new int[nNights][];
        var seenInc = new List<int>(16);
        var reports = new List<int>(16);

        for (int ni = 0; ni < nNights; ni++)
        {
            int night = nights[ni];
            seenInc.Clear();
            reports.Clear();
            for (int r = 0; r < relevantIndices.Count; r++)
            {
                int c = relevantIndices[r];
                int off = c * CardStride;
                if (cardInts[off + 9] != night)
                {
                    continue;
                }
                int incTok = cardInts[off + 15];
                if (!seenInc.Contains(incTok))
                {
                    seenInc.Add(incTok);
                    reports.Add(c);
                }
            }
            reportsByNight[ni] = reports.Count > 0 ? reports.ToArray() : Array.Empty<int>();
        }
        return reportsByNight;
    }

    private static double ComputePersonLikelihoodCore(
        int personIdx,
        int alignCode,
        List<int> nights,
        int[][] reportsByNight,
        int[] personHomes,
        int[] personDeathBeforeNight,
        int[] demonAttackEvents,
        bool hasCurse,
        int curseFrom,
        int curseUntil,
        int[] cardInts,
        double[] cardDoubles,
        int cardCount)
    {
        Span<int> profKinds = stackalloc int[3];
        Span<double> profWeights = stackalloc double[3];
        BuildProfileWeights(personIdx, alignCode, cardInts, cardDoubles, cardCount, profKinds, profWeights, out int profCount, out int roleCode);

        int nNights = nights.Count;
        double[][][] tables = new double[nNights][][];
        for (int n = 0; n < nNights; n++)
        {
            tables[n] = new double[BlockCount][];
        }

        double total = 0.0;
        for (int pr = 0; pr < profCount; pr++)
        {
            int profKind = profKinds[pr];
            double profW = profWeights[pr];

            for (int n = 0; n < nNights; n++)
            {
                int night = nights[n];
                int currentAlign = alignCode;
                if (alignCode == AlignConverted)
                {
                    int nightTick = night * 4 + 3;
                    currentAlign = (hasCurse && nightTick >= curseFrom && nightTick < curseUntil) ? AlignMinion : AlignGood;
                }
                int effProfKind = (alignCode == AlignConverted && currentAlign == AlignMinion) ? ProfMinion : profKind;
                var paths = BuildProfilePaths(
                    personIdx, night, effProfKind, roleCode, personHomes, personDeathBeforeNight,
                    demonAttackEvents, cardInts, cardDoubles, cardCount);
                int pathCount = paths.Count;
                int[] nightCards = reportsByNight[n];

                for (int e = 0; e < BlockCount; e++)
                {
                    double[] products = new double[pathCount];
                    for (int pi = 0; pi < pathCount; pi++)
                    {
                        PathSpec path = paths[pi];
                        double p = path.Weight;
                        for (int ci = 0; ci < nightCards.Length; ci++)
                        {
                            p *= Observed(nightCards[ci], cardInts, cardDoubles, personIdx, e, path, currentAlign, alignCode);
                        }
                        products[pi] = p;
                    }
                    tables[n][e] = products;
                }
            }

            // Exact haunt -> night -> evening -> path contraction order (lines 364-375)
            for (int haunt = 0; haunt < BlockCount; haunt++)
            {
                double weight = profW / (double)BlockCount;
                for (int n = 0; n < nNights; n++)
                {
                    double sum = 0.0;
                    for (int e = 0; e < BlockCount; e++)
                    {
                        double eveningP = e == haunt ? 0.7 : 0.1;
                        double[] prods = tables[n][e];
                        for (int pi = 0; pi < prods.Length; pi++)
                        {
                            sum += eveningP * prods[pi];
                        }
                    }
                    weight *= sum;
                }
                total += weight;
            }
        }

        return total;
    }

    public static double ComputeCrossingProbability(
        int personIdx,
        int night,
        int alignCode,
        int sceneBlockCode,
        int[] personHomes,
        int[] personDeathBeforeNight,
        int[] demonAttackEvents,
        bool hasCurse,
        int curseFrom,
        int curseUntil,
        int[] cardInts,
        double[] cardDoubles)
    {
        if (sceneBlockCode == -1 || night >= personDeathBeforeNight[personIdx])
        {
            return 0.0;
        }
        int cardCount = cardInts.Length / CardStride;
        var seenInc = new List<int>(16);
        var nightObs = new List<int>(16);
        for (int c = 0; c < cardCount; c++)
        {
            int off = c * CardStride;
            int kind = cardInts[off];
            int roleCode = cardInts[off + 7];
            if (!IsRelevantCard(kind, roleCode))
            {
                continue;
            }
            int flags = cardInts[off + 1];
            if (cardInts[off + 9] != night || kind == KindTrace || ((flags & FlagQuoted) != 0 && kind != KindAlibi))
            {
                continue;
            }
            int incTok = cardInts[off + 15];
            if (!seenInc.Contains(incTok))
            {
                seenInc.Add(incTok);
                nightObs.Add(c);
            }
        }
        int[] obsArr = nightObs.Count > 0 ? nightObs.ToArray() : Array.Empty<int>();
        return ComputeCrossingCore(
            personIdx, night, alignCode, sceneBlockCode, obsArr, personHomes, personDeathBeforeNight,
            demonAttackEvents, hasCurse, curseFrom, curseUntil, cardInts, cardDoubles, cardCount);
    }

    /// <summary>
    /// Computes scene crossing probabilities for ALL N people on (night, sceneBlockCode) in one call.
    /// Stride is 3 doubles per person (good, minion, converted) if includeConverted is true, else 2 (good, minion).
    /// </summary>
    public static double[] ComputeSceneCrossings(
        int night,
        int sceneBlockCode,
        bool includeConverted,
        int[] personHomes,
        int[] personDeathBeforeNight,
        int[] demonAttackEvents,
        bool hasCurse,
        int curseFrom,
        int curseUntil,
        int[] cardInts,
        double[] cardDoubles)
    {
        int nPeople = personHomes.Length;
        int stride = includeConverted ? 3 : 2;
        double[] outBuf = new double[nPeople * stride];
        if (sceneBlockCode == -1)
        {
            return outBuf;
        }
        int cardCount = cardInts.Length / CardStride;
        var seenInc = new List<int>(16);
        var nightObs = new List<int>(16);
        for (int c = 0; c < cardCount; c++)
        {
            int off = c * CardStride;
            int kind = cardInts[off];
            int roleCode = cardInts[off + 7];
            if (!IsRelevantCard(kind, roleCode))
            {
                continue;
            }
            int flags = cardInts[off + 1];
            if (cardInts[off + 9] != night || kind == KindTrace || ((flags & FlagQuoted) != 0 && kind != KindAlibi))
            {
                continue;
            }
            int incTok = cardInts[off + 15];
            if (!seenInc.Contains(incTok))
            {
                seenInc.Add(incTok);
                nightObs.Add(c);
            }
        }
        int[] obsArr = nightObs.Count > 0 ? nightObs.ToArray() : Array.Empty<int>();

        for (int p = 0; p < nPeople; p++)
        {
            int b = p * stride;
            outBuf[b] = ComputeCrossingCore(
                p, night, AlignGood, sceneBlockCode, obsArr, personHomes, personDeathBeforeNight,
                demonAttackEvents, hasCurse, curseFrom, curseUntil, cardInts, cardDoubles, cardCount);
            outBuf[b + 1] = ComputeCrossingCore(
                p, night, AlignMinion, sceneBlockCode, obsArr, personHomes, personDeathBeforeNight,
                demonAttackEvents, hasCurse, curseFrom, curseUntil, cardInts, cardDoubles, cardCount);
            if (includeConverted)
            {
                outBuf[b + 2] = ComputeCrossingCore(
                    p, night, AlignConverted, sceneBlockCode, obsArr, personHomes, personDeathBeforeNight,
                    demonAttackEvents, hasCurse, curseFrom, curseUntil, cardInts, cardDoubles, cardCount);
            }
        }
        return outBuf;
    }

    private static double ComputeCrossingCore(
        int personIdx,
        int night,
        int alignCode,
        int sceneBlockCode,
        int[] obsArr,
        int[] personHomes,
        int[] personDeathBeforeNight,
        int[] demonAttackEvents,
        bool hasCurse,
        int curseFrom,
        int curseUntil,
        int[] cardInts,
        double[] cardDoubles,
        int cardCount)
    {
        if (sceneBlockCode == -1 || night >= personDeathBeforeNight[personIdx])
        {
            return 0.0;
        }

        Span<int> profKinds = stackalloc int[3];
        Span<double> profWeights = stackalloc double[3];
        BuildProfileWeights(personIdx, alignCode, cardInts, cardDoubles, cardCount, profKinds, profWeights, out int profCount, out int roleCode);

        int currentAlign = alignCode;
        if (alignCode == AlignConverted && hasCurse)
        {
            int nightTick = night * 4 + 3;
            currentAlign = (nightTick >= curseFrom && nightTick < curseUntil) ? AlignMinion : AlignGood;
        }

        double numCross = 0.0;
        double denAll = 0.0;

        for (int pr = 0; pr < profCount; pr++)
        {
            int pKind = (alignCode == AlignConverted && currentAlign == AlignMinion) ? ProfMinion : profKinds[pr];
            double profW = profWeights[pr];
            var paths = BuildProfilePaths(
                personIdx, night, pKind, roleCode, personHomes, personDeathBeforeNight,
                demonAttackEvents, cardInts, cardDoubles, cardCount);
            int pathCount = paths.Count;

            for (int e = 0; e < BlockCount; e++)
            {
                const double evP = 0.25;
                for (int pi = 0; pi < pathCount; pi++)
                {
                    PathSpec path = paths[pi];
                    double wP = profW * evP * path.Weight;
                    for (int oi = 0; oi < obsArr.Length; oi++)
                    {
                        wP *= Observed(obsArr[oi], cardInts, cardDoubles, personIdx, e, path, currentAlign, alignCode);
                    }
                    denAll += wP;
                    if (path.Out && path.HasBlock(sceneBlockCode))
                    {
                        numCross += wP;
                    }
                }
            }
        }

        if (denAll <= 1e-20)
        {
            return 0.0;
        }
        return Math.Clamp(numCross / denAll, 0.0, 1.0);
    }

    // --- 3. Joint Movement Factor Registration & World Scoring ---

    /// <summary>
    /// Deserializes a compiled movement factor from flat int[] + double[] buffers into SolverContext
    /// and returns its integer handle.
    /// metaInts layout:
    ///   [0] peopleCount (N)
    ///   [1] hasConvertedProfiles (0/1)
    ///   [2] sceneCount (S)
    ///   [3] scionSplitCount (K)
    ///   Then for each scene s in 0..S-1 (4 ints):
    ///     [victimIdx, sceneTraceCount, twoCited (0/1), hasCrossConverted (0/1)]
    ///   Then for each scion split k in 0..K-1:
    ///     [executedIdx, aliveDemonMask, preSceneCount, postSceneCount]
    ///     followed by preSceneCount * 4 ints and postSceneCount * 4 ints!
    /// metaDoubles layout:
    ///   [0] tracePasserEps
    ///   [1] traceUnknownWeight
    ///   Then main profiles: ProfGood[N], ProfMinion[N], ProfDemon[N], (if hasConvertedProfiles: ProfConverted[N])
    ///   Then for each main scene: W1[N], (if twoCited: W2[N]), (if twoCited || sceneTraceCount >= 2: CrossGood[N], CrossMinion[N], (if hasCrossConverted: CrossConverted[N]))
    ///   Then for each scion split:
    ///     PreGood[N], PreMinion[N], PreDemon[N], PostGood[N], PostMinion[N], PostDemon[N],
    ///     followed by PreScenes doubles and PostScenes doubles using the exact same scene layout!
    ///   Then, optionally, one trailing double: DayDemonShare (absent = 0).
    /// </summary>
    public static int RegisterCompiledFactor(int[] metaInts, double[] metaDoubles)
    {
        int iPos = 0;
        int dPos = 0;

        int n = metaInts[iPos++];
        int colFlags = metaInts[iPos++];   // bit 0: converted column; bit 1: Unrequited column
        bool hasConv = (colFlags & 1) != 0;
        bool hasUnreq = (colFlags & 2) != 0;
        int sceneCount = metaInts[iPos++];
        int splitCount = metaInts[iPos++];

        var factor = new CompiledMovementFactor
        {
            PeopleCount = n,
            HasConvertedProfiles = hasConv,
            TracePasserEps = metaDoubles[dPos++],
            TraceUnknownWeight = metaDoubles[dPos++],
            ProfGood = SliceDoubles(metaDoubles, ref dPos, n),
            ProfMinion = SliceDoubles(metaDoubles, ref dPos, n),
            ProfDemon = SliceDoubles(metaDoubles, ref dPos, n),
            ProfConverted = hasConv ? SliceDoubles(metaDoubles, ref dPos, n) : Array.Empty<double>(),
            ProfUnrequited = hasUnreq ? SliceDoubles(metaDoubles, ref dPos, n) : Array.Empty<double>(),
            SceneTables = new SceneTableData[sceneCount],
            ScionSplits = new ScionSplitData[splitCount],
        };

        // Read scene headers first or inline: reading scene headers inline with scene doubles keeps packing linear!
        for (int s = 0; s < sceneCount; s++)
        {
            factor.SceneTables[s] = ReadSceneTable(n, metaInts, ref iPos, metaDoubles, ref dPos);
        }

        for (int k = 0; k < splitCount; k++)
        {
            int execIdx = metaInts[iPos++];
            int aliveMask = metaInts[iPos++];
            int preScCount = metaInts[iPos++];
            int postScCount = metaInts[iPos++];

            var split = new ScionSplitData
            {
                ExecutedIdx = execIdx,
                AliveDemonMask = aliveMask,
                PreGood = SliceDoubles(metaDoubles, ref dPos, n),
                PreMinion = SliceDoubles(metaDoubles, ref dPos, n),
                PreDemon = SliceDoubles(metaDoubles, ref dPos, n),
                PostGood = SliceDoubles(metaDoubles, ref dPos, n),
                PostMinion = SliceDoubles(metaDoubles, ref dPos, n),
                PostDemon = SliceDoubles(metaDoubles, ref dPos, n),
                PreScenes = new SceneTableData[preScCount],
                PostScenes = new SceneTableData[postScCount],
            };
            for (int ps = 0; ps < preScCount; ps++)
            {
                split.PreScenes[ps] = ReadSceneTable(n, metaInts, ref iPos, metaDoubles, ref dPos);
            }
            for (int qs = 0; qs < postScCount; qs++)
            {
                split.PostScenes[qs] = ReadSceneTable(n, metaInts, ref iPos, metaDoubles, ref dPos);
            }
            factor.ScionSplits[k] = split;
        }

        // Optional trailing double: the day-killer share. Absent means 0, so old packings read the same.
        if (dPos < metaDoubles.Length)
        {
            factor.DayDemonShare = metaDoubles[dPos++];
        }
        // Optional trailing Hexer kills: ints [K, (places, aliveMask, regMask x places) x K],
        // doubles [floor, (n shares per place) ...]. Only written with a share above 0.
        if (iPos < metaInts.Length && dPos < metaDoubles.Length)
        {
            int k = metaInts[iPos++];
            factor.HexFloor = metaDoubles[dPos++];
            factor.HexKills = new HexKill[k];
            for (int i = 0; i < k; i++)
            {
                var hk = new HexKill();
                int places = metaInts[iPos++];
                hk.AliveMask = metaInts[iPos++];
                hk.Night = metaInts[iPos++];
                hk.RegMasks = new int[places];
                hk.Shares = new double[places][];
                for (int p = 0; p < places; p++)
                {
                    hk.RegMasks[p] = metaInts[iPos++];
                    var sh = new double[n];
                    for (int j = 0; j < n; j++)
                        sh[j] = metaDoubles[dPos++];
                    hk.Shares[p] = sh;
                }
                factor.HexKills[i] = hk;
            }
            // Then the possible successions: [S, (executed, exec day, alive mask) x S].
            if (iPos < metaInts.Length)
            {
                int sc = metaInts[iPos++];
                factor.HexSuccessions = new HexSuccession[sc];
                for (int i = 0; i < sc; i++)
                {
                    factor.HexSuccessions[i] = new HexSuccession
                    {
                        ExecutedIdx = metaInts[iPos++],
                        ExecDay = metaInts[iPos++],
                        AliveDemonMask = metaInts[iPos++],
                    };
                }
            }
        }

        return SolverContext.RegisterMovementFactor(factor);
    }

    /// <summary>
    /// Attaches the sighting contests to a registered factor.
    /// ints: [P, then per contest: person, k, sighter x k, then per sighter a converted flag].
    /// doubles: [truth, then per contest, per subset m = 1 .. 2^k - 1: good, minion, demon,
    /// converted, C; then per flagged sighter j, per subset m containing j: the same five].
    /// </summary>
    public static void AttachContests(int factorHandle, int[] ints, double[] doubles)
    {
        var factor = SolverContext.GetMovementFactor(factorHandle);
        int iPos = 0;
        int dPos = 0;
        int count = ints[iPos++];
        factor.ContestTruth = doubles[dPos++];
        factor.Contests = new SightingContest[factor.PeopleCount];
        for (int c = 0; c < count; c++)
        {
            int person = ints[iPos++];
            int k = ints[iPos++];
            var ct = new SightingContest { Sighters = new int[k] };
            for (int j = 0; j < k; j++)
                ct.Sighters[j] = ints[iPos++];
            int subsets = (1 << k) - 1;
            ct.Alt = new double[subsets][];
            ct.C = new double[subsets];
            for (int m = 0; m < subsets; m++)
            {
                ct.Alt[m] = SliceDoubles(doubles, ref dPos, 4);
                ct.C[m] = doubles[dPos++];
            }
            ct.ConvAlt = new double[k][][];
            ct.ConvC = new double[k][];
            for (int j = 0; j < k; j++)
            {
                if (ints[iPos++] == 0)
                    continue;
                ct.ConvAlt[j] = new double[subsets][];
                ct.ConvC[j] = new double[subsets];
                for (int m = 1; m <= subsets; m++)
                {
                    if ((m & (1 << j)) == 0)
                        continue;
                    ct.ConvAlt[j][m - 1] = SliceDoubles(doubles, ref dPos, 4);
                    ct.ConvC[j][m - 1] = doubles[dPos++];
                }
            }
            factor.Contests[person] = ct;
        }
    }

    /// <summary>
    /// Attaches the quiet-night Warden guards to a registered factor.
    /// ints: [K, then per guard: source, target, night]. doubles: [R x K, then per subset
    /// T = 1 .. 2^K - 1: the demon profile of each person; then, per Scion split in order,
    /// the same subsets for its before profiles and then for its after profiles].
    /// </summary>
    public static void AttachListMix(int factorHandle, int watcher, double broken, double altScale, bool toldCursed, int nextHandle, int altHandle)
    {
        AttachListMix(factorHandle, watcher, broken, altScale, toldCursed, nextHandle, altHandle, false, false);
    }

    /// <summary>AttachListMix for a Lamplighter's count: <paramref name="evilTakesAlt"/> and
    /// <paramref name="soundZero"/> (CompiledMovementFactor.ListMixEvilTakesAlt, ListMixSoundZero).</summary>
    public static void AttachListMix(int factorHandle, int watcher, double broken, double altScale, bool toldCursed, int nextHandle, int altHandle, bool evilTakesAlt, bool soundZero)
    {
        AttachListMix(factorHandle, watcher, broken, altScale, toldCursed, nextHandle, altHandle, evilTakesAlt, soundZero, 0);
    }

    /// <summary>AttachListMix with the omen claimants whose window covers the list or count
    /// (CompiledMovementFactor.ListMixOmenMask).</summary>
    public static void AttachListMix(int factorHandle, int watcher, double broken, double altScale, bool toldCursed, int nextHandle, int altHandle, bool evilTakesAlt, bool soundZero, int omenMask)
    {
        SolverContext.GetMovementFactor(factorHandle).ListMixOmenMask = omenMask;
        SolverContext.GetMovementFactor(factorHandle).ListMixToldCursed = toldCursed;
        var factor = SolverContext.GetMovementFactor(factorHandle);
        factor.ListMixEvilTakesAlt = evilTakesAlt;
        factor.ListMixSoundZero = soundZero;
        factor.ListMixWatcher = watcher;
        factor.ListMixBroken = broken;
        factor.ListMixNext = SolverContext.GetMovementFactor(nextHandle);
        factor.ListMixAlt = SolverContext.GetMovementFactor(altHandle);
        factor.ListMixAltScale = altScale;
        SetListNorm(factor.ListMixAlt, factor);
    }

    /// <summary>Score <paramref name="f"/> and everything under it on <paramref name="src"/>'s
    /// scale: the same divisors in BaseScore, the direct profiles and each succession
    /// split's.</summary>
    private static void SetListNorm(CompiledMovementFactor f, CompiledMovementFactor src)
    {
        if (f == null || src == null)
            return;
        f.NormGood = src.NormGood ?? src.ProfGood;
        if (f.ScionSplits.Length == src.ScionSplits.Length)
        {
            for (int k = 0; k < f.ScionSplits.Length; k++)
            {
                f.ScionSplits[k].NormPreGood = src.ScionSplits[k].NormPreGood ?? src.ScionSplits[k].PreGood;
                f.ScionSplits[k].NormPostGood = src.ScionSplits[k].NormPostGood ?? src.ScionSplits[k].PostGood;
            }
        }
        SetListNorm(f.ListMixNext, src);
        SetListNorm(f.ListMixAlt, src);
    }

    public static void AttachGuards(int factorHandle, int[] ints, double[] doubles)
    {
        var factor = SolverContext.GetMovementFactor(factorHandle);
        int k = ints[0];
        var g = new GuardSet { Sources = new int[k], Targets = new int[k], Nights = new int[k], R = new double[k] };
        for (int j = 0; j < k; j++)
        {
            g.Sources[j] = ints[1 + 3 * j];
            g.Targets[j] = ints[2 + 3 * j];
            g.Nights[j] = ints[3 + 3 * j];
            g.R[j] = doubles[j];
        }
        int iPos = 1 + 3 * k;
        if (iPos + 2 < ints.Length)
        {
            g.HasCurse = ints[iPos] != 0;
            g.CurseFrom = ints[iPos + 1];
            g.CurseUntil = ints[iPos + 2];
        }
        int dPos = k;
        int subsets = (1 << k) - 1;
        g.AltDemon = ReadAlt(doubles, ref dPos, subsets, factor.PeopleCount);
        factor.Guards = k > 0 ? g : null;
        if (k == 0)
            return;
        foreach (var split in factor.ScionSplits)
        {
            split.PreGuards = new GuardSet { Sources = g.Sources, Targets = g.Targets, Nights = g.Nights, R = g.R, HasCurse = g.HasCurse, CurseFrom = g.CurseFrom, CurseUntil = g.CurseUntil, AltDemon = ReadAlt(doubles, ref dPos, subsets, factor.PeopleCount) };
            split.PostGuards = new GuardSet { Sources = g.Sources, Targets = g.Targets, Nights = g.Nights, R = g.R, HasCurse = g.HasCurse, CurseFrom = g.CurseFrom, CurseUntil = g.CurseUntil, AltDemon = ReadAlt(doubles, ref dPos, subsets, factor.PeopleCount) };
        }
        // Then the contested sightings' alternatives, person by person (Codex on #243).
        for (int p = 0; p < factor.Contests.Length; p++)
        {
            var ct = factor.Contests[p];
            if (ct == null)
                continue;
            int ms = ct.Alt.Length;
            ct.GuardAlt = new double[ms][];
            for (int m = 0; m < ms; m++)
                ct.GuardAlt[m] = SliceDoubles(doubles, ref dPos, subsets);
            ct.ConvGuardAlt = new double[ct.Sighters.Length][][];
            for (int j = 0; j < ct.Sighters.Length; j++)
            {
                if (ct.ConvAlt.Length <= j || ct.ConvAlt[j] == null)
                    continue;
                ct.ConvGuardAlt[j] = new double[ms][];
                for (int m = 1; m <= ms; m++)
                {
                    if ((m & (1 << j)) == 0)
                        continue;
                    ct.ConvGuardAlt[j][m - 1] = SliceDoubles(doubles, ref dPos, subsets);
                }
            }
        }
    }

    /// <summary>A contest's per-subset values as GuardedMix's alt (one value per row).</summary>
    private static double[][] Column(double[] values)
    {
        var col = new double[values.Length][];
        for (int t = 0; t < values.Length; t++)
            col[t] = new[] { values[t] };
        return col;
    }

    private static double[][] ReadAlt(double[] doubles, ref int dPos, int subsets, int n)
    {
        var alt = new double[subsets][];
        for (int t = 0; t < subsets; t++)
            alt[t] = SliceDoubles(doubles, ref dPos, n);
        return alt;
    }

    /// <summary>The demon profile of person i with the world's holding guards mixed in: the
    /// guards whose Warden and guarded person are both good here (not evil, not the demon,
    /// not the converted).</summary>
    private static double GuardedDemon(GuardSet g, int i, int evilMask, int convIdx, int demonIdx, double usual) =>
        GuardedMix(g, evilMask, convIdx, demonIdx, usual, g.AltDemon, i);

    /// <summary>Good on the guard's night: not evil, not the demon, and not the converted
    /// person while the curse holds (Codex on #243).</summary>
    private static bool GoodOnNight(GuardSet g, int x, int night, int evilMask, int convIdx, int demonIdx)
    {
        if ((evilMask & (1 << x)) != 0 || x == demonIdx)
            return false;
        if (x != convIdx)
            return true;
        int tick = night * 4 + 3;
        return !(g.HasCurse && tick >= g.CurseFrom && tick < g.CurseUntil);
    }

    /// <summary>The mixture over which holding guards held. alt[T - 1][i] is the demon profile
    /// with the attacks of subset T; with i &lt; 0, alt[T - 1][0] (a contest's alternative).</summary>
    private static double GuardedMix(GuardSet g, int evilMask, int convIdx, int demonIdx, double usual, double[][] alt, int i)
    {
        int h = 0;
        for (int j = 0; j < g.Sources.Length; j++)
        {
            if (GoodOnNight(g, g.Sources[j], g.Nights[j], evilMask, convIdx, demonIdx) && GoodOnNight(g, g.Targets[j], g.Nights[j], evilMask, convIdx, demonIdx))
                h |= 1 << j;
        }
        if (h == 0)
            return usual;
        // The Demon visits one door a night: of the holding guards on one night, at most one
        // held (Codex on #243). Each night is a choice of none (1 - the sum of their R) or one
        // of them (its R), the sum scaled to 1 if it goes over; nights are independent.
        double total = 0.0;
        for (int sub = h; ; sub = (sub - 1) & h)
        {
            double w = 1.0;
            bool ok = true;
            for (int j = 0; j < g.Sources.Length && ok; j++)
            {
                if ((h & (1 << j)) == 0)
                    continue;
                bool first = true;   // the first holding guard of its night carries that night's weight
                double sumR = 0.0;
                int chosen = 0;
                for (int q = 0; q < g.Sources.Length; q++)
                {
                    if ((h & (1 << q)) == 0 || g.Nights[q] != g.Nights[j])
                        continue;
                    if (q < j)
                        first = false;
                    sumR += g.R[q];
                    if ((sub & (1 << q)) != 0)
                        chosen++;
                }
                if (chosen > 1)
                {
                    ok = false;
                    break;
                }
                if (!first)
                    continue;
                double scale = sumR > 1.0 ? 1.0 / sumR : 1.0;
                double wNight = Math.Max(0.0, 1.0 - sumR * scale);
                for (int q = 0; q < g.Sources.Length; q++)
                {
                    if ((h & (1 << q)) != 0 && g.Nights[q] == g.Nights[j] && (sub & (1 << q)) != 0)
                        wNight = g.R[q] * scale;
                }
                w *= wNight;
            }
            if (ok)
                total += w * (sub == 0 ? usual : (i >= 0 ? alt[sub - 1][i] : alt[sub - 1][0]));
            if (sub == 0)
                break;
        }
        return total;
    }

    private static double[] SliceDoubles(double[] src, ref int pos, int count)
    {
        if (count <= 0)
        {
            return Array.Empty<double>();
        }
        double[] dst = new double[count];
        Array.Copy(src, pos, dst, 0, count);
        pos += count;
        return dst;
    }

    private static SceneTableData ReadSceneTable(int n, int[] metaInts, ref int iPos, double[] metaDoubles, ref int dPos)
    {
        int victimIdx = metaInts[iPos++];
        int traceCount = metaInts[iPos++];
        bool twoCited = metaInts[iPos++] != 0;
        bool hasCross = metaInts[iPos++] != 0;
        bool hasCrossConv = metaInts[iPos++] != 0;

        var st = new SceneTableData
        {
            VictimIdx = victimIdx,
            SceneTraceCount = traceCount,
            TwoCited = twoCited,
            W1 = SliceDoubles(metaDoubles, ref dPos, n),
            W2 = twoCited ? SliceDoubles(metaDoubles, ref dPos, n) : Array.Empty<double>(),
            CrossGood = hasCross ? SliceDoubles(metaDoubles, ref dPos, n) : Array.Empty<double>(),
            CrossMinion = hasCross ? SliceDoubles(metaDoubles, ref dPos, n) : Array.Empty<double>(),
            CrossConverted = (hasCross && hasCrossConv) ? SliceDoubles(metaDoubles, ref dPos, n) : Array.Empty<double>(),
        };
        return st;
    }

    public static double ScoreWorld(long packedWorld, int factorHandle)
    {
        var factor = SolverContext.GetMovementFactor(factorHandle);
        if (factor == null)
        {
            return 1.0;
        }
        return ScoreMixed(new WorldEntry(packedWorld), factor);
    }

    public static double[] ScoreWorlds(long[] packedWorlds, int factorHandle)
    {
        double[] outScores = new double[packedWorlds.Length];
        var factor = SolverContext.GetMovementFactor(factorHandle);
        if (factor == null)
        {
            Array.Fill(outScores, 1.0);
            return outScores;
        }
        for (int i = 0; i < packedWorlds.Length; i++)
        {
            outScores[i] = ScoreMixed(new WorldEntry(packedWorlds[i]), factor);
        }
        return outScores;
    }

    /// <summary>ScoreWorldCore, mixed over each Night Watch list being sound or broken
    /// (CompiledMovementFactor.ListMixWatcher).</summary>
    private static double ScoreMixed(WorldEntry world, CompiledMovementFactor factor)
    {
        if (factor.ListMixWatcher < 0)
            return ScoreWorldCore(world, factor);
        bool evilTeller = (world.Evil & (1 << factor.ListMixWatcher)) != 0
            || (factor.ListMixToldCursed && world.ConvertedOrMinusOne == factor.ListMixWatcher);
        if (evilTeller && factor.ListMixEvilTakesAlt)
            return factor.ListMixAltScale * ScoreMixed(world, factor.ListMixAlt);
        // A good teller's reading under a fallen omen, in a world where its claimant truly held
        // Ill-Omened, was poisoned: the broken branch outright (its walk still counts there).
        if (!evilTeller && factor.ListMixOmenMask != 0 && world.EffectiveModifier == WorldEntry.ModIllOmened
            && (world.Holders & factor.ListMixOmenMask) != 0)
            return factor.ListMixAltScale * ScoreMixed(world, factor.ListMixAlt);
        double sound = factor.ListMixSoundZero ? 0.0 : ScoreMixed(world, factor.ListMixNext);
        if (evilTeller)
            return sound;
        double b = factor.ListMixBroken;
        // Both on the sound branch's scale: the broken branch divides by the sound branch's
        // good profiles (NormGood, SetListNorm).
        return (1.0 - b) * sound + b * factor.ListMixAltScale * ScoreMixed(world, factor.ListMixAlt);
    }

    [MethodImpl(MethodImplOptions.AggressiveInlining)]
    private static double ScoreWorldCore(WorldEntry world, CompiledMovementFactor factor)
    {
        double share = factor.DayDemonShare;
        if (share <= 0.0)
            return ScoreTyped(world, factor, false);
        // The demon's type is one hidden fact for the whole case: score the world as a walking
        // demon and as a Hexer (out at night like a minion, times the chance its hexes drew
        // these victims), then mix: (1-s)*walk + s*day*hex.
        double walk = ScoreTyped(world, factor, false);
        return (1.0 - share) * walk + share * ScoreDayType(world, factor);
    }

    /// <summary>
    /// The Hexer world: out at night like a minion, times HexFactor. A Scion succession is
    /// mixed branch by branch, 0.5 * direct * hex(direct) + 0.5 * (pre x post) * hex(split),
    /// where in the split branch the kills before the execution are the executed demon's
    /// hexes. Either side may be absent: no movement split keeps direct movement in the
    /// split branch, no hex succession keeps the direct hexes.
    /// </summary>
    private static double ScoreDayType(WorldEntry world, CompiledMovementFactor factor)
    {
        int dIdx = world.DemonOrMinusOne;
        int evil = world.Evil;
        double direct = DirectScore(world, factor, true);
        double hexDirect = HexFactor(world, factor, -1, 0);
        double moveSplit = direct;
        bool haveMove = false;
        int execIdx = -1;
        if (dIdx >= 0)
        {
            foreach (var split in factor.ScionSplits)
            {
                if (SuccessionApplies(split.ExecutedIdx, split.AliveDemonMask, dIdx, evil))
                {
                    moveSplit = SplitScore(world, factor, split, true);
                    haveMove = true;
                    execIdx = split.ExecutedIdx;
                    break;
                }
            }
        }
        double hexSplit = hexDirect;
        bool haveHex = false;
        if (dIdx >= 0)
        {
            foreach (var sc in factor.HexSuccessions)
            {
                // Same executed person as the movement split when there is one.
                if ((execIdx < 0 || sc.ExecutedIdx == execIdx) && SuccessionApplies(sc.ExecutedIdx, sc.AliveDemonMask, dIdx, evil))
                {
                    hexSplit = HexFactor(world, factor, sc.ExecutedIdx, sc.ExecDay);
                    haveHex = true;
                    break;
                }
            }
        }
        if (!haveMove && !haveHex)
            return direct * hexDirect;
        return 0.5 * direct * hexDirect + 0.5 * moveSplit * hexSplit;
    }

    [MethodImpl(MethodImplOptions.AggressiveInlining)]
    private static bool SuccessionApplies(int execIdx, int aliveDemonMask, int dIdx, int evil) =>
        execIdx != dIdx && (evil & (1 << execIdx)) != 0 && (aliveDemonMask & (1 << dIdx)) != 0;

    /// <summary>
    /// For a Hexer world: the product over kills of how likely the hex drew this victim,
    /// relative to a walking demon choosing among all the living good. Per kill:
    /// sum over the victim's places L of P(the demon hexed L that day) * goodAlive / goodRegulars(L),
    /// plus HexFloor for a regular place nobody knows of (an unlearned haunt).
    /// </summary>
    internal static double HexFactor(WorldEntry world, CompiledMovementFactor factor) =>
        HexFactor(world, factor, -1, 0);

    /// <summary>With priorIdx &gt;= 0, kills on nights before priorUntil are scored as priorIdx's
    /// hexes (a Scion succession: the executed demon struck those).</summary>
    internal static double HexFactor(WorldEntry world, CompiledMovementFactor factor, int priorIdx, int priorUntil)
    {
        int curIdx = world.DemonOrMinusOne;
        if (curIdx < 0 || factor.HexKills.Length == 0)
            return 1.0;
        int evil = world.Evil;
        double m = 1.0;
        foreach (var hk in factor.HexKills)
        {
            int dIdx = priorIdx >= 0 && hk.Night < priorUntil ? priorIdx : curIdx;
            int goodAlive = System.Numerics.BitOperations.PopCount((uint)(hk.AliveMask & ~evil));
            double s = 0.0;
            for (int p = 0; p < hk.RegMasks.Length; p++)
            {
                int goodRegs = System.Numerics.BitOperations.PopCount((uint)(hk.RegMasks[p] & ~evil & hk.AliveMask));
                if (goodRegs <= 0)
                    continue;
                s += hk.Shares[p][dIdx] * goodAlive / goodRegs;
            }
            m *= s + factor.HexFloor;
        }
        return m;
    }

    private static double ScoreTyped(WorldEntry world, CompiledMovementFactor factor, bool dayType)
    {
        int dIdx = world.DemonOrMinusOne;
        int evil = world.Evil;
        double direct = DirectScore(world, factor, dayType);
        var splits = factor.ScionSplits;
        for (int k = 0; k < splits.Length; k++)
        {
            var split = splits[k];
            if (dIdx >= 0 && SuccessionApplies(split.ExecutedIdx, split.AliveDemonMask, dIdx, evil))
            {
                return 0.5 * direct + 0.5 * SplitScore(world, factor, split, dayType);
            }
        }
        return direct;
    }

    private static double DirectScore(WorldEntry world, CompiledMovementFactor factor, bool dayType) =>
        BaseScore(
            factor.PeopleCount,
            world.Evil,
            world.ConvertedOrMinusOne,
            world.DemonOrMinusOne,
            factor.HasConvertedProfiles,
            factor.ProfGood,
            factor.ProfMinion,
            dayType ? factor.ProfMinion : factor.ProfDemon,
            factor.ProfConverted,
            factor.SceneTables,
            factor.TracePasserEps,
            factor.TraceUnknownWeight,
            factor.Contests,
            factor.ContestTruth,
            dayType,
            factor.Guards,
            factor.NormGood,
            UnrequitedHolder(world, factor),
            factor.ProfUnrequited);

    /// <summary>The good Unrequited holder whose own profile column applies in this world, or -1
    /// (burdens prototype). The Scion split branches keep the plain good column (an
    /// approximation, as are the sighting contests' and death scenes' good columns).</summary>
    [MethodImpl(MethodImplOptions.AggressiveInlining)]
    internal static int UnrequitedHolder(WorldEntry world, CompiledMovementFactor factor)
    {
        if (factor.ProfUnrequited.Length == 0 || world.EffectiveModifier != WorldEntry.ModUnrequited || world.Holders == 0)
            return -1;
        int h = System.Numerics.BitOperations.TrailingZeroCount((uint)world.Holders);
        if ((world.Evil & (1 << h)) != 0 || world.ConvertedOrMinusOne == h)
            return -1;
        return h;
    }

    /// <summary>The succession branch's movement: before the execution scored with the
    /// executed person as demon, after it with the successor.</summary>
    private static double SplitScore(WorldEntry world, CompiledMovementFactor factor, ScionSplitData split, bool dayType)
    {
        int evil = world.Evil;
        int convIdx = world.ConvertedOrMinusOne;
        double preS = BaseScore(
            factor.PeopleCount, evil, convIdx, split.ExecutedIdx, false,
            split.PreGood, split.PreMinion, dayType ? split.PreMinion : split.PreDemon, Array.Empty<double>(),
            split.PreScenes, factor.TracePasserEps, factor.TraceUnknownWeight, null, 1.0, dayType, split.PreGuards, split.NormPreGood);
        double postS = BaseScore(
            factor.PeopleCount, evil, convIdx, world.DemonOrMinusOne, false,
            split.PostGood, split.PostMinion, dayType ? split.PostMinion : split.PostDemon, Array.Empty<double>(),
            split.PostScenes, factor.TracePasserEps, factor.TraceUnknownWeight, null, 1.0, dayType, split.PostGuards, split.NormPostGood);
        return preS * postS;
    }

    private static double BaseScore(
        int nPeople,
        int evilMask,
        int convIdx,
        int demonIdx,
        bool hasConvertedProfiles,
        double[] profGood,
        double[] profMinion,
        double[] profDemon,
        double[] profConverted,
        SceneTableData[] sceneTables,
        double eps,
        double unkWeight,
        SightingContest[] contests = null,
        double contestTruth = 1.0,
        bool dayType = false,
        GuardSet guards = null,
        double[] normGood = null,
        int unreqIdx = -1,
        double[] profUnreq = null)
    {
        double[] divisor = normGood ?? profGood;
        double result = 1.0;
        for (int i = 0; i < nPeople; i++)
        {
            double pVal;
            int align;   // 0 good, 1 minion, 2 demon, 3 converted: the contest's Alt column
            if (convIdx == i && hasConvertedProfiles)
            {
                pVal = profConverted[i];
                align = 3;
            }
            else if (demonIdx == i)
            {
                pVal = profDemon[i];
                align = dayType ? 1 : 2;
                if (guards != null && !dayType)
                    pVal = GuardedDemon(guards, i, evilMask, convIdx, demonIdx, pVal);
            }
            else if ((evilMask & (1 << i)) != 0)
            {
                pVal = profMinion[i];
                align = 1;
            }
            else
            {
                pVal = i == unreqIdx ? profUnreq![i] : profGood[i];
                align = 0;
            }
            if (contests != null && i < contests.Length && contests[i] != null)
            {
                var ct = contests[i];
                int m = 0;
                int convJ = -1;   // a sighter converted by the curse in this world
                for (int j = 0; j < ct.Sighters.Length; j++)
                {
                    int s = ct.Sighters[j];
                    if ((evilMask & (1 << s)) != 0 || demonIdx == s)
                        m |= 1 << j;
                    else if (convIdx == s && ct.ConvAlt[j] != null)
                        convJ = j;
                }
                if (convJ >= 0)
                {
                    int mc = m | (1 << convJ);
                    double altV = ct.ConvAlt[convJ][mc - 1][align];
                    if (align == 2 && guards != null && ct.ConvGuardAlt != null && ct.ConvGuardAlt[convJ] != null && ct.ConvGuardAlt[convJ][mc - 1] != null)
                        altV = GuardedMix(guards, evilMask, convIdx, demonIdx, altV, Column(ct.ConvGuardAlt[convJ][mc - 1]), -1);
                    pVal = contestTruth * pVal + (1.0 - contestTruth) * ct.ConvC[convJ][mc - 1] * altV;
                }
                else if (m != 0)
                {
                    double altV = ct.Alt[m - 1][align];
                    if (align == 2 && guards != null && ct.GuardAlt != null)
                        altV = GuardedMix(guards, evilMask, convIdx, demonIdx, altV, Column(ct.GuardAlt[m - 1]), -1);
                    pVal = contestTruth * pVal + (1.0 - contestTruth) * ct.C[m - 1] * altV;
                }
            }
            result *= Math.Max(pVal, GdFloor1e30) / Math.Max(divisor[i], GdFloor1e30);
        }
        result *= SceneScore(evilMask, convIdx, demonIdx, sceneTables, eps, unkWeight);
        return result;
    }

    private static double SceneScore(
        int evilMask,
        int convIdx,
        int demonIdx,
        SceneTableData[] sceneTables,
        double eps,
        double unkWeight)
    {
        if (demonIdx < 0 || sceneTables.Length == 0)
        {
            return 1.0;
        }
        double total = 1.0;
        for (int s = 0; s < sceneTables.Length; s++)
        {
            var st = sceneTables[s];
            double w1d = st.W1[demonIdx];
            if (st.TwoCited)
            {
                double w2d = st.W2[demonIdx];
                double ep2 = PasserExpectedWeight(evilMask, convIdx, demonIdx, st, st.W2, eps, unkWeight);
                double ep1 = PasserExpectedWeight(evilMask, convIdx, demonIdx, st, st.W1, eps, unkWeight);
                total *= 0.5 * (w1d * ep2 + w2d * ep1);
            }
            else if (st.SceneTraceCount >= 2)
            {
                double epSingle = PasserExpectedWeight(evilMask, convIdx, demonIdx, st, st.W1, eps, unkWeight);
                total *= 0.5 * w1d + 0.5 * epSingle;
            }
            else
            {
                total *= w1d;
            }
        }
        return total;
    }

    private static double PasserExpectedWeight(
        int evilMask,
        int convIdx,
        int demonIdx,
        SceneTableData st,
        double[] traceWeights,
        double eps,
        double unkWeight)
    {
        double num = eps * unkWeight;
        double den = eps;
        int nPeople = traceWeights.Length;
        bool hasCrossConv = st.CrossConverted.Length == nPeople;
        bool hasCross = st.CrossGood.Length == nPeople;

        for (int j = 0; j < nPeople; j++)
        {
            if (j == demonIdx || j == st.VictimIdx)
            {
                continue;
            }
            double cp = 0.0;
            if (hasCross)
            {
                if (convIdx == j && hasCrossConv)
                {
                    cp = st.CrossConverted[j];
                }
                else if ((evilMask & (1 << j)) != 0)
                {
                    cp = st.CrossMinion[j];
                }
                else
                {
                    cp = st.CrossGood[j];
                }
            }
            if (cp > 0.0)
            {
                num += cp * traceWeights[j];
                den += cp;
            }
        }
        return num / Math.Max(den, 1e-12);
    }
}
