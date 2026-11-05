using System;
using System.Runtime.CompilerServices;
using Godot;

namespace Demonologist.Workshop;

public partial class SolverBridge : RefCounted
{
    public const int ModeGdscript = 0;
    public const int ModeCsharp = 1;
    public const int ModeVerify = 2;

    private static int _mode = ModeGdscript;
    private static long _contextEpoch = 0;
    private static long _verifyCalls = 0;
    private static long _verifyMismatches = 0;

    // Transient buffers for multi-array CompileOwnCounts unpack without extra allocations:
    private static int[] _lastOwnOf = Array.Empty<int>();
    private static byte[] _lastOwnFlatCodes = Array.Empty<byte>();
    private static double[] _lastOwnCounts = Array.Empty<double>();

    public static int GetMode() => _mode;
    public static void SetMode(int mode) => _mode = Math.Clamp(mode, ModeGdscript, ModeVerify);

    public static string GetModeName() => _mode switch
    {
        ModeCsharp => "CSHARP",
        ModeVerify => "VERIFY",
        _ => "GDSCRIPT"
    };

    /// <summary>
    /// Called atomically from workshop/caches.gd :: WorkshopCaches.clear_all()
    /// so C# context state never leaks across Game.new_case() runs.
    /// </summary>
    public static void ClearContext()
    {
        _contextEpoch++;
        _verifyCalls = 0;
        _verifyMismatches = 0;
        _lastOwnOf = Array.Empty<int>();
        _lastOwnFlatCodes = Array.Empty<byte>();
        _lastOwnCounts = Array.Empty<double>();
        SolverContext.Clear();
    }

    public static long GetContextEpoch() => _contextEpoch;
    public static long GetVerifyCalls() => _verifyCalls;
    public static long GetVerifyMismatches() => _verifyMismatches;
    public static int GetCachedUniverseCount() => SolverContext.CachedUniverseCount;
    public static int GetRegisteredHandleCount() => SolverContext.RegisteredHandleCount;
    public static int GetRegisteredMovementFactorCount() => SolverContext.RegisteredMovementFactorCount;
    public static int GetRegisteredCompiledCaseCount() => SolverContext.RegisteredCompiledCaseCount;
    public static int GetRegisteredProgramCount() => SolverContext.RegisteredProgramCount;
    public static int GetRegisteredCircuitCount() => SolverContext.RegisteredCircuitCount;
    public static int GetWorldEntryByteSize() => Unsafe.SizeOf<WorldEntry>();
    public static double GetGdFloor1e30() => SolverContext.GdFloor1e30;

    // --- Handle-Based Universe Arena (Eliminates Per-Call World Repacking) ---

    public static int LookupPackedUniverseHandle(string key) =>
        SolverContext.LookupPackedUniverseHandle(key);

    public static int RegisterPackedUniverse(string key, long[] packedWorlds) =>
        SolverContext.RegisterPackedUniverse(key, packedWorlds);

    public static int RegisterIndexedSubUniverse(string subKey, int baseHandle, int[] indices) =>
        SolverContext.RegisterIndexedSubUniverse(subKey, baseHandle, indices);

    public static void ClearCompiledCases() =>
        SolverContext.ClearCompiledCases();

    // --- Bit-Exact Numerical Helpers (Slice C0 / C0b Math Audit) ---

    [MethodImpl(MethodImplOptions.AggressiveInlining)]
    public static double GodotRound(double x) =>
        Math.Round(x, MidpointRounding.AwayFromZero);

    [MethodImpl(MethodImplOptions.AggressiveInlining)]
    public static double GodotSnappedf(double value, double step) =>
        step != 0.0 ? Math.Floor(value / step + 0.5) * step : value;

    [MethodImpl(MethodImplOptions.AggressiveInlining)]
    public static double GodotLerpf(double from, double to, double weight) =>
        from + (to - from) * weight;

    [MethodImpl(MethodImplOptions.AggressiveInlining)]
    public static double GodotExp(double x) => Math.Exp(x);

    [MethodImpl(MethodImplOptions.AggressiveInlining)]
    public static double GodotLog(double x) => Math.Log(x);

