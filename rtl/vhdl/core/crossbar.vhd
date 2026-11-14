----------------------------------------------------------------------------------
-- Company: 
-- Engineer: Duval Mambou
-- 
-- Create Date: 13.11.2026 21:20:08
-- Design Name: 
-- Module Name: crossbar - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
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

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

use work.router_pkg.all;

entity crossbar is
  Port ( 
        flit_N, flit_S, flit_E, flit_W, flit_L : in flit_t;
        grant_N, grant_S, grant_E, grant_W, grant_L : in port_vec_t;
        flit_out_N, flit_out_S, flit_out_E, flit_out_W, flit_out_L : out flit_t;
        valid_out_N, valid_out_S, valid_out_E, valid_out_W, valid_out_L : out std_logic
    );
end crossbar;

architecture Behavioral of crossbar is

    constant GRANT_NULL : port_vec_t := "00000";

begin

    Mux_N : entity work.mux_crossbar
        port map (
                flit_N   => flit_N, 
                flit_S   => flit_S, 
                flit_E   => flit_E, 
                flit_W   => flit_W, 
                flit_L   => flit_L,
                grant    => grant_N,
                flit_out => flit_out_N
            );
            
    Mux_S : entity work.mux_crossbar
        port map (
                flit_N   => flit_N, 
                flit_S   => flit_S, 
                flit_E   => flit_E, 
                flit_W   => flit_W, 
                flit_L   => flit_L,
                grant    => grant_S,
                flit_out => flit_out_S
            );
            
    Mux_E : entity work.mux_crossbar
        port map (
                flit_N   => flit_N, 
                flit_S   => flit_S, 
                flit_E   => flit_E, 
                flit_W   => flit_W, 
                flit_L   => flit_L,
                grant    => grant_E,
                flit_out => flit_out_E
            );
            
    Mux_W : entity work.mux_crossbar
        port map (
                flit_N   => flit_N, 
                flit_S   => flit_S, 
                flit_E   => flit_E, 
                flit_W   => flit_W, 
                flit_L   => flit_L,
                grant    => grant_W,
                flit_out => flit_out_W
            );
            
    Mux_L : entity work.mux_crossbar
        port map (
                flit_N   => flit_N, 
                flit_S   => flit_S, 
                flit_E   => flit_E, 
                flit_W   => flit_W, 
                flit_L   => flit_L,
                grant    => grant_L,
                flit_out => flit_out_L
            );
            
    valid_out_N <= '1' when grant_N /= GRANT_NULL else '0'; 
    valid_out_S <= '1' when grant_S /= GRANT_NULL else '0';
    valid_out_E <= '1' when grant_E /= GRANT_NULL else '0';
    valid_out_W <= '1' when grant_W /= GRANT_NULL else '0';
    valid_out_L <= '1' when grant_L /= GRANT_NULL else '0'; 

end Behavioral;

