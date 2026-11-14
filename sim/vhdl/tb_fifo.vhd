----------------------------------------------------------------------------------
-- Company: 
-- Engineer: Duval Mambou
-- 
-- Create Date: 11.10.2026 11:40:43
-- Design Name: 
-- Module Name: tb_fifo - Behavioral
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

entity tb_fifo is
end entity tb_fifo;

architecture Behavioral of tb_fifo is

  constant CLK_PERIOD : time     := 10 ns;
  constant DEPTH_TB   : positive := FIFO_DEPTH;  -- test assumes DEPTH >= 4

  signal clk      : std_logic := '0';
  signal rst_n    : std_logic := '0';
  signal wr_en    : std_logic := '0';
  signal rd_en    : std_logic := '0';
  signal data_in  : flit_t    := (others => '0');
  signal data_out : flit_t;
  signal empty    : std_logic;
  signal full     : std_logic;

  signal done : boolean := false;

begin

  -- Clock generation (stops when the test is done)
  clk <= not clk after CLK_PERIOD / 2 when not done;

  -- Device under test
  dut : entity work.fifo
    generic map (DEPTH => DEPTH_TB)
    port map (
      clk      => clk,
      rst_n    => rst_n,
      wr_en    => wr_en,
      rd_en    => rd_en,
      data_in  => data_in,
      data_out => data_out,
      empty    => empty,
      full     => full
    );

  stim : process

    variable err_cnt : natural := 0;

    -- Build a recognizable flit from an integer
    function mk_flit (n : natural) return flit_t is
    begin
      return std_logic_vector(to_unsigned(n, FLIT_WIDTH));
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

    -- Write one flit (inputs are driven after an edge, sampled at the next)
    procedure push (n : natural) is
    begin
      wr_en   <= '1';
      data_in <= mk_flit(n);
      wait until rising_edge(clk);
      wr_en   <= '0';
      wait for 1 ns;
    end procedure;

    -- Check the head WITHOUT popping, then pop it
    procedure pop_check (n : natural) is
    begin
      check(data_out = mk_flit(n), "head value is " & integer'image(n));
      rd_en <= '1';
      wait until rising_edge(clk);
      rd_en <= '0';
      wait for 1 ns;
    end procedure;

  begin
    ---------------------------------------------------------------
    -- Test 1: reset state
    ---------------------------------------------------------------
    report "TEST 1: reset state" severity note;
    rst_n <= '0';
    wait for 2 * CLK_PERIOD;
    check(empty = '1', "empty after reset");
    check(full  = '0', "not full after reset");
    wait until rising_edge(clk);
    rst_n <= '1';
    wait for 1 ns;

    ---------------------------------------------------------------
    -- Test 2: fill until full
    ---------------------------------------------------------------
    report "TEST 2: fill until full" severity note;
    for i in 1 to DEPTH_TB loop
      push(i);
    end loop;
    check(full  = '1', "full after DEPTH writes");
    check(empty = '0', "not empty after DEPTH writes");

    ---------------------------------------------------------------
    -- Test 3: write while full is ignored, then drain in order
    ---------------------------------------------------------------
    report "TEST 3: write when full ignored, FIFO order" severity note;
    push(99);                                  -- must be ignored
    check(full = '1', "still full after ignored write");
    for i in 1 to DEPTH_TB loop
      pop_check(i);                            -- 99 must never appear
    end loop;
    check(empty = '1', "empty after full drain");
    check(full  = '0', "not full after full drain");

    ---------------------------------------------------------------
    -- Test 4: read while empty is ignored
    ---------------------------------------------------------------
    report "TEST 4: read when empty ignored" severity note;
    rd_en <= '1';
    wait until rising_edge(clk);
    rd_en <= '0';
    wait for 1 ns;
    check(empty = '1', "still empty after ignored read");
    push(5);
    check(empty = '0', "not empty after one write");
    pop_check(5);
    check(empty = '1', "empty again");

    ---------------------------------------------------------------
    -- Test 5: simultaneous read and write (neither empty nor full)
    ---------------------------------------------------------------
    report "TEST 5: simultaneous read and write" severity note;
    push(10);
    push(11);
    wr_en   <= '1';
    data_in <= mk_flit(12);
    rd_en   <= '1';
    wait until rising_edge(clk);
    wr_en <= '0';
    rd_en <= '0';
    wait for 1 ns;
    check(empty = '0' and full = '0', "occupancy unchanged (2 flits)");
    pop_check(11);                             -- 10 was consumed by the read
    pop_check(12);
    check(empty = '1', "empty after draining");

    ---------------------------------------------------------------
    -- Test 6: simultaneous read and write while full
    --         the write must be refused, the read accepted
    ---------------------------------------------------------------
    report "TEST 6: simultaneous rd/wr when full" severity note;
    for i in 1 to DEPTH_TB loop
      push(100 + i);
    end loop;
    check(full = '1', "full before simultaneous access");
    wr_en   <= '1';
    data_in <= mk_flit(999);
    rd_en   <= '1';
    wait until rising_edge(clk);
    wr_en <= '0';
    rd_en <= '0';
    wait for 1 ns;
    check(full = '0', "not full: read accepted, write refused");
    for i in 2 to DEPTH_TB loop
      pop_check(100 + i);                      -- 999 must never appear
    end loop;
    check(empty = '1', "empty after draining");

    ---------------------------------------------------------------
    -- Test 7: pointer wrap-around (many more flits than DEPTH)
    ---------------------------------------------------------------
    report "TEST 7: pointer wrap-around" severity note;
    push(1);
    push(2);
    push(3);
    for i in 4 to 3 * DEPTH_TB + 3 loop
      push(i);
      pop_check(i - 3);
    end loop;
    pop_check(3 * DEPTH_TB + 1);
    pop_check(3 * DEPTH_TB + 2);
    pop_check(3 * DEPTH_TB + 3);
    check(empty = '1', "empty at the end of wrap test");

    ---------------------------------------------------------------
    -- Summary
    ---------------------------------------------------------------
    if err_cnt = 0 then
      report "ALL TESTS PASSED" severity note;
    else
      report "TESTS FAILED: " & integer'image(err_cnt) & " error(s)"
        severity error;
    end if;

    done <= true;
    wait;
  end process stim;

end architecture Behavioral;
