`timescale 1ns / 1ps

//================================================================
// Top Module
//================================================================

import uvm_pkg::*;
`include "uvm_macros.svh"
import clock_pkg::*;


module top;
    localparam int DIV_FACTOR = 1;

    logic clk;

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;   // 10ns clock period (100MHz)
    end

    digital_clock_if vif (.*);

    digital_clock #(.DIV_FACTOR(DIV_FACTOR)) u_dut (
        .clk   (clk),
        .rst_n (vif.rst_n),
        .sec   (vif.sec),
        .min   (vif.min),
        .hr    (vif.hr)
    );

    initial begin
        uvm_config_db#(virtual digital_clock_if)::set(null, "*.agt.drv", "vif", vif);
        uvm_config_db#(virtual digital_clock_if)::set(null, "*.agt.mon", "vif", vif);
        uvm_config_db#(virtual digital_clock_if)::set(null, "*.scb", "vif", vif);
        uvm_config_db#(int)::set(null, "*", "div_factor", DIV_FACTOR);
    end

    initial begin
        run_test();
    end

    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0, top);
    end

endmodule
