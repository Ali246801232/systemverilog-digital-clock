`timescale 1ns / 1ps

//================================================================
// Testbench Interface
//================================================================

interface digital_clock_if (input logic clk);
    logic rst_n;
    logic [5:0] sec;
    logic [5:0] min;
    logic [4:0] hr;
endinterface
