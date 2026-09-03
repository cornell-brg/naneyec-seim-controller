# NanEyeC Controller

NanEyeC is a miniature camera module manufactured by ams OSRAM. This repository provides a synthesizable and reliable controller for operating NanEyeC sensors in SEIM (Single-Ended Interface Mode).

[![Tests](https://github.com/cornell-brg/naneyec-seim-controller/actions/workflows/test.yml/badge.svg)](https://github.com/cornell-brg/naneyec-seim-controller/actions/workflows/test.yml)

## Features

- Configurable sensor register parameters
- Configurable output pixel width
- Pixel-valid and frame-completion outputs
- Automatic frame alignment and readout recovery
- Synchronization support for multiple sensors (usage shown in examples)
- Validation using a behavioral sensor model with single- and multiple-sensor testbenches

## Example Images

## Controller Diagram

<p align="center">
    <img src="docs/naneye-seim-architecture-drawing.jpg" alt="Controller Diagram" width="600" >
</p>

### Interface and Pixel Retrieval

The controller communicates with the sensor through the `naneye_sclk` and the bidirectional `naneye_sdat` signals. During register configuration, the controller drives the data line, and during pixel readout, it tri-states the data line and samples the data provided by the sensor.

Each transmitted pixel is 12 serial-clock cycles with the format:
`{start bit = 1, pixel data[9:0], stop bit = 0}`. Incoming bits are effectively sampled on falling `naneye_sclk` edges, and are collected in a shift register. During the row readout state, `valid` pulses for every 12 received pixel bits. In this context, however, valid indicates a pixel boundary and not that the start and stop bits are correct.
- If the start and stop bits do match, `valid` goes high and the most significant `OUTBITS` of the pixel value are returned.
- If the start and stop bits do not match, `valid` still goes high but the pixel output becomes zero.

## Control Unit

<p align="center">
  <img src="docs/naneye-seim-fsm-diagram-drawing.jpg" width="600" alt="FSM Diagram">
</p>

### Startup and Configuration

After reset, the controller remains in `IDLE` until start goes high. Then, the sensor serial clock gets enabled, configuration registers are written, and waits `WAITCLKS` serial clock cycles to enter `FIND_READOUT` to find the first pixel readout row.

### EOF (End of Frame) Validation

After each readout phase, the controller enters `EOF` state and an EOF pattern of 96 consecutive zero bits are transmitted by the sensor. The controller checks if this stream indeed has the 96 repeating zeros. If it does, `eof_valid` goes high and if it doesn't `eof_valid` remains low.

### Frame Alignment

The frame aligner unit is enabled only in the `FIND_READOUT` state. The frame aligner uses the fact that there is a long pattern of alternating ones and zeros, called a training pattern, before readout starts. Frame aligner detects the first two consecutive ones after at least 12 rows of alternating bits in the data stream to reliably detect the start of pixel readout. This detection takes place when the first bit of the first pixel is already sampled so the phase counter and pixel-bit counters are loaded with 1.

Find readout state is usually entered after each `INTERFACE` state in which the registers are again written the pre-defined register parameters. However, `INTERFACE` state is skipped after leaving pixel readout either when there are at least 11 pixels that do not match the start and stop bit format or when `eof_valid` is low. Entering `INTERFACE` under those circumstances could cause the controller to drive `naneye_sdat` while the sensor is still transmitting data, resulting in bus contention and incorrectly timed register writes. Instead, the controller keeps naneye_sdat released and enters `FIND_READOUT` to recover the beginning of a valid readout period.

It's important to note that this frame alignment method enables recovering from timing shifts caused by propagation delay from the controller to the sensor.

## Validation

The controller is validated with a behavioral NanEyeC sensor model and Verilator testbenches that use this model.

The single-sensor testbench includes:
- Scoreboard comparison of received pixels against constant and pixels of stored images
- Sensor configuration register checks
- Injected row-delay corruption to verify loss-of-alignment recovery
- Injected serial-data noise during `FIND_READOUT` to verify alignment robustness
- Tracked valid pixels, completed frame count, delay corruption cases, and controller FSM state

There is also a multiple sensor testbench that configures two controllers with different delay values and verifies that their `valid`, `frame_pulse`, and pixel outputs remain synchronized.

The controller was also synthesized and tested on an FPGA board. The example picture captures are given above.

### Run the tests

Tests below can be run with GNU Make and Verilator installed.

```sh
make lint
make test
```

Individual simulations can also be run with:

```sh
make test-small
make test-large
make test-multiple
```
