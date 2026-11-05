using System;
using System.Collections.Generic;
using System.Numerics;
using System.Runtime.CompilerServices;

namespace Demonologist.Workshop;

/// <summary>
/// Slice C3 1:1 port of workshop/solver.gd hot loops and constraint tables:
///   - world_bits &amp; sig_groups (cached per universe handle)
///   - valid_table &amp; report_table (_report_holds, _testimony_content, _report_content)
///   - _solve world filtering, _positions filtering, and fixture _movement bitmask enumeration
///   - question_table, holds / _build_premise_mask, and unresolved bitmask scan
/// </summary>
internal static class SolverKernel
{
    // Position codes matching workshop/solver.gd :: position_holds:
    public const int PosGood = 0;
    public const int PosEvil = 1;
    public const int PosDemon = 2;
    public const int PosMinion = 3;
    public const int PosMarked = 4;
    public const int PosUnmarked = 5;

    // Report card kind codes:
    public const int CardKindOther = 0;
    public const int CardKindReport = 1;
    public const int CardKindCurseEvent = 2;

    // Testimony shape codes (_testimony_content):
    public const int TestimFallbackContent = 0;
    public const int TestimRoleInGroupGood = 1;
    public const int TestimRoleInGroupMinion = 2;
    public const int TestimRoleInGroupAlignEvil = 3;
    public const int TestimRoleInGroupAlignGood = 4;
    public const int TestimPingYes = 5;
    public const int TestimPingNo = 6;
    public const int TestimSecretPair = 7;

    // Report content mode codes (_report_content):
    public const int ContentTrivialTrue = 0;
    public const int ContentAlwaysFalse = 1;
    public const int ContentWardenSaved = 2;
    public const int ContentLiveRumor = 3;
    public const int ContentFixtureRumor = 4;
    public const int ContentSiteGroup = 5;
    public const int ContentSurveyor = 6;
    public const int ContentParityGroup = 7;
    public const int ContentChronicler = 8;
    public const int ContentAugur = 9;
    public const int ContentMonitor = 10;          // targetOrSecret: bit0 walked, bits1-2 role class (0 none, 1 minion, 2 demon, 3 other)
    public const int ContentConfessorForgot = 11;  // every chip: evil or Marked, never the source

    // Conclusion type codes (holds / _build_premise_mask):
    public const int ConclEvilOrSuspicious = 0;
    public const int ConclGoodOrRole = 1;
    public const int ConclNotRole = 2;
    public const int ConclLied = 3;
    public const int ConclTruthful = 4;
    public const int ConclDemon = 5;
    public const int ConclMinion = 6;
    public const int ConclNotDemon = 7;
    public const int ConclMarked = 8;
    public const int ConclSecretMod = 9;
    public const int ConclOther = 10;

    [MethodImpl(MethodImplOptions.AggressiveInlining)]
    public static bool EvilIndex(WorldEntry w, int index, bool convEvilAtTime)
    {
        if (index < 0)
        {
            return false;
        }
        if ((w.Evil & (1 << index)) != 0)
        {
            return true;
        }
        return convEvilAtTime && w.HasConverted && w.ConvertedRaw == index;
    }

    [MethodImpl(MethodImplOptions.AggressiveInlining)]
    public static bool PositionHolds(WorldEntry w, int personIdx, int posCode, bool convEvilAtEpoch)
    {
        switch (posCode)
        {
            case PosDemon:
                return personIdx >= 0 && w.DemonOrMinusOne == personIdx;
            case PosMinion:
                return personIdx >= 0 && (w.Evil & (1 << personIdx)) != 0 && w.DemonOrMinusOne != personIdx;
            case PosMarked:
                return personIdx >= 0 && w.Marked == personIdx;
            case PosUnmarked:
                return personIdx >= 0 && w.Marked != personIdx;
            case PosEvil:
                return EvilIndex(w, personIdx, convEvilAtEpoch);
            default:
                return !EvilIndex(w, personIdx, convEvilAtEpoch);
        }
    }

    public static (long[] Evil, long[] Deluded, bool Plain) GetOrComputeWorldBits(int universeHandle, long[] fallbackWorlds)
    {
        var meta = SolverContext.GetOrCreateUniverseMeta(universeHandle);
        if (meta.HasWorldBits && meta.EvilBits != null && meta.DeludedBits != null)
        {
            return (meta.EvilBits, meta.DeludedBits, meta.PlainBits);
        }

        long[] worlds = SolverContext.ResolveWorlds(universeHandle, Array.Empty<int>(), fallbackWorlds);
        int n = worlds.Length;
        long[] evil = new long[n];
        long[] deluded = new long[n];
        bool plain = true;
        for (int i = 0; i < n; i++)
        {
            var w = new WorldEntry(worlds[i]);
            evil[i] = w.Evil;
            deluded[i] = (w.ModifierCode == WorldEntry.ModDelusional) ? w.Holders : 0L;
            if (w.HasConverted)
            {
                plain = false;
            }
        }

        meta.EvilBits = evil;
        meta.DeludedBits = deluded;
        meta.PlainBits = plain;
        meta.HasWorldBits = true;
        return (evil, deluded, plain);
    }

    /// <summary>
    /// Flat encoding for GDScript Solver.world_bits: [plainFlag (1 or 0), evil[0..n-1], deluded[0..n-1]].
    /// </summary>
    public static long[] ComputeWorldBitsFlat(int universeHandle, long[] fallbackWorlds)
    {
        var (evil, deluded, plain) = GetOrComputeWorldBits(universeHandle, fallbackWorlds);
        int n = evil.Length;
        long[] outBuf = new long[1 + 2 * n];
        outBuf[0] = plain ? 1L : 0L;
        Array.Copy(evil, 0, outBuf, 1, n);
        Array.Copy(deluded, 0, outBuf, 1 + n, n);
        return outBuf;
    }