    [MethodImpl(MethodImplOptions.AggressiveInlining)]
    public static double GodotPow(double x, double y) => Math.Pow(x, y);

    public static double[] EvalMathBatch(int[] ops, double[] xs, double[] ys)
    {
        int n = ops.Length;
        double[] outBuf = new double[n];
        for (int i = 0; i < n; i++)
        {
            outBuf[i] = ops[i] switch
            {
                0 => GodotRound(xs[i]),
                1 => GodotSnappedf(xs[i], ys[i]),
                2 => GodotExp(xs[i]),
                3 => GodotLog(xs[i]),
                4 => GodotPow(xs[i], ys[i]),
                5 => GodotLerpf(1.0, xs[i], ys[i]),
                _ => double.NaN
            };
        }
        return outBuf;
    }

    public static double[] EvalLerpfBatch(double[] froms, double[] tos, double[] weights)
    {
        int n = froms.Length;
        double[] outBuf = new double[n];
        for (int i = 0; i < n; i++)
        {
            outBuf[i] = GodotLerpf(froms[i], tos[i], weights[i]);
        }
        return outBuf;
    }

    // --- VERIFY Mode Buffer & Scalar Comparators ---

    public static int VerifyFloat64Buffer(string fnName, double[] gd, double[] cs, double tol = 0.0)
    {
        _verifyCalls++;
        if (gd.Length != cs.Length)
        {
            _verifyMismatches++;
            GD.PushError($"[SolverBridge.VERIFY] {fnName}: length mismatch gd={gd.Length} cs={cs.Length}");
            return 0;
        }
        for (int i = 0; i < gd.Length; i++)
        {
            double a = gd[i];
            double b = cs[i];
            bool match = tol == 0.0
                ? BitConverter.DoubleToInt64Bits(a) == BitConverter.DoubleToInt64Bits(b)
                : Math.Abs(a - b) <= tol;
            if (!match)
            {
                _verifyMismatches++;
                long ulp = Math.Abs(BitConverter.DoubleToInt64Bits(a) - BitConverter.DoubleToInt64Bits(b));
                GD.PushError($"[SolverBridge.VERIFY] {fnName}[{i}]: gd={a:G17} cs={b:G17} diff={Math.Abs(a - b):E3} ulp={ulp}");
                return i;
            }
        }
        return -1;
    }

    public static int VerifyInt64Buffer(string fnName, long[] gd, long[] cs)
    {
        _verifyCalls++;
        if (gd.Length != cs.Length)
        {
            _verifyMismatches++;
            GD.PushError($"[SolverBridge.VERIFY] {fnName}: length mismatch gd={gd.Length} cs={cs.Length}");
            return 0;
        }
        for (int i = 0; i < gd.Length; i++)
        {
            if (gd[i] != cs[i])
            {
                _verifyMismatches++;
                GD.PushError($"[SolverBridge.VERIFY] {fnName}[{i}]: gd={gd[i]} cs={cs[i]}");
                return i;
            }
        }
        return -1;
    }

    public static int VerifyInt32Buffer(string fnName, int[] gd, int[] cs)
    {
        _verifyCalls++;
        if (gd.Length != cs.Length)
        {
            _verifyMismatches++;
            GD.PushError($"[SolverBridge.VERIFY] {fnName}: length mismatch gd={gd.Length} cs={cs.Length}");
            return 0;
        }
        for (int i = 0; i < gd.Length; i++)
        {
            if (gd[i] != cs[i])
            {
                _verifyMismatches++;
                GD.PushError($"[SolverBridge.VERIFY] {fnName}[{i}]: gd={gd[i]} cs={cs[i]}");
                return i;
            }
        }
        return -1;
    }

    public static int VerifyByteBuffer(string fnName, byte[] gd, byte[] cs)
    {
        _verifyCalls++;
        if (gd.Length != cs.Length)
        {
            _verifyMismatches++;
            GD.PushError($"[SolverBridge.VERIFY] {fnName}: length mismatch gd={gd.Length} cs={cs.Length}");
            return 0;
        }
        for (int i = 0; i < gd.Length; i++)
        {
            if (gd[i] != cs[i])
            {
                _verifyMismatches++;
                GD.PushError($"[SolverBridge.VERIFY] {fnName}[{i}]: gd={gd[i]} cs={cs[i]}");
                return i;
            }
        }
        return -1;
    }

