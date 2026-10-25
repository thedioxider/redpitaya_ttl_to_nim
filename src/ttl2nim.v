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
/** If disabled, use binary threshold */
`define ENABLE_SUBSAMPLING

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
    `else
    assign led_o[6:0] = 7'b0;
    `endif // LED_CLOCK


    // ----- ADC -----
    reg [13:0] adc_raw;  // raw bits read from ADC
    always @(posedge clk125)
        adc_raw <= adc_dat_a_i[15:2];  // cut reserved bits
    wire signed [13:0] in1 = {adc_raw[13], ~adc_raw[12:0]};  // actual ADC value


    // ----- DAC -----
    // OUT1: IN1 copy
    // OUT2: NIM signal
    localparam signed [13:0] DAC_GND  =  -14'sd115;  // ~ 0V DAC
    localparam signed [13:0] TTL_THR  =   14'sd615;  // ~ 1.5V HV ADC
    localparam signed [13:0] NIM_HI   = -14'sd6400;  // ~ -0.8V DAC
    localparam signed [13:0] NIM_LO   = DAC_GND;
    localparam signed [13:0] NIM_SPAN = NIM_HI - NIM_LO;

    assign dac_rst_o = ~locked;  // wait until clocks are locked

    // output values
    wire signed [13:0] out1, out2;
    assign out1 = in1;

    // actual DAC values, clocked
    reg [13:0] dac_a, dac_b;
    always @(posedge clk125) begin
        dac_a <= {out1[13], ~out1[12:0]};
        dac_b <= {out2[13], ~out2[12:0]};
    end

    `ifdef ENABLE_SUBSAMPLING
    reg signed [13:0] nim_level = NIM_LO;
    assign out2 = nim_level;

    // -- PREPROCESSING: precompute reciprocal table
    localparam FRACTION_BITS = 14;  // how many bits numerator & denominator contains
    localparam RECIP_RESOLUTION = 18;
    localparam SUBSAMPLE_RESOLUTION = 8;
    reg [RECIP_RESOLUTION:0] recip_rom [0:(1 << FRACTION_BITS) - 1];
    integer i;
    initial begin
        recip_rom[0] = 0;
        for (i = 1; i < (1 << FRACTION_BITS); i = i + 1)
            recip_rom[i] = ((1 << RECIP_RESOLUTION) + i / 2) / i;  // round to nearest integer
    end

    // -- STAGE 0: update samples, compare them against threshold
    reg signed [13:0] s0, s1;  // last two samples
    always @(posedge clk125) begin
        s0 <= s1;
        s1 <= in1;
    end
    wire        ttl_high  = (s1 > TTL_THR);
    wire        ttl_rise  = (s0 <= TTL_THR) && ttl_high;
    wire        ttl_fall  = (s0 >  TTL_THR) && !ttl_high;
    wire [13:0] s0_to_thr = (TTL_THR > s0) ? (TTL_THR - s0) : (s0 - TTL_THR);
    wire [13:0] s_delta   = (s1 > s0) ? (s1 - s0) : (s0 - s1);

    // -- STAGE 1: lock comparison results
    reg r1_high, r1_rise, r1_fall;
    reg [FRACTION_BITS - 1:0] r1_num, r1_den;  // numerator & denominator for position formula
    always @(posedge clk125) begin
        {r1_high, r1_rise, r1_fall} <= {ttl_high, ttl_rise, ttl_fall};
        {r1_num, r1_den} <= {s0_to_thr, s_delta};
    end

    // -- STAGE 2: lookup inverse denominator in ROM
    reg r2_high, r2_rise, r2_fall;
    reg [FRACTION_BITS - 1:0] r2_num;
    reg [RECIP_RESOLUTION:0] r2_recip;
    always @(posedge clk125) begin
        {r2_high, r2_rise, r2_fall} <= {r1_high, r1_rise, r1_fall};
        r2_num <= r1_num;
        r2_recip <= recip_rom[r1_den];
    end

    // -- STAGE 3: find threshold position between samples
    reg r3_high, r3_rise, r3_fall;
    reg [SUBSAMPLE_RESOLUTION:0] r3_subpos;  // 0 - THR at s0, 2^SUBSAMPLE_RESOLUTION - THR at s1
    localparam W3_PROD_W = FRACTION_BITS + RECIP_RESOLUTION + 1;
    localparam W3_PROD_SHIFT = RECIP_RESOLUTION - SUBSAMPLE_RESOLUTION;
    wire [W3_PROD_W - 1:0] w3_prod = r2_num * r2_recip;
    wire [W3_PROD_W - W3_PROD_SHIFT - 1:0] w3_subpos = w3_prod >> W3_PROD_SHIFT;
    always @(posedge clk125) begin
        {r3_high, r3_rise, r3_fall} <= {r2_high, r2_rise, r2_fall};
        r3_subpos <= (w3_subpos > (1 << SUBSAMPLE_RESOLUTION))
            ? (1 << SUBSAMPLE_RESOLUTION)
            : w3_subpos[SUBSAMPLE_RESOLUTION:0];
    end

    // -- STAGE 4: compute rise/fall levels
    reg r4_high, r4_rise, r4_fall;
    wire signed [SUBSAMPLE_RESOLUTION + 1:0] w4_subpos = {1'b0, r3_subpos};  // signed to keep expressions signed
    reg signed [13 + SUBSAMPLE_RESOLUTION:0] r4_rise_part;
    reg signed [13 + SUBSAMPLE_RESOLUTION:0] r4_fall_part;
    always @(posedge clk125) begin
        {r4_high, r4_rise, r4_fall} <= {r3_high, r3_rise, r3_fall};
        r4_rise_part <= NIM_SPAN * ((1 <<< SUBSAMPLE_RESOLUTION) - w4_subpos);
        r4_fall_part <= NIM_SPAN * w4_subpos;
    end

    // -- STAGE 5: output level with subsampling on edges
    always @(posedge clk125)
        if      (r4_rise) nim_level <= NIM_LO + (r4_rise_part >>> SUBSAMPLE_RESOLUTION);
        else if (r4_fall) nim_level <= NIM_LO + (r4_fall_part >>> SUBSAMPLE_RESOLUTION);
        else              nim_level <= r4_high ? NIM_HI : NIM_LO;

    `else // ENABLE_SUBSAMPLING
    assign out2 = (in1 > TTL_THR) ? NIM_HI : NIM_LO;
    `endif // ENABLE_SUBSAMPLING

    // use one bus, switch outputs twice a tick
    ODDR o_sel (.Q(dac_sel_o), .C(clk125),  .D1(1'b1), .D2(1'b0), .CE(1'b1), .S(1'b0), .R(1'b0));
    ODDR o_dat [13:0] (.Q(dac_dat_o), .C(clk125), .D1(dac_b), .D2(dac_a), .CE(1'b1), .S(1'b0), .R(1'b0));
    ODDR o_wrt (.Q(dac_wrt_o), .C(clk250),  .D1(1'b0), .D2(1'b1), .CE(1'b1), .S(1'b0), .R(1'b0));
    // DAC clock's posedge comes after write established
    ODDR o_clk (.Q(dac_clk_o), .C(clk250p), .D1(1'b0), .D2(1'b1), .CE(1'b1), .S(1'b0), .R(1'b0));
endmodule
