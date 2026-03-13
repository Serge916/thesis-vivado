library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library xil_defaultlib;
use xil_defaultlib.constants_pkg.all;
use xil_defaultlib.weights_pkg.all;

entity SpikeVision is
    generic (
        S_AXIS_TDATA_WIDTH_G : positive := 256; -- 128 per line * 2 input channels
        M_AXIS_TDATA_WIDTH_G : positive := 64 -- 128 per line * 2 input channels
    );
    port (
        -- Clock and Reset
        aclk : in std_logic;
        aresetn : in std_logic;

        -- Input Data Stream
        s_axis_tready : out std_logic;
        s_axis_tvalid : in std_logic;
        s_axis_tdata : in std_logic_vector(S_AXIS_TDATA_WIDTH_G - 1 downto 0);
        s_axis_tkeep : in std_logic_vector((S_AXIS_TDATA_WIDTH_G/8) - 1 downto 0);
        s_axis_tuser : in std_logic_vector(AXIS_TUSER_WIDTH_C - 1 downto 0);
        s_axis_tlast : in std_logic;

        -- Output Data Stream
        m_axis_tready : in std_logic;
        m_axis_tvalid : out std_logic;
        m_axis_tdata : out std_logic_vector(M_AXIS_TDATA_WIDTH_G - 1 downto 0);
        m_axis_tkeep : out std_logic_vector((M_AXIS_TDATA_WIDTH_G/8) - 1 downto 0);
        m_axis_tuser : out std_logic_vector(AXIS_TUSER_WIDTH_C - 1 downto 0);
        m_axis_tlast : out std_logic
    );
end entity SpikeVision;

architecture rtl of SpikeVision is
    -- INPUT TO CONV1
    signal dma_conv1_tready : std_logic;
    signal dma_conv1_tvalid : std_logic;
    signal dma_conv1_tdata : std_logic_vector(CONV1_TDATA_WIDTH - 1 downto 0);
    signal dma_conv1_tkeep : std_logic_vector(CONV1_TDATA_WIDTH/8 - 1 downto 0);
    signal dma_conv1_tuser : std_logic_vector(AXIS_TUSER_WIDTH_C - 1 downto 0);
    signal dma_conv1_tlast : std_logic;
    -- CONV1 TO MAXPOOL1
    signal conv1_maxpool1_tready : std_logic;
    signal conv1_maxpool1_tvalid : std_logic;
    signal conv1_maxpool1_tdata : std_logic_vector(MAXPOOL1_TDATA_WIDTH - 1 downto 0);
    signal conv1_maxpool1_tkeep : std_logic_vector(MAXPOOL1_TDATA_WIDTH/8 - 1 downto 0);
    signal conv1_maxpool1_tuser : std_logic_vector(AXIS_TUSER_WIDTH_C - 1 downto 0);
    signal conv1_maxpool1_tlast : std_logic;
    signal conv1_debug : std_logic_vector(11 downto 0);
    -- MAXPOOL1 TO CONV2
    signal maxpool1_conv2_tready : std_logic;
    signal maxpool1_conv2_tvalid : std_logic;
    signal maxpool1_conv2_tdata : std_logic_vector(CONV2_TDATA_WIDTH - 1 downto 0);
    signal maxpool1_conv2_tkeep : std_logic_vector(CONV2_TDATA_WIDTH/8 - 1 downto 0);
    signal maxpool1_conv2_tuser : std_logic_vector(AXIS_TUSER_WIDTH_C - 1 downto 0);
    signal maxpool1_conv2_tlast : std_logic;
    signal maxpool1_debug : std_logic_vector(11 downto 0);
begin
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

    conv1 : entity xil_defaultlib.Conv1_Layer
        generic map(
            S_AXIS_TDATA_WIDTH_G => CONV1_TDATA_WIDTH, -- 128 per line * 2 input channels
            M_AXIS_TDATA_WIDTH_G => MAXPOOL1_TDATA_WIDTH, -- 128 per line * 2 input channels
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

    maxpool1 : entity xil_defaultlib.Maxpool1_Layer
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
end rtl;