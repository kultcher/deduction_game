using System;
using System.Collections.Generic;
using System.Runtime.CompilerServices;

namespace Demonologist.Workshop;

/// <summary>
/// Slice C3 1:1 bit-exact port of workshop/case_eval.gd equivalence-class compilation,
/// sparse private-reading states, listener team priors, class likelihoods, and full
/// posterior marginalization (including _people, _joint, _pivotal, and _expand).
/// Preserves exact IEEE-754 double evaluation order (--tol 0).
/// </summary>
internal static class CaseEvalKernel
{
    internal sealed class CompiledCaseEntry
    {
        public readonly int UniverseHandle;
        public readonly int NPeople;
        public readonly int K;
        public readonly int[] Team;
        public readonly int[] Group;
        public readonly int[] GroupBits;
        public readonly int[] Rep;
        public readonly double[] Count;
        public readonly byte[] Premise;
        public readonly byte[] Dead;
        public readonly byte[] States;
        public readonly int[] ClassOf;
        public readonly byte[] TestHold;
        public readonly int NumTests;
        public readonly double[] Move;
        public readonly bool MovementOk;
        public readonly double[] Q;

        public CompiledCaseEntry(
            int universeHandle,
            int nPeople,
            int k,
            int[] team,
            int[] group,
            int[] groupBits,
            int[] rep,
            double[] count,
            byte[] premise,
            byte[] dead,
            byte[] states,
            int[] classOf,
            byte[] testHold,
            int numTests,
            double[] move,
            bool movementOk,
            double[] q)
        {
            UniverseHandle = universeHandle;
            NPeople = nPeople;
            K = k;
            Team = team;
            Group = group;
            GroupBits = groupBits;
            Rep = rep;
            Count = count;
            Premise = premise;
            Dead = dead;
            States = states;
            ClassOf = classOf;
            TestHold = testHold;
            NumTests = numTests;
            Move = move;
            MovementOk = movementOk;
            Q = q;
        }
    }

    [MethodImpl(MethodImplOptions.AggressiveInlining)]
    private static double GodotClamp(double a, double min, double max) =>
        a < min ? min : (a > max ? max : a);

    [MethodImpl(MethodImplOptions.AggressiveInlining)]
    private static double GodotMax(double a, double b) => a > b ? a : b;

    [MethodImpl(MethodImplOptions.AggressiveInlining)]
    private static double GodotMin(double a, double b) => a < b ? a : b;

    [MethodImpl(MethodImplOptions.AggressiveInlining)]
    public static double Factor(int st, double err, double q) => st switch
    {
        0 => (1.0 - err) + err * q,
        1 => err * q,
        _ => q
    };

    [MethodImpl(MethodImplOptions.AggressiveInlining)]
    private static double Odds(double p)
    {
        p = GodotClamp(p, 1e-9, 1.0 - 1e-9);
        return p / (1.0 - p);
    }

    [MethodImpl(MethodImplOptions.AggressiveInlining)]
    private static int CategoryRank(double lr, double lrWeak, double lrModerate, double lrStrong)
    {
        if (lr < 1.0 / lrWeak)
        {
            return 0;
        }
        if (lr < lrWeak)
        {
            return 1;
        }
        if (lr < lrModerate)
        {
            return 2;
        }
        if (lr < lrStrong)
        {
            return 3;
        }
        return 4;
    }

    [MethodImpl(MethodImplOptions.AggressiveInlining)]
    private static double AugurSlotProb(int codes, int personIdx)
    {
        if (personIdx < 0)
        {
            return 0.0;
        }
        int code = (codes >> (personIdx * 2)) & 3;
        return code switch
        {
            0 => 0.0,
            1 => 0.1875,
            2 => 0.25,
            _ => 1.0
        };
    }

    public static (int[] Teams, int[] TeamOf) GetOrComputeTeamIndex(
        int universeHandle,
        long[] fallbackWorlds,
        bool currentEpochConvEvil)
    {
        var meta = SolverContext.GetOrCreateUniverseMeta(universeHandle);
        if (!currentEpochConvEvil && meta.HasPlainTeams && meta.PlainTeams != null && meta.PlainTeamOf != null)
        {
            return (meta.PlainTeams, meta.PlainTeamOf);
        }
        if (currentEpochConvEvil && meta.HasCurseTeams && meta.CurseTeams != null && meta.CurseTeamOf != null)
        {
            return (meta.CurseTeams, meta.CurseTeamOf);
        }

        long[] worlds = SolverContext.ResolveWorlds(universeHandle, Array.Empty<int>(), fallbackWorlds);
        int n = worlds.Length;
        var teamsList = new List<int>(64);
        var teamIdx = new Dictionary<int, int>(64);
        int[] teamOf = new int[n];

        for (int i = 0; i < n; i++)
        {
            var w = new WorldEntry(worlds[i]);
            int evil = w.Evil;
            if (w.HasConverted && SolverKernel.EvilIndex(w, w.ConvertedRaw, currentEpochConvEvil))
            {
                evil |= (1 << w.ConvertedRaw);
            }
            if (!teamIdx.TryGetValue(evil, out int idx))
            {
                idx = teamsList.Count;
                teamIdx[evil] = idx;
                teamsList.Add(evil);
            }
            teamOf[i] = idx;
        }

        int[] teams = teamsList.ToArray();
        if (!currentEpochConvEvil)
        {
            meta.PlainTeams = teams;
            meta.PlainTeamOf = teamOf;
            meta.HasPlainTeams = true;
        }
        else
        {
            meta.CurseTeams = teams;
            meta.CurseTeamOf = teamOf;
            meta.HasCurseTeams = true;
        }
        return (teams, teamOf);
    }

