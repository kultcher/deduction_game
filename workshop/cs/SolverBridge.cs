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
        // Slice C1+ will reset SolverContext arena buffers here.
    }

    public static long GetContextEpoch() => _contextEpoch;
    public static long GetVerifyCalls() => _verifyCalls;
    public static long GetVerifyMismatches() => _verifyMismatches;

    // --- Bit-Exact Numerical Helpers (Slice C0 Math Audit) ---

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

    [MethodImpl(MethodImplOptions.AggressiveInlining)]
    public static double GodotExp(double x) => Math.Exp(x);

    [MethodImpl(MethodImplOptions.AggressiveInlining)]
    public static double GodotLog(double x) => Math.Log(x);

    [MethodImpl(MethodImplOptions.AggressiveInlining)]
    public static double GodotPow(double x, double y) => Math.Pow(x, y);

    /// <summary>
    /// Batch-evaluates [op, x, y] triples so GDScript can verify 0-ULP parity
    /// across thousands of representative kernel inputs in one call.
    /// op: 0=round(x), 1=snappedf(x,y), 2=exp(x), 3=log(x), 4=pow(x,y)
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
                _ => double.NaN
            };
        }
        return outBuf;
    }

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
}
