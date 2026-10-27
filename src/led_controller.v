`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: Innopolis University
// Engineer: Demetrius Ryabov
//
// Create Date: 10/27/2026 10:25:59 AM
// Design Name: LED Controller
// Module Name: led_controller
// Project Name: Fast TTL2NIM Converter
// Target Devices: Red Pitaya STEMlab 125-14 v1.1 (Zynq-7010, xc7z010clg400-1)
// Tool Versions: Vivado 2025.2
//////////////////////////////////////////////////////////////////////////////////


/** Enables displaying binary tick counter on LEDs */
`define LED_CLOCK

module led_controller(
    input clk_locked,
    input clk,
    output [7:0] led_o
);
    assign led_o[7] = clk_locked;

    `ifdef LED_CLOCK
    reg [31:0] cnt = 0;  // tick counter
    always @(posedge clk)
        cnt <= cnt + 1;
    wire [31:0] rev_cnt = {<<{cnt}};
    assign led_o[6:0] = rev_cnt[8:2];

    `else // LED_CLOCK
    assign led_o[6:0] = 7'b0;
    `endif // LED_CLOCK
endmodule
