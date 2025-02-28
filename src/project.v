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
    input  wire       ena,      // always 1 when the design is powered, so you can ignore it
    input  wire       clk,      // clock
    input  wire       rst_n     // reset_n - low to reset
    );
    
    // All output pins must be assigned. If not used, assign to 0.
    assign uo_out  = ui_in + uio_in;  // Example: ou_out is the sum of ui_in and uio_in
    assign uio_out = 0;
    assign uio_oe  = 0;
    
    // List all unused inputs to prevent warnings
    wire _unused = &{ena, clk, rst_n, 1'b0};
    // Set all bidirectional pins as inputs initially
    assign uio_oe = 8'b00000000;
    assign uio_out = 8'b00000000;

    // Parameters for the spectrum analyzer
    parameter SAMPLE_RATE_DIV = 100;      // Divide clock to get sample rate
    parameter NUM_BANDS = 4;              // Number of frequency bands
    parameter PWM_RESOLUTION = 8;         // Resolution of PWM outputs

    // Internal signals
    wire audio_in;               // Audio input signal
    wire sample_clock;           // Sampling clock
    wire signed [7:0] audio_sample;      // Audio sample
    wire [PWM_RESOLUTION-1:0] band_energy [NUM_BANDS-1:0];  // Energy in each band
    wire [NUM_BANDS-1:0] pwm_out;         // PWM outputs
    
    // Input/output assignments
    assign audio_in = ui_in[0];                   // Audio input on first input pin
    assign uo_out[NUM_BANDS-1:0] = pwm_out;       // PWM outputs
    assign uo_out[7:NUM_BANDS] = {(8-NUM_BANDS){1'b0}}; // Unused outputs

    // Sample rate generation
    sample_rate_divider #(
        .DIV(SAMPLE_RATE_DIV)
    ) sample_divider (
        .clk(clk),
        .rst_n(rst_n),
        .sample_clock(sample_clock)
    );

    // Audio input sampling
    audio_sampler sampler (
        .clk(clk),
        .rst_n(rst_n),
        .sample_clock(sample_clock),
        .audio_in(audio_in),
        .audio_sample(audio_sample)
    );

    // Filter bank for frequency analysis
    filter_bank #(
        .NUM_BANDS(NUM_BANDS),
        .ENERGY_BITS(PWM_RESOLUTION)
    ) filters (
        .clk(clk),
        .rst_n(rst_n),
        .sample_clock(sample_clock),
        .audio_sample(audio_sample),
        .band_energy(band_energy)
    );

    // PWM generators for each band
    genvar i;
    generate
        for (i = 0; i < NUM_BANDS; i = i + 1) begin : pwm_gen
            pwm_generator #(
                .RESOLUTION(PWM_RESOLUTION)
            ) pwm (
                .clk(clk),
                .rst_n(rst_n),
                .duty_cycle(band_energy[i]),
                .pwm_out(pwm_out[i])
            );
        end
    endgenerate

endmodule

// Sample Rate Divider
module sample_rate_divider #(
    parameter DIV = 100  // Divider ratio
)(
    input wire clk,
    input wire rst_n,
    output reg sample_clock
);
    reg [$clog2(DIV)-1:0] counter;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            counter <= 0;
            sample_clock <= 0;
        end else begin
            if (counter == DIV - 1) begin
                counter <= 0;
                sample_clock <= 1;
            end else begin
                counter <= counter + 1;
                sample_clock <= 0;
            end
        end
    end
endmodule