    public static (int[] Rep, int[] Of) GetOrComputeSigGroups(
        int universeHandle,
        long[] fallbackWorlds,
        int nPeople,
        bool isLive)
    {
        var meta = SolverContext.GetOrCreateUniverseMeta(universeHandle);
        if (meta.HasSigGroups && meta.SigIsLive == isLive && meta.SigNPeople == nPeople && meta.SigRep != null && meta.SigOf != null)
        {
            return (meta.SigRep, meta.SigOf);
        }

        long[] worlds = SolverContext.ResolveWorlds(universeHandle, Array.Empty<int>(), fallbackWorlds);
        int n = worlds.Length;
        int[] of = new int[n];

        // Fixture worlds carry neither __key nor __i, so content_sig returns -1 for every world
        // and each world gets its own group; live curse worlds set __i = i and also get 1:1 groups.
        if (!isLive)
        {
            int[] idRep = new int[n];
            for (int i = 0; i < n; i++)
            {
                idRep[i] = i;
                of[i] = i;
            }
            meta.SigRep = idRep;
            meta.SigOf = of;
            meta.SigIsLive = isLive;
            meta.SigNPeople = nPeople;
            meta.HasSigGroups = true;
            return (idRep, of);
        }

        var index = new Dictionary<long, int>(Math.Max(64, n / Math.Max(nPeople, 1)));
        var repList = new List<int>(Math.Max(64, n / Math.Max(nPeople, 1)));
        long np1 = nPeople + 1L;

        for (int i = 0; i < n; i++)
        {
            var w = new WorldEntry(worlds[i]);
            long sig;
            if (w.HasConverted)
            {
                sig = i;
            }
            else
            {
                long wKey = WorldDomainKernel.ComputeKey(nPeople, w);
                sig = w.HasDemon ? (wKey / np1) : wKey;
            }

            int g = -1;
            if (sig >= 0 && index.TryGetValue(sig, out int found))
            {
                g = found;
            }
            if (g < 0)
            {
                g = repList.Count;
                repList.Add(i);
                if (sig >= 0)
                {
                    index[sig] = g;
                }
            }
            of[i] = g;
        }

        int[] rep = repList.ToArray();
        meta.SigRep = rep;
        meta.SigOf = of;
        meta.SigIsLive = isLive;
        meta.SigNPeople = nPeople;
        meta.HasSigGroups = true;
        return (rep, of);
    }

    /// <summary>
    /// Flat encoding for GDScript Solver.sig_groups: [rep.Length, rep[0..R-1], of[0..N-1]].
    /// </summary>
    public static int[] ComputeSigGroupsFlat(
        int universeHandle,
        long[] fallbackWorlds,
        int nPeople,
        bool isLive)
    {
        var (rep, of) = GetOrComputeSigGroups(universeHandle, fallbackWorlds, nPeople, isLive);
        int[] outBuf = new int[1 + rep.Length + of.Length];
        outBuf[0] = rep.Length;
        Array.Copy(rep, 0, outBuf, 1, rep.Length);
        Array.Copy(of, 0, outBuf, 1 + rep.Length, of.Length);
        return outBuf;
    }

    [MethodImpl(MethodImplOptions.AggressiveInlining)]
    private static bool SourceValidWorld(
        WorldEntry w,
        bool isLive,
        int cardKindCode,
        bool testimonyOnly,
        int sourceIdx,
        bool giftTimeAndAliveOk,
        bool convEvilAtCheck)
    {
        if (cardKindCode != CardKindReport)
        {
            return true;
        }
        if (testimonyOnly)
        {
            return !EvilIndex(w, sourceIdx, convEvilAtCheck);
        }
        if (EvilIndex(w, sourceIdx, convEvilAtCheck))
        {
            return false;
        }
        if (isLive)
        {
            if (!giftTimeAndAliveOk || !WorldDomainKernel.Healthy(w.Raw, sourceIdx))
            {
                return false;
            }
        }
        return true;
    }

    public static byte[] EvaluateValidTable(
        int universeHandle,
        long[] fallbackWorlds,
        int nPeople,
        bool isLive,
        int cardKindCode,
        bool testimonyOnly,
        int sourceIdx,
        bool giftTimeAndAliveOk,
        bool convEvilAtCheck)
    {
        long[] worlds = SolverContext.ResolveWorlds(universeHandle, Array.Empty<int>(), fallbackWorlds);
        int n = worlds.Length;
        byte[] t = new byte[n];

        if (cardKindCode != CardKindReport)
        {
            Array.Fill(t, (byte)1);
            return t;
        }

        if (testimonyOnly)
        {
            for (int i = 0; i < n; i++)
            {
                var w = new WorldEntry(worlds[i]);
                t[i] = !EvilIndex(w, sourceIdx, convEvilAtCheck) ? (byte)1 : (byte)0;
            }
            return t;
        }

        if (isLive && !giftTimeAndAliveOk)
        {
            return t;
        }

        var (evil, deluded, plain) = GetOrComputeWorldBits(universeHandle, worlds);
        if (isLive && plain)
        {
            if (sourceIdx >= 0)
            {
                long bit = 1L << sourceIdx;
                for (int i = 0; i < n; i++)
                {
                    t[i] = ((evil[i] & bit) != 0L || (deluded[i] & bit) != 0L) ? (byte)0 : (byte)1;
                }
            }
            return t;
        }

        var (rep, of) = GetOrComputeSigGroups(universeHandle, worlds, nPeople, isLive);
        int gCount = rep.Length;
        byte[] answers = new byte[gCount];
        for (int g = 0; g < gCount; g++)
        {
            var w = new WorldEntry(worlds[rep[g]]);
            answers[g] = SourceValidWorld(w, isLive, cardKindCode, false, sourceIdx, giftTimeAndAliveOk, convEvilAtCheck)
                ? (byte)1
                : (byte)0;
        }
        for (int i = 0; i < n; i++)
        {
            t[i] = answers[of[i]];
        }
        return t;
    }

