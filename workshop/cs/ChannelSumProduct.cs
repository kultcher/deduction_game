using System;
using System.Collections.Generic;
using System.Runtime.CompilerServices;

namespace Demonologist.Workshop;

/// <summary>
/// Slice C3 1:1 bit-exact port of workshop/channel_sum_product.gd and the inner
/// per-world evaluation/memoization batch of workshop/factored_channels.gd.
/// Preserves exact variable elimination order, left-to-right multiplication/summation,
/// zero-safe reverse adjoints, folded arithmetic circuits, and exact signature memoization.
/// </summary>
internal static class ChannelSumProductKernel
{
    internal readonly struct EliminationStep
    {
        public readonly int[] Inputs;
        public readonly int[][] Maps;
        public readonly int Output;
        public readonly int Size;

        public EliminationStep(int[] inputs, int[][] maps, int output, int size)
        {
            Inputs = inputs;
            Maps = maps;
            Output = output;
            Size = size;
        }
    }

    internal sealed class CompiledProgram
    {
        public readonly int[][] Nodes;
        public readonly EliminationStep[] Steps;
        public readonly int[] Roots;
        public readonly int Inputs;
        public readonly int Peak;

        public CompiledProgram(int[][] nodes, EliminationStep[] steps, int[] roots, int inputs, int peak)
        {
            Nodes = nodes;
            Steps = steps;
            Roots = roots;
            Inputs = inputs;
            Peak = peak;
        }
    }

    internal sealed class CompiledCircuit
    {
        public readonly int[] OpKind;
        public readonly int[] OpA;
        public readonly int[] OpB;
        public readonly int[] InputFactor;
        public readonly int[] InputRow;
        public readonly int[] InputReg;
        public readonly int Root;
        public readonly int[] Shapes;

        public CompiledCircuit(
            int[] opKind,
            int[] opA,
            int[] opB,
            int[] inputFactor,
            int[] inputRow,
            int[] inputReg,
            int root,
            int[] shapes)
        {
            OpKind = opKind;
            OpA = opA;
            OpB = opB;
            InputFactor = inputFactor;
            InputRow = inputRow;
            InputReg = inputReg;
            Root = root;
            Shapes = shapes;
        }
    }

    // Factor kinds for FactoredChannels.assess batching:
    public const int FactStatic = 0;
    public const int FactPriorConst = 1;
    public const int FactPriorImpaired = 2;
    public const int FactChance = 3;
    public const int FactReport = 4;
    public const int FactKnowledge = 5;
    public const int FactPublic = 6;
    public const int FactCondConst0 = 7;     // forced_lamp, route_counts, fixture_movement (sig = 0)
    public const int FactCondActivity = 8;   // activity (sig = 0, 1, or 2)
    public const int FactCondRoles = 9;      // roles (sig = RoleConstraintsKernel.CoarseMask)
    public const int FactCondSpeech = 10;    // speech (sig = evil * (n + 1) + demon + 1)

