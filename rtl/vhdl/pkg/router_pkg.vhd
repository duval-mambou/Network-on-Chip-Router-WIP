----------------------------------------------------------------------------------
-- Company: 
-- Engineer: Duval Mambou
-- 
-- Create Date: 10/10/2026 11:40:05 PM
-- Design Name: 
-- Module Name: router_pkg - 
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

package router_pkg is

---------------------------------------------------------------------
-- Flit format (32 bits), header in MSB
--  [31:30] flit_type (these bits reserved for this V1 version)
--  [29:27] dest_x
--  [26:24] dest_y
--  [23:0]  payload
---------------------------------------------------------------------
constant FLIT_WIDTH      : positive := 32;
constant COORD_WIDTH     : positive := 3;    -- mesh 6x6 : from 0 to 5
constant FLIT_TYPE_WIDTH : positive := 2;
constant PAYLOAD_WIDTH   : positive := FLIT_WIDTH - FLIT_TYPE_WIDTH - 2 * COORD_WIDTH;

-- Boundaries HI : High and LO : Low
constant FLIT_TYPE_HI   : natural := FLIT_WIDTH - 1;
constant FLIT_TYPE_LO   : natural := FLIT_WIDTH - FLIT_TYPE_WIDTH;
constant DEST_X_HI      : natural := FLIT_TYPE_LO - 1;
constant DEST_X_LO      : natural := DEST_X_HI - COORD_WIDTH + 1;
constant DEST_Y_HI      : natural := DEST_X_LO - 1;
constant DEST_Y_LO      : natural := DEST_Y_HI - COORD_WIDTH + 1;

---------------------------------------------------------------------
-- Ports
---------------------------------------------------------------------
constant NUM_PORTS      : positive := 5;
constant NUM_REQUESTORS : positive := NUM_PORTS - 1;

constant PORT_N : natural := 0;
constant PORT_S : natural := 1;
constant PORT_E : natural := 2;
constant PORT_W : natural := 3;
constant PORT_L : natural := 4;

constant VALID_REQ_POS : natural := 5;

----------------------------------------------------------------------
-- Router parameters
----------------------------------------------------------------------
constant FIFO_DEPTH : positive := 4;

----------------------------------------------------------------------
-- Types 
----------------------------------------------------------------------
subtype flit_t is std_logic_vector (FLIT_WIDTH - 1 downto 0);
subtype coord_t is std_logic_vector (COORD_WIDTH - 1 downto 0);     -- x_coord, y_coord
subtype port_vec_t is std_logic_vector (NUM_PORTS - 1 downto 0);    -- one hot reg, one bit per port
subtype requestors_vec_t is std_logic_vector (NUM_REQUESTORS - 1 downto 0);     -- one hot reg, one bit per requestor
subtype request_t is std_logic_vector (NUM_PORTS downto 0);

type flit_array_t is array (0 to NUM_PORTS - 1) of flit_t;
type port_vec_array_t is array (0 to NUM_PORTS - 1) of requestors_vec_t;

----------------------------------------------------------------------
-- Flit type encoding (not used in this V1 version)
----------------------------------------------------------------------
constant FLIT_BODY  : std_logic_vector (FLIT_TYPE_WIDTH - 1 downto 0) := "00";
constant FLIT_HEAD  : std_logic_vector (FLIT_TYPE_WIDTH - 1 downto 0) := "01";
constant FLIT_TAIL  : std_logic_vector (FLIT_TYPE_WIDTH - 1 downto 0) := "10";
constant FLIT_HEAD_TAIL  : std_logic_vector (FLIT_TYPE_WIDTH - 1 downto 0) := "11";

----------------------------------------------------------------------
-- Acces functions
----------------------------------------------------------------------
function get_dest_x (f : flit_t) return coord_t;
function get_dest_y (f : flit_t) return coord_t;
 
end package router_pkg;

package body router_pkg is

    function get_dest_x (f : flit_t) return coord_t is
    begin
        return f(DEST_X_HI downto DEST_X_LO);
    end function ;
    
    function get_dest_y (f : flit_t) return coord_t is
    begin
        return f(DEST_Y_HI downto DEST_Y_LO);
    end function;
    
end package body router_pkg;