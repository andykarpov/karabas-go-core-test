----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    21:35:50 08/09/2023 
-- Design Name: 
-- Module Name:    karabas_go - Behavioral 
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 
--
-- Dependencies: 
--
-- Revision: 
-- Revision 0.01 - File Created
-- Additional Comments: 
--
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.std_logic_unsigned.all;
use IEEE.numeric_std.all; 

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity karabas_go is
    Port ( CLK_50MHZ : in  STD_LOGIC;
           TAPE_IN : in  STD_LOGIC;
           TAPE_OUT : out  STD_LOGIC;
           BEEPER : out  STD_LOGIC;
           DAC_LRCK : out  STD_LOGIC;
           DAC_DAT : out  STD_LOGIC;
           DAC_BCK : out  STD_LOGIC;
           DAC_MUTE : out  STD_LOGIC;
           ESP_RESET_N : out  STD_LOGIC;
           ESP_BOOT_N : out  STD_LOGIC;
           UART_RX : inout  STD_LOGIC;
           UART_TX : inout  STD_LOGIC;
           UART_CTS : out  STD_LOGIC;
           WA : out  STD_LOGIC_VECTOR (2 downto 0);
           WCS_N : out  STD_LOGIC_VECTOR(1 downto 0);
           WRD_N : out  STD_LOGIC;
           WWR_N : out  STD_LOGIC;
           WRESET_N : out  STD_LOGIC;
           WD : inout  STD_LOGIC_VECTOR (15 downto 0);
           MA : out  STD_LOGIC_VECTOR (20 downto 0);
           MD : inout  STD_LOGIC_VECTOR (15 downto 0);
           MWR_N : out  STD_LOGIC_VECTOR (1 downto 0);
           MRD_N : out  STD_LOGIC_VECTOR (1 downto 0);
           SDR_BA : out  STD_LOGIC_VECTOR (1 downto 0);
           SDR_A : out  STD_LOGIC_VECTOR (12 downto 0);
           SDR_CLK : out  STD_LOGIC;
           SDR_DQM : out  STD_LOGIC_VECTOR (1 downto 0);
           SDR_WE_N : out  STD_LOGIC;
           SDR_CAS_N : out  STD_LOGIC;
           SDR_RAS_N : out  STD_LOGIC;
           SDR_DQ : inout  STD_LOGIC_VECTOR (15 downto 0);
           SD_CS_N : out  STD_LOGIC;
           SD_DI : inout  STD_LOGIC;
           SD_DO : inout  STD_LOGIC;
           SD_CLK : out  STD_LOGIC;
           SD_DET_N : in  STD_LOGIC;
           FDC_INDEX : inout  STD_LOGIC;
           FDC_DRIVE : out  STD_LOGIC_VECTOR (1 downto 0);
           FDC_MOTOR : out  STD_LOGIC;
           FDC_DIR : inout  STD_LOGIC;
           FDC_STEP : inout  STD_LOGIC;
           FDC_WDATA : inout  STD_LOGIC;
           FDC_WGATE : inout  STD_LOGIC;
           FDC_TR00 : inout  STD_LOGIC;
           FDC_WPRT : inout  STD_LOGIC;
           FDC_RDATA : inout  STD_LOGIC;
           FDC_SIDE_N : inout  STD_LOGIC;
           FT_SPI_CS_N : out  STD_LOGIC;
           FT_SPI_SCK : out  STD_LOGIC;
           FT_SPI_MISO : inout  STD_LOGIC;
           FT_SPI_MOSI : inout  STD_LOGIC;
           FT_INT_N : inout  STD_LOGIC;
           FT_CLK : inout  STD_LOGIC;
           FT_OE_N : out  STD_LOGIC;
           VGA_R : out  STD_LOGIC_VECTOR (7 downto 0);
           VGA_G : out  STD_LOGIC_VECTOR (7 downto 0);
           VGA_B : out  STD_LOGIC_VECTOR (7 downto 0);
           VGA_HS : out  STD_LOGIC;
           VGA_VS : out  STD_LOGIC;
           V_CLK : out  STD_LOGIC;
           MCU_CS_N : in  STD_LOGIC;
           MCU_SCK : in  STD_LOGIC;
           MCU_MOSI : inout  STD_LOGIC;
           MCU_MISO : inout  STD_LOGIC);
end karabas_go;

architecture Behavioral of karabas_go is

signal cnt: std_logic_vector(26 downto 0) := (others => '0');
signal led: std_logic := '0';

