----------------------------------------------------------------------------------
-- Company: 
-- Engineer: CW
-- 
-- Create Date:    22:32:50 06/05/2012 
-- Design Name: 
-- Module Name:    Eth_Ctrl_v3 - Behavioral 
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

library std;
use std.textio.all;

entity iec_61850_sv is
	Generic (	SV_ID_IN 					: in string := "MU_TEST_SVID");
		Port ( 	CLK_IN 						: in std_logic;

				SOURCE_MAC_IN				: in std_logic_vector(47 downto 0);
				DEST_MAC_2LSB_IN			: in std_logic_vector(15 downto 0);
				PRIORITY_IN 				: in std_logic_vector(2 downto 0);
				VLAN_ID_IN 					: in std_logic_vector(11 downto 0);
				APP_ID_IN					: in std_logic_vector(15 downto 0);

				SAMPLE_ADDR_OUT				: out std_logic_vector(2 downto 0);
				SAMPLE_IN 					: in std_logic_vector(31 downto 0);
				SAMPLE_QUALITY_IN			: in std_logic_vector(31 downto 0);

				SAMPLE_COUNT_IN 			: in std_logic_vector(15 downto 0);
				SAMPLE_SYNC_IN 				: in std_logic_vector(7 downto 0);
				DO_PACKET_SEND_IN 			: in std_logic;

				ETH_TXD_CLK_IN				: in std_logic;
				ETH_TXD_EN_OUT				: out std_logic;
				ETH_TXD_OUT					: out std_logic_vector(1 downto 0));
end iec_61850_sv;

architecture Behavioral of iec_61850_sv is

subtype slv is std_logic_vector;

COMPONENT CRC32_calc2
    Port (  CLOCK               :   in  std_logic;
            RESET               :   in  std_logic;
            DATA                :   in  std_logic_vector(7 downto 0);
            LOAD_INIT           :   in  std_logic;
            CALC                :   in  std_logic;
            D_VALID             :   in  std_logic;
            CRC                 :   out std_logic_vector(7 downto 0);
            CRC_REG             :   out std_logic_vector(31 downto 0);
            CRC_VALID           :   out std_logic);
END COMPONENT;

COMPONENT TDP_RAM
	Generic (	G_DATA_A_SIZE	:natural :=8;
				G_ADDR_A_SIZE	:natural :=9;
				G_RELATION		:natural :=1;
				G_INIT_FILE		:string :="");--log2(SIZE_A/SIZE_B)
   Port ( 	CLK_A_IN 	: in  STD_LOGIC;
         	WE_A_IN 	: in  STD_LOGIC;
          	ADDR_A_IN 	: in  STD_LOGIC_VECTOR (G_ADDR_A_SIZE-1 downto 0);
          	DATA_A_IN	: in  STD_LOGIC_VECTOR (G_DATA_A_SIZE-1 downto 0);
          	DATA_A_OUT	: out  STD_LOGIC_VECTOR (G_DATA_A_SIZE-1 downto 0);
          	CLK_B_IN 	: in  STD_LOGIC;
			WE_B_IN 	: in  STD_LOGIC;
          	ADDR_B_IN 	: in  STD_LOGIC_VECTOR (G_ADDR_A_SIZE+G_RELATION-1 downto 0);
          	DATA_B_IN 	: in  STD_LOGIC_VECTOR (G_DATA_A_SIZE/(2**G_RELATION)-1 downto 0);
          	DATA_B_OUT 	: out STD_LOGIC_VECTOR (G_DATA_A_SIZE/(2**G_RELATION)-1 downto 0));
END COMPONENT;

type MAIN_STATE is (
						IDLE,
						INIT_SEND_IEC_68150_PACKET,
						SEND_FRAME0,
						SEND_FRAME1,
						SEND_FRAME2,
						SEND_FRAME3,
						SEND_FRAME4,
						SEND_FRAME5,
						SEND_FRAME6,
						SEND_FRAME7,
						SEND_FRAME8,
						WAIT_FOR_TRANSMIT_COMPLETE,
						COMPLETE
					);

signal main_st, main_st_next : MAIN_STATE := IDLE;