    private static bool EvalReportContentWorld(
        WorldEntry w,
        int nPeople,
        bool isLive,
        int contentMode,
        int sourceIdx,
        bool convEvilAtObs,
        int pairOrGroupMask,
        int targetOrSecretCode,
        bool hasAnsPos,
        int ansPosMask,
        bool ansPosHasUnknown,
        int[] reqMarkedIndices,
        int[] chosenBlockMasks,
        bool chosenBlocksInvalid,
        int[] allBlockMasks)
    {
        switch (contentMode)
        {
            case ContentTrivialTrue:
                return true;

            case ContentAlwaysFalse:
                return false;

            case ContentWardenSaved:
                return targetOrSecretCode < 0 || (w.Evil & (1 << targetOrSecretCode)) == 0;

            case ContentLiveRumor:
            {
                int holders = w.Holders;
                if (sourceIdx >= 0 && (holders & ~(1 << sourceIdx)) == 0)
                {
                    return false;
                }
                if (w.EffectiveModifier != targetOrSecretCode || targetOrSecretCode < 0)
                {
                    return false;
                }
                if ((holders & pairOrGroupMask) == 0)
                {
                    return false;
                }
                if (hasAnsPos && (holders & ansPosMask) != ansPosMask)
                {
                    return false;
                }
                return true;
            }

            case ContentFixtureRumor:
            {
                int m = w.Marked;
                if (m < 0 || m >= nPeople)
                {
                    return false;
                }
                int mBit = 1 << m;
                if ((pairOrGroupMask & mBit) == 0)
                {
                    return false;
                }
                return !hasAnsPos || (ansPosMask & mBit) != 0;
            }

            case ContentSiteGroup:
            case ContentSurveyor:
            {
                bool isSurveyor = contentMode == ContentSurveyor;
                if (ansPosHasUnknown)
                {
                    return false;
                }
                if (!isSurveyor && (chosenBlockMasks.Length > 0 || chosenBlocksInvalid))
                {
                    return false;
                }
                if (chosenBlocksInvalid)
                {
                    return false;
                }
                for (int r = 0; r < reqMarkedIndices.Length; r++)
                {
                    if (reqMarkedIndices[r] != w.Marked)
                    {
                        return false;
                    }
                }

                int evilBits = w.Evil;
                if (w.HasConverted && w.ConvertedRaw >= 0 && EvilIndex(w, w.ConvertedRaw, convEvilAtObs))
                {
                    evilBits |= (1 << w.ConvertedRaw);
                }

                int startMarkReads = reqMarkedIndices.Length > 0 ? 1 : 0;
                for (int mr = startMarkReads; mr <= 1; mr++)
                {
                    bool markReads = mr == 1;
                    int posMask = evilBits | ((markReads && w.Marked >= 0) ? (1 << w.Marked) : 0);
                    if ((posMask & ansPosMask) != ansPosMask)
                    {
                        continue;
                    }

                    bool blocksOk = true;
                    for (int cb = 0; cb < chosenBlockMasks.Length; cb++)
                    {
                        if ((posMask & chosenBlockMasks[cb]) == 0)
                        {
                            blocksOk = false;
                            break;
                        }
                    }
                    if (!blocksOk)
                    {
                        continue;
                    }

                    int count = 0;
                    if (isSurveyor)
                    {
                        for (int b = 0; b < allBlockMasks.Length; b++)
                        {
                            if ((posMask & allBlockMasks[b]) != 0)
                            {
                                count++;
                            }
                        }
                    }
                    else
                    {
                        count = BitOperations.PopCount((uint)(posMask & pairOrGroupMask));
                    }

                    if (count == targetOrSecretCode)
                    {
                        return true;
                    }
                }
                return false;
            }

            case ContentParityGroup:
            {
                if (ansPosHasUnknown || chosenBlocksInvalid || chosenBlockMasks.Length > 0)
                {
                    return false;
                }
                if (hasAnsPos && (ansPosMask & ~pairOrGroupMask) != 0)
                {
                    return false;
                }
                for (int r = 0; r < reqMarkedIndices.Length; r++)
                {
                    int rm = reqMarkedIndices[r];
                    if (rm != w.Marked || (pairOrGroupMask & (1 << rm)) == 0)
                    {
                        return false;
                    }
                }

                int groupSize = BitOperations.PopCount((uint)pairOrGroupMask);
                if (groupSize < 2)
                {
                    return false;
                }

                int evilBits = w.Evil;
                if (w.HasConverted && w.ConvertedRaw >= 0 && EvilIndex(w, w.ConvertedRaw, convEvilAtObs))
                {
                    evilBits |= (1 << w.ConvertedRaw);
                }

                bool wantSame = targetOrSecretCode != 0;
                int startMarkReads = reqMarkedIndices.Length > 0 ? 1 : 0;
                for (int mr = startMarkReads; mr <= 1; mr++)
                {
                    bool markReads = mr == 1;
                    int posMask = evilBits | ((markReads && w.Marked >= 0) ? (1 << w.Marked) : 0);
                    if (hasAnsPos && (posMask & ansPosMask) != ansPosMask)
                    {
                        continue;
                    }
                    int cnt = BitOperations.PopCount((uint)(posMask & pairOrGroupMask));
                    bool isSame = (cnt == 0 || cnt == groupSize);
                    if (isSame == wantSame)
                    {
                        return true;
                    }
                }
                return false;
            }

            case ContentChronicler:
            {
                if (ansPosHasUnknown || chosenBlocksInvalid || chosenBlockMasks.Length > 0 || reqMarkedIndices.Length > 0)
                {
                    return false;
                }
                if (BitOperations.PopCount((uint)pairOrGroupMask) != 3)
                {
                    return false;
                }
                if (isLive && sourceIdx >= 0 && (w.Holders & ~(1 << sourceIdx)) == 0)
                {
                    return false;
                }
                if (sourceIdx >= 0 && (pairOrGroupMask & (1 << sourceIdx)) != 0)
                {
                    return false;
                }
                int allMask = (1 << nPeople) - 1;
                int demonIdx = w.DemonOrMinusOne;
                int demonBit = demonIdx >= 0 ? (1 << demonIdx) : 0;
                int minionMask = w.Evil & ~demonBit;
                int secretMask = isLive
                    ? (w.Holders & ~w.Evil)
                    : ((w.Marked >= 0 ? (1 << w.Marked) : 0) & ~w.Evil);
                int folkMask = allMask & ~w.Evil & ~secretMask;
                if ((pairOrGroupMask & minionMask) == 0
                    || (pairOrGroupMask & secretMask) == 0
                    || (pairOrGroupMask & folkMask) == 0)
                {
                    return false;
                }
                if (hasAnsPos && ((ansPosMask & pairOrGroupMask) != ansPosMask || (ansPosMask & minionMask) != ansPosMask))
                {
                    return false;
                }
                return true;
            }

            case ContentMonitor:
            {
                if (!hasAnsPos)
                {
                    return true;
                }
                if (ansPosHasUnknown)
                {
                    return false;
                }
                bool walked = (targetOrSecretCode & 1) != 0;
                int cls = (targetOrSecretCode >> 1) & 3;
                if (!walked || cls == 0)
                {
                    return false;
                }
                for (int pi = 0; pi < nPeople; pi++)
                {
                    if ((ansPosMask & (1 << pi)) == 0)
                    {
                        continue;
                    }
                    if (sourceIdx >= 0 && pi == sourceIdx)
                    {
                        return false;
                    }
                    bool isEvil = (w.Evil & (1 << pi)) != 0;
                    bool isMarked = w.Marked == pi;
                    if (cls == 1 && !isEvil && !isMarked)
                    {
                        return false;
                    }
                    if (cls == 2)
                    {
                        bool isDemon = w.HasDemon ? w.DemonOrMinusOne == pi : isEvil;
                        if (!isDemon && !isMarked)
                        {
                            return false;
                        }
                    }
                    if (cls == 3 && isEvil)
                    {
                        return false;
                    }
                }
                return true;
            }

            case ContentConfessorForgot:
            {
                if (!hasAnsPos)
                {
                    return true;
                }
                if (ansPosHasUnknown)
                {
                    return false;
                }
                for (int pi = 0; pi < nPeople; pi++)
                {
                    if ((ansPosMask & (1 << pi)) == 0)
                    {
                        continue;
                    }
                    if ((sourceIdx >= 0 && pi == sourceIdx) || ((w.Evil & (1 << pi)) == 0 && w.Marked != pi))
                    {
                        return false;
                    }
                }
                return true;
            }

            case ContentAugur:
            {
                if (ansPosHasUnknown || chosenBlocksInvalid || chosenBlockMasks.Length > 0 || reqMarkedIndices.Length > 0)
                {
                    return false;
                }
                int demonIdx = w.DemonOrMinusOne;
                if (sourceIdx >= 0 && demonIdx == sourceIdx)
                {
                    return false;
                }
                if (hasAnsPos)
                {
                    if (targetOrSecretCode == 0)
                    {
                        return false;
                    }
                    if (sourceIdx >= 0 && (ansPosMask & (1 << sourceIdx)) != 0)
                    {
                        return false;
                    }
                    int regDemonMask = (w.HasDemon ? (demonIdx >= 0 ? (1 << demonIdx) : 0) : w.Evil)
                        | (w.Marked >= 0 ? (1 << w.Marked) : 0);
                    if ((ansPosMask & regDemonMask) != ansPosMask)
                    {
                        return false;
                    }
                }
                return true;
            }

            default:
                return true;
        }
    }

