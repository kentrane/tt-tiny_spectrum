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
    parameter SAMPLE_RATE_DIV = 64;      // Smaller divider (power of 2 for efficiency)
    parameter NUM_BANDS = 3;             // Reduced from 4 to 3 bands
    parameter PWM_RESOLUTION = 6;        // Reduced from 8 to 6 bits

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
    reg [$clog2(SAMPLE_RATE_DIV)-1:0] sample_counter;
    reg sample_clk_reg;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sample_counter <= 0;
            sample_clk_reg <= 0;
        end else begin
            if (sample_counter == SAMPLE_RATE_DIV - 1) begin
                sample_counter <= 0;
                sample_clk_reg <= 1;
            end else begin
                sample_counter <= sample_counter + 1;
                sample_clk_reg <= 0;
            end
        end
    end
    
    assign sample_clock = sample_clk_reg;

    // Audio input sampling - Inline implementation to save area
    reg [6:0] audio_accumulator;
    reg [2:0] audio_sample_counter;
    reg signed [7:0] audio_sample_reg;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            audio_accumulator <= 7'd0;
            audio_sample_counter <= 3'd0;
            audio_sample_reg <= 8'd0;
        end else if (sample_clock) begin
            // Basic delta-sigma approach
            if (audio_in)
                audio_accumulator <= audio_accumulator + 1;
            
            audio_sample_counter <= audio_sample_counter + 1;
            
            if (audio_sample_counter == 3'd7) begin
                audio_sample_reg <= {1'b0, audio_accumulator} - 8'd64;
                audio_accumulator <= 7'd0;
            end
        end
    end
    
    assign audio_sample = audio_sample_reg;

    // Filter bank - Three filters instead of four
    // Low band filter (bass)
    reg signed [11:0] filter_state0, filter_output0; // Reduced bit width
    reg [PWM_RESOLUTION-1:0] energy_accum0, band_energy_reg0;
    
    // Mid band filter 
    reg signed [11:0] filter_state1, filter_output1;
    reg [PWM_RESOLUTION-1:0] energy_accum1, band_energy_reg1;
    
    // High band filter (treble)
    reg signed [11:0] filter_state2, filter_output2;
    reg [PWM_RESOLUTION-1:0] energy_accum2, band_energy_reg2;
    
    reg [2:0] energy_count;
    
    // Filter coefficients - Simplified to save area
    parameter signed [7:0] COEFF_LOW_A = 8'sd24;     // Low freq ~20-200Hz
    parameter signed [7:0] COEFF_LOW_B = 8'sd8;
    
    parameter signed [7:0] COEFF_MID_A = 8'sd16;     // Mid freq ~200-2000Hz
    parameter signed [7:0] COEFF_MID_B = 8'sd24;
    
    parameter signed [7:0] COEFF_HIGH_A = 8'sd8;     // High freq ~2000-8000Hz
    parameter signed [7:0] COEFF_HIGH_B = 8'sd32;
    
    // Helper wires for absolute values - Simplified calculation
    wire [5:0] abs_output0 = filter_output0[11] ? (~filter_output0[10:5] + 1'b1) : filter_output0[10:5];
    wire [5:0] abs_output1 = filter_output1[11] ? (~filter_output1[10:5] + 1'b1) : filter_output1[10:5];
    wire [5:0] abs_output2 = filter_output2[11] ? (~filter_output2[10:5] + 1'b1) : filter_output2[10:5];
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all registers
            filter_state0 <= 12'd0; filter_output0 <= 12'd0;
            filter_state1 <= 12'd0; filter_output1 <= 12'd0;
            filter_state2 <= 12'd0; filter_output2 <= 12'd0;
            
            energy_accum0 <= {PWM_RESOLUTION{1'b0}};
            energy_accum1 <= {PWM_RESOLUTION{1'b0}};
            energy_accum2 <= {PWM_RESOLUTION{1'b0}};
            
            band_energy_reg0 <= {PWM_RESOLUTION{1'b0}};
            band_energy_reg1 <= {PWM_RESOLUTION{1'b0}};
            band_energy_reg2 <= {PWM_RESOLUTION{1'b0}};
            
            energy_count <= 3'd0;
        end else if (sample_clock) begin
            // Apply different filters to each band
            // Low band filter
            filter_state0 <= filter_state0 - 
                          ((COEFF_LOW_A * filter_output0) >>> 8) + 
                          ((COEFF_LOW_B * {{4{audio_sample[7]}}, audio_sample}) >>> 8);
            filter_output0 <= filter_state0;
            
            // Mid band filter
            filter_state1 <= filter_state1 - 
                          ((COEFF_MID_A * filter_output1) >>> 8) + 
                          ((COEFF_MID_B * {{4{audio_sample[7]}}, audio_sample}) >>> 8);
            filter_output1 <= filter_state1;
            
            // High band filter
            filter_state2 <= filter_state2 - 
                          ((COEFF_HIGH_A * filter_output2) >>> 8) + 
                          ((COEFF_HIGH_B * {{4{audio_sample[7]}}, audio_sample}) >>> 8);
            filter_output2 <= filter_state2;
            
            // Calculate energy (absolute value of filter output)
            energy_accum0 <= energy_accum0 + abs_output0;
            energy_accum1 <= energy_accum1 + abs_output1;
            energy_accum2 <= energy_accum2 + abs_output2;
            
            energy_count <= energy_count + 1;
            
            // Update band energy outputs periodically - reduced sampling
            if (energy_count == 3'd7) begin
                // Apply some decay to the previous value for smoother visualization
                band_energy_reg0 <= (band_energy_reg0 >> 1) + (energy_accum0 >> 1);
                band_energy_reg1 <= (band_energy_reg1 >> 1) + (energy_accum1 >> 1);
                band_energy_reg2 <= (band_energy_reg2 >> 1) + (energy_accum2 >> 1);
                
                energy_accum0 <= {PWM_RESOLUTION{1'b0}};
                energy_accum1 <= {PWM_RESOLUTION{1'b0}};
                energy_accum2 <= {PWM_RESOLUTION{1'b0}};
                
                energy_count <= 3'd0;
            end
        end
    end
    
    assign band_energy0 = band_energy_reg0;
    assign band_energy1 = band_energy_reg1;
    assign band_energy2 = band_energy_reg2;

    // PWM Generator for each band - Simplified implementation
    reg [PWM_RESOLUTION-1:0] pwm_counter;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pwm_counter <= {PWM_RESOLUTION{1'b0}};
        end else begin
            pwm_counter <= pwm_counter + 1'b1;
        end
    end
    
    // Generate PWM outputs by comparing counter with duty cycle
    assign pwm_out0 = (pwm_counter < band_energy0);
    assign pwm_out1 = (pwm_counter < band_energy1);
    assign pwm_out2 = (pwm_counter < band_energy2);

    // List all unused inputs to prevent warnings
    wire _unused = &{ena, ui_in[7:1], uio_in, 1'b0};

endmodule

`default_nettype wire
