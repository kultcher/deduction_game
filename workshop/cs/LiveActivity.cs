using System;
using System.Collections.Generic;
using System.Numerics;
using System.Runtime.CompilerServices;
using System.Runtime.InteropServices;

namespace Demonologist.Workshop;

/// <summary>
/// Slice C2 1:1 port of workshop/live_activity.gd.
/// Covers:
///   - Night route bitmask enumeration, drop owner Hall matching & Lamplighter counts (routes / _paths)
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

    // Mirrors of sim/tuning.gd Workshop.VIGIL_MISS and WALKER_CLAIM_* (Nov 5).
    public const double VigilMiss = 0.05;
    public const double WalkerClaimGift = 0.95;
    public const double WalkerClaimHome = 0.03;
    public const double WalkerClaimSecret = 0.02;
    public const int KindAlibi = 5;
    public const int KindDropped = 6;
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
    public const int FlagItemDrop = 1 << 7;
    public const int FlagTraceHasFamily = 1 << 8;
    public const int FlagRoleIsNightWalk = 1 << 9;

    // Movement role codes (slot 7):
    public const int MoveRoleEmpty = 0;
    public const int MoveRoleNightwatch = 1;
    public const int MoveRoleWarden = 2;
    public const int MoveRoleLamplighter = 3;
    public const int MoveRoleVeteran = 4;
    public const int MoveRoleMedium = 5;
    public const int MoveRoleOther = 6;
    public const int MoveRoleMonitor = 7;

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
    /// StayHome: BlockMask = 0, LastBlock = -1, IsLampTour = false.
    /// Direct / Detour: BlockMask != 0, LastBlock = destination (0..3), IsLampTour = false.
    /// LampTour (C.BLOCKS.keys()): BlockMask = 0xF, LastBlock = 3 ("hill"), IsLampTour = true.
    /// </summary>
    internal readonly struct PathSpec
    {
        public readonly int BlockMask;
        public readonly int LastBlock;
        public readonly bool IsLampTour;
        public readonly double Weight;

        [MethodImpl(MethodImplOptions.AggressiveInlining)]
        public PathSpec(int blockMask, int lastBlock, bool isLampTour, double weight = 1.0)
        {
            BlockMask = blockMask;
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
        /// Matches C.vigil_sees_path(block, path):
        /// not path.is_empty() and (path.back() == block or path.size() == BLOCKS.size())
        /// </summary>
        [MethodImpl(MethodImplOptions.AggressiveInlining)]
        public bool VigilSees(int blockCode) =>
            LastBlock >= 0 && ((blockCode >= 0 && LastBlock == blockCode) || IsLampTour);

        public static PathSpec StayHome(double weight = 1.0) => new(0, -1, false, weight);

        public static PathSpec LampTour(double weight = 1.0) => new(0xF, BlockHill, true, weight);

        [MethodImpl(MethodImplOptions.AggressiveInlining)]
        public static PathSpec Route(int home, int dest, double weight = 1.0) =>
            new((1 << home) | (1 << dest), dest, false, weight);
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
        public double[] PreGood = Array.Empty<double>();
        public double[] PreMinion = Array.Empty<double>();
        public double[] PreDemon = Array.Empty<double>();
        public double[] PostGood = Array.Empty<double>();
        public double[] PostMinion = Array.Empty<double>();
        public double[] PostDemon = Array.Empty<double>();
        public SceneTableData[] PreScenes = Array.Empty<SceneTableData>();
        public SceneTableData[] PostScenes = Array.Empty<SceneTableData>();
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
        public SceneTableData[] SceneTables = Array.Empty<SceneTableData>();
        public ScionSplitData[] ScionSplits = Array.Empty<ScionSplitData>();
        /// <summary>Share of the script's possible demons that never walk at night (0 = walking only).
        /// ProfDemon is already mixed (it's linear in the one demon's profile); the Scion splits keep
        /// walking profiles and are mixed after multiplying pre and post, over one shared type.</summary>
        public double DayDemonShare;
    }

    [MethodImpl(MethodImplOptions.AggressiveInlining)]
    private static bool IsRelevantCard(int kind, int moveRoleCode) =>
        kind == KindSighting
        || kind == KindEvening
        || kind == KindTrace
        || kind == KindCoverage
        || kind == KindAlibi
        || kind == KindDropped
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
                    if (roleCode == MoveRoleEmpty || roleCode == MoveRoleLamplighter)
                    {
                        candBuf[5] = PathSpec.LampTour();
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
                            if (kind == KindSighting && cardDoubles[c * 2] < 1.0)
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
                            else if (kind == KindAlibi && cardInts[off + 3] == i)
                            {
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
                    if (allLamp && !forcedLamp.Contains(i))
                    {
                        forcedLamp.Add(i);
                    }
                }
            }

            // Collect drops deduplicated by DropFactToken (slot 16) in insertion order
            var dropTokens = new List<int>(4);
            var dropMasks = new List<int>(4);
            for (int c = 0; c < cardCount; c++)
            {
                int off = c * CardStride;
                int flags = cardInts[off + 1];
                if (cardInts[off + 9] != night || (flags & FlagQuoted) != 0)
                {
                    continue;
                }
                int kind = cardInts[off];
                if (kind != KindDropped && (flags & FlagItemDrop) == 0)
                {
                    continue;
                }
                int blk = cardInts[off + 10];
                int matOrSubj = kind == KindDropped ? cardInts[off + 11] : cardInts[off + 3];
                int candidates = 0;
                for (int i = 0; i < n; i++)
                {
                    bool matchesOwner = kind == KindDropped
                        ? (matOrSubj >= 0 && personHomes[i] == matOrSubj)
                        : (i == matOrSubj);
                    if (!matchesOwner)
                    {
                        continue;
                    }
                    var opts = personOptions[i];
                    for (int k = 0; k < opts.Count; k++)
                    {
                        if (opts[k].HasBlock(blk))
                        {
                            candidates |= (1 << i);
                            break;
                        }
                    }
                }

                int fTok = cardInts[off + 16];
                int existingIdx = dropTokens.IndexOf(fTok);
                if (existingIdx >= 0)
                {
                    dropMasks[existingIdx] = candidates;
                }
                else
                {
                    dropTokens.Add(fTok);
                    dropMasks.Add(candidates);
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

            ReadOnlySpan<int> dropSpan = CollectionsMarshal.AsSpan(dropMasks);
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
                if (valid && DropOwners(dropSpan, dropSpan.Length - 1, mask))
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

    private static bool DropOwners(ReadOnlySpan<int> groups, int idx, int available)
    {
        if (idx < 0)
        {
            return true;
        }
        int candidates = groups[idx] & available;
        while (candidates != 0)
        {
            int bit = candidates & -candidates;
            if (DropOwners(groups, idx - 1, available & ~bit))
            {
                return true;
            }
            candidates &= ~bit;
        }
        return false;
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
        double demonDetour)
    {
        double rate = profKind switch
        {
            ProfDemon => night > 0 ? 1.0 : 0.0,
            ProfMinion => 0.25,
            ProfGift => 1.0,
            ProfSecret => 0.55,
            _ => 0.05
        };

        if (profKind == ProfOrdinary)
        {
            for (int c = 0; c < cardCount; c++)
            {
                int off = c * CardStride;
                int flags = cardInts[off + 1];
                if (cardInts[off] == KindSecretClaim && (flags & FlagQuoted) == 0
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
        if (unknownLamp)
        {
            result.Add(PathSpec.LampTour(rate * 0.1));
        }

        double denom = Math.Max(destCount, 1);
        double baseWeight = rate * (unknownLamp ? 0.9 : 1.0) / denom;
        int home = personHomes[personIdx];

        for (int d = 0; d < destCount; d++)
        {
            int dest = destStack[d];
            if (profKind == ProfDemon)
            {
                // Exact demon_routes(home, dest) order: direct first, then via blocks in 0..3 order
                int directMask = (1 << home) | (1 << dest);
                int viaCount = home == dest ? 3 : 2;
                result.Add(new PathSpec(directMask, dest, false, baseWeight * (1.0 - demonDetour)));
                double detourShare = demonDetour / (double)viaCount;
                for (int b = 0; b < BlockCount; b++)
                {
                    if ((directMask & (1 << b)) == 0)
                    {
                        result.Add(new PathSpec(directMask | (1 << b), dest, false, baseWeight * detourShare));
                    }
                }
            }
            else
            {
                PathSpec path = (profKind == ProfGift && roleCode == MoveRoleLamplighter)
                    ? PathSpec.LampTour(baseWeight)
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
        int currentAlign)
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
                if ((cardInts[off + 4] & personBit) != 0)
                {
                    int blk = cardInts[off + 10];
                    bool complete = (flags & FlagComplete) != 0;
                    bool matchesBlock = (blk == -1) || (complete ? path.VigilSees(blk) : path.HasBlock(blk));
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
                if (cardInts[off + 3] == personIdx)
                {
                    if (!quoted)
                    {
                        return !isOut ? 1.0 : 0.0;
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
        double demonDetour,
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
            demonDetour,
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
        double demonDetour,
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
                demonAttackEvents, hasCurse, curseFrom, curseUntil, demonDetour, cardInts, cardDoubles, cardCount);
            outBuf[b + 1] = ComputePersonLikelihoodCore(
                p, AlignMinion, nights, reportsByNight, personHomes, personDeathBeforeNight,
                demonAttackEvents, hasCurse, curseFrom, curseUntil, demonDetour, cardInts, cardDoubles, cardCount);
            outBuf[b + 2] = ComputePersonLikelihoodCore(
                p, AlignDemon, nights, reportsByNight, personHomes, personDeathBeforeNight,
                demonAttackEvents, hasCurse, curseFrom, curseUntil, demonDetour, cardInts, cardDoubles, cardCount);
            if (includeConverted)
            {
                outBuf[b + 3] = ComputePersonLikelihoodCore(
                    p, AlignConverted, nights, reportsByNight, personHomes, personDeathBeforeNight,
                    demonAttackEvents, hasCurse, curseFrom, curseUntil, demonDetour, cardInts, cardDoubles, cardCount);
            }
        }

        return outBuf;
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
        double demonDetour,
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
                    demonAttackEvents, cardInts, cardDoubles, cardCount, demonDetour);
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
                            p *= Observed(nightCards[ci], cardInts, cardDoubles, personIdx, e, path, currentAlign);
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
        double demonDetour,
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
            demonAttackEvents, hasCurse, curseFrom, curseUntil, demonDetour, cardInts, cardDoubles, cardCount);
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
        double demonDetour,
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
                demonAttackEvents, hasCurse, curseFrom, curseUntil, demonDetour, cardInts, cardDoubles, cardCount);
            outBuf[b + 1] = ComputeCrossingCore(
                p, night, AlignMinion, sceneBlockCode, obsArr, personHomes, personDeathBeforeNight,
                demonAttackEvents, hasCurse, curseFrom, curseUntil, demonDetour, cardInts, cardDoubles, cardCount);
            if (includeConverted)
            {
                outBuf[b + 2] = ComputeCrossingCore(
                    p, night, AlignConverted, sceneBlockCode, obsArr, personHomes, personDeathBeforeNight,
                    demonAttackEvents, hasCurse, curseFrom, curseUntil, demonDetour, cardInts, cardDoubles, cardCount);
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
        double demonDetour,
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
                demonAttackEvents, cardInts, cardDoubles, cardCount, demonDetour);
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
                        wP *= Observed(obsArr[oi], cardInts, cardDoubles, personIdx, e, path, currentAlign);
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
        bool hasConv = metaInts[iPos++] != 0;
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

        return SolverContext.RegisterMovementFactor(factor);
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
        return ScoreWorldCore(new WorldEntry(packedWorld), factor);
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
            outScores[i] = ScoreWorldCore(new WorldEntry(packedWorlds[i]), factor);
        }
        return outScores;
    }

    [MethodImpl(MethodImplOptions.AggressiveInlining)]
    private static double ScoreWorldCore(WorldEntry world, CompiledMovementFactor factor)
    {
        int dIdx = world.DemonOrMinusOne;
        int evil = world.Evil;
        int convIdx = world.ConvertedOrMinusOne;

        double direct = BaseScore(
            factor.PeopleCount,
            evil,
            convIdx,
            dIdx,
            factor.HasConvertedProfiles,
            factor.ProfGood,
            factor.ProfMinion,
            factor.ProfDemon,
            factor.ProfConverted,
            factor.SceneTables,
            factor.TracePasserEps,
            factor.TraceUnknownWeight);

        var splits = factor.ScionSplits;
        for (int k = 0; k < splits.Length; k++)
        {
            var split = splits[k];
            int execIdx = split.ExecutedIdx;
            if (dIdx >= 0 && execIdx != dIdx && (evil & (1 << execIdx)) != 0
                && (split.AliveDemonMask & (1 << dIdx)) != 0)
            {
                double preS = BaseScore(
                    factor.PeopleCount,
                    evil,
                    convIdx,
                    execIdx,
                    false,
                    split.PreGood,
                    split.PreMinion,
                    split.PreDemon,
                    Array.Empty<double>(),
                    split.PreScenes,
                    factor.TracePasserEps,
                    factor.TraceUnknownWeight);
                double postS = BaseScore(
                    factor.PeopleCount,
                    evil,
                    convIdx,
                    dIdx,
                    false,
                    split.PostGood,
                    split.PostMinion,
                    split.PostDemon,
                    Array.Empty<double>(),
                    split.PostScenes,
                    factor.TracePasserEps,
                    factor.TraceUnknownWeight);
                double succession = preS * postS;
                double share = factor.DayDemonShare;
                if (share > 0.0)
                {
                    // The demon's type is one hidden fact for the whole case, so mix the
                    // product: (1-s)*Wpre*Wpost + s*Dpre*Dpost, where a day demon moves like a minion.
                    double preDay = BaseScore(
                        factor.PeopleCount, evil, convIdx, execIdx, false,
                        split.PreGood, split.PreMinion, split.PreMinion, Array.Empty<double>(),
                        split.PreScenes, factor.TracePasserEps, factor.TraceUnknownWeight);
                    double postDay = BaseScore(
                        factor.PeopleCount, evil, convIdx, dIdx, false,
                        split.PostGood, split.PostMinion, split.PostMinion, Array.Empty<double>(),
                        split.PostScenes, factor.TracePasserEps, factor.TraceUnknownWeight);
                    succession = (1.0 - share) * succession + share * (preDay * postDay);
                }
                return 0.5 * direct + 0.5 * succession;
            }
        }
        return direct;
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
        double unkWeight)
    {
        double result = 1.0;
        for (int i = 0; i < nPeople; i++)
        {
            double pVal;
            if (convIdx == i && hasConvertedProfiles)
            {
                pVal = profConverted[i];
            }
            else if (demonIdx == i)
            {
                pVal = profDemon[i];
            }
            else if ((evilMask & (1 << i)) != 0)
            {
                pVal = profMinion[i];
            }
            else
            {
                pVal = profGood[i];
            }
            result *= Math.Max(pVal, GdFloor1e30) / Math.Max(profGood[i], GdFloor1e30);
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
