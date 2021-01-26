//--------------------------------------------------------------------------------
// CMS Muon Endcap
// GEM Collaboration
// Optohybrid v3 Firmware -- TTC
// A. Peck
//--------------------------------------------------------------------------------

module ttc #(
  parameter HOLD_UNTIL_BX0 = 0,
  parameter MXBXN          = 12 // Number BXN bits, LHC bunchs numbered 0 to 3563
) (

  input clock,

  input reset,

  input  ttc_bx0,
  output reg bx0_local,

  input ttc_resync,

  input  [MXBXN-1:0] bxn_offset, // BXN offset at reset

  output reg [MXBXN-1:0] bxn_counter,

  output     bx0_sync_err, // sync error on bx0
  output reg bxn_sync_err  // bunch counter sync error

);

  localparam [11:0] LHC_CYCLE      = 12'd3564; // LHC period, max BXN count+1
  localparam        MXCNT          = 32;       // Maximum counter length

  // Bunch Crossing Counter, counts 0 to 3563, presets at resync or bxreset, stops counting, resumes at bx0

  //--------------------------------------------------------------------------------------------------------------------
  // Restrict bxn offsets to be in the interval 0 < LHC_CYCLE to prevent non-physical bxns
  //--------------------------------------------------------------------------------------------------------------------

  reg [MXBXN-1:0] bxn_offset_lim     = 0;

  always @(posedge clock) begin
    bxn_offset_lim <= (bxn_offset >= LHC_CYCLE) ? (LHC_CYCLE-1'b1) : (bxn_offset);
  end

  //--------------------------------------------------------------------------------------------------------------------
  // hold the bunch crossing counter until the first bx0 is received
  //--------------------------------------------------------------------------------------------------------------------
  reg bxn_hold = 1'b1;
  always @(posedge clock) begin
    if      ( reset   ) bxn_hold <= 1; // Count hold FF
    else if ( ttc_bx0 ) bxn_hold <= 0;
  end

  //--------------------------------------------------------------------------------------------------------------------
  // bxn counter should restore to its preset value if it is being held or a resync is received
  //--------------------------------------------------------------------------------------------------------------------

  // user should send a resync, followed by a bc0 to initiate syncrhonziation

  wire bxn_preset = ((HOLD_UNTIL_BX0 && bxn_hold) || ttc_resync) && !ttc_bx0;   // Load bxn offset value

  //--------------------------------------------------------------------------------------------------------------------
  // Max value overflow
  //--------------------------------------------------------------------------------------------------------------------

  wire bxn_ovf = bxn_counter == LHC_CYCLE[11:0]-1;      // BXN maximum count for pretrig bxn counter

  //--------------------------------------------------------------------------------------------------------------------
  // BXN Counter
  //--------------------------------------------------------------------------------------------------------------------

  initial bxn_counter  = 0;

  always @(posedge clock) begin
    if      (bxn_preset) bxn_counter  <= bxn_offset_lim;  // Counter
    else if (bxn_ovf   ) bxn_counter  <= 0;
    else                 bxn_counter  <= bxn_counter+1'b1;
  end

  //--------------------------------------------------------------------------------------------------------------------
  // Synchronization
  //--------------------------------------------------------------------------------------------------------------------

  initial bxn_sync_err = 0;

  wire bxn_sync = bxn_counter == bxn_offset_lim; // BXN now at offset value (i.e. local bx0)

  always @(posedge clock) begin
    bx0_local <= bxn_counter == 0; // This TMBs bxn is at 0
  end

  always @(posedge clock) begin
    if      (bxn_preset)  bxn_sync_err <= 0; // Sync err latch if count isnt at offset on ttc_bx0
    else if (ttc_bx0   )  bxn_sync_err <= !bxn_sync || bxn_sync_err;
    else if (bxn_sync  )  bxn_sync_err <= !ttc_bx0  || bxn_sync_err;
  end

  assign bx0_sync_err = bxn_sync_err || bxn_preset; // single clock strobe of sync error at bx0

endmodule
