----------------------------------------------------------------------------------
-- Company: 
-- Engineer: Duval Mambou
-- 
-- Create Date: 14.11.2026 12:25:08
-- Design Name: 
-- Module Name: tb_router - Behavioral
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

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.router_pkg.all;

entity tb_router is
end entity tb_router;

architecture Behavioral of tb_router is

  constant CLK_PERIOD : time    := 10 ns;
  -- Position of the router under test. 
  constant X_POS      : natural := 2;
  constant Y_POS      : natural := 3;
  constant MAX_C      : natural := 4;      -- last coordinate of the 5x5 mesh
  constant N_PER_PORT : natural := 30;     -- flits per input in the random test
  constant MAX_CYCLES : natural := 5000;   -- timeout of the random test
  constant HT         : std_logic_vector (FLIT_TYPE_WIDTH - 1 downto 0) := FLIT_HEAD_TAIL;
  constant NAMES      : string (1 to 5) := "NSEWL";   -- index = port number
  constant ZERO5      : std_logic_vector (NUM_PORTS - 1 downto 0) := (others => '0');
  constant ONES5      : std_logic_vector (NUM_PORTS - 1 downto 0) := (others => '1');

  signal clk   : std_logic := '0';
  signal rst_n : std_logic := '0';
  signal fin   : flit_array_t := (others => (others => '0'));
  signal vin   : std_logic_vector (NUM_PORTS - 1 downto 0) := (others => '0');
  signal rin   : std_logic_vector (NUM_PORTS - 1 downto 0) := (others => '1');  -- ready_in
  signal fout  : flit_array_t;
  signal vout  : std_logic_vector (NUM_PORTS - 1 downto 0);
  signal rout  : std_logic_vector (NUM_PORTS - 1 downto 0);                     -- ready_out
  signal done  : boolean := false;