    /// <summary>
    /// Compiles variable elimination program from flattened scopes.
    /// Registers CompiledProgram in SolverContext and returns serialized int[] description:
    ///   [handle, inputs, peak, nodesCount,
    ///    (for each node: scopeLen, vars...),
    ///    stepsCount,
    ///    (for each step: output, size, inCount, inputs..., (for each input: map[0..size*2-1])),
    ///    rootsCount, roots...]
    /// </summary>
    public static int[] CompileProgram(int nInputs, int[] scopeOffsets, int[] scopeVars)
    {
        var nodes = new List<int[]>(nInputs * 2 + 2);
        var active = new List<int>(nInputs);
        for (int i = 0; i < nInputs; i++)
        {
            int start = scopeOffsets[i];
            int len = scopeOffsets[i + 1] - start;
            int[] sc = new int[len];
            if (len > 0)
            {
                Array.Copy(scopeVars, start, sc, 0, len);
            }
            nodes.Add(sc);
            active.Add(i);
        }

        var steps = new List<EliminationStep>(nInputs);
        int peak = 1;
        var choiceOrder = new List<int>(32);
        var choiceSeen = new HashSet<int>(32);

        while (HasNonEmptyScope(active, nodes))
        {
            choiceOrder.Clear();
            choiceSeen.Clear();
            for (int a = 0; a < active.Count; a++)
            {
                int[] sc = nodes[active[a]];
                for (int b = 0; b < sc.Length; b++)
                {
                    int v = sc[b];
                    if (choiceSeen.Add(v))
                    {
                        choiceOrder.Add(v);
                    }
                }
            }

            int selected = -1;
            List<int>? best = null;
            for (int ci = 0; ci < choiceOrder.Count; ci++)
            {
                int variable = choiceOrder[ci];
                var joinedCandidate = new List<int>(8);
                for (int a = 0; a < active.Count; a++)
                {
                    int[] sc = nodes[active[a]];
                    if (Array.IndexOf(sc, variable) >= 0)
                    {
                        for (int b = 0; b < sc.Length; b++)
                        {
                            int other = sc[b];
                            if (!joinedCandidate.Contains(other))
                            {
                                joinedCandidate.Add(other);
                            }
                        }
                    }
                }
                if (selected < 0 || joinedCandidate.Count < best!.Count)
                {
                    selected = variable;
                    best = joinedCandidate;
                }
            }

            var stepInputsList = new List<int>(8);
            for (int a = 0; a < active.Count; a++)
            {
                int idx = active[a];
                if (Array.IndexOf(nodes[idx], selected) >= 0)
                {
                    stepInputsList.Add(idx);
                }
            }
            int[] stepInputs = stepInputsList.ToArray();

            best!.Remove(selected);
            best.Sort();
            int[] bestArr = best.ToArray();

            int[] joined = new int[bestArr.Length + 1];
            Array.Copy(bestArr, 0, joined, 0, bestArr.Length);
            joined[bestArr.Length] = selected;

            int rows = 1 << joined.Length;
            if (rows > peak)
            {
                peak = rows;
            }

            var maps = new int[stepInputs.Length][];
            for (int k = 0; k < stepInputs.Length; k++)
            {
                int[] sc = nodes[stepInputs[k]];
                int[] mapping = new int[rows];
                for (int row = 0; row < rows; row++)
                {
                    int index = 0;
                    for (int bit = 0; bit < sc.Length; bit++)
                    {
                        int pos = Array.IndexOf(joined, sc[bit]);
                        index |= ((row >> pos) & 1) << bit;
                    }
                    mapping[row] = index;
                }
                maps[k] = mapping;
            }

            int output = nodes.Count;
            nodes.Add(bestArr);
            steps.Add(new EliminationStep(stepInputs, maps, output, rows / 2));

            var nextActive = new List<int>(active.Count);
            for (int a = 0; a < active.Count; a++)
            {
                int idx = active[a];
                if (Array.IndexOf(stepInputs, idx) < 0)
                {
                    nextActive.Add(idx);
                }
            }
            nextActive.Add(output);
            active = nextActive;
        }

        var prog = new CompiledProgram(nodes.ToArray(), steps.ToArray(), active.ToArray(), nInputs, peak);
        int handle = SolverContext.RegisterProgram(prog);

        var outInts = new List<int>(256)
        {
            handle,
            nInputs,
            peak,
            prog.Nodes.Length,
        };
        for (int i = 0; i < prog.Nodes.Length; i++)
        {
            int[] sc = prog.Nodes[i];
            outInts.Add(sc.Length);
            for (int j = 0; j < sc.Length; j++)
            {
                outInts.Add(sc[j]);
            }
        }
        outInts.Add(prog.Steps.Length);
        for (int s = 0; s < prog.Steps.Length; s++)
        {
            var st = prog.Steps[s];
            outInts.Add(st.Output);
            outInts.Add(st.Size);
            outInts.Add(st.Inputs.Length);
            for (int k = 0; k < st.Inputs.Length; k++)
            {
                outInts.Add(st.Inputs[k]);
            }
            for (int k = 0; k < st.Maps.Length; k++)
            {
                int[] mp = st.Maps[k];
                for (int r = 0; r < mp.Length; r++)
                {
                    outInts.Add(mp[r]);
                }
            }
        }
        outInts.Add(prog.Roots.Length);
        for (int r = 0; r < prog.Roots.Length; r++)
        {
            outInts.Add(prog.Roots[r]);
        }

        return outInts.ToArray();
    }