    private static bool EvalTestimonyContentWorld(
        WorldEntry w,
        int nPeople,
        bool isLive,
        bool preTestimonyFail,
        int testimonyShape,
        bool markedRegisters,
        int testimonyMask,
        int secretModCode,
        int fallbackContentMode,
        int sourceIdx,
        bool convEvilAtObs,
        int fallbackPairOrGroupMask,
        int fallbackTargetOrSecretCode,
        int[] allBlockMasks)
    {
        if (preTestimonyFail)
        {
            return false;
        }

        int evil = w.Evil;
        if (w.HasConverted && EvilIndex(w, w.ConvertedRaw, convEvilAtObs))
        {
            evil |= (1 << w.ConvertedRaw);
        }

        switch (testimonyShape)
        {
            case TestimRoleInGroupGood:
                return (testimonyMask & ~w.Evil) != 0;

            case TestimRoleInGroupMinion:
            {
                int demonIdx = w.DemonOrMinusOne;
                int demonBit = demonIdx >= 0 ? (1 << demonIdx) : 0;
                return (testimonyMask & w.Evil & ~demonBit) != 0;
            }

            case TestimRoleInGroupAlignEvil:
            {
                bool readsEvil = (w.Evil & testimonyMask) != 0
                    || (markedRegisters && w.Marked >= 0 && (testimonyMask & (1 << w.Marked)) != 0);
                return readsEvil;
            }

            case TestimRoleInGroupAlignGood:
                return (w.Evil & testimonyMask) == 0;

            case TestimPingYes:
            {
                int demonIdx = w.DemonOrMinusOne;
                bool demon = demonIdx >= 0 && (testimonyMask & (1 << demonIdx)) != 0;
                return demon || (testimonyMask & ~evil) != 0;
            }

            case TestimPingNo:
            {
                int demonIdx = w.DemonOrMinusOne;
                bool demon = demonIdx >= 0 && (testimonyMask & (1 << demonIdx)) != 0;
                return !demon;
            }

            case TestimSecretPair:
            {
                int effHolders = isLive ? w.Holders : (w.Marked >= 0 ? (1 << w.Marked) : 0);
                return secretModCode >= 0 && w.EffectiveModifier == secretModCode && (effHolders & testimonyMask) != 0;
            }

            default:
            {
                int fbSourceIdx = (fallbackContentMode == ContentChronicler || fallbackContentMode == ContentAugur
                    || fallbackContentMode == ContentMonitor || fallbackContentMode == ContentConfessorForgot)
                    ? -1
                    : sourceIdx;
                return EvalReportContentWorld(
                    w,
                    nPeople,
                    isLive,
                    fallbackContentMode,
                    fbSourceIdx,
                    convEvilAtObs,
                    fallbackPairOrGroupMask,
                    fallbackTargetOrSecretCode,
                    false,
                    0,
                    false,
                    Array.Empty<int>(),
                    Array.Empty<int>(),
                    false,
                    allBlockMasks);
            }
        }
    }

