using System;
using System.Collections.Generic;
using System.Runtime.CompilerServices;

namespace Demonologist.Workshop;

/// <summary>
/// Slice C1 1:1 port of workshop/role_constraints.gd.
/// Preserves exact 64-bit coarse_mask, Hall bipartite role matching, Seer Red Herring
/// marginalization, Medium relay health/visit checks, Sexton knell, Veteran approach,
/// Martyr substitution/outcome, Revenant curse/totem, and bluff weight products.
/// </summary>
internal static class RoleConstraintsKernel
{
    // Fixed role IDs shared with workshop/role_constraints.gd packer:
    public const int RoleMedium = 0;
    public const int RoleLamplighter = 1;
    public const int RoleRevenant = 2;
    public const int RoleMartyr = 3;
    public const int RoleSexton = 4;
    public const int RoleVeteran = 5;
    public const int RoleSeer = 6;
    public const int RoleGravedigger = 7;
    public const int RoleNightwatch = 8;
    public const int RoleDemon = 9;
    public const int RoleScion = 10;
    public const int RoleExecutor = 11;
    public const int RoleRegistrar = 12;

    // Packed card stride (24 int32 slots per live card):
    public const int CardStride = 24;

    // Card kind codes (slot 0):
    public const int KindOther = 0;
    public const int KindReport = 1;
    public const int KindClaim = 2;
    public const int KindSecretClaim = 3;
    public const int KindTotem = 4;
    public const int KindEventMartyr = 5;
    public const int KindTownHall = 6;

    // Card flag bits (slot 1):
    public const int FlagQuoted = 1 << 0;
    public const int FlagInferred = 1 << 1;
    public const int FlagHasRelaySource = 1 << 2;
    public const int FlagRelayAliveAtNight = 1 << 3;
    public const int FlagMartyrEvil = 1 << 4;
    public const int FlagMartyrExecutedOk = 1 << 5;
    public const int FlagGravediggerExecOk = 1 << 6;
    public const int FlagRoleInGroup = 1 << 7;
    public const int FlagMarkedRegisters = 1 << 8;
    public const int FlagReadRoleEvil = 1 << 9;
    public const int FlagSeerYes = 1 << 10;
    public const int FlagSecretSleepwalker = 1 << 11;
    public const int FlagSextonEnvOk = 1 << 12;
    public const int FlagExecutorDeadOk = 1 << 13;
    public const int FlagExecutorRoleRead = 1 << 14;
    public const int FlagExecutorAssigned = 1 << 15;

    // ROLE_IN_GROUP target pool codes (slot 17):
    public const int PoolGood = 0;
    public const int PoolMinion = 1;
    public const int PoolDemon = 2;
    public const int PoolAny = 3;

    [MethodImpl(MethodImplOptions.AggressiveInlining)]
    public static long CoarseMask(int people, WorldEntry w, bool seer, int mediums, int walkers)
    {
        long n = people + 1L;
        long mask = (((long)w.Evil * n + (long)w.DemonOrMinusOne + 1L) * n) + (seer ? ((long)w.Marked + 1L) : 0L);
        if (mediums != 0)
        {
            long deluded = (w.EffectiveModifier == WorldEntry.ModDelusional) ? (w.Holders & mediums) : 0L;
            mask = mask * (1L << people) + deluded;
        }
        if (walkers != 0)
        {
            long asleep = (w.EffectiveModifier == WorldEntry.ModSleepwalker) ? (w.Holders & walkers) : 0L;
            mask = mask * (1L << people) + asleep;
        }
        if (w.HasConverted)
        {
            mask = mask * n + (long)w.ConvertedRaw + 1L;
        }
        return mask;
    }

    public static long[] CoarseMasks(int people, long[] packedWorlds, bool seer, int mediums, int walkers)
    {
        long[] outMasks = new long[packedWorlds.Length];
        for (int i = 0; i < packedWorlds.Length; i++)
        {
            outMasks[i] = CoarseMask(people, new WorldEntry(packedWorlds[i]), seer, mediums, walkers);
        }
        return outMasks;
    }