    public static bool VerifyScalarBool(string fnName, bool gd, bool cs)
    {
        _verifyCalls++;
        if (gd != cs)
        {
            _verifyMismatches++;
            GD.PushError($"[SolverBridge.VERIFY] {fnName}: gd={gd} cs={cs}");
            return false;
        }
        return true;
    }

    public static bool VerifyScalarInt64(string fnName, long gd, long cs)
    {
        _verifyCalls++;
        if (gd != cs)
        {
            _verifyMismatches++;
            GD.PushError($"[SolverBridge.VERIFY] {fnName}: gd={gd} cs={cs}");
            return false;
        }
        return true;
    }

    public static bool VerifyScalarFloat64(string fnName, double gd, double cs, double tol = 0.0)
    {
        _verifyCalls++;
        bool match = tol == 0.0
            ? BitConverter.DoubleToInt64Bits(gd) == BitConverter.DoubleToInt64Bits(cs)
            : Math.Abs(gd - cs) <= tol;
        if (!match)
        {
            _verifyMismatches++;
            long ulp = Math.Abs(BitConverter.DoubleToInt64Bits(gd) - BitConverter.DoubleToInt64Bits(cs));
            GD.PushError($"[SolverBridge.VERIFY] {fnName}: gd={gd:G17} cs={cs:G17} ulp={ulp}");
            return false;
        }
        return true;
    }

    // --- Slice C1: WorldDomain Entry Points ---

    public static long[] DomainEnumerateWorlds(int n, int evilCount, string[] modifiers, bool identities) =>
        WorldDomainKernel.EnumerateWorlds(n, evilCount, modifiers, identities);

    public static long DomainWorldKey(int n, long packedWorld) =>
        WorldDomainKernel.ComputeKey(n, new WorldEntry(packedWorld));

    public static long[] DomainWorldKeys(int n, long[] packedWorlds) =>
        WorldDomainKernel.ComputeKeys(n, packedWorlds);

    public static bool DomainClaimsCompatible(
        int[] kindCodes,
        byte[] flags,
        string[] sources,
        string[] roles,
        bool hasSelf,
        string selfId,
        bool hasOwnRole,
        string ownRole) =>
        WorldDomainKernel.ClaimsCompatible(kindCodes, flags, sources, roles, hasSelf, selfId, hasOwnRole, ownRole);

    public static bool DomainHealthy(long packedWorld, int personIndex) =>
        WorldDomainKernel.Healthy(packedWorld, personIndex);

    public static byte[] DomainHealthyTable(long[] packedWorlds, int personIndex) =>
        WorldDomainKernel.HealthyTable(packedWorlds, personIndex);

    public static bool DomainGiftTime(
        string roleId,
        string align,
        bool eveningOrNight,
        bool isDay,
        bool firstNight,
        int minGiftDay,
        int obsDay,
        string obsPhase) =>
        WorldDomainKernel.GiftTime(roleId, align, eveningOrNight, isDay, firstNight, minGiftDay, obsDay, obsPhase);

    public static bool DomainRumor(
        long packedWorld,
        string worldModifier,
        int sourceIdx,
        string secret,
        int pairMask,
        bool hasAnsPos,
        int ansMask) =>
        WorldDomainKernel.Rumor(packedWorld, worldModifier, sourceIdx, secret, pairMask, hasAnsPos, ansMask);

    // --- Slice C1: RoleConstraints Entry Points (Direct & Handle-Backed) ---

    public static long RoleCoarseMask(int people, long packedWorld, bool seer, int mediums, int walkers) =>
        RoleConstraintsKernel.CoarseMask(people, new WorldEntry(packedWorld), seer, mediums, walkers);

    public static long[] RoleCoarseMasks(int people, long[] packedWorlds, bool seer, int mediums, int walkers) =>
        RoleConstraintsKernel.CoarseMasks(people, packedWorlds, seer, mediums, walkers);