    public static byte[] EvaluateReportTable(
        int universeHandle,
        long[] fallbackWorlds,
        int nPeople,
        bool isLive,
        int[] specInts,
        int[] reqMarkedIndices,
        int[] chosenBlockMasks,
        int[] allBlockMasks)
    {
        // specInts layout (18 ints):
        //  [0] cardKindCode (0=other, 1=report, 2=curse_event)
        //  [1] testimonyOnly (0/1)
        //  [2] sourceIdx
        //  [3] giftTimeAndAliveOk (0/1)
        //  [4] convEvilAtStmt (0/1)
        //  [5] convEvilAtObs (0/1)
        //  [6] contentMode (Content*)
        //  [7] pairOrGroupMask
        //  [8] targetOrSecretCode
        //  [9] hasAnsPos (0/1)
        // [10] ansPosMask
        // [11] ansPosHasUnknown (0/1)
        // [12] chosenBlocksInvalid (0/1)
        // [13] preTestimonyFail (0/1)
        // [14] testimonyShape (Testim*)
        // [15] markedRegisters (0/1)
        // [16] testimonyMask
        // [17] testimonySecretModCode
        long[] worlds = SolverContext.ResolveWorlds(universeHandle, Array.Empty<int>(), fallbackWorlds);
        int n = worlds.Length;
        byte[] accepted = new byte[n];

        int cardKindCode = specInts[0];
        bool testimonyOnly = specInts[1] != 0;
        int sourceIdx = specInts[2];
        bool giftTimeAndAliveOk = specInts[3] != 0;
        bool convEvilAtStmt = specInts[4] != 0;
        bool convEvilAtObs = specInts[5] != 0;
        int contentMode = specInts[6];
        int pairOrGroupMask = specInts[7];
        int targetOrSecretCode = specInts[8];
        bool hasAnsPos = specInts[9] != 0;
        int ansPosMask = specInts[10];
        bool ansPosHasUnknown = specInts[11] != 0;
        bool chosenBlocksInvalid = specInts[12] != 0;
        bool preTestimonyFail = specInts[13] != 0;
        int testimonyShape = specInts[14];
        bool markedRegisters = specInts[15] != 0;
        int testimonyMask = specInts[16];
        int testimonySecretModCode = specInts[17];

        if (testimonyOnly && cardKindCode == CardKindReport)
        {
            for (int i = 0; i < n; i++)
            {
                var w = new WorldEntry(worlds[i]);
                bool ok = SourceValidWorld(w, isLive, CardKindReport, true, sourceIdx, giftTimeAndAliveOk, convEvilAtStmt)
                    && EvalTestimonyContentWorld(
                        w,
                        nPeople,
                        isLive,
                        preTestimonyFail,
                        testimonyShape,
                        markedRegisters,
                        testimonyMask,
                        testimonySecretModCode,
                        contentMode,
                        sourceIdx,
                        convEvilAtObs,
                        pairOrGroupMask,
                        targetOrSecretCode,
                        allBlockMasks);
                accepted[i] = ok ? (byte)1 : (byte)0;
            }
            return accepted;
        }

        // Chronicler and Augur depend on world.Demon, which sig_groups collapses; evaluate per world.
        if (cardKindCode == CardKindReport && (contentMode == ContentChronicler || contentMode == ContentAugur || contentMode == ContentMonitor))
        {
            byte[] valid = EvaluateValidTable(
                universeHandle,
                worlds,
                nPeople,
                isLive,
                CardKindReport,
                false,
                sourceIdx,
                giftTimeAndAliveOk,
                convEvilAtObs);
            for (int i = 0; i < n; i++)
            {
                if (valid[i] == 0)
                {
                    accepted[i] = 0;
                }
                else
                {
                    var w = new WorldEntry(worlds[i]);
                    accepted[i] = EvalReportContentWorld(
                        w,
                        nPeople,
                        isLive,
                        contentMode,
                        sourceIdx,
                        convEvilAtObs,
                        pairOrGroupMask,
                        targetOrSecretCode,
                        hasAnsPos,
                        ansPosMask,
                        ansPosHasUnknown,
                        reqMarkedIndices,
                        chosenBlockMasks,
                        chosenBlocksInvalid,
                        allBlockMasks) ? (byte)1 : (byte)0;
                }
            }
            return accepted;
        }

        var (rep, of) = GetOrComputeSigGroups(universeHandle, worlds, nPeople, isLive);
        int gCount = rep.Length;
        byte[] answers = new byte[gCount];

        if (cardKindCode == CardKindReport)
        {
            byte[] valid = EvaluateValidTable(
                universeHandle,
                worlds,
                nPeople,
                isLive,
                CardKindReport,
                false,
                sourceIdx,
                giftTimeAndAliveOk,
                convEvilAtObs);
            bool trivial = contentMode == ContentTrivialTrue;
            for (int g = 0; g < gCount; g++)
            {
                int rIdx = rep[g];
                if (valid[rIdx] == 0)
                {
                    answers[g] = 0;
                }
                else if (trivial)
                {
                    answers[g] = 1;
                }
                else
                {
                    var w = new WorldEntry(worlds[rIdx]);
                    answers[g] = EvalReportContentWorld(
                        w,
                        nPeople,
                        isLive,
                        contentMode,
                        sourceIdx,
                        convEvilAtObs,
                        pairOrGroupMask,
                        targetOrSecretCode,
                        hasAnsPos,
                        ansPosMask,
                        ansPosHasUnknown,
                        reqMarkedIndices,
                        chosenBlockMasks,
                        chosenBlocksInvalid,
                        allBlockMasks) ? (byte)1 : (byte)0;
                }
            }
        }
        else if (cardKindCode == CardKindCurseEvent)
        {
            for (int g = 0; g < gCount; g++)
            {
                if (!hasAnsPos)
                {
                    answers[g] = 1;
                }
                else
                {
                    var w = new WorldEntry(worlds[rep[g]]);
                    int convIdx = w.ConvertedOrMinusOne;
                    if (convIdx < 0 && nPeople > 0)
                    {
                        convIdx = nPeople - 1;
                    }
                    answers[g] = (convIdx >= 0 && (ansPosMask & (1 << convIdx)) != 0) ? (byte)1 : (byte)0;
                }
            }
        }
        else
        {
            Array.Fill(answers, (byte)1);
        }

        for (int i = 0; i < n; i++)
        {
            accepted[i] = answers[of[i]];
        }
        return accepted;
    }

