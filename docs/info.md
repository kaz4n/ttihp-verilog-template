<!---

This file is used to generate your project datasheet. Please fill in the information below and delete any unused
sections.

You can also include images in this folder and reference them in the markdown. Each image must be less than
512 kb in size, and the combined size of all images must be less than 1 MB.
-->

## How it works

Hi
## How to test

Hi
## External hardware

Hi
# Educational 4004-style CPU demo

This Tiny Tapeout starter contains:

- `i4004_edu_core.v`: compact 4-bit 4004-style CPU core
- `tt_um_replace_me_i4004_demo.v`: Tiny Tapeout wrapper plus small demo ROM

## Demo modes

- `ui_in[5] = 0`: mirror `ui_in[3:0]` to the output port
- `ui_in[5] = 1`: free-running 4-bit counter

## Pin map

- `ui_in[3:0]`: input nibble
- `ui_in[4]`: TEST pin
- `ui_in[5]`: ROM/demo mode select
- `uo_out[3:0]`: output nibble
- `uo_out[7:4]`: accumulator
- `uio[3:0]`: low nibble of PC
- `uio[4]`: ZERO
- `uio[5]`: CARRY
- `uio[6]`: immediate-fetch phase
- `uio[7]`: heartbeat
