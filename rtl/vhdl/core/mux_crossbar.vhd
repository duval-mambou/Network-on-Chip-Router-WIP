----------------------------------------------------------------------------------
-- Company: 
-- Engineer: Duval Mambou
-- 
-- Create Date: 13.11.2026 22:21:45
-- Design Name: 
-- Module Name: mux_crossbar - Behavioral
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

entity mux_crossbar is
    port (
        flit_N, flit_S, flit_E, flit_W, flit_L : in flit_t;
        grant : in port_vec_t;
        flit_out : out flit_t
        );
end mux_crossbar;

architecture Arch of mux_crossbar is

constant GRANT_N : port_vec_t := "00001";
constant GRANT_S : port_vec_t := "00010";
constant GRANT_E : port_vec_t := "00100";
constant GRANT_W : port_vec_t := "01000";
constant GRANT_L : port_vec_t := "10000";

constant FLIT_NULL : flit_t := (others => '0');

begin
    flit_out <= flit_N when grant = GRANT_N else
                flit_S when grant = GRANT_S else
                flit_E when grant = GRANT_E else
                flit_W when grant = GRANT_W else
                flit_L when grant = GRANT_L else
                FLIT_NULL;
end Arch;
        

