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
  tt_um_musical_tone_generator user_project (
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

  // Clock generation (10 MHz)
  initial begin
    clk = 0;
    forever #50 clk = ~clk; // 100ns period (10 MHz)
  end
  
  // Test sequence - this can be overridden by cocotb
  initial begin
    rst_n = 0;
    ena = 0;
    ui_in = 8'h00;
    uio_in = 8'h00;
    
    // Release reset and enable the design
    #100;
    rst_n = 1;
    ena = 1;
    
    // Test note C in base octave
    #100;
    ui_in = 8'h40; // Note 0 (C), octave 0, enable=1, tremolo=0
    
    // Run for a while to see multiple cycles of the note
    #100000;
    
    // Test note A in base octave
    ui_in = 8'h49; // Note 9 (A), octave 0, enable=1, tremolo=0
    
    #100000;
    
    // Test note C with tremolo
    ui_in = 8'hC0; // Note 0 (C), octave 0, enable=1, tremolo=1
    
    #100000;
    
    // Test note E in higher octave
    ui_in = 8'h54; // Note 4 (E), octave 1, enable=1, tremolo=0
    
    #100000;
    
    // Disable output
    ui_in = 8'h00; // Output disabled
    
    #10000;
    
    $finish;
  end

endmodule