    /// <summary>
    /// Flat encoding for GDScript CaseEval._index: [teams.Length, teams[0..T-1], teamOf[0..N-1]].
    /// </summary>
    public static int[] BuildTeamIndexFlat(
        int universeHandle,
        long[] fallbackWorlds,
        bool currentEpochConvEvil)
    {
        var (teams, teamOf) = GetOrComputeTeamIndex(universeHandle, fallbackWorlds, currentEpochConvEvil);
        int[] outBuf = new int[1 + teams.Length + teamOf.Length];
        outBuf[0] = teams.Length;
        Array.Copy(teams, 0, outBuf, 1, teams.Length);
        Array.Copy(teamOf, 0, outBuf, 1 + teams.Length, teamOf.Length);
        return outBuf;
    }

    /// <summary>
    /// 1:1 port of CaseEval.compile equivalence-class construction &amp; movement scoring.
    /// Registers CompiledCaseEntry in SolverContext and returns ccHandle.
    /// Also provides accessors (GetCompiledCaseInts / GetCompiledCaseBytes / GetCompiledCaseDoubles)
    /// so GDScript populates the exact cc Dictionary in 3 flat buffer reads.
    /// </summary>
    public static int CompileEquivalenceClasses(
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
        double[] moveFactorDoubles)
    {
        // headerInts layout (11 ints):
        //  [0] nPeople
        //  [1] isLive (0/1)
        //  [2] rolesOn (0/1)
        //  [3] hasCurse (0/1)
        //  [4] seer (0/1)
        //  [5] mediums
        //  [6] walkers
        //  [7] currentEpochConvEvil (0/1)
        //  [8] conclEpochConvEvil (0/1)
        //  [9] k (reports count)
        // [10] movementOk (0/1)
        int nPeople = headerInts[0];
        bool isLive = headerInts[1] != 0;
        bool rolesOn = headerInts[2] != 0;
        bool hasCurse = headerInts[3] != 0;
        bool seer = headerInts[4] != 0;
        int mediums = headerInts[5];
        int walkers = headerInts[6];
        bool currentEpochConvEvil = headerInts[7] != 0;
        bool conclEpochConvEvil = headerInts[8] != 0;
        int k = headerInts[9];
        bool movementOk = headerInts[10] != 0;

        long[] worlds = SolverContext.ResolveWorlds(universeHandle, Array.Empty<int>(), fallbackWorlds);
        int n = worlds.Length;

        var (ixTeams, teamOf) = GetOrComputeTeamIndex(universeHandle, worlds, currentEpochConvEvil);
        var (evilBits, _, plainBits) = SolverKernel.GetOrComputeWorldBits(universeHandle, worlds);

        long radix;
        long rmBound;
        unchecked
        {
            radix = (long)SolverBridge.GodotPow(3.0, k);
            rmBound = (1L << nPeople)
                * (nPeople + 2L)
                * (nPeople + 2L)
                * (mediums != 0 ? (1L << nPeople) : 1L)
                * (walkers != 0 ? (1L << nPeople) : 1L);
            if (hasCurse)
            {
                rmBound *= (nPeople + 1L);
            }
        }
        bool intKeys = k <= 16 && ((double)rmBound * (double)radix * 4.0 < 9.0e18);

        long[] codes = new long[n];
        for (int c = 0; c < k; c++)
        {
            int cOff = c * n;
            unchecked
            {
                for (int i = 0; i < n; i++)
                {
                    long digit = flatTables[cOff + i] == 1
                        ? 0L
                        : (flatValids[cOff + i] == 1 ? 1L : 2L);
                    codes[i] = codes[i] * 3L + digit;
                }
            }
        }

        long[] rms;
        if (!isLive)
        {
            rms = new long[n];
            for (int i = 0; i < n; i++)
            {
                rms[i] = i;
            }
        }
        else if (rolesOn || seer)
        {
            rms = RoleConstraintsKernel.CoarseMasks(nPeople, worlds, seer, mediums, walkers);
        }
        else if (hasCurse)
        {
            rms = new long[n];
            long np1 = nPeople + 1L;
            for (int i = 0; i < n; i++)
            {
                var w = new WorldEntry(worlds[i]);
                rms[i] = evilBits[i] * np1 + w.ConvertedOrMinusOne + 1L;
            }
        }
        else
        {
            rms = evilBits;
        }

        int mTests = testTargetSpecs.Length / 2;
        int initCap = Math.Min(Math.Max(n / 8, 64), 4096);
        var teamList = new List<int>(initCap);
        var groupList = new List<int>(initCap);
        var repList = new List<int>(initCap);
        var countList = new List<double>(initCap);
        var premList = new List<byte>(initCap);
        var isDeadList = new List<byte>(initCap);
        var statesList = new List<byte>(initCap * Math.Max(k, 1));
        var testHoldList = new List<byte>(initCap * Math.Max(mTests, 1));
        int[] classOf = new int[n];
        byte[] digits = new byte[k];

        var groupBitsList = plainBits ? null : new List<int>(64);
        var groupIndex = plainBits ? null : new Dictionary<int, int>(64);

        if (intKeys)
        {
            var indexLong = new Dictionary<long, int>(initCap);
            for (int i = 0; i < n; i++)
            {
                long code = codes[i];
                long rm = rms[i];
                long ck = ((rm * radix + code) * 2L + premise[i]) * 2L + dead[i];
                if (!indexLong.TryGetValue(ck, out int cId))
                {
                    cId = AppendNewClass(
                        i,
                        code,
                        k,
                        nPeople,
                        worlds,
                        teamOf,
                        plainBits,
                        conclEpochConvEvil,
                        premise,
                        dead,
                        mTests,
                        testTargetSpecs,
                        digits,
                        teamList,
                        groupList,
                        groupBitsList,
                        groupIndex,
                        repList,
                        countList,
                        premList,
                        isDeadList,
                        testHoldList,
                        statesList);
                    indexLong[ck] = cId;
                }
                countList[cId] += 1.0;
                classOf[i] = cId;
            }
        }
        else
        {
            var indexTuple = new Dictionary<(long Rm, long Code, byte Prem, byte Dead), int>(initCap);
            for (int i = 0; i < n; i++)
            {
                long code = codes[i];
                long rm = rms[i];
                var ck = (rm, code, premise[i], dead[i]);
                if (!indexTuple.TryGetValue(ck, out int cId))
                {
                    cId = AppendNewClass(
                        i,
                        code,
                        k,
                        nPeople,
                        worlds,
                        teamOf,
                        plainBits,
                        conclEpochConvEvil,
                        premise,
                        dead,
                        mTests,
                        testTargetSpecs,
                        digits,
                        teamList,
                        groupList,
                        groupBitsList,
                        groupIndex,
                        repList,
                        countList,
                        premList,
                        isDeadList,
                        testHoldList,
                        statesList);
                    indexTuple[ck] = cId;
                }
                countList[cId] += 1.0;
                classOf[i] = cId;
            }
        }

        int[] repArr = repList.ToArray();
        double[] move = ComputeClassMovementScores(worlds, repArr, moveFactorSpecs, moveFactorDoubles);

        int[] finalGroupBits = plainBits ? ixTeams : groupBitsList!.ToArray();
        double[] qCopy = new double[q.Length];
        Array.Copy(q, qCopy, q.Length);

        var entry = new CompiledCaseEntry(
            universeHandle,
            nPeople,
            k,
            teamList.ToArray(),
            groupList.ToArray(),
            finalGroupBits,
            repArr,
            countList.ToArray(),
            premList.ToArray(),
            isDeadList.ToArray(),
            statesList.ToArray(),
            classOf,
            testHoldList.ToArray(),
            mTests,
            move,
            movementOk,
            qCopy);

        return SolverContext.RegisterCompiledCase(entry);
    }

