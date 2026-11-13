#!/usr/bin/env python3
"""Link v2 tops of the test core for Mini and Go.

- rtl/karabas_mini_top.v is made from rtl/karabas_minig_top.v (the same 40 MHz design): the
  header and ports of the last v1 Mini top, the sigma-delta audio of Mini, its ESP / FT / MIDI pins;
  INT on MCU_IO[1]; FT_CLK_OUT (E7, MCU_IO<4> before) 8 MHz as on Mini G.
- rtl/karabas_go_top.v keeps its own older design (clk7 / clk14, VGA): only its MCU part changes
  from the v1 top (V1_REF): kg_mcu2 on clk14 (keyboard report, mouse buttons, joysticks, the Reset
  switch), INT on MCU_SPI_IO[0] (N9), kg_pcm5102 of modules. No OSD on Go (the core has none).
Every replacement must match once, else this stops.
"""
import os
import subprocess
import sys

SRC = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
RTL = os.path.join(SRC, "rtl")
V1_REF = "f77445c"  # master before link v2


def sub(s, old, new, what):
    if s.count(old) != 1:
        sys.exit("mktops.py: %s: %d matches of %r" % (what, s.count(old), old[:70]))
    return s.replace(old, new)


def v1(board):
    return subprocess.check_output(["git", "show", "%s:src/rtl/karabas_%s_top.v" % (V1_REF, board)],
                                   cwd=SRC).decode()


def head(s):
    i = s.index("module karabas_")
    return s[:s.index("\n);\n", i) + 4]


def body(s):
    i = s.index("module karabas_")
    return s[s.index("\n);\n", i) + 4:]


minig = open(os.path.join(RTL, "karabas_minig_top.v")).read()

# ---------------------------------------------------------------- Mini
m = body(minig)
m = sub(m, """kg_pcm5102 #(.DIV_BITS(3)) PCM5102(
	.clk(clk40),
	.reset(~clocks_ready),
	.left(audio_out_l),
	.right(audio_out_r),
	.din(DAC_DAT),
	.bck(DAC_BCK),
	.lrck(DAC_WS)
);""", """// Mini has no I2S DAC: sigma-delta outputs into an RC filter, offset binary input
kg_sigma_delta_dac dac_l(.clk(clk40), .reset(~clocks_ready), .din({ ~audio_out_l[15], audio_out_l[14:0] }), .dout(AUDIO_L));
kg_sigma_delta_dac dac_r(.clk(clk40), .reset(~clocks_ready), .din({ ~audio_out_r[15], audio_out_r[14:0] }), .dout(AUDIO_R));""",
        "mini dac")
m = sub(m, "	 assign ESP32_SPI_CS_N = 1'b1;\n", "    assign ESP_RESET_N = 1'bZ;\n    assign ESP_BOOT_N = 1'bZ;\n", "mini esp")
m = sub(m, "    assign FT_SPI_MOSI = 1'b1;\n", "    assign FT_SPI_MOSI = 1'b1;\n	 assign FT_RESET = 1'b1;\n", "mini ft")
m = sub(m, "	 assign MIDI_TX = 1'b0;\n", "	 assign MIDI_TX = 1'b0;\n	 assign MIDI_CLK = 1'b0;\n	 assign MIDI_RESET_N = 1'b1;\n", "mini midi")
m = sub(m, "assign MCU_IO[5:2] = 4'bzzzz;", "assign MCU_IO[3:2] = 2'bzz;", "mini mcu_io")
h = head(v1("mini"))
h = sub(h, "	input wire [4:0] MCU_IO,", "	inout wire [3:0] MCU_IO,   // [1] INT of link v2, [2] sd2 cs_n, [3] ft cs_n", "mini port mcu_io")
h = sub(h, "	output wire FT_RESET,", "	output wire FT_RESET,\n	output wire FT_CLK_OUT,", "mini port ft_clk")
mini = h + "// karabas: made by src/tools/mktops.py from karabas_minig_top.v (do not edit it, change Mini G)\n" + m

