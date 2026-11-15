IVERILOG ?= iverilog
VVP ?= vvp
RTL = rtl/mac.v rtl/pe.v rtl/systolic_array.v
.PHONY: all test demo synth synth-fpga clean
all: test
test:
	@mkdir -p build
	$(IVERILOG) -g2012 -Wall -s tb_pe -o build/pe $(RTL) tb/tb_pe.v
	$(VVP) build/pe
	@for n in 1 3 4; do \
	 $(IVERILOG) -g2012 -Wall -s tb_array -Ptb_array.N=$$n -o build/array_$$n $(RTL) tb/tb_array.v && \
	 $(VVP) build/array_$$n || exit 1; \
	 done
demo:
	@mkdir -p build
	$(IVERILOG) -g2012 -s tb_array -o build/array_3 $(RTL) tb/tb_array.v
	$(VVP) build/array_3
synth:
	@mkdir -p build
	yosys -s scripts/synth.ys > build/synthesis.log
	@tail -35 build/synthesis.log
synth-fpga:
	@mkdir -p build
	yosys -s scripts/synth_xilinx.ys > build/synthesis_xilinx.log
	@tail -40 build/synthesis_xilinx.log
clean:
	rm -rf build