    private static int AppendNewClass(
        int i,
        long code,
        int k,
        int nPeople,
        long[] worlds,
        int[] teamOf,
        bool plainBits,
        bool conclEpochConvEvil,
        byte[] premise,
        byte[] dead,
        int mTests,
        int[] testTargetSpecs,
        byte[] digits,
        List<int> teamList,
        List<int> groupList,
        List<int>? groupBitsList,
        Dictionary<int, int>? groupIndex,
        List<int> repList,
        List<double> countList,
        List<byte> premList,
        List<byte> isDeadList,
        List<byte> testHoldList,
        List<byte> statesList)
    {
        int cId = teamList.Count;
        teamList.Add(teamOf[i]);
        var w = new WorldEntry(worlds[i]);

        if (plainBits)
        {
            groupList.Add(teamOf[i]);
        }
        else
        {
            int bits = 0;
            for (int j = 0; j < nPeople; j++)
            {
                if (SolverKernel.EvilIndex(w, j, conclEpochConvEvil))
                {
                    bits |= (1 << j);
                }
            }
            if (!groupIndex!.TryGetValue(bits, out int gId))
            {
                gId = groupBitsList!.Count;
                groupIndex[bits] = gId;
                groupBitsList.Add(bits);
            }
            groupList.Add(gId);
        }

        repList.Add(i);
        countList.Add(0.0);
        premList.Add(premise[i]);
        isDeadList.Add(dead[i]);

        for (int f = 0; f < mTests; f++)
        {
            int tIdx = testTargetSpecs[f * 2];
            bool tConv = testTargetSpecs[f * 2 + 1] != 0;
            testHoldList.Add((tIdx >= 0 && SolverKernel.EvilIndex(w, tIdx, tConv)) ? (byte)1 : (byte)0);
        }

        long tmp = code;
        for (int c = k - 1; c >= 0; c--)
        {
            digits[c] = (byte)(tmp % 3L);
            tmp /= 3L;
        }
        for (int c = 0; c < k; c++)
        {
            statesList.Add(digits[c]);
        }

        return cId;
    }

