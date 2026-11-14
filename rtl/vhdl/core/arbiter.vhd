----------------------------------------------------------------------------------
-- Company: 
-- Engineer: Duval Mambou
-- 
-- Create Date: 11.11.2026 13:29:49
-- Design Name: 
-- Module Name: arbiter_x - Behavioral
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

entity arbiter_x is  Port ( 
    clk, rst_n : in std_logic ;
    request_x : in requestors_vec_t;
    grant_a_x : out requestors_vec_t  -- mean grant given by an arbiter
        );
end arbiter_x;

architecture Behavioral of arbiter_x is

constant REQUEST_NULL : requestors_vec_t := "0000";

signal pointer : requestors_vec_t;
signal grant_masked, grant_full, grant_X : requestors_vec_t;
signal request_masked : requestors_vec_t;
signal use_full : std_logic ;

begin
    
    -- mask process
    process (request_x, pointer)
        variable mask : requestors_vec_t;
    begin
        mask(0) := '0';
        mask(1) := pointer(0);
        mask(2) := pointer(1) or pointer(0);
        mask(3) := pointer(2) or pointer(1) or pointer(0);
        
        request_masked <= request_x and mask;
    end process;
    
    process (clk, rst_n)
    begin
      if rst_n = '0' then
        pointer <= "1000";
      elsif rising_edge(clk) then
        if grant_X /= REQUEST_NULL then
          pointer <= grant_X;
        end if;
      end if;
    end process;
    
    -- first priority encoder
    enc_masked : entity work.priority_encoder
    port map (
            request => request_masked,
            grant   => grant_masked
        );
      
    -- second priority encoder    
    enc_raw : entity work.priority_encoder
    port map (
            request => request_x,
            grant   => grant_full
        );
        
   -- writing grant select
   use_full <= '1' when request_masked = REQUEST_NULL else '0';      
        
   -- mux final grant select
   grant_X <= grant_masked when use_full = '0' else grant_full;
 
   grant_a_x <= grant_X;

end Behavioral;