    public static long[] RoleCoarseMasksByHandle(
        int people,
        int universeHandle,
        int[] subsetIndices,
        long[] fallbackWorlds,
        bool seer,
        int mediums,
        int walkers) =>
        RoleConstraintsKernel.CoarseMasks(
            people, SolverContext.ResolveWorlds(universeHandle, subsetIndices, fallbackWorlds), seer, mediums, walkers);

    public static double RoleSeerRhWeight(int candidatesMask, int demon, int marked, int[] readingInts) =>
        RoleConstraintsKernel.SeerRhWeight(candidatesMask, demon, marked, readingInts);

    public static double[] RoleFitsWeights(
        long[] packedWorlds,
        int[] headerInts,
        int[] publicRolesInts,
        int[] forcedLampIndices,
        int[] cardInts) =>
        RoleConstraintsKernel.FitsWeights(packedWorlds, headerInts, publicRolesInts, forcedLampIndices, cardInts);

    public static double[] RoleFitsWeightsByHandle(
        int universeHandle,
        int[] subsetIndices,
        long[] fallbackWorlds,
        int[] headerInts,
        int[] publicRolesInts,
        int[] forcedLampIndices,
        int[] cardInts) =>
        RoleConstraintsKernel.FitsWeights(
            SolverContext.ResolveWorlds(universeHandle, subsetIndices, fallbackWorlds),
            headerInts, publicRolesInts, forcedLampIndices, cardInts);

    public static byte[] RoleFitsTable(
        long[] packedWorlds,
        int[] headerInts,
        int[] publicRolesInts,
        int[] forcedLampIndices,
        int[] cardInts) =>
        RoleConstraintsKernel.FitsTable(packedWorlds, headerInts, publicRolesInts, forcedLampIndices, cardInts);

    public static double[] RoleBluffWeightsSimple(long[] packedWorlds, int[] declaredBits, double bluffWeight) =>
        RoleConstraintsKernel.BluffWeightsSimple(packedWorlds, declaredBits, bluffWeight);

    public static double[] RoleBluffWeightsSimpleByHandle(
        int universeHandle,
        int[] subsetIndices,
        long[] fallbackWorlds,
        int[] declaredBits,
        double bluffWeight) =>
        RoleConstraintsKernel.BluffWeightsSimple(
            SolverContext.ResolveWorlds(universeHandle, subsetIndices, fallbackWorlds), declaredBits, bluffWeight);

    public static double[] RoleBluffWeightsTemporal(
        long[] packedWorlds,
        int[] whoIndices,
        double[] hearingWeights,
        int[] stmtTicks,
        bool hasCurse,
        int curseFrom,
        int curseUntil,
        double bluffWeight) =>
        RoleConstraintsKernel.BluffWeightsTemporal(
            packedWorlds, whoIndices, hearingWeights, stmtTicks, hasCurse, curseFrom, curseUntil, bluffWeight);

    public static double[] RoleBluffWeightsTemporalByHandle(
        int universeHandle,
        int[] subsetIndices,
        long[] fallbackWorlds,
        int[] whoIndices,
        double[] hearingWeights,
        int[] stmtTicks,
        bool hasCurse,
        int curseFrom,
        int curseUntil,
        double bluffWeight) =>
        RoleConstraintsKernel.BluffWeightsTemporal(
            SolverContext.ResolveWorlds(universeHandle, subsetIndices, fallbackWorlds),
            whoIndices, hearingWeights, stmtTicks, hasCurse, curseFrom, curseUntil, bluffWeight);

    // --- Slice C2: LiveActivity Entry Points ---

    public static int[] LiveEvaluateRoutes(
        int[] headerInts,
        int[] personHomes,
        int[] personDeathBeforeNight,
        int[] ownOutingsInts,
        int[] cardInts,
        double[] cardDoubles) =>
        LiveActivityKernel.EvaluateRoutes(
            headerInts, personHomes, personDeathBeforeNight, ownOutingsInts, cardInts, cardDoubles);

    public static double LiveSingleLikelihood(
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
        double[] cardDoubles) =>
        LiveActivityKernel.ComputeSingleLikelihood(
            personIdx, alignCode, personHomes, personDeathBeforeNight, demonAttackEvents,
            hasCurse, curseFrom, curseUntil, demonDetour, cardInts, cardDoubles);

