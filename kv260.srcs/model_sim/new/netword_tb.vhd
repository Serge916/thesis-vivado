library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library xil_defaultlib;
use xil_defaultlib.constants_pkg.all;
use xil_defaultlib.weights_pkg.all;

entity network_tb is
end entity;

architecture sim of network_tb is

    constant S_AXIS_TDATA_WIDTH_G : positive := 256;
    constant M_AXIS_TDATA_WIDTH_G : positive := 8;

    signal aclk : std_logic := '0';
    signal aresetn : std_logic := '0';

    signal s_axis_tready : std_logic;
    signal s_axis_tvalid : std_logic := '0';
    signal s_axis_tdata : std_logic_vector(S_AXIS_TDATA_WIDTH_G - 1 downto 0) := (others => '0');
    signal s_axis_tkeep : std_logic_vector((S_AXIS_TDATA_WIDTH_G/8) - 1 downto 0) := (others => '0');
    signal s_axis_tuser : std_logic_vector(AXIS_TUSER_WIDTH_C - 1 downto 0) := (others => '0');
    signal s_axis_tlast : std_logic := '0';

    signal m_axis_tready : std_logic := '1';
    signal m_axis_tvalid : std_logic;
    signal m_axis_tdata : std_logic_vector(M_AXIS_TDATA_WIDTH_G - 1 downto 0);
    signal m_axis_tkeep : std_logic_vector((M_AXIS_TDATA_WIDTH_G/8) - 1 downto 0);
    signal m_axis_tuser : std_logic_vector(AXIS_TUSER_WIDTH_C - 1 downto 0);
    signal m_axis_tlast : std_logic;

    signal d_output : std_logic_vector(CONV1_ACCUM_WIDTH_C - 1 downto 0);

    constant CLK_PERIOD : time := 8 ns; -- 125 MHz

begin
    --------------------------------------------------------------------
    -- DUT
    --------------------------------------------------------------------
    uut : entity xil_defaultlib.SpikeVision
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
            m_axis_tlast => m_axis_tlast
        );

    --------------------------------------------------------------------
    -- Clock generation
    --------------------------------------------------------------------
    clk_process : process
    begin
        loop
            aclk <= '0';
            wait for CLK_PERIOD/2;
            aclk <= '1';
            wait for CLK_PERIOD/2;
        end loop;
    end process;

    --------------------------------------------------------------------
    -- Stimulus
    --------------------------------------------------------------------
    stim_proc : process
        variable tx_val : unsigned(S_AXIS_TDATA_WIDTH_G/2 - 1 downto 0); -- /2 to include both channels in one word (256 bits total)
        constant NUM_WORDS_C : natural := 130; -- 128 rows + 2 of padding
    begin
        -- Default inputs
        s_axis_tvalid <= '0';
        s_axis_tdata <= (others => '0');
        s_axis_tkeep <= (others => '1'); -- all bytes valid
        s_axis_tuser <= (others => '0');
        s_axis_tlast <= '0';

        -- Reset
        aresetn <= '0';
        wait for 50 ns;
        wait until rising_edge(aclk);
        aresetn <= '1';
        wait until rising_edge(aclk);

        -- Send increasing AXI Stream values
        tx_val := (others => '0');

        for i in 0 to NUM_WORDS_C - 1 loop
            s_axis_tvalid <= '1';
            s_axis_tdata <= std_logic_vector(tx_val & tx_val);
            s_axis_tkeep <= (others => '1');
            s_axis_tuser <= (others => '0');

            if i = NUM_WORDS_C - 1 then
                s_axis_tlast <= '1';
            else
                s_axis_tlast <= '0';
            end if;

            -- Wait until DUT is ready and transfer occurs
            loop
                wait until rising_edge(aclk);

                if s_axis_tvalid = '1' then
                    assert s_axis_tdata = std_logic_vector(tx_val & tx_val)
                    report "AXIS source changed tdata before handshake"
                        severity error;
                end if;

                exit when s_axis_tready = '1';
            end loop;

            -- Handshake happened on this clock edge
            assert s_axis_tready = '1'
            report "Expected DUT to be ready for AXIS transfer"
                severity error;

            tx_val := tx_val + 1;
            -- tx_val := (others => '1');
        end loop;

        -- Deassert stream after final transfer
        wait until rising_edge(aclk);
        s_axis_tvalid <= '0';
        s_axis_tdata <= (others => '0');
        s_axis_tkeep <= (others => '0');
        s_axis_tuser <= (others => '0');
        s_axis_tlast <= '0';

        wait until m_axis_tlast /= '0' for 1ms;
        -- Let DUT run for a while
        wait for 3us;

        assert false report "End of simulation" severity failure;
    end process;

end architecture;