# ---------------------------------------------------------------- Go
g = v1("go")
g = sub(g, "	output wire MCU_MISO	\n   );", "	output wire MCU_MISO,\n	inout wire [1:0] MCU_SPI_IO   // [0] INT of link v2 (N9)\n   );", "go port")
i = g.index("//---------- MCU ------------")
j = g.index("//---------- DAC ------------")
g = g[:i] + """//---------- MCU: link v2 (karabas-go-firmware docs/link_v2.md, kg_mcu2); INT on MCU_SPI_IO[0] ------------

wire [7:0] ms_b8;
wire [2:0] ms_b = ms_b8[2:0];
wire [55:0] hid_kbd;
wire [7:0] hid_kb_status = hid_kbd[7:0], hid_kb_data = hid_kbd[15:8];
wire [15:0] joy_l16, joy_r16;
assign joy_l = joy_l16[12:0];
assign joy_r = joy_r16[12:0];
wire [7:0] sw;
wire mcu_busy;
wire mcu_int;
assign MCU_SPI_IO[0] = mcu_int;
assign MCU_SPI_IO[1] = 1'bz;

kg_mcu2 #(
	.SW_N(1),
	.CS_FILTER(3),
	.ENABLE_OSD(0),
	.ENABLE_FT(0),
	.ENABLE_SD2(0)
) mcu (
	.CLK(clk14),
	.N_RESET(clocks_ready),

	.MCU_SCK(MCU_SCK),
	.MCU_MOSI(MCU_MOSI),
	.MCU_MISO(MCU_MISO),
	.MCU_SS(MCU_CS_N),
	.MCU_INT(mcu_int),
	.MCU_SPI_FT_SS(1'b1),
	.MCU_SPI_SD2_SS(1'b1),

	.SW(sw), .SW_WR(), .SW_INDEX(), .SW_VALUE(), .HW_ID(), .DVI_ONLY(), .CORE_BUILD(), .FW_BUILD(),
	.BUSY(mcu_busy), .BTNS(), .RELOAD_REQ(1'b0), .RELOAD_CORE(8'd0),

	.KBD(hid_kbd), .KBD_WR(), .PS2_CODE(), .PS2_KIND(), .PS2_WR(),
	.MS_X(), .MS_Y(), .MS_Z(), .MS_B(ms_b8), .MS_WR(),
	.JOY_L(joy_l16), .JOY_R(joy_r16), .JOY_WR(),
	.PS2_CMD(16'h0000), .PS2_CMD_WR(1'b0),

	.LD_KIND(), .LD_SLOT(), .LD_SIZE(), .LD_START(), .LD_ACTIVE(), .LD_END(),
	.LD_ADDR(), .LD_DATA(), .LD_WR(), .LD_READY(1'b1),

	.OSD_WR(), .OSD_WADDR(), .OSD_WDATA(), .OSD_EN(), .OSD_FG(), .OSD_BG(), .OSD_ALPHA(),
	.OSD_PX(), .OSD_PY(), .OSD_PW(), .OSD_PH(), .OSD_PLACE(), .OSD_ZOOM(),

	.SDC_IMG_MOUNTED(), .SDC_IMG_SIZE(),
	.SDC_RD(8'd0), .SDC_WR(8'd0), .SDC_SECTOR(32'd0),
	.SDC_BUSY(), .SDC_DONE(), .SDC_ERROR(), .SDC_SLOT(),
	.SDC_BYTE_IN_STROBE(), .SDC_BYTE_ADDR(), .SDC_BYTE_IN_DATA(), .SDC_BYTE_OUT_DATA(8'd0),
	.IMG_WP(), .IMG_PHYS_WR(), .IMG_PHYS(), .IMG_FLUSH(), .FDD_CHNG_WR(), .FDD_CHNG(),
	.FDD_CHNG_REQ(1'b0), .FDD_CHNG_DS(2'd0),
	.BK_MOUNT(1'b0), .BK_FLUSHED(1'b0), .BK_SLOT(3'd0), .BK_SIZE(32'd0), .BK_KIND(8'd0), .BK_RESULT(8'd0),
	.IMG_ACTIVE(),

	.PORT_OUT_DATA(), .PORT_OUT_WR(), .PORT_OUT_READY(4'b1111), .PORT_IN_DATA(32'd0), .PORT_IN_WR(4'd0),
	.PORT_CFG(128'd0), .PORT_IN_FULL(), .PORT_STAT(), .PORT_STAT_WR(),
	.RTC_A(8'd0), .RTC_DI(8'd0), .RTC_CS(1'b0), .RTC_WR_N(1'b1), .RTC_DO(),
	.MATRIX_CMD(24'd0), .MATRIX_CMD_WR(1'b0), .DEBUG_ADDR(16'd0), .DEBUG_DATA(16'd0),

	.FT_SPI_ON(), .FT_VGA_ON(), .FT_RESET(), .FT_SCK(), .FT_MOSI(), .FT_MISO(1'b1), .FT_CS_N(),
	.SD2_SCK(), .SD2_MOSI(), .SD2_MISO(1'b1), .SD2_CS_N()
);

// -- MZYX CBAS RLDU O Positive Logic
// -- MXYZ SACB RLDU   Negative Logic
assign joy_l_md = {joy_l[12], joy_l[9], joy_l[10], joy_l[11], joy_l[5], joy_l[6], joy_l[8], joy_l[7], joy_l[4:1]};
assign joy_r_md = {joy_r[12], joy_r[9], joy_r[10], joy_r[11], joy_r[5], joy_r[6], joy_r[8], joy_r[7], joy_r[4:1]};

//---------- Soft switches (the SW registers of kg_mcu2) ------------

wire kb_reset = sw[0];
assign master_reset = kb_reset | mcu_busy;


""" + g[j:]
g = sub(g, """PCM5102 PCM5102(
	.clk(clk14),""", """kg_pcm5102 PCM5102(
	.clk(clk14),
	.reset(~clocks_ready),""", "go dac")
g = sub(g, "module karabas_go_top (", "// karabas: MCU part made by src/tools/mktops.py (link v2)\nmodule karabas_go_top (", "go note")

open(os.path.join(RTL, "karabas_mini_top.v"), "w").write(mini)
open(os.path.join(RTL, "karabas_go_top.v"), "w").write(g)
print("mktops.py: karabas_mini_top.v, karabas_go_top.v")
