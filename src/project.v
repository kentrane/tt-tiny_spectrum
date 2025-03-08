/*
 * Copyright (c) 2024 Your Name
 * SPDX-License-Identifier: Apache-2.0
 */


/*
 * Musical Tone Generator for TinyTapeout
 *
 * This design generates musical tones based on input selections.
 * - 4 input pins for note selection (16 possible notes)
 * - 2 input pins for octave selection (4 possible octaves)
 * - 1 input pin for enable/disable
 * - 1 input pin for tremolo effect
 * 
 * Outputs:
 * - Primary audio output on output[0]
 * - Visual note indicators on output[1:7]
 */

`default_nettype none

module tt_um_kentrane_tinymusical (
    input  wire [7:0] ui_in,    // Dedicated inputs
    output wire [7:0] uo_out,   // Dedicated outputs
    input  wire [7:0] uio_in,   // IOs: Input path
    output wire [7:0] uio_out,  // IOs: Output path
    output wire [7:0] uio_oe,   // IOs: Enable path (active high: 0=input, 1=output)
    input  wire       ena,      // always 1 when the design is powered
    input  wire       clk,      // clock
    input  wire       rst_n     // reset_n - low to reset
);
    // Set all bidirectional pins as inputs
    assign uio_oe = 8'b00000000;
    assign uio_out = 8'b00000000;

    // Input assignments
    wire [3:0] note_select = ui_in[3:0];    // 16 possible notes (0-15)
    wire [1:0] octave_select = ui_in[5:4];  // 4 possible octaves
    wire enable = ui_in[6];                 // Enable/disable tone
    wire tremolo_enable = ui_in[7];         // Enable tremolo effect
    
    // Internal registers
    reg [19:0] counter = 0;         // Counter for frequency division
    reg [7:0] tremolo_counter = 0;  // Counter for tremolo effect
    reg tone_out = 0;               // Output tone state
    
    // Frequency divider values for notes (based on C4 = 261.63 Hz)
    // Values calculated for a 10 MHz clock (100 ns period)
    wire [19:0] base_dividers [0:15];
    
    // C, C#, D, D#, E, F, F#, G, G#, A, A#, B and a few more notes
    assign base_dividers[0]  = 20'd19121; // C  (261.63 Hz)
    assign base_dividers[1]  = 20'd18039; // C# (277.18 Hz)
    assign base_dividers[2]  = 20'd17026; // D  (293.66 Hz)
    assign base_dividers[3]  = 20'd16071; // D# (311.13 Hz)
    assign base_dividers[4]  = 20'd15169; // E  (329.63 Hz)
    assign base_dividers[5]  = 20'd14318; // F  (349.23 Hz)
    assign base_dividers[6]  = 20'd13514; // F# (369.99 Hz)
    assign base_dividers[7]  = 20'd12755; // G  (392.00 Hz)
    assign base_dividers[8]  = 20'd12039; // G# (415.30 Hz)
    assign base_dividers[9]  = 20'd11364; // A  (440.00 Hz)
    assign base_dividers[10] = 20'd10726; // A# (466.16 Hz)
    assign base_dividers[11] = 20'd10124; // B  (493.88 Hz)
    assign base_dividers[12] = 20'd9556;  // C5 (523.25 Hz)
    assign base_dividers[13] = 20'd9019;  // C#5 (554.37 Hz)
    assign base_dividers[14] = 20'd8513;  // D5 (587.33 Hz)
    assign base_dividers[15] = 20'd8035;  // D#5 (622.25 Hz)
    
    // Select base frequency divider based on note_select
    wire [19:0] selected_base_divider;
    assign selected_base_divider = base_dividers[note_select];
    
    // Apply octave scaling (divide frequency by 2^octave_select)
    wire [19:0] freq_divider;
    assign freq_divider = (octave_select == 2'b00) ? selected_base_divider :
                         (octave_select == 2'b01) ? selected_base_divider >> 1 :  // Octave higher
                         (octave_select == 2'b10) ? selected_base_divider >> 2 :  // Two octaves higher
                                                  selected_base_divider << 1;   // Octave lower
    
    // Tremolo effect (amplitude modulation)
    wire tremolo_active;
    assign tremolo_active = tremolo_enable ? tremolo_counter[7] : 1'b1;
    
    // Tone generation logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            counter <= 20'd0;
            tremolo_counter <= 8'd0;
            tone_out <= 1'b0;
        end else if (ena && enable) begin
            // Tremolo counter
            tremolo_counter <= tremolo_counter + 1'b1;
            
            // Tone generation counter
            if (counter >= freq_divider - 1) begin
                counter <= 20'd0;
                tone_out <= ~tone_out;  // Toggle output
            end else begin
                counter <= counter + 1'b1;
            end
        end else begin
            // If not enabled, reset output
            tone_out <= 1'b0;
        end
    end
    
    // LED display logic - light up LEDs based on the note playing
    // This creates a visual indication of which note is playing
    reg [6:0] note_display;
    always @* begin
        case (note_select)
            4'd0:  note_display = 7'b0000001;  // C
            4'd1:  note_display = 7'b0000010;  // C#
            4'd2:  note_display = 7'b0000100;  // D
            4'd3:  note_display = 7'b0001000;  // D#
            4'd4:  note_display = 7'b0010000;  // E
            4'd5:  note_display = 7'b0100000;  // F
            4'd6:  note_display = 7'b1000000;  // F#
            4'd7:  note_display = 7'b0000011;  // G
            4'd8:  note_display = 7'b0000110;  // G#
            4'd9:  note_display = 7'b0001100;  // A
            4'd10: note_display = 7'b0011000;  // A#
            4'd11: note_display = 7'b0110000;  // B
            4'd12: note_display = 7'b1100000;  // C5
            4'd13: note_display = 7'b0000111;  // C#5
            4'd14: note_display = 7'b0001110;  // D5
            4'd15: note_display = 7'b0011100;  // D#5
            default: note_display = 7'b0000000;
        endcase
    end
    
    // Output assignments
    assign uo_out[0] = enable ? (tone_out & tremolo_active) : 1'b0;  // Audio output with tremolo
    assign uo_out[7:1] = note_display;  // Visual indicator LEDs
    
endmodule