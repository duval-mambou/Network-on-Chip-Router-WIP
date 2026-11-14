----------------------------------------------------------------------------------
-- Company: 
-- Engineer: Duval Mambou
-- 
-- Create Date: 13.11.2026 21:13:36
-- Design Name: 
-- Module Name: tb_switch_allocator - Behavioral
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

entity tb_switch_allocator is
end entity tb_switch_allocator;

architecture Behavioral of tb_switch_allocator is

  constant CLK_PERIOD : time := 10 ns;

  subtype req_t is std_logic_vector (NUM_PORTS downto 0);
  type req_arr_t is array (0 to NUM_PORTS - 1) of req_t;
  type gr_arr_t  is array (0 to NUM_PORTS - 1) of port_vec_t;

  constant ZERO_G : gr_arr_t := (others => (others => '0'));
  constant NAMES  : string (1 to 5) := "NSEWL";   -- index = port number (N=0 ... L=4)

  signal clk   : std_logic := '0';
  signal rst_n : std_logic := '0';
  signal req   : req_arr_t := (others => (others => '0'));
  signal rdy   : std_logic_vector (NUM_PORTS - 1 downto 0) := (others => '1');
  signal g     : gr_arr_t;
  signal pp    : std_logic_vector (NUM_PORTS - 1 downto 0);
  signal done  : boolean := false;

