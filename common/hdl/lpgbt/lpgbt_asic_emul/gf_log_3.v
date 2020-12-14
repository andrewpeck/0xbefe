module gf_log_3(op, err, res);
	
// -------------------------------------------------------------------------- //
// ------------- Triple Modular Redundancy Generator Directives ------------- //
// -------------------------------------------------------------------------- //
// tmrg do_not_touch
// -------------------------------------------------------------------------- //

	input      [2:0] op;
	output reg       err;
	output reg [2:0] res;

	always @(op) begin
		case(op)
			3'd0 :
			begin 
				err  = 1;
				res  = 3'd0;
			end

			3'd1 : 
			begin
				err  = 0;
				res  = 3'd0;
			end

			3'd2 : 
			begin
				err  = 0;
				res  = 3'd1;
			end

			3'd3 : 
			begin
				err  = 0;
				res  = 3'd3;
			end

			3'd4 : 
			begin
				err  = 0;
				res  = 3'd2;
			end

			3'd5 : 
			begin
				err  = 0;
				res  = 3'd6;
			end

			3'd6 : 
			begin
				err  = 0;
				res  = 3'd4;
			end

			3'd7 : 
			begin
				err  = 0;
				res  = 3'd5;
			end

		endcase
	end
endmodule
			
