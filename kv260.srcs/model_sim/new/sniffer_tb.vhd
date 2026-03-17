library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;
use ieee.std_logic_textio.all;

library xil_defaultlib;
use xil_defaultlib.constants_pkg.all;
use xil_defaultlib.weights_pkg.all;

entity sniffer_tb is
end entity;

architecture sim of sniffer_tb is

    constant S_AXIS_TDATA_WIDTH_G : positive := 256;
    constant M_AXIS_TDATA_WIDTH_G : positive := 64;
    constant CLK_PERIOD : time := 10 ns;
    constant NUM_WORDS_C : natural := 128;

    signal aclk : std_logic := '0';
    signal aresetn : std_logic := '0';

    -- Top-level stimulus interface
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

    -- Internal SpikeVision interconnects
    signal dma_conv1_tready : std_logic;
    signal dma_conv1_tvalid : std_logic;
    signal dma_conv1_tdata : std_logic_vector(CONV1_TDATA_WIDTH - 1 downto 0);
    signal dma_conv1_tkeep : std_logic_vector(CONV1_TDATA_WIDTH/8 - 1 downto 0);
    signal dma_conv1_tuser : std_logic_vector(AXIS_TUSER_WIDTH_C - 1 downto 0);
    signal dma_conv1_tlast : std_logic;

    signal conv1_maxpool1_tready : std_logic;
    signal conv1_maxpool1_tvalid : std_logic;
    signal conv1_maxpool1_tdata : std_logic_vector(MAXPOOL1_TDATA_WIDTH - 1 downto 0);
    signal conv1_maxpool1_tkeep : std_logic_vector(MAXPOOL1_TDATA_WIDTH/8 - 1 downto 0);
    signal conv1_maxpool1_tuser : std_logic_vector(AXIS_TUSER_WIDTH_C - 1 downto 0);
    signal conv1_maxpool1_tlast : std_logic;

    signal maxpool1_conv2_tready : std_logic;
    signal maxpool1_conv2_tvalid : std_logic;
    signal maxpool1_conv2_tdata : std_logic_vector(CONV2_TDATA_WIDTH - 1 downto 0);
    signal maxpool1_conv2_tkeep : std_logic_vector(CONV2_TDATA_WIDTH/8 - 1 downto 0);
    signal maxpool1_conv2_tuser : std_logic_vector(AXIS_TUSER_WIDTH_C - 1 downto 0);
    signal maxpool1_conv2_tlast : std_logic;

    signal conv1_debug : std_logic_vector(11 downto 0);
    signal maxpool1_debug : std_logic_vector(11 downto 0);

    file f_input_frame : text open read_mode is "../../../../kv260.srcs/model_sim/new/split_frames/frame_000000.txt";
    file f_dma_conv1 : text open write_mode is "../../../../kv260.srcs/model_sim/new/axi_dma_to_conv1.log";
    file f_conv1_maxpool1 : text open write_mode is "../../../../kv260.srcs/model_sim/new/axi_conv1_to_maxpool1.log";
    file f_maxpool1_conv2 : text open write_mode is "../../../../kv260.srcs/model_sim/new/axi_maxpool1_to_conv2.log";

    procedure log_axi_transfer(
        file log_f : text;
        constant if_name : in string;
        constant cyc : in natural;
        signal tdata_s : in std_logic_vector;
        signal tkeep_s : in std_logic_vector;
        signal tuser_s : in std_logic_vector;
        signal tlast_s : in std_logic
    ) is
        variable l : line;
    begin
        -- write(l, string'("cycle="));
        -- write(l, cyc);
        -- write(l, string'(" time="));
        -- write(l, now);
        -- write(l, string'(" if="));
        -- write(l, if_name);
        -- write(l, string'(" tdata=0x"));
        write(l, tdata_s);
        -- write(l, string'(" tkeep=0x"));
        -- hwrite(l, tkeep_s);
        -- write(l, string'(" tuser=0x"));
        write(l, string'(",0x"));
        hwrite(l, tuser_s);
        -- write(l, string'(" tlast="));
        -- write(l, std_logic'image(tlast_s));
        writeline(log_f, l);
    end procedure;

begin
    --------------------------------------------------------------------
    -- Same top-level connectivity as the SpikeVision wrapper
    --------------------------------------------------------------------
    s_axis_tready <= dma_conv1_tready;
    dma_conv1_tvalid <= s_axis_tvalid;
    dma_conv1_tdata <= s_axis_tdata;
    dma_conv1_tkeep <= s_axis_tkeep;
    dma_conv1_tuser <= s_axis_tuser;
    dma_conv1_tlast <= s_axis_tlast;

    maxpool1_conv2_tready <= m_axis_tready;
    m_axis_tvalid <= maxpool1_conv2_tvalid;
    m_axis_tdata <= maxpool1_conv2_tdata;
    m_axis_tkeep <= maxpool1_conv2_tkeep;
    m_axis_tuser <= maxpool1_conv2_tuser;
    m_axis_tlast <= maxpool1_conv2_tlast;

    --------------------------------------------------------------------
    -- DUT decomposed into SpikeVision sub-components
    --------------------------------------------------------------------
    conv1_i : entity xil_defaultlib.Conv1_Layer
        generic map(
            S_AXIS_TDATA_WIDTH_G => CONV1_TDATA_WIDTH,
            M_AXIS_TDATA_WIDTH_G => MAXPOOL1_TDATA_WIDTH,
            COLUMS_PER_CYCLE => 32
        )
        port map(
            aclk => aclk,
            aresetn => aresetn,
            s_axis_tready => dma_conv1_tready,
            s_axis_tvalid => dma_conv1_tvalid,
            s_axis_tdata => dma_conv1_tdata,
            s_axis_tkeep => dma_conv1_tkeep,
            s_axis_tuser => dma_conv1_tuser,
            s_axis_tlast => dma_conv1_tlast,
            m_axis_tready => conv1_maxpool1_tready,
            m_axis_tvalid => conv1_maxpool1_tvalid,
            m_axis_tdata => conv1_maxpool1_tdata,
            m_axis_tkeep => conv1_maxpool1_tkeep,
            m_axis_tuser => conv1_maxpool1_tuser,
            m_axis_tlast => conv1_maxpool1_tlast,
            d_output => conv1_debug
        );

    maxpool1_i : entity xil_defaultlib.Maxpool1_Layer
        generic map(
            S_AXIS_TDATA_WIDTH_G => MAXPOOL1_TDATA_WIDTH,
            M_AXIS_TDATA_WIDTH_G => CONV2_TDATA_WIDTH
        )
        port map(
            aclk => aclk,
            aresetn => aresetn,
            s_axis_tready => conv1_maxpool1_tready,
            s_axis_tvalid => conv1_maxpool1_tvalid,
            s_axis_tdata => conv1_maxpool1_tdata,
            s_axis_tkeep => conv1_maxpool1_tkeep,
            s_axis_tuser => conv1_maxpool1_tuser,
            s_axis_tlast => conv1_maxpool1_tlast,
            m_axis_tready => maxpool1_conv2_tready,
            m_axis_tvalid => maxpool1_conv2_tvalid,
            m_axis_tdata => maxpool1_conv2_tdata,
            m_axis_tkeep => maxpool1_conv2_tkeep,
            m_axis_tuser => maxpool1_conv2_tuser,
            m_axis_tlast => maxpool1_conv2_tlast,
            d_output => maxpool1_debug
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
    -- AXI Stream monitors: one file per connection
    --------------------------------------------------------------------
    monitor_proc : process (aclk)
        variable cycle_cnt : natural := 0;
    begin
        if rising_edge(aclk) then
            if aresetn = '0' then
                cycle_cnt := 0;
            else
                cycle_cnt := cycle_cnt + 1;

                if dma_conv1_tvalid = '1' and dma_conv1_tready = '1' then
                    log_axi_transfer(f_dma_conv1, "dma_conv1", cycle_cnt,
                    dma_conv1_tdata, dma_conv1_tkeep,
                    dma_conv1_tuser, dma_conv1_tlast);
                end if;

                if conv1_maxpool1_tvalid = '1' and conv1_maxpool1_tready = '1' then
                    log_axi_transfer(f_conv1_maxpool1, "conv1_maxpool1", cycle_cnt,
                    conv1_maxpool1_tdata, conv1_maxpool1_tkeep,
                    conv1_maxpool1_tuser, conv1_maxpool1_tlast);
                end if;

                if maxpool1_conv2_tvalid = '1' and maxpool1_conv2_tready = '1' then
                    log_axi_transfer(f_maxpool1_conv2, "maxpool1_conv2", cycle_cnt,
                    maxpool1_conv2_tdata, maxpool1_conv2_tkeep,
                    maxpool1_conv2_tuser, maxpool1_conv2_tlast);
                end if;
            end if;
        end if;
    end process;

    --------------------------------------------------------------------
    -- Stimulus
    --------------------------------------------------------------------
    -- stim_proc : process
    --     variable tx_val : unsigned(S_AXIS_TDATA_WIDTH_G - 1 downto 0);
    -- begin
    --     s_axis_tvalid <= '0';
    --     s_axis_tdata <= (others => '0');
    --     s_axis_tkeep <= (others => '1');
    --     s_axis_tuser <= (others => '0');
    --     s_axis_tlast <= '0';

    --     aresetn <= '0';
    --     wait for 50 ns;
    --     wait until rising_edge(aclk);
    --     aresetn <= '1';
    --     wait until rising_edge(aclk);

    --     tx_val := (others => '0');

    --     for i in 0 to NUM_WORDS_C - 1 loop
    --         s_axis_tvalid <= '1';
    --         s_axis_tdata <= std_logic_vector(tx_val);
    --         s_axis_tkeep <= (others => '1');
    --         s_axis_tuser <= (others => '0');

    --         if i = NUM_WORDS_C - 1 then
    --             s_axis_tlast <= '1';
    --         else
    --             s_axis_tlast <= '0';
    --         end if;

    --         loop
    --             wait until rising_edge(aclk);

    --             if s_axis_tvalid = '1' then
    --                 assert s_axis_tdata = std_logic_vector(tx_val)
    --                 report "AXIS source changed tdata before handshake"
    --                     severity error;
    --             end if;

    --             exit when s_axis_tready = '1';
    --         end loop;

    --         assert s_axis_tready = '1'
    --         report "Expected DUT to be ready for AXIS transfer"
    --             severity error;

    --         tx_val := tx_val + 1;
    --     end loop;

    --     wait until rising_edge(aclk);
    --     s_axis_tvalid <= '0';
    --     s_axis_tdata <= (others => '0');
    --     s_axis_tkeep <= (others => '0');
    --     s_axis_tuser <= (others => '0');
    --     s_axis_tlast <= '0';

    --     wait until m_axis_tlast = '1' for 1 ms;
    --     wait for 3 us;

    --     assert false report "End of simulation" severity failure;
    -- end process;
    stim_proc : process
        variable line_v : line;
        variable tx_val : std_logic_vector(S_AXIS_TDATA_WIDTH_G - 1 downto 0);
    begin
        s_axis_tvalid <= '0';
        s_axis_tdata <= (others => '0');
        s_axis_tkeep <= (others => '1');
        s_axis_tuser <= (others => '0');
        s_axis_tlast <= '0';

        aresetn <= '0';
        wait for 50 ns;
        wait until rising_edge(aclk);
        aresetn <= '1';
        wait until rising_edge(aclk);
        -- This is to include padding
        for i in -1 to NUM_WORDS_C loop
            if (i =- 1) or (i = NUM_WORDS_C) then
                tx_val := (others => '0');
            else
                assert not endfile(f_input_frame)
                report "Input file has fewer lines than NUM_WORDS_C"
                    severity failure;

                readline(f_input_frame, line_v);
                read(line_v, tx_val);
            end if;

            s_axis_tvalid <= '1';
            s_axis_tdata <= tx_val;
            s_axis_tkeep <= (others => '1');
            s_axis_tuser <= (others => '0');
            -- This also takes into account the padding
            if i = NUM_WORDS_C then
                s_axis_tlast <= '1';
            else
                s_axis_tlast <= '0';
            end if;

            loop
                wait until rising_edge(aclk);

                if s_axis_tvalid = '1' then
                    assert s_axis_tdata = tx_val
                    report "AXIS source changed tdata before handshake"
                        severity error;
                end if;

                exit when s_axis_tready = '1';
            end loop;

            assert s_axis_tready = '1'
            report "Expected DUT to be ready for AXIS transfer"
                severity error;
        end loop;

        assert endfile(f_input_frame)
        report "Input file has more lines than NUM_WORDS_C"
            severity warning;

        wait until rising_edge(aclk);
        s_axis_tvalid <= '0';
        s_axis_tdata <= (others => '0');
        s_axis_tkeep <= (others => '0');
        s_axis_tuser <= (others => '0');
        s_axis_tlast <= '0';

        wait until m_axis_tlast = '1' for 1 ms;
        wait for 3 us;

        assert false report "End of simulation" severity failure;
    end process;

end architecture;