begin

  clk <= not clk after CLK_PERIOD / 2 when not done;

  dut : entity work.router
    generic map (ROUTER_X_POS => X_POS, ROUTER_Y_POS => Y_POS)
    port map (
      clk => clk, rst_n => rst_n,
      flit_in_N => fin(PORT_N), flit_in_S => fin(PORT_S), flit_in_E => fin(PORT_E),
      flit_in_W => fin(PORT_W), flit_in_L => fin(PORT_L),
      valid_in_N => vin(PORT_N), valid_in_S => vin(PORT_S), valid_in_E => vin(PORT_E),
      valid_in_W => vin(PORT_W), valid_in_L => vin(PORT_L),
      ready_in_N => rin(PORT_N), ready_in_S => rin(PORT_S), ready_in_E => rin(PORT_E),
      ready_in_W => rin(PORT_W), ready_in_L => rin(PORT_L),
      flit_out_N => fout(PORT_N), flit_out_S => fout(PORT_S), flit_out_E => fout(PORT_E),
      flit_out_W => fout(PORT_W), flit_out_L => fout(PORT_L),
      valid_out_N => vout(PORT_N), valid_out_S => vout(PORT_S), valid_out_E => vout(PORT_E),
      valid_out_W => vout(PORT_W), valid_out_L => vout(PORT_L),
      ready_out_N => rout(PORT_N), ready_out_S => rout(PORT_S), ready_out_E => rout(PORT_E),
      ready_out_W => rout(PORT_W), ready_out_L => rout(PORT_L));

  stim : process

    type nat_arr_t  is array (0 to NUM_PORTS - 1) of natural;
    type bool_arr_t is array (0 to NUM_PORTS - 1) of boolean;
    type tab_t      is array (0 to NUM_PORTS - 1, 0 to N_PER_PORT - 1) of flit_t;
    type ord_t      is array (0 to 5) of natural;

    constant FAIR : ord_t := (11, 21, 31, 12, 22, 32);   -- expected order in test 7

    variable err_cnt : natural := 0;
    variable seed    : natural := 12345;
    variable f, fa, fb : flit_t;
    variable ox, oy  : natural;
    variable ov, pv, x2 : natural;
    variable expf    : flit_array_t;
    variable r, rdy_pct : natural;
    variable sent_n, exp_seq : nat_arr_t;
    variable pending : bool_arr_t;
    variable pend_f  : flit_array_t;
    variable tab     : tab_t;
    variable rcv_total, acc_total, cyc : natural;
    variable src, sq, rx, ry : natural;
    variable pl      : std_logic_vector (PAYLOAD_WIDTH - 1 downto 0);

    -------------------------------------------------------------
    -- Helpers
    -------------------------------------------------------------
    function onehot (i : natural) return std_logic_vector is
      variable v : std_logic_vector (NUM_PORTS - 1 downto 0) := (others => '0');
    begin
      v(i) := '1';
      return v;
    end function;

    -- Build a flit, following the layout from MSB to LSB
    function mk_flit (x, y, payload : natural) return flit_t is
      variable v : flit_t := (others => '0');
    begin
      v(FLIT_TYPE_HI downto FLIT_TYPE_LO) := HT;
      v(DEST_X_HI downto DEST_X_LO) := std_logic_vector(to_unsigned(x, COORD_WIDTH));
      v(DEST_Y_HI downto DEST_Y_LO) := std_logic_vector(to_unsigned(y, COORD_WIDTH));
      v(PAYLOAD_WIDTH - 1 downto 0) := std_logic_vector(to_unsigned(payload, PAYLOAD_WIDTH));
      return v;
    end function;

    -- Reference model of the XY routing (integers, X before Y)
    function route_out (x, y : natural) return natural is
    begin
      if    x > X_POS then return PORT_E;
      elsif x < X_POS then return PORT_W;
      elsif y < Y_POS then return PORT_N;
      elsif y > Y_POS then return PORT_S;
      else                 return PORT_L;
      end if;
    end function;

    -- Does the output o exist at this position of the mesh?
    function reachable (o : natural) return boolean is
    begin
      if    o = PORT_N then return Y_POS > 0;
      elsif o = PORT_S then return Y_POS < MAX_C;
      elsif o = PORT_E then return X_POS < MAX_C;
      elsif o = PORT_W then return X_POS > 0;
      else                  return true;
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

    -- Go to 1 ns after the next rising edge (inputs are driven there)
    procedure tick is
    begin
      wait until rising_edge(clk);
      wait for 1 ns;
    end procedure;

    procedure ticks (n : natural) is
    begin
      for i in 1 to n loop
        tick;
      end loop;
    end procedure;

    procedure idle is
    begin
      vin <= (others => '0');
      rin <= (others => '1');
    end procedure;

    -- rst_n released just after an edge, then 3 edges: the internal reset
    -- (2-flip-flop synchronizer) is over
    procedure do_reset is
    begin
      idle;
      rst_n <= '0';
      wait for 2 * CLK_PERIOD;
      tick;
      rst_n <= '1';
      ticks(3);
    end procedure;

    -- One flit on input p, written at the next edge
    procedure send (p : natural; fl : flit_t) is
    begin
      fin(p) <= fl;
      vin(p) <= '1';
      tick;
      vin(p) <= '0';
    end procedure;

    -- Destination of a flit that goes to output o and is a neighbour in that direction
    procedure nb_dest (o : natural; dx, dy : out natural) is
    begin
      dx := X_POS;
      dy := Y_POS;
      if    o = PORT_E then dx := X_POS + 1;
      elsif o = PORT_W and X_POS > 0 then dx := X_POS - 1;
      elsif o = PORT_N and Y_POS > 0 then dy := Y_POS - 1;
      elsif o = PORT_S then dy := Y_POS + 1;
      end if;
    end procedure;

    procedure check_idle (msg : string) is
    begin
      check(vout = ZERO5, msg & ": no valid_out");
    end procedure;

    -- Exactly one valid output (x), carrying the flit fl
    procedure check_only (x : natural; fl : flit_t; msg : string) is
    begin
      check(vout = onehot(x), msg & ": only valid_out_" & NAMES(x + 1));
      check(fout(x) = fl,     msg & ": flit_out_" & NAMES(x + 1) & " is the injected flit");
    end procedure;

    -- Small pseudo-random generator (LCG, full period), r in 0 .. m-1
    procedure rnd (m : natural; rr : out natural) is
    begin
      seed := (seed * 1105 + 12345) mod 65536;
      if m = 0 then
        rr := 0;
      else
        rr := (seed / 8) mod m;
      end if;
    end procedure;

    -- Random destination for a flit entering by port p: the output is chosen
    -- uniformly among the existing outputs different from p (no U-turn)
    procedure pick_dest (p : natural; dx, dy : out natural) is
      variable o, rr : natural;
    begin
      loop
        rnd(NUM_PORTS, rr);
        o := rr;
        exit when o /= p and reachable(o);
      end loop;
      dx := X_POS;
      dy := Y_POS;
      if o = PORT_E then
        rnd(MAX_C - X_POS, rr);  dx := X_POS + 1 + rr;
        rnd(MAX_C + 1, rr);      dy := rr;
      elsif o = PORT_W then
        rnd(X_POS, rr);          dx := rr;
        rnd(MAX_C + 1, rr);      dy := rr;
      elsif o = PORT_N then
        rnd(Y_POS, rr);          dy := rr;
      elsif o = PORT_S then
        rnd(MAX_C - Y_POS, rr);  dy := Y_POS + 1 + rr;
      end if;
    end procedure;

  begin
    for o in 0 to NUM_PORTS - 1 loop
      if not reachable(o) then
        report "NOTE: output " & NAMES(o + 1) & " does not exist at this position, its cases are skipped"
          severity note;
      end if;
    end loop;

    ---------------------------------------------------------------
    -- Test 1: reset state
    ---------------------------------------------------------------
    report "TEST 1: reset state" severity note;
    idle;
    rst_n <= '0';
    wait for 2 * CLK_PERIOD;
    check_idle("during reset");
    check(rout = ONES5, "during reset: ready_out = 1 on every port");
    tick;
    rst_n <= '1';
    ticks(3);
    check_idle("after reset");
    check(rout = ONES5, "after reset: ready_out = 1 on every port");

    ---------------------------------------------------------------
    -- Test 2: reset release. The internal reset ends 2 edges after rst_n
    --         (known limit of the local synchronizer in V1)
    ---------------------------------------------------------------
    report "TEST 2: flit sent right after the release of rst_n" severity note;
    idle;
    rst_n <= '0';
    wait for 2 * CLK_PERIOD;
    tick;
    fa := mk_flit(X_POS, Y_POS, 16#00A#);              -- toward L
    fb := mk_flit(X_POS, Y_POS, 16#00B#);
    rst_n <= '1';
    fin(PORT_N) <= fa;
    vin(PORT_N) <= '1';
    tick;                                              -- edge 1: still in internal reset
    vin(PORT_N) <= '0';
    check_idle("flit A sent at the first edge is lost");
    tick;                                              -- edge 2: internal reset released after it
    check_idle("flit A never shows up");
    fin(PORT_N) <= fb;
    vin(PORT_N) <= '1';
    tick;                                              -- edge 3: accepted
    vin(PORT_N) <= '0';
    check_only(PORT_L, fb, "flit B sent after the internal reset");
    tick;
    check_idle("flit B left exactly once");

    ---------------------------------------------------------------
    -- Test 3: the 20 paths (input p to output x), hand-written
    --         expectations: a neighbour in the direction of x
    ---------------------------------------------------------------
    report "TEST 3: the 20 paths" severity note;
    for p in 0 to NUM_PORTS - 1 loop
      for x in 0 to NUM_PORTS - 1 loop
        if p /= x and reachable(x) then
          nb_dest(x, ox, oy);
          f := mk_flit(ox, oy, 16 * p + x + 1);
          send(p, f);
          check_only(x, f, "path " & NAMES(p + 1) & "->" & NAMES(x + 1));
          tick;
          check_idle("path " & NAMES(p + 1) & "->" & NAMES(x + 1) & " flit left once");
        end if;
      end loop;
    end loop;

    ---------------------------------------------------------------
    -- Test 4: the 36 destinations of the mesh, XY routing against the model
    ---------------------------------------------------------------
    report "TEST 4: the 36 destinations" severity note;
    for dxx in 0 to MAX_C loop
      for dyy in 0 to MAX_C loop
        ov := route_out(dxx, dyy);
        pv := (ov + 1) mod NUM_PORTS;                  -- any input except ov
        f  := mk_flit(dxx, dyy, dxx * 6 + dyy);
        send(pv, f);
        check_only(ov, f, "dest (" & integer'image(dxx) & "," & integer'image(dyy) & ")");
        tick;
        check_idle("dest (" & integer'image(dxx) & "," & integer'image(dyy) & ") left once");
      end loop;
    end loop;

    ---------------------------------------------------------------
    -- Test 5: ready_in = 0 holds the flit, nothing is lost, it leaves once
    ---------------------------------------------------------------
    report "TEST 5: blocked output" severity note;
    for x in 0 to NUM_PORTS - 1 loop
      if reachable(x) then
        pv := (x + 1) mod NUM_PORTS;
        nb_dest(x, ox, oy);
        f := mk_flit(ox, oy, 500 + x);
        idle;
        rin(x) <= '0';
        send(pv, f);
        check_idle("output " & NAMES(x + 1) & " blocked");
        ticks(3);
        check_idle("output " & NAMES(x + 1) & " still blocked after 3 cycles");
        check(rout(pv) = '1', "output " & NAMES(x + 1) & " blocked: ready_out of the input still 1");
        rin(x) <= '1';
        wait for 1 ns;
        check_only(x, f, "output " & NAMES(x + 1) & " released");
        tick;
        check_idle("output " & NAMES(x + 1) & " flit left exactly once");
      end if;
    end loop;

    ---------------------------------------------------------------
    -- Test 6: full FIFO, ready_out falls, extra flit ignored, order kept
    ---------------------------------------------------------------
    report "TEST 6: full FIFO" severity note;
    do_reset;
    rin(PORT_L) <= '0';
    for i in 1 to FIFO_DEPTH loop
      fin(PORT_N) <= mk_flit(X_POS, Y_POS, i);
      vin(PORT_N) <= '1';
      tick;
      if i < FIFO_DEPTH then
        check(rout(PORT_N) = '1', "ready_out_N = 1 with " & integer'image(i) & " flit(s)");
      end if;
    end loop;
    check(rout(PORT_N) = '0', "ready_out_N = 0 with FIFO_DEPTH flits");
    fin(PORT_N) <= mk_flit(X_POS, Y_POS, 99);          -- must be ignored
    tick;
    vin(PORT_N) <= '0';
    check(rout(PORT_N) = '0', "still not ready after the ignored write");
    check_idle("L blocked while the FIFO is full");
    rin(PORT_L) <= '1';
    wait for 1 ns;
    for i in 1 to FIFO_DEPTH loop
      check(vout = onehot(PORT_L), "drain " & integer'image(i) & ": only valid_out_L");
      check(fout(PORT_L) = mk_flit(X_POS, Y_POS, i), "drain " & integer'image(i) & ": FIFO order");
      tick;
      if i = 1 then
        check(rout(PORT_N) = '1', "ready_out_N back to 1 after one pop");
      end if;
    end loop;
    check_idle("drained, the ignored flit never appeared");

    ---------------------------------------------------------------
    -- Test 7: fairness, N, S and E send 2 flits each to L
    --         expected order N1 S1 E1 N2 S2 E2 (a fixed priority would give N1 N2 ...)
    ---------------------------------------------------------------
    report "TEST 7: round-robin fairness" severity note;
    do_reset;
    fin(PORT_N) <= mk_flit(X_POS, Y_POS, 11);
    fin(PORT_S) <= mk_flit(X_POS, Y_POS, 21);
    fin(PORT_E) <= mk_flit(X_POS, Y_POS, 31);
    vin(PORT_N) <= '1';
    vin(PORT_S) <= '1';
    vin(PORT_E) <= '1';
    tick;                                              -- first wave written
    fin(PORT_N) <= mk_flit(X_POS, Y_POS, 12);
    fin(PORT_S) <= mk_flit(X_POS, Y_POS, 22);
    fin(PORT_E) <= mk_flit(X_POS, Y_POS, 32);
    for i in 0 to 5 loop
      check(vout = onehot(PORT_L), "fairness step " & integer'image(i) & ": only valid_out_L");
      check(fout(PORT_L) = mk_flit(X_POS, Y_POS, FAIR(i)),
            "fairness step " & integer'image(i) & ": expected flit " & integer'image(FAIR(i)));
      tick;
      if i = 0 then
        vin <= (others => '0');                        -- second wave written at this edge
      end if;
    end loop;
    check_idle("fairness: the six flits are delivered");

    ---------------------------------------------------------------
    -- Test 8: permutation, 5 flows without conflict in the same cycle
    --         (needs an interior router: the 5 outputs must exist)
    ---------------------------------------------------------------
    report "TEST 8: simultaneous flows" severity note;
    if X_POS >= 1 and X_POS <= MAX_C - 1 and Y_POS >= 1 and Y_POS <= MAX_C - 1 then
      for k in 1 to 4 loop
        idle;
        for p in 0 to NUM_PORTS - 1 loop
          ov := (p + k) mod NUM_PORTS;
          nb_dest(ov, ox, oy);
          expf(ov) := mk_flit(ox, oy, 100 * k + p);
          fin(p) <= expf(ov);
          vin(p) <= '1';
        end loop;
        tick;
        vin <= (others => '0');
        check(vout = ONES5, "permutation +" & integer'image(k) & ": 5 outputs valid in the same cycle");
        for q in 0 to NUM_PORTS - 1 loop
          check(fout(q) = expf(q), "permutation +" & integer'image(k) & ": flit_out_" & NAMES(q + 1));
        end loop;
        tick;
        check_idle("permutation +" & integer'image(k) & ": flits left exactly once");
      end loop;
    else
      report "NOTE: test 8 skipped, it needs an interior router" severity note;
    end if;

    ---------------------------------------------------------------
    -- Test 9: order and full throughput on one input (1 flit per cycle)
    ---------------------------------------------------------------
    report "TEST 9: order and throughput" severity note;
    idle;
    for i in 1 to 4 loop
      fin(PORT_N) <= mk_flit(X_POS, Y_POS, 200 + i);
      vin(PORT_N) <= '1';
      tick;
      check(vout = onehot(PORT_L), "back-to-back flit " & integer'image(i) & ": only valid_out_L");
      check(fout(PORT_L) = mk_flit(X_POS, Y_POS, 200 + i), "back-to-back flit " & integer'image(i) & ": order");
    end loop;
    vin(PORT_N) <= '0';
    tick;
    check_idle("back-to-back: last flit left once");

    ---------------------------------------------------------------
    -- Test 10: head-of-line blocking (expected behaviour in V1)
    --          N receives A for L (blocked) then B for another output
    ---------------------------------------------------------------
    report "TEST 10: head-of-line blocking" severity note;
    if    reachable(PORT_E) then x2 := PORT_E;
    elsif reachable(PORT_S) then x2 := PORT_S;
    else                         x2 := PORT_W;
    end if;
    idle;
    rin(PORT_L) <= '0';
    fa := mk_flit(X_POS, Y_POS, 301);
    nb_dest(x2, ox, oy);
    fb := mk_flit(ox, oy, 302);
    send(PORT_N, fa);
    send(PORT_N, fb);
    check_idle("A blocked on L, B waits behind it");
    ticks(3);
    check_idle("still blocked after 3 cycles");
    rin(PORT_L) <= '1';
    wait for 1 ns;
    check_only(PORT_L, fa, "L released: A leaves first");
    tick;
    check_only(x2, fb, "then B reaches its output");
    tick;
    check_idle("A and B delivered exactly once");

    ---------------------------------------------------------------
    -- Test 11: asynchronous reset in the middle of traffic
    ---------------------------------------------------------------
    report "TEST 11: asynchronous reset" severity note;
    idle;
    f := mk_flit(X_POS, Y_POS, 401);
    send(PORT_N, f);
    check_only(PORT_L, f, "before reset: flit offered on L");
    wait for 2 ns;                                     -- 3 ns after the edge
    rst_n <= '0';
    wait for 1 ns;                                     -- no clock edge in between
    check_idle("reset acts immediately");
    check(rout = ONES5, "reset acts immediately: ready_out = 1");
    tick;
    rst_n <= '1';
    ticks(3);
    check_idle("no old flit comes back after reset (a)");

    idle;
    rin(PORT_L) <= '0';
    for i in 1 to FIFO_DEPTH loop
      send(PORT_N, mk_flit(X_POS, Y_POS, 410 + i));
    end loop;
    check(rout(PORT_N) = '0', "FIFO of N full before reset");
    wait for 2 ns;
    rst_n <= '0';
    wait for 1 ns;
    check(rout(PORT_N) = '1', "reset acts immediately: ready_out_N back to 1");
    tick;
    rst_n <= '1';
    ticks(3);
    rin(PORT_L) <= '1';
    ticks(2);
    check_idle("old flits are gone after reset (b)");

    ---------------------------------------------------------------
    -- Test 12: random traffic, conservation
    --          every flit must come out once, on the right output,
    --          unchanged, and in order for its input
    ---------------------------------------------------------------
    for ph in 0 to 1 loop
      if ph = 0 then
        rdy_pct := 40;
      else
        rdy_pct := 90;
      end if;
      report "TEST 12 phase " & integer'image(ph + 1) & ": ready_in = 1 with probability "
             & integer'image(rdy_pct) & " %" severity note;
      do_reset;
      sent_n := (others => 0);
      exp_seq := (others => 0);
      pending := (others => false);
      rcv_total := 0;
      acc_total := 0;
      cyc := 0;
      while rcv_total < NUM_PORTS * N_PER_PORT and cyc < MAX_CYCLES loop
        -- ready_in of this cycle
        for x in 0 to NUM_PORTS - 1 loop
          rnd(100, r);
          if r < rdy_pct then
            rin(x) <= '1';
          else
            rin(x) <= '0';
          end if;
        end loop;
        -- inputs: a pending flit is held until the router accepts it
        for p in 0 to NUM_PORTS - 1 loop
          if (not pending(p)) and sent_n(p) < N_PER_PORT then
            rnd(100, r);
            if r < 60 then
              pick_dest(p, rx, ry);
              pend_f(p) := mk_flit(rx, ry, p * 1048576 + sent_n(p));   -- payload = source & sequence
              tab(p, sent_n(p)) := pend_f(p);
              sent_n(p) := sent_n(p) + 1;
              pending(p) := true;
            end if;
          end if;
          if pending(p) then
            fin(p) <= pend_f(p);
            vin(p) <= '1';
          else
            vin(p) <= '0';
          end if;
        end loop;
        wait for 2 ns;                                 -- outputs are combinational: let them settle
        -- outputs: a flit with valid_out = 1 is transferred at the next edge
        for x in 0 to NUM_PORTS - 1 loop
          if vout(x) = '1' then
            rcv_total := rcv_total + 1;
            rx := to_integer(unsigned(fout(x)(DEST_X_HI downto DEST_X_LO)));
            ry := to_integer(unsigned(fout(x)(DEST_Y_HI downto DEST_Y_LO)));
            pl := fout(x)(PAYLOAD_WIDTH - 1 downto 0);
            src := to_integer(unsigned(pl(PAYLOAD_WIDTH - 1 downto 20)));
            sq  := to_integer(unsigned(pl(19 downto 0)));
            check(route_out(rx, ry) = x and rin(x) = '1',
                  "flit " & integer'image(rcv_total) & ": right output " & NAMES(x + 1) & " and ready_in = 1");
            if src < NUM_PORTS and sq < N_PER_PORT then
              check(sq = exp_seq(src),
                    "flit " & integer'image(rcv_total) & ": in order for input " & NAMES(src + 1));
              check(fout(x) = tab(src, sq),
                    "flit " & integer'image(rcv_total) & ": unchanged");
              exp_seq(src) := sq + 1;
            else
              check(false, "flit " & integer'image(rcv_total) & ": valid source and sequence number");
            end if;
          end if;
        end loop;
        -- inputs: a flit with valid_in = 1 and ready_out = 1 is written at the next edge
        for p in 0 to NUM_PORTS - 1 loop
          if pending(p) and rout(p) = '1' then
            pending(p) := false;
            acc_total := acc_total + 1;
          end if;
        end loop;
        tick;
        cyc := cyc + 1;
      end loop;
      idle;
      check(acc_total = NUM_PORTS * N_PER_PORT, "phase " & integer'image(ph + 1) & ": every flit accepted");
      check(rcv_total = NUM_PORTS * N_PER_PORT, "phase " & integer'image(ph + 1) & ": every flit delivered before the timeout");
      for p in 0 to NUM_PORTS - 1 loop
        check(exp_seq(p) = N_PER_PORT, "phase " & integer'image(ph + 1) & ": all flits of input " & NAMES(p + 1) & " delivered");
      end loop;
      for i in 1 to 6 loop
        tick;
        check_idle("phase " & integer'image(ph + 1) & ": no duplicate after the end, cycle " & integer'image(i));
      end loop;
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

end architecture Behavioral;