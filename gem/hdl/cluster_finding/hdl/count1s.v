//------------------------------------------------------------------------------------------------------------------------
//  prodcedural function to sum number of layers hit into a binary value - rom version
//  returns   count1s = (inp[5]+inp[4]+inp[3])+(inp[2]+inp[1]+inp[0]);
//------------------------------------------------------------------------------------------------------------------------

  function  [2:0] count1s;
  input     [5:0] inp;
  reg       [2:0] rom;

  begin
  case(inp[5:0])
  6'b000000: rom = 0;
  6'b000001: rom = 1;
  6'b000010: rom = 1;
  6'b000011: rom = 2;
  6'b000100: rom = 1;
  6'b000101: rom = 2;
  6'b000110: rom = 2;
  6'b000111: rom = 3;
  6'b001000: rom = 1;
  6'b001001: rom = 2;
  6'b001010: rom = 2;
  6'b001011: rom = 3;
  6'b001100: rom = 2;
  6'b001101: rom = 3;
  6'b001110: rom = 3;
  6'b001111: rom = 4;
  6'b010000: rom = 1;
  6'b010001: rom = 2;
  6'b010010: rom = 2;
  6'b010011: rom = 3;
  6'b010100: rom = 2;
  6'b010101: rom = 3;
  6'b010110: rom = 3;
  6'b010111: rom = 4;
  6'b011000: rom = 2;
  6'b011001: rom = 3;
  6'b011010: rom = 3;
  6'b011011: rom = 4;
  6'b011100: rom = 3;
  6'b011101: rom = 4;
  6'b011110: rom = 4;
  6'b011111: rom = 5;
  6'b100000: rom = 1;
  6'b100001: rom = 2;
  6'b100010: rom = 2;
  6'b100011: rom = 3;
  6'b100100: rom = 2;
  6'b100101: rom = 3;
  6'b100110: rom = 3;
  6'b100111: rom = 4;
  6'b101000: rom = 2;
  6'b101001: rom = 3;
  6'b101010: rom = 3;
  6'b101011: rom = 4;
  6'b101100: rom = 3;
  6'b101101: rom = 4;
  6'b101110: rom = 4;
  6'b101111: rom = 5;
  6'b110000: rom = 2;
  6'b110001: rom = 3;
  6'b110010: rom = 3;
  6'b110011: rom = 4;
  6'b110100: rom = 3;
  6'b110101: rom = 4;
  6'b110110: rom = 4;
  6'b110111: rom = 5;
  6'b111000: rom = 3;
  6'b111001: rom = 4;
  6'b111010: rom = 4;
  6'b111011: rom = 5;
  6'b111100: rom = 4;
  6'b111101: rom = 5;
  6'b111110: rom = 5;
  6'b111111: rom = 6;
  endcase

  count1s = rom;

  end
  endfunction
