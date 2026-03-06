library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library xil_defaultlib;
use xil_defaultlib.constants_pkg.all;
use xil_defaultlib.weights_pkg.all;

entity Conv1_ROM is
    port (
        -- Clock and Reset
        clk : in std_logic;

        -- Input
        en : in std_logic;
        addr : in std_logic_vector(CONV1_ADDR_WIDTH_C - 1 downto 0);
        -- Output
        dout : out std_logic_vector(7 downto 0)
    );
end entity Conv1_ROM;

architecture rtl of Conv1_ROM is

    signal rom : conv1_ram_t := CONV1_ARRAY;

    attribute ram_style : string;
    attribute ram_style of rom : signal is "block";

    signal dout_q : std_logic_vector(7 downto 0);

begin

    dout <= dout_q;

    read : process (clk)
    begin
        if rising_edge(clk) then
            dout_q <= rom(to_integer(unsigned(addr)));
        end if;
    end process;

end rtl;