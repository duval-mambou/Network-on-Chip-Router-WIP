----------------------------------------------------------------------------------
-- Company: 
-- Engineer: Duval Mambou
-- 
-- Create Date: 13.11.2026 18:31:45
-- Design Name: 
-- Module Name: tb_priority_encoder - Behavioral
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

entity tb_priority_encoder is
end entity tb_priority_encoder;

architecture Behavioral of tb_priority_encoder is

  signal request : requestors_vec_t := (others => '0');
  signal grant   : requestors_vec_t;
  
begin

  dut : entity work.priority_encoder
    port map (request => request, grant => grant);

  stim : process
    variable err_cnt : natural := 0;
    variable exp     : requestors_vec_t;
    variable found   : boolean;
    variable ones    : natural;

    procedure check (cond : boolean; msg : string) is
    begin
      if not cond then
        report "FAIL: " & msg severity error;
        err_cnt := err_cnt + 1;
      end if;
    end procedure;

  begin
    -- Exhaustive: every possible request vector
    for v in 0 to 2 ** NUM_REQUESTORS - 1 loop
      request <= std_logic_vector(to_unsigned(v, NUM_REQUESTORS));
      wait for 10 ns;

      -- Reference model: scan from index 0, keep the first bit set
      exp   := (others => '0');
      found := false;
      for i in 0 to NUM_REQUESTORS - 1 loop
        if request(i) = '1' and not found then
          exp(i) := '1';
          found  := true;
        end if;
      end loop;

      ones := 0;
      for i in 0 to NUM_REQUESTORS - 1 loop
        if grant(i) = '1' then
          ones := ones + 1;
        end if;
      end loop;

      check(grant = exp, "wrong grant for request = " & integer'image(v));
      check(ones <= 1,   "grant not one-hot for request = " & integer'image(v));
      check((grant and not request) = "0000",
            "grant on a non-requester for request = " & integer'image(v));
    end loop;

    if err_cnt = 0 then
      report "ALL TESTS PASSED" severity note;
    else
      report "TESTS FAILED: " & integer'image(err_cnt) & " error(s)" severity error;
    end if;
    wait;
  end process stim;

end architecture Behavioral;
