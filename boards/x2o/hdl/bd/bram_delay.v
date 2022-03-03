`timescale 1ns / 1ps

module bram_delay
(
    input [6:0] delay,
    input [31:0] di,
    output reg [31:0] dout,
    input clk
);

    reg [31:0] dd [127:0];
    integer i;

    always @(posedge clk)
    begin
        dout = dd[delay];
    
        for (i = 126; i >= 0; i=i-1)
        begin
            dd[i+1] = dd[i];
        end
        dd[0] = di;
    end

endmodule
