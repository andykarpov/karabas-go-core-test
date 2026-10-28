# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

The board test core of the Karabas Go, Mini and Mini G: Xilinx Spartan-6 XC6SLX25 (speed grade -2), ISE 14.7 (XST), Verilog with some VHDL. The README calls it an adopted version of the ZXDOS test core; the screen says "KARABAS GO PCB TESTER" (`rtl/common/texto_inicial_lx25.txt`) and many module and instance names are Spanish (`relojes`, `teclas`, `mensajes`). No license file.

It shows a text screen with the FPGA DNA and the results of the tests: SRAM fast / slow (`ramtest16b`), joysticks 1 and 2, switches, EAR, SDRAM (`sdramtest`), SD slot (`sdtest`), SPI flash (`flashtest`), mouse, and plays an audio sample (`audio_test`). Keys (`rtl/common/switch_mode.v`, USB keyboard scancodes): 1 PAL, 2 NTSC, 3 VGA 60 Hz, 4-9 repeat a test, Space hides the text window.

Three tops: `src/rtl/karabas_go_top.v` (VGA: `video_processor_lx25` and `vga_scandoubler` on clk7, PCM5102 DAC), `karabas_mini_top.v` and `karabas_minig_top.v` (HDMI: `video_processor_vga` on clk40, `pllx5` for the TMDS clocks, `hdmi` or `dvi` by `DVI_ONLY`). The ISE projects set no Verilog macros.

The core is not converted to karabas-go-modules: it carries its own MCU link, soft switches and HDMI code.

## Layout

- `src/rtl/karabas_*_top.v`: the boards. `src/rtl/relojes.v`: the PLL from CLK_50MHZ (VCO 700 MHz): clk100, clk14, clk7, clk40 (~41.2 MHz).
- `src/rtl/common`: the tests, `video_processor*.v` (the text screen, module `updater`; `CP437.hex` font, `texto_inicial*.hex` screens), `switch_mode.v`, `get_dna.v`, `sync_generator_*.v`, the audio samples (`left_audio.hex`, `right_audio.hex`) and some `tb_*.v` testbenches with `.wcfg` waves.
- `src/rtl/mcu`: `mcu.vhd`, `soft_switches.vhd`, `hid_parser.vhd`, `cursor.vhd`. `src/rtl/hdmi`, `src/rtl/dac` (`pcm5102.v`, `dac.vhd` of the Mini), `src/rtl/adc/i2s_transceiver.vhd`, `src/rtl/spi`.
- `src/ipcore_dir`: CoreGen cores (`.xco` and generated files, committed); the projects use `rtc`, `queue` and on the Mini / Mini G `pllx5`.

## Build

- Open `src/karabas-go.xise`, `karabas-mini.xise` or `karabas-minig.xise` in ISE 14.7 and run Generate Programming File; "Create Binary Configuration File" is on, so ISE writes `src/karabas_<board>_top.bin`. There is no Makefile or build script.
- Pack with `make_core.py` (a symlink to `../../karabas-go-tools/make_core/make_core.py`, the sibling repo must be checked out next to this one) from `core.json` (Go), `core_mini.json`, `core_minig.json` into `src/test.kg1` / `kg2` / `kg3`. The `.bin` and `.kg*` files are committed; the ISE outputs are in `.gitignore`.
- The json: id `test`, `"type": "hidden"`, no ROMs, `eeprom_bank` 255 (none), one OSD item Reset (Ctrl+Alt+Del). The `build` of `core.json` (24030514) is older than that of the Mini files (26011000).
- `src/karabas_go.bin` (tracked) is from an older Go project with a VHDL top; the current Go project writes `karabas_go_top.bin`, the one `core.json` packs.

## MCU link

- `rtl/mcu/mcu.vhd` is an old local copy: keyboard (01), mouse (02), joysticks (03), buttons (04), switches (05), ROM bank / data / loader (06-08), OSD (20), CMD_HW_SETUP (F9, `DVI_ONLY`), RTC (FA), init start / done. No CMD_CAPS, so no bursts. The tops use the keyboard, mouse buttons, joysticks and the soft switches (`soft_switches.vhd`, its `RESET`); the RTC, ROM loader and OSD outputs are left open.
- The MCU link runs on clk14 on the Go and clk40 on the Mini / Mini G.

## Release

- `karabas-go/cores/test.kg1` of the release repo is the same file as `src/test.kg1`.

## Memory

The Claude Code memory of this repo is shared with all karabas-go repos: `~/.claude/projects/<this project>/memory` is a symlink to `../karabas-go-notes` (private repo `andykarpov/karabas-go-notes`, `link.sh` there makes the links). Its `MEMORY.md` is split by repo; commit and push it after every memory change.
