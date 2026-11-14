----------------------------------------------------------------------------------
-- Company: 
-- Engineer: Duval Mambou
-- 
-- Create Date: 11.10.2026 10:33:11
-- Design Name: 
-- Module Name: fifo - Behavioral
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
use work.router_pkg.all;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity fifo is
  generic (DEPTH : positive := FIFO_DEPTH);
  Port ( 
    clk, rst_n  : in std_logic ;
    wr_en       : in std_logic ;
    rd_en       : in std_logic ;
    data_in     : in flit_t ;
    data_out    : out flit_t ;
    empty       : out std_logic ;
    full        : out std_logic
  );
end fifo;

architecture Behavioral of fifo is
    type mem_t is array (0 to DEPTH - 1) of flit_t;
    signal mem      : mem_t;
    signal wr_ptr   : natural  range 0 to DEPTH - 1;
    signal rd_ptr   : natural  range 0 to DEPTH - 1;
    signal count    : natural range  0 to DEPTH;
    signal s_empty, s_full : std_logic ;
    signal do_wr, do_rd    : std_logic ;
begin
    s_empty <= '1' when count = 0 else '0';
    s_full <= '1' when count = DEPTH else '0';
    empty <= s_empty;
    full <= s_full;
    
    -- ignore read operation when empty, and write operation when full
    do_wr <= wr_en and not s_full;
    do_rd <= rd_en and not s_empty;
    
    data_out <= mem(rd_ptr);
    
    process (clk, rst_n)
    begin
        if rst_n = '0' then
            wr_ptr <= 0;
            rd_ptr <= 0;
            count <= 0;
        elsif rising_edge (clk) then
            if do_wr = '1' then
                mem(wr_ptr) <= data_in;
                if wr_ptr = DEPTH - 1 then wr_ptr <= 0; else wr_ptr <= wr_ptr + 1; end if;
            end if;
            
            if do_rd = '1' then
                if rd_ptr = DEPTH - 1 then rd_ptr <= 0; else rd_ptr <= rd_ptr + 1; end if;
            end if;
            
            if do_wr = '1' and do_rd = '0' then count <= count + 1; 
            elsif do_wr = '0' and do_rd = '1' then count <= count - 1;
            end if; -- both read and write operations, count doesnt change
        end if;
    end process;

end Behavioral;
