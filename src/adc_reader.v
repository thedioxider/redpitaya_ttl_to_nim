`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: Innopolis University
// Engineer: Demetrius Ryabov
//
// Create Date: 10/27/2026 09:31:42 AM
// Design Name: ADC Reader
// Module Name: adc_reader
// Project Name: Fast TTL2NIM Converter
// Target Devices: Red Pitaya STEMlab 125-14 v1.1 (Zynq-7010, xc7z010clg400-1)
// Tool Versions: Vivado 2025.2
//////////////////////////////////////////////////////////////////////////////////


module adc_reader(
    input clk,
    input [15:0] adc_dat_a_i, adc_dat_b_i,
    output signed [13:0] in1, in2
);
    //raw bits read from ADC
    reg [13:0] adc_a_raw, adc_b_raw;

    always @(posedge clk) begin
        // cut reserved bits
        adc_a_raw <= adc_dat_a_i[15:2];
        adc_b_raw <= adc_dat_b_i[15:2];
    end

    // actual ADC value
    assign in1 = {adc_a_raw[13], ~adc_a_raw[12:0]};
    assign in2 = {adc_b_raw[13], ~adc_b_raw[12:0]};
endmodule