    private static bool HasNonEmptyScope(List<int> active, List<int[]> nodes)
    {
        for (int i = 0; i < active.Count; i++)
        {
            if (nodes[active[i]].Length > 0)
            {
                return true;
            }
        }
        return false;
    }

    private static CompiledProgram ReconstructProgramFromFlat(int[] flatProg)
    {
        int p = 0;
        int nInputs = flatProg[p++];
        int peak = flatProg[p++];
        int nNodes = flatProg[p++];
        var nodes = new int[nNodes][];
        for (int i = 0; i < nNodes; i++)
        {
            int len = flatProg[p++];
            int[] sc = new int[len];
            for (int j = 0; j < len; j++)
            {
                sc[j] = flatProg[p++];
            }
            nodes[i] = sc;
        }
        int nSteps = flatProg[p++];
        var steps = new EliminationStep[nSteps];
        for (int s = 0; s < nSteps; s++)
        {
            int output = flatProg[p++];
            int size = flatProg[p++];
            int inCount = flatProg[p++];
            int[] ins = new int[inCount];
            for (int k = 0; k < inCount; k++)
            {
                ins[k] = flatProg[p++];
            }
            var maps = new int[inCount][];
            int mapLen = size * 2;
            for (int k = 0; k < inCount; k++)
            {
                int[] mp = new int[mapLen];
                for (int r = 0; r < mapLen; r++)
                {
                    mp[r] = flatProg[p++];
                }
                maps[k] = mp;
            }
            steps[s] = new EliminationStep(ins, maps, output, size);
        }
        int nRoots = flatProg[p++];
        int[] roots = new int[nRoots];
        for (int r = 0; r < nRoots; r++)
        {
            roots[r] = flatProg[p++];
        }
        return new CompiledProgram(nodes, steps, roots, nInputs, peak);
    }

    /// <summary>
    /// Evaluates a CompiledProgram on flattened input value tables.
    /// Returns [total] when marginals == false, or [total, adjTable0..., adjTable1..., ...] when marginals == true.
    /// </summary>
    public static double[] EvaluateProgram(
        int programHandle,
        int[] fallbackFlatProgram,
        int[] valOffsets,
        double[] flatValues,
        bool marginals)
    {
        CompiledProgram prog = SolverContext.GetProgram(programHandle)
            ?? ReconstructProgramFromFlat(fallbackFlatProgram);

        int nIn = valOffsets.Length - 1;
        int totalTables = nIn + prog.Steps.Length;
        var data = new double[totalTables][];
        for (int i = 0; i < nIn; i++)
        {
            int start = valOffsets[i];
            int len = valOffsets[i + 1] - start;
            double[] arr = new double[len];
            if (len > 0)
            {
                Array.Copy(flatValues, start, arr, 0, len);
            }
            data[i] = arr;
        }

        for (int s = 0; s < prog.Steps.Length; s++)
        {
            var step = prog.Steps[s];
            double[] output = new double[step.Size];
            int rows = step.Size * 2;
            for (int row = 0; row < rows; row++)
            {
                double product = 1.0;
                for (int k = 0; k < step.Inputs.Length; k++)
                {
                    product *= data[step.Inputs[k]][step.Maps[k][row]];
                }
                output[row % step.Size] += product;
            }
            data[nIn + s] = output;
        }

        double total = 1.0;
        for (int r = 0; r < prog.Roots.Length; r++)
        {
            total *= data[prog.Roots[r]][0];
        }

        if (!marginals)
        {
            return new[] { total };
        }

        var adjoints = new double[totalTables][];
        int totalAdjElems = 0;
        for (int t = 0; t < totalTables; t++)
        {
            int len = data[t].Length;
            adjoints[t] = new double[len];
            totalAdjElems += len;
        }

        for (int ri = 0; ri < prog.Roots.Length; ri++)
        {
            int rootIdx = prog.Roots[ri];
            double derivative = 1.0;
            for (int rj = 0; rj < prog.Roots.Length; rj++)
            {
                int otherIdx = prog.Roots[rj];
                if (otherIdx != rootIdx)
                {
                    derivative *= data[otherIdx][0];
                }
            }
            adjoints[rootIdx][0] = derivative;
        }

        for (int s = prog.Steps.Length - 1; s >= 0; s--)
        {
            var step = prog.Steps[s];
            int rows = step.Size * 2;
            for (int row = 0; row < rows; row++)
            {
                double gradient = adjoints[step.Output][row % step.Size];
                if (gradient == 0.0)
                {
                    continue;
                }
                double nonzero = gradient;
                int zeros = 0;
                for (int k = 0; k < step.Inputs.Length; k++)
                {
                    double weight = data[step.Inputs[k]][step.Maps[k][row]];
                    if (weight == 0.0)
                    {
                        zeros++;
                    }
                    else
                    {
                        nonzero *= weight;
                    }
                }
                for (int k = 0; k < step.Inputs.Length; k++)
                {
                    int i = step.Inputs[k];
                    int index = step.Maps[k][row];
                    double weight = data[i][index];
                    if (zeros == 0)
                    {
                        adjoints[i][index] += nonzero / weight;
                    }
                    else if (zeros == 1 && weight == 0.0)
                    {
                        adjoints[i][index] += nonzero;
                    }
                }
            }
        }

        double[] outBuf = new double[1 + totalAdjElems];
        outBuf[0] = total;
        int cursor = 1;
        for (int t = 0; t < totalTables; t++)
        {
            double[] adj = adjoints[t];
            Array.Copy(adj, 0, outBuf, cursor, adj.Length);
            cursor += adj.Length;
        }
        return outBuf;
    }

