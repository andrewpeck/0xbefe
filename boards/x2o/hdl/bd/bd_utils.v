`timescale 1ns / 1ps

module ff_util
(
    input d,
    output reg q,
    input c
);

    always @(posedge c) q = d;

endmodule