    /// <summary>
    /// 1:1 port of RoleConstraints._seer_rh_weight.
    /// readingInts has 4 ints per reading: [yes (0/1), pairMask, pingMask, reasonCode].
    /// reasonCode: 0 = "", 1 = "demon", 2 = "red_herring", 3 = "marked".
    /// Preserves exact ascending r_bit summation order and final division.
    /// </summary>
    public static double SeerRhWeight(int candidatesMask, int demon, int marked, ReadOnlySpan<int> readingInts)
    {
        if (candidatesMask == 0)
        {
            return 0.0;
        }
        int demonBit = demon >= 0 ? (1 << demon) : 0;
        int markedBit = marked >= 0 ? (1 << marked) : 0;
        double totalWeight = 0.0;
        int nCandidates = 0;
        int pool = candidatesMask;
        int rCount = readingInts.Length / 4;

        while (pool != 0)
        {
            int rBit = pool & -pool;
            pool &= ~rBit;
            nCandidates += 1;
            double w = 1.0;

            for (int r = 0; r < rCount; r++)
            {
                int b = r * 4;
                bool yes = readingInts[b] != 0;
                int pair = readingInts[b + 1];
                if (!yes)
                {
                    if ((pair & demonBit) != 0 || (pair & rBit) != 0)
                    {
                        w = 0.0;
                        break;
                    }
                    if ((pair & markedBit) != 0)
                    {
                        w *= 0.5;
                    }
                }
                else
                {
                    int ping = readingInts[b + 2];
                    int reason = readingInts[b + 3];
                    bool demonIn = (ping & demonBit) != 0;
                    bool rhIn = (ping & rBit) != 0;
                    bool markedIn = (ping & markedBit) != 0;

                    if (reason == 1) // "demon"
                    {
                        if (!demonIn)
                        {
                            w = 0.0;
                            break;
                        }
                    }
                    else if (reason == 2) // "red_herring"
                    {
                        if (!rhIn)
                        {
                            w = 0.0;
                            break;
                        }
                    }
                    else if (reason == 3) // "marked"
                    {
                        if (!markedIn)
                        {
                            w = 0.0;
                            break;
                        }
                        if (!demonIn && !rhIn)
                        {
                            w *= 0.5;
                        }
                    }
                    else
                    {
                        if (demonIn || rhIn)
                        {
                            // w *= 1.0
                        }
                        else if (markedIn)
                        {
                            w *= 0.5;
                        }
                        else
                        {
                            w = 0.0;
                            break;
                        }
                    }
                }
            }

            totalWeight += w;
        }

        return nCandidates > 0 ? totalWeight / (double)nCandidates : 0.0;
    }

    public static double[] FitsWeights(
        long[] packedWorlds,
        int[] headerInts,
        int[] publicRolesInts,
        int[] forcedLampIndices,
        int[] cardInts)
    {
        int uLen = packedWorlds.Length;
        double[] outWeights = new double[uLen];
        if (uLen == 0)
        {
            return outWeights;
        }

        int peopleCount = headerInts[0];
        bool reuseMemo = headerInts[11] != 0;
        bool seerFlag = headerInts[12] != 0;
        int mediumsMask = headerInts[13];
        int walkersMask = headerInts[14];

        int baseCardCount = cardInts.Length / CardStride;
        var relayInferredSources = new List<int>(4);
        for (int c = 0; c < baseCardCount; c++)
        {
            int flags = cardInts[c * CardStride + 1];
            if ((flags & FlagHasRelaySource) != 0 && (flags & FlagQuoted) == 0)
            {
                relayInferredSources.Add(cardInts[c * CardStride + 6]);
            }
        }
        int[] relayMediumSourceIndices = relayInferredSources.Count > 0 ? relayInferredSources.ToArray() : Array.Empty<int>();

        if (!reuseMemo)
        {
            for (int i = 0; i < uLen; i++)
            {
                outWeights[i] = FitsViewSingle(
                    new WorldEntry(packedWorlds[i]),
                    headerInts,
                    publicRolesInts,
                    forcedLampIndices,
                    cardInts,
                    baseCardCount,
                    relayMediumSourceIndices);
            }
            return outWeights;
        }

        var memo = new Dictionary<long, double>(Math.Min(uLen, 256));
        for (int i = 0; i < uLen; i++)
        {
            var world = new WorldEntry(packedWorlds[i]);
            long mask = CoarseMask(peopleCount, world, seerFlag, mediumsMask, walkersMask);
            if (!memo.TryGetValue(mask, out double w))
            {
                w = FitsViewSingle(
                    world,
                    headerInts,
                    publicRolesInts,
                    forcedLampIndices,
                    cardInts,
                    baseCardCount,
                    relayMediumSourceIndices);
                memo[mask] = w;
            }
            outWeights[i] = w;
        }
        return outWeights;
    }

    public static byte[] FitsTable(
        long[] packedWorlds,
        int[] headerInts,
        int[] publicRolesInts,
        int[] forcedLampIndices,
        int[] cardInts)
    {
        double[] weights = FitsWeights(packedWorlds, headerInts, publicRolesInts, forcedLampIndices, cardInts);
        byte[] outBytes = new byte[weights.Length];
        for (int i = 0; i < weights.Length; i++)
        {
            outBytes[i] = weights[i] > 0.0 ? (byte)1 : (byte)0;
        }
        return outBytes;
    }