// Audio Sampler
module audio_sampler (
    input wire clk,
    input wire rst_n,
    input wire sample_clock,
    input wire audio_in,
    output reg signed [7:0] audio_sample
);
    // Simple PDM to PCM conversion    
    reg [7:0] accumulator;
    reg [3:0] sample_counter;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            accumulator <= 8'd0;
            sample_counter <= 4'd0;
            audio_sample <= 8'd0;
        end else if (sample_clock) begin
            // Basic sigma-delta approach
            if (audio_in) 
                accumulator <= accumulator + 1;
            
            sample_counter <= sample_counter + 1;
            
            if (sample_counter == 4'd15) begin
                audio_sample <= {1'b0, accumulator[7:1]} - 8'd64; // Convert to signed
                accumulator <= 8'd0;
            end
        end
    end
endmodule

// Filter Bank
module filter_bank #(
    parameter NUM_BANDS = 4,
    parameter ENERGY_BITS = 8
)(
    input wire clk,
    input wire rst_n,
    input wire sample_clock,
    input wire signed [7:0] audio_sample,
    output reg [ENERGY_BITS-1:0] band_energy0,
    output reg [ENERGY_BITS-1:0] band_energy1,
    output reg [ENERGY_BITS-1:0] band_energy2,
    output reg [ENERGY_BITS-1:0] band_energy3
);
    // Filter coefficients for different bands
    // simplified IIR filter coefficients
    parameter signed [7:0] COEFF_LOW_A = 8'sd20;    // ~20-200Hz
    parameter signed [7:0] COEFF_LOW_B = 8'sd10;
    
    parameter signed [7:0] COEFF_MID_LOW_A = 8'sd15; // ~200-800Hz
    parameter signed [7:0] COEFF_MID_LOW_B = 8'sd25;
    
    parameter signed [7:0] COEFF_MID_HIGH_A = 8'sd10; // ~800-2500Hz
    parameter signed [7:0] COEFF_MID_HIGH_B = 8'sd30;
    
    parameter signed [7:0] COEFF_HIGH_A = 8'sd5;    // ~2500-8000Hz
    parameter signed [7:0] COEFF_HIGH_B = 8'sd40;
    
    // Individual filter states and outputs for each band
    reg signed [15:0] filter_state0, filter_state1, filter_state2, filter_state3;
    reg signed [15:0] filter_output0, filter_output1, filter_output2, filter_output3;
    
    // Individual energy accumulators for each band
    reg [ENERGY_BITS-1:0] energy_accum0, energy_accum1, energy_accum2, energy_accum3;
    reg [3:0] energy_count;
    
    // Helper wires for absolute values
    wire [7:0] abs_output0 = filter_output0[15] ? ~filter_output0[15:8] + 1'b1 : filter_output0[15:8];
    wire [7:0] abs_output1 = filter_output1[15] ? ~filter_output1[15:8] + 1'b1 : filter_output1[15:8];
    wire [7:0] abs_output2 = filter_output2[15] ? ~filter_output2[15:8] + 1'b1 : filter_output2[15:8];
    wire [7:0] abs_output3 = filter_output3[15] ? ~filter_output3[15:8] + 1'b1 : filter_output3[15:8];
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all states and accumulators
            filter_state0 <= 16'd0;
            filter_state1 <= 16'd0;
            filter_state2 <= 16'd0;
            filter_state3 <= 16'd0;
            
            filter_output0 <= 16'd0;
            filter_output1 <= 16'd0;
            filter_output2 <= 16'd0;
            filter_output3 <= 16'd0;
            
            energy_accum0 <= {ENERGY_BITS{1'b0}};
            energy_accum1 <= {ENERGY_BITS{1'b0}};
            energy_accum2 <= {ENERGY_BITS{1'b0}};
            energy_accum3 <= {ENERGY_BITS{1'b0}};
            
            band_energy0 <= {ENERGY_BITS{1'b0}};
            band_energy1 <= {ENERGY_BITS{1'b0}};
            band_energy2 <= {ENERGY_BITS{1'b0}};
            band_energy3 <= {ENERGY_BITS{1'b0}};
            
            energy_count <= 4'd0;
        end else if (sample_clock) begin
            // Apply different filters to each band
            
            // Low band filter
            filter_state0 <= filter_state0 - 
                           ((COEFF_LOW_A * filter_output0) >>> 8) + 
                           ((COEFF_LOW_B * {{8{audio_sample[7]}}, audio_sample}) >>> 8);
            filter_output0 <= filter_state0;
            
            // Mid-low band filter
            filter_state1 <= filter_state1 - 
                           ((COEFF_MID_LOW_A * filter_output1) >>> 8) + 
                           ((COEFF_MID_LOW_B * {{8{audio_sample[7]}}, audio_sample}) >>> 8);
            filter_output1 <= filter_state1;
            
            // Mid-high band filter
            filter_state2 <= filter_state2 - 
                           ((COEFF_MID_HIGH_A * filter_output2) >>> 8) + 
                           ((COEFF_MID_HIGH_B * {{8{audio_sample[7]}}, audio_sample}) >>> 8);
            filter_output2 <= filter_state2;
            
            // High band filter
            filter_state3 <= filter_state3 - 
                           ((COEFF_HIGH_A * filter_output3) >>> 8) + 
                           ((COEFF_HIGH_B * {{8{audio_sample[7]}}, audio_sample}) >>> 8);
            filter_output3 <= filter_state3;
            
            // Calculate energy (absolute value of filter output)
            energy_accum0 <= energy_accum0 + abs_output0;
            energy_accum1 <= energy_accum1 + abs_output1;
            energy_accum2 <= energy_accum2 + abs_output2;
            energy_accum3 <= energy_accum3 + abs_output3;
            
            energy_count <= energy_count + 1;
            
            // Update band energy outputs periodically
            if (energy_count == 4'd15) begin
                // Apply some decay to the previous value for smoother visualization
                band_energy0 <= (band_energy0 >> 1) + (energy_accum0 >> 1);
                band_energy1 <= (band_energy1 >> 1) + (energy_accum1 >> 1);
                band_energy2 <= (band_energy2 >> 1) + (energy_accum2 >> 1);
                band_energy3 <= (band_energy3 >> 1) + (energy_accum3 >> 1);
                
                energy_accum0 <= {ENERGY_BITS{1'b0}};
                energy_accum1 <= {ENERGY_BITS{1'b0}};
                energy_accum2 <= {ENERGY_BITS{1'b0}};
                energy_accum3 <= {ENERGY_BITS{1'b0}};
                
                energy_count <= 4'd0;
            end
        end
    end
endmodule

// PWM Generator
module pwm_generator #(
    parameter RESOLUTION = 8
)(
    input wire clk,
    input wire rst_n,
    input wire [RESOLUTION-1:0] duty_cycle,
    output reg pwm_out
);
    reg [RESOLUTION-1:0] counter;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            counter <= {RESOLUTION{1'b0}};
            pwm_out <= 1'b0;
        end else begin
            counter <= counter + 1'b1;
            pwm_out <= (counter < duty_cycle);
        end
    end
endmodule