    public static double[] LiveAllProfiles(
        bool includeConverted,
        int[] personHomes,
        int[] personDeathBeforeNight,
        int[] demonAttackEvents,
        bool hasCurse,
        int curseFrom,
        int curseUntil,
        double demonDetour,
        int[] cardInts,
        double[] cardDoubles) =>
        LiveActivityKernel.ComputeAllProfiles(
            includeConverted, personHomes, personDeathBeforeNight, demonAttackEvents,
            hasCurse, curseFrom, curseUntil, demonDetour, cardInts, cardDoubles);

    public static double LiveCrossingProbability(
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
        double[] cardDoubles) =>
        LiveActivityKernel.ComputeCrossingProbability(
            personIdx, night, alignCode, sceneBlockCode, personHomes, personDeathBeforeNight,
            demonAttackEvents, hasCurse, curseFrom, curseUntil, demonDetour, cardInts, cardDoubles);

    public static double[] LiveSceneCrossings(
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
        double[] cardDoubles) =>
        LiveActivityKernel.ComputeSceneCrossings(
            night, sceneBlockCode, includeConverted, personHomes, personDeathBeforeNight,
            demonAttackEvents, hasCurse, curseFrom, curseUntil, demonDetour, cardInts, cardDoubles);

    public static int LiveRegisterMovementFactor(int[] metaInts, double[] metaDoubles) =>
        LiveActivityKernel.RegisterCompiledFactor(metaInts, metaDoubles);

    public static double LiveScoreWorld(long packedWorld, int factorHandle) =>
        LiveActivityKernel.ScoreWorld(packedWorld, factorHandle);

    public static double[] LiveScoreWorldsByHandle(
        int universeHandle,
        int[] subsetIndices,
        long[] fallbackWorlds,
        int factorHandle) =>
        LiveActivityKernel.ScoreWorlds(
            SolverContext.ResolveWorlds(universeHandle, subsetIndices, fallbackWorlds), factorHandle);

    // --- Slice C3: SolverKernel Entry Points ---

    public static long[] SolverWorldBits(int universeHandle, long[] fallbackWorlds) =>
        SolverKernel.ComputeWorldBitsFlat(universeHandle, fallbackWorlds);

    public static int[] SolverSigGroups(
        int universeHandle,
        long[] fallbackWorlds,
        int nPeople,
        bool isLive) =>
        SolverKernel.ComputeSigGroupsFlat(universeHandle, fallbackWorlds, nPeople, isLive);

    public static byte[] SolverValidTable(
        int universeHandle,
        long[] fallbackWorlds,
        int nPeople,
        bool isLive,
        int cardKindCode,
        bool testimonyOnly,
        int sourceIdx,
        bool giftTimeAndAliveOk,
        bool convEvilAtCheck) =>
        SolverKernel.EvaluateValidTable(
            universeHandle, fallbackWorlds, nPeople, isLive, cardKindCode,
            testimonyOnly, sourceIdx, giftTimeAndAliveOk, convEvilAtCheck);

    public static byte[] SolverReportTable(
        int universeHandle,
        long[] fallbackWorlds,
        int nPeople,
        bool isLive,
        int[] specInts,
        int[] reqMarkedIndices,
        int[] chosenBlockMasks,
        int[] allBlockMasks) =>
        SolverKernel.EvaluateReportTable(
            universeHandle, fallbackWorlds, nPeople, isLive, specInts,
            reqMarkedIndices, chosenBlockMasks, allBlockMasks);

    public static int[] SolverFilterCandidates(
        int universeHandle,
        long[] fallbackWorlds,
        int tableCount,
        byte[] flatTables,
        int mustBeGoodMask,
        int mustBeEvilMask,
        int markedReq,
        int[] posSpecs,
        int[] timedGoodSpecs) =>
        SolverKernel.FilterSolveCandidates(
            universeHandle, fallbackWorlds, tableCount, flatTables,
            mustBeGoodMask, mustBeEvilMask, markedReq, posSpecs, timedGoodSpecs);