function to_slv(s: string) return std_logic_vector is 
    constant ss: string(1 to s'length) := s; 
    variable answer: std_logic_vector(1 to 8 * s'length); 
    variable p: integer; 
    variable c: integer; 
begin 
    for i in ss'range loop
        p := 8 * i;
        c := character'pos(ss(i));
        answer(p - 7 to p) := std_logic_vector(to_unsigned(c,8)); 
    end loop; 
    return answer; 
end function;

function write_test(s: string) return integer is
 	constant ss 		: string(1 to s'length) := s;
    variable answer 	: std_logic_vector(1 to 8 * s'length);
    variable c 			: integer; 
 	variable line_slv 	: std_logic_vector(1 to 8);
 	variable line_str 	: string(1 to 16) := "0000000000000000";
 	FILE wr_file 		: text open WRITE_MODE is "XCJA9MN6KJSDAHFG_.coe";
 	variable wr_line 	: line;
 	variable ret 		: integer;
begin
	write(wr_line, string'("0000000001010101"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000001010101"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000001010101"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000001010101"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000001010101"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000001010101"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000001010101"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000011010101"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000001"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000001100"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000011001101"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000100"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000001000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000100000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000100000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000011100000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000011000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000010100000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000010000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000001100000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000010000001"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000101100000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000101000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000010001000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000010111010"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000110100000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000110000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000111100000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000111000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000001100000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0001000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000010000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000001"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000001"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000010100010"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0001000100000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000110000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0001001000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000010000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0001001100000000"));
	writeline(wr_file, wr_line);

	for i in ss'range loop
        c := character'pos(ss(i));
        line_slv := std_logic_vector(to_unsigned(c, 8));
        for j in 1 to 8 loop
            if line_slv(j) = '0' then
                line_str(j+8) := '0';
            else
                line_str(j+8) := '1';
            end if;
        end loop;
		write(wr_line, line_str);
		writeline(wr_file, wr_line);
    end loop; 

	write(wr_line, string'("0000000010000010"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000010"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0001010100000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0001010000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000010000011"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000100"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000001"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000010000101"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000001"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0001011000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000010000111"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000001000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0001101000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0001100100000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0001100000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0001011100000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0001111000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0001110100000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0001110000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0001101100000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0001101000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0001100100000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0001100000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0001011100000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0001111000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0001110100000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0001110000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0001101100000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0001101000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0001100100000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0001100000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0001011100000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0001111000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0001110100000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0001110000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0001101100000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0001101000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0001100100000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0001100000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0001011100000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0001111000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0001110100000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0001110000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0001101100000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0001101000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0001100100000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0001100000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0001011100000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0001111000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0001110100000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0001110000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0001101100000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0001101000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0001100100000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0001100000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0001011100000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0001111000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0001110100000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0001110000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0001101100000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0001101000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0001100100000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0001100000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0001011100000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0001111000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0001110100000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0001110000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0001101100000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0001101000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0001100100000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0001100000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0001011100000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0001111000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0001110100000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0001110000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0001101100000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000100100000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000100100000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000100100000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000100100000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);
	write(wr_line, string'("0000000000000000"));
	writeline(wr_file, wr_line);

    file_close(wr_file);

	return ret;
end function;

constant C_announce_packet_len 				: unsigned(7 downto 0) := to_unsigned((123 + SV_ID_IN'length), 8);
constant C_announce_packet_len_w_crc		: unsigned(7 downto 0) := to_unsigned((127 + SV_ID_IN'length), 8);

constant C_ptp_announce_type 				: std_logic_vector(3 downto 0) := X"b";

signal packet_instruction, tx_packet_data 	: std_logic_vector(7 downto 0) := (others => '0');
signal raw_value 							: std_logic_vector(7 downto 0) := (others => '0');
signal ip_identification 					: std_logic_vector(15 downto 0) := (others => '0');
signal wr_tx_packet 						: std_logic := '0';
signal tx_packet_creation_addr 				: unsigned(7 downto 0) := (others => '0');
signal tx_packet_creation_addr_localized 	: unsigned(8 downto 0) := (others => '0');
signal tx_packet_start_addr 				: std_logic_vector(8 downto 0);
signal tx_packet_creation_data 				: std_logic_vector(15 downto 0) := (others => '0');
signal tx_packet_creation_announce_data 	: std_logic_vector(15 downto 0) := (others => '0');
signal tx_packet_en, trigger_packet_send 	: std_logic := '0';
signal tx_packet_en_managed 				: std_logic := '0';
signal eth_rxd_dv_in_managed 				: std_logic := '0';
signal trigger_packet_send_managed 			: std_logic := '0';
signal trigger_packet_send_managed_prev 	: std_logic := '0';
signal tx_packet_en_p, eth_txd_clk_prev		: std_logic := '0';
signal tx_packet_en_pp, tx_packet_en_ppp	: std_logic := '0';
signal eth_tx_addr 							: unsigned(8 downto 0) := (others => '0');
signal tx_packet_en_sig 					: std_logic := '0';
signal eth_txd 								: std_logic_vector(1 downto 0) := "00";
signal tx_packet_addr_inc 					: std_logic := '0';
signal tx_packet_en_prev 					: std_logic := '0';

signal init_crc_calc, crc_value_valid		: std_logic := '0';
signal crc_calc_en, crc_data_ld				: std_logic := '0';
signal crc_rd_sig 							: std_logic := '0';
signal eth_txd_data 						: std_logic_vector(3 downto 0) := X"0";
signal crc_value 							: std_logic_vector(31 downto 0) := (others => '0');
signal crc_value_msb						: std_logic_vector(7 downto 0) := (others => '0');

signal wr_timestamp_data, eth_buffer_we		: std_logic := '0';
signal wr_timestamp_data_p 					: std_logic := '0';
signal eth_rxd_buf2_we, eth_rxd_buf2_we_ini	: std_logic := '0';
signal new_eth_packet 						: unsigned(4 downto 0) := "00000";
signal eth_buffer_data, rx_timestamp_data 	: std_logic_vector(3 downto 0);
signal rx_timestamp_data_shift 				: std_logic_vector(7 downto 0);
signal time_nsec2_managed	 				: std_logic_vector(31 downto 0);
signal time_sec2_managed	 				: std_logic_vector(47 downto 0);
signal do_packet_send 						: std_logic := '0';

signal sv_id 								: std_logic_vector(1 to (SV_ID_IN'length*8)) := to_slv(SV_ID_IN);
signal sv_id_length 						: std_logic_vector(7 downto 0) := std_logic_vector(to_unsigned(SV_ID_IN'length, 8));
signal total_packet_length					: std_logic_vector(15 downto 0) := std_logic_vector(to_unsigned((SV_ID_IN'length + 98), 16));
signal sav_pdu_length						: std_logic_vector(7 downto 0) := std_logic_vector(to_unsigned((SV_ID_IN'length + 88), 8));
signal seq_asdu_length						: std_logic_vector(7 downto 0) := std_logic_vector(to_unsigned((SV_ID_IN'length + 83), 8));
signal asdu_length 							: std_logic_vector(7 downto 0) := std_logic_vector(to_unsigned((SV_ID_IN'length + 81), 8));

signal sample_addr 							: unsigned(2 downto 0) := "000";

signal i : integer := write_test(SV_ID_IN);

begin

	do_packet_send <= DO_PACKET_SEND_IN;
	SAMPLE_ADDR_OUT <= std_logic_vector(sample_addr);

	process(CLK_IN)
	begin
		if rising_edge(CLK_IN) then
			main_st <= main_st_next;
		end if;
	end process;

	MAIN_STATE_DECODE: process (main_st, do_packet_send, tx_packet_creation_addr, tx_packet_en_managed)
	begin
		main_st_next <= main_st; -- default to remain in same state
		case (main_st) is
			when IDLE =>
				if do_packet_send = '1' then
					main_st_next <= INIT_SEND_IEC_68150_PACKET;
				end if;

			when INIT_SEND_IEC_68150_PACKET => 
				main_st_next <= SEND_FRAME0;

			when SEND_FRAME0 =>
				main_st_next <= SEND_FRAME1;
			when SEND_FRAME1 =>
				main_st_next <= SEND_FRAME2;
			when SEND_FRAME2 =>
				if tx_packet_creation_addr = C_announce_packet_len then
					main_st_next <= SEND_FRAME3;
				else
					main_st_next <= SEND_FRAME1;
				end if;
			when SEND_FRAME3 =>
				main_st_next <= SEND_FRAME4;
			when SEND_FRAME4 =>
				main_st_next <= SEND_FRAME5;
			when SEND_FRAME5 =>
				main_st_next <= SEND_FRAME6;
			when SEND_FRAME6 =>
				main_st_next <= SEND_FRAME7;
			when SEND_FRAME7 =>
				main_st_next <= SEND_FRAME8;
			when SEND_FRAME8 =>
				if tx_packet_en_managed = '1' then
					main_st_next <= WAIT_FOR_TRANSMIT_COMPLETE;
				end if;
			when WAIT_FOR_TRANSMIT_COMPLETE =>
				if tx_packet_en_managed = '0' then
					main_st_next <= COMPLETE;
				end if;

			when COMPLETE =>
				main_st_next <= IDLE;
		end case;
	end process;

	wr_tx_packet <= '1' when main_st = SEND_FRAME2 else crc_rd_sig;
	trigger_packet_send <= '1' when main_st = SEND_FRAME8 else '0';

	TX_PACKET_CREATION: process(CLK_IN)
	begin
		if rising_edge(CLK_IN) then
			if main_st = SEND_FRAME0 then
				tx_packet_creation_addr <= (others => '0');
			elsif main_st = SEND_FRAME2 then
				tx_packet_creation_addr <= tx_packet_creation_addr + 1;
			elsif main_st = SEND_FRAME4 then
				tx_packet_creation_addr <= tx_packet_creation_addr + 1;
			elsif main_st = SEND_FRAME5 then
				tx_packet_creation_addr <= tx_packet_creation_addr + 1;
			elsif main_st = SEND_FRAME6 then
				tx_packet_creation_addr <= tx_packet_creation_addr + 1;
			end if;
			if main_st = SEND_FRAME0 then
				tx_packet_creation_addr_localized <= (others => '0');
			elsif main_st = SEND_FRAME2 then
				tx_packet_creation_addr_localized <= tx_packet_creation_addr_localized + 1;
			elsif main_st = SEND_FRAME4 then
				tx_packet_creation_addr_localized <= tx_packet_creation_addr_localized + 1;
			elsif main_st = SEND_FRAME5 then
				tx_packet_creation_addr_localized <= tx_packet_creation_addr_localized + 1;
			elsif main_st = SEND_FRAME6 then
				tx_packet_creation_addr_localized <= tx_packet_creation_addr_localized + 1;
			end if;	
		end if;
	end process;

	packet_instruction <= tx_packet_creation_data(15 downto 8);
	raw_value <= tx_packet_creation_data(7 downto 0);

	with packet_instruction select
		tx_packet_data <= 	raw_value 										when X"00",
							DEST_MAC_2LSB_IN(7 downto 0) 					when X"01",
							DEST_MAC_2LSB_IN(15 downto 8) 					when X"02",
							SOURCE_MAC_IN(7 downto 0) 						when X"03",
							SOURCE_MAC_IN(15 downto 8) 						when X"04",
							SOURCE_MAC_IN(23 downto 16)						when X"05",
							SOURCE_MAC_IN(31 downto 24)						when X"06",
							SOURCE_MAC_IN(39 downto 32) 					when X"07",
							SOURCE_MAC_IN(47 downto 40) 					when X"08",
							crc_value_msb									when X"09",
							VLAN_ID_IN(7 downto 0) 							when X"0A",
							PRIORITY_IN&'0'&VLAN_ID_IN(11 downto 8) 		when X"0B",
							APP_ID_IN(7 downto 0)							when X"0C",
							APP_ID_IN(15 downto 8)							when X"0D",
							total_packet_length(7 downto 0) 				when X"0E",
							total_packet_length(15 downto 8) 				when X"0F",
							sav_pdu_length 					 				when X"10",
							seq_asdu_length					 				when X"11",
							asdu_length					 					when X"12",
							sv_id_length				 					when X"13",
							SAMPLE_COUNT_IN(7 downto 0) 					when X"14",
							SAMPLE_COUNT_IN(15 downto 8)					when X"15",
							SAMPLE_SYNC_IN									when X"16",
							SAMPLE_IN(7 downto 0) 							when X"17",
							SAMPLE_IN(15 downto 8) 							when X"18",
							SAMPLE_IN(23 downto 16)							when X"19",
							SAMPLE_IN(31 downto 24)							when X"1A",
							SAMPLE_QUALITY_IN(7 downto 0)					when X"1B",
							SAMPLE_QUALITY_IN(15 downto 8) 					when X"1C",
							SAMPLE_QUALITY_IN(23 downto 16)					when X"1D",
							SAMPLE_QUALITY_IN(31 downto 24)					when X"1E",
							X"00" 											when others;

	TX_Instruction_Frame : TDP_RAM
		Generic Map(	G_DATA_A_SIZE  	=> 16,
						G_ADDR_A_SIZE	=> 9,
						G_RELATION		=> 0,
						G_INIT_FILE		=> "XCJA9MN6KJSDAHFG_.coe")

		Port Map ( 		CLK_A_IN 		=> CLK_IN,
						WE_A_IN 		=> '0',
						ADDR_A_IN 		=> slv(tx_packet_creation_addr_localized),
						DATA_A_IN		=> (others => '0'),
						DATA_A_OUT		=> tx_packet_creation_data,
						CLK_B_IN 		=> '0',
						WE_B_IN 		=> '0',
						ADDR_B_IN	 	=> (others => '0'),
						DATA_B_IN 		=> (others => '0'),
						DATA_B_OUT		=> open);

	TX_Frame_Buffer : TDP_RAM
		Generic Map(	G_DATA_A_SIZE  	=> 8,
						G_ADDR_A_SIZE	=> 8,
						G_RELATION		=> 1, 
						G_INIT_FILE		=> "")

		Port Map ( 		CLK_A_IN 		=> CLK_IN,
						WE_A_IN 		=> wr_tx_packet,
						ADDR_A_IN 		=> slv(tx_packet_creation_addr),
						DATA_A_IN		=> tx_packet_data,
						DATA_A_OUT		=> open,
						CLK_B_IN 		=> ETH_TXD_CLK_IN,
						WE_B_IN 		=> '0',
						ADDR_B_IN	 	=> slv(eth_tx_addr),
						DATA_B_IN 		=> (others => '0'),
						DATA_B_OUT		=> eth_txd_data);

	process(CLK_IN)
	begin
		if rising_edge(CLK_IN) then
			if main_st = INIT_SEND_IEC_68150_PACKET then
				sample_addr <= "000";
			elsif main_st = SEND_FRAME1 then
				if packet_instruction = X"1B" then
					sample_addr <= sample_addr + 1;
				end if;
			end if;
		end if;
	end process;

	MANAGE_TX_RX_SIGNALS_ACROSS_CLK_BOUNDARY :process(CLK_IN)
	begin
		if rising_edge(CLK_IN) then
			tx_packet_en_managed <= tx_packet_en;
		end if;
	end process;

	ETH_TXD_EN_OUT <= tx_packet_en_sig;
	ETH_TXD_OUT <= eth_txd;

	SEND_PACKET_PROC :process(ETH_TXD_CLK_IN)
	begin
		if rising_edge(ETH_TXD_CLK_IN) then
			tx_packet_en_ppp <= tx_packet_en_pp;
			tx_packet_en_pp <= tx_packet_en_p;
			tx_packet_en_p <= tx_packet_en;
			trigger_packet_send_managed <= trigger_packet_send;
			trigger_packet_send_managed_prev <= trigger_packet_send_managed;
			if trigger_packet_send_managed = '1' and trigger_packet_send_managed_prev = '0' then
				tx_packet_en <= '1';
			elsif eth_tx_addr = C_announce_packet_len_w_crc&'1' then
				tx_packet_en <= '0';
			end if;
			if tx_packet_en = '1' then
				if tx_packet_addr_inc = '0' then
					eth_tx_addr <= eth_tx_addr + 1;
				end if;
			else
				eth_tx_addr <= (others => '0');
			end if;
			if tx_packet_en = '1' or tx_packet_en_p = '1' then
				tx_packet_addr_inc <= not(tx_packet_addr_inc);
			else
				tx_packet_addr_inc <= '0';
			end if;
			if tx_packet_addr_inc = '1' then
				eth_txd <= eth_txd_data(3 downto 2);
			else
				eth_txd <= eth_txd_data(1 downto 0);
			end if;
			if tx_packet_en = '1' and tx_packet_en_p = '0' then
				tx_packet_en_sig <= '1';
			elsif tx_packet_en_pp = '0' and tx_packet_en_ppp = '1' then
				tx_packet_en_sig <= '0';
			end if;
		end if;
	end process;

	CRC_CALC_PROC : process(CLK_IN)
	begin
		if rising_edge(CLK_IN) then
			if main_st = SEND_FRAME0 then
				crc_calc_en <= '1';
			elsif main_st = SEND_FRAME3 then
				crc_calc_en <= '0';
			end if;
			if main_st = SEND_FRAME0 then
				crc_rd_sig <= '0';
			elsif main_st = SEND_FRAME3 then
				crc_rd_sig <= '1';
			elsif main_st = SEND_FRAME7 then
				crc_rd_sig <= '0';
			end if;
		end if;
	end process;

	crc_data_ld <= wr_tx_packet when tx_packet_creation_addr > X"07" else '0';
	init_crc_calc <= '1' when main_st = SEND_FRAME0 else '0';

	CRC32_calc2_Inst : CRC32_calc2
    Port Map (  CLOCK     => CLK_IN,
	            RESET     => '0',
	            DATA      => tx_packet_data,
	            LOAD_INIT => init_crc_calc,
	            CALC      => crc_calc_en,
	            D_VALID   => crc_data_ld,
	            CRC       => crc_value_msb,
	            CRC_REG   => crc_value,
	            CRC_VALID => crc_value_valid);

end Behavioral;