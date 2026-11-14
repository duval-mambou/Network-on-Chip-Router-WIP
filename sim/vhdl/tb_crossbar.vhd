----------------------------------------------------------------------------------
-- Company: 
-- Engineer: Duval Mambou
-- 
-- Create Date: 13.11.2026 22:19:39
-- Design Name: 
-- Module Name: tb_crossbar - Behavioral
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

entity tb_crossbar is
end entity tb_crossbar;

architecture Behavioral of tb_crossbar is

  type gr_arr_t  is array (0 to NUM_PORTS - 1) of port_vec_t;
  type pat_arr_t is array (0 to 3) of flit_t;

  constant NAMES  : string (1 to 5) := "NSEWL";      -- index = port number (N=0 ... L=4)
  constant ZERO_F : flit_t := (others => '0');
  constant ONES_F : flit_t := (others => '1');
  constant ZERO_G : gr_arr_t := (others => (others => '0'));

  -- One distinct, recognizable flit per port
  constant PFLIT : flit_array_t := (x"A0000001", x"B0000002", x"C0000003",
                                    x"D0000004", x"E0000005");

  constant PATTERNS : pat_arr_t := (ZERO_F, ONES_F, x"AAAAAAAA", x"55555555");

  signal fin  : flit_array_t := PFLIT;
  signal gr   : gr_arr_t := ZERO_G;
  signal fout : flit_array_t;
  signal vout : std_logic_vector (NUM_PORTS - 1 downto 0);

