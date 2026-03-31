library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library xil_defaultlib;
use xil_defaultlib.constants_pkg.all;
use xil_defaultlib.weights_pkg.all;

entity SpikeVision is
    generic (
        S_AXIS_TDATA_WIDTH_G : positive := 256; -- 128 per line * 2 input channels
        M_AXIS_TDATA_WIDTH_G : positive := 8; -- 128 per line * 2 input channels
        AXIS_TUSER_WIDTH_G : positive := 15;
        AXIL_ADDR_WIDTH_G : positive := 32;
        AXIL_DATA_WIDTH_G : positive := 32;
        MEM_WORD_WIDTH_G : positive := 72
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
        m_axis_tlast : out std_logic;

        -- Slave AXI4-Lite Interface
        s_axi_aclk : in std_logic;
        s_axi_aresetn : in std_logic;
        s_axi_awaddr : in std_logic_vector(AXIL_ADDR_WIDTH_G - 1 downto 0);
        s_axi_awprot : in std_logic_vector(2 downto 0); -- NOT USED
        s_axi_awvalid : in std_logic;
        s_axi_awready : out std_logic;
        s_axi_wdata : in std_logic_vector(AXIL_DATA_WIDTH_G - 1 downto 0); -- NOT USED
        s_axi_wstrb : in std_logic_vector((AXIL_DATA_WIDTH_G/8) - 1 downto 0); -- NOT USED
        s_axi_wvalid : in std_logic;
        s_axi_wready : out std_logic;
        s_axi_bresp : out std_logic_vector(1 downto 0);
        s_axi_bvalid : out std_logic;
        s_axi_bready : in std_logic;
        s_axi_araddr : in std_logic_vector(AXIL_ADDR_WIDTH_G - 1 downto 0);
        s_axi_arprot : in std_logic_vector(2 downto 0); -- NOT USED
        s_axi_arvalid : in std_logic;
        s_axi_arready : out std_logic;
        s_axi_rdata : out std_logic_vector(AXIL_DATA_WIDTH_G - 1 downto 0);
        s_axi_rresp : out std_logic_vector(1 downto 0);
        s_axi_rvalid : out std_logic;
        s_axi_rready : in std_logic
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
    -- CONV2 TO MAXPOOL2
    signal conv2_maxpool2_tready : std_logic;
    signal conv2_maxpool2_tvalid : std_logic;
    signal conv2_maxpool2_tdata : std_logic_vector(MAXPOOL2_TDATA_WIDTH - 1 downto 0);
    signal conv2_maxpool2_tkeep : std_logic_vector(MAXPOOL2_TDATA_WIDTH/8 - 1 downto 0);
    signal conv2_maxpool2_tuser : std_logic_vector(AXIS_TUSER_WIDTH_C - 1 downto 0);
    signal conv2_maxpool2_tlast : std_logic;
    signal conv2_debug : std_logic_vector(11 downto 0);
    -- MAXPOOL2 TO CONV3
    signal maxpool2_conv3_tready : std_logic;
    signal maxpool2_conv3_tvalid : std_logic;
    signal maxpool2_conv3_tdata : std_logic_vector(CONV3_TDATA_WIDTH - 1 downto 0);
    signal maxpool2_conv3_tkeep : std_logic_vector(CONV3_TDATA_WIDTH/8 - 1 downto 0);
    signal maxpool2_conv3_tuser : std_logic_vector(AXIS_TUSER_WIDTH_C - 1 downto 0);
    signal maxpool2_conv3_tlast : std_logic;
    signal maxpool2_debug : std_logic_vector(11 downto 0);
    -- CONV3 TO MAXPOOL3
    signal conv3_maxpool3_tready : std_logic;
    signal conv3_maxpool3_tvalid : std_logic;
    signal conv3_maxpool3_tdata : std_logic_vector(MAXPOOL3_TDATA_WIDTH - 1 downto 0);
    signal conv3_maxpool3_tkeep : std_logic_vector(MAXPOOL3_TDATA_WIDTH/8 - 1 downto 0);
    signal conv3_maxpool3_tuser : std_logic_vector(AXIS_TUSER_WIDTH_C - 1 downto 0);
    signal conv3_maxpool3_tlast : std_logic;
    signal conv3_debug : std_logic_vector(11 downto 0);
    -- MAXPOOL3 TO CONV4
    signal maxpool3_conv4_tready : std_logic;
    signal maxpool3_conv4_tvalid : std_logic;
    signal maxpool3_conv4_tdata : std_logic_vector(CONV4_TDATA_WIDTH - 1 downto 0);
    signal maxpool3_conv4_tkeep : std_logic_vector(CONV4_TDATA_WIDTH/8 - 1 downto 0);
    signal maxpool3_conv4_tuser : std_logic_vector(AXIS_TUSER_WIDTH_C - 1 downto 0);
    signal maxpool3_conv4_tlast : std_logic;
    signal maxpool3_debug : std_logic_vector(11 downto 0);
    -- CONV4 TO MAXPOOL4
    signal conv4_maxpool4_tready : std_logic;
    signal conv4_maxpool4_tvalid : std_logic;
    signal conv4_maxpool4_tdata : std_logic_vector(MAXPOOL4_TDATA_WIDTH - 1 downto 0);
    signal conv4_maxpool4_tkeep : std_logic_vector(MAXPOOL4_TDATA_WIDTH/8 - 1 downto 0);
    signal conv4_maxpool4_tuser : std_logic_vector(AXIS_TUSER_WIDTH_C - 1 downto 0);
    signal conv4_maxpool4_tlast : std_logic;
    signal conv4_debug : std_logic_vector(11 downto 0);
    -- MAXPOOL4 TO CONV5
    signal maxpool4_conv5_tready : std_logic;
    signal maxpool4_conv5_tvalid : std_logic;
    signal maxpool4_conv5_tdata : std_logic_vector(CONV5_TDATA_WIDTH - 1 downto 0);
    signal maxpool4_conv5_tkeep : std_logic_vector(CONV5_TDATA_WIDTH/8 - 1 downto 0);
    signal maxpool4_conv5_tuser : std_logic_vector(AXIS_TUSER_WIDTH_C - 1 downto 0);
    signal maxpool4_conv5_tlast : std_logic;
    signal maxpool4_debug : std_logic_vector(11 downto 0);
    -- CONV5 TO SCREENER1
    signal conv5_screener1_tready : std_logic;
    signal conv5_screener1_tvalid : std_logic;
    signal conv5_screener1_tdata : std_logic_vector(SCREENER1_TDATA_WIDTH - 1 downto 0);
    signal conv5_screener1_tkeep : std_logic_vector(SCREENER1_TDATA_WIDTH/8 - 1 downto 0);
    signal conv5_screener1_tuser : std_logic_vector(AXIS_TUSER_WIDTH_C - 1 downto 0);
    signal conv5_screener1_tlast : std_logic;
    signal conv5_debug : std_logic_vector(11 downto 0);

    -- REGISTER BANK
    signal load_mode : std_logic;
    signal soft_reset : std_logic;
    signal enable_operation : std_logic;
    signal conv1_wr_en : std_logic;
    signal conv1_wr_addr : std_logic_vector(CONV1_ADDR_WIDTH_C - 1 downto 0);
    signal conv1_wr_data : std_logic_vector(MEM_WORD_WIDTH_G - 1 downto 0);
    signal conv2_wr_en : std_logic;
    signal conv2_wr_addr : std_logic_vector(CONV2_ADDR_WIDTH_C - 1 downto 0);
    signal conv2_wr_data : std_logic_vector(MEM_WORD_WIDTH_G - 1 downto 0);
    signal conv3_wr_en : std_logic;
    signal conv3_wr_addr : std_logic_vector(CONV3_ADDR_WIDTH_C - 1 downto 0);
    signal conv3_wr_data : std_logic_vector(MEM_WORD_WIDTH_G - 1 downto 0);
    signal conv4_wr_en : std_logic;
    signal conv4_wr_addr : std_logic_vector(CONV4_ADDR_WIDTH_C - 1 downto 0);
    signal conv4_wr_data : std_logic_vector(MEM_WORD_WIDTH_G - 1 downto 0);
    signal conv5_wr_en : std_logic;
    signal conv5_wr_addr : std_logic_vector(CONV5_ADDR_WIDTH_C - 1 downto 0);
    signal conv5_wr_data : std_logic_vector(MEM_WORD_WIDTH_G - 1 downto 0);

begin
    s_axis_tready <= dma_conv1_tready;
    dma_conv1_tvalid <= s_axis_tvalid;
    dma_conv1_tdata <= s_axis_tdata;
    dma_conv1_tkeep <= s_axis_tkeep;
    dma_conv1_tuser <= s_axis_tuser;
    dma_conv1_tlast <= s_axis_tlast;

    conv5_screener1_tready <= m_axis_tready;
    m_axis_tvalid <= conv5_screener1_tvalid;
    m_axis_tdata <= conv5_screener1_tdata;
    m_axis_tkeep <= conv5_screener1_tkeep;
    m_axis_tuser <= conv5_screener1_tuser;
    m_axis_tlast <= conv5_screener1_tlast;

    conv1 : entity xil_defaultlib.Conv1_Layer
        generic map(
            S_AXIS_TDATA_WIDTH_G => CONV1_TDATA_WIDTH, -- 128 per line * 2 input channels
            M_AXIS_TDATA_WIDTH_G => MAXPOOL1_TDATA_WIDTH -- 128 per line * 2 input channels
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

    conv2 : entity xil_defaultlib.Conv2_Layer
        generic map(
            S_AXIS_TDATA_WIDTH_G => CONV2_TDATA_WIDTH, -- 128 per line * 2 input channels
            M_AXIS_TDATA_WIDTH_G => MAXPOOL2_TDATA_WIDTH -- 128 per line * 2 input channels
        )
        port map(
            aclk => aclk,
            aresetn => aresetn,
            s_axis_tready => maxpool1_conv2_tready,
            s_axis_tvalid => maxpool1_conv2_tvalid,
            s_axis_tdata => maxpool1_conv2_tdata,
            s_axis_tkeep => maxpool1_conv2_tkeep,
            s_axis_tuser => maxpool1_conv2_tuser,
            s_axis_tlast => maxpool1_conv2_tlast,
            m_axis_tready => conv2_maxpool2_tready,
            m_axis_tvalid => conv2_maxpool2_tvalid,
            m_axis_tdata => conv2_maxpool2_tdata,
            m_axis_tkeep => conv2_maxpool2_tkeep,
            m_axis_tuser => conv2_maxpool2_tuser,
            m_axis_tlast => conv2_maxpool2_tlast,
            d_output => conv2_debug
        );
    maxpool2 : entity xil_defaultlib.Maxpool2_Layer
        generic map(
            S_AXIS_TDATA_WIDTH_G => MAXPOOL2_TDATA_WIDTH,
            M_AXIS_TDATA_WIDTH_G => CONV3_TDATA_WIDTH
        )
        port map(
            aclk => aclk,
            aresetn => aresetn,
            s_axis_tready => conv2_maxpool2_tready,
            s_axis_tvalid => conv2_maxpool2_tvalid,
            s_axis_tdata => conv2_maxpool2_tdata,
            s_axis_tkeep => conv2_maxpool2_tkeep,
            s_axis_tuser => conv2_maxpool2_tuser,
            s_axis_tlast => conv2_maxpool2_tlast,
            m_axis_tready => maxpool2_conv3_tready,
            m_axis_tvalid => maxpool2_conv3_tvalid,
            m_axis_tdata => maxpool2_conv3_tdata,
            m_axis_tkeep => maxpool2_conv3_tkeep,
            m_axis_tuser => maxpool2_conv3_tuser,
            m_axis_tlast => maxpool2_conv3_tlast,
            d_output => maxpool2_debug
        );

    conv3 : entity xil_defaultlib.Conv3_Layer
        generic map(
            S_AXIS_TDATA_WIDTH_G => CONV3_TDATA_WIDTH,
            M_AXIS_TDATA_WIDTH_G => MAXPOOL3_TDATA_WIDTH
        )
        port map(
            aclk => aclk,
            aresetn => aresetn,
            s_axis_tready => maxpool2_conv3_tready,
            s_axis_tvalid => maxpool2_conv3_tvalid,
            s_axis_tdata => maxpool2_conv3_tdata,
            s_axis_tkeep => maxpool2_conv3_tkeep,
            s_axis_tuser => maxpool2_conv3_tuser,
            s_axis_tlast => maxpool2_conv3_tlast,
            m_axis_tready => conv3_maxpool3_tready,
            m_axis_tvalid => conv3_maxpool3_tvalid,
            m_axis_tdata => conv3_maxpool3_tdata,
            m_axis_tkeep => conv3_maxpool3_tkeep,
            m_axis_tuser => conv3_maxpool3_tuser,
            m_axis_tlast => conv3_maxpool3_tlast,
            d_output => conv3_debug
        );
    maxpool3 : entity xil_defaultlib.Maxpool3_Layer
        generic map(
            S_AXIS_TDATA_WIDTH_G => MAXPOOL3_TDATA_WIDTH,
            M_AXIS_TDATA_WIDTH_G => CONV4_TDATA_WIDTH
        )
        port map(
            aclk => aclk,
            aresetn => aresetn,
            s_axis_tready => conv3_maxpool3_tready,
            s_axis_tvalid => conv3_maxpool3_tvalid,
            s_axis_tdata => conv3_maxpool3_tdata,
            s_axis_tkeep => conv3_maxpool3_tkeep,
            s_axis_tuser => conv3_maxpool3_tuser,
            s_axis_tlast => conv3_maxpool3_tlast,
            m_axis_tready => maxpool3_conv4_tready,
            m_axis_tvalid => maxpool3_conv4_tvalid,
            m_axis_tdata => maxpool3_conv4_tdata,
            m_axis_tkeep => maxpool3_conv4_tkeep,
            m_axis_tuser => maxpool3_conv4_tuser,
            m_axis_tlast => maxpool3_conv4_tlast,
            d_output => maxpool3_debug
        );
    conv4 : entity xil_defaultlib.Conv4_Layer
        generic map(
            S_AXIS_TDATA_WIDTH_G => CONV4_TDATA_WIDTH,
            M_AXIS_TDATA_WIDTH_G => MAXPOOL4_TDATA_WIDTH
        )
        port map(
            aclk => aclk,
            aresetn => aresetn,
            s_axis_tready => maxpool3_conv4_tready,
            s_axis_tvalid => maxpool3_conv4_tvalid,
            s_axis_tdata => maxpool3_conv4_tdata,
            s_axis_tkeep => maxpool3_conv4_tkeep,
            s_axis_tuser => maxpool3_conv4_tuser,
            s_axis_tlast => maxpool3_conv4_tlast,
            m_axis_tready => conv4_maxpool4_tready,
            m_axis_tvalid => conv4_maxpool4_tvalid,
            m_axis_tdata => conv4_maxpool4_tdata,
            m_axis_tkeep => conv4_maxpool4_tkeep,
            m_axis_tuser => conv4_maxpool4_tuser,
            m_axis_tlast => conv4_maxpool4_tlast,
            d_output => conv4_debug
        );
    maxpool4 : entity xil_defaultlib.Maxpool4_Layer
        generic map(
            S_AXIS_TDATA_WIDTH_G => MAXPOOL4_TDATA_WIDTH,
            M_AXIS_TDATA_WIDTH_G => CONV5_TDATA_WIDTH
        )
        port map(
            aclk => aclk,
            aresetn => aresetn,
            s_axis_tready => conv4_maxpool4_tready,
            s_axis_tvalid => conv4_maxpool4_tvalid,
            s_axis_tdata => conv4_maxpool4_tdata,
            s_axis_tkeep => conv4_maxpool4_tkeep,
            s_axis_tuser => conv4_maxpool4_tuser,
            s_axis_tlast => conv4_maxpool4_tlast,
            m_axis_tready => maxpool4_conv5_tready,
            m_axis_tvalid => maxpool4_conv5_tvalid,
            m_axis_tdata => maxpool4_conv5_tdata,
            m_axis_tkeep => maxpool4_conv5_tkeep,
            m_axis_tuser => maxpool4_conv5_tuser,
            m_axis_tlast => maxpool4_conv5_tlast,
            d_output => maxpool4_debug
        );
    conv5 : entity xil_defaultlib.Conv5_Layer
        generic map(
            S_AXIS_TDATA_WIDTH_G => CONV5_TDATA_WIDTH,
            M_AXIS_TDATA_WIDTH_G => SCREENER1_TDATA_WIDTH
        )
        port map(
            aclk => aclk,
            aresetn => aresetn,
            s_axis_tready => maxpool4_conv5_tready,
            s_axis_tvalid => maxpool4_conv5_tvalid,
            s_axis_tdata => maxpool4_conv5_tdata,
            s_axis_tkeep => maxpool4_conv5_tkeep,
            s_axis_tuser => maxpool4_conv5_tuser,
            s_axis_tlast => maxpool4_conv5_tlast,
            m_axis_tready => conv5_screener1_tready,
            m_axis_tvalid => conv5_screener1_tvalid,
            m_axis_tdata => conv5_screener1_tdata,
            m_axis_tkeep => conv5_screener1_tkeep,
            m_axis_tuser => conv5_screener1_tuser,
            m_axis_tlast => conv5_screener1_tlast,
            load_mode_i => load_mode,
            soft_reset_i => soft_reset,
            axil_wr_addr => conv5_wr_addr,
            axil_wr_data => conv5_wr_data,
            axil_wr_en => conv5_wr_en,
            d_output => conv5_debug
        );
    reg_bank : entity xil_defaultlib.Network_Reg_Bank
        generic map(
            AXIL_DATA_WIDTH_G => 32,
            AXIL_ADDR_WIDTH_G => 32,
            MEM_WORD_WIDTH_G => 72 -- This is fixed for UltraRAM
        )
        port map(
            -- CONTROL Register
            load_mode_o => load_mode,
            soft_reset_o => soft_reset,
            enable_operation_o => enable_operation,

            -- Memory interface signals
            conv1_wr_en => conv1_wr_en,
            conv1_wr_addr => conv1_wr_addr,
            conv1_wr_data => conv1_wr_data,
            conv2_wr_en => conv2_wr_en,
            conv2_wr_addr => conv2_wr_addr,
            conv2_wr_data => conv2_wr_data,
            conv3_wr_en => conv3_wr_en,
            conv3_wr_addr => conv3_wr_addr,
            conv3_wr_data => conv3_wr_data,
            conv4_wr_en => conv4_wr_en,
            conv4_wr_addr => conv4_wr_addr,
            conv4_wr_data => conv4_wr_data,
            conv5_wr_en => conv5_wr_en,
            conv5_wr_addr => conv5_wr_addr,
            conv5_wr_data => conv5_wr_data,

            -- Slave AXI4-Lite Interface
            s_axi_aclk => s_axi_aclk,
            s_axi_aresetn => s_axi_aresetn,
            s_axi_awaddr => s_axi_awaddr,
            s_axi_awprot => s_axi_awprot,
            s_axi_awvalid => s_axi_awvalid,
            s_axi_awready => s_axi_awready,
            s_axi_wdata => s_axi_wdata,
            s_axi_wstrb => s_axi_wstrb,
            s_axi_wvalid => s_axi_wvalid,
            s_axi_wready => s_axi_wready,
            s_axi_bresp => s_axi_bresp,
            s_axi_bvalid => s_axi_bvalid,
            s_axi_bready => s_axi_bready,
            s_axi_araddr => s_axi_araddr,
            s_axi_arprot => s_axi_arprot,
            s_axi_arvalid => s_axi_arvalid,
            s_axi_arready => s_axi_arready,
            s_axi_rdata => s_axi_rdata,
            s_axi_rresp => s_axi_rresp,
            s_axi_rvalid => s_axi_rvalid,
            s_axi_rready => s_axi_rready
        );
end rtl;