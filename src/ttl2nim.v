`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: Innopolis University
// Engineer: Demetrius Ryabov
//
// Create Date: 10/18/2026 11:09:41 AM
// Design Name: Fast TTL2NIM Converter
// Module Name: ttl2nim
// Project Name: Fast TTL2NIM Converter
// Target Devices: Red Pitaya STEMlab 125-14 v1.1 (Zynq-7010, xc7z010clg400-1)
// Tool Versions: Vivado 2025.2
// Description:
//   Converts TTL input pulses to NIM output pulses.
//
//////////////////////////////////////////////////////////////////////////////////

/** Enables displaying binary tick counter on LEDs */
`define LED_CLOCK

module ttl2nim(
    input [1:0] adc_clk_i,
    output [7:0] led_o
);
    // ----- Clock -----
    wire clk_in, clk125;

    IBUFDS ibuf (.I(adc_clk_i[1]), .IB(adc_clk_i[0]), .O(clk_in));
    BUFG bufg (.I(clk_in), .O(clk125));

    reg [31:0] cnt = 0;  // tick counter
    always @(posedge clk125)
        cnt <= cnt + 1;


    // ----- LED -----
    `ifdef LED_CLOCK
    wire [31:0] rev_cnt = {<<{cnt}};
    assign led_o = {rev_cnt[9:2]};
    `endif // LED_CLOCK
endmodule
