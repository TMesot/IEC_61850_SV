--------------------------------------------------------------------------------
-- Company: 
-- Engineer:
--
-- Create Date:   14:53:36 06/15/2015
-- Design Name:   
-- Module Name:   /home/craig/Documents/Projects/Git_Repos/private/FPGA_X4/TB_timestamp_diff_calc.vhd
-- Project Name:  ReducedNIMI_XC6S75
-- Target Device:  
-- Tool versions:  
-- Description:   
-- 
-- VHDL Test Bench Created by ISE for module: timestamp_diff_calc
-- 
-- Dependencies:
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
--
-- Notes: 
-- This testbench has been automatically generated using types std_logic and
-- std_logic_vector for the ports of the unit under test.  Xilinx recommends
-- that these types always be used for the top-level I/O of a design in order
-- to guarantee that the testbench will bind correctly to the post-implementation 
-- simulation model.
--------------------------------------------------------------------------------
LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
 
-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--USE ieee.numeric_std.ALL;
 
ENTITY TB_timestamp_diff_calc IS
END TB_timestamp_diff_calc;
 
ARCHITECTURE behavior OF TB_timestamp_diff_calc IS 
 
    -- Component Declaration for the Unit Under Test (UUT)
 
    COMPONENT timestamp_diff_calc
    PORT(
         CLK_IN : IN  std_logic;
         OPER_SEC_LD_IN : IN  std_logic;
         OPER1_SEC_IN : IN  std_logic_vector(7 downto 0);
         OPER2_SEC_IN : IN  std_logic_vector(7 downto 0);
         OPER_NSEC_LD_IN : IN  std_logic;
         OPER1_NSEC_IN : IN  std_logic_vector(7 downto 0);
         OPER2_NSEC_IN : IN  std_logic_vector(7 downto 0);
         PERFORM_DIFF_IN : IN  std_logic;
         SEC_RESULT_OUT : OUT  std_logic_vector(47 downto 0);
         NSEC_RESULT_OUT : OUT  std_logic_vector(31 downto 0);
         DIFF_CALCD_OUT : OUT  std_logic
        );
    END COMPONENT;
    

   --Inputs
   signal CLK_IN : std_logic := '0';
   signal OPER_SEC_LD_IN : std_logic := '0';
   signal OPER1_SEC_IN : std_logic_vector(7 downto 0) := (others => '0');
   signal OPER2_SEC_IN : std_logic_vector(7 downto 0) := (others => '0');
   signal OPER_NSEC_LD_IN : std_logic := '0';
   signal OPER1_NSEC_IN : std_logic_vector(7 downto 0) := (others => '0');
   signal OPER2_NSEC_IN : std_logic_vector(7 downto 0) := (others => '0');
   signal PERFORM_DIFF_IN : std_logic := '0';

 	--Outputs
   signal SEC_RESULT_OUT : std_logic_vector(47 downto 0);
   signal NSEC_RESULT_OUT : std_logic_vector(31 downto 0);
   signal DIFF_CALCD_OUT : std_logic;

   -- Clock period definitions
   constant CLK_IN_period : time := 10 ns;
 