    private static double FitsViewSingle(
        WorldEntry world,
        int[] headerInts,
        int[] publicRolesInts,
        int[] forcedLampIndices,
        int[] cardInts,
        int baseCardCount,
        int[] relayMediumSourceIndices)
    {
        int peopleCount = headerInts[0];
        bool bluffs = headerInts[1] != 0;
        bool viewIsEmpty = headerInts[2] != 0;
        bool hasCurse = headerInts[3] != 0;
        int curseExecutedIdx = headerInts[4];
        int curseFrom = headerInts[5];
        int curseUntil = headerInts[6];
        int ownPersonIdx = headerInts[7];
        int ownRoleId = headerInts[8];
        bool routesAvailable = headerInts[9] != 0;
        bool routesOkay = headerInts[10] != 0;
        int walkersMask = headerInts[14];

        // 1. Sleepwalker secret claim check (lines 139-143)
        if (walkersMask != 0)
        {
            int asleep = world.EffectiveModifier == WorldEntry.ModSleepwalker ? world.Holders : 0;
            if ((walkersMask & ~world.Evil & ~asleep) != 0)
            {
                return 0.0;
            }
        }

        // 2. Medium relay source health, alive_at_night, and duplicate visit checks (lines 144-153)
        if (relayMediumSourceIndices.Length > 0)
        {
            Span<long> visitKeys = stackalloc long[Math.Min(baseCardCount, 64)];
            Span<int> visitDays = stackalloc int[Math.Min(baseCardCount, 64)];
            Dictionary<long, int>? visitOverflow = baseCardCount > 64 ? new Dictionary<long, int>() : null;
            int visitCount = 0;

            for (int c = 0; c < baseCardCount; c++)
            {
                int off = c * CardStride;
                int flags = cardInts[off + 1];
                if ((flags & FlagHasRelaySource) == 0 || (flags & FlagQuoted) != 0)
                {
                    continue;
                }
                int medium = cardInts[off + 6];
                // In play (bluffs), an evil relayer may have invented the relay: it is their
                // bluff, so a world with them evil isn't ruled out and the relay's checks don't
                // apply (seed 100020: the Scion Hollis bluffing Medium). Puzzles keep it hard.
                if (bluffs && medium >= 0 && (world.Evil & (1 << medium)) != 0)
                {
                    continue;
                }
                bool relayHealthy = medium >= 0 && (world.EffectiveModifier != WorldEntry.ModDelusional || (world.Holders & (1 << medium)) == 0);
                if (medium < 0 || (world.Evil & (1 << medium)) != 0 || !relayHealthy || (flags & FlagRelayAliveAtNight) == 0)
                {
                    return 0.0;
                }
                long vKey = ((long)cardInts[off + 7] << 32) | (uint)cardInts[off + 3];
                int rDay = cardInts[off + 8];
                if (visitOverflow != null)
                {
                    if (visitOverflow.TryGetValue(vKey, out int prevDay) && prevDay != rDay)
                    {
                        return 0.0;
                    }
                    visitOverflow[vKey] = rDay;
                }
                else
                {
                    bool found = false;
                    for (int v = 0; v < visitCount; v++)
                    {
                        if (visitKeys[v] == vKey)
                        {
                            if (visitDays[v] != rDay)
                            {
                                return 0.0;
                            }
                            found = true;
                            break;
                        }
                    }
                    if (!found)
                    {
                        visitKeys[visitCount] = vKey;
                        visitDays[visitCount] = rDay;
                        visitCount++;
                    }
                }
            }
        }

        // 3. Martyr executed check & Sexton knell checks (lines 155-176)
        int sextonNight = -1;
        bool sextonEnvOk = true;
        for (int c = 0; c < baseCardCount; c++)
        {
            int off = c * CardStride;
            int kind = cardInts[off];
            int flags = cardInts[off + 1];
            if (kind != KindReport || (flags & FlagQuoted) != 0)
            {
                continue;
            }
            int roleId = cardInts[off + 5];
            if (roleId == RoleMartyr && (flags & FlagMartyrEvil) != 0 && (flags & FlagMartyrExecutedOk) == 0)
            {
                return 0.0;
            }
            if (roleId == RoleSexton)
            {
                int dataNight = cardInts[off + 10];
                if (sextonNight >= 0 && sextonNight != dataNight)
                {
                    return 0.0;
                }
                sextonNight = dataNight;
                sextonEnvOk = (flags & FlagSextonEnvOk) != 0;
            }
        }

        if (sextonNight >= 0)
        {
            if (!sextonEnvOk)
            {
                return 0.0;
            }
        }

        // 4. Veteran approach check (lines 177-186)
        int demon = world.DemonOrMinusOne;
        for (int c = 0; c < baseCardCount; c++)
        {
            int off = c * CardStride;
            int kind = cardInts[off];
            int flags = cardInts[off + 1];
            if (kind != KindReport || (flags & FlagQuoted) != 0 || cardInts[off + 5] != RoleVeteran)
            {
                continue;
            }
            if (demon < 0)
            {
                return 0.0;
            }
            int validDemonMask = cardInts[off + 11];
            if ((validDemonMask & (1 << demon)) == 0)
            {
                return 0.0;
            }
        }

        // 5. Activity routing gate (lines 187-200)
        bool live = bluffs;
        if (routesAvailable && !routesOkay && !live)
        {
            return 0.0;
        }

        // 6. _fits(...) role assignment & Hall matching (lines 206-331)
        int all = (1 << peopleCount) - 1;
        int evil = world.Evil;
        int good = all & ~evil;
        int minions = demon >= 0 ? (evil & ~(1 << demon)) : evil;

        int maxRolesCap = Math.Max(64, (publicRolesInts.Length / 2) + baseCardCount * 2 + 8);
        Span<int> assignRoles = maxRolesCap <= 128 ? stackalloc int[128] : new int[maxRolesCap];
        Span<int> assignMasks = maxRolesCap <= 128 ? stackalloc int[128] : new int[maxRolesCap];
        int assignCount = 0;

        if (ownPersonIdx >= 0 && ownRoleId >= 0)
        {
            AssignRole(assignRoles, assignMasks, ref assignCount, ownRoleId, 1 << ownPersonIdx);
        }

        for (int p = 0; p + 1 < publicRolesInts.Length; p += 2)
        {
            int pIdx = publicRolesInts[p];
            int rId = publicRolesInts[p + 1];
            if (pIdx < 0 || (evil & (1 << pIdx)) != 0 || !AssignRole(assignRoles, assignMasks, ref assignCount, rId, 1 << pIdx))
            {
                return 0.0;
            }
        }

        if (hasCurse && curseExecutedIdx >= 0)
        {
            if (!AssignRole(assignRoles, assignMasks, ref assignCount, RoleRevenant, (1 << curseExecutedIdx) & minions))
            {
                return 0.0;
            }
        }

        int seerSourceToken = -1;
        int seerSourceIdx = -1;
        Span<int> seerReadingsStack = stackalloc int[128];
        List<int>? seerReadingsOverflow = null;
        int seerReadingCount = 0;
        int veteranNight = -1;
        int martyrTargetToken = 0;
        int executorTargetToken = 0;
        bool hasRegistrar = false;
        Span<int> regRoles = stackalloc int[3];
        int regMinionBits = 0;
        int regNoMask = 0;
        int regYesMask = 0;
        Span<int> regYesTargets = stackalloc int[32];
        int regYesCount = 0;

        Span<int> thR0Stack = stackalloc int[16];
        Span<int> thR1Stack = stackalloc int[16];
        Span<int> thPickStack = stackalloc int[16];
        int thCount = 0;

        bool worldHasConverted = world.HasConverted;
        int worldConverted = world.ConvertedRaw;

        // 6a. Base live cards
        for (int c = 0; c < baseCardCount; c++)
        {
            int off = c * CardStride;
            int flags = cardInts[off + 1];
            if ((flags & FlagQuoted) != 0)
            {
                continue;
            }
            int kind = cardInts[off];
            if (kind == KindTownHall)
            {
                int r0 = cardInts[off + 13];
                int r1 = cardInts[off + 14];
                int pickMode = cardInts[off + 15];
                if (r0 < 0 || r1 < 0 || r0 == r1 || pickMode == 3 || thCount >= 16)
                {
                    return 0.0;
                }
                thR0Stack[thCount] = r0;
                thR1Stack[thCount] = r1;
                thPickStack[thCount] = pickMode;
                thCount++;
                continue;
            }
            if (kind == KindTotem)
            {
                int candidates = cardInts[off + 13];
                if (!AssignRole(assignRoles, assignMasks, ref assignCount, RoleRevenant, candidates & minions))
                {
                    return 0.0;
                }
                continue;
            }
            if (kind == KindEventMartyr)
            {
                int actor = cardInts[off + 13];
                int saved = cardInts[off + 14];
                if (actor < 0 || saved < 0 || (evil & ((1 << actor) | (1 << saved))) != 0
                    || !AssignRole(assignRoles, assignMasks, ref assignCount, RoleMartyr, 1 << actor))
                {
                    return 0.0;
                }
                continue;
            }
            if (kind != KindReport && kind != KindClaim)
            {
                continue;
            }

            int source = cardInts[off + 2];
            if (source < 0)
            {
                return 0.0;
            }

            // A relayed reading in a live world where its relayer is evil: invented, so it
            // says nothing about the dead source's role or reading.
            if (live && (flags & FlagHasRelaySource) != 0)
            {
                int relayer = cardInts[off + 6];
                if (relayer >= 0 && (evil & (1 << relayer)) != 0)
                {
                    continue;
                }
            }

            bool sourceEvil = (evil & (1 << source)) != 0;
            if (worldHasConverted && !viewIsEmpty)
            {
                int stmtTick = cardInts[off + 12];
                sourceEvil = ((evil & (1 << source)) != 0)
                    || (worldConverted == source && hasCurse && stmtTick >= curseFrom && stmtTick < curseUntil);
            }

            if (sourceEvil)
            {
                if (live && (flags & FlagInferred) == 0)
                {
                    continue;
                }
                return 0.0;
            }

            int roleId = cardInts[off + 5];
            if (!AssignRole(assignRoles, assignMasks, ref assignCount, roleId, 1 << source))
            {
                return 0.0;
            }

            if (kind == KindClaim)
            {
                continue;
            }

            if (roleId == RoleGravedigger && (flags & FlagGravediggerExecOk) == 0)
            {
                return 0.0;
            }

            int pairMask = cardInts[off + 13];
            if (pairMask < 0)
            {
                return 0.0;
            }
            int selectedMask = cardInts[off + 14];
            if (selectedMask < 0)
            {
                return 0.0;
            }

            if ((flags & FlagRoleInGroup) != 0)
            {
                int groupMode = cardInts[off + 15];
                int groupMask;
                if (groupMode == 0) // "pair"
                {
                    groupMask = pairMask;
                    if (selectedMask != 0)
                    {
                        groupMask &= selectedMask;
                    }
                }
                else
                {
                    int target = cardInts[off + 16];
                    if (target < 0)
                    {
                        return 0.0;
                    }
                    groupMask = 1 << target;
                }

                int readRoleId = cardInts[off + 18];
                bool evilRole = (flags & FlagReadRoleEvil) != 0;
                if ((flags & FlagMarkedRegisters) != 0 && evilRole && world.Marked >= 0 && (groupMask & (1 << world.Marked)) != 0)
                {
                    continue;
                }

                int poolKind = cardInts[off + 17];
                int poolMask = good;
                switch (poolKind)
                {
                    case PoolMinion:
                        poolMask = minions;
                        break;
                    case PoolDemon:
                        poolMask = demon >= 0 ? (1 << demon) : 0;
                        break;
                    case PoolAny:
                        poolMask = (readRoleId == RoleDemon && demon >= 0) ? (1 << demon) : (evilRole ? minions : good);
                        break;
                }

                if (readRoleId == RoleDemon && groupMode != 0)
                {
                    int gdTarget = cardInts[off + 16];
                    if (demon == gdTarget)
                    {
                        if (!AssignRole(assignRoles, assignMasks, ref assignCount, RoleDemon, 1 << gdTarget))
                        {
                            return 0.0;
                        }
                    }
                    else
                    {
                        int scionAliveMask = cardInts[off + 11];
                        if (scionAliveMask != 0 && demon >= 0 && (scionAliveMask & (1 << demon)) != 0 && (minions & (1 << gdTarget)) != 0)
                        {
                            if (!AssignRole(assignRoles, assignMasks, ref assignCount, RoleScion, 1 << gdTarget))
                            {
                                return 0.0;
                            }
                        }
                        else
                        {
                            return 0.0;
                        }
                    }
                }
                else if (!AssignRole(assignRoles, assignMasks, ref assignCount, readRoleId, groupMask & poolMask))
                {
                    return 0.0;
                }
            }
            else if (roleId == RoleExecutor)
            {
                int eTarget = cardInts[off + 16];
                int eToken = cardInts[off + 17];
                if (eToken == 0 || eTarget < 0 || eTarget == source)
                {
                    return 0.0;
                }
                if (executorTargetToken != 0 && executorTargetToken != eToken)
                {
                    return 0.0;
                }
                executorTargetToken = eToken;
                if ((flags & FlagExecutorAssigned) != 0)
                {
                    continue;
                }
                if ((flags & FlagExecutorRoleRead) != 0)
                {
                    if ((flags & FlagExecutorDeadOk) == 0)
                    {
                        return 0.0;
                    }
                    int exRoleId = cardInts[off + 18];
                    bool exEvilRole = (flags & FlagReadRoleEvil) != 0;
                    if (exEvilRole && world.Marked >= 0 && world.Marked == eTarget)
                    {
                        continue;
                    }
                    if (exRoleId == RoleDemon)
                    {
                        if (demon == eTarget)
                        {
                            if (!AssignRole(assignRoles, assignMasks, ref assignCount, RoleDemon, 1 << eTarget))
                            {
                                return 0.0;
                            }
                        }
                        else
                        {
                            int scionAliveMask = cardInts[off + 11];
                            if (scionAliveMask != 0 && demon >= 0 && (scionAliveMask & (1 << demon)) != 0 && (minions & (1 << eTarget)) != 0)
                            {
                                if (!AssignRole(assignRoles, assignMasks, ref assignCount, RoleScion, 1 << eTarget))
                                {
                                    return 0.0;
                                }
                            }
                            else
                            {
                                return 0.0;
                            }
                        }
                    }
                    else
                    {
                        int exPool = exEvilRole ? minions : good;
                        if (!AssignRole(assignRoles, assignMasks, ref assignCount, exRoleId, (1 << eTarget) & exPool))
                        {
                            return 0.0;
                        }
                    }
                }
                else
                {
                    return 0.0;
                }
            }
            else if (roleId == RoleRegistrar)
            {
                int regMeta = cardInts[off + 23];
                if (regMeta < 0)
                {
                    return 0.0;
                }
                int r0 = cardInts[off + 20];
                int r1 = cardInts[off + 21];
                int r2 = cardInts[off + 22];
                if (!hasRegistrar)
                {
                    hasRegistrar = true;
                    regRoles[0] = r0;
                    regRoles[1] = r1;
                    regRoles[2] = r2;
                    regMinionBits = regMeta & 7;
                }
                else
                {
                    bool r0In = (r0 == regRoles[0] || r0 == regRoles[1] || r0 == regRoles[2]);
                    bool r1In = (r1 == regRoles[0] || r1 == regRoles[1] || r1 == regRoles[2]);
                    bool r2In = (r2 == regRoles[0] || r2 == regRoles[1] || r2 == regRoles[2]);
                    if (!r0In || !r1In || !r2In)
                    {
                        return 0.0;
                    }
                }
                if ((regMeta & (1 << 3)) != 0)
                {
                    int rTarget = cardInts[off + 16];
                    if (rTarget < 0 || rTarget == source)
                    {
                        return 0.0;
                    }
                    if ((regMeta & (1 << 4)) != 0)
                    {
                        if ((regYesMask & (1 << rTarget)) == 0)
                        {
                            if (regYesCount >= regYesTargets.Length)
                            {
                                return 0.0;
                            }
                            regYesMask |= (1 << rTarget);
                            regYesTargets[regYesCount++] = rTarget;
                        }
                    }
                    else
                    {
                        regNoMask |= (1 << rTarget);
                    }
                }
            }
            else if (roleId == RoleVeteran)
            {
                int cardNight = cardInts[off + 9];
                if (veteranNight >= 0 && veteranNight != cardNight)
                {
                    return 0.0;
                }
                veteranNight = cardNight;
            }
            else if (roleId == RoleMartyr)
            {
                int mToken = cardInts[off + 17];
                if (martyrTargetToken != 0 && martyrTargetToken != mToken)
                {
                    return 0.0;
                }
                martyrTargetToken = mToken;
                if ((flags & FlagMartyrEvil) != 0)
                {
                    int target = cardInts[off + 16];
                    if (target < 0 || ((evil & (1 << target)) == 0 && world.Marked != target))
                    {
                        return 0.0;
                    }
                }
            }
            else if (roleId == RoleSeer)
            {
                int srcTok = cardInts[off + 3];
                if (seerSourceToken >= 0 && seerSourceToken != srcTok)
                {
                    return 0.0;
                }
                seerSourceToken = srcTok;
                seerSourceIdx = source;
                int ping = selectedMask != 0 ? selectedMask : pairMask;
                int yesInt = (flags & FlagSeerYes) != 0 ? 1 : 0;
                int reasonCode = cardInts[off + 19];

                if (seerReadingsOverflow == null && (seerReadingCount + 1) * 4 <= seerReadingsStack.Length)
                {
                    int b = seerReadingCount * 4;
                    seerReadingsStack[b] = yesInt;
                    seerReadingsStack[b + 1] = pairMask;
                    seerReadingsStack[b + 2] = ping;
                    seerReadingsStack[b + 3] = reasonCode;
                }
                else
                {
                    if (seerReadingsOverflow == null)
                    {
                        seerReadingsOverflow = new List<int>((seerReadingCount + 4) * 4);
                        for (int k = 0; k < seerReadingCount * 4; k++)
                        {
                            seerReadingsOverflow.Add(seerReadingsStack[k]);
                        }
                    }
                    seerReadingsOverflow.Add(yesInt);
                    seerReadingsOverflow.Add(pairMask);
                    seerReadingsOverflow.Add(ping);
                    seerReadingsOverflow.Add(reasonCode);
                }
                seerReadingCount++;
            }
        }

        // 6b. Inferred Medium claims from _routing_cards (inferred = true, statement_tick = 1)
        for (int r = 0; r < relayMediumSourceIndices.Length; r++)
        {
            int source = relayMediumSourceIndices[r];
            if (source < 0)
            {
                return 0.0;
            }
            bool sourceEvil = (evil & (1 << source)) != 0;
            if (worldHasConverted && !viewIsEmpty)
            {
                sourceEvil = sourceEvil || (worldConverted == source && hasCurse && 1 >= curseFrom && 1 < curseUntil);
            }
            if (sourceEvil)
            {
                // In play an evil relayer is bluffing Medium, like any claim (6a).
                if (live)
                {
                    continue;
                }
                return 0.0;
            }
            if (!AssignRole(assignRoles, assignMasks, ref assignCount, RoleMedium, 1 << source))
            {
                return 0.0;
            }
        }

        // 6c. Inferred Lamplighter claims from routes.forced_lamp (when routesAvailable && routesOkay)
        if (routesAvailable && routesOkay)
        {
            for (int f = 0; f < forcedLampIndices.Length; f++)
            {
                int lampIdx = forcedLampIndices[f];
                if (demon == lampIdx)
                {
                    continue;
                }
                if (lampIdx < 0)
                {
                    return 0.0;
                }
                bool sourceEvil = (evil & (1 << lampIdx)) != 0;
                if (worldHasConverted && !viewIsEmpty)
                {
                    sourceEvil = sourceEvil || (worldConverted == lampIdx && hasCurse && 1 >= curseFrom && 1 < curseUntil);
                }
                if (sourceEvil)
                {
                    return 0.0;
                }
                if (!AssignRole(assignRoles, assignMasks, ref assignCount, RoleLamplighter, 1 << lampIdx))
                {
                    return 0.0;
                }
            }
        }

        double seerWeight = 1.0;
        if (seerSourceToken >= 0)
        {
            ReadOnlySpan<int> readingsSpan = seerReadingsOverflow != null
                ? System.Runtime.InteropServices.CollectionsMarshal.AsSpan(seerReadingsOverflow)
                : seerReadingsStack.Slice(0, seerReadingCount * 4);
            seerWeight = SeerRhWeight(good & ~(1 << seerSourceIdx), demon, world.Marked, readingsSpan);
            if (seerWeight <= 0.0)
            {
                return 0.0;
            }
        }

        if (hasRegistrar)
        {
            bool regOk = RegistrarMatches(
                assignRoles,
                assignMasks,
                assignCount,
                regRoles,
                regMinionBits,
                regNoMask,
                regYesTargets.Slice(0, regYesCount),
                world.Marked,
                evil,
                good,
                minions,
                thR0Stack.Slice(0, thCount),
                thR1Stack.Slice(0, thCount),
                thPickStack.Slice(0, thCount));
            return regOk ? seerWeight : 0.0;
        }

        if (thCount == 0)
        {
            return Matching(assignMasks.Slice(0, assignCount), assignCount - 1, 0) ? seerWeight : 0.0;
        }
        Span<int> forbiddenRoles = stackalloc int[16];
        bool thOk = TownHallMatches(
            assignRoles,
            assignMasks,
            assignCount,
            thR0Stack.Slice(0, thCount),
            thR1Stack.Slice(0, thCount),
            thPickStack.Slice(0, thCount),
            0,
            good,
            forbiddenRoles,
            0);
        return thOk ? seerWeight : 0.0;
    }

