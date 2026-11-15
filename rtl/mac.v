`timescale 1ns/1ps
// Full precision signed product, followed by an accumulator-width addition.
module mac #(parameter W=8, parameter ACC_W=18)(
 input signed [W-1:0] a,b,
 input signed [ACC_W-1:0] acc,
 output signed [ACC_W-1:0] next_acc
);
 wire signed [2*W-1:0] product = a*b;
 assign next_acc = acc + product;
endmodule
