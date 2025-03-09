/*
 * Copyright (c) 2024 Kenneth Petersen
 * SPDX-License-Identifier: Apache-2.0
 */


/*
 * Musical Tone Generator for TinyTapeout
 *
 * This chip turns digital inputs into sweet, sweet music!
 *
 * Controls:
 * - Note selector [3:0] - 16 notes from C to D# (your musical palette)
 * - Octave jumper [5:4] - 4 octaves (from deep bass to chirpy highs)
 * - Sound ON/OFF  [6]   - Silence is golden... sometimes
 * - Tremolo       [7]   - For that classic wobble effect
 * 
 * Outputs:
 * - Main audio on pin 7 - Connect to speaker and rock out!
 * - Visual light show on pins [0:6] - 7-segment display shows which note is playing
 */

`default_nettype none

module tt_um_kentrane_tinyspectrum (
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

    // Decoding the musical intentions of the user
    wire [3:0] note_select = ui_in[3:0];    // Pick your note (16 options)
    wire [1:0] octave_select = ui_in[5:4];  // Choose your octave (4 options)
    wire enable = ui_in[6];                 // The master switch
    wire tremolo_enable = ui_in[7];         // Add that classic vibrato effect
    
    // Internal registers
    reg [19:0] counter = 0;         // Frequency timer (the metronome)
    reg [7:0] tremolo_counter = 0;  // Creates that wavering tremolo effect
    reg tone_out = 0;               // The actual sound wave (square wave)
    
    // Musical note frequency dividers - translated for our 10 MHz clock
    // Each value represents "how many clock ticks before toggling the output"
    wire [19:0] base_dividers [0:15];
    
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
    
    wire [19:0] selected_base_divider;
    assign selected_base_divider = base_dividers[note_select];
    // We shift bits right to double the frequency (octave up)
    wire [19:0] freq_divider;
    assign freq_divider =   (octave_select == 2'b00) ? selected_base_divider :
                            (octave_select == 2'b01) ? selected_base_divider >> 1 : // One giant leap up
                            (octave_select == 2'b10) ? selected_base_divider >> 2 : // Reaching the high notes
                            (octave_select == 2'b11) ? selected_base_divider >> 3 : // Soprano territory
                            selected_base_divider;                                  // Safety net
    // Tremolo - that wavering effect in old sci-fi movies
    wire tremolo_active;
    assign tremolo_active = tremolo_enable ? tremolo_counter[7] : 1'b1;
    
    // The sound generation engine - the heart of the chip
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            counter <= 20'd0; // Reset the metronome
            tremolo_counter <= 8'd0; // Reset the tremolo
            tone_out <= 1'b0; //  Reset the sound
        end else if (ena && enable) begin
            // Tremolo effect counter (creates amplitude waves)
            tremolo_counter <= tremolo_counter + 1'b1; // Count up by one
            
            // Sound wave generation - toggles output when counter hits target
            if (counter >= freq_divider - 1) begin 
                counter <= 20'd0;       // Reset the metronome
                tone_out <= ~tone_out;  // Flip the bit, make the sound
            end else begin
                counter <= counter + 1'b1;  // Keep counting
            end
        end else begin
            tone_out <= 1'b0; // be quiet
        end
    end
    
    // Display which note is playing on the 7-segment
    reg [6:0] segment_pattern;
    always @* begin
        case (note_select)
            4'd0:  segment_pattern = 7'b0111111; // 0
            4'd1:  segment_pattern = 7'b0000110; // 1
            4'd2:  segment_pattern = 7'b1011011; // 2
            4'd3:  segment_pattern = 7'b1001111; // 3
            4'd4:  segment_pattern = 7'b1100110; // 4
            4'd5:  segment_pattern = 7'b1101101; // 5
            4'd6:  segment_pattern = 7'b1111101; // 6
            4'd7:  segment_pattern = 7'b0000111; // 7
            4'd8:  segment_pattern = 7'b1111111; // 8
            4'd9:  segment_pattern = 7'b1101111; // 9
            4'd10: segment_pattern = 7'b1110111; // A
            4'd11: segment_pattern = 7'b1111100; // b
            4'd12: segment_pattern = 7'b0111001; // C
            4'd13: segment_pattern = 7'b1011110; // d
            4'd14: segment_pattern = 7'b1111001; // E
            4'd15: segment_pattern = 7'b1110001; // F
            default: segment_pattern = 7'b0000000; // All segments off
        endcase
    end
    
    // Connecting everything up
    assign uo_out[7] = enable ? (tone_out & tremolo_active) : 1'b0;  // The main audio signal
    // Visual lightshow on the 7-segment
    assign uo_out[6:0] = enable ? segment_pattern : 7'b0000000;
    
endmodule