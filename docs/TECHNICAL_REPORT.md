# Technical report: small systolic matrix accelerator

## Objective and architecture

Compute C=A×B for two N×N signed matrices. The default N=3 design contains nine output-stationary processing elements. The hierarchy is `systolic_array → pe → mac`. Internal register arrays buffer A and B; each PE owns an accumulator that serves as one output register. A load interface and cycle controller are included in the top module.

```text
 load interface --> A/B register buffers --> skewed boundary inputs
                         controller: step, busy, done

                  B col 0 ↓    B col 1 ↓    B col 2 ↓
 A row 0 ------> [ PE 0,0 ] -> [ PE 0,1 ] -> [ PE 0,2 ]
                    ↓             ↓             ↓
 A row 1 ------> [ PE 1,0 ] -> [ PE 1,1 ] -> [ PE 1,2 ]
                    ↓             ↓             ↓
 A row 2 ------> [ PE 2,0 ] -> [ PE 2,1 ] -> [ PE 2,2 ]

 Each PE: A forwards right, B forwards down, C accumulates locally.
 All C registers --> packed row-major result bus
```

Each enabled cycle performs `acc ← acc + a_in*b_in` and registers the operands for the neighboring PEs. The accumulator is cleared on accepted start and synchronous reset. All useful products are full precision; injected zero padding makes explicit per-PE valid signals unnecessary.

## Data movement

At compute step t, row r receives A[r,t−r] if 0≤t−r<N; column c receives B[t−c,c] if 0≤t−c<N. Other boundary inputs are zero. Forwarding adds one cycle per hop, so A[r,k] and B[k,c] meet at PE[r,c] at step k+r+c. This proves that each PE accumulates the correct dot product.

For N=3:

| Step | Left boundary, rows 0 / 1 / 2 | Top boundary, columns 0 / 1 / 2 |
|---|---|---|
| 0 | A00 / 0 / 0 | B00 / 0 / 0 |
| 1 | A01 / A10 / 0 | B10 / B01 / 0 |
| 2 | A02 / A11 / A20 | B20 / B11 / B02 |
| 3 | 0 / A12 / A21 | 0 / B21 / B12 |
| 4 | 0 / 0 / A22 | 0 / 0 / B22 |
| 5–6 | 0 / 0 / 0 | 0 / 0 / 0 |

Steps 5 and 6 drain products already traveling through the array.

## Controller and interface contract

The controller uses two states encoded by `busy`:

```text
 IDLE -- accepted start / clear PEs, step=0 --> RUN
 RUN  -- step < 3N−3 / step++ -------------> RUN
 RUN  -- step = 3N−3 / done=1 -------------> IDLE
 Any state -- rst ------------------------> IDLE, clear all registers
```

All inputs are sampled on rising clock edges. Reset is synchronous and active high. Drive testbench inputs on falling edges to avoid races.

| Signal | Meaning |
|---|---|
| load_en | Write one operand element while idle |
| load_b | 0 selects A, 1 selects B |
| load_row, load_col | Unsigned 32-bit indices; invalid indices are ignored |
| load_data | Signed W-bit operand |
| start | Assert for one clock while idle to start a job |
| busy | Computation is in progress; writes and new starts are ignored |
| done | One-cycle completion pulse; the entire result is valid |
| result | N² signed ACC_W-bit values packed in row-major order |

Slice C[r,c] as `result[(r*N+c)*ACC_W +: ACC_W]` and interpret the slice as signed. Results remain stable after completion until another start or reset. They are partial sums while busy. A simultaneous idle load and start is allowed: the written value is available before compute step zero. Holding start high can launch another job when the controller returns idle; normally use a pulse. Buffers persist between jobs and are zeroed on reset.

## Numeric format

Default operands are signed 8-bit two's-complement raw values (−128…127). Default ACC_W = 2W + ceil(log2(N)), giving 18 bits for N=3 and N=4. This width preserves the worst-case N-term signed dot product without saturation or truncation. Explicitly overriding ACC_W with a smaller width causes wraparound overflow.

The same hardware supports fixed point: interpret inputs as raw integers divided by 16 (four fractional bits, signed range −8…7.9375). Interpret output as its signed raw integer divided by 256 (eight fractional bits). No rounding or rescaling occurs inside the accelerator. For example, raw inputs 24 and −8 represent 1.5 and −0.5; their raw product −192 represents −0.75. The scaled identity test uses diagonal raw 16 to represent 1.0.

