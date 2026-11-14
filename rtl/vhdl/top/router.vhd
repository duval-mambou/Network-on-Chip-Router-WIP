----------------------------------------------------------------------------------
-- Company: 
-- Engineer: Duval Mambou
-- 
-- Create Date: 14.11.2026 11:17:02
-- Design Name: 
-- Module Name: router - Behavioral
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

entity router is
  generic (
    ROUTER_X_POS : natural;
    ROUTER_Y_POS : natural
  );
  Port ( 
    clk, rst_n : in std_logic ;
    flit_in_N, flit_in_S, flit_in_E, flit_in_W, flit_in_L : in flit_t ;
    valid_in_N, valid_in_S, valid_in_E, valid_in_W, valid_in_L : in std_logic ;
    ready_in_N, ready_in_S, ready_in_E, ready_in_W, ready_in_L : in std_logic ;
    flit_out_N, flit_out_S, flit_out_E, flit_out_W, flit_out_L : out flit_t;
    valid_out_N, valid_out_S, valid_out_E, valid_out_W, valid_out_L : out std_logic ;
    ready_out_N, ready_out_S, ready_out_E, ready_out_W, ready_out_L : out std_logic 
    );
end router;

architecture Behavioral of router is

-- reset resynchronisation signals 
signal resyn_rst_n, syn_rst_n0 : std_logic;	

-- signal pop for each port
signal pop_N, pop_S, pop_E, pop_W, pop_L : std_logic ;

-- signal request out of each port and in of SA
signal request_N, request_S, request_E, request_W, request_L : request_t;

-- intermediate filt signals inside the router
signal flit_N, flit_S, flit_E, flit_W, flit_L : flit_t ;

-- grant internal signals for the switch allocator and the crossbar
signal grant_N, grant_S, grant_E, grant_W, grant_L : port_vec_t;

begin

    -- Reset synchronization
    Reset : process(rst_n, clk)
    begin
        if rst_n = '0' then
            syn_rst_n0   <= '0';
            resyn_rst_n  <= '0';
        elsif rising_edge (clk) then
            syn_rst_n0   <= '1';
            resyn_rst_n  <= syn_rst_n0;
        end if;
    end process Reset;
    
    -- Port N
    Port_N : entity work.port_x
        generic map (
            ROUTER_X_POS => ROUTER_X_POS,
            ROUTER_Y_POS => ROUTER_Y_POS
        )
        port map (
            clk         => clk, 
            rst_n       => resyn_rst_n,
            valid_in    => valid_in_N,
            pop         => pop_N,
            flit_in     => flit_in_N,
            flit_out    => flit_N,
            ready_out   => ready_out_N,
            request     => request_N
        );     
        
    -- Port S
    Port_S : entity work.port_x
        generic map (
            ROUTER_X_POS => ROUTER_X_POS,
            ROUTER_Y_POS => ROUTER_Y_POS
        )
        port map (
            clk         => clk, 
            rst_n       => resyn_rst_n,
            valid_in    => valid_in_S,
            pop         => pop_S,
            flit_in     => flit_in_S,
            flit_out    => flit_S,
            ready_out   => ready_out_S,
            request     => request_S
        );
        
    -- Port E
    Port_E : entity work.port_x
        generic map (
            ROUTER_X_POS => ROUTER_X_POS,
            ROUTER_Y_POS => ROUTER_Y_POS
        )
        port map (
            clk         => clk, 
            rst_n       => resyn_rst_n,
            valid_in    => valid_in_E,
            pop         => pop_E,
            flit_in     => flit_in_E,
            flit_out    => flit_E,
            ready_out   => ready_out_E,
            request     => request_E
        );     
        
    -- Port W
    Port_W : entity work.port_x
        generic map (
            ROUTER_X_POS => ROUTER_X_POS,
            ROUTER_Y_POS => ROUTER_Y_POS
        )
        port map (
            clk         => clk, 
            rst_n       => resyn_rst_n,
            valid_in    => valid_in_W,
            pop         => pop_W,
            flit_in     => flit_in_W,
            flit_out    => flit_W,
            ready_out   => ready_out_W,
            request     => request_W
        );     
        
        
    -- Port L
    Port_L : entity work.port_x
        generic map (
            ROUTER_X_POS => ROUTER_X_POS,
            ROUTER_Y_POS => ROUTER_Y_POS
        )
        port map (
            clk         => clk, 
            rst_n       => resyn_rst_n,
            valid_in    => valid_in_L,
            pop         => pop_L,
            flit_in     => flit_in_L,
            flit_out    => flit_L,
            ready_out   => ready_out_L,
            request     => request_L
        ); 
        
        -- Switch Allocator (SA)
        SA : entity work.switch_allocator
            port map (
                clk         => clk, 
                rst_n       => resyn_rst_n,
                ready_in_N  => ready_in_N, 
                ready_in_S  => ready_in_S, 
                ready_in_E  => ready_in_E, 
                ready_in_W  => ready_in_W, 
                ready_in_L  => ready_in_L,
                request_N   => request_N, 
                request_S   => request_S, 
                request_E   => request_E, 
                request_W   => request_W, 
                request_L   => request_L,
                grant_N     => grant_N, 
                grant_S     => grant_S, 
                grant_E     => grant_E, 
                grant_W     => grant_W, 
                grant_L     => grant_L,
                pop_N       => pop_N, 
                pop_S       => pop_S, 
                pop_E       => pop_E, 
                pop_W       => pop_W, 
                pop_L       => pop_L
            );
            
        Crossbar : entity work.crossbar
            port map (
                flit_N          => flit_N, 
                flit_S          => flit_S, 
                flit_E          => flit_E, 
                flit_W          => flit_W, 
                flit_L          => flit_L,
                grant_N         => grant_N, 
                grant_S         => grant_S, 
                grant_E         => grant_E, 
                grant_W         => grant_W, 
                grant_L         => grant_L,
                flit_out_N      => flit_out_N, 
                flit_out_S      => flit_out_S, 
                flit_out_E      => flit_out_E,
                flit_out_W      => flit_out_W, 
                flit_out_L      => flit_out_L,
                valid_out_N     => valid_out_N,
                valid_out_S     => valid_out_S, 
                valid_out_E     => valid_out_E, 
                valid_out_W     => valid_out_W, 
                valid_out_L     => valid_out_L
            );        

end Behavioral;
