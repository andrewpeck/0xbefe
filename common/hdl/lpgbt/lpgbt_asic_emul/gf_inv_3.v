module gf_inv_3(op, res);
	
// -------------------------------------------------------------------------- //
// ------------- Triple Modular Redundancy Generator Directives ------------- //
// -------------------------------------------------------------------------- //
// tmrg do_not_touch
// -------------------------------------------------------------------------- //

	input      [2:0] op;
	output reg [2:0] res;

	always @(op) begin
		case(op) 
			3'd0 : 
				res  = 3'd0;
			3'd1 : 
				res  = 3'd1;
			3'd2 : 
				res  = 3'd5;
			3'd3 : 
				res  = 3'd6;
			3'd4 : 
				res  = 3'd7;
			3'd5 :
				res  = 3'd2;
			3'd6 :
				res  = 3'd3;
			3'd7 : 
				res  = 3'd4;
		endcase
	end
endmodule
			
