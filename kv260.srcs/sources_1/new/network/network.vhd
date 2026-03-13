library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library xil_defaultlib;
use xil_defaultlib.constants_pkg.all;
use xil_defaultlib.weights_pkg.all;

entity SpikeVision is
    generic (
        S_AXIS_TDATA_WIDTH_G : positive := 256;
        M_AXIS_TDATA_WIDTH_G : positive := 128;
        AXIS_TUSER_WIDTH_G : positive := 5
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
        s_axis_tuser : in std_logic_vector(AXIS_TUSER_WIDTH_G - 1 downto 0);
        s_axis_tlast : in std_logic;

        -- Output Data Stream
        m_axis_tready : in std_logic;
        m_axis_tvalid : out std_logic;
        m_axis_tdata : out std_logic_vector(M_AXIS_TDATA_WIDTH_G - 1 downto 0);
        m_axis_tkeep : out std_logic_vector((M_AXIS_TDATA_WIDTH_G/8) - 1 downto 0);
        m_axis_tuser : out std_logic_vector(AXIS_TUSER_WIDTH_G - 1 downto 0);
        m_axis_tlast : out std_logic
    );
end entity SpikeVision;

architecture rtl of SpikeVision is
    signal dma_conv1_tready : std_logic;
    signal dma_conv1_tvalid : std_logic;
    signal dma_conv1_tdata : std_logic_vector(256 - 1 downto 0);
    signal dma_conv1_tkeep : std_logic_vector(256/8 - 1 downto 0);
    signal dma_conv1_tuser : std_logic_vector(AXIS_TUSER_WIDTH_G - 1 downto 0);
    signal dma_conv1_tlast : std_logic;
    signal conv1_maxpool1_tready : std_logic;
    signal conv1_maxpool1_tvalid : std_logic;
    signal conv1_maxpool1_tdata : std_logic_vector(128 - 1 downto 0);
    signal conv1_maxpool1_tkeep : std_logic_vector(128/8 - 1 downto 0);
    signal conv1_maxpool1_tuser : std_logic_vector(AXIS_TUSER_WIDTH_G - 1 downto 0);
    signal conv1_maxpool1_tlast : std_logic;
    signal conv1_debug : std_logic_vector(CONV1_ACCUM_WIDTH_C - 1 downto 0);
begin
    s_axis_tready <= dma_conv1_tready;
    dma_conv1_tvalid <= s_axis_tvalid;
    dma_conv1_tdata <= s_axis_tdata;
    dma_conv1_tkeep <= s_axis_tkeep;
    dma_conv1_tuser <= s_axis_tuser;
    dma_conv1_tlast <= s_axis_tlast;

    conv1_maxpool1_tready <= m_axis_tready;
    m_axis_tvalid <= conv1_maxpool1_tvalid;
    m_axis_tdata <= conv1_maxpool1_tdata;
    m_axis_tkeep <= conv1_maxpool1_tkeep;
    m_axis_tuser <= conv1_maxpool1_tuser;
    m_axis_tlast <= conv1_maxpool1_tlast;

    con1 : entity xil_defaultlib.Conv1_Layer
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
end rtl;