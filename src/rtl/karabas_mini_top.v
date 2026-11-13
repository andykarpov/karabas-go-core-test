`timescale 1ns / 1ps
`default_nettype none

/*-------------------------------------------------------------------------------------------------------------------
-- 
-- 
-- #       #######                                                 #                                               
-- #                                                               #                                               
-- #                                                               #                                               
-- ############### ############### ############### ############### ############### ############### ############### 
-- #             #               # #                             # #             #               # #               
-- #             # ############### #               ############### #             # ############### ############### 
-- #             # #             # #               #             # #             # #             #               # 
-- #             # ############### #               ############### ############### ############### ############### 
--                                                                                                                 
--         ####### ####### ####### #######                                         ############### ############### 
--                                                                                 #               #             # 
--                                                                                 #   ########### #             # 
--                                                                                 #             # #             # 
-- https://github.com/andykarpov/karabas-go                                        ############### ############### 
--
-- FPGA Test core for Karabas-Go Mini
--
-- @author Andy Karpov <andy.karpov@gmail.com>
-- Ukraine, 2023, 2025
------------------------------------------------------------------------------------------------------------------*/

module karabas_mini_top (
   //---------------------------
   input wire CLK_50MHZ,

	//---------------------------
	inout wire UART_RX,
	inout wire UART_TX,
	inout wire UART_CTS,
	inout wire ESP_RESET_N,
	inout wire ESP_BOOT_N,
	
   //---------------------------
   output wire [20:0] MA,
   inout wire [15:0] MD,
   output wire [1:0] MWR_N,
   output wire [1:0] MRD_N,

   //---------------------------
	output wire [1:0] SDR_BA,
	output wire [12:0] SDR_A,
	output wire SDR_CLK,
	output wire [1:0] SDR_DQM,
	output wire SDR_WE_N,
	output wire SDR_CAS_N,
	output wire SDR_RAS_N,
	inout wire [15:0] SDR_DQ,

   //---------------------------
   output wire SD_CS_N,
   output wire SD_CLK,
   output wire SD_DI,
   input wire SD_DO,
	input wire SD_DET_N,

   //---------------------------
   input wire [7:0] VGA_R,
   input wire [7:0] VGA_G,
   input wire [7:0] VGA_B,
   input wire VGA_HS,
   input wire VGA_VS,
	
   output wire [3:0] TMDS_P,
   output wire [3:0] TMDS_N,	
	
	//---------------------------
	output wire FT_SPI_CS_N,
	output wire FT_SPI_SCK,
	input wire FT_SPI_MISO,
	output wire FT_SPI_MOSI,
	input wire FT_INT_N,
	input wire FT_CLK,
	input wire FT_AUDIO,
	input wire FT_DE,
	input wire FT_DISP,
	output wire FT_RESET,
	output wire FT_CLK_OUT,

	//---------------------------
	output wire [2:0] WA,
	output wire [1:0] WCS_N,
	output wire WRD_N,
	output wire WWR_N,
	output wire WRESET_N,
	inout wire [15:0] WD,
	
   //---------------------------	
	output wire TAPE_OUT,
	input wire TAPE_IN,
	output wire AUDIO_L,
	output wire AUDIO_R,
	
	//---------------------------
	output wire ADC_CLK,
   inout wire ADC_BCK,
	inout wire ADC_LRCK,
   input wire ADC_DOUT,
	
	//---------------------------
	input wire MCU_CS_N,
	input wire MCU_SCK,
	inout wire MCU_MOSI,
	output wire MCU_MISO,	
	inout wire [3:0] MCU_IO,   // [1] INT of link v2, [2] sd2 cs_n, [3] ft cs_n
	
	//---------------------------
	output wire MIDI_TX,
	output wire MIDI_CLK,
	output wire MIDI_RESET_N,
	
	//---------------------------
	output wire FLASH_CS_N,
	input wire  FLASH_DO,
	output wire FLASH_DI,
	output wire FLASH_SCK,
	output wire FLASH_WP_N,
	output wire FLASH_HOLD_N	
);
// karabas: made by src/tools/mktops.py from karabas_minig_top.v (do not edit it, change Mini G)

   wire [5:0] r_to_vga, g_to_vga, b_to_vga;
   wire hsync_to_vga, vsync_to_vga, blank_to_vga;
   
   wire memtest_init_fast, memtest_init_slow, memtest_progress, memtest_result;
   wire sdtest_init, sdtest_progress, sdtest_result;
   wire flashtest_init, flashtest_progress, flashtest_result;
   wire sdramtest_init, sdramtest_progress, sdramtest_result;
   wire hidetextwindow;
   
   wire [7:0] earcode;
   wire [2:0] mousebutton;  // M R L
   wire mousetest_init;
   
   wire [15:0] flash_vendor_id;
   
   wire master_reset;

	wire [12:0] joy_l; // -- MXYZ SACB RLDU
	wire [12:0] joy_r;  // -- MXYZ SACB RLDU
	
	wire [11:0] joy_l_md, joy_r_md;
   
   wire clk100, clk14, clk7, clk40;
   wire clocks_ready;
   
   relojes los_relojes (
    .CLK_IN1(CLK_50MHZ),
    .CLK_OUT1(clk100),
    .CLK_OUT2(clk14),
    .CLK_OUT3(clk7),
	 .CLK_OUT4(clk40),
    .locked(clocks_ready)
    );
	 
	 wire clk_hdmi, clk_hdmi_n, lockedx5;
	 
	 pllx5 pllx5(
		.CLK_IN1(clk40),
		.CLK_OUT1(clk_hdmi),
		.CLK_OUT2(clk_hdmi_n),
		.LOCKED(lockedx5)
	);

   wire [56:0] dna;

   get_dna dna_fpga (
      .clk(clk40),
      .dna(dna)
   );

   switch_mode teclas (
      .clk(clk40),

      .kbd_status(hid_kb_status),
      .kbd_data(hid_kb_data),

      .memtestf(memtest_init_fast),
      .memtests(memtest_init_slow),
      .sdtest(sdtest_init),
      .flashtest(flashtest_init),
      .mousetest(mousetest_init),
      .sdramtests(sdramtest_init),
      .hidetextwindow(hidetextwindow),
      .master_reset()
   );