begin

  clk <= not clk after CLK_PERIOD / 2 when not done;

  dut : entity work.switch_allocator
    port map (
      clk => clk, rst_n => rst_n,
      ready_in_N => rdy(PORT_N), ready_in_S => rdy(PORT_S), ready_in_E => rdy(PORT_E),
      ready_in_W => rdy(PORT_W), ready_in_L => rdy(PORT_L),
      request_N => req(PORT_N), request_S => req(PORT_S), request_E => req(PORT_E),
      request_W => req(PORT_W), request_L => req(PORT_L),
      grant_N => g(PORT_N), grant_S => g(PORT_S), grant_E => g(PORT_E),
      grant_W => g(PORT_W), grant_L => g(PORT_L),
      pop_N => pp(PORT_N), pop_S => pp(PORT_S), pop_E => pp(PORT_E),
      pop_W => pp(PORT_W), pop_L => pp(PORT_L));

  stim : process
    variable err_cnt : natural := 0;
    variable eg      : gr_arr_t;      -- expected grants
    variable w       : natural;

    function onehot (i : natural) return port_vec_t is
      variable v : port_vec_t := (others => '0');
    begin
      v(i) := '1';
      return v;
    end function;

    -- A valid request toward output o: bit 5 = valid, bits [4:0] = one-hot destination
    function mk_req (o : natural) return req_t is
    begin
      return '1' & onehot(o);
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

    -- No request, every neighbour ready
    procedure idle is
    begin
      req <= (others => (others => '0'));
      rdy <= (others => '1');
    end procedure;

    -- Next clock edge, then 1 ns later (inputs are driven just after an edge)
    procedure tick is
    begin
      wait until rising_edge(clk);
      wait for 1 ns;
    end procedure;

    procedure do_reset is
    begin
      rst_n <= '0';
      wait for 2 * CLK_PERIOD;
      wait until rising_edge(clk);
      rst_n <= '1';
      wait for 1 ns;
    end procedure;

    -- Outputs are combinational: wait 1 ns, then compare with the expected
    -- grants and check the properties that must hold at every cycle
    procedure verify (eg : gr_arr_t; msg : string) is
      variable ones     : natural;
      variable or_grant : std_logic;
      variable exp_pop  : std_logic;
    begin
      wait for 1 ns;
      for x in 0 to NUM_PORTS - 1 loop
        check(g(x) = eg(x), msg & ": grant_" & NAMES(x + 1));
        check(g(x)(x) = '0', msg & ": grant_" & NAMES(x + 1) & " has no bit on its own port");
        ones := 0;
        for p in 0 to NUM_PORTS - 1 loop
          if g(x)(p) = '1' then
            ones := ones + 1;
            check(req(p)(x) = '1' and req(p)(VALID_REQ_POS) = '1' and rdy(x) = '1',
                  msg & ": grant_" & NAMES(x + 1) & " only for a valid request with ready_in");
          end if;
        end loop;
        check(ones <= 1, msg & ": grant_" & NAMES(x + 1) & " is one-hot");
      end loop;
      for p in 0 to NUM_PORTS - 1 loop
        or_grant := '0';
        exp_pop  := '0';
        for x in 0 to NUM_PORTS - 1 loop
          or_grant := or_grant or g(x)(p);
          exp_pop  := exp_pop or eg(x)(p);
        end loop;
        check(pp(p) = or_grant, msg & ": pop_" & NAMES(p + 1) & " = OR of the grants");
        check(pp(p) = exp_pop,  msg & ": pop_" & NAMES(p + 1) & " as expected");
      end loop;
    end procedure;

  begin
    ---------------------------------------------------------------
    -- Test 1: reset, no request
    ---------------------------------------------------------------
    report "TEST 1: reset, no request" severity note;
    idle;
    rst_n <= '0';
    wait for 2 * CLK_PERIOD;
    verify(ZERO_G, "during reset");
    wait until rising_edge(clk);
    rst_n <= '1';
    wait for 1 ns;
    verify(ZERO_G, "after reset");
    tick;

    ---------------------------------------------------------------
    -- Test 2: the 20 pairs (p, x), p /= x, one request, all ready_in = 1
    ---------------------------------------------------------------
    report "TEST 2: the 20 (port, output) pairs" severity note;
    for p in 0 to NUM_PORTS - 1 loop
      for x in 0 to NUM_PORTS - 1 loop
        if p /= x then
          idle;
          req(p) <= mk_req(x);
          eg := ZERO_G;
          eg(x)(p) := '1';
          verify(eg, "pair " & NAMES(p + 1) & "->" & NAMES(x + 1));
          tick;
        end if;
      end loop;
    end loop;

    ---------------------------------------------------------------
    -- Test 3: the request is there but ready_in of the output is 0
    ---------------------------------------------------------------
    report "TEST 3: ready_in = 0 blocks the request" severity note;
    for p in 0 to NUM_PORTS - 1 loop
      for x in 0 to NUM_PORTS - 1 loop
        if p /= x then
          idle;
          rdy(x) <= '0';
          req(p) <= mk_req(x);
          verify(ZERO_G, "blocked " & NAMES(p + 1) & "->" & NAMES(x + 1));
          tick;
        end if;
      end loop;
    end loop;

    ---------------------------------------------------------------
    -- Test 4: the pointer must not move while ready_in = 0
    --         N and S want E, ready_in_E = 1,0,1,0,1,0
    ---------------------------------------------------------------
    report "TEST 4: pointer held while ready_in = 0" severity note;
    do_reset;
    idle;
    req(PORT_N) <= mk_req(PORT_E);
    req(PORT_S) <= mk_req(PORT_E);
    for c in 0 to 5 loop
      eg := ZERO_G;
      if c mod 2 = 0 then
        rdy(PORT_E) <= '1';
        if c = 2 then
          eg(PORT_E)(PORT_S) := '1';
        else
          eg(PORT_E)(PORT_N) := '1';
        end if;
      else
        rdy(PORT_E) <= '0';
      end if;
      verify(eg, "alternating ready_in, cycle " & integer'image(c));
      tick;
    end loop;

    ---------------------------------------------------------------
    -- Test 5: permutation without conflict, 5 grants in one cycle
    --         N->E, S->W, E->L, W->N, L->S
    ---------------------------------------------------------------
    report "TEST 5: permutation, 5 simultaneous transfers" severity note;
    idle;
    req(PORT_N) <= mk_req(PORT_E);
    req(PORT_S) <= mk_req(PORT_W);
    req(PORT_E) <= mk_req(PORT_L);
    req(PORT_W) <= mk_req(PORT_N);
    req(PORT_L) <= mk_req(PORT_S);
    eg := ZERO_G;
    eg(PORT_E)(PORT_N) := '1';
    eg(PORT_W)(PORT_S) := '1';
    eg(PORT_L)(PORT_E) := '1';
    eg(PORT_N)(PORT_W) := '1';
    eg(PORT_S)(PORT_L) := '1';
    verify(eg, "permutation");
    tick;

    ---------------------------------------------------------------
    -- Test 6: three ports want E, fair rotation N, S, W, then N again
    ---------------------------------------------------------------
    report "TEST 6: conflict on E, rotation" severity note;
    do_reset;
    idle;
    req(PORT_N) <= mk_req(PORT_E);
    req(PORT_S) <= mk_req(PORT_E);
    req(PORT_W) <= mk_req(PORT_E);
    for c in 0 to 3 loop
      eg := ZERO_G;
      if c = 1 then
        eg(PORT_E)(PORT_S) := '1';
      elsif c = 2 then
        eg(PORT_E)(PORT_W) := '1';
      else
        eg(PORT_E)(PORT_N) := '1';
      end if;
      verify(eg, "rotation, cycle " & integer'image(c));
      tick;
    end loop;

    ---------------------------------------------------------------
    -- Test 7: two independent conflicts in the same cycle
    --         N and S want E, W and L want S
    ---------------------------------------------------------------
    report "TEST 7: two independent conflicts" severity note;
    do_reset;
    idle;
    req(PORT_N) <= mk_req(PORT_E);
    req(PORT_S) <= mk_req(PORT_E);
    req(PORT_W) <= mk_req(PORT_S);
    req(PORT_L) <= mk_req(PORT_S);
    eg := ZERO_G;
    eg(PORT_E)(PORT_N) := '1';
    eg(PORT_S)(PORT_W) := '1';
    verify(eg, "two conflicts, first cycle");
    tick;
    eg := ZERO_G;
    eg(PORT_E)(PORT_S) := '1';
    eg(PORT_S)(PORT_L) := '1';
    verify(eg, "two conflicts, second cycle");
    tick;

    ---------------------------------------------------------------
    -- Test 8: one blocked output does not stop the others
    --         S->N (ready_in_N = 0), E->L, W->E, L->S
    ---------------------------------------------------------------
    report "TEST 8: one blocked output, the others go" severity note;
    idle;
    rdy(PORT_N) <= '0';
    req(PORT_S) <= mk_req(PORT_N);
    req(PORT_E) <= mk_req(PORT_L);
    req(PORT_W) <= mk_req(PORT_E);
    req(PORT_L) <= mk_req(PORT_S);
    eg := ZERO_G;
    eg(PORT_L)(PORT_E) := '1';
    eg(PORT_E)(PORT_W) := '1';
    eg(PORT_S)(PORT_L) := '1';
    verify(eg, "N blocked");
    tick;

    ---------------------------------------------------------------
    -- Test 9: first winner after reset, all 4 candidates want the same output
    --         candidate 0 wins: port 0, except for output N where it is port 1
    ---------------------------------------------------------------
    report "TEST 9: first winner after reset" severity note;
    for x in 0 to NUM_PORTS - 1 loop
      do_reset;
      idle;
      for p in 0 to NUM_PORTS - 1 loop
        if p /= x then
          req(p) <= mk_req(x);
        end if;
      end loop;
      if x = 0 then
        w := 1;
      else
        w := 0;
      end if;
      eg := ZERO_G;
      eg(x)(w) := '1';
      verify(eg, "all want " & NAMES(x + 1));
      tick;
    end loop;

    ---------------------------------------------------------------
    -- Test 10: valid bit = 0 with a destination bit set, no grant
    ---------------------------------------------------------------
    report "TEST 10: valid bit at 0" severity note;
    idle;
    req(PORT_N) <= '0' & onehot(PORT_E);
    verify(ZERO_G, "valid = 0");
    tick;

    ---------------------------------------------------------------
    -- Test 11: asynchronous reset in the middle of a conflict
    --          N and S want E. After one grant the pointer is on N,
    --          so S would win. A reset must give N back immediately.
    ---------------------------------------------------------------
    report "TEST 11: asynchronous reset" severity note;
    do_reset;
    idle;
    req(PORT_N) <= mk_req(PORT_E);
    req(PORT_S) <= mk_req(PORT_E);
    eg := ZERO_G;
    eg(PORT_E)(PORT_N) := '1';
    verify(eg, "before reset, N wins");
    tick;
    eg := ZERO_G;
    eg(PORT_E)(PORT_S) := '1';
    verify(eg, "before reset, S follows N");
    wait for 1 ns;                       -- 3 ns after the clock edge
    rst_n <= '0';
    eg := ZERO_G;
    eg(PORT_E)(PORT_N) := '1';
    verify(eg, "reset acts immediately, N wins again");
    wait until rising_edge(clk);
    wait for 1 ns;
    rst_n <= '1';
    verify(eg, "after reset release, N wins");
    tick;
    eg := ZERO_G;
    eg(PORT_E)(PORT_S) := '1';
    verify(eg, "normal operation resumes, S follows N");
    tick;

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
