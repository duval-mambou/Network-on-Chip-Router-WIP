----------------------------------------------------------------------------------
-- Company: 
-- Engineer: Duval Mambou
-- 
-- Create Date: 11.11.2026 11:50:08
-- Design Name: 
-- Module Name: tb_port - Behavioral
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

entity tb_port is
end tb_port;

architecture Behavioral of tb_port is

  subtype request_t is std_logic_vector (NUM_PORTS downto 0);

  constant CLK_PERIOD   : time    := 10 ns;
  constant ROUTER_X_POS : natural := 1;
  constant ROUTER_Y_POS : natural := 3;
  constant HT           : std_logic_vector (FLIT_TYPE_WIDTH - 1 downto 0) := FLIT_HEAD_TAIL;

  -- Expected request: bit 5 = valid, bits [4:0] = one-hot destination (N,S,E,W,L)
  constant EXP_REQ_N     : request_t := "100001";
  constant EXP_REQ_S     : request_t := "100010";
  constant EXP_REQ_E     : request_t := "100100";
  constant EXP_REQ_W     : request_t := "101000";
  constant EXP_REQ_L     : request_t := "110000";
  constant EXP_REQ_EMPTY : request_t := "000000";

  signal clk       : std_logic := '0';
  signal rst_n     : std_logic := '0';
  signal valid_in  : std_logic := '0';
  signal pop       : std_logic := '0';
  signal flit_in   : flit_t    := (others => '0');
  signal flit_out  : flit_t;
  signal ready_out : std_logic;
  signal request   : request_t;
  signal done      : boolean := false;