ramtest16b test_de_ram (
      .clk(clk40),
      .hold(~clocks_ready),
      .rstf(memtest_init_fast),
      .rsts(memtest_init_slow),
      .sram_a(MA),
      .sram_d(MD),
      .sram_we_n(MWR_N),
      .sram_rd_n(MRD_N),
      .test_in_progress(memtest_progress),
      .test_result(memtest_result)
   );

   sdtest test_slot_sd (
      .clk(clk40),
      .rst(sdtest_init),
      .spi_clk(SD_CLK),
      .spi_di(SD_DI),
      .spi_do(SD_DO),
      .spi_cs(SD_CS_N),
      .test_in_progress(sdtest_progress),
      .test_result(sdtest_result)
   );

   wire flash_clk, flash_mosi, flash_miso, flash_cs_n; // todo

   flashtest test_spi_flash (
      .clk(clk40),
      .rst(flashtest_init),
      .spi_clk(flash_clk),
      .spi_di(flash_mosi),
      .spi_do(flash_miso),
      .spi_cs(flash_cs_n),
      .test_in_progress(flashtest_progress),
      .test_result(flashtest_result),
      .vendor_code_hex(flash_vendor_id)
   );

   eartest test_ear (
      .clk(clk40),
      .ear(~TAPE_IN),
      .vs(vsync_to_vga),
      .code(earcode)
   );

   assign mousebutton = ms_b;

  sdramtest test_sdram (
    .clk(clk40),
    .rst(sdramtest_init),
    .pll_locked(clocks_ready),
    .test_in_progress(sdramtest_progress),
    .test_result(sdramtest_result),
    .sdram_clk(SDR_CLK),          // seales validas en flanco de suida de CK
    .sdram_cke(),
    .sdram_dqmh_n(SDR_DQM[1]),      // mascara para byte alto o bajo
    .sdram_dqml_n(SDR_DQM[0]),      // durante operaciones de escritura
    .sdram_addr(SDR_A), // pag.14. row=[12:0], col=[8:0]. A10=1 significa precharge all.
    .sdram_ba(SDR_BA),    // banco al que se accede
    .sdram_cs_n(),
    .sdram_we_n(SDR_WE_N),
    .sdram_ras_n(SDR_RAS_N),
    .sdram_cas_n(SDR_CAS_N),
    .sdram_dq(SDR_DQ)    
   );

   wire [11:0] hcnt_ext, vcnt_ext;

   updater mensajes (
     .clk(clk40),
     
     .dna(dna),
     .memtest_progress(memtest_progress),
     .memtest_result(memtest_result),
     .joystick1(8'b00000000),
     .joystick2(8'b00000000),
	  .joy1md(joy_l_md), // -- MXYZ SACB RLDU  Negative Logic
	  .joy2md(joy_r_md), // -- MXYZ SACB RLDU  Negative Logic
     .earcode(earcode),
     .sdtest_progress(sdtest_progress),
     .sdtest_result(sdtest_result),
     .flashtest_progress(flashtest_progress),
     .flashtest_result(flashtest_result),
     .flash_vendor_id(flash_vendor_id),
     .sdramtest_progress(sdramtest_progress),
     .sdramtest_result(sdramtest_result),
     .mousebutton(mousebutton),
     .hidetextwindow(hidetextwindow),
     
     .r(r_to_vga),
     .g(g_to_vga),
     .b(b_to_vga),
     .hsync(hsync_to_vga),
     .vsync(vsync_to_vga),
	  .blank(blank_to_vga),
	  .hcnt(hcnt_ext),
	  .vcnt(vcnt_ext)
     );
   
   audio_test audio (
      .clk(clk40),
      .left(audio_out_l),
      .right(audio_out_r),
      .led()
   );

//---------- MCU: link v2 (karabas-go-firmware docs/link_v2.md, kg_mcu2); INT on IO1 ------------

wire [7:0] ms_b8;
wire [2:0] ms_b = ms_b8[2:0];
wire [55:0] hid_kbd;
wire [7:0] hid_kb_status = hid_kbd[7:0], hid_kb_data = hid_kbd[15:8];
wire [15:0] joy_l16, joy_r16;
assign joy_l = joy_l16[12:0];
assign joy_r = joy_r16[12:0];
wire [7:0] sw;
wire mcu_busy;
wire dvi_only;
wire osd_wr, osd_en, osd_zoom;
wire [11:0] osd_waddr;
wire [7:0] osd_wdata;
wire [23:0] osd_fg, osd_bg;
wire [1:0] osd_alpha, osd_place;
wire [4:0] osd_px, osd_ph;
wire [3:0] osd_py;
wire [5:0] osd_pw;

wire mcu_sck_ibufg, mcu_sck;
IBUFG ibufg_mcu_sck (.I(MCU_SCK), .O(mcu_sck_ibufg));
BUFG bufg_mcu_sck (.I(mcu_sck_ibufg), .O(mcu_sck));
wire mcu_int;
assign MCU_IO[1] = mcu_int;
assign MCU_IO[0] = 1'bz;
assign MCU_IO[3:2] = 2'bzz;

kg_mcu2 #(
	.SW_N(1),
	.CS_FILTER(3),
	.ENABLE_OSD(1),
	.ENABLE_FT(0),
	.ENABLE_SD2(0)      // the second SD slot is tested by the core (sdtest)
) mcu (
	.CLK(clk40),
	.N_RESET(clocks_ready),

	.MCU_SCK(mcu_sck),
	.MCU_MOSI(MCU_MOSI),
	.MCU_MISO(MCU_MISO),
	.MCU_SS(MCU_CS_N),
	.MCU_INT(mcu_int),
	.MCU_SPI_FT_SS(1'b1),
	.MCU_SPI_SD2_SS(1'b1),

	.SW(sw), .SW_WR(), .SW_INDEX(), .SW_VALUE(), .HW_ID(), .DVI_ONLY(dvi_only), .CORE_BUILD(), .FW_BUILD(),
	.BUSY(mcu_busy), .BTNS(), .RELOAD_REQ(1'b0), .RELOAD_CORE(8'd0),

	.KBD(hid_kbd), .KBD_WR(), .PS2_CODE(), .PS2_KIND(), .PS2_WR(),
	.MS_X(), .MS_Y(), .MS_Z(), .MS_B(ms_b8), .MS_WR(),
	.JOY_L(joy_l16), .JOY_R(joy_r16), .JOY_WR(),
	.PS2_CMD(16'h0000), .PS2_CMD_WR(1'b0),

	.LD_KIND(), .LD_SLOT(), .LD_SIZE(), .LD_START(), .LD_ACTIVE(), .LD_END(),
	.LD_ADDR(), .LD_DATA(), .LD_WR(), .LD_READY(1'b1),

	.OSD_WR(osd_wr), .OSD_WADDR(osd_waddr), .OSD_WDATA(osd_wdata), .OSD_EN(osd_en),
	.OSD_FG(osd_fg), .OSD_BG(osd_bg), .OSD_ALPHA(osd_alpha), .OSD_PX(osd_px), .OSD_PY(osd_py),
	.OSD_PW(osd_pw), .OSD_PH(osd_ph), .OSD_PLACE(osd_place), .OSD_ZOOM(osd_zoom),

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


//---------- DAC ------------

wire [15:0] audio_out_l, audio_out_r;

// Mini has no I2S DAC: sigma-delta outputs into an RC filter, offset binary input
kg_sigma_delta_dac dac_l(.clk(clk40), .reset(~clocks_ready), .din({ ~audio_out_l[15], audio_out_l[14:0] }), .dout(AUDIO_L));
kg_sigma_delta_dac dac_r(.clk(clk40), .reset(~clocks_ready), .din({ ~audio_out_r[15], audio_out_r[14:0] }), .dout(AUDIO_R));

// ------------ OSD, HDMI ----------------

// the bitmap OSD of link v2 (kg_l2_osd_overlay): centred in de, 2 clocks of latency with its syncs
wire [23:0] osd_rgb;
wire osd_hs, osd_vs, osd_de;
kg_l2_osd_overlay osd (
	.wclk(clk40),
	.osd_wr(osd_wr), .osd_waddr(osd_waddr), .osd_wdata(osd_wdata), .osd_en(osd_en),
	.osd_fg(osd_fg), .osd_bg(osd_bg), .osd_alpha(osd_alpha), .osd_px(osd_px), .osd_py(osd_py),
	.osd_pw(osd_pw), .osd_ph(osd_ph), .osd_place(osd_place), .osd_zoom(osd_zoom),
	.icon_on(8'd0), .icon_act(8'd0),
	.clk(clk40),
	.rgb_i({r_to_vga, 2'b00, g_to_vga, 2'b00, b_to_vga, 2'b00}),
	.hs_i(hsync_to_vga), .vs_i(vsync_to_vga), .de_i(~blank_to_vga),
	.rgb_o(osd_rgb), .hs_o(osd_hs), .vs_o(osd_vs), .de_o(osd_de)
);

// hdmi_tx of modules (zhdmi): the audio at 48 kHz of clk40 (+ 6 per clock, modulo 5000)
reg [12:0] aud_acc = 13'd0;
reg aud_stb = 1'b0;
always @(posedge clk40) begin
	aud_stb <= 1'b0;
	if (aud_acc >= 13'd5000 - 13'd6) begin
		aud_acc <= aud_acc + 13'd6 - 13'd5000;
		aud_stb <= 1'b1;
	end
	else
		aud_acc <= aud_acc + 13'd6;
end

hdmi_tx #(.SAMPLE_FREQ(48000), .INPUT_REG(1)) hdmi (
	.clk(clk40),
	.sclk(clk_hdmi),
	.sclk_n(clk_hdmi_n),
	.reset(~lockedx5),
	.rgb(osd_rgb),
	.vsync(osd_vs),
	.hsync(osd_hs),
	.de(osd_de),
	.audio_en(~dvi_only),
	.audio_l({audio_out_l, 8'd0}),
	.audio_r({audio_out_r, 8'd0}),
	.audio_clk(aud_stb),
	.tx_clk_n(TMDS_N[3]),
	.tx_clk_p(TMDS_P[3]),
	.tx_d_n(TMDS_N[2:0]),
	.tx_d_p(TMDS_P[2:0])
);

// the clock of the FT812: 40 / 5 = 8 MHz (2 high, 3 low), it must always have one
// (karabas-go-notes ft-clk-out-required)
reg [2:0] ft_div = 3'd0;
always @(posedge clk40) ft_div <= (ft_div == 3'd4) ? 3'd0 : ft_div + 3'd1;
reg ft_clk = 1'b0;
always @(posedge clk40) ft_clk <= ft_div < 3'd2;
assign FT_CLK_OUT = ft_clk;

    assign UART_CTS = 1'b1;
    assign ESP_RESET_N = 1'bZ;
    assign ESP_BOOT_N = 1'bZ;

    assign FT_SPI_CS_N = 1'b1;
    assign FT_SPI_SCK = 1'b1;
    assign FT_SPI_MOSI = 1'b1;
	 assign FT_RESET = 1'b1;

    assign WA = 3'b0;
    assign WCS_N = 2'b1;
    assign WRD_N = 1'b1;
    assign WWR_N = 1'b1;
    assign WRESET_N = 1'b1;

    assign TAPE_OUT = 1'b0;
	 assign ADC_CLK = 1'b0;
	 assign MIDI_TX = 1'b0;
	 assign MIDI_CLK = 1'b0;
	 assign MIDI_RESET_N = 1'b1;
	 
	assign FLASH_CS_N = 1'b1;
	assign FLASH_DI = 1'b1;
	assign FLASH_SCK = 1'b1;
	assign FLASH_WP_N = 1'b1;
	assign FLASH_HOLD_N = 1'b1;

endmodule