    private static bool RegistrarMatches(
        ReadOnlySpan<int> curRoles,
        ReadOnlySpan<int> curMasks,
        int curCount,
        ReadOnlySpan<int> regRoles,
        int regMinionBits,
        int regNoMask,
        ReadOnlySpan<int> regYesTargets,
        int marked,
        int evil,
        int good,
        int minions,
        ReadOnlySpan<int> thR0,
        ReadOnlySpan<int> thR1,
        ReadOnlySpan<int> thPick)
    {
        Span<int> baseRoles = stackalloc int[Math.Max(1, curCount)];
        Span<int> baseMasks = stackalloc int[Math.Max(1, curCount)];
        curRoles.Slice(0, curCount).CopyTo(baseRoles);
        curMasks.Slice(0, curCount).CopyTo(baseMasks);

        Span<int> basePools = stackalloc int[3];
        for (int k = 0; k < 3; k++)
        {
            int rk = regRoles[k];
            basePools[k] = (((regMinionBits & (1 << k)) != 0) ? minions : good) & ~regNoMask;
            for (int a = 0; a < curCount; a++)
            {
                if (baseRoles[a] == rk)
                {
                    baseMasks[a] &= ~regNoMask;
                    if (baseMasks[a] == 0)
                    {
                        return false;
                    }
                }
            }
        }

        return RegistrarYesStep(
            baseRoles.Slice(0, curCount),
            baseMasks.Slice(0, curCount),
            curCount,
            0,
            regRoles,
            regMinionBits,
            basePools,
            regYesTargets,
            marked,
            evil,
            good,
            thR0,
            thR1,
            thPick);
    }

