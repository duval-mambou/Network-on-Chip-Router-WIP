----------------------------------------------------------------------------------
-- Company: 
-- Engineer: Duval Mambou
-- 
-- Create Date: 30.10.2026 16:51:06
-- Design Name: 
-- Module Name: tb_route_compute - Behavioral
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
use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

use work.router_pkg.all;

entity tb_route_compute is
end entity tb_route_compute;

architecture Behavioral of tb_route_compute is
  constant X_POS : natural := 2;
  constant Y_POS : natural := 3;

  -- Expected one-hot codes (bit 0 on the right: N=0, S=1, E=2, W=3, L=4)
  constant EXP_N : port_vec_t := "00001";
  constant EXP_S : port_vec_t := "00010";
  constant EXP_E : port_vec_t := "00100";
  constant EXP_W : port_vec_t := "01000";
  constant EXP_L : port_vec_t := "10000";

  signal flit_dest : std_logic_vector (2 * COORD_WIDTH - 1 downto 0) := (others => '0');
  signal request   : port_vec_t;
begin

  dut : entity work.route_compute
    generic map (X_POS => X_POS, Y_POS => Y_POS)
    port map (flit_dest => flit_dest, request => request);

  sim : process
    variable err_cnt : natural := 0;

    procedure check (cond : boolean; msg : string) is
    begin
      if cond then
        report "PASS: " & msg severity note;
      else
        report "FAIL: " & msg severity error;
        err_cnt := err_cnt + 1;
      end if;
    end procedure;

    -- Drive a destination, let the logic settle, then compare
    procedure apply (x, y : natural; expected : port_vec_t; msg : string) is
    begin
      flit_dest <= std_logic_vector(to_unsigned(x, COORD_WIDTH)) &
                   std_logic_vector(to_unsigned(y, COORD_WIDTH));
      wait for 10 ns;
      check(request = expected, msg);
    end procedure;

  begin
    report "Router at (" & integer'image(X_POS) & "," & integer'image(Y_POS) & ")" severity note;

    apply(2, 3, EXP_L, "local destination (2,3)");
    apply(4, 3, EXP_E, "east, same row (4,3)");
    apply(4, 0, EXP_E, "east, different row (4,0): X before Y");
    apply(0, 3, EXP_W, "west, same row (0,3)");
    apply(0, 5, EXP_W, "west, different row (0,5): X before Y");
    apply(2, 0, EXP_N, "north (2,0)");
    apply(2, 5, EXP_S, "south (2,5)");
    -- immediate neighbours
    apply(3, 3, EXP_E, "neighbour east (3,3)");
    apply(1, 3, EXP_W, "neighbour west (1,3)");
    apply(2, 2, EXP_N, "neighbour north (2,2)");
    apply(2, 4, EXP_S, "neighbour south (2,4)");

    if err_cnt = 0 then
      report "ALL TESTS PASSED" severity note;
    else
      report "TESTS FAILED: " & integer'image(err_cnt) & " error(s)" severity error;
    end if;

    wait;   -- stop the process (otherwise it loops forever)
  end process sim;

end architecture Behavioral;
