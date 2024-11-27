
-- ZX Spectrum Next Video Timing Module
--
-- Copyright 2017 superfo, mcleod, avillena (ZX UNO Project) 
-- Copyright 2020 Fabio Belavenuto, Alvin Albrecht
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
--

-- Original pal_sync_generator.v from the ZX UNO project:
-- <https://github.com/yomboprime/zxuno-addons/blob/master/test24_uart/common/pal_sync_generator.v>

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

entity zxula_timing is
   port (
      clock_i        : in  std_logic;
      clock_x4_i     : in  std_logic;
      reset_conter_i : in  std_logic;
      mode_i         : in  std_logic_vector(2 downto 0);
      video_timing_i : in  std_logic_vector(2 downto 0);
      vf50_60_i      : in  std_logic;
      cu_offset_i    : in  std_logic_vector(7 downto 0);
      hcount_o       : out unsigned(8 downto 0);
      vcount_o       : out unsigned(8 downto 0);
      phcount_o      : out unsigned(8 downto 0);
      whcount_o      : out unsigned(8 downto 0);
      wvcount_o      : out unsigned(8 downto 0);
      cvcount_o      : out unsigned(8 downto 0);
      sc_o           : out std_logic_vector(1 downto 0);
      hsync_n_o      : out std_logic;
      vsync_n_o      : out std_logic;
      hblank_n_o     : out std_logic;
      vblank_n_o     : out std_logic;
      lint_ctrl_i    : in  std_logic_vector(1 downto 0);
      lint_line_i    : in  std_logic_vector(8 downto 0);
      ula_int_o      : out std_logic;
      line_int_o     : out std_logic
   );
end entity;

architecture Behavior of zxula_timing is

   signal hc_s                   : unsigned(8 downto 0);
   signal vc_s                   : unsigned(8 downto 0);
   signal phc_s                  : unsigned(8 downto 0);
   signal whc_s                  : unsigned(8 downto 0);
   signal wvc_s                  : unsigned(8 downto 0);
   signal cvc_s                  : unsigned(8 downto 0);
   signal whc_lsb_d              : std_logic;
   signal sc_s                   : std_logic_vector(1 downto 0);
   
   signal max_hc_s               : std_logic;
   signal max_vc_s               : std_logic;
   signal max_cvc_s              : std_logic;
   signal max_whc_s              : std_logic;
   
   signal int_ula_s              : std_logic;
   signal int_lint_s             : std_logic;

   signal c_max_hc_s             : unsigned(8 downto 0);
   signal c_max_vc_s             : unsigned(8 downto 0);
   signal c_vblank_min_s         : unsigned(8 downto 0);
   signal c_vblank_max_s         : unsigned(8 downto 0);
   signal c_hblank_min_s         : unsigned(8 downto 0);
   signal c_hblank_max_s         : unsigned(8 downto 0);
   signal c_vsync_min_s          : unsigned(8 downto 0);
   signal c_vsync_max_s          : unsigned(8 downto 0);
   signal c_hsync_min_s          : unsigned(8 downto 0);
   signal c_hsync_max_s          : unsigned(8 downto 0);
   signal c_int_h_s              : unsigned(8 downto 0);
   signal c_int_v_s              : unsigned(8 downto 0);
   
   signal vblank_top_cancel      : std_logic;
   signal vblank_bottom_cancel   : std_logic;

