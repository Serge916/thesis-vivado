library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library xil_defaultlib;
use xil_defaultlib.constants_pkg.all;

entity neuronFilter is
  generic (
    AXIS_TDATA_WIDTH_G : positive := 64;
    AXIS_TUSER_WIDTH_G : positive := 1;
    SPIKE_ACCUMULATION_LIMIT : positive := 800
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

    -- Output Data Stream
    m_axis_tready : in std_logic;
    m_axis_tvalid : out std_logic;
    m_axis_tdata : out std_logic_vector(AXIS_TDATA_WIDTH_G - 1 downto 0);
    m_axis_tkeep : out std_logic_vector((AXIS_TDATA_WIDTH_G/8) - 1 downto 0);
    m_axis_tuser : out std_logic_vector(AXIS_TUSER_WIDTH_G - 1 downto 0);
    m_axis_tlast : out std_logic
  );
end entity neuronFilter;

architecture rtl of neuronFilter is
  signal excitation_signal : std_logic;

  -- Cropper to Matrix
  signal tready_cropper_matrix : std_logic;
  signal tvalid_cropper_matrix : std_logic;
  signal tdata_cropper_matrix : std_logic_vector(AXIS_TDATA_WIDTH_G - 1 downto 0);
  signal tkeep_cropper_matrix : std_logic_vector((AXIS_TDATA_WIDTH_G/8) - 1 downto 0);
  signal tuser_cropper_matrix : std_logic_vector(AXIS_TUSER_WIDTH_G - 1 downto 0);
  signal tlast_cropper_matrix : std_logic;

  signal excitation_factor_s : std_logic_vector(31 downto 0);
  signal spike_accumulation_limit_s : std_logic_vector(31 downto 0);
  signal decay_counter_limit_s : std_logic_vector(31 downto 0);

begin
  cropper : entity xil_defaultlib.cropper
    generic map(
      AXIS_TDATA_WIDTH_G => 64,
      AXIS_TUSER_WIDTH_G => 1,
      ROI_WIDTH_PIXEL_AMOUNT => 512,
      ROI_HEIGHT_PIXEL_AMOUNT => 512,
      LET_THROUGH_ONLY_EVENTS => true
    )
    port map(
      -- Clock and Reset
      aclk => aclk,
      aresetn => aresetn,

      -- Input Data Stream to Cropper
      s_axis_tready => s_axis_tready,
      s_axis_tvalid => s_axis_tvalid,
      s_axis_tdata => s_axis_tdata,
      s_axis_tkeep => s_axis_tkeep,
      s_axis_tuser => s_axis_tuser,
      s_axis_tlast => s_axis_tlast,

      -- Cropper to Matrix
      m_axis_tready => tready_cropper_matrix,
      m_axis_tvalid => tvalid_cropper_matrix,
      m_axis_tdata => tdata_cropper_matrix,
      m_axis_tkeep => tkeep_cropper_matrix,
      m_axis_tuser => tuser_cropper_matrix,
      m_axis_tlast => tlast_cropper_matrix
    );

  matrix : entity xil_defaultlib.neuronMatrix
    generic map(
      AXIS_TDATA_WIDTH_G => AXIS_TDATA_WIDTH_G,
      AXIS_TUSER_WIDTH_G => AXIS_TUSER_WIDTH_G,
      SPIKE_ACCUMULATION_LIMIT => SPIKE_ACCUMULATION_LIMIT

    )
    port map(
      -- Clock and Reset
      aclk => aclk,
      aresetn => aresetn,

      -- Input Data Stream
      s_axis_tready => tready_cropper_matrix,
      s_axis_tvalid => tvalid_cropper_matrix,
      s_axis_tdata => tdata_cropper_matrix,
      s_axis_tkeep => tkeep_cropper_matrix,
      s_axis_tuser => tuser_cropper_matrix,
      s_axis_tlast => tlast_cropper_matrix,

      -- Output Data Stream
      m_axis_tready => m_axis_tready,
      m_axis_tvalid => m_axis_tvalid,
      m_axis_tdata => m_axis_tdata,
      m_axis_tkeep => m_axis_tkeep,
      m_axis_tuser => m_axis_tuser,
      m_axis_tlast => m_axis_tlast,
      excitation_factor_i => excitation_factor_s,
      spike_accumulation_limit_i => spike_accumulation_limit_s,
      decay_counter_limit_i => decay_counter_limit_s
    );

  reg : entity xil_defaultlib.neuronMatrix_reg_bank
    port map(
      -- CONTROL Register
      cfg_control_enable_o => open,
      cfg_control_global_reset_o => open,
      cfg_control_clear_o => open,
      -- CONFIG Register
      cfg_config_test_pattern_o => open,
      cfg_config_timeout_enable_o => open,
      -- DECAY_COUNTER_LIMIT Register
      param_decay_counter_limit_o => decay_counter_limit_s,
      -- SPIKE_ACCUMULATION_LIMIT Register
      param_spike_accumulation_limit_o => spike_accumulation_limit_s,
      -- EXCITATION_FACTOR Register
      param_excitation_factor_o => excitation_factor_s,

      -- Slave AXI4-Lite Interface
      s_axi_aclk => aclk,
      s_axi_aresetn => aresetn,
      s_axi_awaddr => x"00000000",
      s_axi_awprot => "000",
      s_axi_awvalid => '0',
      s_axi_awready => open,
      s_axi_wdata => x"00000000",
      s_axi_wstrb => x"0",
      s_axi_wvalid => '0',
      s_axi_wready => open,
      s_axi_bresp => open,
      s_axi_bvalid => open,
      s_axi_bready => '0',
      s_axi_araddr => x"00000000",
      s_axi_arprot => "000",
      s_axi_arvalid => '0',
      s_axi_arready => open,
      s_axi_rdata => open,
      s_axi_rresp => open,
      s_axi_rvalid => open,
      s_axi_rready => '0'
    );
end rtl;