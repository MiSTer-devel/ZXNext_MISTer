-- Z80 IM2 DEVICE
-- Copyright 2020 Alvin Albrecht
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
-- This module completely handles interrupt logic for zxn peripherals.
-- It also implements "pulsed" interrupt logic so is somewhat specific
-- to the zx spectrum architecture.
--

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;

entity im2_peripheral is
   generic (
      constant VEC_BITS       : positive := 4
   );
   port (
      i_CLK_28                : in std_logic;
      i_CLK_CPU               : in std_logic;
      i_reset                 : in std_logic;
      
      i_m1_n                  : in std_logic;
      i_iorq_n                : in std_logic;
      
      i_mode_pulse_0_im2_1    : in std_logic;    -- select standard pulsed zx mode or im2 vector mode
      
      i_iei                   : in std_logic;    -- im2 daisy chain
      o_ieo                   : out std_logic;   -- im2 daisy chain
      
      i_reti_decode           : in std_logic;    -- reti opcode decode in progress
      i_reti_seen             : in std_logic;    -- reti opcode found
      
      i_int_en                : in std_logic;    -- enable interrupts from this device
      i_int_req               : in std_logic;    -- interrupt request from this device (level active, must not persist through im2_isr_serviced signal)
   
      i_int_status_clear      : in std_logic;    -- clear interrupt status bit if 1 (i_CLK_28)
      o_int_status            : out std_logic;   -- current state of interrupt status bit (i_CLK_28)

      o_int_n                 : out std_logic;   -- active low interrupt signal to z80 if in im2 mode
      o_pulse_en              : out std_logic;   -- active high signal for pulse interrupt, same duration as i_int_req (active regardless of pulse/im2 mode)
   
      i_vector                : in std_logic_vector(VEC_BITS-1 downto 0);
      o_vector                : out std_logic_vector(VEC_BITS-1 downto 0);
      
      i_dma_int_en            : in std_logic;
      o_dma_int               : out std_logic    -- set if dma operation should be interrupted, must qualify with im2 mode
   );
end entity;

architecture rtl of im2_peripheral is
   
   signal im2_reset_n         : std_logic;
   
   signal isr_serviced        : std_logic;
   signal isr_serviced_d      : std_logic;
   signal im2_isr_serviced    : std_logic;
   
   signal int_status          : std_logic;
   signal next_int_status     : std_logic;

   signal im2_int_req         : std_logic;

begin

   im2_reset_n <= i_mode_pulse_0_im2_1 and i_int_en and not i_reset;
   
   -- im2 device logic
   
   im2_logic: entity work.im2_device
   generic map (
      VEC_BITS          => VEC_BITS
   )
   port map (
      i_CLK_CPU         => i_CLK_CPU,
      i_reset_n         => im2_reset_n,
      
      i_m1_n            => i_m1_n,
      i_iorq_n          => i_iorq_n,
      
      i_int_req         => im2_int_req,
      o_int_n           => o_int_n,
      
      i_reti_decode     => i_reti_decode,
      i_reti_seen       => i_reti_seen,
      o_isr_serviced    => isr_serviced,
      
      i_iei             => i_iei,
      o_ieo             => o_ieo,

      i_vec             => i_vector,
      o_vec             => o_vector
   );
      
   process (i_CLK_28)
   begin
      if rising_edge(i_CLK_28) then
         if i_reset = '1' then
            isr_serviced_d <= '0';
         else
            isr_serviced_d <= isr_serviced;
         end if;
      end if;
   end process;
   
   im2_isr_serviced <= isr_serviced and not isr_serviced_d;

   -- interrupt status register
   -- record of whether interrupt occurred, only cleared by write or im2 reset

   next_int_status <= i_int_req or (int_status and (im2_reset_n or not i_int_status_clear) and (not im2_isr_serviced));
   
   process (i_CLK_28)
   begin
      if rising_edge(i_CLK_28) then
         if i_reset = '1' then
            int_status <= '0';
         else
            int_status <= next_int_status;
         end if;
      end if;
   end process;
   
   o_int_status <= int_status;
   
   -- im2 interrupt logic
   
   im2_int_req <= int_status;  -- im2 device is held in reset if interrupt is not enabled
   o_dma_int <= int_status and i_int_en and i_dma_int_en;  -- should be qualified by im2 mode

   -- pulse interrupt logic
   
   o_pulse_en <= i_int_req and i_int_en;

end architecture;
