----------------------------------------------------------------------------------
-- Company: 
-- Engineer: Duval Mambou
-- 
-- Create Date: 13.11.2026 19:35:52
-- Design Name: 
-- Module Name: switch_allocator - Behavioral
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

entity switch_allocator is
  Port ( 
        clk, rst_n : in std_logic;
        ready_in_N, ready_in_S, ready_in_E, ready_in_W, ready_in_L : in std_logic ;
        request_N, request_S, request_E, request_W, request_L : in request_t;
        grant_N, grant_S, grant_E, grant_W, grant_L : out port_vec_t;
        pop_N, pop_S, pop_E, pop_W, pop_L : out std_logic
    );
end switch_allocator;

architecture Behavioral of switch_allocator is

signal req_in_a_N, req_in_a_S, req_in_a_E, req_in_a_W, req_in_a_L : requestors_vec_t;
signal grant_out_a_N, grant_out_a_S, grant_out_a_E, grant_out_a_W, grant_out_a_L : requestors_vec_t;
signal s_grant_N, s_grant_S, s_grant_E, s_grant_W, s_grant_L : port_vec_t;

begin

    req_in_a_N(0) <= request_S(PORT_N) when request_S(VALID_REQ_POS) = '1' and ready_in_N = '1' else '0';
    req_in_a_N(1) <= request_E(PORT_N) when request_E(VALID_REQ_POS) = '1' and ready_in_N = '1' else '0';
    req_in_a_N(2) <= request_W(PORT_N) when request_W(VALID_REQ_POS) = '1' and ready_in_N = '1' else '0';
    req_in_a_N(3) <= request_L(PORT_N) when request_L(VALID_REQ_POS) = '1' and ready_in_N = '1' else '0';
    
    req_in_a_S(0) <= request_N(PORT_S) when request_N(VALID_REQ_POS) = '1' and ready_in_S = '1' else '0';
    req_in_a_S(1) <= request_E(PORT_S) when request_E(VALID_REQ_POS) = '1' and ready_in_S = '1' else '0';
    req_in_a_S(2) <= request_W(PORT_S) when request_W(VALID_REQ_POS) = '1' and ready_in_S = '1' else '0';
    req_in_a_S(3) <= request_L(PORT_S) when request_L(VALID_REQ_POS) = '1' and ready_in_S = '1' else '0';
   
    req_in_a_E(0) <= request_N(PORT_E) when request_N(VALID_REQ_POS) = '1' and ready_in_E = '1' else '0';
    req_in_a_E(1) <= request_S(PORT_E) when request_S(VALID_REQ_POS) = '1' and ready_in_E = '1' else '0';
    req_in_a_E(2) <= request_W(PORT_E) when request_W(VALID_REQ_POS) = '1' and ready_in_E = '1' else '0';
    req_in_a_E(3) <= request_L(PORT_E) when request_L(VALID_REQ_POS) = '1' and ready_in_E = '1' else '0';
   
    req_in_a_W(0) <= request_N(PORT_W) when request_N(VALID_REQ_POS) = '1' and ready_in_W = '1' else '0';
    req_in_a_W(1) <= request_S(PORT_W) when request_S(VALID_REQ_POS) = '1' and ready_in_W = '1' else '0';
    req_in_a_W(2) <= request_E(PORT_W) when request_E(VALID_REQ_POS) = '1' and ready_in_W = '1' else '0';
    req_in_a_W(3) <= request_L(PORT_W) when request_L(VALID_REQ_POS) = '1' and ready_in_W = '1' else '0';
   
    req_in_a_L(0) <= request_N(PORT_L) when request_N(VALID_REQ_POS) = '1' and ready_in_L = '1' else '0';
    req_in_a_L(1) <= request_S(PORT_L) when request_S(VALID_REQ_POS) = '1' and ready_in_L = '1' else '0';
    req_in_a_L(2) <= request_E(PORT_L) when request_E(VALID_REQ_POS) = '1' and ready_in_L = '1' else '0';
    req_in_a_L(3) <= request_W(PORT_L) when request_W(VALID_REQ_POS) = '1' and ready_in_L = '1' else '0';

    s_grant_N <= grant_out_a_N(3) & grant_out_a_N(2) & grant_out_a_N(1) & grant_out_a_N(0) & '0'             ;
    s_grant_S <= grant_out_a_S(3) & grant_out_a_S(2) & grant_out_a_S(1) & '0'              & grant_out_a_S(0);
    s_grant_E <= grant_out_a_E(3) & grant_out_a_E(2) & '0'              & grant_out_a_E(1) & grant_out_a_E(0);
    s_grant_W <= grant_out_a_W(3) & '0'              & grant_out_a_W(2) & grant_out_a_W(1) & grant_out_a_W(0);
    s_grant_L <= '0'              & grant_out_a_L(3) & grant_out_a_L(2) & grant_out_a_L(1) & grant_out_a_L(0);
   
       
    arbiter_N : entity work.arbiter_x
            port map (
                    clk       => clk,
                    rst_n     => rst_n,
                    request_x => req_in_a_N,
                    grant_a_x => grant_out_a_N
                );
                
     arbiter_S : entity work.arbiter_x
            port map (
                    clk       => clk,
                    rst_n     => rst_n,
                    request_x => req_in_a_S,
                    grant_a_x => grant_out_a_S
                );
                
     arbiter_E : entity work.arbiter_x
            port map (
                    clk       => clk,
                    rst_n     => rst_n,
                    request_x => req_in_a_E,
                    grant_a_x => grant_out_a_E
                );
                
     arbiter_W : entity work.arbiter_x
            port map (
                    clk       => clk,
                    rst_n     => rst_n,
                    request_x => req_in_a_W,
                    grant_a_x => grant_out_a_W
                );
                
     arbiter_L : entity work.arbiter_x
            port map (
                    clk       => clk,
                    rst_n     => rst_n,
                    request_x => req_in_a_L,
                    grant_a_x => grant_out_a_L
                );                                                
    
    pop_N <= s_grant_N(PORT_N) or s_grant_S(PORT_N) or s_grant_E(PORT_N) or s_grant_W(PORT_N) or s_grant_L(PORT_N) ; 
    pop_S <= s_grant_N(PORT_S) or s_grant_S(PORT_S) or s_grant_E(PORT_S) or s_grant_W(PORT_S) or s_grant_L(PORT_S) ; 
    pop_E <= s_grant_N(PORT_E) or s_grant_S(PORT_E) or s_grant_E(PORT_E) or s_grant_W(PORT_E) or s_grant_L(PORT_E) ; 
    pop_W <= s_grant_N(PORT_W) or s_grant_S(PORT_W) or s_grant_E(PORT_W) or s_grant_W(PORT_W) or s_grant_L(PORT_W) ; 
    pop_L <= s_grant_N(PORT_L) or s_grant_S(PORT_L) or s_grant_E(PORT_L) or s_grant_W(PORT_L) or s_grant_L(PORT_L) ; 
    
    grant_N <= s_grant_N;
    grant_S <= s_grant_S;
    grant_E <= s_grant_E;
    grant_W <= s_grant_W;
    grant_L <= s_grant_L;
    
end Behavioral;
