
-- ZX Spectrum Next Issue 2 FPGA Top Level
-- Copyright 2020 Alvin Albrecht and Fabio Belavenuto
--
-- TBBLUE Issue 2 Top - Fabio Belavenuto
-- ZXNext Refactor - Alvin Albrecht
--
-- This file is part of the ZX Spectrum Next Project
-- <https://gitlab.com/SpectrumNext/ZX_Spectrum_Next_FPGA/tree/master/cores>
--
-- The ZX Spectrum Next FPGA source code is free software: you can 
-- redistribute it and/or modify it under the terms of the GNU General 
-- Public License as published by the Free Software Foundation, either 
-- version 3 of the License, or (at your option) any later version.
--
-- The ZX Spectrum Next FPGA source code is distributed in the hope 
-- that it will be useful, but WITHOUT ANY WARRANTY; without even the 
-- implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR 
-- PURPOSE.  See the GNU General Public License for more details.
--
-- You should have received a copy of the GNU General Public License
-- along with the ZX Spectrum Next FPGA source code.  If not, see 
-- <https://www.gnu.org/licenses/>.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;

entity zxnext_top is
   generic (
      --g_machine_id      : unsigned(7 downto 0)  := X"0A";
		g_video_def       : unsigned(2 downto 0)  := "000";
      g_version         : unsigned(7 downto 0)  := X"32";   
      g_sub_version     : unsigned(7 downto 0)  := X"00";
	   --g_board_issue     : unsigned(3 downto 0)  := X"2";
	   g_video_inc       : unsigned(1 downto 0)  := "10"   
   );
   port (
        g_machine_id      : in unsigned(7 downto 0);   --Debug option
		g_board_issue     : in unsigned(3 downto 0);   --Debug option
		-- Clocks
		CLK_28            : in  std_logic;
		CLK_14            : in  std_logic;
		CLK_7             : in  std_logic;
		
		HW_RESET          : in  std_logic;
		SW_RESET          : in  std_logic;

		CPU_SPEED         : out std_logic_vector(1 downto 0);
		CPU_SPEED_SW      : in  std_logic := '0';
		CPU_WAIT          : in  std_logic := '0';

		RAM_A_ADDR        : out std_logic_vector(20 downto 0);   -- 2MB memory space
		RAM_A_REQ         : out std_logic;                       -- '1' indicates memory request on next rising edge
		RAM_A_RD_n        : out std_logic;                       -- '0' for read, '1' for write
		RAM_A_DI          : in  std_logic_vector(7 downto 0);     -- data read from memory
		RAM_A_DO          : out std_logic_vector(7 downto 0);    -- data written to memory

		RAM_B_ADDR        : out std_logic_vector(20 downto 0);   -- 2MB memory space
		RAM_B_REQ         : out std_logic;                       -- toggle indicates memory request
		RAM_B_DI          : in  std_logic_vector(7 downto 0);     -- data read from memory

		-- PS2
		ps2_key           : in  std_logic_vector(10 downto 0);
		ps2_mouse         : in  std_logic_vector(24 downto 0);
		ps2_mouse_ext     : in  std_logic_vector(7 downto 0);

		-- SD Card
		sd_cs0_n_o        : out std_logic;
		sd_cs1_n_o        : out std_logic;
		sd_sclk_o         : out std_logic;
		sd_mosi_o         : out std_logic;
		sd_miso_i         : in  std_logic := '1';

		-- Joystick
		joy_left          : in  std_logic_vector(11 downto 0); -- active high  X Z Y START A C B U D L R
		joy_right         : in  std_logic_vector(11 downto 0); -- active high  X Z Y START A C B U D L R

		-- Audio
		audio_L           : out std_logic_vector(11 downto 0);
		audio_R           : out std_logic_vector(11 downto 0);

		-- K7
		ear_port_i        : in  std_logic := '1';
		mic_port_o        : out std_logic;

		-- VGA
		RGB               : out std_logic_vector(8 downto 0);    -- RGB333
		RGB_VS_n          : out std_logic;                       -- vsync
		RGB_HS_n          : out std_logic;                       -- hsync
		RGB_VB_n          : out std_logic;                       -- vblank
		RGB_HB_n          : out std_logic;                       -- hblank
		RGB_NTSC          : out std_logic;

		-- I2C (RTC)
		i2c_scl_o         : out std_logic;
		i2c_sda_o         : out std_logic;
		i2c_sda_i         : in  std_logic := '1';

		uart_rx_i         : in  std_logic;
		uart_tx_o         : out std_logic
		
	);