    public static int[] SolverFilterPositions(
        int universeHandle,
        int[] subsetIndices,
        long[] fallbackWorlds,
        int mustBeGoodMask,
        int mustBeEvilMask,
        int markedReq,
        int[] posSpecs) =>
        SolverKernel.FilterPositionsSubset(
            universeHandle, subsetIndices, fallbackWorlds,
            mustBeGoodMask, mustBeEvilMask, markedReq, posSpecs);

    public static int[] ReadingFraction(
        int universeHandle,
        int[] refIndices,
        long[] fallbackWorlds,
        int nPeople,
        int sourceIdx,
        bool convAtEpoch,
        byte[] reportTable,
        byte[] roleTable,
        bool compatible) =>
        SolverKernel.ReadingFraction(
            universeHandle, refIndices, fallbackWorlds, nPeople, sourceIdx,
            convAtEpoch, reportTable, roleTable, compatible);

    public static int[] SolverFixtureMovement(
        int nPeople,
        int ownPersonIdx,
        int[] nightSpecs,
        int[] cardSpecs) =>
        SolverKernel.EvaluateFixtureMovement(nPeople, ownPersonIdx, nightSpecs, cardSpecs);

    public static byte[] SolverQuestionTable(
        int universeHandle,
        long[] fallbackWorlds,
        byte[] accepted,
        byte[] roles,
        bool isMisled,
        bool isSeerYes,
        int pairMask,
        bool pairHasMinusOne,
        int sourceIdx,
        bool convEvilAtObs) =>
        SolverKernel.ComputeQuestionTable(
            universeHandle, fallbackWorlds, accepted, roles,
            isMisled, isSeerYes, pairMask, pairHasMinusOne, sourceIdx, convEvilAtObs);

    public static byte[] SolverPremiseMask(
        int universeHandle,
        long[] fallbackWorlds,
        bool isLive,
        int conclTypeCode,
        int targetIdx,
        int secretModCode,
        bool convEvilAtConcl) =>
        SolverKernel.ComputePremiseMask(
            universeHandle, fallbackWorlds, isLive, conclTypeCode,
            targetIdx, secretModCode, convEvilAtConcl);

    public static int SolverUnresolvedMask(long[] packedWorlds, int nPeople) =>
        SolverKernel.ComputeUnresolvedMask(packedWorlds, nPeople);

    // --- Slice C3: CaseEvalKernel Entry Points ---

    public static int[] CaseEvalTeamIndex(
        int universeHandle,
        long[] fallbackWorlds,
        bool currentEpochConvEvil) =>
        CaseEvalKernel.BuildTeamIndexFlat(universeHandle, fallbackWorlds, currentEpochConvEvil);

    public static int CaseEvalCompile(
        int universeHandle,
        long[] fallbackWorlds,
        int[] headerInts,
        byte[] dead,
        byte[] premise,
        byte[] flatTables,
        byte[] flatValids,
        double[] q,
        int[] testTargetSpecs,
        int[] moveFactorSpecs,
        double[] moveFactorDoubles) =>
        CaseEvalKernel.CompileEquivalenceClasses(
            universeHandle, fallbackWorlds, headerInts, dead, premise,
            flatTables, flatValids, q, testTargetSpecs, moveFactorSpecs, moveFactorDoubles);

    public static int[] CaseEvalGetCompiledInts(int ccHandle) =>
        CaseEvalKernel.GetCompiledCaseInts(ccHandle);

    public static byte[] CaseEvalGetCompiledBytes(int ccHandle) =>
        CaseEvalKernel.GetCompiledCaseBytes(ccHandle);

    public static double[] CaseEvalGetCompiledDoubles(int ccHandle) =>
        CaseEvalKernel.GetCompiledCaseDoubles(ccHandle);

    public static int CaseEvalCompileOwnCounts(
        int ccHandle,
        int[] fallbackClassOf,
        int nc,
        int kOwn,
        byte[] flatTables,
        byte[] flatValids)
    {
        var (ns, of, flatCodes, counts) = CaseEvalKernel.CompileOwnCounts(
            ccHandle, fallbackClassOf, nc, kOwn, flatTables, flatValids);
        _lastOwnOf = of;
        _lastOwnFlatCodes = flatCodes;
        _lastOwnCounts = counts;
        return ns;
    }

