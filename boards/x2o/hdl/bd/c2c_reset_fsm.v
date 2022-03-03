`timescale 1ns / 1ps
module c2c_reset_fsm
(
    input manual_reset, // manual reset
    input reset_command, // command from master
    
    input phy_clk, // clock for c2c TX and RX streams
    
    output reg c2c_channel_up, // this tells c2c to start linking with master
    output reg m_aresetn, // c2c also needs m_aresetn to start linking

    output reg [1:0] state
);

    reg [19:0] timeout_cnt = 20'd1000000;

    // FSM states
    localparam IDLE = 2'h0;
    localparam MRST = 2'h1;
    localparam CRST = 2'h2;

    initial
    begin
        state = IDLE;
    end

    reg [3:0] rstd = 4'b0;

    always @(posedge phy_clk)
    begin
    
        c2c_channel_up = 1'b1;
        m_aresetn = 1'b1;
    
        case (state)
        
            IDLE: // c2c link is up, just wait for reset
            begin
                if (rstd == 4'b1000) // falling edge of reset
                begin
                    timeout_cnt = 20'd100;
                    state = MRST;
                end    
            end
            
            MRST: // drive both resets
            begin
                c2c_channel_up = 1'b0;
                m_aresetn = 1'b0;
                timeout_cnt = timeout_cnt - 20'h1; 
                if (timeout_cnt == 20'h0) // reset done
                begin
                    timeout_cnt = 20'd100;
                    state = CRST;
                end
            end

            CRST: // just c2c_channel_up here 
            begin
                c2c_channel_up = 1'b0;
                timeout_cnt = timeout_cnt - 20'h1; 
                if (timeout_cnt == 20'h0) // reset done
                    state = IDLE;
            end
        endcase
        
        rstd = {rstd[2:0], manual_reset | reset_command};
        
    end


endmodule