## Performance and baseline comparison

The last useful product reaches PE[N−1,N−1] at step 3N−3. Therefore there are L=3N−2 compute cycles after the start acceptance edge. The clear/start edge is a separate preparation edge.

The baseline below is an analytical single-MAC engine performing one useful MAC each clock, with operands already available, requiring N³ compute cycles. No sequential baseline RTL or measured baseline timing is claimed.

| Metric | N=3 | N=4 |
|---|---:|---:|
| Physical MAC units | 9 | 16 |
| Useful MACs/job | 27 | 64 |
| Array compute cycles L | 7 | 10 |
| Single-MAC compute cycles | 27 | 64 |
| Compute-cycle speedup N³/L | 3.86× | 6.40× |
| Useful MACs/compute cycle | 3.86 | 6.40 |
| PE utilization N³/(N²L) | 42.86% | 40% |
| Start-to-start interval, retained inputs | 8 cycles | 11 cycles |
| Start-to-start interval, new inputs | 26 cycles | 43 cycles |

The interface loads one element per clock, so two matrices need 2N² writes. With no unnecessary idle cycles, a fresh-input job consumes 2N²+1+L clocks: 18+1+7=26 for N=3. Loading can start at the edge after completion; starting can follow the final write. Retained-input jobs require 1+L clocks. The supplied testbench deliberately inserts some extra idle edges for readability, so wall-clock testbench duration is not the theoretical minimum transaction interval.

At a hypothetical 100 MHz clock, compute latency is 70 ns for N=3; fresh-input throughput is 100 million/26 = 3.85 million matrices/s. These are arithmetic projections, not achieved board timing. Equal-clock compute speedup excludes loading, preparation, and baseline memory/control overhead. If both engines use the same 18-cycle loading and one-cycle preparation assumption, N=3 end-to-end speedup is (18+1+27)/26 = 1.77×. A wider loader or double buffering would improve throughput but is outside this simple project.

## Verification and measured synthesis

Validated with Icarus Verilog and Yosys 0.70+post on the supplied environment. `make test` passed the dedicated PE test plus 27 jobs each for N=1, N=3 and N=4. Assertions cover reference results, latency, handshake, busy-time interference, done pulse width, accumulator reuse, and reset abort/recovery. VCD traces expose operand movement and partial sums; the run guide gives specific values to inspect. Automated checking uses an independently calculated matrix result and tests control timing; waveform review remains available for visual demonstration.

Reproduce synthesis with `make synth` and `make synth-fpga`. For default N=3, W=8, ACC_W=18:

| Resource | Measured result |
|---|---:|
| Generic mapped cells, including submodules | 6,795 |
| Xilinx 7-series DSP48E1 | 9 |
| Xilinx 7-series FDRE flip-flops | 544 |
| Xilinx LUT2 / LUT3 / LUT4 / LUT5 / LUT6 | 26 / 102 / 36 / 32 / 102 |
| Total mapped LUT primitives | 298 |
| CARRY4 | 28 |
| BUFG | 1 |

Generic gate counts and FPGA primitive counts come from separate synthesis flows and are not interchangeable. Buffer arrays are mapped into registers for this small design; no block RAM is inferred. LUT primitives are a synthesis mapping count, not final occupied slices. Tool versions and optimization can change these values.

Maximum operating frequency: **not measured**. Vivado is not part of the completed validation. `scripts/vivado.tcl` provides an optional routed core timing flow for an Artix-7 device; copy actual resource, worst slack, and timing-limit results into a board submission after running it. External paths are excluded in that script, so its timing result does not validate an external matrix interface. There is no fabricated MHz result or claim of hardware deployment.

## Scope and extensions

This design is a small accelerator core with a simulation demonstration. It has no CPU bus, DMA, UART, board pin mapping, overlapping jobs, or double buffering. Dynamic buffer addressing and a 32-bit controller favor simplicity over minimum area. An FPGA deployment should wrap the core with a narrow communication interface and board-specific constraints. Useful extensions are a sequential RTL baseline, a real board wrapper, a smaller counter/index interface, and double-buffered input streaming.
