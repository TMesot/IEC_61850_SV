----------------------------------------------------------------------------------
-- Company: 
-- Engineer: CRG
-- 
-- Create Date:    12:08:00 09/03/2013 
-- Design Name: 
-- Module Name:    Pulse_Synchronizer - Behavioral 
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
use IEEE.NUMERIC_STD.ALL;

library UNISIM;
use UNISIM.VComponents.all;

entity Pulse_Sync is
    Port ( CLK1_IN : in  STD_LOGIC;
           CLK2_IN : in  STD_LOGIC;
           SIGNAL0_IN : in  STD_LOGIC;
           SIGNAL0_OUT : out  STD_LOGIC);
end Pulse_Sync;

architecture Behavioral of Pulse_Sync is

signal tFF_D, tFF_Q, tFF_Q_bar : std_logic;
signal q_sync_FF1, q_sync_FF2, q_output_FF : std_logic;

begin

  -- Clock domain 1 (CLK1_IN) logic - tFF_Q toggles each time a pulse is received on SIGNAL0_IN

  MUXF7_inst : MUXF7
    port map (
      O => tFF_D,
      I0 => tFF_Q,
      I1 => tFF_Q_bar,
      S => SIGNAL0_IN
    );

  tFF_Q_bar <= not(tFF_Q);
  FDRE_toggleFF : FDRE generic map (INIT => '0')
    port map (
      Q => tFF_Q,
      C => CLK1_IN,
      CE => '1',
      R => '0',
      D => tFF_D
    );

  -- Clock domain 2 (CLK2_IN) logic - SIGNAL0_OUT is pulsed for one clock cycle of CLK2_IN if tFF_Q changes
  -- Datapath between sync_FF1 and sync_FF2 should be minimized - exists to ensure sync_FF1 exits its metastable
  -- state before next clock edge

  sync_FF1 : FDRE generic map (INIT => '0')
    port map (
      Q => q_sync_FF1,
      C => CLK2_IN,
      CE => '1',
      R => '0',
      D => tFF_Q
    );

  sync_FF2 : FDRE generic map (INIT => '0')
    port map (
      Q => q_sync_FF2,
      C => CLK2_IN,
      CE => '1',
      R => '0',
      D => q_sync_FF1
    );

  output_FF : FDRE generic map (INIT => '0')
    port map (
      Q => q_output_FF,
      C => CLK2_IN,
      CE => '1',
      R => '0',
      D => q_sync_FF2
    );

    SIGNAL0_OUT <= q_sync_FF2 xor q_output_FF;

end Behavioral;