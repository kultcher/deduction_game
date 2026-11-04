using System;
using System.Collections.Generic;
using System.Numerics;
using System.Runtime.CompilerServices;

namespace Demonologist.Workshop;

/// <summary>
/// Slice C1 1:1 port of workshop/world_domain.gd.
/// Preserves exact world enumeration order, 64-bit world keys, claim uniqueness checks,
/// Delusional impairment check, gift timing check, and Rumormonger constraint check.
/// </summary>
internal static class WorldDomainKernel
{
    /// <summary>
    /// Enumerates all legal live worlds in the exact order of world_domain.gd::worlds.
    /// Returns a flat stride-3 long[] buffer: [packedWorld0, key0, modInputSlot0, ...].
    /// </summary>
    public static long[] EnumerateWorlds(int n, int evilCount, string[] modifiers, bool identities)
    {
        string cacheKey = $"{n}|{evilCount}|{(identities ? 1 : 0)}|{string.Join(",", modifiers)}";
        if (SolverContext.TryGetUniverse(cacheKey, out long[] cached))
        {
            return cached;
        }

        int modLen = modifiers.Length;
        int[] modCodes = new int[modLen];
        for (int m = 0; m < modLen; m++)
        {
            modCodes[m] = WorldEntry.ParseModifierCode(modifiers[m]);
        }

        var baseWorlds = new List<(WorldEntry World, int ModSlot)>(512);
        int limit = 1 << n;
        for (int evil = 0; evil < limit; evil++)
        {
            if (BitOperations.PopCount((uint)evil) != evilCount)
            {
                continue;
            }
            for (int m = 0; m < modLen; m++)
            {
                string kind = modifiers[m];
                int modCode = modCodes[m];
                bool isLovers = kind == "lovers";
                bool isMarked = kind == "marked";
                for (int i = 0; i < n; i++)
                {
                    if ((evil & (1 << i)) != 0)
                    {
                        continue;
                    }
                    if (!isLovers)
                    {
                        int marked = isMarked ? i : -1;
                        var w = WorldEntry.Pack(evil, 1 << i, marked, modCode, -2, -2);
                        baseWorlds.Add((w, m));
                    }
                    else
                    {
                        for (int j = i + 1; j < n; j++)
                        {
                            if ((evil & (1 << j)) == 0)
                            {
                                var w = WorldEntry.Pack(evil, (1 << i) | (1 << j), -1, modCode, -2, -2);
                                baseWorlds.Add((w, m));
                            }
                        }
                    }
                }
            }
        }

        List<(WorldEntry World, int ModSlot)> finalWorlds;
        if (identities)
        {
            finalWorlds = new List<(WorldEntry World, int ModSlot)>(baseWorlds.Count * Math.Max(evilCount, 1));
            for (int idx = 0; idx < baseWorlds.Count; idx++)
            {
                var item = baseWorlds[idx];
                int evil = item.World.Evil;
                for (int i = 0; i < n; i++)
                {
                    if ((evil & (1 << i)) != 0)
                    {
                        finalWorlds.Add((item.World.WithDemon(i), item.ModSlot));
                    }
                }
            }
        }
        else
        {
            finalWorlds = baseWorlds;
        }

        long[] outBuf = new long[finalWorlds.Count * 3];
        for (int idx = 0; idx < finalWorlds.Count; idx++)
        {
            var item = finalWorlds[idx];
            int offset = idx * 3;
            outBuf[offset] = item.World.Raw;
            outBuf[offset + 1] = ComputeKey(n, item.World);
            outBuf[offset + 2] = item.ModSlot;
        }

        SolverContext.StoreUniverse(cacheKey, outBuf);
        return outBuf;
    }

    [MethodImpl(MethodImplOptions.AggressiveInlining)]
    public static long ComputeKey(int n, WorldEntry w)
    {
        long np1 = n + 1L;
        long baseVal = ((((long)w.Evil * np1 + (long)w.Marked + 1L) * 4L + (long)w.SecretModIndex) * (1L << n)) + (long)w.Holders;
        if (w.HasDemon)
        {
            baseVal = baseVal * np1 + (long)w.DemonRaw + 1L;
        }
        if (w.HasConverted)
        {
            baseVal = baseVal * np1 + (long)w.ConvertedRaw + 1L;
        }
        return baseVal;
    }

    public static long[] ComputeKeys(int n, long[] packedWorlds)
    {
        long[] keys = new long[packedWorlds.Length];
        for (int i = 0; i < packedWorlds.Length; i++)
        {
            keys[i] = ComputeKey(n, new WorldEntry(packedWorlds[i]));
        }
        return keys;
    }