-- Horizontal Timing constants  
constant h_pixels_across	: integer := 1280 - 1;
constant h_sync_on		: integer := 1344 - 1;
constant h_sync_off		: integer := 1480 - 1;
constant h_end_count		: integer := 1680 - 1;
-- Vertical Timing constants
constant v_pixels_down		: integer := 800 - 1;
constant v_sync_on		: integer := 801 - 1;
constant v_sync_off		: integer := 804 - 1;
constant v_end_count		: integer := 828 - 1;

signal hcnt		: std_logic_vector(11 downto 0) := "000000000000"; 	-- horizontal pixel counter
signal vcnt		: std_logic_vector(11 downto 0) := "000000000000"; 	-- vertical line counter
signal hsync		: std_logic;
signal vsync		: std_logic;
signal blank		: std_logic;
signal shift		: std_logic_vector(7 downto 0);
signal red		: std_logic_vector(7 downto 0);
signal green		: std_logic_vector(7 downto 0);
signal blue		: std_logic_vector(7 downto 0);
signal clk_vga		: std_logic;

  component ODDR2
  port(
          D0	: in std_logic;
          D1	: in std_logic;
          C0	: in std_logic;
          C1	: in std_logic;
          Q	: out std_logic;
          CE    : in std_logic;
          S     : in std_logic;
          R	: in std_logic
    );
  end component;

begin

TAPE_OUT <= '0';
BEEPER <= '0';
DAC_LRCK <= '0';
DAC_BCK <= '0';
DAC_DAT <= '0';
DAC_MUTE <= '1';
ESP_RESET_N <= '1';
ESP_BOOT_N <= '1';
UART_CTS <= '0';
WA <= (others => '1');
WCS_N <= "11";
WRD_N <= '1';
WWR_N <= '1';
WRESET_N <= '1';
MA <= (others => '0');
MWR_N <= "11";
MRD_N <= "11";
SDR_BA <= "00";
SDR_A <= (others => '0');
SDR_CLK <= '0';
SDR_DQM <= "00";
SDR_WE_N <= '1';
SDR_CAS_N <= '1';
SDR_RAS_N <= '1';
SD_CLK <= '1';
FDC_DRIVE <= "00";
FDC_MOTOR <= '0';
FT_SPI_CS_N <= '1';
FT_SPI_SCK <= '0';
FT_OE_N <= '1';
--VGA_R <= (others => '0');
--VGA_G <= (others => '0');
--VGA_B <= (others => '0');
--VGA_HS <= '0';
--VGA_VS <= '0';
--V_CLK <= '0';

process (clk_vga) 
begin 
	if rising_edge(clk_vga) then
		cnt <= cnt + 1;
		if cnt = 0 then 
			led <= not led;
		end if;
	end if;
	SD_CS_N <= led;
end process;

hsync	<= '0' when (hcnt <= h_sync_on) or (hcnt > h_sync_off) else '1';
vsync	<= '0' when (vcnt <= v_sync_on) or (vcnt > v_sync_off) else '1';
blank	<= '1' when (hcnt > h_pixels_across) or (vcnt > v_pixels_down) else '0';

red	<= "11111111" when hcnt = 0 or hcnt = h_pixels_across or vcnt = 0 or vcnt = v_pixels_down else (hcnt(7 downto 0) + shift) and "11111111";
green	<= "11111111" when hcnt = 0 or hcnt = h_pixels_across or vcnt = 0 or vcnt = v_pixels_down else (vcnt(7 downto 0) + shift) and "11111111";
blue	<= "11111111" when hcnt = 0 or hcnt = h_pixels_across or vcnt = 0 or vcnt = v_pixels_down else (hcnt(7 downto 0) + vcnt(7 downto 0) - shift) and "11111111";

pll0_inst: entity work.pll 
port map(
	CLK_IN1 => CLK_50MHZ,
	CLK_OUT1 => clk_vga
);

process (clk_vga, hcnt)
begin
	if clk_vga'event and clk_vga = '1' then
		if hcnt = h_end_count then
			hcnt <= (others => '0');
		else
			hcnt <= hcnt + 1;
		end if;
		if hcnt = h_sync_on then
			if vcnt = v_end_count then
				vcnt <= (others => '0');
				shift <= shift + 1;
			else
				vcnt <= vcnt + 1;
			end if;
		end if;
	end if;
end process;

VGA_R <= red;
VGA_G <= green;
VGA_B <= blue;
VGA_HS <= hsync;
VGA_VS <= vsync;

ODDR2_inst: ODDR2
port map(
	Q => V_CLK,
	C0 => clk_vga,
	C1 => not(clk_vga),
	CE => '1',
	D0 => '1',
	D1 => '0',
	R => '0',
	S => '0'
);

--V_CLK <= clk_vga; -- 83.46 MHz

end Behavioral;

