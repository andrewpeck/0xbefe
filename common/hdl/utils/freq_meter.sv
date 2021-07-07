`timescale 1ns / 1ps

module freq_meter #(parameter REF_F = 32'd320628800, parameter N = 12)
(
    input ref_clk,
    input [N-1:0] f,
    output reg [31:0] freq [N-1:0]
);

    (* async_reg *) reg [31:0] cnt [N-1:0];
    reg [31:0] ref_cnt;

    integer i;

    always @(posedge ref_clk)
    begin
        if (ref_cnt == REF_F) // 1 second just ended
        begin
            for (i = 0; i < N; i++)
            begin
                freq[i] = cnt[i];
            end
            ref_cnt = 32'h0;
        end

        ref_cnt++;
    end

    wire cnt_rst = (ref_cnt[31:3] == 29'h0) ? 1'b1 : 1'b0;

    genvar gi;
    generate
        for (gi = 0; gi < N; gi++)
        begin
            always @(posedge f[gi]) if (cnt_rst) cnt[gi] = 32'h0; else cnt[gi]++;
        end
    endgenerate

endmodule