    /// <summary>
    /// Compiles an arithmetic circuit from a CompiledProgram and structural 0/1 constants.
    /// constFlags[i] == 1 means factor i is a constant table in flatConsts[constOffsets[i]..constOffsets[i+1]].
    /// Returns serialized int[] description:
    ///   [circuitHandle, root, opsCount, (kind, a, b) * opsCount,
    ///    inputsCount, (factor, row, reg) * inputsCount,
    ///    shapesCount, shapes...]
    /// </summary>
    public static int[] CompileCircuit(
        int programHandle,
        int[] fallbackFlatProgram,
        byte[] constFlags,
        int[] constOffsets,
        double[] flatConsts)
    {
        CompiledProgram prog = SolverContext.GetProgram(programHandle)
            ?? ReconstructProgramFromFlat(fallbackFlatProgram);

        var opKind = new List<int>(256) { 0, 0 };
        var opA = new List<int>(256) { 0, 1 };
        var opB = new List<int>(256) { 0, 0 };
        var memo = new Dictionary<(int Kind, int Lo, int Hi), int>(256);

        var inFactor = new List<int>(64);
        var inRow = new List<int>(64);
        var inReg = new List<int>(64);

        var data = new List<int[]>(prog.Inputs + prog.Steps.Length);
        int[] shapes = new int[prog.Inputs];

        for (int i = 0; i < prog.Inputs; i++)
        {
            int rows = 1 << prog.Nodes[i].Length;
            shapes[i] = rows;
            int[] table = new int[rows];
            bool isConst = constFlags[i] != 0;
            int cBase = constOffsets[i];
            for (int row = 0; row < rows; row++)
            {
                if (isConst)
                {
                    double v = flatConsts[cBase + row];
                    table[row] = v == 1.0 ? 1 : 0;
                }
                else
                {
                    int reg = opKind.Count;
                    table[row] = reg;
                    inFactor.Add(i);
                    inRow.Add(row);
                    inReg.Add(reg);
                    opKind.Add(1);
                    opA.Add(i);
                    opB.Add(row);
                }
            }
            data.Add(table);
        }

        for (int s = 0; s < prog.Steps.Length; s++)
        {
            var step = prog.Steps[s];
            int[] output = new int[step.Size];
            int rows = step.Size * 2;
            for (int row = 0; row < rows; row++)
            {
                int product = 1;
                for (int k = 0; k < step.Inputs.Length; k++)
                {
                    product = EmitCircuitOp(opKind, opA, opB, memo, 2, product, data[step.Inputs[k]][step.Maps[k][row]]);
                }
                int slot = row % step.Size;
                output[slot] = EmitCircuitOp(opKind, opA, opB, memo, 3, output[slot], product);
            }
            data.Add(output);
        }

        int root = 1;
        for (int r = 0; r < prog.Roots.Length; r++)
        {
            root = EmitCircuitOp(opKind, opA, opB, memo, 2, root, data[prog.Roots[r]][0]);
        }

        var circuit = new CompiledCircuit(
            opKind.ToArray(),
            opA.ToArray(),
            opB.ToArray(),
            inFactor.ToArray(),
            inRow.ToArray(),
            inReg.ToArray(),
            root,
            shapes);
        int handle = SolverContext.RegisterCircuit(circuit);

        int opsLen = circuit.OpKind.Length;
        int insLen = circuit.InputFactor.Length;
        var outInts = new List<int>(4 + opsLen * 3 + insLen * 3 + shapes.Length)
        {
            handle,
            root,
            opsLen,
        };
        for (int i = 0; i < opsLen; i++)
        {
            outInts.Add(circuit.OpKind[i]);
            outInts.Add(circuit.OpA[i]);
            outInts.Add(circuit.OpB[i]);
        }
        outInts.Add(insLen);
        for (int i = 0; i < insLen; i++)
        {
            outInts.Add(circuit.InputFactor[i]);
            outInts.Add(circuit.InputRow[i]);
            outInts.Add(circuit.InputReg[i]);
        }
        outInts.Add(shapes.Length);
        for (int i = 0; i < shapes.Length; i++)
        {
            outInts.Add(shapes[i]);
        }
        return outInts.ToArray();
    }