    private static double[] ComputeClassMovementScores(
        long[] worlds,
        int[] rep,
        int[] moveFactorSpecs,
        double[] moveFactorDoubles)
    {
        int nc = rep.Length;
        double[] outBuf = new double[nc];
        Array.Fill(outBuf, 1.0);
        int nFactors = moveFactorSpecs.Length / 4;
        if (nc == 0 || nFactors == 0)
        {
            return outBuf;
        }

        for (int f = 0; f < nFactors; f++)
        {
            int off = f * 4;
            int kind = moveFactorSpecs[off];
            if (kind == 0)
            {
                int handle = moveFactorSpecs[off + 1];
                for (int c = 0; c < nc; c++)
                {
                    outBuf[c] *= LiveActivityKernel.ScoreWorld(worlds[rep[c]], handle);
                }
                continue;
            }

            if (kind == 2)
            {
                int packedFlags = moveFactorSpecs[off + 1];
                int srcIdx = packedFlags & 0xFFFF;
                bool yes = ((packedFlags >> 16) & 1) != 0;
                bool augConvEvil = ((packedFlags >> 17) & 1) != 0;
                bool augIsLive = ((packedFlags >> 18) & 1) != 0;
                int slot0Codes = moveFactorSpecs[off + 2];
                int slot1Codes = moveFactorSpecs[off + 3];
                double pRef = moveFactorDoubles[f * 2];
                double defaultErr = moveFactorDoubles[f * 2 + 1];
                double zeroMult = (defaultErr * 0.5) / ((1.0 - defaultErr) + defaultErr * 0.5);

                for (int c = 0; c < nc; c++)
                {
                    long wRaw = worlds[rep[c]];
                    var w = new WorldEntry(wRaw);
                    if (SolverKernel.EvilIndex(w, srcIdx, augConvEvil) || (augIsLive && !WorldDomainKernel.Healthy(wRaw, srcIdx)))
                    {
                        continue;
                    }
                    int dIdx = w.DemonOrMinusOne;
                    int mIdx = w.Marked;
                    double dp0 = AugurSlotProb(slot0Codes, dIdx);
                    double dp1 = AugurSlotProb(slot1Codes, dIdx);
                    double mp0 = (mIdx >= 0 && mIdx != srcIdx) ? AugurSlotProb(slot0Codes, mIdx) : 0.0;
                    double mp1 = (mIdx >= 0 && mIdx != srcIdx) ? AugurSlotProb(slot1Codes, mIdx) : 0.0;
                    double trig0 = 1.0 - (1.0 - dp0) * (1.0 - 0.5 * mp0);
                    double trig1 = 1.0 - (1.0 - dp1) * (1.0 - 0.5 * mp1);
                    double pYes = 1.0 - (1.0 - trig0) * (1.0 - trig1);
                    double pOut = yes ? pYes : (1.0 - pYes);
                    double mult = pOut <= 0.0
                        ? zeroMult
                        : ((1.0 - defaultErr) * (pOut / pRef) + defaultErr);
                    outBuf[c] *= mult;
                }
                continue;
            }

            int handleOrTarget = moveFactorSpecs[off + 1];
            bool convEvil = moveFactorSpecs[off + 2] != 0;
            bool isMm = moveFactorSpecs[off + 3] != 0;
            if (handleOrTarget < 0)
            {
                continue;
            }
            double ratio = SolverBridge.GodotPow(2.0, moveFactorDoubles[f * 2]);
            double markedRatio = moveFactorDoubles[f * 2 + 1];
            for (int c = 0; c < nc; c++)
            {
                var w = new WorldEntry(worlds[rep[c]]);
                if (SolverKernel.EvilIndex(w, handleOrTarget, convEvil))
                {
                    outBuf[c] *= ratio;
                }
                else if (isMm && w.Marked == handleOrTarget)
                {
                    outBuf[c] *= markedRatio;
                }
            }
        }
        return outBuf;
    }

    /// <summary>
    /// Flat int[] accessor for CompiledCaseEntry:
    ///   [nc, nWorlds, nGroupBits, team[0..nc-1], rep[0..nc-1], group[0..nc-1], groupBits[0..G-1], classOf[0..N-1]]
    /// </summary>
    public static int[] GetCompiledCaseInts(int ccHandle)
    {
        var e = SolverContext.GetCompiledCase(ccHandle)!;
        int nc = e.Team.Length;
        int nW = e.ClassOf.Length;
        int nG = e.GroupBits.Length;
        int[] outBuf = new int[3 + 3 * nc + nG + nW];
        outBuf[0] = nc;
        outBuf[1] = nW;
        outBuf[2] = nG;
        int p = 3;
        Array.Copy(e.Team, 0, outBuf, p, nc); p += nc;
        Array.Copy(e.Rep, 0, outBuf, p, nc); p += nc;
        Array.Copy(e.Group, 0, outBuf, p, nc); p += nc;
        Array.Copy(e.GroupBits, 0, outBuf, p, nG); p += nG;
        Array.Copy(e.ClassOf, 0, outBuf, p, nW);
        return outBuf;
    }