begin

   --
   process (mode_i, vf50_60_i, video_timing_i)
   begin
      -- Modeline "720x576x50hz"    27       720   732   796   864      576   581   586   625 
      --                                     360   366   398   432      288   290   293   312
      -- ModeLine "720x480@60"      27       720   736   798   858      480   489   495   525 
      --                                     360   368   399   429      240   244   247   262
      if video_timing_i = "111" then
      
         -- HDMI
         
         -- Investigate later.. these numbers were chosen to agree with most hdmi tvs.
         
         if vf50_60_i = '0' then
         
            -- 50 Hz
            
            c_hblank_min_s <= to_unsigned(360-37, 9); -- -37 ok
            c_hsync_min_s  <= to_unsigned(366-37, 9);
            c_hsync_max_s  <= to_unsigned(398-37, 9);
            c_hblank_max_s <= to_unsigned(431-37, 9);
            c_int_h_s      <= to_unsigned(4, 9);
            c_max_hc_s     <= to_unsigned(431, 9);

            c_vblank_min_s <= to_unsigned(248+8-1, 9);-- +8 ok
            c_vsync_min_s  <= to_unsigned(248+8, 9);
            c_vsync_max_s  <= to_unsigned(251+8, 9);
            c_vblank_max_s <= to_unsigned(255+8, 9);
            c_int_v_s      <= to_unsigned(248+8, 9);                                   
            c_max_vc_s     <= to_unsigned(311, 9);
            
         else
         
            -- 60 Hz
            
            c_hblank_min_s <= to_unsigned(360-37, 9); -- -37 ok

            c_hsync_min_s  <= to_unsigned(368-37, 9);
            c_hsync_max_s  <= to_unsigned(399-37, 9);
            c_hblank_max_s <= to_unsigned(428-37, 9);
            c_int_h_s      <= to_unsigned(4, 9);                        
            c_max_hc_s     <= to_unsigned(428, 9);

            c_vblank_min_s <= to_unsigned(240-9-1, 9); -- -9 ok
            c_vsync_min_s  <= to_unsigned(244-9, 9);
            c_vsync_max_s  <= to_unsigned(247-9, 9);
            c_vblank_max_s <= to_unsigned(247-9, 9);
            c_int_v_s      <= to_unsigned(244-9, 9);                                      
            c_max_vc_s     <= to_unsigned(261, 9);
            
         end if;
         
      elsif mode_i = "000" or mode_i = "001" then
      
         -- 48k
         
         c_hblank_min_s <= to_unsigned(320, 9);
         c_hsync_min_s  <= to_unsigned(344, 9);
         c_hsync_max_s  <= to_unsigned(375, 9);
         c_hblank_max_s <= to_unsigned(415, 9);
         c_int_h_s      <= to_unsigned(0, 9);
         c_max_hc_s     <= to_unsigned(447, 9);
         
         if vf50_60_i = '0' then
         
            -- 50 Hz
            
            c_vblank_min_s <= to_unsigned(248-1, 9);
            c_vblank_max_s <= to_unsigned(255, 9);
            c_vsync_min_s  <= to_unsigned(248, 9);
            c_vsync_max_s  <= to_unsigned(251, 9);
            c_int_v_s      <= to_unsigned(248, 9);
            c_max_vc_s     <= to_unsigned(311, 9);
            
         else
         
            -- 60 Hz
            
            c_vblank_min_s <= to_unsigned(224-1, 9);
            c_vsync_min_s  <= to_unsigned(224, 9);
            c_vsync_max_s  <= to_unsigned(227, 9);
            c_vblank_max_s <= to_unsigned(231, 9);
            c_int_v_s      <= to_unsigned(224, 9);
            c_max_vc_s     <= to_unsigned(263, 9);
            
         end if;

      elsif mode_i = "010" or mode_i = "011" then
      
         -- 128k, +3
         
         c_hblank_min_s <= to_unsigned(320, 9);
         c_hsync_min_s  <= to_unsigned(344, 9);
         c_hsync_max_s  <= to_unsigned(375, 9);
         c_hblank_max_s <= to_unsigned(415, 9);
         
         if mode_i = "010" then
         
            -- 128k
            
            c_int_h_s   <= to_unsigned(4, 9);  -- 8
         
         else
         
            -- +3

            c_int_h_s   <= to_unsigned(2, 9);
            
         end if;
         
         c_max_hc_s     <= to_unsigned(455, 9);
         
         if vf50_60_i = '0' then
         
            -- 50 Hz
            
            c_vblank_min_s <= to_unsigned(248-1, 9);
            c_vsync_min_s  <= to_unsigned(248, 9);
            c_vsync_max_s  <= to_unsigned(251, 9);
            c_vblank_max_s <= to_unsigned(255, 9);
            c_int_v_s      <= to_unsigned(248, 9);
            c_max_vc_s     <= to_unsigned(310, 9);
            
         else
         
            -- 60 Hz

            c_vblank_min_s <= to_unsigned(224-1, 9);
            c_vsync_min_s  <= to_unsigned(224, 9);
            c_vsync_max_s  <= to_unsigned(227, 9);
            c_vblank_max_s <= to_unsigned(231, 9);
            c_int_v_s      <= to_unsigned(224, 9);
            c_max_vc_s     <= to_unsigned(263, 9);
            
         end if;     
         
      else
      
         -- Pentagon
      
         c_hblank_min_s <= to_unsigned(336, 9);   -- 336, 320
         c_hsync_min_s  <= to_unsigned(336, 9);   -- 336, 320
         c_hsync_max_s  <= to_unsigned(367, 9);   -- 367, 351
         c_hblank_max_s <= to_unsigned(399, 9);   -- 399, 383
         c_int_h_s      <= to_unsigned(323, 9);   -- 323, 320
         c_max_hc_s     <= to_unsigned(447, 9);   -- 447, 447

         -- There is no 60Hz Pentagon
            
         c_vblank_min_s <= to_unsigned(240-1, 9);
         c_vsync_min_s  <= to_unsigned(240, 9);
         c_vsync_max_s  <= to_unsigned(255, 9);
         c_vblank_max_s <= to_unsigned(256, 9);    -- 271
         c_int_v_s      <= to_unsigned(239, 9);    -- 240, 239
         c_max_vc_s     <= to_unsigned(319, 9);
         
      end if;
      
   end process;
   
   -- Signals generation
   
   vblank_top_cancel <= '1' when vc_s = c_vblank_max_s and hc_s >= c_hblank_min_s else '0';
   vblank_bottom_cancel <= '1' when vc_s = c_vblank_min_s and hc_s < c_hblank_min_s else '0';
   
   process (hc_s, vc_s, c_hblank_min_s, c_hblank_max_s, c_vblank_min_s, c_vblank_max_s,
            c_hsync_min_s, c_hsync_max_s, c_vsync_min_s, c_vsync_max_s, vblank_top_cancel, vblank_bottom_cancel)
   begin
      hblank_n_o  <= '1';
      vblank_n_o  <= '1';
      hsync_n_o   <= '1';
      vsync_n_o   <= '1';

      -- HBlank
      if hc_s >= c_hblank_min_s and hc_s <= c_hblank_max_s then
         hblank_n_o <= '0';
      end if;
      -- VBlank
      if vc_s >= c_vblank_min_s and vc_s <= c_vblank_max_s then
         vblank_n_o <= vblank_top_cancel or vblank_bottom_cancel;
      end if;
      -- HSync
      if hc_s >= c_hsync_min_s and hc_s <= c_hsync_max_s then
         hsync_n_o <= '0';
      end if;
      -- VSync
      if vc_s >= c_vsync_min_s and vc_s <= c_vsync_max_s then
         vsync_n_o <= '0';
      end if;

   end process;

   -- INT pulse generation, lasts one 7MHz period
   
   process (hc_s, vc_s, cvc_s, c_int_v_s, c_int_h_s, max_cvc_s, lint_line_i, lint_ctrl_i)

      variable lint_minus_one_v  : unsigned(8 downto 0);
   begin
   
      int_ula_s <= '0';
      int_lint_s <= '0';
      lint_minus_one_v := unsigned(lint_line_i) - 1;
      
      if lint_ctrl_i(0) = '1' then
         if vc_s = c_int_v_s and hc_s = c_int_h_s then
            int_ula_s <= '1';
         end if;
      end if;
      
      if lint_ctrl_i(1) = '1' and hc_s = 256 then
         if lint_line_i = 0 then
            if max_cvc_s = '1' then
               int_lint_s <= '1';
            end if;
         elsif cvc_s = lint_minus_one_v then
            int_lint_s <= '1';
         end if;
      end if;
      
   end process;
   
   ula_int_o <= int_ula_s;
   line_int_o <= int_lint_s;

   -- Pixel position counters
   
   -- All timing refers to the ULA counter as implemented in the original hardware.
   -- The ULA produces its first pixel in the 256 pixel wide area during count 12.
   
   -- Practical counters are generated for other modules that count the actual pixel
   -- position being generated in the current cycle as well as delivering negative values
   -- leading up to pixel zero.
   
   -- ULA counter, pixel 0 is generated in cycle 12
   
   max_hc_s <= '1' when hc_s = c_max_hc_s else '0';
   
   process (clock_i)
   begin
      if rising_edge(clock_i) then
         if reset_conter_i = '1' then
            hc_s <= (others => '0');
         elsif max_hc_s = '1' then
            hc_s <= (others => '0');
         else
            hc_s <= hc_s + 1;
         end if;
      end if;
   end process;

   max_vc_s <= '1' when vc_s = c_max_vc_s else '0';
   
   process (clock_i)
   begin
      if rising_edge(clock_i) then
         if reset_conter_i = '1' then
            vc_s <= c_vsync_min_s;
         elsif max_hc_s = '1' then
            if max_vc_s = '1' then
               vc_s <= (others => '0');
            else
               vc_s <= vc_s + 1;
            end if;
         end if;
      end if;
   end process;
   
   -- Copper offset vertical counter
   
   max_cvc_s <= '1' when cvc_s = c_max_vc_s else '0';
   
   process (clock_i)
   begin
      if rising_edge(clock_i) then
         if reset_conter_i = '1' then
            cvc_s <= c_vsync_min_s;
         elsif max_hc_s = '1' then
            if max_vc_s = '1' then
               cvc_s <= unsigned('0' & cu_offset_i);
            elsif max_cvc_s = '1' then
               cvc_s <= (others => '0');
            else
               cvc_s <= cvc_s + 1;
            end if;
         end if;
      end if;
   end process;
   
   -- Practical wide counters.  (0,0) corresponds to (-32,-32) for the 320 x 256 surface
   
   max_whc_s <= '1' when hc_s = (c_max_hc_s - 32+12-16) else '0';
   
   process (clock_i)
   begin
      if rising_edge(clock_i) then
         if reset_conter_i = '1' then
            whc_s <= (others => '0');
         elsif max_whc_s = '1' then
            whc_s <= "111110000";      -- starting at -16
         else
            whc_s <= whc_s + 1;
         end if;
      end if;
   end process;
   
   process (clock_i)
   begin
      if rising_edge(clock_i) then
         if reset_conter_i = '1' then
            wvc_s <= to_unsigned(256, 9);
         elsif max_whc_s = '1' then
            if vc_s = (c_max_vc_s - 32-2) then
               wvc_s <= "111111110";   -- starting at -2
            else
               wvc_s <= wvc_s + 1;
            end if;
         end if;
      end if;
   end process;
   
   -- Practical 256 horizontal counter.  0 corresponds to pixel x=0 on the 256 x 192 surface

   process (clock_i)
   begin
      if rising_edge(clock_i) then
         if reset_conter_i = '1' then
            phc_s <= (others => '0');
         elsif max_whc_s = '1' then
            phc_s <= "111010000";      -- starting at -48
         else
            phc_s <= phc_s + 1;
         end if;
      end if;
   end process;
   
   -- 28MHZ sub-pixel counter
   
   process (clock_x4_i)
   begin
      if rising_edge(clock_x4_i) then
         if reset_conter_i = '1' then
            whc_lsb_d <= '0';
         else
            whc_lsb_d <= whc_s(0);
         end if;
      end if;
   end process;
   
   process (clock_x4_i)
   begin
      if rising_edge(clock_x4_i) then
         if reset_conter_i = '1' then
            sc_s <= (others => '0');
         elsif whc_s(0) /= whc_lsb_d then
            sc_s <= "01";
         else
            sc_s <= sc_s + 1;
         end if;
      end if;
   end process;

   --
   
   hcount_o <= hc_s;
   vcount_o <= vc_s;
   
   phcount_o <= phc_s;
   
   whcount_o <= whc_s;
   wvcount_o <= wvc_s;
   cvcount_o <= cvc_s;
   
   sc_o <= sc_s;

end architecture;
