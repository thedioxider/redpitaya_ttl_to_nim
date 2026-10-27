`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: Innopolis University
// Engineer: Demetrius Ryabov
//
// Create Date: 10/26/2026 01:46:36 PM
// Design Name: TTL Signal Processor
// Module Name: ttl_signal
// Project Name: Fast TTL2NIM Converter
// Target Devices: Red Pitaya STEMlab 125-14 v1.1 (Zynq-7010, xc7z010clg400-1)
// Tool Versions: Vivado 2025.2
// Description:
//   Detects TTL signal edges with hysteresis.
//////////////////////////////////////////////////////////////////////////////////


module ttl_signal #(
    parameter signed [13:0] THR_HI = 14'sd655,  // ~ 1.6V HV ADC
                            THR_LO = 14'sd575   // ~ 1.4V HV ADC
) (
    input clk,
    input signed [13:0] sample_i,
    // aligned bundle: all outputs describe sample_o
    output signed [13:0] sample_o,
    output signed [13:0] thr_o,  // threshold sample was compared against
    output high_o,  // logic level for this sample
    output edge_o   // threshold crossed between previous and this sample
);
    reg state = 0;  // remembered logic state from last sample

    assign thr_o    = state ? THR_LO : THR_HI;
    assign edge_o   = state ? (sample_i < thr_o) : (sample_i > thr_o);
    assign high_o   = state ^ edge_o;
    assign sample_o = sample_i;

    always @(posedge clk)
        state <= high_o;
endmodule
