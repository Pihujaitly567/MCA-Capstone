# Systolic Array Matrix Multiplication Accelerator

A working teaching project: parameterized signed Verilog RTL, a default 3×3 array, self-checking testbenches, VCD waveforms, and reproducible synthesis scripts. Start with the [run and demonstration guide](docs/RUN_AND_DEMO.md). The [technical report](docs/TECHNICAL_REPORT.md) explains the architecture, timing, numeric format, measured resources, and limitations.

## Quick start

Run these commands in this project directory:

```sh
make test          # PE tests and matrix checks for N=1,3,4
make demo          # 3×3 demonstration; refresh build/array.vcd
make synth         # generic gate synthesis
make synth-fpga    # Xilinx 7-series resource mapping
```

Requires Icarus Verilog (`iverilog`, `vvp`), Make, and Yosys for synthesis. GTKWave is optional. No Python packages or proprietary tools are required for the simulation demo.

Expected 3×3 result:

```text
30   24  18
84   69  54
138 114  90
PASS array N=3: 27 jobs, latency=7 cycles
```

Files: `rtl/mac.v`, `rtl/pe.v`, `rtl/systolic_array.v`; tests in `tb/`; synthesis flows in `scripts/`. Generated reports and waveforms appear in `build/`.

Video link: https://drive.google.com/file/d/1ie0hjAKfvPVRXL3KCM5HGUGDSfp7DLX-/view?usp=sharing