    /// <summary>
    /// 1:1 port of Solver._solve candidate filtering (report tables + alignment/position/timed_good filters).
    /// Returns ascending universe indices of surviving worlds before Roles.fits_table.
    /// posSpecs is stride-3: [personIdx, posCode, convEvilAtEpochFlag].
    /// timedGoodSpecs is stride-2: [personIdx, convEvilAtFactTimeFlag].
    /// </summary>
    public static int[] FilterSolveCandidates(
        int universeHandle,
        long[] fallbackWorlds,
        int tableCount,
        byte[] flatTables,
        int mustBeGoodMask,
        int mustBeEvilMask,
        int markedReq,
        int[] posSpecs,
        int[] timedGoodSpecs)
    {
        long[] worlds = SolverContext.ResolveWorlds(universeHandle, Array.Empty<int>(), fallbackWorlds);
        int n = worlds.Length;
        if (n == 0)
        {
            return Array.Empty<int>();
        }

        int posCount = posSpecs.Length / 3;
        int tgCount = timedGoodSpecs.Length / 2;
        var kept = new List<int>(n);

        for (int i = 0; i < n; i++)
        {
            bool accepted = true;
            for (int t = 0; t < tableCount; t++)
            {
                if (flatTables[t * n + i] == 0)
                {
                    accepted = false;
                    break;
                }
            }
            if (!accepted)
            {
                continue;
            }

            var w = new WorldEntry(worlds[i]);
            if (mustBeGoodMask != 0 && (w.Evil & mustBeGoodMask) != 0)
            {
                continue;
            }
            if (mustBeEvilMask != 0 && (w.Evil & mustBeEvilMask) != mustBeEvilMask)
            {
                continue;
            }
            if (markedReq >= 0 && w.Marked != markedReq)
            {
                continue;
            }

            for (int p = 0; p < posCount; p++)
            {
                int pIdx = posSpecs[p * 3];
                int pCode = posSpecs[p * 3 + 1];
                bool convEvil = posSpecs[p * 3 + 2] != 0;
                if (!PositionHolds(w, pIdx, pCode, convEvil))
                {
                    accepted = false;
                    break;
                }
            }
            if (!accepted)
            {
                continue;
            }

            for (int g = 0; g < tgCount; g++)
            {
                int pIdx = timedGoodSpecs[g * 2];
                bool convEvil = timedGoodSpecs[g * 2 + 1] != 0;
                if (EvilIndex(w, pIdx, convEvil))
                {
                    accepted = false;
                    break;
                }
            }
            if (accepted)
            {
                kept.Add(i);
            }
        }

        return kept.ToArray();
    }

