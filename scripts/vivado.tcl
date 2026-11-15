# Run from project root: vivado -mode batch -source scripts/vivado.tcl
# Override with: FPGA_PART=xc7a35tcpg236-1 vivado ...
set part xc7a35tcpg236-1
if {[info exists ::env(FPGA_PART)]} { set part $::env(FPGA_PART) }
file mkdir build/vivado
read_verilog [glob rtl/*.v]
synth_design -top systolic_array -part $part
create_clock -name clk -period 10.000 [get_ports clk]
# Core-only estimate: external loading/result paths are excluded deliberately.
set_false_path -from [get_ports {rst load_en load_b load_row[*] load_col[*] load_data[*] start}]
set_false_path -to [get_ports {busy done result[*]}]
opt_design
place_design
route_design
report_utilization -file build/vivado/utilization.rpt
report_timing_summary -file build/vivado/timing.rpt
report_timing -max_paths 10 -file build/vivado/critical_paths.rpt
write_checkpoint -force build/vivado/routed.dcp
