----------------------------------------------------------------------------------
-- Company: 
-- Engineer: Duval Mambou
-- 
-- Create Date: 13.11.2026 18:57:14
-- Design Name: 
-- Module Name: tb_arbiter - Behavioral
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

entity tb_arbiter is
end entity tb_arbiter;

architecture Behavioral of tb_arbiter is
  constant CLK_PERIOD : time := 10 ns;

  signal clk       : std_logic := '0';
  signal rst_n     : std_logic := '0';
  signal request_x : requestors_vec_t := (others => '0');
  signal grant_a_x : requestors_vec_t;
  signal done      : boolean := false;
begin

  clk <= not clk after CLK_PERIOD / 2 when not done;

  dut : entity work.arbiter_x
    port map (clk => clk, rst_n => rst_n,
              request_x => request_x, grant_a_x => grant_a_x);

  stim : process
    variable err_cnt : natural := 0;
    variable exp     : requestors_vec_t;
    variable r       : requestors_vec_t;

    function onehot (i : natural) return requestors_vec_t is
      variable v : requestors_vec_t := (others => '0');
    begin
      v(i mod NUM_REQUESTORS) := '1';
      return v;
    end function;

    -- Reference model: p = last winner, the winner is the first requester
    -- after p in the cyclic order (p+1, p+2, ..., p). Written as a search,
    -- independently of the mask + fallback structure of the DUT.
    function model (p : natural; req : requestors_vec_t) return requestors_vec_t is
      variable g   : requestors_vec_t := (others => '0');
      variable idx : natural;
    begin
      for k in 1 to NUM_REQUESTORS loop
        idx := (p + k) mod NUM_REQUESTORS;
        if req(idx) = '1' then
          g(idx) := '1';
          return g;
        end if;
      end loop;
      return g;
    end function;

    procedure check (cond : boolean; msg : string) is
    begin
      if cond then
        report "PASS: " & msg severity note;
      else
        report "FAIL: " & msg severity error;
        err_cnt := err_cnt + 1;
      end if;
    end procedure;

    -- One clock cycle: drive the request just after an edge, check the
    -- (combinational) grant and the three properties, then pass the next edge
    procedure step (req, e : requestors_vec_t; msg : string) is
      variable ones : natural := 0;
    begin
      request_x <= req;
      wait for 1 ns;
      check(grant_a_x = e, msg & ": unexpected grant");
      for i in 0 to NUM_REQUESTORS - 1 loop
        if grant_a_x(i) = '1' then
          ones := ones + 1;
        end if;
      end loop;
      check(ones <= 1, msg & ": grant is not one-hot");
      check((grant_a_x and not req) = "0000", msg & ": grant given to a non-requester");
      check(req = "0000" or grant_a_x /= "0000", msg & ": a requester must always win");
      wait until rising_edge(clk);
      wait for 1 ns;
    end procedure;

  begin
    ---------------------------------------------------------------
    -- Test 1: reset, no request. After reset the pointer is "1000"
    ---------------------------------------------------------------
    report "TEST 1: reset, no request" severity note;
    rst_n <= '0';
    wait for 2 * CLK_PERIOD;
    check(grant_a_x = "0000", "no grant during reset with no request");
    wait until rising_edge(clk);
    rst_n <= '1';
    wait for 1 ns;
    step("0000", "0000", "no request");                    -- P = 3

    ---------------------------------------------------------------
    -- Test 2: first winner after reset is requester 0
    ---------------------------------------------------------------
    report "TEST 2: first grant after reset" severity note;
    step("1111", "0001", "all request after reset");       -- P = 0

    ---------------------------------------------------------------
    -- Test 3: a lone requester wins every cycle (fallback path)
    ---------------------------------------------------------------
    report "TEST 3: lone requester" severity note;
    for i in 0 to NUM_REQUESTORS - 1 loop
      for c in 1 to 3 loop
        step(onehot(i), onehot(i), "lone requester " & integer'image(i));
      end loop;
    end loop;                                              -- P = 3

    ---------------------------------------------------------------
    -- Test 4: P is unchanged when nobody requests
    ---------------------------------------------------------------
    report "TEST 4: pointer held without request" severity note;
    step("0010", "0010", "requester 1 wins");              -- P = 1
    for c in 1 to 3 loop
      step("0000", "0000", "idle cycle");
    end loop;
    step("1111", "0100", "requester 2 must follow 1");     -- P = 2

    ---------------------------------------------------------------
    -- Test 5: fairness, 3 full rounds with everybody requesting
    ---------------------------------------------------------------
    report "TEST 5: fairness" severity note;
    step("0001", "0001", "steer P to 0");                  -- P = 0
    for i in 0 to 3 * NUM_REQUESTORS - 1 loop
      step("1111", onehot(i + 1), "round-robin cycle " & integer'image(i));
    end loop;                                              -- P = 0

    ---------------------------------------------------------------
    -- Test 6: requesters 0 and 3 only, grants must alternate
    ---------------------------------------------------------------
    report "TEST 6: two requesters alternate" severity note;
    for i in 0 to 5 loop
      if i mod 2 = 0 then
        step("1001", "1000", "alternation, requester 3");
      else
        step("1001", "0001", "alternation, requester 0 (P = 3, empty mask)");
      end if;
    end loop;                                              -- P = 0

    ---------------------------------------------------------------
    -- Test 7: the last winner must not overtake a waiting requester
    ---------------------------------------------------------------
    report "TEST 7: last winner does not overtake" severity note;
    step("0100", "0100", "steer P to 2");                  -- P = 2
    step("0101", "0001", "P = 2, requesters 0 and 2");     -- P = 0

    ---------------------------------------------------------------
    -- Test 8: P = 3, empty mask, fallback to the lowest requester
    ---------------------------------------------------------------
    report "TEST 8: P = 3 fallback" severity note;
    step("1000", "1000", "steer P to 3");                  -- P = 3
    step("0110", "0010", "P = 3, requesters 1 and 2");     -- P = 1

    ---------------------------------------------------------------
    -- Test 9: a requester withdraws its request
    ---------------------------------------------------------------
    report "TEST 9: request withdrawn" severity note;
    step("0001", "0001", "steer P to 0");                  -- P = 0
    step("0110", "0010", "1 wins, 2 waits");               -- P = 1
    step("0100", "0100", "1 withdrew, 2 wins");            -- P = 2
    step("0000", "0000", "everybody withdrew");

    ---------------------------------------------------------------
    -- Test 10: exhaustive, every P combined with every request vector
    ---------------------------------------------------------------
    report "TEST 10: exhaustive" severity note;
    for p in 0 to NUM_REQUESTORS - 1 loop
      for v in 0 to 2 ** NUM_REQUESTORS - 1 loop
        step(onehot(p), onehot(p), "steer to P = " & integer'image(p));
        r := std_logic_vector(to_unsigned(v, NUM_REQUESTORS));
        step(r, model(p, r),
             "exhaustive P = " & integer'image(p) & ", req = " & integer'image(v));
      end loop;
    end loop;

    ---------------------------------------------------------------
    -- Test 11: asynchronous reset in the middle of operation
    ---------------------------------------------------------------
    report "TEST 11: asynchronous reset" severity note;
    step("0001", "0001", "steer P to 0");                  -- P = 0
    wait for 2 ns;                                         -- 3 ns after the edge
    request_x <= "1111";
    rst_n     <= '0';
    wait for 1 ns;                                         -- no clock edge in between
    -- without the reset, P = 0 would give "0010"
    check(grant_a_x = "0001", "reset acts immediately: P back to 3, grant = 0001");
    wait until rising_edge(clk);
    wait for 1 ns;
    rst_n <= '1';
    step("1111", "0001", "first grant after reset release");   -- P = 0
    step("1111", "0010", "normal operation resumes");

    ---------------------------------------------------------------
    -- Summary
    ---------------------------------------------------------------
    if err_cnt = 0 then
      report "ALL TESTS PASSED" severity note;
    else
      report "TESTS FAILED: " & integer'image(err_cnt) & " error(s)" severity error;
    end if;
    done <= true;
    wait;
  end process stim;

end architecture Behavioral;