    private static bool RegistrarYesStep(
        ReadOnlySpan<int> curRoles,
        ReadOnlySpan<int> curMasks,
        int curCount,
        int yIdx,
        ReadOnlySpan<int> regRoles,
        int regMinionBits,
        ReadOnlySpan<int> basePools,
        ReadOnlySpan<int> regYesTargets,
        int marked,
        int evil,
        int good,
        ReadOnlySpan<int> thR0,
        ReadOnlySpan<int> thR1,
        ReadOnlySpan<int> thPick)
    {
        if (yIdx >= regYesTargets.Length)
        {
            bool anyIn = false;
            for (int a = 0; a < curCount; a++)
            {
                int cr = curRoles[a];
                if (cr == regRoles[0] || cr == regRoles[1] || cr == regRoles[2])
                {
                    anyIn = true;
                    break;
                }
            }
            Span<int> fbBuf = stackalloc int[16];
            if (anyIn)
            {
                if (thR0.Length == 0)
                {
                    return Matching(curMasks.Slice(0, curCount), curCount - 1, 0);
                }
                return TownHallMatches(curRoles, curMasks, curCount, thR0, thR1, thPick, 0, good, fbBuf, 0);
            }

            Span<int> nextInRoles = stackalloc int[curCount + 1];
            Span<int> nextInMasks = stackalloc int[curCount + 1];
            for (int k = 0; k < 3; k++)
            {
                int bp = basePools[k];
                if (bp == 0)
                {
                    continue;
                }
                curRoles.Slice(0, curCount).CopyTo(nextInRoles);
                curMasks.Slice(0, curCount).CopyTo(nextInMasks);
                int nextInCount = curCount;
                if (!AssignRole(nextInRoles, nextInMasks, ref nextInCount, regRoles[k], bp))
                {
                    continue;
                }
                if (thR0.Length == 0)
                {
                    if (Matching(nextInMasks.Slice(0, nextInCount), nextInCount - 1, 0))
                    {
                        return true;
                    }
                }
                else
                {
                    fbBuf.Clear();
                    if (TownHallMatches(nextInRoles, nextInMasks, nextInCount, thR0, thR1, thPick, 0, good, fbBuf, 0))
                    {
                        return true;
                    }
                }
            }
            return false;
        }

        int t = regYesTargets[yIdx];
        int tBit = 1 << t;
        Span<int> nextRoles = stackalloc int[curCount + 1];
        Span<int> nextMasks = stackalloc int[curCount + 1];

        for (int k = 0; k < 3; k++)
        {
            if ((basePools[k] & tBit) == 0)
            {
                continue;
            }
            curRoles.Slice(0, curCount).CopyTo(nextRoles);
            curMasks.Slice(0, curCount).CopyTo(nextMasks);
            int nextCount = curCount;
            if (!AssignRole(nextRoles, nextMasks, ref nextCount, regRoles[k], tBit))
            {
                continue;
            }
            if (RegistrarYesStep(
                nextRoles.Slice(0, nextCount),
                nextMasks.Slice(0, nextCount),
                nextCount,
                yIdx + 1,
                regRoles,
                regMinionBits,
                basePools,
                regYesTargets,
                marked,
                evil,
                good,
                thR0,
                thR1,
                thPick))
            {
                return true;
            }
        }

        if (regMinionBits != 0 && marked == t && (evil & tBit) == 0)
        {
            if (RegistrarYesStep(
                curRoles,
                curMasks,
                curCount,
                yIdx + 1,
                regRoles,
                regMinionBits,
                basePools,
                regYesTargets,
                marked,
                evil,
                good,
                thR0,
                thR1,
                thPick))
            {
                return true;
            }
        }
        return false;
    }