    [MethodImpl(MethodImplOptions.AggressiveInlining)]
    private static int EmitCircuitOp(
        List<int> opKind,
        List<int> opA,
        List<int> opB,
        Dictionary<(int Kind, int Lo, int Hi), int> memo,
        int kind,
        int a,
        int b)
    {
        if (kind == 2)
        {
            if (a == 0 || b == 0)
            {
                return 0;
            }
            if (a == 1 || b == 1)
            {
                return a == 1 ? b : a;
            }
        }
        else
        {
            if (a == 0 || b == 0)
            {
                return a == 0 ? b : a;
            }
        }
        int lo = a < b ? a : b;
        int hi = a > b ? a : b;
        var key = (kind, lo, hi);
        if (!memo.TryGetValue(key, out int reg))
        {
            reg = opKind.Count;
            memo[key] = reg;
            opKind.Add(kind);
            opA.Add(lo);
            opB.Add(hi);
        }
        return reg;
    }

    private static CompiledCircuit ReconstructCircuitFromFlat(int[] flatCircuit)
    {
        int p = 0;
        int root = flatCircuit[p++];
        int opsLen = flatCircuit[p++];
        int[] opKind = new int[opsLen];
        int[] opA = new int[opsLen];
        int[] opB = new int[opsLen];
        for (int i = 0; i < opsLen; i++)
        {
            opKind[i] = flatCircuit[p++];
            opA[i] = flatCircuit[p++];
            opB[i] = flatCircuit[p++];
        }
        int insLen = flatCircuit[p++];
        int[] inFactor = new int[insLen];
        int[] inRow = new int[insLen];
        int[] inReg = new int[insLen];
        for (int i = 0; i < insLen; i++)
        {
            inFactor[i] = flatCircuit[p++];
            inRow[i] = flatCircuit[p++];
            inReg[i] = flatCircuit[p++];
        }
        int shLen = flatCircuit[p++];
        int[] shapes = new int[shLen];
        for (int i = 0; i < shLen; i++)
        {
            shapes[i] = flatCircuit[p++];
        }
        return new CompiledCircuit(opKind, opA, opB, inFactor, inRow, inReg, root, shapes);
    }