    public static int[] CaseEvalGetLastOwnOf() => _lastOwnOf;
    public static byte[] CaseEvalGetLastOwnFlatCodes() => _lastOwnFlatCodes;
    public static double[] CaseEvalGetLastOwnCounts() => _lastOwnCounts;

    public static double[] CaseEvalTeamPrior(
        int universeHandle,
        long[] fallbackWorlds,
        bool currentEpochConvEvil,
        double[] rawSusp,
        double[] npcTrust,
        int goodMask,
        double priorK) =>
        CaseEvalKernel.ComputeTeamPrior(
            universeHandle, fallbackWorlds, currentEpochConvEvil, rawSusp, npcTrust, goodMask, priorK);

    public static double[] CaseEvalClassLike(
        int ccHandle,
        int ncFallback,
        int kFallback,
        byte[] fallbackStates,
        byte[] fallbackDead,
        double[] fallbackQ,
        double[] errs,
        int skip) =>
        CaseEvalKernel.ComputeClassLike(
            ccHandle, ncFallback, kFallback, fallbackStates, fallbackDead, fallbackQ, errs, skip);

    public static double[] CaseEvalEvaluatePosterior(
        int ccHandle,
        int universeHandle,
        long[] fallbackWorlds,
        int[] evalInts,
        double[] tuningDoubles,
        double[] teamPrior,
        double[] fits,
        double[] fitsBefore,
        double[] caseErrs,
        double[] ownErrs,
        double[] ownQs,
        double[] counts,
        int[] ownOf,
        byte[] flatOwnCodes,
        double[] routeCredits,
        double[] testLog2Ratios,
        double biasFactor) =>
        CaseEvalKernel.EvaluatePosterior(
            ccHandle, universeHandle, fallbackWorlds, evalInts, tuningDoubles,
            teamPrior, fits, fitsBefore, caseErrs, ownErrs, ownQs,
            counts, ownOf, flatOwnCodes, routeCredits, testLog2Ratios, biasFactor);

    // --- Slice C3: ChannelSumProduct & FactoredChannels Entry Points ---

    public static int[] SumProductCompile(int nInputs, int[] scopeOffsets, int[] scopeVars) =>
        ChannelSumProductKernel.CompileProgram(nInputs, scopeOffsets, scopeVars);

    public static double[] SumProductEvaluate(
        int programHandle,
        int[] fallbackFlatProgram,
        int[] valOffsets,
        double[] flatValues,
        bool marginals) =>
        ChannelSumProductKernel.EvaluateProgram(
            programHandle, fallbackFlatProgram, valOffsets, flatValues, marginals);

    public static int[] SumProductCircuit(
        int programHandle,
        int[] fallbackFlatProgram,
        byte[] constFlags,
        int[] constOffsets,
        double[] flatConsts) =>
        ChannelSumProductKernel.CompileCircuit(
            programHandle, fallbackFlatProgram, constFlags, constOffsets, flatConsts);

    public static double[] SumProductRun(
        int circuitHandle,
        int[] fallbackFlatCircuit,
        int[] valOffsets,
        double[] flatValues,
        bool marginals) =>
        ChannelSumProductKernel.RunCircuit(
            circuitHandle, fallbackFlatCircuit, valOffsets, flatValues, marginals);

    public static double[] FactoredAssessBatch(
        int universeHandle,
        long[] fallbackWorlds,
        int nPeople,
        int[] representatives,
        double[] multiplicity,
        int circuitHandle,
        int[] fallbackFlatCircuit,
        int[] factorSpecs,
        double[] factorDoubles,
        int tableStride,
        byte[] flatByteTables,
        int[] publicSpecs,
        double[] publicRatios,
        long[] condRowSigs,
        int[] condRowOffsets,
        double[] flatCondRows,
        int[] markerFactorIndices,
        int[] markerAdjRows) =>
        ChannelSumProductKernel.AssessFactoredBatch(
            universeHandle, fallbackWorlds, nPeople, representatives, multiplicity,
            circuitHandle, fallbackFlatCircuit, factorSpecs, factorDoubles,
            tableStride, flatByteTables, publicSpecs, publicRatios,
            condRowSigs, condRowOffsets, flatCondRows, markerFactorIndices, markerAdjRows);
}