    private static bool TownHallMatches(
        ReadOnlySpan<int> curRoles,
        ReadOnlySpan<int> curMasks,
        int curCount,
        ReadOnlySpan<int> thR0,
        ReadOnlySpan<int> thR1,
        ReadOnlySpan<int> thPick,
        int idx,
        int good,
        ReadOnlySpan<int> forbidden,
        int forbiddenCount)
    {
        if (idx >= thR0.Length)
        {
            return Matching(curMasks.Slice(0, curCount), curCount - 1, 0);
        }

        int r0 = thR0[idx];
        int r1 = thR1[idx];
        int pickMode = thPick[idx];

        Span<int> nextRoles = stackalloc int[curCount + 1];
        Span<int> nextMasks = stackalloc int[curCount + 1];
        Span<int> nextForbidden = stackalloc int[forbiddenCount + 1];

        for (int choice = 0; choice < 2; choice++)
        {
            if (pickMode == 1 && choice != 0)
            {
                continue;
            }
            if (pickMode == 2 && choice != 1)
            {
                continue;
            }

            int inRole = choice == 0 ? r0 : r1;
            int outRole = choice == 0 ? r1 : r0;

            bool inIsForbidden = false;
            for (int f = 0; f < forbiddenCount; f++)
            {
                if (forbidden[f] == inRole)
                {
                    inIsForbidden = true;
                    break;
                }
            }
            if (inIsForbidden)
            {
                continue;
            }

            bool outIsAssigned = false;
            for (int a = 0; a < curCount; a++)
            {
                if (curRoles[a] == outRole)
                {
                    outIsAssigned = true;
                    break;
                }
            }
            if (outIsAssigned)
            {
                continue;
            }

            curRoles.Slice(0, curCount).CopyTo(nextRoles);
            curMasks.Slice(0, curCount).CopyTo(nextMasks);
            int nextCount = curCount;
            if (!AssignRole(nextRoles, nextMasks, ref nextCount, inRole, good))
            {
                continue;
            }

            forbidden.Slice(0, forbiddenCount).CopyTo(nextForbidden);
            nextForbidden[forbiddenCount] = outRole;

            if (TownHallMatches(
                nextRoles,
                nextMasks,
                nextCount,
                thR0,
                thR1,
                thPick,
                idx + 1,
                good,
                nextForbidden,
                forbiddenCount + 1))
            {
                return true;
            }
        }

        return false;
    }

