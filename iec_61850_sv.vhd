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

COMPONENT checksum_calc2
    Port ( CLK_IN 						: in  STD_LOGIC;
           RST_IN 						: in  STD_LOGIC;
           CHECKSUM_CALC_IN 			: in  STD_LOGIC;
           START_ADDR_IN 				: in  STD_LOGIC_VECTOR (7 downto 0);
           COUNT_IN 					: in  STD_LOGIC_VECTOR (7 downto 0);
           VALUE_IN 					: in  STD_LOGIC_VECTOR (7 downto 0);
           VALUE_ADDR_OUT 				: out STD_LOGIC_VECTOR (7 downto 0);
		   CHECKSUM_INIT_IN				: in  STD_LOGIC_VECTOR (15 downto 0);
		   CHECKSUM_SET_INIT_IN			: in  STD_LOGIC;
		   CHECKSUM_ODD_LENGTH_IN		: in  STD_LOGIC;
           CHECKSUM_OUT 				: out STD_LOGIC_VECTOR (15 downto 0);
           CHECKSUM_DONE_OUT 			: out STD_LOGIC);
END COMPONENT;

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

COMPONENT Pulse_Sync
    Port ( CLK1_IN 		: in  STD_LOGIC;
           CLK2_IN 		: in  STD_LOGIC;
           SIGNAL0_IN 	: in  STD_LOGIC;
           SIGNAL0_OUT 	: out  STD_LOGIC);
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

COMPONENT lfsr32_mod
    Port ( CLK_IN 		: in  STD_LOGIC;
           SEED_IN 		: in  STD_LOGIC_VECTOR(31 downto 0);
           SEED_EN_IN 	: in  STD_LOGIC;
           VAL_OUT 		: out STD_LOGIC_VECTOR(31 downto 0));
END COMPONENT;

