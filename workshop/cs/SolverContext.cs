using System;
using System.Collections.Generic;
using System.Runtime.CompilerServices;
using System.Runtime.InteropServices;

namespace Demonologist.Workshop;

/// <summary>
/// Compact 8-byte representation of a candidate alignment/modifier world.
/// Bit layout inside Raw (58 bits used, bits 58..63 always 0):
///   bits  0..17 (18 bits): Evil bitmask (supports up to 18 people)
///   bits 18..35 (18 bits): Holders bitmask (supports up to 18 people)
///   bits 36..41 ( 6 bits): Marked + 2 (-1 = none, 0..17 = index)
///   bits 42..45 ( 4 bits): ModifierCode + 2 (-2 = absent/default "marked", -1 = custom,
///                          0 = "delusional", 1 = "marked", 2 = "lovers", 3 = "sleepwalker")
///   bits 46..51 ( 6 bits): DemonRaw + 2 (-2 = key absent, -1 = explicit -1, 0..17 = index)
///   bits 52..57 ( 6 bits): ConvertedRaw + 2 (-2 = key absent, -1 = explicit -1, 0..17 = index)
/// </summary>
[StructLayout(LayoutKind.Sequential, Pack = 1)]
public readonly struct WorldEntry : IEquatable<WorldEntry>
{
    public const int ModAbsentDefaultMarked = -2;
    public const int ModUnknownExplicit = -1;
    public const int ModDelusional = 0;
    public const int ModMarked = 1;
    public const int ModLovers = 2;
    public const int ModSleepwalker = 3;

    public readonly long Raw;

    [MethodImpl(MethodImplOptions.AggressiveInlining)]
    public WorldEntry(long raw)
    {
        Raw = raw;
    }

    public int Evil
    {
        [MethodImpl(MethodImplOptions.AggressiveInlining)]
        get => (int)(Raw & 0x3FFFFL);
    }

    public int Holders
    {
        [MethodImpl(MethodImplOptions.AggressiveInlining)]
        get => (int)((Raw >> 18) & 0x3FFFFL);
    }

    public int Marked
    {
        [MethodImpl(MethodImplOptions.AggressiveInlining)]
        get => (int)((Raw >> 36) & 0x3FL) - 2;
    }

    public int ModifierCode
    {
        [MethodImpl(MethodImplOptions.AggressiveInlining)]
        get => (int)((Raw >> 42) & 0xFL) - 2;
    }

    public int EffectiveModifier
    {
        [MethodImpl(MethodImplOptions.AggressiveInlining)]
        get
        {
            int code = ModifierCode;
            return code == ModAbsentDefaultMarked ? ModMarked : code;
        }
    }

    public int SecretModIndex
    {
        [MethodImpl(MethodImplOptions.AggressiveInlining)]
        get
        {
            int code = ModifierCode;
            return code < 0 ? -1 : code;
        }
    }

    public int DemonRaw
    {
        [MethodImpl(MethodImplOptions.AggressiveInlining)]
        get => (int)((Raw >> 46) & 0x3FL) - 2;
    }

    public bool HasDemon
    {
        [MethodImpl(MethodImplOptions.AggressiveInlining)]
        get => DemonRaw != -2;
    }

    public int DemonOrMinusOne
    {
        [MethodImpl(MethodImplOptions.AggressiveInlining)]
        get
        {
            int d = DemonRaw;
            return d < 0 ? -1 : d;
        }
    }

    public int ConvertedRaw
    {
        [MethodImpl(MethodImplOptions.AggressiveInlining)]
        get => (int)((Raw >> 52) & 0x3FL) - 2;
    }

    public bool HasConverted
    {
        [MethodImpl(MethodImplOptions.AggressiveInlining)]
        get => ConvertedRaw != -2;
    }

    public int ConvertedOrMinusOne
    {
        [MethodImpl(MethodImplOptions.AggressiveInlining)]
        get
        {
            int c = ConvertedRaw;
            return c < 0 ? -1 : c;
        }
    }

    [MethodImpl(MethodImplOptions.AggressiveInlining)]
    public static WorldEntry Pack(int evil, int holders, int marked, int modCode, int demonRaw, int convertedRaw)
    {
        long raw = ((long)(evil & 0x3FFFF))
                 | ((long)(holders & 0x3FFFF) << 18)
                 | ((long)((marked + 2) & 0x3F) << 36)
                 | ((long)((modCode + 2) & 0xF) << 42)
                 | ((long)((demonRaw + 2) & 0x3F) << 46)
                 | ((long)((convertedRaw + 2) & 0x3F) << 52);
        return new WorldEntry(raw);
    }

    [MethodImpl(MethodImplOptions.AggressiveInlining)]
    public WorldEntry WithDemon(int demonIdx) =>
        Pack(Evil, Holders, Marked, ModifierCode, demonIdx, ConvertedRaw);

    [MethodImpl(MethodImplOptions.AggressiveInlining)]
    public WorldEntry WithConverted(int convertedIdx) =>
        Pack(Evil, Holders, Marked, ModifierCode, DemonRaw, convertedIdx);

    [MethodImpl(MethodImplOptions.AggressiveInlining)]
    public static int ParseModifierCode(string modifier) => modifier switch
    {
        "delusional" => ModDelusional,
        "marked" => ModMarked,
        "lovers" => ModLovers,
        "sleepwalker" => ModSleepwalker,
        _ => ModUnknownExplicit
    };

    public bool Equals(WorldEntry other) => Raw == other.Raw;
    public override bool Equals(object? obj) => obj is WorldEntry other && Raw == other.Raw;
    public override int GetHashCode() => Raw.GetHashCode();
}

