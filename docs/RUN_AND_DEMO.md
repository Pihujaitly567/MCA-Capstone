# How to run and demonstrate the project

## 1. Install tools

On Ubuntu/Debian:

```sh
sudo apt update
sudo apt install iverilog yosys gtkwave make
```

For other operating systems, install Icarus Verilog, Yosys, Make, and optionally a VCD-compatible waveform viewer using the supported installation method.

Open a terminal in the project folder. All commands below run from that folder.

## 2. Run functional verification

```sh
make test
```

The command must exit successfully and print PASS for the PE and N=1, N=3, N=4 arrays. Any mismatch or timeout calls `$fatal` and fails the command. Each array configuration runs 27 jobs against a triple-loop reference model, including repeated runs without reloading, signed operands, zeros, identity-scaled data, extreme values, deterministic random inputs, and recovery after reset during computation. Busy-time writes and start pulses are checked by issuing them during every job.

The array test's integer reference computes `sum(A[i,k]*B[k,j])` independently of the streaming schedule. The PE test separately checks signed products, accumulation, forwarding, enable hold, clear, and reset.

## 3. Run the 3×3 demonstration

```sh
make demo
```

The first matrices are:

```text
A = 1 2 3       B = 9 8 7
    4 5 6           6 5 4
    7 8 9           3 2 1
```

The printed result is:

```text
C = 30  24 18
    84  69 54
   138 114 90
```

For example, C[0,0] = 1×9 + 2×6 + 3×3 = 30. The first result prints twice because the test repeats the job using the same input buffers to verify accumulator clearing. Further directed and random cases run silently unless a mismatch occurs.

## 4. Inspect the waveforms

```sh
gtkwave build/array.vcd
```

Run `make demo` immediately before opening this file: `make test` overwrites it with the last configuration, N=4. Open `build/pe.vcd` for the standalone PE test.

In the array waveform, expand `tb_array` and `dut`. Add `clk`, `rst`, `load_en`, `load_b`, `load_row`, `load_col`, `load_data`, `start`, `busy`, `done`, `step`, and `result`. Expand generated scopes `rows[0].cols[0].cell_pe` and `rows[2].cols[2].cell_pe`; inspect `a_in`, `b_in`, and `acc`. Use signed decimal radix for operands and accumulators.

Locate the first rising edge accepting `start` while idle. That edge clears the PEs and makes `busy` high. The next seven rising edges execute steps 0–6. At step 6, `done` becomes high, `busy` becomes low, and all results are valid. Simulation uses a 10 ns clock; this is a testbench setting, not a demonstrated FPGA timing limit.

The first PE accumulates 9, 21, 30 over steps 0, 1, 2. The bottom-right PE sees its useful products at steps 4, 5, 6 and accumulates 21, 53, 90. `done` stays high for one clock. Packed result slices are row-major, starting at the least significant bits; with default parameters C[0,0] occupies bits 17:0 and C[2,2] occupies bits 161:144.

## 5. Generate synthesis reports

```sh
make synth
make synth-fpga
```

Inspect `build/synthesis.log` and `build/synthesis_xilinx.log`. The second script maps to Xilinx 7-series primitives and reports DSPs, LUTs and flip-flops. These are synthesis estimates; they do not establish routed timing or board operation.

If Vivado is installed, run from the project root:

```sh
vivado -mode batch -source scripts/vivado.tcl
```

The default part is `xc7a35tcpg236-1`. Override it when needed:

```sh
FPGA_PART=xc7a100tcsg324-1 vivado -mode batch -source scripts/vivado.tcl
```

The script synthesizes, places, routes, and writes utilization and timing reports to `build/vivado/`. It targets a 10 ns core clock and excludes external interface timing. It creates no bitstream or board pin constraints. Use the worst internal setup path delay from the timing report to estimate Fmax; check hold timing and all remaining constraints as well. A rough estimate from a 10 ns constraint is `1000/(10 - WNS)` MHz, valid only for the reported internal single-cycle path group. Report the actual device, tool version, constraints, and measured timing with the result.

A physical board demo requires a board-specific wrapper (for example UART register writes and result reads), clock/reset handling, and pin/timing constraints. The parallel core interface is intended for integration inside a larger FPGA design. Directly exposing every core port as a package pin can exceed a small board's available pins. This project provides a complete simulation demo, not an unverified board bitstream.

## 6. Suggested five-minute presentation

1. Show the diagram in the technical report. Explain that A travels right, B travels down, and each PE keeps one output sum.
2. Show `rtl/pe.v`: a registered MAC and operand forwarding.
3. Run `make test` and point out all four PASS lines.
4. Run `make demo`; verify C[0,0] by hand.
5. Show the first and last PE in the waveform and count seven compute edges.
6. Show `make synth-fpga`, then explain the 27/7 = 3.86× compute-cycle comparison and the loading overhead. State that routed Fmax is pending unless you have run Vivado.

## 7. Change the example

Edit case `0` in `tb/tb_array.v` to change the demonstration operands. The reference model automatically checks the new result. To run another size manually:

```sh
iverilog -g2012 -s tb_array -Ptb_array.N=4 -o build/demo4 rtl/mac.v rtl/pe.v rtl/systolic_array.v tb/tb_array.v
vvp build/demo4
```

Use N≥1, W≥2, and ACC_W≥2W+ceil(log2(N)) for the stated full-precision guarantee. The supplied testbench is designed for 8-bit inputs and small array sizes. `make clean` removes generated output; rerun a Make target to recreate it.
