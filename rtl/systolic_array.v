`timescale 1ns/1ps
// Output-stationary array. Load operands while idle, pulse start, wait for done.
// Packed result element (r,c): result[(r*N+c)*ACC_W +: ACC_W].
module systolic_array #(
 parameter N=3, parameter W=8,
 parameter ACC_W=2*W+$clog2(N)
)(
 input clk,rst,
 input load_en, load_b,
 input [31:0] load_row,load_col,
 input signed [W-1:0] load_data,
 input start,
 output reg busy,done,
 output [N*N*ACC_W-1:0] result
);
 localparam LAST_STEP=3*N-3;
 reg signed [W-1:0] a_mem[0:N*N-1], b_mem[0:N*N-1];
 reg [31:0] step;
 wire signed [W-1:0] a_link[0:N-1][0:N];
 wire signed [W-1:0] b_link[0:N][0:N-1];
 wire clear = start && !busy;
 integer i;
 always @(posedge clk) begin
  if (rst) begin
   busy<=0; done<=0; step<=0;
   for(i=0;i<N*N;i=i+1) begin a_mem[i]<=0; b_mem[i]<=0; end
  end else begin
   done<=0;
   if (!busy) begin
    if(load_en && load_row<N && load_col<N) begin
     if(load_b) b_mem[load_row*N+load_col]<=load_data;
     else a_mem[load_row*N+load_col]<=load_data;
    end
    if(start) begin busy<=1; step<=0; end
   end else if(step==LAST_STEP) begin busy<=0; done<=1; end
   else step<=step+1;
  end
 end
 genvar r,c;
 generate for(r=0;r<N;r=r+1) begin: rows
  // Row r and column r are delayed by r cycles at the array boundary.
  assign a_link[r][0] = (busy && step>=r && step<r+N)
                                ? a_mem[r*N+(step-r)] : {W{1'b0}};
  assign b_link[0][r] = (busy && step>=r && step<r+N)
                                ? b_mem[(step-r)*N+r] : {W{1'b0}};
  for(c=0;c<N;c=c+1) begin: cols
   pe #(.W(W),.ACC_W(ACC_W)) cell_pe(
    .clk(clk),.rst(rst),.clear(clear),.enable(busy),
    .a_in(a_link[r][c]),.b_in(b_link[r][c]),
    .a_out(a_link[r][c+1]),.b_out(b_link[r+1][c]),
    .acc(result[(r*N+c)*ACC_W +: ACC_W]));
  end
 end endgenerate
endmodule
