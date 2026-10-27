`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: Innopolis University
// Engineer: Demetrius Ryabov
//
// Create Date: 10/27/2026 09:53:32 AM
// Design Name: TTL2NIM Simple Converter
// Module Name: ttl2nim_simple
// Project Name: Fast TTL2NIM Converter
// Target Devices: Red Pitaya STEMlab 125-14 v1.1 (Zynq-7010, xc7z010clg400-1)
// Tool Versions: Vivado 2025.2
// Description:
//   Convert TTL to NIM simply by comparing with threshold.
//////////////////////////////////////////////////////////////////////////////////


`include "levels.vh"

module ttl2nim_simple(
    input clk,
    input signed [13:0] ttl_i,
    output signed [13:0] nim_o
);
    localparam signed [13:0] NIM_HI = `LVL_NIM_HI,
                             NIM_LO = `LVL_NIM_LO;

    wire ttl_high;
    ttl_signal (.clk(clk), .sample_i(ttl_i), .high_o(ttl_high));
    assign nim_o = ttl_high ? NIM_HI : NIM_LO;
endmodule
