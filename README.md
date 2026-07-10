# SystemVerilog Digital Clock

A modular 24-hour digital clock (`HH:MM:SS`) designed in SystemVerilog and verified using a UVM-based testbench. The full runnable version of the code is available on [EDA Playground](https://www.edaplayground.com/x/qgSM); the code and test results are also in the [edaplayground](./edaplayground/) of this repository.

## Overview

This project implements a digital clock that increments every second, rolling over at `23:59:59` back to `00:00:00`. The design is built from reusable counter modules and includes a clock divider to generate a 1 Hz enable tick from a higher-frequency system clock.

## Key Features

- **24-hour timekeeping:** counts from `00:00:00` to `23:59:59`
- **Modular architecture:** separate counters for seconds, minutes, and hours
- **Clock divider:** generates a 1-second enable pulse
- **Asynchronous active-low reset:** resets all counters to zero
- **UVM verification:**  complete verification environment with using UVM

## Architecture

| Module | Description |
|--------|-------------|
| `clk_divider` | Divides input clock to produce a 1 Hz tick enable |
| `mod60_counter` | 6-bit counter that counts 0-59 and asserts a rollover flag |
| `mod24_counter` | 5-bit counter that counts 0-23 and asserts a rollover flag |
| `digital_clock` | Top-level module that instantiates the counters and drives the `HH:MM:SS` outputs |

## Verification

The UVM testbench validates the design against all specification points through three tests:

1. `reset_test`: Tests that `reset` causes clock to remain at `00:00:00` when set.
2. `seconds_test`: Tests that counters update once every second.
3. `rollover_test`: Tests that every possible time correctly increments counters and rollovers.

A UVM scoreboard automatically compares the DUT outputs against the expected values. To enable fast functional testing without having to wait for real-time seconds, there is a `DIV_FACTOR` parameter that is set to `1` during simulation.

The scoreboard also uses a `counting` parameter in the `digital_clock_if` that ensures the setup and cleanup operations are not counted as part of the test. The virtual interface also adds a `pass_count` and `fail_count` that the scoreboard hooks into, to provie the test statuses to the top module so the waveform can display them.
