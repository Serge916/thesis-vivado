library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library xil_defaultlib;
use xil_defaultlib.constants_pkg.all;
use xil_defaultlib.weights_pkg.all;

entity SpikeVision is
    generic (
        AXIS_TDATA_WIDTH_G : positive := 64;
        AXIS_TUSER_WIDTH_G : positive := 1
    );
    port (
        -- Clock and Reset
        aclk : in std_logic;
        aresetn : in std_logic;

        -- Input Data Stream
        s_axis_tready : out std_logic;
        s_axis_tvalid : in std_logic;
        s_axis_tdata : in std_logic_vector(AXIS_TDATA_WIDTH_G - 1 downto 0);
        s_axis_tkeep : in std_logic_vector((AXIS_TDATA_WIDTH_G/8) - 1 downto 0);
        s_axis_tuser : in std_logic_vector(AXIS_TUSER_WIDTH_G - 1 downto 0);
        s_axis_tlast : in std_logic;

        -- Debug Output
        d_output : out std_logic_vector(7 downto 0)
    );
end entity SpikeVision;

architecture rtl of SpikeVision is
    signal conv1_en : std_logic;
    signal conv1_addr : std_logic_vector(CONV1_ADDR_WIDTH_C - 1 downto 0);
    signal conv1_dout : std_logic_vector(7 downto 0);

begin
    conv1_mem : entity xil_defaultlib.Conv1_ROM
        port map(
            clk => aclk,
            en => conv1_en,
            addr => conv1_addr,
            dout => conv1_dout
        );

    d_output <= conv1_dout;
    s_axis_tready <= '1';

    debug : process (aclk)
        variable i : integer range 0 to 575 := 0;
    begin
        if rising_edge(aclk) then
            -- output_q <= myram(i);
            conv1_addr <= std_logic_vector(to_unsigned(i, conv1_addr'length));
            if i < 575 then
                i := i + 1;
            else
                i := 0;
            end if;
        end if;
    end process;

end rtl;