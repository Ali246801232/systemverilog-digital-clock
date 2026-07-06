`timescale 1ns / 1ps

//================================================================
// RTL Implementation of a Digital Clock
//================================================================

// Clock Divider: generates 1Hz enable pulse from fast clock
module clk_divider #(
    parameter DIV_FACTOR = 100_000_000
) (
    input  logic clk,
    input  logic rst_n,
    output logic en_1hz
);
    integer count;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            count <= 0;
        else if (count == DIV_FACTOR - 1)
            count <= 0;
        else
            count <= count + 1;
    end

    assign en_1hz = (count == DIV_FACTOR - 1);
endmodule


// Mod-60 Counter: counts 0 to 59 (used for seconds and minutes)
module mod60_counter (
    input  logic       clk,
    input  logic       rst_n,
    input  logic       en,
    output logic [5:0] count,
    output logic       rollover
);
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            count <= 0;
        else if (en) begin
            if (count == 59)
                count <= 0;
            else
                count <= count + 1;
        end
    end

    assign rollover = en && (count == 59);
endmodule


// Mod-24 Counter: counts 0 to 23 (used for hours)
module mod24_counter (
    input  logic       clk,
    input  logic       rst_n,
    input  logic       en,
    output logic [4:0] count,
    output logic       rollover
);
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            count <= 0;
        else if (en) begin
            if (count == 23)
                count <= 0;
            else
                count <= count + 1;
        end
    end

    assign rollover = en && (count == 23);
endmodule


// Digital Clock: top module
module digital_clock #(
    parameter DIV_FACTOR = 100_000_000
) (
    input  logic       clk,
    input  logic       rst_n,
    output logic [5:0] sec,
    output logic [5:0] min,
    output logic [4:0] hr
);
    logic en_1hz;
    logic en_min;
    logic en_hr;

    clk_divider #(.DIV_FACTOR(DIV_FACTOR)) u_div (
        .clk    (clk),
        .rst_n  (rst_n),
        .en_1hz (en_1hz)
    );

    mod60_counter u_sec (
        .clk      (clk),
        .rst_n    (rst_n),
        .en       (en_1hz),
        .count    (sec),
        .rollover (en_min)
    );

    mod60_counter u_min (
        .clk      (clk),
        .rst_n    (rst_n),
        .en       (en_min),
        .count    (min),
        .rollover (en_hr)
    );

    mod24_counter u_hr (
        .clk      (clk),
        .rst_n    (rst_n),
        .en       (en_hr),
        .count    (hr),
        .rollover ()  // connected to nothing because no day counter
    );
endmodule
