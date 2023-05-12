----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    16:11:25 03/21/2022 
-- Design Name: 
-- Module Name:    MCD - Behavioral 
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
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
use IEEE.STD_LOGIC_UNSIGNED.All;
use ieee.std_logic_arith.all ;
-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity MCD is
    Port ( D_Line 										: inout  STD_LOGIC_VECTOR (15 downto 0);
           A_Upper 										: out  STD_LOGIC_VECTOR (3 downto 0);
           A_Enable 									: out  STD_LOGIC_VECTOR (1 downto 0);
           A_Lower 										: out  STD_LOGIC_VECTOR (5 downto 0);
           RESET_INV 									: inout  STD_LOGIC;
           RESET 										: inout  STD_LOGIC;
           READ_ENABLE --OE								: out  STD_LOGIC;
           WRITE_ENABLE --WE							: out  STD_LOGIC;
           RW 											: in  STD_LOGIC;
           BERR 										: out  STD_LOGIC; --always high
           DTACK 										: out  STD_LOGIC;
           IPL0 										: out  STD_LOGIC; --high
           IPL1 										: out  STD_LOGIC; --high
           IPL2 										: out  STD_LOGIC; --high
           LRAM 										: out  STD_LOGIC;
           URAM 										: out  STD_LOGIC;
           LROM 										: out  STD_LOGIC;
           UROM 										: out  STD_LOGIC;
           BR 											: out  STD_LOGIC; --high
           BGACK 										: out  STD_LOGIC; --high
           BG 											: in  STD_LOGIC; --disconnect
           VPA 											: out  STD_LOGIC; --high
           VMA 											: in  STD_LOGIC; --discoonect
           E 											: in  STD_LOGIC; --disco
           AS 											: in  STD_LOGIC;
           UDS 											: in  STD_LOGIC;
           LDS 											: in  STD_LOGIC;
           IACK 										: inout  STD_LOGIC;
           DUART 										: inout  STD_LOGIC;
           DUARTIRQ 									: inout  STD_LOGIC;
           CPU_Clock 									: in  STD_LOGIC;
           X1 											: in  STD_LOGIC;
           LED 											: inout  STD_LOGIC_VECTOR (7 downto 0));

end MCD;

architecture Behavioral of MCD is
			 
			  signal CLOCK_COUNTER: std_logic_vector(25 downto 0);
			  alias 	MEMORY_ADD:		std_logic_vector(1 downto 0) is A_Enable(1 downto 0);
					
begin
				--Read/Write Assignments
				READ_ENABLE <= not RW;
				WRITE_ENABLE <= RW;

				RESET_INV <= 'Z';
				HALTT <= 'Z';
				RESET <= 'Z';

				--Pin always on Assignments
				IPL0 <= '1';
				IPL1 <= '1';
				IPL2 <= '1';				
				
				BERR <= '1';
				
				BR <= '1';
				BGACK <= '1';
				VPA <= '1';
				
				--Clock Divider
			    process(CPU_Clock)
				begin
						if(RISING_edge(CPU_Clock)) then
							CLOCK_COUNTER <= CLOCK_COUNTER + '1';
						end if;
				end process;
				
				--Address Decoding
				LROM  <= (LDS OR AS) when MEMORY_ADD = "00" else '1';
				UROM  <= (UDS OR AS) when MEMORY_ADD = "00" else '1';
				
				LRAM  <= (LDS OR AS) when MEMORY_ADD = "01" else '1';
				URAM  <= (UDS OR AS) when MEMORY_ADD = "01" else '1';
				
				DUART <= (LDS OR AS) when MEMORY_ADD = "10" else '1';
				
				DTACK <= 'Z' when MEMORY_ADD = "10" else AS;
				--LED				
				LED(0) <= CLOCK_COUNTER(17);
				LED(1) <= CLOCK_COUNTER(18);
				LED(2) <= CLOCK_COUNTER(19);
				LED(3) <= CLOCK_COUNTER(20);
				LED(4) <= CLOCK_COUNTER(21);
				LED(5) <= CLOCK_COUNTER(22);
				LED(6) <= CLOCK_COUNTER(23);
				LED(7) <= CLOCK_COUNTER(24);


end Behavioral;


