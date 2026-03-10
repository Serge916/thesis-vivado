library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library xil_defaultlib;
use xil_defaultlib.constants_pkg.all;
use xil_defaultlib.weights_pkg.all;

entity network_tb is
end entity;

architecture sim of network_tb is

    constant AXIS_TDATA_WIDTH_G : positive := 128;
    constant AXIS_TUSER_WIDTH_G : positive := 1;

    signal aclk : std_logic := '0';
    signal aresetn : std_logic := '0';

    signal s_axis_tready : std_logic;
    signal s_axis_tvalid : std_logic := '0';
    signal s_axis_tdata : std_logic_vector(AXIS_TDATA_WIDTH_G - 1 downto 0) := (others => '0');
    signal s_axis_tkeep : std_logic_vector((AXIS_TDATA_WIDTH_G/8) - 1 downto 0) := (others => '0');
    signal s_axis_tuser : std_logic_vector(AXIS_TUSER_WIDTH_G - 1 downto 0) := (others => '0');
    signal s_axis_tlast : std_logic := '0';

    signal m_axis_tready : std_logic := '1';
    signal m_axis_tvalid : std_logic;
    signal m_axis_tdata : std_logic_vector(AXIS_TDATA_WIDTH_G - 1 downto 0);
    signal m_axis_tkeep : std_logic_vector((AXIS_TDATA_WIDTH_G/8) - 1 downto 0);
    signal m_axis_tuser : std_logic_vector(AXIS_TUSER_WIDTH_G - 1 downto 0);
    signal m_axis_tlast : std_logic;

    signal d_output : std_logic_vector(CONV1_ACCUM_WIDTH_C - 1 downto 0);

    constant CLK_PERIOD : time := 10 ns;

begin
    --------------------------------------------------------------------
    -- DUT
    --------------------------------------------------------------------
    uut : entity xil_defaultlib.SpikeVision
        generic map(
            AXIS_TDATA_WIDTH_G => AXIS_TDATA_WIDTH_G,
            AXIS_TUSER_WIDTH_G => AXIS_TUSER_WIDTH_G
        )
        port map(
            aclk => aclk,
            aresetn => aresetn,
            s_axis_tready => s_axis_tready,
            s_axis_tvalid => s_axis_tvalid,
            s_axis_tdata => s_axis_tdata,
            s_axis_tkeep => s_axis_tkeep,
            s_axis_tuser => s_axis_tuser,
            s_axis_tlast => s_axis_tlast,
            m_axis_tready => m_axis_tready,
            m_axis_tvalid => m_axis_tvalid,
            m_axis_tdata => m_axis_tdata,
            m_axis_tkeep => m_axis_tkeep,
            m_axis_tuser => m_axis_tuser,
            m_axis_tlast => m_axis_tlast,
            d_output => d_output
        );

    --------------------------------------------------------------------
    -- Clock generation
    --------------------------------------------------------------------
    clk_process : process
    begin
        while now < 5 us loop
            aclk <= '0';
            wait for CLK_PERIOD/2;
            aclk <= '1';
            wait for CLK_PERIOD/2;
        end loop;
        wait;
    end process;

    --------------------------------------------------------------------
    -- Stimulus
    --------------------------------------------------------------------
    stim_proc : process
    begin
        -- Reset
        aresetn <= '0';
        wait for 50 ns;
        aresetn <= '1';

        -- Drive some AXIS inputs, even though current DUT ignores them
        wait for 20 ns;
        s_axis_tvalid <= '1';
        s_axis_tdata <= (others => '0');
        s_axis_tkeep <= (others => '0');
        s_axis_tuser <= "1";
        s_axis_tlast <= '0';

        wait for CLK_PERIOD;
        s_axis_tdata <= (0 => '1', others => '0');
        s_axis_tlast <= '0';
        wait for CLK_PERIOD;
        s_axis_tdata <= (others => '0');
        s_axis_tvalid <= '0';
        wait for CLK_PERIOD * 3;
        s_axis_tdata <= (1 => '1', others => '0');
        s_axis_tvalid <= '1';
        wait for CLK_PERIOD;
        s_axis_tdata <= (others => '0');
        s_axis_tvalid <= '0';
        wait for CLK_PERIOD * 3;
        s_axis_tdata <= (2 => '1', others => '0');
        s_axis_tvalid <= '1';
        wait for CLK_PERIOD;
        s_axis_tdata <= (others => '0');
        s_axis_tvalid <= '0';
        wait for CLK_PERIOD * 3;
        s_axis_tdata <= (3 => '1', others => '0');
        s_axis_tvalid <= '1';

        wait for CLK_PERIOD;
        s_axis_tvalid <= '0';
        s_axis_tdata <= (others => '0');
        s_axis_tkeep <= (others => '0');
        s_axis_tuser <= (others => '0');
        s_axis_tlast <= '0';

        -- Let the RAM reader run for a while
        wait for 3 us;

        assert false report "End of simulation" severity failure;
    end process;

end architecture;