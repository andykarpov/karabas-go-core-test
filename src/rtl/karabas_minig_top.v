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
-- FPGA Test core for Karabas-Go Mini rev.G
--
-- @author Andy Karpov <andy.karpov@gmail.com>
-- Ukraine, 2023, 2025
------------------------------------------------------------------------------------------------------------------*/

module karabas_minig_top (
   //---------------------------
   input wire CLK_50MHZ,

	//---------------------------
	inout wire UART_RX,
	inout wire UART_TX,
	inout wire UART_CTS,
	
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
	input wire FT_DE,
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

	output wire DAC_BCK,
	output wire DAC_WS,
	output wire DAC_DAT,
	
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
	input wire [5:0] MCU_IO,
	
	//---------------------------
	output wire MIDI_TX,
	
	output wire ESP32_SPI_CS_N,
	input wire ESP32_PCM_BCK,
	input wire ESP32_PCM_RLCK,
	input wire ESP32_PCM_DAT,
	
	//---------------------------
	output wire FLASH_CS_N,
	input wire  FLASH_DO,
	output wire FLASH_DI,
	output wire FLASH_SCK,
	output wire FLASH_WP_N,
	output wire FLASH_HOLD_N	
);

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

//---------- MCU ------------

wire [2:0] ms_b;
wire [7:0] hid_kb_status, hid_kb_data;
wire [15:0] softsw_command;
wire mcu_busy;

mcu mcu(
	.CLK(clk40),
	.N_RESET(~clocks_ready),
	
	.MCU_MOSI(MCU_MOSI),
	.MCU_MISO(MCU_MISO),
	.MCU_SCK(MCU_SCK),
	.MCU_SS(MCU_CS_N),
	
	.MS_X(),
	.MS_Y(),
	.MS_Z(),
	.MS_B(ms_b),
	.MS_UPD(),
	
	.KB_STATUS(hid_kb_status),
	.KB_DAT0(hid_kb_data),
	.KB_DAT1(),
	.KB_DAT2(),
	.KB_DAT3(),
	.KB_DAT4(),
	.KB_DAT5(),
	
	.JOY_L(joy_l),
	.JOY_R(joy_r),
	
	.RTC_A(),
	.RTC_DI(8'b00000000),
	.RTC_DO(),
	.RTC_CS(1'b1),
	.RTC_WR_N(1'b1),
	
	.ROMLOADER_ACTIVE(),
	.ROMLOAD_ADDR(),
	.ROMLOAD_DATA(),
	.ROMLOAD_WR(),
	
	.SOFTSW_COMMAND(softsw_command),	
	.OSD_COMMAND(),
	
	.BUSY(mcu_busy)
);

// -- MZYX CBAS RLDU O Positive Logic
// -- MXYZ SACB RLDU   Negative Logic
assign joy_l_md = {joy_l[12], joy_l[9], joy_l[10], joy_l[11], joy_l[5], joy_l[6], joy_l[8], joy_l[7], joy_l[4:1]}; 
assign joy_r_md = {joy_r[12], joy_r[9], joy_r[10], joy_r[11], joy_r[5], joy_r[6], joy_r[8], joy_r[7], joy_r[4:1]};

//---------- Soft switches ------------

wire kb_reset;

soft_switches soft_switches(
	.CLK(clk40),
	.SOFTSW_COMMAND(softsw_command),
	.RESET(kb_reset)
);

assign master_reset = kb_reset | mcu_busy;


//---------- DAC ------------

wire [15:0] audio_out_l, audio_out_r;

PCM5102 PCM5102(
	.clk(clk40),
	.left(audio_out_l),
	.right(audio_out_r),
	.din(DAC_DAT),
	.bck(DAC_BCK),
	.lrck(DAC_WS)
);

// ------------ HDMI ----------------

wire [9:0] tmds_red, tmds_green, tmds_blue;

hdmi hdmi(
	.I_CLK_PIXEL(clk40),
	.I_R({r_to_vga, 2'b00}),
	.I_G({g_to_vga, 2'b00}),
	.I_B({b_to_vga, 2'b00}),
	.I_BLANK(blank_to_vga),
	.I_HSYNC(hsync_to_vga),
	.I_VSYNC(vsync_to_vga),
	.I_AUDIO_ENABLE(1'b1),
	.I_AUDIO_PCM_L(audio_out_l[15:0]),
	.I_AUDIO_PCM_R(audio_out_r[15:0]),
	.O_RED(tmds_red),
	.O_GREEN(tmds_green),
	.O_BLUE(tmds_blue)
);

hdmi_out_xilinx hdmiio(
	.clock_pixel_i(clk40),
	.clock_tdms_i(clk_hdmi),
	.clock_tdms_n_i(clk_hdmi_n),
	.red_i(tmds_red),
	.green_i(tmds_green),
	.blue_i(tmds_blue),
	.tmds_out_p(TMDS_P),
	.tmds_out_n(TMDS_N)
);	

    assign UART_CTS = 1'b1;
	 assign ESP32_SPI_CS_N = 1'b1;

    assign FT_SPI_CS_N = 1'b1;
    assign FT_SPI_SCK = 1'b1;
    assign FT_SPI_MOSI = 1'b1;
	 assign FT_CLK_OUT = 1'b1;

    assign WA = 3'b0;
    assign WCS_N = 2'b1;
    assign WRD_N = 1'b1;
    assign WWR_N = 1'b1;
    assign WRESET_N = 1'b1;

    assign TAPE_OUT = 1'b0;
	 assign ADC_CLK = 1'b0;
	 assign MIDI_TX = 1'b0;
	 
	assign FLASH_CS_N = 1'b1;
	assign FLASH_DI = 1'b1;
	assign FLASH_SCK = 1'b1;
	assign FLASH_WP_N = 1'b1;
	assign FLASH_HOLD_N = 1'b1;

endmodule
