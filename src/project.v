/*
 * Copyright (c) 2024 Your Name
 * SPDX-License-Identifier: Apache-2.0
 */
// Spectrum Analyzer with PWM Outputs for TinyTapeout
// Top module designed to comply with TinyTapeout requirements

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
    
    // Set all bidirectional pins as inputs initially
    assign uio_oe = 8'b00000000;
    assign uio_out = 8'b00000000;

    // Parameters - REDUCED VALUES to save area
    // Use power of 2 for SAMPLE_RATE_DIV to avoid width expansion warnings
    parameter SAMPLE_RATE_DIV = 32;      // Smaller divider (power of 2 for efficiency)
    parameter PWM_RESOLUTION = 5;        // Reduced from 6 to 5 bits

    // Internal signals
    wire audio_in;                       // Audio input signal
    wire sample_clock;                   // Sampling clock
    wire signed [7:0] audio_sample;      // Audio sample

    // Simplified band energies and PWM outputs
    wire [PWM_RESOLUTION-1:0] band_energy0, band_energy1, band_energy2;
    wire pwm_out0, pwm_out1, pwm_out2;
    
    // Input/output assignments
    assign audio_in = ui_in[0];          // Audio input on first input pin
    
    // Assign PWM outputs individually to output pins
    assign uo_out[0] = pwm_out0;         // Low frequencies
    assign uo_out[1] = pwm_out1;         // Mid frequencies
    assign uo_out[2] = pwm_out2;         // High frequencies
    assign uo_out[7:3] = 5'b00000;       // Unused outputs

    // Sample rate generator - Simplified to use a counter
    // Using fixed bit width that matches SAMPLE_RATE_DIV
    reg [4:0] sample_counter;  // 5 bits for value up to 32
    reg sample_clk_reg;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sample_counter <= 5'b0;
            sample_clk_reg <= 1'b0;
        end else begin
            // Using a constant value to avoid width expansion warning
            if (sample_counter == 5'd31) begin  // SAMPLE_RATE_DIV - 1
                sample_counter <= 5'b0;
                sample_clk_reg <= 1'b1;
            end else begin
                sample_counter <= sample_counter + 5'b1;
                sample_clk_reg <= 1'b0;
            end
        end
    end
    
    assign sample_clock = sample_clk_reg;

    // Audio input sampling - Inline implementation to save area
    reg [6:0] audio_accumulator;
    reg [1:0] audio_sample_counter;  // Reduced from 3 to 2 bits
    reg signed [7:0] audio_sample_reg;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            audio_accumulator <= 7'd0;
            audio_sample_counter <= 2'd0;
            audio_sample_reg <= 8'd0;
        end else if (sample_clock) begin
            // Basic delta-sigma approach
            if (audio_in)
                audio_accumulator <= audio_accumulator + 7'd1;
            
            audio_sample_counter <= audio_sample_counter + 2'd1;
            
            if (audio_sample_counter == 2'd3) begin  // Sample over 4 cycles instead of 8
                audio_sample_reg <= {1'b0, audio_accumulator} - 8'd64;
                audio_accumulator <= 7'd0;
            end
        end
    end
    
    assign audio_sample = audio_sample_reg;

    // Filter bank - Three filters - with reduced bit widths
    // Low band filter (bass)
    reg signed [10:0] filter_state0, filter_output0;  // Reduced from 12 to 11 bits
    reg [PWM_RESOLUTION-1:0] energy_accum0, band_energy_reg0;
    
    // Mid band filter 
    reg signed [10:0] filter_state1, filter_output1;
    reg [PWM_RESOLUTION-1:0] energy_accum1, band_energy_reg1;
    
    // High band filter (treble)
    reg signed [10:0] filter_state2, filter_output2;
    reg [PWM_RESOLUTION-1:0] energy_accum2, band_energy_reg2;
    
    reg [1:0] energy_count;  // Reduced from 3 to 2 bits
    
    // Filter coefficients - Simplified to powers of 2 where possible to save gates
    parameter signed [7:0] COEFF_LOW_A = 8'sd16;     // Low freq ~20-200Hz (power of 2)
    parameter signed [7:0] COEFF_LOW_B = 8'sd8;      // (power of 2)
    
    parameter signed [7:0] COEFF_MID_A = 8'sd16;     // Mid freq ~200-2000Hz (power of 2)
    parameter signed [7:0] COEFF_MID_B = 8'sd24;     // 16 + 8
    
    parameter signed [7:0] COEFF_HIGH_A = 8'sd8;     // High freq ~2000-8000Hz (power of 2)
    parameter signed [7:0] COEFF_HIGH_B = 8'sd32;    // (power of 2)
    
    // Helper wires for absolute values - Simplified calculation
    wire [4:0] abs_output0 = filter_output0[10] ? (~filter_output0[9:5] + 1'b1) : filter_output0[9:5];
    wire [4:0] abs_output1 = filter_output1[10] ? (~filter_output1[9:5] + 1'b1) : filter_output1[9:5];
    wire [4:0] abs_output2 = filter_output2[10] ? (~filter_output2[9:5] + 1'b1) : filter_output2[9:5];
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all registers
            filter_state0 <= 11'd0; filter_output0 <= 11'd0;
            filter_state1 <= 11'd0; filter_output1 <= 11'd0;
            filter_state2 <= 11'd0; filter_output2 <= 11'd0;
            
            energy_accum0 <= {PWM_RESOLUTION{1'b0}};
            energy_accum1 <= {PWM_RESOLUTION{1'b0}};
            energy_accum2 <= {PWM_RESOLUTION{1'b0}};
            
            band_energy_reg0 <= {PWM_RESOLUTION{1'b0}};
            band_energy_reg1 <= {PWM_RESOLUTION{1'b0}};
            band_energy_reg2 <= {PWM_RESOLUTION{1'b0}};
            
            energy_count <= 2'd0;
        end else if (sample_clock) begin
            // Apply different filters to each band
            // Simplify calculations with shifts where possible for powers of 2
            
            // Low band filter
            filter_state0 <= filter_state0 - 
                          (filter_output0 >>> 4) +     // Divide by 16 (COEFF_LOW_A)
                          ({{3{audio_sample[7]}}, audio_sample} >>> 3); // Divide by 8 (COEFF_LOW_B)
            filter_output0 <= filter_state0;
            
            // Mid band filter
            filter_state1 <= filter_state1 - 
                          (filter_output1 >>> 4) +     // Divide by 16 (COEFF_MID_A)
                          (({{3{audio_sample[7]}}, audio_sample} >>> 3) + 
                           ({{3{audio_sample[7]}}, audio_sample} >>> 4)); // Approximates COEFF_MID_B
            filter_output1 <= filter_state1;
            
            // High band filter
            filter_state2 <= filter_state2 - 
                          (filter_output2 >>> 3) +     // Divide by 8 (COEFF_HIGH_A)
                          ({{3{audio_sample[7]}}, audio_sample} >>> 2); // Divide by 4 (COEFF_HIGH_B/8)
            filter_output2 <= filter_state2;
            
            // Calculate energy (absolute value of filter output)
            energy_accum0 <= energy_accum0 + abs_output0;
            energy_accum1 <= energy_accum1 + abs_output1;
            energy_accum2 <= energy_accum2 + abs_output2;
            
            energy_count <= energy_count + 2'd1;
            
            // Update band energy outputs periodically - reduced from 8 to 4 cycles
            if (energy_count == 2'd3) begin
                // Simple decay for visualization
                band_energy_reg0 <= (band_energy_reg0 >> 1) + (energy_accum0 >> 1);
                band_energy_reg1 <= (band_energy_reg1 >> 1) + (energy_accum1 >> 1);
                band_energy_reg2 <= (band_energy_reg2 >> 1) + (energy_accum2 >> 1);
                
                energy_accum0 <= {PWM_RESOLUTION{1'b0}};
                energy_accum1 <= {PWM_RESOLUTION{1'b0}};
                energy_accum2 <= {PWM_RESOLUTION{1'b0}};
                
                energy_count <= 2'd0;
            end
        end
    end
    
    assign band_energy0 = band_energy_reg0;
    assign band_energy1 = band_energy_reg1;
    assign band_energy2 = band_energy_reg2;

    // PWM Generator for all bands - Minimalist shared counter
    reg [PWM_RESOLUTION-1:0] pwm_counter;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pwm_counter <= {PWM_RESOLUTION{1'b0}};
        end else begin
            pwm_counter <= pwm_counter + 1'b1;
        end
    end
    
    // Generate PWM outputs with simple comparators
    assign pwm_out0 = (pwm_counter < band_energy0);
    assign pwm_out1 = (pwm_counter < band_energy1);
    assign pwm_out2 = (pwm_counter < band_energy2);

    // List all unused inputs to prevent warnings
    wire _unused = &{ena, ui_in[7:1], uio_in, 1'b0};

endmodule

`default_nettype wire