end entity;

architecture rtl of zxnext_top is

   -- resets
   
   signal zxn_video_mode         : std_logic_vector(2 downto 0);
   signal actual_video_mode      : std_logic_vector(2 downto 0)   := "000";

   signal reset_counter          : std_logic_vector(9 downto 0);
   signal reset                  : std_logic;
   
   signal zxn_reset_hard         : std_logic;
   signal zxn_reset_soft         : std_logic;
   
   -- clocks
   
   signal CLK_i0                 : std_logic;
   signal CLK_CPU                : std_logic;
   signal q0                     : std_logic;
   signal q0_enable              : std_logic;
   signal q1                     : std_logic;
   signal q1_enable              : std_logic;
   
   signal clk_28_div             : std_logic_vector(17 downto 0);
   
   signal CLK_28_PSG_EN          : std_logic;
   signal CLK_28_JOY_EN          : std_logic;
   signal CLK_28_MEMBRANE_EN     : std_logic;
   
   signal zxn_clock_contend      : std_logic;
   signal zxn_clock_lsb          : std_logic;
   signal zxn_cpu_speed          : std_logic_vector(1 downto 0);
   signal zxn_cpu_speed2         : std_logic_vector(1 downto 0);

   -- serial communication
   
   signal zxn_i2c_scl            : std_logic;

   -- audio
   
   signal zxn_audio_L_pre        : std_logic_vector(12 downto 0);
   signal zxn_audio_R_pre        : std_logic_vector(12 downto 0);
   
   -- buttons, joystick, mouse, keyboard
   
   signal zxn_joy_io_mode_en     : std_logic;
   signal zxn_joy_io_mode_pin_7  : std_logic;
   
   signal zxn_joy_left_type      : std_logic_vector(2 downto 0);
   signal zxn_joy_right_type     : std_logic_vector(2 downto 0);

   signal zxn_mouse_control      : std_logic_vector(2 downto 0);
   signal zxn_mouse_x            : std_logic_vector(7 downto 0);
   signal zxn_mouse_y            : std_logic_vector(7 downto 0);
   signal zxn_mouse_wheel        : std_logic_vector(7 downto 0);
   signal zxn_mouse_button       : std_logic_vector(2 downto 0);
   signal zxn_mouse_stb          : std_logic;
   
   signal ps2_kbd_col            : std_logic_vector(6 downto 0);
   signal ps2_kbd_fn             : std_logic_vector(11 downto 1);

   signal zxn_keymap_addr        : std_logic_vector(8 downto 0);
   signal zxn_keymap_dat         : std_logic_vector(7 downto 0);
   signal zxn_keymap_we          : std_logic;
   signal zxn_joymap_we          : std_logic;
   
   signal zxn_key_row            : std_logic_vector(7 downto 0);
   signal zxn_key_col            : std_logic_vector(4 downto 0);
   
   signal zxn_cancel_extended_entries  : std_logic;
   signal zxn_extended_keys      : std_logic_vector(15 downto 0);
   
   signal membrane_index         : std_logic_vector(2 downto 0);
   signal membrane_stick_col     : std_logic_vector(6 downto 0);
   
	function mouse_scale(off : std_logic_vector(7 downto 0); scale : std_logic_vector(1 downto 0)) return std_logic_vector is
	begin
		-- avoid -1 value if negative off is less than scale
		case(scale) is
			when "00" =>
				return off;
				
			when "01" =>
				if off <= X"FE" then
					return off(7) & off(7 downto 1);
				end if;
			
			when "10" =>
				if off <= X"FC" then
					return off(7) & off(7) & off(7 downto 2);
				end if;

			when "11" =>
				if off <= X"F8" then
					return off(7) & off(7) & off(7) & off(7 downto 3);
				end if;
		end case;

		return (others => '0');
	end function;