    [MethodImpl(MethodImplOptions.AggressiveInlining)]
    private static double RunCircuitInternal(
        CompiledCircuit circuit,
        double[][] values,
        double[] registers,
        double[]? derivative,
        double[][]? adjoints)
    {
        int opsLen = circuit.OpKind.Length;
        Array.Clear(registers, 0, opsLen);
        registers[1] = 1.0;

        int[] opKind = circuit.OpKind;
        int[] opA = circuit.OpA;
        int[] opB = circuit.OpB;

        for (int i = 2; i < opsLen; i++)
        {
            switch (opKind[i])
            {
                case 1:
                    registers[i] = values[opA[i]][opB[i]];
                    break;
                case 2:
                    registers[i] = registers[opA[i]] * registers[opB[i]];
                    break;
                case 3:
                    registers[i] = registers[opA[i]] + registers[opB[i]];
                    break;
            }
        }

        double total = registers[circuit.Root];
        if (derivative == null || adjoints == null)
        {
            return total;
        }

        Array.Clear(derivative, 0, opsLen);
        derivative[circuit.Root] = 1.0;
        for (int i = opsLen - 1; i >= 2; i--)
        {
            double d = derivative[i];
            int k = opKind[i];
            if (k == 2)
            {
                int a = opA[i];
                int b = opB[i];
                derivative[a] += d * registers[b];
                derivative[b] += d * registers[a];
            }
            else if (k == 3)
            {
                derivative[opA[i]] += d;
                derivative[opB[i]] += d;
            }
        }

        for (int f = 0; f < adjoints.Length; f++)
        {
            Array.Clear(adjoints[f], 0, adjoints[f].Length);
        }
        int[] inFactor = circuit.InputFactor;
        int[] inRow = circuit.InputRow;
        int[] inReg = circuit.InputReg;
        for (int i = 0; i < inFactor.Length; i++)
        {
            adjoints[inFactor[i]][inRow[i]] = derivative[inReg[i]];
        }

        return total;
    }

    public static double[] RunCircuit(
        int circuitHandle,
        int[] fallbackFlatCircuit,
        int[] valOffsets,
        double[] flatValues,
        bool marginals)
    {
        CompiledCircuit circuit = SolverContext.GetCircuit(circuitHandle)
            ?? ReconstructCircuitFromFlat(fallbackFlatCircuit);

        int nIn = circuit.Shapes.Length;
        var values = new double[nIn][];
        for (int i = 0; i < nIn; i++)
        {
            int start = valOffsets[i];
            int len = valOffsets[i + 1] - start;
            double[] arr = new double[len];
            if (len > 0)
            {
                Array.Copy(flatValues, start, arr, 0, len);
            }
            values[i] = arr;
        }

        double[] registers = new double[circuit.OpKind.Length];
        if (!marginals)
        {
            double totalOnly = RunCircuitInternal(circuit, values, registers, null, null);
            return new[] { totalOnly };
        }

        double[] derivative = new double[circuit.OpKind.Length];
        var adjoints = new double[nIn][];
        int totalAdjElems = 0;
        for (int i = 0; i < nIn; i++)
        {
            int sh = circuit.Shapes[i];
            adjoints[i] = new double[sh];
            totalAdjElems += sh;
        }

        double total = RunCircuitInternal(circuit, values, registers, derivative, adjoints);
        double[] outBuf = new double[1 + totalAdjElems];
        outBuf[0] = total;
        int cursor = 1;
        for (int i = 0; i < nIn; i++)
        {
            double[] adj = adjoints[i];
            Array.Copy(adj, 0, outBuf, cursor, adj.Length);
            cursor += adj.Length;
        }
        return outBuf;
    }

    private sealed class ValuesMatrixKeyComparer : IEqualityComparer<double[][]>
    {
        public static readonly ValuesMatrixKeyComparer Instance = new();

