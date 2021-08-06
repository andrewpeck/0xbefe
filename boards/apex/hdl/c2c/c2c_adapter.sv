`timescale 1ns / 1ps

module c2c_adapter
(
    input c2c_phy_clk,
    
    output reg [31:0] c2c_rx_data,
    output reg        c2c_rx_valid,
    
    input [31:0] c2c_tx_tdata,
    input        c2c_tx_tvalid,
    input        do_cc,
    output reg   link_reset,
    
    input [31:0] mgt_rx_data,
    input [ 3:0] mgt_rx_k,
    input        rx_aligned,
    
    output reg [31:0] mgt_tx_data,
    output reg [ 3:0] mgt_tx_k
);

    // clock correction pattern    
    wire [31:0] clkc_d = 32'h000050bc;
    wire [ 3:0] clkc_k = 4'b0001;

    // link reset command pattern    
    wire [31:0] lrst_d = 32'hfcfcfcfc;
    wire [ 3:0] lrst_k = 4'b1111;

    wire [31:0] zero_d = 32'h0;
    wire [ 3:0] zero_k = 4'b0;
    
    // sync patterns used by c2c slave
    wire [31:0] spatd0 = 32'h001011bc;
    wire [31:0] spatd1 = 32'h001011fc;
    wire [31:0] spatd2 = 32'h001011dc;
    
    wire tx_can_cc = (c2c_tx_tdata == spatd0) || (c2c_tx_tdata == spatd1) || (c2c_tx_tdata == zero_d);
    
    reg do_cc_r;
    reg [9:0] link_reset_cnt = 10'd0;
    
    always @(posedge c2c_phy_clk)
    begin
    
        // link reset logic
        if (link_reset_cnt == 10'd0) link_reset = 1'b0;
        else link_reset_cnt--;
    
        // rx logic
        if (mgt_rx_data == lrst_d && mgt_rx_k == lrst_k) // link reset command from master
        begin
            // replace with invalid data
            c2c_rx_data  = zero_d;
            c2c_rx_valid = 1'b0;
            link_reset_cnt = 10'd1000;
            link_reset = 1'b1;
        end
        else
        if (mgt_rx_data == clkc_d && mgt_rx_k == clkc_k) // CC symbol
        begin
            // replace with invalid data
            c2c_rx_data  = zero_d;
            c2c_rx_valid = 1'b0;
        end
        else
        begin
            c2c_rx_data = mgt_rx_data;
            c2c_rx_valid = rx_aligned;
        end


        
        // tx logic
        if (c2c_tx_tvalid == 1'b0)
        begin 
            if (do_cc_r) // CC needed
            begin
                mgt_tx_data = clkc_d; 
                mgt_tx_k = clkc_k;
                do_cc_r = 1'b0;
            end
            else
            begin
                // send invalid pattern
                mgt_tx_data = zero_d; 
                mgt_tx_k = zero_k;
            end
        end
        else
        begin 
            if (do_cc_r && tx_can_cc) // CC needed and pattern can be interrupted
            begin
                mgt_tx_data = clkc_d; 
                mgt_tx_k = clkc_k;
                do_cc_r = 1'b0;
            end
            else
            begin
                // valid data that cannot be interrupted
                mgt_tx_data = c2c_tx_tdata; 
                mgt_tx_k = zero_k;
            end
        end
        
        if (do_cc) do_cc_r = 1'b1;
    end

endmodule