begin

  clk <= not clk after CLK_PERIOD / 2 when not done;

  dut : entity work.port_x
    generic map (
            ROUTER_X_POS => ROUTER_X_POS, 
            ROUTER_Y_POS => ROUTER_Y_POS
            )
    port map (
            clk         => clk, 
            rst_n       => rst_n, 
            valid_in    => valid_in,
            pop         => pop,
            flit_in     => flit_in,
            flit_out    => flit_out,
            ready_out   => ready_out, 
            request     => request);

  stim : process
    variable err_cnt : natural := 0;
    variable x, y    : natural;

    -- Build a flit, following the layout from MSB to LSB
    function mk_flit (ftype   : std_logic_vector (FLIT_TYPE_WIDTH - 1 downto 0);
                      x, y    : natural;
                      payload : natural) return flit_t is
      variable f : flit_t := (others => '0');
    begin
      f(FLIT_TYPE_HI downto FLIT_TYPE_LO) := ftype;
      f(DEST_X_HI downto DEST_X_LO) := std_logic_vector(to_unsigned(x, COORD_WIDTH));
      f(DEST_Y_HI downto DEST_Y_LO) := std_logic_vector(to_unsigned(y, COORD_WIDTH));
      f(PAYLOAD_WIDTH - 1 downto 0) := std_logic_vector(to_unsigned(payload, PAYLOAD_WIDTH));
      return f;
    end function;

    -- Reference model, integer arithmetic, independent of route_compute
    function expected_req (x, y : natural) return request_t is
      variable dx : integer := x - ROUTER_X_POS;
      variable dy : integer := y - ROUTER_Y_POS;
    begin
      if    dx > 0 then return EXP_REQ_E;
      elsif dx < 0 then return EXP_REQ_W;
      elsif dy < 0 then return EXP_REQ_N;   -- Y grows southward
      elsif dy > 0 then return EXP_REQ_S;
      else              return EXP_REQ_L;
      end if;
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

    -- Inputs driven just after an edge, sampled at the next one
    procedure push (f : flit_t) is
    begin
      valid_in <= '1';
      flit_in  <= f;
      wait until rising_edge(clk);
      valid_in <= '0';
      wait for 1 ns;
    end procedure;

    procedure pop_one is
    begin
      pop <= '1';
      wait until rising_edge(clk);
      pop <= '0';
      wait for 1 ns;
    end procedure;

  begin
    ---------------------------------------------------------------
    -- Test 1: reset state
    ---------------------------------------------------------------
    report "TEST 1: reset state" severity note;
    rst_n <= '0';
    wait for 2 * CLK_PERIOD;
    check(ready_out = '1', "ready_out = 1 after reset");
    check(request = EXP_REQ_EMPTY, "request is all zeros after reset");
    wait until rising_edge(clk);
    rst_n <= '1';
    wait for 1 ns;

    -- Sanity check of mk_flit against a hand-written binary flit
    check(mk_flit(HT, 4, 3, 16#ABCDE#) = flit_t'("11" & "100" & "011" & x"0ABCDE"),
          "mk_flit matches the hand-written layout");

    ---------------------------------------------------------------
    -- Test 2: one write, head visible without pop
    ---------------------------------------------------------------
    report "TEST 2: head visible without pop" severity note;
    push(mk_flit(HT, 4, 3, 16#ABCDE#));
    check(request = EXP_REQ_E, "request = East");
    check(flit_out = mk_flit(HT, 4, 3, 16#ABCDE#), "flit_out = written flit");
    check(ready_out = '1', "ready_out = 1");

    ---------------------------------------------------------------
    -- Test 3: stability, the head must not move on its own
    ---------------------------------------------------------------
    report "TEST 3: stability" severity note;
    for i in 1 to 5 loop
      wait until rising_edge(clk);
    end loop;
    wait for 1 ns;
    check(request = EXP_REQ_E, "request unchanged after 5 cycles");
    check(flit_out = mk_flit(HT, 4, 3, 16#ABCDE#), "flit_out unchanged after 5 cycles");

    ---------------------------------------------------------------
    -- Test 4: pop
    ---------------------------------------------------------------
    report "TEST 4: pop" severity note;
    pop_one;
    check(request = EXP_REQ_EMPTY, "request cleared right after pop");

    ---------------------------------------------------------------
    -- Test 5: the five directions, hard-coded expectations
    --         (router at (1,3): neighbours, far targets, mesh edges)
    ---------------------------------------------------------------
    report "TEST 5: five directions" severity note;
    push(mk_flit(HT, 1, 3, 0)); check(request = EXP_REQ_L, "local (1,3)");            pop_one;
    push(mk_flit(HT, 2, 3, 0)); check(request = EXP_REQ_E, "east neighbour (2,3)");   pop_one;
    push(mk_flit(HT, 5, 3, 0)); check(request = EXP_REQ_E, "east edge (5,3)");        pop_one;
    push(mk_flit(HT, 4, 0, 0)); check(request = EXP_REQ_E, "east, X before Y (4,0)"); pop_one;
    push(mk_flit(HT, 0, 3, 0)); check(request = EXP_REQ_W, "west edge (0,3)");        pop_one;
    push(mk_flit(HT, 0, 5, 0)); check(request = EXP_REQ_W, "west, X before Y (0,5)"); pop_one;
    push(mk_flit(HT, 1, 2, 0)); check(request = EXP_REQ_N, "north neighbour (1,2)");  pop_one;
    push(mk_flit(HT, 1, 0, 0)); check(request = EXP_REQ_N, "north edge (1,0)");       pop_one;
    push(mk_flit(HT, 1, 4, 0)); check(request = EXP_REQ_S, "south neighbour (1,4)");  pop_one;
    push(mk_flit(HT, 1, 5, 0)); check(request = EXP_REQ_S, "south edge (1,5)");       pop_one;

    ---------------------------------------------------------------
    -- Test 6: two flits, different destinations, head drives route compute
    ---------------------------------------------------------------
    report "TEST 6: two flits" severity note;
    push(mk_flit(HT, 4, 3, 1));   -- East
    push(mk_flit(HT, 1, 0, 2));   -- North
    check(request = EXP_REQ_E, "head is the first flit: East");
    check(flit_out = mk_flit(HT, 4, 3, 1), "flit_out = first flit");
    pop_one;
    check(request = EXP_REQ_N, "after pop, head is the second flit: North");
    check(flit_out = mk_flit(HT, 1, 0, 2), "flit_out = second flit");
    pop_one;
    check(request = EXP_REQ_EMPTY, "empty after both pops");

    ---------------------------------------------------------------
    -- Test 7: filling, off-by-one on ready_out, write when full ignored
    ---------------------------------------------------------------
    report "TEST 7: filling" severity note;
    for i in 1 to FIFO_DEPTH - 1 loop
      push(mk_flit(HT, 4, 3, i));
    end loop;
    check(ready_out = '1', "ready_out = 1 with DEPTH-1 flits");
    push(mk_flit(HT, 4, 3, FIFO_DEPTH));
    check(ready_out = '0', "ready_out = 0 with DEPTH flits");
    check(request = EXP_REQ_E, "request still valid when full");
    check(flit_out = mk_flit(HT, 4, 3, 1), "head is still the first flit when full");
    push(mk_flit(HT, 1, 3, 99));   -- must be ignored
    check(ready_out = '0', "still not ready after ignored write");
    for i in 1 to FIFO_DEPTH loop
      check(flit_out = mk_flit(HT, 4, 3, i), "drain order, flit " & integer'image(i));
      pop_one;
      if i = 1 then
        check(ready_out = '1', "ready_out back to 1 after one pop");
      end if;
    end loop;
    check(request = EXP_REQ_EMPTY, "empty after drain, ignored flit never appeared");

    ---------------------------------------------------------------
    -- Test 8: pop when empty is ignored
    ---------------------------------------------------------------
    report "TEST 8: pop when empty" severity note;
    pop_one;
    check(request = EXP_REQ_EMPTY, "still empty after pop on empty FIFO");
    push(mk_flit(HT, 4, 3, 7));
    check(flit_out = mk_flit(HT, 4, 3, 7), "head is the written flit");
    check(request = EXP_REQ_E, "request = East");
    pop_one;

    ---------------------------------------------------------------
    -- Test 9: simultaneous write and pop
    ---------------------------------------------------------------
    report "TEST 9a: write + pop, one flit inside" severity note;
    push(mk_flit(HT, 4, 3, 1));            -- A, East
    valid_in <= '1'; flit_in <= mk_flit(HT, 1, 0, 2); pop <= '1';   -- B, North
    wait until rising_edge(clk);
    valid_in <= '0'; pop <= '0';
    wait for 1 ns;
    check(request = EXP_REQ_N, "head is B after simultaneous write/pop");
    check(flit_out = mk_flit(HT, 1, 0, 2), "flit_out = B");
    pop_one;
    check(request = EXP_REQ_EMPTY, "empty after popping B");

    report "TEST 9b: write + pop on empty FIFO" severity note;
    valid_in <= '1'; flit_in <= mk_flit(HT, 1, 3, 3); pop <= '1';   -- C, Local
    wait until rising_edge(clk);
    valid_in <= '0'; pop <= '0';
    wait for 1 ns;
    check(request = EXP_REQ_L, "write accepted, pop ignored");
    check(flit_out = mk_flit(HT, 1, 3, 3), "flit_out = C");
    pop_one;

    report "TEST 9c: write + pop on full FIFO" severity note;
    for i in 1 to FIFO_DEPTH loop
      push(mk_flit(HT, 4, 3, i));
    end loop;
    valid_in <= '1'; flit_in <= mk_flit(HT, 1, 3, 99); pop <= '1';  -- write must be refused
    wait until rising_edge(clk);
    valid_in <= '0'; pop <= '0';
    wait for 1 ns;
    check(ready_out = '1', "pop accepted, write refused: not full anymore");
    for i in 2 to FIFO_DEPTH loop
      check(flit_out = mk_flit(HT, 4, 3, i), "drain after 9c, flit " & integer'image(i));
      pop_one;
    end loop;
    check(request = EXP_REQ_EMPTY, "empty, refused flit never appeared");

    ---------------------------------------------------------------
    -- Test 10: pointer wrap-around, 3 x DEPTH flits, varied destinations
    ---------------------------------------------------------------
    report "TEST 10: wrap-around" severity note;
    for i in 0 to 3 * FIFO_DEPTH - 1 loop
      x := i mod 6;
      y := (i / 2) mod 6;
      push(mk_flit(HT, x, y, i));
      check(request = expected_req(x, y), "wrap, request, flit " & integer'image(i));
      check(flit_out = mk_flit(HT, x, y, i), "wrap, flit_out, flit " & integer'image(i));
      pop_one;
    end loop;

    ---------------------------------------------------------------
    -- Test 11: flit_type and payload must not influence the route
    ---------------------------------------------------------------
    report "TEST 11: type and payload ignored" severity note;
    push(mk_flit("00", 4, 3, 16#000000#)); check(request = EXP_REQ_E, "type 00, payload 000000"); pop_one;
    push(mk_flit("01", 4, 3, 16#FFFFFF#)); check(request = EXP_REQ_E, "type 01, payload FFFFFF"); pop_one;
    push(mk_flit("10", 4, 3, 16#AAAAAA#)); check(request = EXP_REQ_E, "type 10, payload AAAAAA"); pop_one;
    push(mk_flit("11", 4, 3, 16#555555#)); check(request = EXP_REQ_E, "type 11, payload 555555"); pop_one;
    -- hand-written binary flit: type 00, dest (0,3) = West, payload all ones
    push(flit_t'("00" & "000" & "011" & x"FFFFFF"));
    check(request = EXP_REQ_W, "hand-written flit: West");
    pop_one;

    ---------------------------------------------------------------
    -- Test 12: exhaustive, all 36 destinations of the 6x6 mesh
    ---------------------------------------------------------------
    report "TEST 12: exhaustive" severity note;
    for xx in 0 to 5 loop
      for yy in 0 to 5 loop
        push(mk_flit(HT, xx, yy, xx * 6 + yy));
        check(request = expected_req(xx, yy),
              "dest (" & integer'image(xx) & "," & integer'image(yy) & ")");
        check(flit_out = mk_flit(HT, xx, yy, xx * 6 + yy), "flit_out matches");
        pop_one;
      end loop;
    end loop;

    ---------------------------------------------------------------
    -- Test 13: asynchronous reset in the middle of operation
    --          n = 1: half full, n = 2: full
    ---------------------------------------------------------------
    report "TEST 13: asynchronous reset" severity note;
    for n in 1 to 2 loop
      for i in 1 to FIFO_DEPTH * n / 2 loop
        push(mk_flit(HT, 4, 3, i));
      end loop;
      wait for 2 ns;                       -- 3 ns after the clock edge
      rst_n <= '0';
      wait for 1 ns;                       -- no clock edge in between
      check(ready_out = '1', "ready_out = 1 immediately, reset case " & integer'image(n));
      check(request = EXP_REQ_EMPTY, "request cleared immediately, reset case " & integer'image(n));
      wait until rising_edge(clk);
      wait for 1 ns;
      rst_n <= '1';
      wait for 1 ns;
      check(request = EXP_REQ_EMPTY, "still empty after reset release, case " & integer'image(n));
      push(mk_flit(HT, 2, 3, 5));
      check(flit_out = mk_flit(HT, 2, 3, 5), "no old flit after reset, case " & integer'image(n));
      check(request = EXP_REQ_E, "new flit routed, case " & integer'image(n));
      pop_one;
    end loop;

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

end Behavioral;
