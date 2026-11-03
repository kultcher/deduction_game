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
        SolverContext.Clear();
    }

    public static long GetContextEpoch() => _contextEpoch;
    public static long GetVerifyCalls() => _verifyCalls;
    public static long GetVerifyMismatches() => _verifyMismatches;
    public static int GetCachedUniverseCount() => SolverContext.CachedUniverseCount;
    public static int GetWorldEntryByteSize() => Unsafe.SizeOf<WorldEntry>();

    // --- Bit-Exact Numerical Helpers (Slice C0 / C0b Math Audit) ---

    /// <summary>
    /// Matches Godot's global round(x): rounds half-way cases away from zero
    /// (unlike Math.Round's default ToEven / banker's rounding).
    /// </summary>
    [MethodImpl(MethodImplOptions.AggressiveInlining)]
    public static double GodotRound(double x) =>
        Math.Round(x, MidpointRounding.AwayFromZero);

    /// <summary>
    /// Matches Godot's Math::snapped(p_value, p_step):
    /// floor(p_value / p_step + 0.5) * p_step when step != 0.
    /// </summary>
    [MethodImpl(MethodImplOptions.AggressiveInlining)]
    public static double GodotSnappedf(double value, double step) =>
        step != 0.0 ? Math.Floor(value / step + 0.5) * step : value;

    /// <summary>
    /// Matches Godot's Math::lerp(p_from, p_to, p_weight) / GDScript lerpf:
    /// p_from + (p_to - p_from) * p_weight in 64-bit IEEE-754 double.
    /// </summary>
    [MethodImpl(MethodImplOptions.AggressiveInlining)]
    public static double GodotLerpf(double from, double to, double weight) =>
        from + (to - from) * weight;

    [MethodImpl(MethodImplOptions.AggressiveInlining)]
    public static double GodotExp(double x) => Math.Exp(x);

    [MethodImpl(MethodImplOptions.AggressiveInlining)]
    public static double GodotLog(double x) => Math.Log(x);

    [MethodImpl(MethodImplOptions.AggressiveInlining)]
    public static double GodotPow(double x, double y) => Math.Pow(x, y);

    /// <summary>
    /// Batch-evaluates [op, x, y] triples so GDScript can verify 0-ULP parity
    /// across thousands of representative kernel inputs in one call.
    /// op: 0=round(x), 1=snappedf(x,y), 2=exp(x), 3=log(x), 4=pow(x,y), 5=lerpf(1.0,x,y)
    /// </summary>
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

    /// <summary>
    /// Compares two double arrays bit-for-bit (or within tol) for VERIFY mode.
    /// Returns the index of the first mismatch, or -1 if identical.
    /// </summary>
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

    // --- Slice C1: RoleConstraints Entry Points ---

    public static long RoleCoarseMask(int people, long packedWorld, bool seer, int mediums, int walkers) =>
        RoleConstraintsKernel.CoarseMask(people, new WorldEntry(packedWorld), seer, mediums, walkers);

    public static long[] RoleCoarseMasks(int people, long[] packedWorlds, bool seer, int mediums, int walkers) =>
        RoleConstraintsKernel.CoarseMasks(people, packedWorlds, seer, mediums, walkers);

    public static double RoleSeerRhWeight(int candidatesMask, int demon, int marked, int[] readingInts) =>
        RoleConstraintsKernel.SeerRhWeight(candidatesMask, demon, marked, readingInts);

    public static double[] RoleFitsWeights(
        long[] packedWorlds,
        int[] headerInts,
        int[] publicRolesInts,
        int[] forcedLampIndices,
        int[] cardInts) =>
        RoleConstraintsKernel.FitsWeights(packedWorlds, headerInts, publicRolesInts, forcedLampIndices, cardInts);

    public static byte[] RoleFitsTable(
        long[] packedWorlds,
        int[] headerInts,
        int[] publicRolesInts,
        int[] forcedLampIndices,
        int[] cardInts) =>
        RoleConstraintsKernel.FitsTable(packedWorlds, headerInts, publicRolesInts, forcedLampIndices, cardInts);

    public static double[] RoleBluffWeightsSimple(long[] packedWorlds, int[] declaredBits, double bluffWeight) =>
        RoleConstraintsKernel.BluffWeightsSimple(packedWorlds, declaredBits, bluffWeight);

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
}