type MAIN_STATE is (
						IDLE,
						INIT_SEND_ANNOUNCE_PACKET,
						SETUP_PACKET_CHECKSUM0,
    					SETUP_PACKET_CHECKSUM1,
    					SETUP_PACKET_CHECKSUM2,
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

type PACKET_HANDLER_STATE is (
						IDLE, 
						VERIFY_PACKET_VERACITY0,
						VERIFY_PACKET_VERACITY1,
						VERIFY_PACKET_DATA,
						VERIFY_PACKET_DATA_TWO_OPT,
						VERIFY_PACKET_DATA_TWO_OPT1,
						VERIFY_PACKET_DATA_MSB,
						JUMP_TO_ADDRESS,
						PACKET_VERACITY_ERROR,
						INC_VERACITY_ADDR,
						SET_VERACITY_ADDR,
						GET_HEADER_LENGTH0,
						GET_HEADER_LENGTH1,
						GET_HEADER_LENGTH2,
						GET_HEADER_LENGTH3,
						GET_HEADER_LENGTH4,
						SETUP_CHECKSUM_CALC0,
						SETUP_CHECKSUM_CALC1,
						SETUP_CHECKSUM_CALC2,
						SETUP_CHECKSUM_CALC3,
						SETUP_CHECKSUM_CALC4,
						SETUP_CHECKSUM_CALC5,
						SETUP_CHECKSUM_CALC6,
						SETUP_CHECKSUM_CALC7,
						SETUP_CHECKSUM_CALC8,
						INVERT_CHECKSUM_RESULT,
						ADD_SOURCE_ADDR0,
						ADD_SOURCE_ADDR1,
						ADD_SOURCE_ADDR2,
						ADD_SOURCE_ADDR3,
						ADD_SOURCE_ADDR4,
						ADD_SOURCE_ADDR5,
						ADD_SOURCE_ADDR6,
						ADD_SOURCE_ADDR7,
						VERIFY_CHECKSUM,
						CHECKSUM_ERROR,
						EXTRACT_PTP_DATA0,
						EXTRACT_PTP_DATA1,
						EXTRACT_PTP_DATA2,
						EXTRACT_PTP_DATA3,
						EXTRACT_PTP_DATA4,
						EXTRACT_PTP_DATA5,
						EXTRACT_PTP_DATA6,
						EXTRACT_PTP_DATA7,
						EXTRACT_PTP_DATA8,
						EXTRACT_PTP_DATA9,
						EXTRACT_PTP_DATA10,
						EXTRACT_PTP_DATA11,
						EXTRACT_PTP_DATA12,
						EXTRACT_PTP_DATA13,
						EXTRACT_PTP_DATA14,
						EXTRACT_PTP_CLOCK_IDENTITY0,
						EXTRACT_PTP_CLOCK_IDENTITY1,
						EXTRACT_PTP_CLOCK_IDENTITY2,
						EXTRACT_PTP_CLOCK_IDENTITY3,
						EXTRACT_PTP_CLOCK_IDENTITY4,
						EXTRACT_PTP_CLOCK_IDENTITY5,
						EXTRACT_PTP_CLOCK_IDENTITY6,
						EXTRACT_PTP_CLOCK_IDENTITY7,
						EXTRACT_PTP_CLOCK_IDENTITY8,
						EXTRACT_PTP_CLOCK_IDENTITY9,
						EXTRACT_PTP_PACKET_ARRIVAL_TIME0,
						EXTRACT_PTP_PACKET_ARRIVAL_TIME1,
						EXTRACT_PTP_PACKET_ARRIVAL_TIME2,
						EXTRACT_PTP_PACKET_ARRIVAL_TIME3,
						EXTRACT_PTP_PACKET_ARRIVAL_TIME4,
						EXTRACT_PTP_PACKET_ARRIVAL_TIME5,
						EXTRACT_PTP_PACKET_ARRIVAL_TIME6,
						EXTRACT_PTP_PACKET_ARRIVAL_TIME7,
						EXTRACT_PTP_PACKET_ARRIVAL_TIME8,
						EXTRACT_PTP_PACKET_ARRIVAL_TIME9,
						TRIGGER_DELAY_RESP_PACKET,
						WAIT_FOR_PACKET_TRANSMISSION_CMPLT,
						COMPLETE
					);

type BASIC_MAC_STATE is (
							MAC_IDLE,
							GOTO_FRAME_START_ADDR0,
							WRITE_PACKET_INTO_PARSING_BUFFER0,
							WRITE_PACKET_INTO_PARSING_BUFFER1,
							WRITE_PACKET_INTO_PARSING_BUFFER2,
							WRITE_PACKET_INTO_PARSING_BUFFER3,
							ANNOUNCE_NEW_PACKET,
							COMPLETE
						);

signal bm_st, bm_st_next : BASIC_MAC_STATE := MAC_IDLE;

signal packet_handler_st, packet_handler_st_next : PACKET_HANDLER_STATE := IDLE;

constant C_SDO_Epoch_Sec 				: std_logic_vector(47 downto 0) := X"0000555D3C20"; -- Default time

constant C_nsec_max 					: std_logic_vector(29 downto 0) := "11"&X"B9AC9F6"; -- 	999999990 base 10
constant C_nsec_max_inv					: std_logic_vector(29 downto 0) := "00"&X"4653609"; -- 	Inverse of maximum value of nano second register
constant C_sync_packet_lantency_ns 		: std_logic_vector(29 downto 0) := "00"&X"0001135"; -- Time in ns from setting sync packet send time to actually sending it TODO
constant C_sync_packet_lantency_ns_inv 	: std_logic_vector(29 downto 0) := "11"&X"B9AB8C1"; -- (999999990 - C_sync_packet_lantency_ns) TODO
constant C_500ms 						: unsigned(29 downto 0) := "01"&X"DCD6500";

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

signal time_sec_100mhz 				: unsigned(47 downto 0);
signal time_sec_100mhz_47 			: unsigned(7 downto 0) := unsigned(C_SDO_Epoch_Sec(47 downto 40));
signal time_sec_100mhz_39 			: unsigned(7 downto 0) := unsigned(C_SDO_Epoch_Sec(39 downto 32));
signal time_sec_100mhz_31 			: unsigned(7 downto 0) := unsigned(C_SDO_Epoch_Sec(31 downto 24));
signal time_sec_100mhz_23 			: unsigned(7 downto 0) := unsigned(C_SDO_Epoch_Sec(23 downto 16));
signal time_sec_100mhz_15 			: unsigned(7 downto 0) := unsigned(C_SDO_Epoch_Sec(15 downto 8));
signal time_sec_100mhz_7 			: unsigned(7 downto 0) := unsigned(C_SDO_Epoch_Sec(7 downto 0));
signal time_sec, time_sec_intra  	: unsigned(47 downto 0) := unsigned(C_SDO_Epoch_Sec);
--signal time_nsec_100mhz 			: unsigned(29 downto 0) := (others => '0');
signal time_nsec_100mhz 			: unsigned(29 downto 0) := (unsigned(C_nsec_max)-100); -- TODO Testing -> remove
signal interval_ns 					: unsigned(29 downto 0) := "00"&X"000000A";

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

	time_sec_100mhz <= time_sec_100mhz_47&time_sec_100mhz_39&time_sec_100mhz_31&time_sec_100mhz_23&time_sec_100mhz_15&time_sec_100mhz_7;

	packet_veracity_data_cmd <= packet_veracity_data(9 downto 8);
	packet_veracity_data_lower <= packet_veracity_data(7 downto 0);

	process(CLK_IN)
	begin
		if rising_edge(CLK_IN) then
			packet_handler_st <= packet_handler_st_next; -- TODO add timeout on no state transition (prob around 2 sec?)
		end if;
	end process;

	PACKET_HANDLER_DECODE: process (packet_handler_st, new_packet_received, packet_veracity_data_cmd, packet_data, 
										packet_veracity_data_lower, checksum_done, checksum_final, extracting_resp_data, main_st)
	begin
		packet_handler_st_next <= packet_handler_st;
		case (packet_handler_st) is
			when IDLE =>
				if new_packet_received = '1' then
					packet_handler_st_next <= VERIFY_PACKET_VERACITY0;
				end if;
			when VERIFY_PACKET_VERACITY0 =>
				packet_handler_st_next <= VERIFY_PACKET_VERACITY1;
			when VERIFY_PACKET_VERACITY1 =>
				if packet_veracity_data_cmd = "00" then
					packet_handler_st_next <= VERIFY_PACKET_DATA;
				elsif packet_veracity_data_cmd = "01" then
					packet_handler_st_next <= VERIFY_PACKET_DATA_TWO_OPT;
				elsif packet_veracity_data_cmd = "10" then
					packet_handler_st_next <= VERIFY_PACKET_DATA_MSB;
				else
					packet_handler_st_next <= JUMP_TO_ADDRESS;
				end if;
			when VERIFY_PACKET_DATA =>
				if packet_data /= packet_veracity_data_lower then
					packet_handler_st_next <= PACKET_VERACITY_ERROR;
				else
					packet_handler_st_next <= INC_VERACITY_ADDR;
				end if;
			when VERIFY_PACKET_DATA_TWO_OPT =>
				if packet_data /= packet_veracity_data_lower then
					packet_handler_st_next <= VERIFY_PACKET_DATA_TWO_OPT1;
				else
					packet_handler_st_next <= INC_VERACITY_ADDR;
				end if;
			when VERIFY_PACKET_DATA_TWO_OPT1 =>
				if packet_data /= two_opt_data then
					packet_handler_st_next <= PACKET_VERACITY_ERROR;
				else
					packet_handler_st_next <= INC_VERACITY_ADDR;
				end if;
			when VERIFY_PACKET_DATA_MSB =>
				if packet_data(7 downto 4) /= packet_veracity_data_lower(7 downto 4) then
					packet_handler_st_next <= PACKET_VERACITY_ERROR;
				else
					packet_handler_st_next <= INC_VERACITY_ADDR;
				end if;
			when JUMP_TO_ADDRESS =>
				if packet_veracity_data_lower = X"FE" then
					packet_handler_st_next <= GET_HEADER_LENGTH0;
				elsif packet_veracity_data_lower = X"FF" then
					packet_handler_st_next <= SETUP_CHECKSUM_CALC0;
				else
					packet_handler_st_next <= SET_VERACITY_ADDR;
				end if;
			when INC_VERACITY_ADDR =>
				packet_handler_st_next <= VERIFY_PACKET_VERACITY0;
			when SET_VERACITY_ADDR =>
				packet_handler_st_next <= VERIFY_PACKET_VERACITY0;	

			when GET_HEADER_LENGTH0 =>
				packet_handler_st_next <= GET_HEADER_LENGTH1;
			when GET_HEADER_LENGTH1 =>
				packet_handler_st_next <= GET_HEADER_LENGTH2;
			when GET_HEADER_LENGTH2 =>
				packet_handler_st_next <= GET_HEADER_LENGTH3;
			when GET_HEADER_LENGTH3 =>
				packet_handler_st_next <= GET_HEADER_LENGTH4;
			when GET_HEADER_LENGTH4 =>
				packet_handler_st_next <= VERIFY_PACKET_VERACITY0;

			when PACKET_VERACITY_ERROR =>
				packet_handler_st_next <= COMPLETE;

			when SETUP_CHECKSUM_CALC0 =>
				packet_handler_st_next <= SETUP_CHECKSUM_CALC1;
			when SETUP_CHECKSUM_CALC1 =>
				packet_handler_st_next <= SETUP_CHECKSUM_CALC2;
			when SETUP_CHECKSUM_CALC2 =>
				packet_handler_st_next <= SETUP_CHECKSUM_CALC3;
			when SETUP_CHECKSUM_CALC3 =>
				packet_handler_st_next <= SETUP_CHECKSUM_CALC4;
			when SETUP_CHECKSUM_CALC4 =>
				packet_handler_st_next <= SETUP_CHECKSUM_CALC5;
			when SETUP_CHECKSUM_CALC5 =>
				packet_handler_st_next <= SETUP_CHECKSUM_CALC6;
			when SETUP_CHECKSUM_CALC6 =>
				packet_handler_st_next <= SETUP_CHECKSUM_CALC7;
			when SETUP_CHECKSUM_CALC7 =>
				packet_handler_st_next <= SETUP_CHECKSUM_CALC8;
			when SETUP_CHECKSUM_CALC8 =>
				if checksum_done = '1' then
					packet_handler_st_next <= INVERT_CHECKSUM_RESULT;
				end if;
			when INVERT_CHECKSUM_RESULT =>
				packet_handler_st_next <= ADD_SOURCE_ADDR0;
			when ADD_SOURCE_ADDR0 =>
				packet_handler_st_next <= ADD_SOURCE_ADDR1;
			when ADD_SOURCE_ADDR1 =>
				packet_handler_st_next <= ADD_SOURCE_ADDR2;
			when ADD_SOURCE_ADDR2 =>
				packet_handler_st_next <= ADD_SOURCE_ADDR3;
			when ADD_SOURCE_ADDR3 =>
				packet_handler_st_next <= ADD_SOURCE_ADDR4;
			when ADD_SOURCE_ADDR4 =>
				packet_handler_st_next <= ADD_SOURCE_ADDR5;
			when ADD_SOURCE_ADDR5 =>
				packet_handler_st_next <= ADD_SOURCE_ADDR6;
			when ADD_SOURCE_ADDR6 =>
				packet_handler_st_next <= ADD_SOURCE_ADDR7;
			when ADD_SOURCE_ADDR7 =>
				packet_handler_st_next <= VERIFY_CHECKSUM;
			when VERIFY_CHECKSUM =>
				if checksum_final = X"FFFF" then
					packet_handler_st_next <= EXTRACT_PTP_DATA0;
				elsif udp_checksum = X"0000" then
					packet_handler_st_next <= EXTRACT_PTP_DATA0;
				else
					packet_handler_st_next <= CHECKSUM_ERROR;
				end if;
			when CHECKSUM_ERROR =>
				packet_handler_st_next <= COMPLETE;

			when EXTRACT_PTP_DATA0 =>
				packet_handler_st_next <= EXTRACT_PTP_DATA1;
			when EXTRACT_PTP_DATA1 =>
				packet_handler_st_next <= EXTRACT_PTP_DATA2;
			when EXTRACT_PTP_DATA2 =>
				packet_handler_st_next <= EXTRACT_PTP_DATA3;
			when EXTRACT_PTP_DATA3 =>
				packet_handler_st_next <= EXTRACT_PTP_DATA4;
			when EXTRACT_PTP_DATA4 =>
				packet_handler_st_next <= EXTRACT_PTP_DATA5;
			when EXTRACT_PTP_DATA5 =>
				packet_handler_st_next <= EXTRACT_PTP_DATA6;
			when EXTRACT_PTP_DATA6 =>
				packet_handler_st_next <= EXTRACT_PTP_DATA7;
			when EXTRACT_PTP_DATA7 =>
				packet_handler_st_next <= EXTRACT_PTP_DATA8;
			when EXTRACT_PTP_DATA8 =>
				packet_handler_st_next <= EXTRACT_PTP_DATA9;
			when EXTRACT_PTP_DATA9 =>
				packet_handler_st_next <= EXTRACT_PTP_DATA10;
			when EXTRACT_PTP_DATA10 =>
				packet_handler_st_next <= EXTRACT_PTP_DATA11;

			when EXTRACT_PTP_DATA11 =>
				packet_handler_st_next <= EXTRACT_PTP_DATA12;
			when EXTRACT_PTP_DATA12 =>
				packet_handler_st_next <= EXTRACT_PTP_DATA13;
			when EXTRACT_PTP_DATA13 =>
				packet_handler_st_next <= EXTRACT_PTP_DATA14;
			when EXTRACT_PTP_DATA14 =>
				if ptp_message_type = C_ptp_delay_req_type then
					packet_handler_st_next <= EXTRACT_PTP_CLOCK_IDENTITY0;
				else
					packet_handler_st_next <= COMPLETE;
				end if;

			when EXTRACT_PTP_CLOCK_IDENTITY0 =>
				packet_handler_st_next <= EXTRACT_PTP_CLOCK_IDENTITY1;
			when EXTRACT_PTP_CLOCK_IDENTITY1 =>
				packet_handler_st_next <= EXTRACT_PTP_CLOCK_IDENTITY2;
			when EXTRACT_PTP_CLOCK_IDENTITY2 =>
				packet_handler_st_next <= EXTRACT_PTP_CLOCK_IDENTITY3;
			when EXTRACT_PTP_CLOCK_IDENTITY3 =>
				packet_handler_st_next <= EXTRACT_PTP_CLOCK_IDENTITY4;
			when EXTRACT_PTP_CLOCK_IDENTITY4 =>
				packet_handler_st_next <= EXTRACT_PTP_CLOCK_IDENTITY5;
			when EXTRACT_PTP_CLOCK_IDENTITY5 =>
				packet_handler_st_next <= EXTRACT_PTP_CLOCK_IDENTITY6;
			when EXTRACT_PTP_CLOCK_IDENTITY6 =>
				packet_handler_st_next <= EXTRACT_PTP_CLOCK_IDENTITY7;
			when EXTRACT_PTP_CLOCK_IDENTITY7 =>
				packet_handler_st_next <= EXTRACT_PTP_CLOCK_IDENTITY8;
			when EXTRACT_PTP_CLOCK_IDENTITY8 =>
				packet_handler_st_next <= EXTRACT_PTP_CLOCK_IDENTITY9;
			when EXTRACT_PTP_CLOCK_IDENTITY9 =>
				packet_handler_st_next <= EXTRACT_PTP_PACKET_ARRIVAL_TIME0;

			when EXTRACT_PTP_PACKET_ARRIVAL_TIME0 =>
				packet_handler_st_next <= EXTRACT_PTP_PACKET_ARRIVAL_TIME1;
			when EXTRACT_PTP_PACKET_ARRIVAL_TIME1 =>
				packet_handler_st_next <= EXTRACT_PTP_PACKET_ARRIVAL_TIME2;
			when EXTRACT_PTP_PACKET_ARRIVAL_TIME2 =>
				packet_handler_st_next <= EXTRACT_PTP_PACKET_ARRIVAL_TIME3;
			when EXTRACT_PTP_PACKET_ARRIVAL_TIME3 =>
				packet_handler_st_next <= EXTRACT_PTP_PACKET_ARRIVAL_TIME4;
			when EXTRACT_PTP_PACKET_ARRIVAL_TIME4 =>
				packet_handler_st_next <= EXTRACT_PTP_PACKET_ARRIVAL_TIME5;
			when EXTRACT_PTP_PACKET_ARRIVAL_TIME5 =>
				packet_handler_st_next <= EXTRACT_PTP_PACKET_ARRIVAL_TIME6;
			when EXTRACT_PTP_PACKET_ARRIVAL_TIME6 =>
				packet_handler_st_next <= EXTRACT_PTP_PACKET_ARRIVAL_TIME7;
			when EXTRACT_PTP_PACKET_ARRIVAL_TIME7 =>
				packet_handler_st_next <= EXTRACT_PTP_PACKET_ARRIVAL_TIME8;
			when EXTRACT_PTP_PACKET_ARRIVAL_TIME8 =>
				packet_handler_st_next <= EXTRACT_PTP_PACKET_ARRIVAL_TIME9;
			when EXTRACT_PTP_PACKET_ARRIVAL_TIME9 =>
				packet_handler_st_next <= TRIGGER_DELAY_RESP_PACKET;

			when TRIGGER_DELAY_RESP_PACKET =>
					packet_handler_st_next <= WAIT_FOR_PACKET_TRANSMISSION_CMPLT;
			when WAIT_FOR_PACKET_TRANSMISSION_CMPLT =>
				if main_st = COMPLETE then
					packet_handler_st_next <= COMPLETE;
				end if;

			when COMPLETE =>
				packet_handler_st_next <= IDLE;
		end case;
	end process;

	PACKET_ADDRS : process(CLK_IN)
	begin
		if rising_edge(CLK_IN) then
			if packet_handler_st = IDLE then
				packet_veracity_addr <= (others => '0');
			elsif packet_handler_st = VERIFY_PACKET_VERACITY0 then
				packet_veracity_addr <= packet_veracity_addr;
			elsif packet_handler_st = VERIFY_PACKET_VERACITY1 then
				packet_veracity_addr <= packet_veracity_addr;
			elsif packet_handler_st = VERIFY_PACKET_DATA then
				packet_veracity_addr <= packet_veracity_addr;
			elsif packet_handler_st = VERIFY_PACKET_DATA_TWO_OPT then
				packet_veracity_addr <= packet_veracity_addr;
			elsif packet_handler_st = VERIFY_PACKET_DATA_TWO_OPT1 then
				packet_veracity_addr <= packet_veracity_addr;
			elsif packet_handler_st = VERIFY_PACKET_DATA_MSB then
				packet_veracity_addr <= packet_veracity_addr;
			elsif packet_handler_st = SET_VERACITY_ADDR then
				packet_veracity_addr <= unsigned(packet_veracity_data_lower);
			elsif packet_handler_st = GET_HEADER_LENGTH0 then
				packet_veracity_addr <= unsigned(C_ip_header_packet_length_addr);
			elsif packet_handler_st = GET_HEADER_LENGTH4 then
				packet_veracity_addr <= unsigned(upd_packet_start_addr);
			elsif packet_handler_st = SETUP_CHECKSUM_CALC0 then
				packet_veracity_addr <= unsigned(upd_packet_start_addr) + 4;
			elsif packet_handler_st = ADD_SOURCE_ADDR0 then
				packet_veracity_addr <= X"1A"; -- Source IP start address
			elsif packet_handler_st = ADD_SOURCE_ADDR4 then
				packet_veracity_addr <= X"21"; -- Destination IP LSB address
			elsif packet_handler_st = EXTRACT_PTP_DATA0 then
				packet_veracity_addr <= unsigned(upd_packet_start_addr) + 8; -- start of PTP message address
			elsif packet_handler_st = EXTRACT_PTP_DATA8 then
				packet_veracity_addr <= unsigned(upd_packet_start_addr) + 36; -- SourcePortID address
			elsif packet_handler_st = EXTRACT_PTP_CLOCK_IDENTITY0 then
				packet_veracity_addr <= unsigned(upd_packet_start_addr) + 28; -- Clock Identity address
			elsif packet_handler_st = EXTRACT_PTP_CLOCK_IDENTITY8 then
				packet_veracity_addr <= unsigned(upd_packet_start_addr) + packet_arrival_timestamp_offset_addr; -- Packet Arrival timestamp
			else
				packet_veracity_addr <= packet_veracity_addr + 1;
			end if;
		end if;
	end process;

	PACKET_VERACITY_ADDRS : process(CLK_IN)
	begin
		if rising_edge(CLK_IN) then
			if packet_handler_st = IDLE then
				packet_veracity_ram_addr <= (others => '0');
			elsif packet_handler_st = INC_VERACITY_ADDR then
				packet_veracity_ram_addr <= packet_veracity_ram_addr + 1;
			elsif packet_handler_st = SET_VERACITY_ADDR then
				packet_veracity_ram_addr <= packet_veracity_ram_addr + 1;
			elsif packet_handler_st = GET_HEADER_LENGTH4 then
				packet_veracity_ram_addr <= packet_veracity_ram_addr + 1;
			end if;
		end if;
	end process;

	IP_HEADER_LEN : process( CLK_IN )
	begin
		if rising_edge(CLK_IN) then
			if packet_handler_st = GET_HEADER_LENGTH2 then
				header_length <= "00"&packet_data(3 downto 0)&"00";
			end if;
			if packet_handler_st = GET_HEADER_LENGTH3 then
				upd_packet_start_addr <= unsigned(C_ip_header_packet_length_addr) + unsigned(header_length);
			end if;
		end if;
	end process;

	CHECKSUM_PROC : process( CLK_IN )
	begin
		if rising_edge(CLK_IN) then
			if packet_handler_st = SETUP_CHECKSUM_CALC2 then
				udp_packet_length(15 downto 8) <= unsigned(packet_data);
			end if;
			if packet_handler_st = SETUP_CHECKSUM_CALC3 then
				udp_packet_length(7 downto 0) <= unsigned(packet_data);
			end if;
			if packet_handler_st = SETUP_CHECKSUM_CALC4 then
				checksum_initial_val <= udp_packet_length + X"E111"; -- Protocol (UDP) + Top three bytes of destination ip (Multicast always 224.0.1.x)
				checksum_start_addr <= slv(upd_packet_start_addr);
				checksum_count <= '0'&slv(udp_packet_length(7 downto 1));
			end if;
			if packet_handler_st = SETUP_CHECKSUM_CALC4 then
				udp_checksum(15 downto 8) <= packet_data;
			end if;
			if packet_handler_st = SETUP_CHECKSUM_CALC5 then
				udp_checksum(7 downto 0) <= packet_data;
			end if;
			if packet_handler_st = SETUP_CHECKSUM_CALC4 then
				checksum_set_init_en <= '1';
			else
				checksum_set_init_en <= '0';
			end if;
			if packet_handler_st = SETUP_CHECKSUM_CALC7 then
				checksum_calc_en <= '1';
			else
				checksum_calc_en <= '0';
			end if;
			if packet_handler_st = SETUP_CHECKSUM_CALC5 then
				doing_checksum <= '1';
			elsif packet_handler_st = INVERT_CHECKSUM_RESULT then
				doing_checksum <= '0';
			end if;
			if packet_handler_st = INVERT_CHECKSUM_RESULT then
				checksum_inv <= not(checksum);
			end if;
			if packet_handler_st = ADD_SOURCE_ADDR2 then
				source_addr_msb(15 downto 8) <= packet_data;
			end if;
			if packet_handler_st = ADD_SOURCE_ADDR3 then
				source_addr_msb(7 downto 0) <= packet_data;
			end if;
			if packet_handler_st = ADD_SOURCE_ADDR4 then
				source_addr_lsb(15 downto 8) <= packet_data;
			end if;
			if packet_handler_st = ADD_SOURCE_ADDR5 then
				source_addr_lsb(7 downto 0) <= packet_data;
			end if;
			if packet_handler_st = ADD_SOURCE_ADDR4 then
				checksum_final <= unsigned(checksum_inv) + unsigned(source_addr_msb);
			elsif packet_handler_st = ADD_SOURCE_ADDR6 then
				checksum_final <= checksum_final + unsigned(source_addr_lsb);
			elsif packet_handler_st = ADD_SOURCE_ADDR7 then
				checksum_final <= checksum_final + unsigned(X"00"&dest_ip_lsb);
			end if;
		end if;
	end process;

	Checksum_Calc_Inst : checksum_calc2
    Port Map ( CLK_IN 					=> CLK_IN,
           	   RST_IN 					=> '0',
	           CHECKSUM_CALC_IN 		=> checksum_calc_en,
	           START_ADDR_IN 			=> checksum_start_addr,
	           COUNT_IN 				=> checksum_count,
	           VALUE_IN 				=> packet_data,
	           VALUE_ADDR_OUT			=> checksum_addr,
			   CHECKSUM_INIT_IN			=> slv(checksum_initial_val), 
			   CHECKSUM_SET_INIT_IN		=> checksum_set_init_en,
			   CHECKSUM_ODD_LENGTH_IN	=> '0', 
	           CHECKSUM_OUT 			=> checksum,
	           CHECKSUM_DONE_OUT 		=> checksum_done);

	EXTRACT_PTP_DATA : process(CLK_IN)
	begin
		if rising_edge(CLK_IN) then
			if packet_handler_st = EXTRACT_PTP_DATA2 then
				ptp_message_type <= packet_data(3 downto 0);
			end if;
			if packet_handler_st = EXTRACT_PTP_DATA3 then
				ptp_version <= packet_data;
			end if;
			if packet_handler_st = EXTRACT_PTP_DATA4 then
				ptp_message_length(15 downto 8) <= packet_data;
			end if;
			if packet_handler_st = EXTRACT_PTP_DATA5 then
				ptp_message_length(7 downto 0) <= packet_data;
			end if;
			if packet_handler_st = EXTRACT_PTP_DATA8 then
				ptp_flags(15 downto 8) <= packet_data;
			end if;
			if packet_handler_st = EXTRACT_PTP_DATA9 then
				ptp_flags(7 downto 0) <= packet_data;
			end if;
			if packet_handler_st = EXTRACT_PTP_DATA12 then
				sequenceID(15 downto 8) <= packet_data;
			end if;
			if packet_handler_st = EXTRACT_PTP_DATA13 then
				sequenceID(7 downto 0) <= packet_data;
			end if;
			if packet_handler_st = EXTRACT_PTP_CLOCK_IDENTITY2 then
				slave_mac(47 downto 40) <= packet_data;
			end if;
			if packet_handler_st = EXTRACT_PTP_CLOCK_IDENTITY3 then
				slave_mac(39 downto 32) <= packet_data;
			end if;
			if packet_handler_st = EXTRACT_PTP_CLOCK_IDENTITY4 then
				slave_mac(31 downto 24) <= packet_data;
			end if;
			if packet_handler_st = EXTRACT_PTP_CLOCK_IDENTITY7 then
				slave_mac(23 downto 16) <= packet_data;
			end if;
			if packet_handler_st = EXTRACT_PTP_CLOCK_IDENTITY8 then
				slave_mac(15 downto 8) <= packet_data;
			end if;
			if packet_handler_st = EXTRACT_PTP_CLOCK_IDENTITY9 then
				slave_mac(7 downto 0) <= packet_data;
			end if;
			if packet_handler_st = EXTRACT_PTP_PACKET_ARRIVAL_TIME0 then
				slave_timestamp_sec(47 downto 40) <= packet_data;
			end if;
			if packet_handler_st = EXTRACT_PTP_PACKET_ARRIVAL_TIME1 then
				slave_timestamp_sec(39 downto 32) <= packet_data;
			end if;
			if packet_handler_st = EXTRACT_PTP_PACKET_ARRIVAL_TIME2 then
				slave_timestamp_sec(31 downto 24) <= packet_data;
			end if;
			if packet_handler_st = EXTRACT_PTP_PACKET_ARRIVAL_TIME3 then
				slave_timestamp_sec(23 downto 16) <= packet_data;
			end if;
			if packet_handler_st = EXTRACT_PTP_PACKET_ARRIVAL_TIME4 then
				slave_timestamp_sec(15 downto 8) <= packet_data;
			end if;
			if packet_handler_st = EXTRACT_PTP_PACKET_ARRIVAL_TIME5 then
				slave_timestamp_sec(7 downto 0) <= packet_data;
			end if;
			if packet_handler_st = EXTRACT_PTP_PACKET_ARRIVAL_TIME6 then
				slave_timestamp_nsec(31 downto 24) <= packet_data;
			end if;
			if packet_handler_st = EXTRACT_PTP_PACKET_ARRIVAL_TIME7 then
				slave_timestamp_nsec(23 downto 16) <= packet_data;
			end if;
			if packet_handler_st = EXTRACT_PTP_PACKET_ARRIVAL_TIME8 then
				slave_timestamp_nsec(15 downto 8) <= packet_data;
			end if;
			if packet_handler_st = EXTRACT_PTP_PACKET_ARRIVAL_TIME9 then
				slave_timestamp_nsec(7 downto 0) <= packet_data;
			end if;
		end if;
	end process;

	Eth_Veracity_frame : TDP_RAM
		Generic Map(	G_DATA_A_SIZE  	=> 10,
						G_ADDR_A_SIZE	=> 5,
						G_RELATION		=> 0, 
						G_INIT_FILE		=> "./coe_dir/1588_bare_frame_bin.coe")

		Port Map ( 		CLK_A_IN 		=> CLK_IN,
						WE_A_IN 		=> '0',
						ADDR_A_IN 		=> slv(packet_veracity_ram_addr),
						DATA_A_IN		=> (others => '0'),
						DATA_A_OUT		=> packet_veracity_data,
						CLK_B_IN 		=> '0',
						WE_B_IN 		=> '0',
						ADDR_B_IN	 	=> (others => '0'),
						DATA_B_IN 		=> (others => '0'),
						DATA_B_OUT		=> open);

	frame_rd_addr <= slv(packet_veracity_addr) when doing_checksum = '0' else checksum_addr;

	Eth_RX_frame : TDP_RAM
		Generic Map(	G_DATA_A_SIZE  	=> 8,
						G_ADDR_A_SIZE	=> 8,
						G_RELATION		=> 0, 
						G_INIT_FILE		=> "")

		Port Map ( 	CLK_A_IN 		=> CLK_IN,
					WE_A_IN 		=> '0',
					ADDR_A_IN 		=> frame_rd_addr,
					DATA_A_IN		=> (others => '0'),
					DATA_A_OUT		=> packet_data,
					CLK_B_IN 		=> CLK_IN,
					WE_B_IN 		=> frame_we,
					ADDR_B_IN	 	=> slv(frame_wr_addr),
					DATA_B_IN 		=> bm_data,
					DATA_B_OUT		=> open);

   	rx_timestamp_data_shift <= time_sec2_managed(47 downto 40);
	eth_buffer_data <= eth_rxd_data_buf1 when wr_timestamp_data = '0' else rx_timestamp_data;
	eth_buffer_we <= eth_rxd_buf2_we or wr_timestamp_data;

	process(CLK_IN)
	begin
		if rising_edge(CLK_IN) then
			bm_st <= bm_st_next; -- TODO add timeout on no state transition (prob around 2 sec?)
		end if;
	end process;

	debug_st <= '1' when bm_st = MAC_IDLE else '0';

	BASIC_MAC_DECODE: process (bm_st, bm_addr, bm_data, eth_rxd_addr_buf1, preamble_octets, 
								packet_handler_st, frame_addr_wr_addr, frame_addr_rd_addr)
	begin
		bm_st_next <= bm_st;
		case (bm_st) is
			when MAC_IDLE =>
				if frame_addr_rd_addr /= frame_addr_wr_addr then
					bm_st_next <= GOTO_FRAME_START_ADDR0;
				end if;

			when GOTO_FRAME_START_ADDR0 =>
				bm_st_next <= WRITE_PACKET_INTO_PARSING_BUFFER0;
			when WRITE_PACKET_INTO_PARSING_BUFFER0 =>
				if packet_handler_st = IDLE then
					bm_st_next <= WRITE_PACKET_INTO_PARSING_BUFFER1;
				end if;
			when WRITE_PACKET_INTO_PARSING_BUFFER1 =>
				if (bm_addr = eth_rxd_addr_buf2(10 downto 1)) and (eth_rxd_dv_in_managed = '0') then
					bm_st_next <= ANNOUNCE_NEW_PACKET;
				elsif (frame_addr_rd_addr /= frame_addr_wr_addr) and (bm_addr = unsigned(frame_addr_val(10 downto 1))) then
					bm_st_next <= ANNOUNCE_NEW_PACKET;
				elsif (frame_addr_rd_addr = frame_addr_wr_addr) and (bm_addr = packet_start_addr(10 downto 1)) and packet_wr_during_parsing = '1' then
					bm_st_next <= ANNOUNCE_NEW_PACKET;
				else
					bm_st_next <= WRITE_PACKET_INTO_PARSING_BUFFER2;
				end if;
			when WRITE_PACKET_INTO_PARSING_BUFFER2 =>
				bm_st_next <= WRITE_PACKET_INTO_PARSING_BUFFER3;
			when WRITE_PACKET_INTO_PARSING_BUFFER3 =>
				bm_st_next <= WRITE_PACKET_INTO_PARSING_BUFFER1;

			when ANNOUNCE_NEW_PACKET =>
				if packet_handler_st = IDLE then
					bm_st_next <= COMPLETE;
				end if;

			when COMPLETE =>
				bm_st_next <= MAC_IDLE;

		end case;
	end process;

	process(CLK_IN)
	begin
		if rising_edge(CLK_IN) then
			eth_rxd_dv_in_managed <= eth_rxd_dv;
			if bm_st = ANNOUNCE_NEW_PACKET then
				new_packet_received <= '1';
			else
				new_packet_received <= '0';
			end if;
		end if;
	end process;

	frame_we <= '1' when bm_st = WRITE_PACKET_INTO_PARSING_BUFFER3 else '0';

	process(CLK_IN)
	begin
		if rising_edge(CLK_IN) then
			if bm_st = GOTO_FRAME_START_ADDR0 then
				frame_addr_rd_addr <= frame_addr_rd_addr + 1;
			end if;
			if bm_st = GOTO_FRAME_START_ADDR0 then
				bm_addr <= unsigned(frame_addr_val(10 downto 1));
			elsif bm_st = WRITE_PACKET_INTO_PARSING_BUFFER3 then
				bm_addr <= bm_addr + 1;
			end if;
			if bm_st = WRITE_PACKET_INTO_PARSING_BUFFER3 then
				frame_wr_addr <= frame_wr_addr + 1;
			elsif bm_st = ANNOUNCE_NEW_PACKET then
				frame_wr_addr <= X"00";
			end if;
		end if;
	end process;

	process(CLK_IN)
	begin
		if rising_edge(CLK_IN) then
			one_sec_time_invalid(5 downto 1) <= one_sec_time_invalid(4 downto 0);
			if time_nsec_100mhz >= unsigned(C_nsec_max) then
				one_sec_time_invalid(0) <= '1';
			else
				one_sec_time_invalid(0) <= '0';
			end if;
			if time_nsec_100mhz >= unsigned(C_nsec_max) then
				time_invalid <= '1';
			elsif one_sec_time_invalid(5) = '1' then
				time_invalid <= '0';
			end if;
		end if;
	end process;

	process(CLK_IN)
	begin
		if rising_edge(CLK_IN) then
			send_sync(15 downto 1) <= send_sync(14 downto 0);
			if time_nsec_100mhz >= unsigned(C_nsec_max) then
				send_sync(0) <= '1';
			else
				send_sync(0) <= '0';
			end if;
			if time_nsec_100mhz >= unsigned(C_nsec_max) then
				time_nsec_100mhz <= (others => '0');
			else
				time_nsec_100mhz <= time_nsec_100mhz + interval_ns;
			end if;
			if time_nsec_100mhz >= unsigned(C_nsec_max) then
				time_sec_100mhz_7 <= time_sec_100mhz_7 + 1;	
			end if;
			if time_nsec_100mhz >= unsigned(C_nsec_max) then
				nsec_7_incd <= '1';
			else
				nsec_7_incd <= '0';
			end if;
			if nsec_7_incd = '1' and time_sec_100mhz_7 = X"00" then
				time_sec_100mhz_15 <= time_sec_100mhz_15 + 1;	
			end if;
			if nsec_7_incd = '1' and time_sec_100mhz_7 = X"00" then
				nsec_15_incd <= '1';
			else
				nsec_15_incd <= '0';
			end if;
			if nsec_15_incd = '1' and time_sec_100mhz_15 = X"00" then
				time_sec_100mhz_23 <= time_sec_100mhz_23 + 1;	
			end if;
			if nsec_15_incd = '1' and time_sec_100mhz_15 = X"00" then
				nsec_23_incd <= '1';
			else
				nsec_23_incd <= '0';
			end if;
			if nsec_23_incd = '1' and time_sec_100mhz_23 = X"00" then
				time_sec_100mhz_31 <= time_sec_100mhz_31 + 1;	
			end if;
			if nsec_23_incd = '1' and time_sec_100mhz_23 = X"00" then
				nsec_31_incd <= '1';
			else
				nsec_31_incd <= '0';
			end if;
			if nsec_31_incd = '1' and time_sec_100mhz_31 = X"00" then
				time_sec_100mhz_39 <= time_sec_100mhz_39 + 1;	
			end if;
			if nsec_31_incd = '1' and time_sec_100mhz_31 = X"00" then
				nsec_39_incd <= '1';
			else
				nsec_39_incd <= '0';
			end if;
			if nsec_39_incd = '1' and time_sec_100mhz_39 = X"00" then
				time_sec_100mhz_47 <= time_sec_100mhz_47 + 1;	
			end if;
		end if;
	end process;

	Pulse_Sync_Inst : Pulse_Sync
    Port Map ( 	CLK1_IN 	=> CLK_IN,
           		CLK2_IN 	=> CLK_IN,
           		SIGNAL0_IN 	=> clk_in_set_intra_clock_registers,
           		SIGNAL0_OUT => clk_100mhz_set_intra_clock_registers);

	process(CLK_IN)
	begin
		if rising_edge(CLK_IN) then
			if clk_100mhz_set_intra_clock_registers = '1' then
				do_intra_clock_set <= '1';
			elsif time_invalid = '0' then
				do_intra_clock_set <= '0';
			end if;
			if do_intra_clock_set = '1' and time_invalid = '0' then
				time_nsec_intra <= time_nsec_100mhz;
				time_sec_intra <= time_sec_100mhz_47&time_sec_100mhz_39&time_sec_100mhz_31&time_sec_100mhz_23&time_sec_100mhz_15&time_sec_100mhz_7;
			end if;
		end if;
	end process;

    get_time_cmplt <= get_time_oh_st(15);
	process (CLK_IN)
	begin
		if rising_edge(CLK_IN) then
			get_time_oh_st(15 downto 1) <= get_time_oh_st(14 downto 0);
			if get_time_oh_st = X"0000" then
				get_time_oh_st(0) <= get_time;
			else
				get_time_oh_st(0) <= '0';
			end if;
			if get_time_oh_st(0) = '1' then
				clk_in_set_intra_clock_registers <= '1';
			else			
				clk_in_set_intra_clock_registers <= '0';
			end if;
			if get_time_oh_st(10) = '1' then
				time_nsec <= time_nsec_intra;
				time_sec <= time_sec_intra;
			end if;
		end if;
	end process;

	process(CLK_IN)
	begin
		if rising_edge(CLK_IN) then
			do_intra_clock_set2_p <= do_intra_clock_set2;
			do_intra_clock_set2_pp <= do_intra_clock_set2_p;
			if clk_100mhz_set_intra_clock_registers2 = '1' then
				do_intra_clock_set2 <= '1';
			elsif time_invalid = '0' then
				do_intra_clock_set2 <= '0';
			end if;
			if do_intra_clock_set2_pp = '1' and time_invalid = '0' then
				time_nsec_intra2 <= slv(time_nsec_100mhz);
				time_sec_intra2 <= slv(time_sec_100mhz_47&time_sec_100mhz_39&time_sec_100mhz_31&time_sec_100mhz_23&time_sec_100mhz_15&time_sec_100mhz_7);
			end if;
		end if;
	end process;

	process(CLK_IN)
	begin
		if rising_edge(CLK_IN) then
			get_time_oh_st2(11 downto 1) <= get_time_oh_st2(10 downto 0);
			get_time2_managed <= get_time2;
			get_time2_managed_prev <= get_time2_managed;
			if get_time_oh_st2 = X"000" then
				get_time_oh_st2(0) <= (get_time2_managed and not(get_time2_managed_prev));
			else
				get_time_oh_st2(0) <= '0';
			end if;
			if get_time_oh_st2(10) = '1' then
				time_nsec2 <= slv(time_nsec_intra2);
				time_sec2 <= slv(time_sec_intra2);
			end if;
		end if;
	end process;

	process(CLK_IN)
	begin
		if rising_edge(CLK_IN) then
			send_sync_managed <= send_sync(15) or send_sync(14) or send_sync(13);
			send_sync_managed_prev <= send_sync_managed;
			if send_sync_managed_prev = '0' and send_sync_managed = '1' then
				send_sync_packet_waiting <= '1';
			else
				send_sync_packet_waiting <= '0';
			end if;
		end if;
	end process;

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
				main_st_next <= SETUP_PACKET_CHECKSUM0;

			when SETUP_PACKET_CHECKSUM0 =>
				main_st_next <= SETUP_PACKET_CHECKSUM1;
			when SETUP_PACKET_CHECKSUM1 =>
				if ip_checksum(19 downto 16) = X"0" then
					main_st_next <= SETUP_PACKET_CHECKSUM2;
				end if;
			when SETUP_PACKET_CHECKSUM2 =>
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
			tx_packet_start_addr <= C_announce_packet_start_addr;
			if main_st = SEND_FRAME0 then
				tx_packet_creation_addr_localized <= unsigned(tx_packet_start_addr);
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

	lfsr32_mod_inst : lfsr32_mod
    Port Map ( 	CLK_IN 		=> CLK_IN,
           		SEED_IN 	=> (others => '0'),
           		SEED_EN_IN 	=> '0',
           		VAL_OUT 	=> lfsr_val);

	TX_PACKET_PRE_REQ: process(CLK_IN)
	begin
		if rising_edge(CLK_IN) then
			if main_st = COMPLETE then
				sequenceID_sync_packet <= sequenceID_sync_packet + 1;
			end if;
			if main_st = SETUP_PACKET_CHECKSUM0 then
				ip_identification <= lfsr_val(15 downto 0);
			end if;
			if main_st = SETUP_PACKET_CHECKSUM0 then
				ip_checksum <= ip_checksum_base_to_use + unsigned(X"0"&lfsr_val(15 downto 0));
			elsif main_st = SETUP_PACKET_CHECKSUM1 and ip_checksum(19 downto 16) /= X"0" then
				ip_checksum <= unsigned(X"0"&ip_checksum(15 downto 0)) + unsigned(X"0000"&ip_checksum(19 downto 16));
			elsif main_st = SETUP_PACKET_CHECKSUM2 then
				ip_checksum <= not(ip_checksum);
			end if;
		end if;
	end process;

	process(CLK_IN)
	begin
		if rising_edge(CLK_IN) then
			ip_checksum_base_to_use <= ip_checksum_base_announce_packet;
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

	CRC32_calc2_Inst : CRC32_calc2 -- TODO CRC32 on incoming packets?
    Port Map (  CLOCK     => CLK_IN,
	            RESET     => '0',
	            DATA      => tx_packet_data,
	            LOAD_INIT => init_crc_calc,
	            CALC      => crc_calc_en,
	            D_VALID   => crc_data_ld,
	            CRC       => crc_value_msb,
	            CRC_REG   => crc_value,
	            CRC_VALID => crc_value_valid);

    dec_one_sec_required <= '1' when time_nsec > unsigned(C_sync_packet_lantency_ns_inv) else '0';

end Behavioral;