        public bool Equals(double[][]? x, double[][]? y)
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
                double[] a = x[i];
                double[] b = y[i];
                if (a.Length != b.Length)
                {
                    return false;
                }
                for (int j = 0; j < a.Length; j++)
                {
                    if (a[j] != b[j])
                    {
                        return false;
                    }
                }
            }
            return true;
        }

        public int GetHashCode(double[][] obj)
        {
            var hc = new HashCode();
            hc.Add(obj.Length);
            for (int i = 0; i < obj.Length; i++)
            {
                double[] row = obj[i];
                hc.Add(row.Length);
                for (int j = 0; j < row.Length; j++)
                {
                    double v = row[j] == 0.0 ? 0.0 : row[j];
                    hc.Add(BitConverter.DoubleToInt64Bits(v));
                }
            }
            return hc.ToHashCode();
        }
    }

    /// <summary>
    /// Evaluates FactoredChannels.assess over all `size` worlds / representatives in one C# pass.
    /// factorSpecs is stride-6 per factor:
    ///   [0] kindCode (Fact*)
    ///   [1] paramA (sourceIdx / tableIdx / personIdx / seerFlag / scopeNonEmpty)
    ///   [2] paramB (mediumsMask / doubleOffset)
    ///   [3] paramC (walkersMask / doubleLen)
    ///   [4] condRowStart (index into condRowSigs / condRowOffsets)
    ///   [5] condRowCount
    /// publicSpecs is stride-2 per public factor: [targetIdx, convEvilAtEpochFlag], with ratios in publicRatios.
    /// markerFactorIndices &amp; markerAdjRow (0 or 1) describe graph.markers in deterministic order.
    /// Returns flat double[]:
    ///   [statesCount, post[0..size-1], held_marker0[0..size-1], ..., acceptance[0..M-1]]
    /// </summary>
    public static double[] AssessFactoredBatch(
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
        int[] markerAdjRows)
    {
        long[] worlds = SolverContext.ResolveWorlds(universeHandle, Array.Empty<int>(), fallbackWorlds);
        int size = representatives.Length > 0 ? representatives.Length : worlds.Length;
        bool hasReps = representatives.Length > 0;
        bool hasMult = multiplicity.Length > 0;

        CompiledCircuit circuit = SolverContext.GetCircuit(circuitHandle)
            ?? ReconstructCircuitFromFlat(fallbackFlatCircuit);

        int nFactors = factorSpecs.Length / 6;
        int nMarkers = markerFactorIndices.Length;

        // Pre-unpack static/chance/prior constant arrays and conditional row dictionaries:
        var preStatic = new double[nFactors][];
        var prePriorHealthy = new double[nFactors][];
        var prePriorImpaired = new double[nFactors][];
        var condDicts = new Dictionary<long, double[]>?[nFactors];

        for (int f = 0; f < nFactors; f++)
        {
            int off = f * 6;
            int kind = factorSpecs[off];
            int pA = factorSpecs[off + 1];
            int pB = factorSpecs[off + 2];
            int pC = factorSpecs[off + 3];
            int cStart = factorSpecs[off + 4];
            int cCount = factorSpecs[off + 5];

            if (kind == FactStatic)
            {
                double[] arr = new double[pC];
                Array.Copy(factorDoubles, pB, arr, 0, pC);
                preStatic[f] = arr;
            }
            else if (kind == FactPriorConst)
            {
                double p = factorDoubles[pB];
                preStatic[f] = new[] { 1.0 - p, p };
            }
            else if (kind == FactPriorImpaired)
            {
                double pH = factorDoubles[pB];
                double pI = factorDoubles[pB + 1];
                prePriorHealthy[f] = new[] { 1.0 - pH, pH };
                prePriorImpaired[f] = new[] { 1.0 - pI, pI };
            }
            else if (kind == FactChance)
            {
                double ch = factorDoubles[pB];
                preStatic[f] = pA != 0 ? new[] { ch, 1.0 } : new[] { 1.0 };
            }
            else if (kind >= FactCondConst0)
            {
                var dict = new Dictionary<long, double[]>(Math.Max(4, cCount));
                for (int r = 0; r < cCount; r++)
                {
                    int idx = cStart + r;
                    int dStart = condRowOffsets[idx];
                    int dLen = condRowOffsets[idx + 1] - dStart;
                    double[] rowVals = new double[dLen];
                    if (dLen > 0)
                    {
                        Array.Copy(flatCondRows, dStart, rowVals, 0, dLen);
                    }
                    dict[condRowSigs[idx]] = rowVals;
                }
                condDicts[f] = dict;
            }
        }

        double[] reportZero2 = { 1.0, 0.0 };
        double[] reportOne2 = { 1.0, 1.0 };
        double[] scalarZero1 = { 0.0 };
        double[] scalarOne1 = { 1.0 };

        var memo = new Dictionary<double[][], (double Total, double[] MarkerVals)>(
            Math.Min(Math.Max(size, 16), 4096),
            ValuesMatrixKeyComparer.Instance);

        double[] registers = new double[circuit.OpKind.Length];
        double[] derivative = new double[circuit.OpKind.Length];
        var adjoints = new double[nFactors][];
        for (int f = 0; f < nFactors; f++)
        {
            adjoints[f] = new double[circuit.Shapes[f]];
        }

        int outLen = 1 + size + nMarkers * size + nMarkers;
        double[] outBuf = new double[outLen];
        int postBase = 1;
        int heldBase = 1 + size;
        int accBase = 1 + size + nMarkers * size;

        int pubCount = publicSpecs.Length / 2;

        for (int slot = 0; slot < size; slot++)
        {
            int index = hasReps ? representatives[slot] : slot;
            var w = new WorldEntry(worlds[index]);

            var values = new double[nFactors][];
            for (int f = 0; f < nFactors; f++)
            {
                int off = f * 6;
                int kind = factorSpecs[off];
                int pA = factorSpecs[off + 1];
                int pB = factorSpecs[off + 2];
                int pC = factorSpecs[off + 3];

                switch (kind)
                {
                    case FactStatic:
                    case FactPriorConst:
                    case FactChance:
                        values[f] = preStatic[f];
                        break;

                    case FactPriorImpaired:
                        values[f] = WorldDomainKernel.Healthy(w.Raw, pA)
                            ? prePriorHealthy[f]
                            : prePriorImpaired[f];
                        break;

                    case FactReport:
                    {
                        bool holds = flatByteTables[pB * tableStride + index] != 0;
                        values[f] = pA != 0
                            ? (holds ? reportOne2 : reportZero2)
                            : (holds ? scalarOne1 : scalarZero1);
                        break;
                    }

                    case FactKnowledge:
                    {
                        bool ok = flatByteTables[pB * tableStride + index] != 0;
                        values[f] = ok ? scalarOne1 : scalarZero1;
                        break;
                    }

                    case FactPublic:
                    {
                        double weight = 1.0;
                        for (int pi = 0; pi < pubCount; pi++)
                        {
                            int tIdx = publicSpecs[pi * 2];
                            bool convEvil = publicSpecs[pi * 2 + 1] != 0;
                            if (SolverKernel.EvilIndex(w, tIdx, convEvil))
                            {
                                weight *= publicRatios[pi];
                            }
                        }
                        values[f] = new[] { weight };
                        break;
                    }

                    case FactCondConst0:
                        values[f] = condDicts[f]![0L];
                        break;

                    case FactCondActivity:
                    {
                        long sig = (w.DemonOrMinusOne == pA)
                            ? 2L
                            : (((w.Evil & (1 << pA)) != 0) ? 1L : 0L);
                        values[f] = condDicts[f]![sig];
                        break;
                    }

                    case FactCondRoles:
                    {
                        long sig = RoleConstraintsKernel.CoarseMask(nPeople, w, pA != 0, pB, pC);
                        values[f] = condDicts[f]![sig];
                        break;
                    }

                    case FactCondSpeech:
                    {
                        long sig = (long)w.Evil * (nPeople + 1L) + (long)w.DemonOrMinusOne + 1L;
                        values[f] = condDicts[f]![sig];
                        break;
                    }
                }
            }

            if (!memo.TryGetValue(values, out var cached))
            {
                double tot = RunCircuitInternal(circuit, values, registers, derivative, adjoints);
                double[] mVals = new double[nMarkers];
                for (int m = 0; m < nMarkers; m++)
                {
                    mVals[m] = adjoints[markerFactorIndices[m]][markerAdjRows[m]];
                }
                cached = (tot, mVals);
                memo[values] = cached;
            }

            outBuf[postBase + slot] = cached.Total;
            for (int m = 0; m < nMarkers; m++)
            {
                outBuf[heldBase + m * size + slot] = cached.MarkerVals[m];
            }
        }

        outBuf[0] = memo.Count;

        double totalMass = 0.0;
        for (int slot = 0; slot < size; slot++)
        {
            double mult = hasMult ? multiplicity[slot] : 1.0;
            totalMass += outBuf[postBase + slot] * mult;
        }

        for (int m = 0; m < nMarkers; m++)
        {
            double mass = 0.0;
            int mBase = heldBase + m * size;
            for (int slot = 0; slot < size; slot++)
            {
                double mult = hasMult ? multiplicity[slot] : 1.0;
                mass += outBuf[mBase + slot] * mult;
            }
            outBuf[accBase + m] = totalMass > 0.0 ? (mass / totalMass) : 0.0;
        }

        return outBuf;
    }
}
