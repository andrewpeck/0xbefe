//--------------------------------------------------------------------------------
// CMS Muon Endcap
// GEM Collaboration
// Optohybrid v3 Firmware -- Device DNA
// A. Peck
//--------------------------------------------------------------------------------
// Description:
//   This module reads the Virtex-6 Device DNA
//--------------------------------------------------------------------------------
// 2018/10/11 -- Initial tested version
//--------------------------------------------------------------------------------

module device_dna #(
parameter  DNA_LENGTH = 'd57
)
(
  input clock,
  input reset,
  output reg [DNA_LENGTH-1:0] dna
);

  wire DOUT, CLK, DIN;
  reg  READ, SHIFT;

  parameter READ_SIZE  = 'd6;

  reg [DNA_LENGTH-1:0] dna_sr   = {DNA_LENGTH{1'b0}};
  reg [READ_SIZE -1:0] read_cnt = {READ_SIZE{1'b0}};

  wire read_done = (read_cnt == DNA_LENGTH+1);
  wire busy      = ~read_done;

  // A Low-to-High transition on SHIFT should be avoided when CLK is High because this
  // causes a spurious initial clock edge. Ideally, SHIFT should only be asserted when CLK is
  // Low or on a falling edge of CLK.

  always @(negedge clock) begin
    if      (reset)     SHIFT <= 1'b0;
    else if (busy)      SHIFT <= 1'b1;
    else if (read_done) SHIFT <= 1'b0;
  end

  always @(posedge clock) begin

    if      (reset)     begin read_cnt <= 0;               READ <= 1'b1; end
    else if (busy)      begin read_cnt <= read_cnt + 1'b1; READ <= 1'b0; end
    else if (read_done) begin read_cnt <= read_cnt;        READ <= 1'b0; end

    if (busy) begin
      dna_sr <= {dna_sr[DNA_LENGTH-2:0], DOUT & ~(reset)};
    end

    if (read_done) dna <= dna_sr[DNA_LENGTH-1:0];
    else           dna <= {DNA_LENGTH{1'b0}};

  end

  assign CLK  = clock;
  assign DIN  = DOUT;

  DNA_PORT #(
    .SIM_DNA_VALUE(57'h123456789abcdef)  // Specifies the ID value for simulation
  )
  DNA_PORT_inst (
    .DOUT      (DOUT), // 1-bit output: DNA output data
    .CLK       (CLK),  // 1-bit input: Clock input
    .DIN       (DIN),  // 1-bit input: User data input pin
    .READ      (READ), // 1-bit input: Active high load DNA, active low read input
    .SHIFT     (SHIFT) // 1-bit input: Active high SHIFT enable input
  );

  // End of DNA_PORT_inst instantiation

endmodule
