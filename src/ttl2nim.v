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
/** If disabled, just copy ADC to DAC */
// `define CONVERT_TO_NIM

module ttl2nim(
    input [1:0] adc_clk_i,
    input [15:0] adc_dat_a_i,
    input [15:0] adc_dat_b_i,
    output adc_cdcs_o,
    output [7:0] led_o,
    output [13:0] dac_dat_o,
    output dac_clk_o, dac_sel_o, dac_wrt_o, dac_rst_o
);
    // ----- Clock -----
    assign adc_cdcs_o = 1'b1;  // clock duty cycle stabilizer

    wire clk_in, fb_u, fb, locked;
    wire clk125_u, clk250_u, clk250p_u;
    wire clk125, clk250, clk250p;

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
        .LOCKED(locked),
        .RST(1'b0),
        .PWRDWN(1'b0)
    );
    BUFG bfb   (.I(fb_u), .O(fb));
    BUFG bufg0 (.I(clk125_u), .O(clk125));
    BUFG bufg1 (.I(clk250_u), .O(clk250));
    BUFG bufg2 (.I(clk250p_u), .O(clk250p));

    reg [31:0] cnt = 0;  // tick counter
    always @(posedge clk125)
        cnt <= cnt + 1;


    // ----- LED -----
    assign led_o[7] = locked;
    `ifdef LED_CLOCK
    wire [31:0] rev_cnt = {<<{cnt}};
    assign led_o[6:0] = rev_cnt[8:2];
    `endif // LED_CLOCK


    // ----- ADC -----
    reg [13:0] adc_raw;  // raw bits read from ADC
    always @(posedge clk125)
        adc_raw <= adc_dat_a_i[15:2];  // cut reserved bits
    wire signed [13:0] in1 = {adc_raw[13], ~adc_raw[12:0]};  // actual ADC value


    // ----- DAC -----
    assign dac_rst_o = ~locked;  // wait until clocks are locked
    // output values to be assigned
    wire signed [13:0] out1;
    wire signed [13:0] out2;

    // actual DAC values, clocked
    reg [13:0] dac_a, dac_b;
    always @(posedge clk125) begin
        dac_a <= {out1[13], ~out1[12:0]};
        dac_b <= {out2[13], ~out2[12:0]};
    end

    `ifdef CONVERT_TO_NIM
    // TODO

    `else // CONVERT_TO_NIM
    // OUT1: 50% duty square pulse
    // OUT2: copied input signal
    assign out1 = cnt[6] ? 14'sd4000 : -14'sd4000;
    assign out2 = in1;

    // use one bus, switch outputs twice a tick
    ODDR o_sel (.Q(dac_sel_o), .C(clk125),  .D1(1'b1), .D2(1'b0), .CE(1'b1), .S(1'b0), .R(1'b0));
    ODDR o_dat [13:0] (.Q(dac_dat_o), .C(clk125), .D1(dac_b), .D2(dac_a), .CE(1'b1), .S(1'b0), .R(1'b0));
    `endif // CONVERT_TO_NIM


    ODDR o_wrt (.Q(dac_wrt_o), .C(clk250),  .D1(1'b0), .D2(1'b1), .CE(1'b1), .S(1'b0), .R(1'b0));
    // DAC clock's posedge comes after write established
    ODDR o_clk (.Q(dac_clk_o), .C(clk250p), .D1(1'b0), .D2(1'b1), .CE(1'b1), .S(1'b0), .R(1'b0));
endmodule