    [MethodImpl(MethodImplOptions.AggressiveInlining)]
    private static bool AssignRole(Span<int> roles, Span<int> masks, ref int count, int roleId, int candidates)
    {
        for (int i = 0; i < count; i++)
        {
            if (roles[i] == roleId)
            {
                candidates &= masks[i];
                masks[i] = candidates;
                return candidates != 0;
            }
        }
        roles[count] = roleId;
        masks[count] = candidates;
        count++;
        return candidates != 0;
    }

    private static bool Matching(ReadOnlySpan<int> masks, int idx, int occupied)
    {
        if (idx < 0)
        {
            return true;
        }
        int available = masks[idx] & ~occupied;
        while (available != 0)
        {
            int bit = available & -available;
            if (Matching(masks, idx - 1, occupied | bit))
            {
                return true;
            }
            available &= ~bit;
        }
        return false;
    }

    public static double[] BluffWeightsSimple(long[] packedWorlds, int[] declaredBits, double bluffWeight)
    {
        int uLen = packedWorlds.Length;
        double[] outWeights = new double[uLen];
        int dLen = declaredBits.Length;
        for (int w = 0; w < uLen; w++)
        {
            int evil = new WorldEntry(packedWorlds[w]).Evil;
            double weight = 1.0;
            for (int d = 0; d < dLen; d++)
            {
                if ((evil & declaredBits[d]) != 0)
                {
                    weight *= bluffWeight;
                }
            }
            outWeights[w] = weight;
        }
        return outWeights;
    }

