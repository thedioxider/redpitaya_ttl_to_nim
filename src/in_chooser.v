`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: Innopolis University
// Engineer: Demetrius Ryabov
//
// Create Date: 11/02/2026 07:29:29 AM
// Design Name: ADC Input Chooser
// Module Name: in_chooser
// Project Name: Fast TTL2NIM Converter
// Target Devices: Red Pitaya STEMlab 125-14 v1.1 (Zynq-7010, xc7z010clg400-1)
// Tool Versions: Vivado 2025.2
// Description:
//   Choose between HV and LV ADC inputs.
//////////////////////////////////////////////////////////////////////////////////


module in_chooser(
    input signed [13:0] in1, in2,
    input use_lv,  // otherwise, HV is used
    output signed [13:0] inx
);
    assign inx = use_lv ? in2 : in1;
endmodule
