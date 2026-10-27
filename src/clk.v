`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: Innopolis University
// Engineer: Demetrius Ryabov
//
// Create Date: 10/27/2026 09:23:19 AM
// Design Name: CLK Manager
// Module Name: clk
// Project Name: Fast TTL2NIM Converter
// Target Devices: Red Pitaya STEMlab 125-14 v1.1 (Zynq-7010, xc7z010clg400-1)
// Tool Versions: Vivado 2025.2
//////////////////////////////////////////////////////////////////////////////////


module clk(
    input [1:0] adc_clk_i,
    output clk_locked,
    output adc_cdcs_o,
    output clk125, clk250, clk250p
);
    assign adc_cdcs_o = 1'b1;  // clock duty cycle stabilizer

    wire clk_in, fb_u, fb;
    wire clk125_u, clk250_u, clk250p_u;

    IBUFDS ibuf (.I(adc_clk_i[1]), .IB(adc_clk_i[0]), .O(clk_in));
    PLLE2_BASE #(
        .CLKIN1_PERIOD(8.0),
        .CLKFBOUT_MULT(8),
        .CLKOUT0_DIVIDE(8),
        .CLKOUT1_DIVIDE(4),
        .CLKOUT2_DIVIDE(4),
        .CLKOUT2_PHASE(-45.0)
    ) pll (
        .CLKIN1(clk_in), .CLKFBOUT(fb_u), .CLKFBIN(fb),
        .CLKOUT0(clk125_u),
        .CLKOUT1(clk250_u),
        .CLKOUT2(clk250p_u),
        .LOCKED(clk_locked),
        .RST(1'b0),
        .PWRDWN(1'b0)
    );
    BUFG bfb   (.I(fb_u), .O(fb));
    BUFG bufg0 (.I(clk125_u), .O(clk125));
    BUFG bufg1 (.I(clk250_u), .O(clk250));
    BUFG bufg2 (.I(clk250p_u), .O(clk250p));
endmodule
