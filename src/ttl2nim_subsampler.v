`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: Innopolis University
// Engineer: Demetrius Ryabov
//
// Create Date: 10/26/2026 01:18:03 PM
// Design Name: TTL2NIM Subsampler Converter
// Module Name: ttl2nim_subsampler
// Project Name: Fast TTL2NIM Converter
// Target Devices: Red Pitaya STEMlab 125-14 v1.1 (Zynq-7010, xc7z010clg400-1)
// Tool Versions: Vivado 2025.2
// Description:
//   Increase threshold crossing position precision by subsampling the signal.
//////////////////////////////////////////////////////////////////////////////////


`include "levels.vh"

module ttl2nim_subsampler #(
    parameter RECIP_RESOLUTION = 18,
    parameter SUBSAMPLE_RESOLUTION = 8
) (
    input clk,
    input signed [13:0] ttl_i,
    output signed [13:0] nim_o
);
    localparam signed [13:0] NIM_HI   = `LVL_NIM_HI,
                             NIM_LO   = `LVL_NIM_LO,
                             NIM_SPAN = NIM_HI - NIM_LO;
    localparam LATENCY = 5;  // the module delays signal by this many ticks
    localparam FRACTION_BITS = 14;  // how many bits numerator & denominator contains

    // Abbreviations
    localparam RR = RECIP_RESOLUTION;
    localparam SR = SUBSAMPLE_RESOLUTION;
    localparam FB = FRACTION_BITS;

    reg signed [13:0] nim_level = NIM_LO;
    assign nim_o = nim_level;

    // -- PREPROCESSING: precompute reciprocal table
    reg [RR:0] recip_rom [0:(1 << FB) - 1];
    integer i;
    initial begin
        recip_rom[0] = 0;
        for (i = 1; i < (1 << FB); i = i + 1)
            recip_rom[i] = ((1 << RR) + i / 2) / i;  // round to nearest integer
    end

    // -- STAGE 0: update samples, compare them against threshold
    wire signed [13:0] ttl_sample, ttl_thr;
    wire ttl_high, ttl_edge;
    ttl_signal ttl_signal_i (
        .clk(clk), .sample_i(ttl_i),
        .sample_o(ttl_sample), .thr_o(ttl_thr),
        .high_o(ttl_high), .edge_o(ttl_edge)
    );
    reg  signed [13:0] prev_s;  // previous ttl sample
    wire signed [13:0] curr_s = ttl_sample;
    always @(posedge clk)
        prev_s <= curr_s;
    wire [13:0] prev_to_thr = (ttl_thr > prev_s) ? (ttl_thr - prev_s) : (prev_s - ttl_thr);
    wire [13:0] s_delta     = (curr_s > prev_s) ? (curr_s - prev_s) : (prev_s - curr_s);

    // -- STAGE 1: lock comparison results
    reg r1_high, r1_edge;
    reg [FB - 1:0] r1_num, r1_den;  // numerator & denominator for position formula
    always @(posedge clk) begin
        {r1_high, r1_edge} <= {ttl_high, ttl_edge};
        {r1_num, r1_den} <= {prev_to_thr, s_delta};
    end

    // -- STAGE 2: lookup inverse denominator in ROM
    reg r2_high, r2_edge;
    reg [FB - 1:0] r2_num;
    reg [RR:0] r2_recip;
    always @(posedge clk) begin
        {r2_high, r2_edge} <= {r1_high, r1_edge};
        r2_num <= r1_num;
        r2_recip <= recip_rom[r1_den];
    end
    localparam W2_PROD_W = FB + RR + 1;
    localparam W2_PROD_SHIFT = RR - SR;
    wire [W2_PROD_W - 1:0]                 w2_prod   = r2_num * r2_recip;
    wire [W2_PROD_W - W2_PROD_SHIFT - 1:0] w2_subpos = w2_prod >> W2_PROD_SHIFT;
    // threshold position: 0 - at s0, 2^SR - at s1
    wire [SR:0] w2_clip = (w2_subpos > (1 << SR)) ? (1 << SR) : w2_subpos[SR:0]; 

    // -- STAGE 3: find threshold position between samples and compute fraction spent high
    reg [SR:0] r3_high_duty;
    always @(posedge clk) begin
        if      (r2_edge) r3_high_duty <= r2_high ? (1 << SR) - w2_clip : w2_clip;
        else              r3_high_duty <= r2_high ? (1 << SR)           : 0;
    end
    wire signed [SR + 1:0] w3_high_duty_s = {1'b0, r3_high_duty};  // signed to keep expressions signed

    // -- STAGE 4: scale level by NIM signal span
    reg signed [13 + SR:0] r4_edge_part;
    always @(posedge clk) begin
        r4_edge_part <= NIM_SPAN * w3_high_duty_s;
    end

    // -- STAGE 5: offset the signal to NIM_LO
    // ((a + b/2) / b): round to nearest instead of flooring
    // full equation: NIM_LO + ((NIM_SPAN * high_duty + (1 <<< (SR - 1))) >>> SR)
    localparam NIM_LO_OFS = (NIM_LO <<< SR) + (1 <<< (SR - 1));
    always @(posedge clk)
        nim_level <= (r4_edge_part + NIM_LO_OFS) >>> SR;
endmodule
