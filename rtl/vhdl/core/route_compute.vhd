----------------------------------------------------------------------------------
-- Company: 
-- Engineer: Duval Mambou
-- 
-- Create Date: 30.10.2026 15:59:38
-- Design Name: 
-- Module Name: route_compute - Behavioral
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
use work.router_pkg.all;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.router_pkg.all;

entity route_compute is
  generic (
    X_POS : natural;
    Y_POS : natural
  );
  port (
    flit_dest : in  std_logic_vector (2 * COORD_WIDTH - 1 downto 0);  -- dest_x & dest_y
    request   : out port_vec_t
  );
end entity route_compute;

architecture Behavioral of route_compute is
begin
  process (flit_dest)
    variable dest_x, dest_y : unsigned (COORD_WIDTH - 1 downto 0);
  begin
    dest_x := unsigned(flit_dest(2 * COORD_WIDTH - 1 downto COORD_WIDTH));
    dest_y := unsigned(flit_dest(COORD_WIDTH - 1 downto 0));

    request <= (others => '0');            -- default value: avoids a latch

    if    dest_x > X_POS then request(PORT_E) <= '1';
    elsif dest_x < X_POS then request(PORT_W) <= '1';
    elsif dest_y < Y_POS then request(PORT_N) <= '1';  -- Y grows southward
    elsif dest_y > Y_POS then request(PORT_S) <= '1';
    else                      request(PORT_L) <= '1';  -- dest = this router
    end if;
  end process;
end architecture Behavioral;