    /// <summary>
    /// Flat byte[] accessor for CompiledCaseEntry:
    ///   [premise[0..nc-1], dead[0..nc-1], states[0..nc*k-1], testHold[0..nc*m-1]]
    /// </summary>
    public static byte[] GetCompiledCaseBytes(int ccHandle)
    {
        var e = SolverContext.GetCompiledCase(ccHandle)!;
        int nc = e.Premise.Length;
        int sLen = e.States.Length;
        int tLen = e.TestHold.Length;
        byte[] outBuf = new byte[2 * nc + sLen + tLen];
        int p = 0;
        Array.Copy(e.Premise, 0, outBuf, p, nc); p += nc;
        Array.Copy(e.Dead, 0, outBuf, p, nc); p += nc;
        if (sLen > 0)
        {
            Array.Copy(e.States, 0, outBuf, p, sLen);
            p += sLen;
        }
        if (tLen > 0)
        {
            Array.Copy(e.TestHold, 0, outBuf, p, tLen);
        }
        return outBuf;
    }

    /// <summary>
    /// Flat double[] accessor for CompiledCaseEntry:
    ///   [count[0..nc-1], move[0..nc-1]]
    /// </summary>
    public static double[] GetCompiledCaseDoubles(int ccHandle)
    {
        var e = SolverContext.GetCompiledCase(ccHandle)!;
        int nc = e.Count.Length;
        double[] outBuf = new double[2 * nc];
        Array.Copy(e.Count, 0, outBuf, 0, nc);
        Array.Copy(e.Move, 0, outBuf, nc, nc);
        return outBuf;
    }

    private sealed class ByteArrayComparer : IEqualityComparer<byte[]>
    {
        public static readonly ByteArrayComparer Instance = new();

        public bool Equals(byte[]? x, byte[]? y)
        {
            if (ReferenceEquals(x, y))
            {
                return true;
            }
            if (x == null || y == null || x.Length != y.Length)
            {
                return false;
            }
            for (int i = 0; i < x.Length; i++)
            {
                if (x[i] != y[i])
                {
                    return false;
                }
            }
            return true;
        }

        public int GetHashCode(byte[] obj)
        {
            var hc = new HashCode();
            hc.AddBytes(obj);
            return hc.ToHashCode();
        }
    }

    /// <summary>
    /// 1:1 port of CaseEval._own_counts.
    /// Populates sparse own-reading states in exact first-appearance order.
    /// Returns serialized int[] header+of: [ns, of[0..n-1]]; caller reads counts and flatCodes via out helpers
    /// or single tuple wrapper on SolverBridge.
    /// </summary>
    public static (int Ns, int[] Of, byte[] FlatCodes, double[] Counts) CompileOwnCounts(
        int ccHandle,
        int[] fallbackClassOf,
        int nc,
        int kOwn,
        byte[] flatTables,
        byte[] flatValids)
    {
        var cc = SolverContext.GetCompiledCase(ccHandle);
        int[] classOf = cc != null ? cc.ClassOf : fallbackClassOf;
        int actualNc = cc != null ? cc.Team.Length : nc;
        int n = classOf.Length;

        int[] of = new int[n];
        var codesList = new List<byte[]>(16);

        if (kOwn <= 39)
        {
            var indices = new Dictionary<long, int>(32);
            for (int i = 0; i < n; i++)
            {
                long packed = 0L;
                for (int c = 0; c < kOwn; c++)
                {
                    int off = c * n + i;
                    long d = flatTables[off] == 1 ? 0L : (flatValids[off] == 1 ? 1L : 2L);
                    packed = packed * 3L + d;
                }
                if (!indices.TryGetValue(packed, out int sIdx))
                {
                    byte[] code = new byte[kOwn];
                    for (int c = 0; c < kOwn; c++)
                    {
                        int off = c * n + i;
                        code[c] = flatTables[off] == 1 ? (byte)0 : (flatValids[off] == 1 ? (byte)1 : (byte)2);
                    }
                    sIdx = codesList.Count;
                    indices[packed] = sIdx;
                    codesList.Add(code);
                }
                of[i] = sIdx;
            }
        }
        else
        {
            var indices = new Dictionary<byte[], int>(32, ByteArrayComparer.Instance);
            for (int i = 0; i < n; i++)
            {
                byte[] code = new byte[kOwn];
                for (int c = 0; c < kOwn; c++)
                {
                    int off = c * n + i;
                    code[c] = flatTables[off] == 1 ? (byte)0 : (flatValids[off] == 1 ? (byte)1 : (byte)2);
                }
                if (!indices.TryGetValue(code, out int sIdx))
                {
                    sIdx = codesList.Count;
                    indices[code] = sIdx;
                    codesList.Add(code);
                }
                of[i] = sIdx;
            }
        }

        int ns = codesList.Count;
        double[] counts = new double[actualNc * ns];
        for (int i = 0; i < n; i++)
        {
            counts[classOf[i] * ns + of[i]] += 1.0;
        }

        byte[] flatCodes = new byte[ns * kOwn];
        for (int s = 0; s < ns; s++)
        {
            Array.Copy(codesList[s], 0, flatCodes, s * kOwn, kOwn);
        }

        return (ns, of, flatCodes, counts);
    }