/// <summary>
/// Central C# solver arena and memoization context. Cleared atomically from
/// workshop/caches.gd :: WorkshopCaches.clear_all() -> SolverBridge.ClearContext().
/// </summary>
internal static class SolverContext
{
    private static readonly Dictionary<string, long[]> UniverseStride3Cache = new(16);
    private static readonly List<long[]> PackedUniverses = new(64);
    private static readonly Dictionary<string, int> PackedUniverseByKey = new(64);
    private static readonly List<LiveActivityKernel.CompiledMovementFactor> MovementFactors = new(64);

    public static void Clear()
    {
        UniverseStride3Cache.Clear();
        PackedUniverses.Clear();
        PackedUniverseByKey.Clear();
        MovementFactors.Clear();
    }

    public static int CachedUniverseCount => UniverseStride3Cache.Count;
    public static int RegisteredHandleCount => PackedUniverses.Count;
    public static int RegisteredMovementFactorCount => MovementFactors.Count;

    public static bool TryGetUniverse(string cacheKey, out long[] stride3) =>
        UniverseStride3Cache.TryGetValue(cacheKey, out stride3!);

    public static void StoreUniverse(string cacheKey, long[] stride3)
    {
        if (UniverseStride3Cache.Count >= 16)
        {
            UniverseStride3Cache.Clear();
        }
        UniverseStride3Cache[cacheKey] = stride3;
    }

    public static int LookupPackedUniverseHandle(string key) =>
        PackedUniverseByKey.TryGetValue(key, out int handle) ? handle : -1;

    public static int RegisterPackedUniverse(string key, long[] packedWorlds)
    {
        if (!string.IsNullOrEmpty(key) && PackedUniverseByKey.TryGetValue(key, out int existing))
        {
            return existing;
        }
        int handle = PackedUniverses.Count;
        PackedUniverses.Add(packedWorlds);
        if (!string.IsNullOrEmpty(key))
        {
            PackedUniverseByKey[key] = handle;
        }
        return handle;
    }

    public static int RegisterIndexedSubUniverse(string subKey, int baseHandle, int[] indices)
    {
        if (!string.IsNullOrEmpty(subKey) && PackedUniverseByKey.TryGetValue(subKey, out int existing))
        {
            return existing;
        }
        if (baseHandle < 0 || baseHandle >= PackedUniverses.Count)
        {
            return -1;
        }
        long[] baseWorlds = PackedUniverses[baseHandle];
        long[] sliced = new long[indices.Length];
        for (int i = 0; i < indices.Length; i++)
        {
            sliced[i] = baseWorlds[indices[i]];
        }
        int handle = PackedUniverses.Count;
        PackedUniverses.Add(sliced);
        if (!string.IsNullOrEmpty(subKey))
        {
            PackedUniverseByKey[subKey] = handle;
        }
        return handle;
    }

    public static long[] ResolveWorlds(int handle, int[] subsetIndices, long[] fallbackWorlds)
    {
        if (handle < 0 || handle >= PackedUniverses.Count)
        {
            return fallbackWorlds;
        }
        long[] baseWorlds = PackedUniverses[handle];
        if (subsetIndices.Length == 0)
        {
            return baseWorlds;
        }
        long[] sub = new long[subsetIndices.Length];
        for (int i = 0; i < subsetIndices.Length; i++)
        {
            sub[i] = baseWorlds[subsetIndices[i]];
        }
        return sub;
    }

    public static int RegisterMovementFactor(LiveActivityKernel.CompiledMovementFactor factor)
    {
        int handle = MovementFactors.Count;
        MovementFactors.Add(factor);
        return handle;
    }

    public static LiveActivityKernel.CompiledMovementFactor? GetMovementFactor(int handle) =>
        (handle >= 0 && handle < MovementFactors.Count) ? MovementFactors[handle] : null;
}