    /// <summary>
    /// 1:1 port of Solver._positions over an arbitrary packed or handle-indexed world slice.
    /// Returns subset indices (0..sliceLen-1) that match all position and temporal_position filters.
    /// </summary>
    /// <summary>
    /// ReadingChallenges._fraction's world loop (Nov 4): over the listener's reference worlds
    /// (universe indices), keep those where the report's source is good at the epoch and
    /// healthy; count distinct alignment/modifier layouts (ignoring the Demon's identity),
    /// and those where the report and its role claim also hold. Returns [numerator, denominator].
    /// </summary>
    public static int[] ReadingFraction(
        int universeHandle,
        int[] refIndices,
        long[] fallbackWorlds,
        int nPeople,
        int sourceIdx,
        bool convAtEpoch,
        byte[] reportTable,
        byte[] roleTable,
        bool compatible)
    {
        if (refIndices.Length == 0)
        {
            return new[] { 0, 0 }; // ResolveWorlds reads an empty subset as "all worlds"
        }
        long[] worlds = SolverContext.ResolveWorlds(universeHandle, refIndices, fallbackWorlds);
        var denominator = new HashSet<long>();
        var numerator = new HashSet<long>();
        long span = 1L << nPeople;
        for (int k = 0; k < worlds.Length; k++)
        {
            var w = new WorldEntry(worlds[k]);
            if (!PositionHolds(w, sourceIdx, PosGood, convAtEpoch) || !WorldDomainKernel.Healthy(worlds[k], sourceIdx))
            {
                continue;
            }
            int holders = w.Holders;
            if (holders == 0 && w.Marked >= 0)
            {
                holders = 1 << w.Marked; // fixture worlds carry no holders: the marked one
            }
            long baseKey = ((long)w.Evil * 5 + w.EffectiveModifier) * span + holders;
            denominator.Add(baseKey);
            int ui = refIndices[k];
            if (compatible && reportTable[ui] != 0 && roleTable[ui] != 0)
            {
                numerator.Add(baseKey);
            }
        }
        return new[] { numerator.Count, denominator.Count };
    }

    public static int[] FilterPositionsSubset(
        int universeHandle,
        int[] subsetIndices,
        long[] fallbackWorlds,
        int mustBeGoodMask,
        int mustBeEvilMask,
        int markedReq,
        int[] posSpecs)
    {
        long[] worlds = SolverContext.ResolveWorlds(universeHandle, subsetIndices, fallbackWorlds);
        int n = worlds.Length;
        int posCount = posSpecs.Length / 3;
        var kept = new List<int>(n);

        for (int i = 0; i < n; i++)
        {
            var w = new WorldEntry(worlds[i]);
            if (mustBeGoodMask != 0 && (w.Evil & mustBeGoodMask) != 0)
            {
                continue;
            }
            if (mustBeEvilMask != 0 && (w.Evil & mustBeEvilMask) != mustBeEvilMask)
            {
                continue;
            }
            if (markedReq >= 0 && w.Marked != markedReq)
            {
                continue;
            }

            bool ok = true;
            for (int p = 0; p < posCount; p++)
            {
                if (!PositionHolds(w, posSpecs[p * 3], posSpecs[p * 3 + 1], posSpecs[p * 3 + 2] != 0))
                {
                    ok = false;
                    break;
                }
            }
            if (ok)
            {
                kept.Add(i);
            }
        }

        return kept.ToArray();
    }

    /// <summary>
    /// 1:1 port of fixture Solver._movement over 0..(1 &lt;&lt; nPeople) - 1.
    /// nightSpecs is stride-4 per night: [night, ownOutState (-1=unset, 0=false, 1=true), cardStart, cardCount].
    /// cardSpecs is stride-5 per relevant card: [kindCode (1=req_only, 2=alibi, 3=lamp_count), reqMask, hasInvalidReq (0/1), alibiIdx, lampSourceIdx, lampCount] -> stride 6.
    /// Returns [okayFlag, night0, compatible0, forcedOutMask0, ...].
    /// </summary>
    public static int[] EvaluateFixtureMovement(
        int nPeople,
        int ownPersonIdx,
        int[] nightSpecs,
        int[] cardSpecs)
    {
        int nightCount = nightSpecs.Length / 4;
        var outList = new List<int>(1 + nightCount * 3) { 1 };
        int limit = 1 << nPeople;
        int allMask = limit - 1;
        bool allOkay = true;

        for (int ni = 0; ni < nightCount; ni++)
        {
            int night = nightSpecs[ni * 4];
            int ownOutState = nightSpecs[ni * 4 + 1];
            int cStart = nightSpecs[ni * 4 + 2];
            int cCount = nightSpecs[ni * 4 + 3];
            if (cCount <= 0)
            {
                continue;
            }

            int compatCount = 0;
            int forcedMask = allMask;

            for (int mask = 0; mask < limit; mask++)
            {
                if (ownPersonIdx >= 0 && ownOutState >= 0)
                {
                    bool isOut = (mask & (1 << ownPersonIdx)) != 0;
                    if (isOut != (ownOutState == 1))
                    {
                        continue;
                    }
                }

                bool valid = true;
                for (int ci = 0; ci < cCount; ci++)
                {
                    int off = (cStart + ci) * 6;
                    int kindCode = cardSpecs[off];
                    int reqMask = cardSpecs[off + 1];
                    bool hasInvalidReq = cardSpecs[off + 2] != 0;
                    int alibiIdx = cardSpecs[off + 3];
                    int lampSrcIdx = cardSpecs[off + 4];
                    int lampCount = cardSpecs[off + 5];

                    if (kindCode == 2)
                    {
                        if (alibiIdx >= 0 && (mask & (1 << alibiIdx)) != 0)
                        {
                            valid = false;
                        }
                    }
                    else if (kindCode == 3)
                    {
                        int srcBit = lampSrcIdx >= 0 ? (1 << lampSrcIdx) : 0;
                        if (BitOperations.PopCount((uint)(mask & ~srcBit)) != lampCount)
                        {
                            valid = false;
                        }
                    }

                    if (hasInvalidReq || (mask & reqMask) != reqMask)
                    {
                        valid = false;
                    }

                    if (!valid)
                    {
                        break;
                    }
                }

                if (valid)
                {
                    compatCount++;
                    forcedMask &= mask;
                }
            }

            if (compatCount == 0)
            {
                forcedMask = 0;
                allOkay = false;
            }

            outList.Add(night);
            outList.Add(compatCount);
            outList.Add(forcedMask);
        }

        outList[0] = allOkay ? 1 : 0;
        return outList.ToArray();
    }