    /// <summary>
    /// 1:1 port of WorldDomain.claims_compatible(cards, knowledge).
    /// kindCodes: 1 = "report", 2 = "claim", 0 = other.
    /// flags: bit 0 = quoted, bit 1 = testimony_only.
    /// </summary>
    public static bool ClaimsCompatible(
        int[] kindCodes,
        byte[] flags,
        string[] sources,
        string[] roles,
        bool hasSelf,
        string selfId,
        bool hasOwnRole,
        string ownRole)
    {
        var seenSources = new Dictionary<string, string>(kindCodes.Length);
        var seenRoles = new Dictionary<string, string>(kindCodes.Length);
        string ownRoleOrEmpty = hasOwnRole ? ownRole : "";

        for (int i = 0; i < kindCodes.Length; i++)
        {
            int kc = kindCodes[i];
            if ((kc != 1 && kc != 2) || (flags[i] & 0x3) != 0)
            {
                continue;
            }
            string src = sources[i];
            string role = roles[i];

            if (seenSources.TryGetValue(src, out string? prevRole) && prevRole != role)
            {
                return false;
            }
            if (seenRoles.TryGetValue(role, out string? prevSrc) && prevSrc != src)
            {
                return false;
            }

            bool isSelf = hasSelf && src == selfId;
            if (isSelf && (hasOwnRole ? ownRole : role) != role)
            {
                return false;
            }
            if (!isSelf && role == ownRoleOrEmpty)
            {
                return false;
            }

            seenSources[src] = role;
            seenRoles[role] = src;
        }
        return true;
    }

    [MethodImpl(MethodImplOptions.AggressiveInlining)]
    public static bool Healthy(long packedWorld, int personIndex)
    {
        if (personIndex < 0)
        {
            return false;
        }
        var w = new WorldEntry(packedWorld);
        return w.EffectiveModifier != WorldEntry.ModDelusional || (w.Holders & (1 << personIndex)) == 0;
    }

    public static byte[] HealthyTable(long[] packedWorlds, int personIndex)
    {
        byte[] outBuf = new byte[packedWorlds.Length];
        if (personIndex < 0)
        {
            return outBuf;
        }
        int bit = 1 << personIndex;
        for (int i = 0; i < packedWorlds.Length; i++)
        {
            var w = new WorldEntry(packedWorlds[i]);
            outBuf[i] = (w.EffectiveModifier != WorldEntry.ModDelusional || (w.Holders & bit) == 0) ? (byte)1 : (byte)0;
        }
        return outBuf;
    }

    /// <summary>
    /// 1:1 port of RoleDef.is_valid_gift_time(observed_at) via WorldDomain.gift_time(card).
    /// </summary>
    public static bool GiftTime(
        string roleId,
        string align,
        bool eveningOrNight,
        bool isDay,
        bool firstNight,
        int minGiftDay,
        int obsDay,
        string obsPhase)
    {
        if (string.IsNullOrEmpty(roleId) || roleId == "hearthwitch" || align != "good")
        {
            return false;
        }
        if (roleId == "chronicler")
        {
            return obsDay == 3 && obsPhase == "night";
        }
        if (roleId == "augur")
        {
            return obsDay >= minGiftDay && obsPhase == "evening";
        }
        if (roleId == "executor")
        {
            return (obsDay == 0 && obsPhase == "night") || (obsDay >= 1 && obsPhase == "morning");
        }
        if (roleId == "registrar")
        {
            return obsDay >= 0 && obsPhase == "night";
        }
        if (eveningOrNight)
        {
            return obsDay >= minGiftDay && (obsPhase == "evening" || obsPhase == "night");
        }
        if (isDay)
        {
            return obsDay >= minGiftDay && (obsPhase == "morning" || obsPhase == "afternoon" || obsPhase == "evening");
        }
        if (firstNight)
        {
            return obsDay == 0 && obsPhase == "night";
        }
        return obsDay >= minGiftDay && obsPhase == "night";
    }

    /// <summary>
    /// 1:1 port of WorldDomain.rumor(view, world, card, answer).
    /// </summary>
    public static bool Rumor(
        long packedWorld,
        string worldModifier,
        int sourceIdx,
        string secret,
        int pairMask,
        bool hasAnsPos,
        int ansMask)
    {
        var w = new WorldEntry(packedWorld);
        int holders = w.Holders;
        if (sourceIdx >= 0 && (holders & ~(1 << sourceIdx)) == 0)
        {
            return false;
        }
        if (worldModifier != secret)
        {
            return false;
        }
        if ((holders & pairMask) == 0)
        {
            return false;
        }
        if (hasAnsPos && (holders & ansMask) != ansMask)
        {
            return false;
        }
        return true;
    }
}