    public static double[] ComputeTeamPrior(
        int universeHandle,
        long[] fallbackWorlds,
        bool currentEpochConvEvil,
        double[] rawSusp,
        double[] npcTrust,
        int goodMask,
        double priorK)
    {
        var (teams, _) = GetOrComputeTeamIndex(universeHandle, fallbackWorlds, currentEpochConvEvil);
        int nPeople = rawSusp.Length;
        double[] odds = new double[nPeople];

        for (int j = 0; j < nPeople; j++)
        {
            double raw = rawSusp[j];
            double sv = GodotClamp(raw, 0.02, 0.98);
            double trust = npcTrust[j];
            double baseVal = priorK < 0.0
                ? (sv / (1.0 - sv))
                : SolverBridge.GodotExp(priorK * GodotClamp(raw, 0.0, 1.5));
            odds[j] = baseVal * SolverBridge.GodotPow(2.0, -2.0 * (GodotClamp(trust, 0.0, 1.0) - 0.5));
        }

        double[] teamPrior = new double[teams.Length];
        for (int t = 0; t < teams.Length; t++)
        {
            int evil = teams[t];
            if ((evil & goodMask) != 0)
            {
                teamPrior[t] = 0.0;
                continue;
            }
            double v = 1.0;
            for (int j = 0; j < nPeople; j++)
            {
                if ((evil & (1 << j)) != 0)
                {
                    v *= odds[j];
                }
            }
            teamPrior[t] = v;
        }
        return teamPrior;
    }

    public static double[] ComputeClassLike(
        int ccHandle,
        int ncFallback,
        int kFallback,
        byte[] fallbackStates,
        byte[] fallbackDead,
        double[] fallbackQ,
        double[] errs,
        int skip)
    {
        var cc = SolverContext.GetCompiledCase(ccHandle);
        if (cc != null)
        {
            return ComputeClassLikeCore(cc.Team.Length, cc.K, cc.States, cc.Dead, cc.Q, errs, skip);
        }
        return ComputeClassLikeCore(ncFallback, kFallback, fallbackStates, fallbackDead, fallbackQ, errs, skip);
    }

    private static double[] ComputeClassLikeCore(
        int nc,
        int k,
        byte[] states,
        byte[] dead,
        double[] q,
        double[] errs,
        int skip)
    {
        double[] like = new double[nc];
        double[] f = new double[3 * k];
        for (int c = 0; c < k; c++)
        {
            for (int st = 0; st < 3; st++)
            {
                f[3 * c + st] = (c == skip) ? 1.0 : Factor(st, errs[c], q[c]);
            }
        }

        for (int x = 0; x < nc; x++)
        {
            if (dead[x] == 1)
            {
                like[x] = 0.0;
                continue;
            }
            double v = 1.0;
            int at = x * k;
            for (int c = 0; c < k; c++)
            {
                v *= f[3 * c + states[at + c]];
            }
            like[x] = v;
        }
        return like;
    }

    [MethodImpl(MethodImplOptions.AggressiveInlining)]
    private static (double Yes, double Total) ClassShare(byte[] prem, double[] w, int ns)
    {
        double yes = 0.0;
        double total = 0.0;
        for (int idx = 0; idx < w.Length; idx++)
        {
            double wk = w[idx];
            total += wk;
            if (prem[idx / ns] == 1)
            {
                yes += wk;
            }
        }
        return (yes, total);
    }

