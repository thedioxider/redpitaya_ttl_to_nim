`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: Innopolis University
// Engineer: Demetrius Ryabov
//
// Create Date: 10/26/2026 01:05:19 PM
// Design Name: Coarse Delay
// Module Name: delay_ticks
// Project Name: Fast TTL2NIM Converter
// Target Devices: Red Pitaya STEMlab 125-14 v1.1 (Zynq-7010, xc7z010clg400-1)
// Tool Versions: Vivado 2025.2
// Description:
//   Delay output NIM signal by coarse tick steps via ring buffer.
//////////////////////////////////////////////////////////////////////////////////


`include "levels.vh"

module delay_ticks #(
    parameter ADDR_W = 10,
    parameter signed [13:0] DEFAULT_VALUE = `LVL_NIM_LO
) (
    input clk,
    input [ADDR_W - 1:0] n_ticks,
    input signed [13:0] i,
    output signed [13:0] o
);
    (* ram_style = "block" *)
    reg signed [13:0] delay_buffer [(1 << ADDR_W) - 1:0];
    integer k;
    initial for (k = 0; k < (1 << ADDR_W); k = k + 1)
        delay_buffer[k] = DEFAULT_VALUE;

    reg [ADDR_W - 1:0] wrt_p = 0;
    reg signed [13:0] out_r = DEFAULT_VALUE;
    assign o = out_r;

    always @(posedge clk) begin
        delay_buffer[wrt_p] <= i;
        wrt_p <= wrt_p + 1;
        out_r <= delay_buffer[wrt_p - n_ticks - 1];
    end
endmodule
