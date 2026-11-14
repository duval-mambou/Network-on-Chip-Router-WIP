----------------------------------------------------------------------------------
-- Company: 
-- Engineer: Duval Mambou
-- 
-- Create Date: 30.10.2026 17:35:46
-- Design Name: 
-- Module Name: port - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: 
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:-- 
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

use work.router_pkg.all;

entity port_x is
  generic (
    ROUTER_X_POS : natural;
    ROUTER_Y_POS : natural
  );
  
  Port ( 
    clk, rst_n  : in std_logic ;
    valid_in    : in std_logic ;
    pop         : in std_logic ;
    flit_in     : in flit_t ;
    flit_out    : out flit_t ;
    ready_out   : out std_logic ;
    request     : out request_t
  );
end port_x;

architecture Behavioral of port_x is
signal s_empty, s_full : std_logic ;
signal s_request_raw   : port_vec_t;
signal s_data_out : flit_t;
begin

   U_FIFO :  entity work.fifo
    port map (clk       => clk,
                rst_n   => rst_n,
                wr_en   => valid_in,
                rd_en   => pop,
                data_in => flit_in,
                data_out => s_data_out,
                empty    => s_empty,
                full     => s_full
    );
    
    U_ROUTE_COMPUTE : entity work.route_compute
        generic map (
            X_POS => ROUTER_X_POS,
            Y_POS => ROUTER_Y_POS
        )
        port map (
            flit_dest   => s_data_out(DEST_X_HI downto DEST_Y_LO ),
            request     => s_request_raw
        );
        
    ready_out <= not s_full;
    flit_out <= s_data_out;
    request <= '1' & s_request_raw  when s_empty = '0' else (others => '0');

end Behavioral;
