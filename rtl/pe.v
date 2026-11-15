`timescale 1ns/1ps
module pe #(parameter W=8, parameter ACC_W=18)(
 input clk, rst, clear, enable,
 input signed [W-1:0] a_in,b_in,
 output reg signed [W-1:0] a_out,b_out,
 output reg signed [ACC_W-1:0] acc
);
 wire signed [ACC_W-1:0] next_acc;
 mac #(.W(W),.ACC_W(ACC_W)) arithmetic(a_in,b_in,acc,next_acc);
 always @(posedge clk) begin
  if (rst || clear) begin a_out<=0; b_out<=0; acc<=0; end
  else if (enable) begin
   a_out<=a_in; b_out<=b_in; acc<=next_acc;
  end
 end
endmodule
