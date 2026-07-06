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


//================================================================
// UVM Testbench Package
//================================================================

package clock_pkg;
    import uvm_pkg::*;
    `include "uvm_macros.svh"


    // Sequence Item

    class clk_seq_item extends uvm_sequence_item;
        `uvm_object_utils(clk_seq_item)

        rand bit reset_n;
        rand int duration;
        rand int div_factor;

        bit [5:0] sec;
        bit [5:0] min;
        bit [4:0] hr;

        constraint c_duration { duration > 0; duration < 100000; }

        function new(string name = "clk_seq_item");
            super.new(name);
            if (!uvm_config_db#(int)::get(null, "", "div_factor", div_factor))
                div_factor = 1;
            sec = 0;
            min = 0;
            hr = 0;
        endfunction
    endclass


    // Sequencer

    class clk_sequencer extends uvm_sequencer #(clk_seq_item);
        `uvm_component_utils(clk_sequencer)

        function new(string name = "clk_sequencer", uvm_component parent = null);
            super.new(name, parent);
        endfunction
    endclass


    // Driver

    class clk_driver extends uvm_driver #(clk_seq_item);
        `uvm_component_utils(clk_driver)

        virtual digital_clock_if vif;
        clk_seq_item req;

        function new(string name = "clk_driver", uvm_component parent = null);
            super.new(name, parent);
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            if (!uvm_config_db#(virtual digital_clock_if)::get(this, "", "vif", vif))
                `uvm_fatal("DRV", "No virtual interface found")
        endfunction

        task run_phase(uvm_phase phase);
            forever begin
                seq_item_port.get_next_item(req);
                vif.rst_n = req.reset_n;
                repeat (req.duration) @(posedge vif.clk);
                seq_item_port.item_done();
            end
        endtask
    endclass


    // Monitor

    class clk_monitor extends uvm_monitor;
        `uvm_component_utils(clk_monitor)

        virtual digital_clock_if vif;
        uvm_analysis_port #(clk_seq_item) mon_ap;

        function new(string name = "clk_monitor", uvm_component parent = null);
            super.new(name, parent);
            mon_ap = new("mon_ap", this);
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            if (!uvm_config_db#(virtual digital_clock_if)::get(this, "", "vif", vif))
                `uvm_fatal("MON", "No virtual interface found")
        endfunction

        task run_phase(uvm_phase phase);
            clk_seq_item item;
            forever begin
                @(negedge vif.clk);
                item = clk_seq_item::type_id::create("item");
                item.sec = vif.sec;
                item.min = vif.min;
                item.hr  = vif.hr;
                mon_ap.write(item);
            end
        endtask
    endclass


    // Agent

    class clk_agent extends uvm_agent;
        `uvm_component_utils(clk_agent)

        clk_sequencer sqr;
        clk_driver drv;
        clk_monitor mon;

        function new(string name = "clk_agent", uvm_component parent = null);
            super.new(name, parent);
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            sqr = clk_sequencer::type_id::create("sqr", this);
            drv = clk_driver::type_id::create("drv", this);
            mon = clk_monitor::type_id::create("mon", this);
        endfunction

        function void connect_phase(uvm_phase phase);
            super.connect_phase(phase);
            drv.seq_item_port.connect(sqr.seq_item_export);
        endfunction
    endclass


    // Scoreboard

    class clk_scoreboard extends uvm_scoreboard;
        `uvm_component_utils(clk_scoreboard)

        uvm_analysis_imp #(clk_seq_item, clk_scoreboard) mon_export;
        virtual digital_clock_if vif;

        int div_factor;
        int pass_count, fail_count;

        int clk_div_count;
        logic [5:0] model_sec;
        logic [5:0] model_min;
        logic [4:0] model_hr;

        function new(string name = "clk_scoreboard", uvm_component parent = null);
            super.new(name, parent);
            mon_export = new("mon_export", this);
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            if (!uvm_config_db#(virtual digital_clock_if)::get(this, "", "vif", vif))
                `uvm_fatal("SCB", "No virtual interface")
            if (!uvm_config_db#(int)::get(this, "", "div_factor", div_factor))
                div_factor = 1;
            pass_count = 0;
            fail_count = 0;
        endfunction

        task run_phase(uvm_phase phase);
            forever begin
                @(posedge vif.clk);

                if (!vif.rst_n) begin
                    clk_div_count = 0;
                    model_sec = 0;
                    model_min = 0;
                    model_hr = 0;
                end else begin
                    logic en_1hz = (clk_div_count == div_factor - 1);
                    logic en_min = en_1hz && (model_sec == 59);
                    logic en_hr  = en_min  && (model_min == 59);

                    if (en_1hz) begin
                        model_sec = (model_sec == 59) ? 0 : model_sec + 1;
                    end
                    if (en_min) begin
                        model_min = (model_min == 59) ? 0 : model_min + 1;
                    end
                    if (en_hr) begin
                        model_hr = (model_hr == 23) ? 0 : model_hr + 1;
                    end

                    if (clk_div_count == div_factor - 1)
                        clk_div_count = 0;
                    else
                        clk_div_count = clk_div_count + 1;
                end
            end
        endtask

        function void write(clk_seq_item item);
            bit sec_err, min_err, hr_err;

            sec_err = (item.sec !== model_sec);
            min_err = (item.min !== model_min);
            hr_err  = (item.hr  !== model_hr);

            if (sec_err || min_err || hr_err) begin
                if (sec_err)
                    `uvm_error("SCB", $sformatf("SEC mismatch: DUT=%0d, REF=%0d", item.sec, model_sec))
                if (min_err)
                    `uvm_error("SCB", $sformatf("MIN mismatch: DUT=%0d, REF=%0d", item.min, model_min))
                if (hr_err)
                    `uvm_error("SCB", $sformatf("HR mismatch: DUT=%0d, REF=%0d", item.hr, model_hr))
                fail_count++;
            end else begin
                `uvm_info("SCB", $sformatf("MATCH: %0d:%0d:%0d", item.hr, item.min, item.sec), UVM_HIGH)
                pass_count++;
            end
        endfunction

        function void report_phase(uvm_phase phase);
            `uvm_info("SCB", $sformatf("Scoreboard summary: %0d passed, %0d failed", pass_count, fail_count), UVM_LOW)
        endfunction
    endclass


    // Environment

    class clk_env extends uvm_env;
        `uvm_component_utils(clk_env)

        clk_agent agt;
        clk_scoreboard scb;

        function new(string name = "clk_env", uvm_component parent = null);
            super.new(name, parent);
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            agt = clk_agent::type_id::create("agt", this);
            scb = clk_scoreboard::type_id::create("scb", this);
        endfunction

        function void connect_phase(uvm_phase phase);
            super.connect_phase(phase);
            agt.mon.mon_ap.connect(scb.mon_export);
        endfunction
    endclass


    // Sequences

    class reset_seq extends uvm_sequence #(clk_seq_item);
        `uvm_object_utils(reset_seq)

        function new(string name = "reset_seq");
            super.new(name);
        endfunction

        task body();
            clk_seq_item item;

            item = clk_seq_item::type_id::create("item");
            start_item(item);
            item.reset_n = 0;
            item.duration = 15;
            finish_item(item);

            item = clk_seq_item::type_id::create("item");
            start_item(item);
            item.reset_n = 1;
            item.duration = 30;
            finish_item(item);
        endtask
    endclass

    class seconds_count_seq extends uvm_sequence #(clk_seq_item);
        `uvm_object_utils(seconds_count_seq)

        int div_factor;

        function new(string name = "seconds_count_seq");
            super.new(name);
            if (!uvm_config_db#(int)::get(null, "", "div_factor", div_factor))
                div_factor = 1;
        endfunction

        task body();
            clk_seq_item item;

            item = clk_seq_item::type_id::create("item");
            start_item(item);
            item.reset_n = 0;
            item.duration = 10;
            finish_item(item);

            item = clk_seq_item::type_id::create("item");
            start_item(item);
            item.reset_n = 1;
            item.duration = div_factor * 59; // sec: 0 -> 59, no rollover into min
            finish_item(item);
        endtask
    endclass

    class rollover_seq extends uvm_sequence #(clk_seq_item);
        `uvm_object_utils(rollover_seq)
        int div_factor;

        function new(string name = "rollover_seq");
            super.new(name);
            if (!uvm_config_db#(int)::get(null, "", "div_factor", div_factor))
                div_factor = 1;
        endfunction

        task body();
            clk_seq_item item;

            item = clk_seq_item::type_id::create("item");
            start_item(item);
            item.reset_n = 0;
            item.duration = 10;
            finish_item(item);

            item = clk_seq_item::type_id::create("item");
            start_item(item);
            item.reset_n = 1;
            item.duration = 10;
            finish_item(item);

            item = clk_seq_item::type_id::create("item");
            start_item(item);
            item.reset_n = 1;
            item.duration = div_factor * 24 * 60 * 60;
            finish_item(item);
        endtask
    endclass


    // Tests

    class reset_test extends uvm_test;
        `uvm_component_utils(reset_test)

        clk_env env;
        reset_seq seq;

        function new(string name = "reset_test", uvm_component parent = null);
            super.new(name, parent);
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            env = clk_env::type_id::create("env", this);
            seq = reset_seq::type_id::create("seq", this);
        endfunction

        task run_phase(uvm_phase phase);
            phase.raise_objection(this);
            seq.start(env.agt.sqr);
            #100;
            phase.drop_objection(this);
        endtask
    endclass

    class seconds_test extends uvm_test;
        `uvm_component_utils(seconds_test)

        clk_env env;
        seconds_count_seq seq;

        function new(string name = "seconds_test", uvm_component parent = null);
            super.new(name, parent);
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            env = clk_env::type_id::create("env", this);
            seq = seconds_count_seq::type_id::create("seq", this);
        endfunction

        task run_phase(uvm_phase phase);
            phase.raise_objection(this);
            seq.start(env.agt.sqr);
            #100;
            phase.drop_objection(this);
        endtask
    endclass

    class rollover_test extends uvm_test;
        `uvm_component_utils(rollover_test)

        clk_env env;
        rollover_seq seq;

        function new(string name = "rollover_test", uvm_component parent = null);
            super.new(name, parent);
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            env = clk_env::type_id::create("env", this);
            seq = rollover_seq::type_id::create("seq", this);
        endfunction

        task run_phase(uvm_phase phase);
            phase.raise_objection(this);
            seq.start(env.agt.sqr);
            #100;
            phase.drop_objection(this);
        endtask
    endclass

endpackage


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
