`default_nettype none
`timescale 1ns / 1ps

/* This testbench instantiates the musical tone generator module 
   and makes convenient wires that can be driven/tested by the cocotb test.py.
*/
module tb ();
  // Dump the signals to a VCD file. You can view it with gtkwave or surfer.
  initial begin
    $dumpfile("tb.vcd");
    $dumpvars(0, tb);
    #1;
  end

  // Wire up the inputs and outputs:
  reg clk;
  reg rst_n;
  reg ena;
  reg [7:0] ui_in;
  reg [7:0] uio_in;
  wire [7:0] uo_out;
  wire [7:0] uio_out;
  wire [7:0] uio_oe;

`ifdef GL_TEST
  wire VPWR = 1'b1;
  wire VGND = 1'b0;
`endif

  // Instantiate the musical tone generator module:
  tt_um_kentrane_tinyspectrum user_project (
      // Include power ports for the Gate Level test:
`ifdef GL_TEST
      .VPWR(VPWR),
      .VGND(VGND),
`endif
      .ui_in  (ui_in),    // Dedicated inputs: note select, octave select, enable, tremolo
      .uo_out (uo_out),   // Dedicated outputs: audio out, note LEDs
      .uio_in (uio_in),   // IOs: Input path (not used in this design)
      .uio_out(uio_out),  // IOs: Output path (not used in this design)
      .uio_oe (uio_oe),   // IOs: Enable path (not used in this design)
      .ena    (ena),      // enable - goes high when design is selected
      .clk    (clk),      // clock
      .rst_n  (rst_n)     // not reset
  );

endmodule