begin

  dut : entity work.crossbar
    port map (
      flit_N => fin(PORT_N), flit_S => fin(PORT_S), flit_E => fin(PORT_E),
      flit_W => fin(PORT_W), flit_L => fin(PORT_L),
      grant_N => gr(PORT_N), grant_S => gr(PORT_S), grant_E => gr(PORT_E),
      grant_W => gr(PORT_W), grant_L => gr(PORT_L),
      flit_out_N => fout(PORT_N), flit_out_S => fout(PORT_S), flit_out_E => fout(PORT_E),
      flit_out_W => fout(PORT_W), flit_out_L => fout(PORT_L),
      valid_out_N => vout(PORT_N), valid_out_S => vout(PORT_S), valid_out_E => vout(PORT_E),
      valid_out_W => vout(PORT_W), valid_out_L => vout(PORT_L));

  stim : process
    variable err_cnt : natural := 0;
    variable v       : flit_t;

    function onehot (i : natural) return port_vec_t is
      variable r : port_vec_t := (others => '0');
    begin
      r(i) := '1';
      return r;
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

    -- Output x gets the flit of port (x + k) mod 5. For k = 1..4 this is a
    -- permutation with no port on its own output: 5 simultaneous transfers
    procedure set_perm (k : natural) is
    begin
      gr <= ZERO_G;
      for x in 0 to NUM_PORTS - 1 loop
        gr(x) <= onehot((x + k) mod NUM_PORTS);
      end loop;
    end procedure;

    -- Combinational block: wait 1 ns, then compare every output with the
    -- reference model (the flit of the granted port, or 0 without grant)
    procedure verify (msg : string) is
      variable expf : flit_t;
      variable anyg : std_logic;
    begin
      wait for 1 ns;
      for x in 0 to NUM_PORTS - 1 loop
        expf := ZERO_F;
        anyg := '0';
        for p in 0 to NUM_PORTS - 1 loop
          if gr(x)(p) = '1' then
            expf := fin(p);
            anyg := '1';
          end if;
        end loop;
        check(fout(x) = expf, msg & ": flit_out_" & NAMES(x + 1));
        check(vout(x) = anyg, msg & ": valid_out_" & NAMES(x + 1));
      end loop;
    end procedure;

  begin
    ---------------------------------------------------------------
    -- Test 1: no grant, every output 0 and not valid
    ---------------------------------------------------------------
    report "TEST 1: no grant" severity note;
    fin <= PFLIT;
    gr  <= ZERO_G;
    verify("no grant");

    ---------------------------------------------------------------
    -- Test 2: the 20 pairs (p, x), one grant, explicit expectation
    ---------------------------------------------------------------
    report "TEST 2: the 20 (port, output) pairs" severity note;
    for p in 0 to NUM_PORTS - 1 loop
      for x in 0 to NUM_PORTS - 1 loop
        if p /= x then
          gr <= ZERO_G;
          gr(x) <= onehot(p);
          verify("pair " & NAMES(p + 1) & "->" & NAMES(x + 1));
          check(fout(x) = PFLIT(p), "pair " & NAMES(p + 1) & "->" & NAMES(x + 1) & ": exact source flit");
        end if;
      end loop;
    end loop;

    ---------------------------------------------------------------
    -- Test 3: permutation, 5 transfers in the same cycle
    --         N->E, S->W, E->L, W->N, L->S, then the 4 cyclic shifts
    ---------------------------------------------------------------
    report "TEST 3: permutations" severity note;
    gr <= ZERO_G;
    gr(PORT_E) <= onehot(PORT_N);
    gr(PORT_W) <= onehot(PORT_S);
    gr(PORT_L) <= onehot(PORT_E);
    gr(PORT_N) <= onehot(PORT_W);
    gr(PORT_S) <= onehot(PORT_L);
    verify("permutation N->E, S->W, E->L, W->N, L->S");
    check(fout(PORT_E) = PFLIT(PORT_N) and fout(PORT_W) = PFLIT(PORT_S) and
          fout(PORT_L) = PFLIT(PORT_E) and fout(PORT_N) = PFLIT(PORT_W) and
          fout(PORT_S) = PFLIT(PORT_L), "permutation: exact source flits");
    for k in 1 to 4 loop
      set_perm(k);
      verify("cyclic shift " & integer'image(k));
    end loop;

    ---------------------------------------------------------------
    -- Test 4: bit patterns copied exactly on 32 bits
    ---------------------------------------------------------------
    report "TEST 4: bit patterns" severity note;
    set_perm(1);
    for i in 0 to 3 loop
      fin <= (others => PATTERNS(i));
      verify("pattern " & integer'image(i));
    end loop;
    fin <= PFLIT;

    ---------------------------------------------------------------
    -- Test 5: walking one, a different bit on every port,
    --         a lost or crossed bit shows up
    ---------------------------------------------------------------
    report "TEST 5: walking one" severity note;
    set_perm(1);
    for b in 0 to FLIT_WIDTH - 1 loop
      for p in 0 to NUM_PORTS - 1 loop
        v := ZERO_F;
        v((b + p) mod FLIT_WIDTH) := '1';
        fin(p) <= v;
      end loop;
      verify("walking one, bit " & integer'image(b));
    end loop;
    fin <= PFLIT;

    ---------------------------------------------------------------
    -- Test 6: the source changes while the grant stays fixed,
    --         the output follows in the same cycle (combinational)
    ---------------------------------------------------------------
    report "TEST 6: source changes, grant fixed" severity note;
    gr <= ZERO_G;
    gr(PORT_E) <= onehot(PORT_N);
    verify("initial");
    fin(PORT_N) <= x"DEADBEEF";
    verify("source = DEADBEEF");
    fin(PORT_N) <= ZERO_F;
    verify("source = 0");
    fin(PORT_N) <= ONES_F;
    verify("source = all ones");

    ---------------------------------------------------------------
    -- Test 7: the grant disappears, the output goes back to 0 at once
    --         (no memory of the previous flit)
    ---------------------------------------------------------------
    report "TEST 7: grant removed, no memory" severity note;
    gr <= ZERO_G;
    verify("grant removed");

    ---------------------------------------------------------------
    -- Test 8: a non-selected port changes, no output moves
    ---------------------------------------------------------------
    report "TEST 8: non-selected ports change" severity note;
    fin <= PFLIT;
    gr <= ZERO_G;
    gr(PORT_E) <= onehot(PORT_N);
    verify("before");
    fin(PORT_S) <= ONES_F;
    fin(PORT_W) <= ZERO_F;
    fin(PORT_L) <= x"12345678";
    fin(PORT_E) <= x"87654321";           -- own port of the output
    verify("others changed");
    check(fout(PORT_E) = PFLIT(PORT_N), "output E still holds the flit of N");

    ---------------------------------------------------------------
    -- Test 9: undefined ('U') flits on non-selected ports
    --         the selected output is clean, the others are exactly 0
    ---------------------------------------------------------------
    report "TEST 9: U on non-selected ports" severity note;
    fin <= (others => (others => 'U'));
    gr <= ZERO_G;
    verify("all inputs U, no grant");
    fin(PORT_N) <= PFLIT(PORT_N);
    gr(PORT_E) <= onehot(PORT_N);
    verify("only N defined, N->E");
    gr <= ZERO_G;
    fin(PORT_L) <= PFLIT(PORT_L);
    gr(PORT_S) <= onehot(PORT_L);
    verify("only N and L defined, L->S");
    fin <= PFLIT;

    ---------------------------------------------------------------
    -- Test 10: the grant moves between sources on the same output,
    --          back to back, without a cycle in between
    ---------------------------------------------------------------
    report "TEST 10: grant switches source on output E" severity note;
    gr <= ZERO_G;
    for p in 0 to NUM_PORTS - 1 loop
      if p /= PORT_E then
        gr(PORT_E) <= onehot(p);
        verify("output E fed by " & NAMES(p + 1));
      end if;
    end loop;

    ---------------------------------------------------------------
    -- Summary
    ---------------------------------------------------------------
    if err_cnt = 0 then
      report "ALL TESTS PASSED" severity note;
    else
      report "TESTS FAILED: " & integer'image(err_cnt) & " error(s)" severity error;
    end if;
    wait;
  end process stim;

end architecture Behavioral;
