`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: Innopolis University
// Engineer: Demetrius Ryabov
//
// Create Date: 10/27/2026 09:31:42 AM
// Design Name: DAC Writer
// Module Name: dac_writer
// Project Name: Fast TTL2NIM Converter
// Target Devices: Red Pitaya STEMlab 125-14 v1.1 (Zynq-7010, xc7z010clg400-1)
// Tool Versions: Vivado 2025.2
//////////////////////////////////////////////////////////////////////////////////


module dac_writer(
    input clk_locked,
    input clk125, clk250, clk250p,
    input signed [13:0] out1, out2,
    output dac_clk_o, dac_sel_o, dac_wrt_o, dac_rst_o,
    output [13:0] dac_dat_o
);
    assign dac_rst_o = ~clk_locked;  // wait until clocks are locked

    // actual DAC values, clocked
    reg [13:0] dac_a, dac_b;
    always @(posedge clk125) begin
        dac_a <= {out1[13], ~out1[12:0]};
        dac_b <= {out2[13], ~out2[12:0]};
    end

    // use one bus, switch outputs twice a tick
    ODDR o_sel (.Q(dac_sel_o), .C(clk125),  .D1(1'b1), .D2(1'b0), .CE(1'b1), .S(1'b0), .R(1'b0));
    ODDR o_dat [13:0] (.Q(dac_dat_o), .C(clk125), .D1(dac_b), .D2(dac_a), .CE(1'b1), .S(1'b0), .R(1'b0));

    ODDR o_wrt (.Q(dac_wrt_o), .C(clk250),  .D1(1'b0), .D2(1'b1), .CE(1'b1), .S(1'b0), .R(1'b0));
    // DAC clock's posedge comes after write established
    ODDR o_clk (.Q(dac_clk_o), .C(clk250p), .D1(1'b0), .D2(1'b1), .CE(1'b1), .S(1'b0), .R(1'b0));
endmodule