    public static byte[] ComputeQuestionTable(
        int universeHandle,
        long[] fallbackWorlds,
        byte[] accepted,
        byte[] roles,
        bool isMisled,
        bool isSeerYes,
        int pairMask,
        bool pairHasMinusOne,
        int sourceIdx,
        bool convEvilAtObs)
    {
        long[] worlds = SolverContext.ResolveWorlds(universeHandle, Array.Empty<int>(), fallbackWorlds);
        int n = worlds.Length;
        byte[] outBuf = new byte[n];

        for (int i = 0; i < n; i++)
        {
            bool wrong = accepted[i] == 0 || roles[i] == 0;
            if (isMisled)
            {
                var w = new WorldEntry(worlds[i]);
                bool demonInPair = w.DemonRaw < 0
                    ? pairHasMinusOne
                    : ((pairMask & (1 << w.DemonRaw)) != 0);
                bool registration = isSeerYes && w.HasDemon && !demonInPair;
                wrong = !EvilIndex(w, sourceIdx, convEvilAtObs) && (wrong || registration);
            }
            outBuf[i] = wrong ? (byte)1 : (byte)0;
        }
        return outBuf;
    }

    public static byte[] ComputePremiseMask(
        int universeHandle,
        long[] fallbackWorlds,
        bool isLive,
        int conclTypeCode,
        int targetIdx,
        int secretModCode,
        bool convEvilAtConcl)
    {
        long[] worlds = SolverContext.ResolveWorlds(universeHandle, Array.Empty<int>(), fallbackWorlds);
        int n = worlds.Length;
        byte[] m = new byte[n];
        if (targetIdx < 0 || conclTypeCode == ConclOther)
        {
            return m;
        }

        var (evil, _, plain) = GetOrComputeWorldBits(universeHandle, worlds);
        if (plain && (conclTypeCode == ConclEvilOrSuspicious || conclTypeCode == ConclGoodOrRole))
        {
            long bit = 1L << targetIdx;
            byte want = conclTypeCode == ConclGoodOrRole ? (byte)0 : (byte)1;
            byte alt = (byte)(1 - want);
            for (int i = 0; i < n; i++)
            {
                m[i] = (evil[i] & bit) != 0L ? want : alt;
            }
            return m;
        }

        int tBit = 1 << targetIdx;
        for (int i = 0; i < n; i++)
        {
            var w = new WorldEntry(worlds[i]);
            bool holds = conclTypeCode switch
            {
                ConclEvilOrSuspicious => EvilIndex(w, targetIdx, convEvilAtConcl),
                ConclGoodOrRole => !EvilIndex(w, targetIdx, convEvilAtConcl),
                ConclNotRole => EvilIndex(w, targetIdx, convEvilAtConcl),
                ConclLied => EvilIndex(w, targetIdx, convEvilAtConcl),
                ConclTruthful => !EvilIndex(w, targetIdx, convEvilAtConcl),
                ConclDemon => PositionHolds(w, targetIdx, PosDemon, convEvilAtConcl),
                ConclMinion => PositionHolds(w, targetIdx, PosMinion, convEvilAtConcl),
                ConclNotDemon => !PositionHolds(w, targetIdx, PosDemon, convEvilAtConcl),
                ConclMarked => w.Marked == targetIdx,
                ConclSecretMod => secretModCode >= 0
                    && w.EffectiveModifier == secretModCode
                    && ((isLive ? w.Holders : (w.Marked >= 0 ? (1 << w.Marked) : 0)) & tBit) != 0,
                _ => false
            };
            m[i] = holds ? (byte)1 : (byte)0;
        }
        return m;
    }

    public static int ComputeUnresolvedMask(long[] packedWorlds, int nPeople)
    {
        if (packedWorlds.Length == 0 || nPeople <= 0)
        {
            return 0;
        }
        int allMask = (1 << nPeople) - 1;
        int anyEvil = 0;
        int anyGood = 0;
        for (int i = 0; i < packedWorlds.Length; i++)
        {
            int e = new WorldEntry(packedWorlds[i]).Evil;
            anyEvil |= e;
            anyGood |= ~e & allMask;
            if ((anyEvil & anyGood) == allMask)
            {
                break;
            }
        }
        return anyEvil & anyGood;
    }
}
