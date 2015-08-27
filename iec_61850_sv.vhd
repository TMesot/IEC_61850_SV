----------------------------------------------------------------------------------
-- Company: SDO
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
--------------------------------------------------------------------------------------
-- 								Latency Calculations								--
--------------------------------------------------------------------------------------
-- Total Latency – Sync Pulse		
--
-- Write packet to buffer:	(16 + (86 * 2)) Packet Nibbles * (1/25 MHZ)		7520 ns
-- Packet veracity check:	266 CLK cycles * (1/57.6 MHZ)					4618 ns
--																	----------------
--																	Total:	12138 ns
--------------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity iec_61850_sv is
	Port ( 	CLK_IN 						: in std_logic;

			IP_ADDR_IN 					: in std_logic_vector(31 downto 0);
			MAC_IN 						: in std_logic_vector(47 downto 0);

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
						INIT_SEND_ANNOUNCE_PACKET,
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

constant C_ip_header_packet_length_addr : std_logic_vector(7 downto 0) := X"0E";
constant C_delay_req_packet_len 		: unsigned(7 downto 0) := X"5D";
constant C_delay_req_packet_len_w_crc	: unsigned(7 downto 0) := X"61";	

constant C_announce_packet_len 			: unsigned(7 downto 0) := X"71";
constant C_announce_packet_len_w_crc	: unsigned(7 downto 0) := X"75";

constant C_delay_resp_packet_len 		: unsigned(7 downto 0) := X"67";
constant C_delay_resp_packet_len_w_crc 	: unsigned(7 downto 0) := X"6B";

--constant C_delay_req_packet_len 		: unsigned(7 downto 0) := X"43"; -- Test
--constant C_delay_req_packet_len_w_crc	: unsigned(7 downto 0) := X"48"; -- Test

constant C_ptp_sync_type 		: std_logic_vector(3 downto 0) := X"0";
constant C_ptp_follow_up_type 	: std_logic_vector(3 downto 0) := X"8";
constant C_ptp_delay_req_type	: std_logic_vector(3 downto 0) := X"1";
constant C_ptp_delay_resp_type	: std_logic_vector(3 downto 0) := X"9";
constant C_ptp_announce_type 	: std_logic_vector(3 downto 0) := X"b";

constant C_sync_packet_start_addr 		: std_logic_vector(8 downto 0) := '0'&X"00";
constant C_delay_resp_packet_start_addr : std_logic_vector(8 downto 0) := '0'&X"62";
constant C_announce_packet_start_addr 	: std_logic_vector(8 downto 0) := '0'&X"CE";

signal eth_rxd_dv_p, eth_rxd_dv_pp							: std_logic := '0';
signal eth_rxd_dv_ppp										: std_logic := '0';
signal new_eth_packet_detected								: std_logic := '0';
signal eth_rxd_addr_buf1 									: unsigned(10 downto 0) := (others => '0');
signal eth_rxd_addr_buf2 									: unsigned(10 downto 0) := (others => '0');
signal packet_start_addr 									: unsigned(10 downto 0) := (others => '0');
signal bm_addr												: unsigned(9 downto 0) := "00"&X"00";
signal bm_data												: std_logic_vector(7 downto 0) := X"00";
signal new_packet_received 									: std_logic := '0';
signal new_packet_received_prev 							: std_logic := '0';
signal preamble_octets 										: unsigned(3 downto 0) := X"0";
signal frame_wr_addr										: unsigned(7 downto 0) := X"00";
signal frame_we												: std_logic := '0';
signal eth_rxd_data_buf1 									: std_logic_vector(3 downto 0) := X"0";
signal eth_rxd_data_in 										: std_logic_vector(1 downto 0) := "00";
signal eth_crs_in_p, eth_crs_in_pp, eth_crs_async_occurred 	: std_logic := '0';
signal eth_crs_async_occurred_managed	 					: std_logic := '0';
signal packet_arrival_timestamp_offset_addr 				: unsigned(7 downto 0) := X"38";
signal eth_crs_async_occurred_flag0 						: std_logic := '0'; 
signal eth_crs_async_occurred_flag1 						: std_logic := '0';

signal packet_veracity_addr 				: unsigned(7 downto 0) := X"00";
signal packet_veracity_ram_addr 			: unsigned(4 downto 0) := (others => '0');
signal packet_veracity_data 				: std_logic_vector(9 downto 0) := "00"&X"00";
signal packet_veracity_data_lower 			: std_logic_vector(7 downto 0) := X"00";
signal packet_veracity_data_cmd 			: std_logic_vector(1 downto 0) := "00";
signal packet_data 							: std_logic_vector(7 downto 0) := X"00";
signal packet_veracity_error_sig 			: std_logic := '0';
signal packet_complete, checksum_error_sig 	: std_logic := '0';
signal new_timestamp_received_sig 			: std_logic := '0';

signal header_length 			: std_logic_vector(7 downto 0) := X"00";
signal upd_packet_start_addr 	: unsigned(7 downto 0) := X"00";
signal two_opt_data 			: std_logic_vector(7 downto 0) := X"40"; -- allow ports 319 or 320
signal udp_packet_length 		: unsigned(15 downto 0);
signal udp_checksum 			: std_logic_vector(15 downto 0);

signal checksum_calc_en 					: std_logic := '0';
signal checksum_set_init_en, checksum_done 	: std_logic := '0';
signal checksum_start_addr, checksum_count 	: std_logic_vector(7 downto 0) := X"00";
signal checksum_addr, frame_rd_addr 		: std_logic_vector(7 downto 0) := X"00";
signal checksum_initial_val 				: unsigned(15 downto 0) := X"0000";
signal checksum, checksum_inv 				: std_logic_vector(15 downto 0);
signal doing_checksum 						: std_logic := '0';
signal source_addr_msb, source_addr_lsb 	: std_logic_vector(15 downto 0);
signal dest_ip_lsb 							: std_logic_vector(7 downto 0) := X"81";
signal checksum_final 						: unsigned(15 downto 0);
signal debug_reg 							: std_logic_vector(7 downto 0);
signal debug_reg2, debug_reg4 				: unsigned(7 downto 0) := X"00";
signal debug_reg3 							: unsigned(7 downto 0);

signal ptp_message_type 				: std_logic_vector(3 downto 0);
signal ptp_message_type_send 			: std_logic_vector(7 downto 0) := X"80";
signal ptp_flags_send, ptp_port_send	: std_logic_vector(7 downto 0);
signal ptp_version 						: std_logic_vector(7 downto 0);
signal ptp_message_length, ptp_flags 	: std_logic_vector(15 downto 0);
signal sequenceID 						: std_logic_vector(15 downto 0);
signal sequenceID_sync_packet 			: unsigned(15 downto 0) := (others => '0');
signal sequenceID_announce_packet		: unsigned(15 downto 0) := (others => '0');
signal originTimestamp_sec 				: std_logic_vector(47 downto 0) := (others => '0');
signal originTimestamp_nsec 			: std_logic_vector(31 downto 0) := (others => '0');
signal ptp_sync_one_step_rec 			: std_logic := '0';
signal ptp_sync_two_step_rec 			: std_logic := '0';
signal ptp_origin_timestamp_rec 		: std_logic := '0';

signal time_nsec, time_nsec_intra 						: unsigned(29 downto 0) := (others => '0');
signal clk_in_set_intra_clock_registers 				: std_logic := '0';
signal clk_100mhz_set_intra_clock_registers 			: std_logic := '0';
signal clk_in_set_intra_clock_registers_prev 			: std_logic := '0';
signal get_time, get_time_cmplt, dec_one_sec_required 	: std_logic := '0';
signal get_time_oh_st 									: std_logic_vector(15 downto 0) := (others => '0');
signal time_sec2, time_sec_intra2						: std_logic_vector(47 downto 0) := (others => '0');
signal time_nsec2, time_nsec_intra2 					: std_logic_vector(29 downto 0) := (others => '0');
signal clk_in_set_intra_clock_registers2 				: std_logic := '0';
signal clk_100mhz_set_intra_clock_registers2 			: std_logic := '0';
signal clk_in_set_intra_clock_registers_prev2 			: std_logic := '0';
signal get_time2, do_intra_clock_set2					: std_logic := '0';
signal do_intra_clock_set2_pp, do_intra_clock_set2_p 	: std_logic := '0';
signal get_time2_managed, get_time2_managed_prev 		: std_logic := '0';
signal get_time_oh_st2									: std_logic_vector(11 downto 0) := (others => '0');
signal get_time2_shift_reg								: std_logic_vector(12 downto 0) := (others => '0');
signal set_sync_debug 									: std_logic := '0'; --TODO Debug - REMOVE

signal nsec_7_incd, nsec_15_incd, nsec_23_incd 			: std_logic := '0';
signal nsec_31_incd, nsec_39_incd, nsec_47_incd 		: std_logic := '0';

signal time_sync_sent_sec 						: unsigned(47 downto 0) := (others => '0'); -- T1'
signal time_sync_sent_ns						: unsigned(31 downto 0) := (others => '0'); -- T1'
signal time_invalid, do_intra_clock_set 		: std_logic := '0';
signal one_sec_time_invalid 					: std_logic_vector(5 downto 0) := (others => '0');
signal new_timestamp_received 					: std_logic := '0';
signal frame_addr_wr_addr, frame_addr_rd_addr 	: unsigned(4 downto 0) := (others => '0');
signal frame_addr_val							: std_logic_vector(10 downto 0) := (others => '0');
signal debug_st 								: std_logic := '0';

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

signal init_crc_calc, crc_value_valid	: std_logic := '0';
signal crc_calc_en, crc_data_ld			: std_logic := '0';
signal crc_rd_sig 						: std_logic := '0';
signal eth_txd_data 					: std_logic_vector(3 downto 0) := X"0";
signal crc_value 						: std_logic_vector(31 downto 0) := (others => '0');
signal crc_value_msb					: std_logic_vector(7 downto 0) := (others => '0');
signal ip_checksum_base						: unsigned(19 downto 0) := X"167DA" + unsigned(X"0"&IP_ADDR_IN(31 downto 16)) + unsigned(X"0"&IP_ADDR_IN(15 downto 0));
signal ip_checksum_base_announce_packet 	: unsigned(19 downto 0) := X"167EE" + unsigned(X"0"&IP_ADDR_IN(31 downto 16)) + unsigned(X"0"&IP_ADDR_IN(15 downto 0));
signal ip_checksum_base_to_use 				: unsigned(19 downto 0) := (others => '0');
signal ip_checksum_base_delay_resp_packet 	: unsigned(19 downto 0) := X"167E4" + unsigned(X"0"&IP_ADDR_IN(31 downto 16)) + unsigned(X"0"&IP_ADDR_IN(15 downto 0));
signal ip_checksum						: unsigned(19 downto 0) := (others => '0');
signal lfsr_val 						: std_logic_vector(31 downto 0);
signal time_delay_req_nsec 				: unsigned(31 downto 0) := (others => '0');
signal time_delay_req_sec 				: unsigned(47 downto 0);
signal extracting_resp_data 			: std_logic := '0';
signal new_delay_timestamp_received 	: std_logic := '0';

signal send_sync 									: std_logic_vector(15 downto 0) := (others => '0');
signal send_sync_managed, send_sync_managed_prev 	: std_logic := '0';
signal send_sync_packet_waiting 					: std_logic := '0';
signal do_two_step 									: std_logic := '1';
signal sending_followup 							: std_logic := '0';

signal wr_timestamp_data, eth_buffer_we		: std_logic := '0';
signal wr_timestamp_data_p 					: std_logic := '0';
signal eth_rxd_buf2_we, eth_rxd_buf2_we_ini	: std_logic := '0';
signal new_eth_packet 						: unsigned(4 downto 0) := "00000";
signal eth_buffer_data, rx_timestamp_data 	: std_logic_vector(3 downto 0);
signal rx_timestamp_data_shift 				: std_logic_vector(7 downto 0);
signal time_nsec2_managed	 				: std_logic_vector(31 downto 0);
signal time_sec2_managed	 				: std_logic_vector(47 downto 0);

signal doing_announce_packet_creation 		: std_logic := '0';
signal doing_delay_resp_packet_creation 	: std_logic := '0';
signal slave_mac 							: std_logic_vector(47 downto 0) := (others => '0');
signal slave_timestamp_sec 					: std_logic_vector(47 downto 0) := (others => '0');
signal slave_timestamp_nsec 				: std_logic_vector(31 downto 0) := (others => '0');

signal us_counter 			: unsigned(7 downto 0) := X"00";
signal main_state_latency 	: unsigned(4 downto 0) := (others => '0');

-- TODO Remove
signal pulse_counter : unsigned(15 downto 0) := X"0000";
signal eth_tx_clk_sampled, u1588_release_bus  	: std_logic := '0';
signal eth_rxd_p, eth_rxd_pp					: std_logic_vector(1 downto 0);
signal eth_rxd_dv, eth_rxd_dv_ini				: std_logic := '0';
signal waggle_counter 							: unsigned(5 downto 0) := (others => '0');
signal packet_wr_during_parsing 				: std_logic := '0';
signal sync_packet_latency, sync_packet_latency_counter_rd 		: unsigned(15 downto 0) := X"0000";
signal eth_rxd_addr 							: unsigned(11 downto 0) := (others => '0');
signal incoming_latency_counter, incoming_latency_counter_rd 	: unsigned(15 downto 0) := X"0000";

signal do_packet_send : std_logic := '0';

begin

	do_packet_send <= DO_PACKET_SEND_IN;

	process(CLK_IN)
	begin
		if rising_edge(CLK_IN) then
			main_st <= main_st_next;
		end if;
	end process;

	MAIN_STATE_DECODE: process (main_st, do_packet_send, ip_checksum, tx_packet_creation_addr, tx_packet_en_managed, us_counter)
	begin
		main_st_next <= main_st; -- default to remain in same state
		case (main_st) is
			when IDLE =>
				if do_packet_send = '1' then
					main_st_next <= INIT_SEND_ANNOUNCE_PACKET;
				end if;

			when INIT_SEND_ANNOUNCE_PACKET => 
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
				tx_packet_creation_addr_localized <= unsigned(C_announce_packet_start_addr);
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
							ip_identification(7 downto 0) 					when X"01",
							ip_identification(15 downto 8) 					when X"02",
							IP_ADDR_IN(7 downto 0) 							when X"03",
							IP_ADDR_IN(15 downto 8) 						when X"04",
							IP_ADDR_IN(23 downto 16)						when X"05",
							IP_ADDR_IN(31 downto 24)						when X"06",
							dest_ip_lsb(7 downto 0)							when X"07",
							MAC_IN(7 downto 0) 								when X"08",
							MAC_IN(15 downto 8) 							when X"09",
							MAC_IN(23 downto 16)							when X"0A",
							MAC_IN(31 downto 24)							when X"0B",
							MAC_IN(39 downto 32) 							when X"0C",
							MAC_IN(47 downto 40) 							when X"0D",
							slv(sequenceID_sync_packet(7 downto 0)) 		when X"0E",
							slv(sequenceID_sync_packet(15 downto 8))		when X"0F",
							crc_value_msb									when X"12",
							slv(ip_checksum(7 downto 0))					when X"13",
							slv(ip_checksum(15 downto 8))					when X"14",
							slv(time_sync_sent_sec(7 downto 0))				when X"15",
							slv(time_sync_sent_sec(15 downto 8)) 			when X"16",
							slv(time_sync_sent_sec(23 downto 16))			when X"17",
							slv(time_sync_sent_sec(31 downto 24))			when X"18",
							slv(time_sync_sent_sec(39 downto 32))			when X"19",
							slv(time_sync_sent_sec(47 downto 40)) 			when X"1A",
							slv(time_sync_sent_ns(7 downto 0)) 				when X"1B",
							slv(time_sync_sent_ns(15 downto 8)) 			when X"1C",
							slv(time_sync_sent_ns(23 downto 16))			when X"1D",
							slv("00"&time_sync_sent_ns(29 downto 24))		when X"1E",
							ptp_message_type_send							when X"1F",
							ptp_flags_send									when X"20",
							"000000"&ptp_message_type_send(3 downto 2)		when X"21",
							ptp_port_send 									when X"22",
							slv(sequenceID_announce_packet(7 downto 0)) 	when X"23",
							slv(sequenceID_announce_packet(15 downto 8))	when X"24",
							slv(slave_timestamp_sec(7 downto 0))			when X"25",
							slv(slave_timestamp_sec(15 downto 8)) 			when X"26",
							slv(slave_timestamp_sec(23 downto 16))			when X"27",
							slv(slave_timestamp_sec(31 downto 24))			when X"28",
							slv(slave_timestamp_sec(39 downto 32))			when X"29",
							slv(slave_timestamp_sec(47 downto 40)) 			when X"2A",
							slv(slave_timestamp_nsec(7 downto 0)) 			when X"2B",
							slv(slave_timestamp_nsec(15 downto 8)) 			when X"2C",
							slv(slave_timestamp_nsec(23 downto 16))			when X"2D",
							slv("00"&slave_timestamp_nsec(29 downto 24))	when X"2E",
							slv(slave_mac(7 downto 0))						when X"2F",
							slv(slave_mac(15 downto 8)) 					when X"30",
							slv(slave_mac(23 downto 16))					when X"31",
							slv(slave_mac(31 downto 24))					when X"32",
							slv(slave_mac(39 downto 32))					when X"33",
							slv(slave_mac(47 downto 40)) 					when X"34",
							X"00" 											when others;

	TX_Instruction_Frame : TDP_RAM
		Generic Map(	G_DATA_A_SIZE  	=> 16,
						G_ADDR_A_SIZE	=> 9,
						G_RELATION		=> 0,
						G_INIT_FILE		=> "./coe_dir/1588_tx_frame.coe")

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