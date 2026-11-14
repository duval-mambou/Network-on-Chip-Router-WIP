----------------------------------------------------------------------------------
-- Company: 
-- Engineer: Duval Mambou
-- 
-- Create Date: 11.11.2026 17:23:52
-- Design Name: 
-- Module Name: priority_encoder - Behavioral
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

entity priority_encoder is
  Port ( 
        request : in requestors_vec_t;
        grant   : out requestors_vec_t
  );
end priority_encoder;

architecture Behavioral of priority_encoder is

begin

    grant(0) <= request(0);
    grant(1) <= request(1) and not request(0);
    grant(2) <= request(2) and not request(1) and not request(0);
    grant(3) <= request(3) and not request(2) and not request(1) and not request(0);

end Behavioral;