begin

   ------------------------------------------------------------
   -- RESETS --------------------------------------------------
   ------------------------------------------------------------

   process (CLK_28)
   begin
      if rising_edge(CLK_28) then
         if zxn_video_mode /= actual_video_mode or (zxn_reset_soft or zxn_reset_hard or SW_RESET) = '1' then
            actual_video_mode <= zxn_video_mode;
            reset_counter <= (others => '1');
				reset <= '1';
         elsif reset_counter /= "0000000000" then
            reset_counter <= reset_counter - 1;
			else
				reset <= '0';
         end if;
      end if;
   end process;
   
   ------------------------------------------------------------
   -- CLOCKS --------------------------------------------------
   ------------------------------------------------------------
   
	CPU_SPEED <= zxn_cpu_speed2;

   -- cpu clock selection
	process (CLK_28)
	begin
		if rising_edge(CLK_28) then
			case(zxn_cpu_speed2) is
				when "00"   =>
					if clk_28_div(1 downto 0) = "00" then
						if zxn_clock_lsb = '1' and zxn_clock_contend = '0' then
							CLK_i0 <= '0';
						elsif zxn_clock_lsb = '0' then
							CLK_i0 <= '1';
						end if;
					end if;

				when "01"   =>
					CLK_i0 <= clk_28_div(1);

				when others =>
					CLK_i0 <= clk_28_div(0);
			end case;
			
			if clk_28_div(1 downto 0) = "11" then
				zxn_cpu_speed2 <= zxn_cpu_speed;
			end if;
		end if;
	end process;
	
   process(q1, CLK_i0)
   begin
       if (q1 = '1') then
           q0_enable <= '0';
       elsif falling_edge(CLK_i0) then
           q0_enable <= '1';
       end if;
   end process;
   
   process(q0, CLK_28)
   begin
       if (q0 = '1') then
           q1_enable <= '0';
       elsif falling_edge(CLK_28) then
           q1_enable <= '1';
       end if;
   end process;

   q0 <= not (zxn_cpu_speed(1) and zxn_cpu_speed(0)) and q0_enable when rising_edge(CLK_i0);
   q1 <=     (zxn_cpu_speed(1) and zxn_cpu_speed(0)) and q1_enable when rising_edge(CLK_28);

   CLK_CPU <= CLK_i0 when q0 = '1' else CLK_28 when q1 = '1' else '1';

   -- Clock Enables
   clk_28_div <= clk_28_div + 1 when rising_edge(CLK_28);
   
   CLK_28_PSG_EN <= '1' when clk_28_div(3 downto 0) = "1110" else '0';                   -- AY clock enable @ 1.75MHz
   CLK_28_JOY_EN <= '1' when clk_28_div(6 downto 0) = ("111" & X"F") else '0';           -- stick step every 4.57us (pulse width = 9.14us for each side)
   CLK_28_MEMBRANE_EN <= '1' when clk_28_div(8 downto 7) = "11" and CLK_28_JOY_EN = '1' else '0';  -- complete scan every 2.5 scanlines (0.018ms per row)
   
   ------------------------------------------------------------
   -- BUTTONS, JOYSTICKS, MOUSE, KEYBOARD ---------------------
   ------------------------------------------------------------

   -- ps2 mouse
	
   process (CLK_28)
   begin
      if rising_edge(CLK_28) then

			zxn_mouse_stb <= ps2_mouse(24);
			if (zxn_mouse_stb xor ps2_mouse(24)) = '1' then
				zxn_mouse_x    <= zxn_mouse_x + mouse_scale(ps2_mouse(15 downto 8), zxn_mouse_control(1 downto 0));
				zxn_mouse_y    <= zxn_mouse_y + mouse_scale(ps2_mouse(23 downto 16), zxn_mouse_control(1 downto 0));
				zxn_mouse_wheel<= zxn_mouse_wheel + ps2_mouse_ext;
			end if;

			if zxn_mouse_control(2) = '0' then
				zxn_mouse_button <= ps2_mouse(2 downto 0);
			else
				zxn_mouse_button <= (ps2_mouse(2) & ps2_mouse(0) & ps2_mouse(1));
			end if;

      end if;
   end process;

   -- ps2 keyboard

   ps2_kbd_mod : entity work.ps2_keyb
   port map
   (
      i_CLK             => CLK_28,
      i_reset           => reset,

		ps2_key           => ps2_key,

      -- membrane interaction
      i_membrane_row    => membrane_index,
      o_membrane_col    => ps2_kbd_col,

      -- programmable keymap
      i_keymap_addr     => zxn_keymap_addr,
      i_keymap_data     => zxn_keymap_dat,
      i_keymap_we       => zxn_keymap_we,

      fn                => ps2_kbd_fn   -- F11:F1
   );

   -- membrane keyboard
   
   membrane_mod : entity work.membrane
   port map
   (
      i_CLK             => CLK_28,
      i_CLK_EN          => CLK_28_MEMBRANE_EN,
      
      i_reset           => reset,
      
      i_rows            => zxn_key_row,
      o_cols            => zxn_key_col,
      
      o_membrane_ridx   => membrane_index,
      i_membrane_cols   => membrane_stick_col and ps2_kbd_col,
      
      i_cancel_extended_entries => zxn_cancel_extended_entries,
      o_extended_keys => zxn_extended_keys
   );
   
   -- membrane joystick
   
   membrane_stick_mod : entity work.membrane_stick
   port map
   (
      i_CLK             => CLK_28,
      i_CLK_EN          => CLK_28_MEMBRANE_EN,

      i_reset           => reset,

      i_joy_en_n        => zxn_joy_io_mode_en,

      i_joy_left        => joy_left,
      i_joy_left_type   => zxn_joy_left_type,

      i_joy_right       => joy_right,
      i_joy_right_type  => zxn_joy_right_type,

      i_membrane_row    => membrane_index,
      o_membrane_col    => membrane_stick_col,

      i_keymap_addr     => zxn_keymap_addr(4 downto 0),
      i_keymap_data     => zxn_keymap_dat(5 downto 0),
      i_keymap_we       => zxn_joymap_we
   );

   ------------------------------------------------------------
   -- SERIAL COMMUNICATION ------------------------------------
   ------------------------------------------------------------

   -- i2c
   
   i2c_scl_o <= zxn_i2c_scl;

   ------------------------------------------------------------
   -- TBBLUE / ZXNEXT -----------------------------------------
   ------------------------------------------------------------

   --  F1 = hard reset
   --  F2 = 
   --  F3 = toggle 50Hz / 60Hz display
   --  F4 = soft reset
   --  F5 = 
   --  F6 = 
   --  F7 = 
   --  F8 = change cpu speed
   --  F9 = m1 button (multiface nmi)
   -- F10 = drive button (divmmc nmi)

   zxnext : entity work.zxnext
   generic map
   (
      --g_machine_id         => g_machine_id,
		g_video_def				=> g_video_def,
      g_version            => g_version,
      g_sub_version        => g_sub_version,
	  --g_board_issue        => g_board_issue,
		g_video_inc				=> g_video_inc
   )
   port map
   (
	  g_machine_id         => g_machine_id,    --Debug option
	  g_board_issue        => g_board_issue,   --Degub option
      -- CLOCK
      
      i_CLK_28             => CLK_28,
      i_CLK_28_n           => not CLK_28,
      i_CLK_14             => CLK_14,
      i_CLK_7              => CLK_7,
      i_CLK_CPU            => CLK_CPU,
      i_CLK_PSG_EN         => CLK_28_PSG_EN,
      
      o_CPU_SPEED          => zxn_cpu_speed,
      o_CPU_CONTEND        => zxn_clock_contend,
      o_CPU_CLK_LSB        => zxn_clock_lsb,
      i_CPU_WAIT           => CPU_WAIT,
      
      -- RESET

      i_RESET              => reset,
      i_BOOT               => ps2_kbd_fn(1) or HW_RESET,
      
      o_RESET_HARD         => zxn_reset_hard,
      o_RESET_SOFT         => zxn_reset_soft,
      
      -- SPECIAL KEYS

      i_SPKEY_FUNCTION     => ps2_kbd_fn(10) & ps2_kbd_fn(9) & (ps2_kbd_fn(8) or CPU_SPEED_SW) & "000" & (ps2_kbd_fn(4) or ps2_kbd_fn(1) or HW_RESET) & ps2_kbd_fn(3) & "00",
      i_SPKEY_BUTTONS      => ps2_kbd_fn(10) & ps2_kbd_fn(9),
      
      -- MEMBRANE KEYBOARD
      
      o_KBD_CANCEL         => zxn_cancel_extended_entries,
      o_KBD_ROW            => zxn_key_row,
      i_KBD_COL            => zxn_key_col,
      i_KBD_EXTENDED_KEYS  => zxn_extended_keys,
      
      -- PS/2 KEYBOARD AND KEY JOYSTICK SETUP
      
      o_KEYMAP_ADDR        => zxn_keymap_addr,
      o_KEYMAP_DATA        => zxn_keymap_dat,
      o_KEYMAP_WE          => zxn_keymap_we,
      o_JOYMAP_WE          => zxn_joymap_we,
      
      -- JOYSTICK
      
      i_JOY_LEFT           => joy_left,
      i_JOY_RIGHT          => joy_right,
      o_JOY_IO_MODE_EN     => zxn_joy_io_mode_en,
      o_JOY_LEFT_TYPE      => zxn_joy_left_type,
      o_JOY_RIGHT_TYPE     => zxn_joy_right_type,
      
      -- MOUSE
      
      i_MOUSE_X            => zxn_mouse_x,
      i_MOUSE_Y            => zxn_mouse_y,
      i_MOUSE_BUTTON       => zxn_mouse_button,
      i_MOUSE_WHEEL        => zxn_mouse_wheel(3 downto 0),
      o_MOUSE_CONTROL      => zxn_mouse_control,
      
      -- I2C
      
      i_I2C_SCL_n          => zxn_i2c_scl,
      i_I2C_SDA_n          => i2c_sda_i,
      o_I2C_SCL_n          => zxn_i2c_scl,
      o_I2C_SDA_n          => i2c_sda_o,
      
      -- SPI

      o_SPI_SS_SD1_n       => sd_cs1_n_o,
      o_SPI_SS_SD0_n       => sd_cs0_n_o,
      o_SPI_SCK            => sd_sclk_o,
      o_SPI_MOSI           => sd_mosi_o,
      i_SPI_SD_MISO        => sd_miso_i,
      i_SPI_FLASH_MISO     => '1',
      
      -- UART
      
      i_UART0_RX           => uart_rx_i,
      o_UART0_TX           => uart_tx_o,
	  i_UART0_CTS_n        => '0',
      o_UART0_RTR_n        => open,

      
      -- VIDEO
      -- synchronized to i_CLK_14
      
      o_RGB                => RGB,
      o_RGB_VS_n           => RGB_VS_n,
      o_RGB_HS_n           => RGB_HS_n,
      o_RGB_VB_n           => RGB_VB_n,
      o_RGB_HB_n           => RGB_HB_n,
      o_VIDEO_MODE         => zxn_video_mode,
		o_VIDEO_50_60        => RGB_NTSC,
      
      -- AUDIO
      
      i_AUDIO_EAR          => ear_port_i,
      o_AUDIO_MIC          => mic_port_o,
      o_AUDIO_L            => zxn_audio_L_pre,
      o_AUDIO_R            => zxn_audio_R_pre,

      -- EXTERNAL SRAM (synchronized to i_CLK_28)
      -- memory transactions complete in one cycle, data read is registered but available asap
      
		o_RAM_A_ADDR         => RAM_A_ADDR,
		o_RAM_A_REQ          => RAM_A_REQ,
		o_RAM_A_RD_n         => RAM_A_RD_n,
		i_RAM_A_DI           => RAM_A_DI,
		o_RAM_A_DO           => RAM_A_DO,
		o_RAM_B_ADDR         => RAM_B_ADDR,
		o_RAM_B_REQ_T        => RAM_B_REQ,
		i_RAM_B_DI           => RAM_B_DI,
      
      -- EXPANSION BUS
      
      i_BUS_DI             => (others => '1'),
      i_BUS_WAIT_n         => '1',
      i_BUS_NMI_n          => '1',
      i_BUS_INT_n          => '1',
      i_BUS_BUSREQ_n       => '1',
      i_BUS_ROMCS_n        => '1',
      i_BUS_IORQULA_n      => '1',
      
      -- ESP GPIO

      i_ESP_GPIO_20        => (others => '1'),
      o_ESP_GPIO_0         => open,
      o_ESP_GPIO_0_EN      => open,

      -- PI GPIO

      i_GPIO               => (others => '1'),
      o_GPIO               => open,
      o_GPIO_EN            => open
   );

   audio_L <= (others => '1') when zxn_audio_L_pre(12) = '1' else zxn_audio_L_pre(11 downto 0);
   audio_R <= (others => '1') when zxn_audio_R_pre(12) = '1' else zxn_audio_R_pre(11 downto 0);
	

--	g_machine_id <= X"0A" when machine = '1' else g_machine_id <=X"DA";
-- g_board_issue <= X"0" when issue = '1' else X"2";
end architecture;
