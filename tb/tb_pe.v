`timescale 1ns/1ps
module tb_pe;
 reg clk=0; always #5 clk=~clk;
 reg rst=1,clear=0,enable=0;
 reg signed [7:0] a=0,b=0;
 wire signed [7:0] ao,bo;
 wire signed [17:0] acc;
 pe dut(clk,rst,clear,enable,a,b,ao,bo,acc);
 task tick; begin @(posedge clk); #1; end endtask
 initial begin
  $dumpfile("build/pe.vcd"); $dumpvars(0,tb_pe);
  tick; if(acc!==0 || ao!==0 || bo!==0) $fatal(1,"reset");
  @(negedge clk); rst=0; enable=1; a=7; b=-3;
  tick; if(acc!==-21 || ao!==7 || bo!==-3) $fatal(1,"signed MAC/forwarding");
  @(negedge clk); a=-128; b=-128;
  tick; if(acc!==16363) $fatal(1,"extreme MAC");
  @(negedge clk); enable=0; a=5; b=5;
  tick; if(acc!==16363 || ao!==-128) $fatal(1,"hold");
  @(negedge clk); clear=1;
  tick; if(acc!==0 || ao!==0 || bo!==0) $fatal(1,"clear");
  $display("PASS PE: signed MAC, extremes, forwarding, hold, clear, reset");
  $finish;
 end
 initial begin #10000; $fatal(1,"timeout"); end
endmodule
