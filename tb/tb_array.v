`timescale 1ns/1ps
module tb_array;
 parameter N=3;
 localparam W=8, AW=2*W+$clog2(N), LAT=3*N-2;
 reg clk=0; always #5 clk=~clk;
 reg rst=1,load_en=0,load_b=0,start=0;
 reg [31:0] load_row=0,load_col=0;
 reg signed [W-1:0] load_data=0;
 wire busy,done;
 wire [N*N*AW-1:0] result;
 integer a[0:N*N-1],b[0:N*N-1];
 integer i,j,k,t,cycles,expected,observed,seed=12;
 systolic_array #(.N(N)) dut(clk,rst,load_en,load_b,load_row,load_col,load_data,start,busy,done,result);
 task tick; begin @(posedge clk); #1; end endtask
 task load_matrices;
  integer s,r,c;
  begin
   for(s=0;s<2;s=s+1) for(r=0;r<N;r=r+1) for(c=0;c<N;c=c+1) begin
    @(negedge clk); load_en=1; load_b=s; load_row=r; load_col=c;
    load_data=s ? b[r*N+c] : a[r*N+c]; tick;
   end
   @(negedge clk); load_en=0;
  end
 endtask
 task run_check;
  begin
   @(negedge clk); start=1; tick;
   if(!busy || done) $fatal(1,"start handshake");
   @(negedge clk); start=0;
   cycles=0;
   while(!done && cycles<LAT+2) begin
    // Writes and start while busy must be ignored.
    load_en=1; load_data=99; load_row=0; load_col=0;
    start=(cycles==0); tick; cycles=cycles+1;
    @(negedge clk); start=0;
   end
   load_en=0;
   if(cycles!=LAT || busy || !done) $fatal(1,"latency N=%0d cycles=%0d",N,cycles);
   for(i=0;i<N;i=i+1) begin
    for(j=0;j<N;j=j+1) begin
     expected=0;
     for(k=0;k<N;k=k+1) expected=expected+a[i*N+k]*b[k*N+j];
     observed=$signed(result[(i*N+j)*AW +: AW]);
     if(observed!==expected) $fatal(1,"N=%0d C[%0d,%0d] got %0d expected %0d",N,i,j,observed,expected);
     if(t==0) $write("%8d ",observed);
    end
    if(t==0) $write("\n");
   end
   tick; if(done) $fatal(1,"done must pulse");
  end
 endtask
 initial begin
  $dumpfile("build/array.vcd"); $dumpvars(0,tb_array);
  tick; @(negedge clk); rst=0;
  for(t=0;t<25;t=t+1) begin
   for(i=0;i<N*N;i=i+1) begin
    case(t)
     0: begin a[i]=i+1; b[i]=N*N-i; end
     1: begin a[i]=0; b[i]=-128; end
     2: begin a[i]=(i/N==i%N)?16:0; b[i]=(i%2)?-24:32; end
     3: begin a[i]=-128; b[i]=-128; end
     4: begin a[i]=127; b[i]=(i%2)?-128:127; end
     default: begin a[i]=$random(seed)%128; b[i]=$random(seed)%128; end
    endcase
   end
   load_matrices; run_check;
   // Reuse buffers to verify that start clears previous accumulation.
   if(t==0) run_check;
  end
  // Abort an in-flight multiply with synchronous reset, then recover.
  @(negedge clk); start=1; tick;
  @(negedge clk); start=0; rst=1; tick;
  if(busy || done || result!==0) $fatal(1,"reset abort");
  @(negedge clk); rst=0;
  load_matrices; run_check;
  $display("PASS array N=%0d: 27 jobs, latency=%0d cycles",N,LAT);
  $finish;
 end
 initial begin #1000000; $fatal(1,"timeout"); end
endmodule