BEGIN
 
	-- Instantiate the Unit Under Test (UUT)
   uut: timestamp_diff_calc PORT MAP (
          CLK_IN => CLK_IN,
          OPER_SEC_LD_IN => OPER_SEC_LD_IN,
          OPER1_SEC_IN => OPER1_SEC_IN,
          OPER2_SEC_IN => OPER2_SEC_IN,
          OPER_NSEC_LD_IN => OPER_NSEC_LD_IN,
          OPER1_NSEC_IN => OPER1_NSEC_IN,
          OPER2_NSEC_IN => OPER2_NSEC_IN,
          PERFORM_DIFF_IN => PERFORM_DIFF_IN,
          SEC_RESULT_OUT => SEC_RESULT_OUT,
          NSEC_RESULT_OUT => NSEC_RESULT_OUT,
          DIFF_CALCD_OUT => DIFF_CALCD_OUT
        );

   -- Clock process definitions
   CLK_IN_process :process
   begin
		CLK_IN <= '0';
		wait for CLK_IN_period/2;
		CLK_IN <= '1';
		wait for CLK_IN_period/2;
   end process;
 

   -- Stimulus process
   stim_proc: process
   begin		

        wait for 100 ns;
        wait for CLK_IN_period*10;
		
        OPER_SEC_LD_IN <= '1';
        OPER1_SEC_IN <= X"00";
        OPER2_SEC_IN <= X"00";
        wait for CLK_IN_period;
        OPER1_SEC_IN <= X"00";
        OPER2_SEC_IN <= X"00";
        wait for CLK_IN_period;
        OPER1_SEC_IN <= X"55";
        OPER2_SEC_IN <= X"51";
        wait for CLK_IN_period;
        OPER1_SEC_IN <= X"7E";
        OPER2_SEC_IN <= X"5E";
        wait for CLK_IN_period;
        OPER1_SEC_IN <= X"5E";
        OPER2_SEC_IN <= X"7E";
        wait for CLK_IN_period;
        OPER1_SEC_IN <= X"E8";
        OPER2_SEC_IN <= X"E8";
        wait for CLK_IN_period;
        OPER_SEC_LD_IN <= '0';

        wait for CLK_IN_period;

        OPER_NSEC_LD_IN <= '1';
        OPER1_NSEC_IN <= X"55";
        OPER2_NSEC_IN <= X"05";
        wait for CLK_IN_period;
        OPER1_NSEC_IN <= X"7E";
        OPER2_NSEC_IN <= X"4E";
        wait for CLK_IN_period;
        OPER1_NSEC_IN <= X"5E";
        OPER2_NSEC_IN <= X"2E";
        wait for CLK_IN_period;
        OPER1_NSEC_IN <= X"E8";
        OPER2_NSEC_IN <= X"08";
        wait for CLK_IN_period;
        OPER_NSEC_LD_IN <= '0';

        wait for CLK_IN_period;

        PERFORM_DIFF_IN <= '1';
        wait for CLK_IN_period;
        PERFORM_DIFF_IN <= '0';
		  
		  wait for CLK_IN_period * 100;

		  OPER_SEC_LD_IN <= '1';
        OPER1_SEC_IN <= X"00";
        OPER2_SEC_IN <= X"00";
        wait for CLK_IN_period;
        OPER1_SEC_IN <= X"00";
        OPER2_SEC_IN <= X"00";
        wait for CLK_IN_period;
        OPER1_SEC_IN <= X"05";
        OPER2_SEC_IN <= X"51";
        wait for CLK_IN_period;
        OPER1_SEC_IN <= X"7E";
        OPER2_SEC_IN <= X"5E";
        wait for CLK_IN_period;
        OPER1_SEC_IN <= X"5E";
        OPER2_SEC_IN <= X"7E";
        wait for CLK_IN_period;
        OPER1_SEC_IN <= X"E8";
        OPER2_SEC_IN <= X"E8";
        wait for CLK_IN_period;
        OPER_SEC_LD_IN <= '0';

        wait for CLK_IN_period;

        OPER_NSEC_LD_IN <= '1';
		  
        OPER1_NSEC_IN <= X"05";
		  OPER2_NSEC_IN <= X"55";
        wait for CLK_IN_period;
		  OPER1_NSEC_IN <= X"4E";
        OPER2_NSEC_IN <= X"7E";
        wait for CLK_IN_period;
		  OPER1_NSEC_IN <= X"2E";
        OPER2_NSEC_IN <= X"5E";
        wait for CLK_IN_period;
		  OPER1_NSEC_IN <= X"08";
        OPER2_NSEC_IN <= X"E8";
        wait for CLK_IN_period;
        OPER_NSEC_LD_IN <= '0';

        wait for CLK_IN_period;

        PERFORM_DIFF_IN <= '1';
        wait for CLK_IN_period;
        PERFORM_DIFF_IN <= '0';
		  
		    wait for CLK_IN_period * 100;

		    OPER_SEC_LD_IN <= '1';
        OPER1_SEC_IN <= X"FF";
        OPER2_SEC_IN <= X"00";
        wait for CLK_IN_period;
        OPER1_SEC_IN <= X"FF";
        OPER2_SEC_IN <= X"00";
        wait for CLK_IN_period;
        OPER1_SEC_IN <= X"B4";
        OPER2_SEC_IN <= X"51";
        wait for CLK_IN_period;
        OPER1_SEC_IN <= X"1F";
        OPER2_SEC_IN <= X"5E";
        wait for CLK_IN_period;
        OPER1_SEC_IN <= X"DF";
        OPER2_SEC_IN <= X"7E";
        wait for CLK_IN_period;
        OPER1_SEC_IN <= X"FF";
        OPER2_SEC_IN <= X"E8";
        wait for CLK_IN_period;
        OPER_SEC_LD_IN <= '0';

        wait for CLK_IN_period;

        OPER_NSEC_LD_IN <= '1';
		  
        OPER1_NSEC_IN <= X"05";
		    OPER2_NSEC_IN <= X"55";
        wait for CLK_IN_period;
		    OPER1_NSEC_IN <= X"4E";
        OPER2_NSEC_IN <= X"7E";
        wait for CLK_IN_period;
		    OPER1_NSEC_IN <= X"2E";
        OPER2_NSEC_IN <= X"5E";
        wait for CLK_IN_period;
		    OPER1_NSEC_IN <= X"08";
        OPER2_NSEC_IN <= X"E8";
        wait for CLK_IN_period;
        OPER_NSEC_LD_IN <= '0';

        wait for CLK_IN_period;

        PERFORM_DIFF_IN <= '1';
        wait for CLK_IN_period;
        PERFORM_DIFF_IN <= '0';

        wait for CLK_IN_period * 100;

        OPER_SEC_LD_IN <= '1';
        OPER1_SEC_IN <= X"FF";
        OPER2_SEC_IN <= X"00";
        wait for CLK_IN_period;
        OPER1_SEC_IN <= X"FF";
        OPER2_SEC_IN <= X"00";
        wait for CLK_IN_period;
        OPER1_SEC_IN <= X"B4";
        OPER2_SEC_IN <= X"51";
        wait for CLK_IN_period;
        OPER1_SEC_IN <= X"1F";
        OPER2_SEC_IN <= X"5E";
        wait for CLK_IN_period;
        OPER1_SEC_IN <= X"DF";
        OPER2_SEC_IN <= X"7E";
        wait for CLK_IN_period;
        OPER1_SEC_IN <= X"FF";
        OPER2_SEC_IN <= X"E8";
        wait for CLK_IN_period;
        OPER_SEC_LD_IN <= '0';

        wait for CLK_IN_period;

        OPER_NSEC_LD_IN <= '1';
      
        OPER1_NSEC_IN <= X"35";
        OPER2_NSEC_IN <= X"35";
        wait for CLK_IN_period;
        OPER1_NSEC_IN <= X"7E";
        OPER2_NSEC_IN <= X"7E";
        wait for CLK_IN_period;
        OPER1_NSEC_IN <= X"5E";
        OPER2_NSEC_IN <= X"5E";
        wait for CLK_IN_period;
        OPER1_NSEC_IN <= X"E8";
        OPER2_NSEC_IN <= X"E8";
        wait for CLK_IN_period;
        OPER_NSEC_LD_IN <= '0';

        wait for CLK_IN_period;

        PERFORM_DIFF_IN <= '1';
        wait for CLK_IN_period;
        PERFORM_DIFF_IN <= '0';

        wait for CLK_IN_period * 100;

        OPER_SEC_LD_IN <= '1';
        OPER2_SEC_IN <= X"FF";
        OPER1_SEC_IN <= X"00";
        wait for CLK_IN_period;
        OPER2_SEC_IN <= X"FF";
        OPER1_SEC_IN <= X"00";
        wait for CLK_IN_period;
        OPER2_SEC_IN <= X"B4";
        OPER1_SEC_IN <= X"51";
        wait for CLK_IN_period;
        OPER2_SEC_IN <= X"1F";
        OPER1_SEC_IN <= X"5E";
        wait for CLK_IN_period;
        OPER2_SEC_IN <= X"DF";
        OPER1_SEC_IN <= X"7E";
        wait for CLK_IN_period;
        OPER2_SEC_IN <= X"FF";
        OPER1_SEC_IN <= X"E8";
        wait for CLK_IN_period;
        OPER_SEC_LD_IN <= '0';

        wait for CLK_IN_period;

        OPER_NSEC_LD_IN <= '1';
      
        OPER1_NSEC_IN <= X"35";
        OPER2_NSEC_IN <= X"35";
        wait for CLK_IN_period;
        OPER1_NSEC_IN <= X"7E";
        OPER2_NSEC_IN <= X"7E";
        wait for CLK_IN_period;
        OPER1_NSEC_IN <= X"5E";
        OPER2_NSEC_IN <= X"5E";
        wait for CLK_IN_period;
        OPER1_NSEC_IN <= X"E8";
        OPER2_NSEC_IN <= X"E8";
        wait for CLK_IN_period;
        OPER_NSEC_LD_IN <= '0';

        wait for CLK_IN_period;

        PERFORM_DIFF_IN <= '1';
        wait for CLK_IN_period;
        PERFORM_DIFF_IN <= '0';

      wait;
   end process;

END;