    /// <summary>
    /// 1:1 port of CaseEval.evaluate posterior marginalization pass.
    /// Returns a single flat double[] buffer containing:
    ///   [0] prior (p0)
    ///   [1] posterior (p1)
    ///   [2] lr
    ///   [3] impossibleFlag (1.0 or 0.0)
    ///   [4] consistentFlag (1.0 or 0.0)
    ///   [5] credence
    ///   [6 .. 6 + 2*nPeople - 1] (prior_j, posterior_j) for j = 0..nPeople-1
    ///   [6 + 2*nPeople .. + (k + ko) - 1] acceptance[0..k+ko-1]
    ///   [next] pivotalCount, followed by pivotal report indices (0..k-1) as doubles
    ///   [optional tail if needExpandedPost] expandedPost[0..nWorlds-1]
    /// </summary>
    public static double[] EvaluatePosterior(
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
        double biasFactor)
    {
        // evalInts layout (9 ints):
        //  [0] ns (own states count)
        //  [1] ko (own reports count)
        //  [2] hasBias (0/1)
        //  [3] biasTargetIdx
        //  [4] biasPosCode
        //  [5] biasConvEvil (0/1)
        //  [6] computePivotal (0/1)
        //  [7] needExpandedPost (0/1)
        //  [8] fallbackNc (unused when ccHandle >= 0)
        // tuningDoubles layout (4 doubles):
        //  [0] DEFAULT_ERR
        //  [1] LR_WEAK
        //  [2] LR_MODERATE
        //  [3] LR_STRONG
        var cc = SolverContext.GetCompiledCase(ccHandle)!;
        int nc = cc.Team.Length;
        int k = cc.K;
        int nPeople = cc.NPeople;
        int ns = evalInts[0];
        int ko = evalInts[1];
        bool hasBias = evalInts[2] != 0;
        int biasTargetIdx = evalInts[3];
        int biasPosCode = evalInts[4];
        bool biasConvEvil = evalInts[5] != 0;
        bool computePivotal = evalInts[6] != 0;
        bool needExpandedPost = evalInts[7] != 0;

        double defaultErr = tuningDoubles[0];
        double lrWeak = tuningDoubles[1];
        double lrModerate = tuningDoubles[2];
        double lrStrong = tuningDoubles[3];

        // 1. Case & own-state likelihoods:
        double[] caseLike = ComputeClassLikeCore(nc, k, cc.States, cc.Dead, cc.Q, caseErrs, -1);

        double[] ownLike = new double[ns];
        for (int o = 0; o < ns; o++)
        {
            double v = 1.0;
            int oBase = o * ko;
            // GDScript _state_like iterates c from own.size() - 1 down to 0:
            for (int c = ko - 1; c >= 0; c--)
            {
                v *= Factor(flatOwnCodes[oBase + c], ownErrs[c], ownQs[c]);
            }
            ownLike[o] = v;
        }

        // 2. Test-factor likelihoods:
        int mTests = cc.NumTests;
        double[] testLike = new double[nc];
        Array.Fill(testLike, 1.0);
        if (mTests > 0)
        {
            byte[] tHold = cc.TestHold;
            for (int j = 0; j < mTests; j++)
            {
                double w = routeCredits[j];
                double ratio = SolverBridge.GodotPow(2.0, testLog2Ratios[j]);
                double mult = (1.0 - w) + w * ratio;
                for (int c = 0; c < nc; c++)
                {
                    if (tHold[c * mTests + j] == 1)
                    {
                        testLike[c] *= mult;
                    }
                }
            }
        }

        // 3. Base & posterior class-state weights:
        int totalCells = nc * ns;
        double[] baseArr = new double[totalCells];
        double[] postArr = new double[totalCells];
        int[] team = cc.Team;
        double[] move = cc.Move;
        bool movementOk = cc.MovementOk;

        for (int c = 0; c < nc; c++)
        {
            double tp = teamPrior[team[c]];
            double w0 = tp * fits[c];
            double fb = fitsBefore[c];
            double cl = caseLike[c];
            double moveC = movementOk ? move[c] : 0.0;
            double tl = testLike[c];
            int rowBase = c * ns;
            for (int o = 0; o < ns; o++)
            {
                int idx = rowBase + o;
                double cnt = counts[idx];
                double ol = ownLike[o];
                double b = cnt * w0 * ol;
                baseArr[idx] = cnt * tp * fb * ol;
                postArr[idx] = b * cl * moveC * tl;
            }
        }

        // 4. Optional theory bias on postArr:
        if (hasBias)
        {
            long[] worlds = SolverContext.ResolveWorlds(
                universeHandle >= 0 ? universeHandle : cc.UniverseHandle,
                Array.Empty<int>(),
                fallbackWorlds);
            int[] rep = cc.Rep;
            for (int c = 0; c < nc; c++)
            {
                var w = new WorldEntry(worlds[rep[c]]);
                if (SolverKernel.PositionHolds(w, biasTargetIdx, biasPosCode, biasConvEvil))
                {
                    int rowBase = c * ns;
                    for (int o = 0; o < ns; o++)
                    {
                        postArr[rowBase + o] *= biasFactor;
                    }
                }
            }
        }

        // 5. Premise shares, prior/posterior, LR:
        var (bYes, bTot) = ClassShare(cc.Premise, baseArr, ns);
        var (aYes, aTot) = ClassShare(cc.Premise, postArr, ns);
        double p0 = bTot > 0.0 ? (bYes / bTot) : 0.0;
        double p1 = aTot > 0.0 ? (aYes / aTot) : 0.0;
        double lr = (p0 > 0.0 && p0 < 1.0) ? (Odds(p1) / Odds(p0)) : 1.0;
        bool impossible = aTot <= 0.0;

        // 6. Per-person marginals (_people):
        int[] group = cc.Group;
        int[] groupBits = cc.GroupBits;
        int nt = groupBits.Length;
        double[] tb = new double[nt];
        double[] ta = new double[nt];
        for (int idx = 0; idx < totalCells; idx++)
        {
            int g = group[idx / ns];
            tb[g] += baseArr[idx];
            ta[g] += postArr[idx];
        }
        double sb = 0.0;
        double sa = 0.0;
        for (int t = 0; t < nt; t++)
        {
            sb += tb[t];
            sa += ta[t];
        }
        double[] pbs = new double[nPeople];
        double[] pas = new double[nPeople];
        for (int t = 0; t < nt; t++)
        {
            int evil = groupBits[t];
            int j = 0;
            while (evil != 0)
            {
                if ((evil & 1) != 0)
                {
                    pbs[j] += tb[t];
                    pas[j] += ta[t];
                }
                evil >>= 1;
                j++;
            }
        }

        // 7. Joint report consistency, acceptance & credence (_joint):
        int totalCards = k + ko;
        double[] accurate = new double[totalCards];
        for (int j = 0; j < k; j++)
        {
            double err = caseErrs[j];
            double qj = cc.Q[j];
            accurate[j] = (1.0 - err) / GodotMax((1.0 - err) + err * qj, 1e-12);
        }
        for (int j = 0; j < ko; j++)
        {
            double err = ownErrs[j];
            double qj = ownQs[j];
            accurate[k + j] = (1.0 - err) / GodotMax((1.0 - err) + err * qj, 1e-12);
        }

        double[] held = new double[totalCards];
        double totalPost = 0.0;
        double baseTotal = 0.0;
        double readable = 0.0;
        bool consistent = false;
        byte[] states = cc.States;
        byte[] dead = cc.Dead;

        for (int x = 0; x < totalCells; x++)
        {
            int c = x / ns;
            bool allHold = dead[c] == 0 && move[c] > 0.0 && movementOk;
            bool allValid = true;
            int stBase = c * k;
            double px = postArr[x];
            double bx = baseArr[x];

            for (int j = 0; j < k; j++)
            {
                byte st = states[stBase + j];
                if (st == 0)
                {
                    held[j] += px;
                }
                else
                {
                    allHold = false;
                }
                if (st == 2)
                {
                    allValid = false;
                }
            }

            if (ko > 0)
            {
                int oBase = (x % ns) * ko;
                for (int j = 0; j < ko; j++)
                {
                    if (flatOwnCodes[oBase + j] == 0)
                    {
                        held[k + j] += px;
                    }
                }
            }

            totalPost += px;
            baseTotal += bx;
            if (allValid)
            {
                readable += bx;
            }
            if (allHold && bx > 0.0)
            {
                consistent = true;
            }
        }

        double credence = baseTotal > 0.0 ? (readable / baseTotal) : 0.0;
        for (int j = 0; j < k; j++)
        {
            credence *= GodotMin(1.0, (1.0 - caseErrs[j]) / (1.0 - defaultErr));
        }

        // 8. Optional pivotal cards check (_pivotal, reference listener only):
        var pivList = new List<int>(k);
        if (computePivotal)
        {
            int catRank = CategoryRank(lr, lrWeak, lrModerate, lrStrong);
            if (catRank > 1)
            {
                if (k < 2)
                {
                    for (int s = 0; s < k; s++)
                    {
                        pivList.Add(s);
                    }
                }
                else
                {
                    double[] wTmp = new double[totalCells];
                    for (int skip = 0; skip < k; skip++)
                    {
                        double[] likeSkip = ComputeClassLikeCore(nc, k, states, dead, cc.Q, caseErrs, skip);
                        for (int idx = 0; idx < totalCells; idx++)
                        {
                            wTmp[idx] = baseArr[idx] * likeSkip[idx / ns];
                        }
                        var (sYes, sTot) = ClassShare(cc.Premise, wTmp, ns);
                        double sp1 = sTot > 0.0 ? (sYes / sTot) : 0.0;
                        double slr = (p0 > 0.0 && p0 < 1.0) ? (Odds(sp1) / Odds(p0)) : 1.0;
                        if (CategoryRank(slr, lrWeak, lrModerate, lrStrong) < catRank)
                        {
                            pivList.Add(skip);
                        }
                    }
                }
            }
        }

        // 9. Optional expanded per-world posterior weights (_expand for _theory_fit):
        int nWorlds = needExpandedPost ? cc.ClassOf.Length : 0;
        int outLen = 6 + 2 * nPeople + totalCards + 1 + pivList.Count + nWorlds;
        double[] outBuf = new double[outLen];

        int p = 0;
        outBuf[p++] = p0;
        outBuf[p++] = p1;
        outBuf[p++] = lr;
        outBuf[p++] = impossible ? 1.0 : 0.0;
        outBuf[p++] = consistent ? 1.0 : 0.0;
        outBuf[p++] = credence;

        for (int j = 0; j < nPeople; j++)
        {
            outBuf[p++] = sb > 0.0 ? (pbs[j] / sb) : 0.0;
            outBuf[p++] = sa > 0.0 ? (pas[j] / sa) : 0.0;
        }

        for (int j = 0; j < totalCards; j++)
        {
            outBuf[p++] = totalPost > 0.0 ? (held[j] / totalPost * accurate[j]) : 0.0;
        }

        outBuf[p++] = pivList.Count;
        for (int s = 0; s < pivList.Count; s++)
        {
            outBuf[p++] = pivList[s];
        }

        if (needExpandedPost)
        {
            int[] classOf = cc.ClassOf;
            for (int i = 0; i < nWorlds; i++)
            {
                int idx = classOf[i] * ns + (ns > 1 ? ownOf[i] : 0);
                outBuf[p++] = counts[idx] > 0.0 ? (postArr[idx] / counts[idx]) : 0.0;
            }
        }

        return outBuf;
    }
}