    public static double[] BluffWeightsTemporal(
        long[] packedWorlds,
        int[] whoIndices,
        double[] hearingWeights,
        int[] stmtTicks,
        bool hasCurse,
        int curseFrom,
        int curseUntil,
        double bluffWeight)
    {
        int dLen = whoIndices.Length;
        double[] factors = new double[dLen];
        for (int d = 0; d < dLen; d++)
        {
            factors[d] = SolverBridge.GodotLerpf(1.0, bluffWeight, hearingWeights[d]);
        }

        int uLen = packedWorlds.Length;
        double[] outWeights = new double[uLen];
        for (int i = 0; i < uLen; i++)
        {
            var world = new WorldEntry(packedWorlds[i]);
            bool converted = world.HasConverted;
            int convIdx = world.ConvertedRaw;
            int evil = world.Evil;
            double weight = 1.0;
            for (int d = 0; d < dLen; d++)
            {
                int j = whoIndices[d];
                if (j < 0)
                {
                    continue;
                }
                bool isEvilThen = ((evil & (1 << j)) != 0)
                    || (converted && convIdx == j && hasCurse && stmtTicks[d] >= curseFrom && stmtTicks[d] < curseUntil);
                if (isEvilThen)
                {
                    weight *= factors[d];
                }
            }
            outWeights[i] = weight;
        }
        return outWeights;
    }
}
