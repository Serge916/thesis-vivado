library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

library xil_defaultlib;
use xil_defaultlib.constants_pkg.all;
use xil_defaultlib.weights_pkg.all;
use xil_defaultlib.network_reg_bank_pkg.all;
-------------------------------
-- SpikeVision Register Bank
-------------------------------
entity Network_Reg_Bank is
    generic (
        -- AXI generics - AXI4-Lite supports a data bus width of 32-bit or 64-bit
        AXIL_DATA_WIDTH_G : integer := 32;
        AXIL_ADDR_WIDTH_G : integer := 32;
        MEM_WORD_WIDTH_G : integer := 72 -- This is fixed for UltraRAM
    );
    port (
        -- CONTROL Register
        load_mode_o : out std_logic;
        soft_reset_o : out std_logic;
        enable_operation_o : out std_logic;

        -- Memory interface signals
        conv1_wr_en : out std_logic;
        conv1_wr_addr : out std_logic_vector(CONV1_ADDR_WIDTH_C - 1 downto 0);
        conv1_wr_data : out std_logic_vector(MEM_WORD_WIDTH_G - 1 downto 0);
        conv2_wr_en : out std_logic;
        conv2_wr_addr : out std_logic_vector(CONV2_ADDR_WIDTH_C - 1 downto 0);
        conv2_wr_data : out std_logic_vector(MEM_WORD_WIDTH_G - 1 downto 0);
        conv3_wr_en : out std_logic;
        conv3_wr_addr : out std_logic_vector(CONV3_ADDR_WIDTH_C - 1 downto 0);
        conv3_wr_data : out std_logic_vector(MEM_WORD_WIDTH_G - 1 downto 0);
        conv4_wr_en : out std_logic;
        conv4_wr_addr : out std_logic_vector(CONV4_ADDR_WIDTH_C - 1 downto 0);
        conv4_wr_data : out std_logic_vector(MEM_WORD_WIDTH_G - 1 downto 0);
        conv5_wr_en : out std_logic;
        conv5_wr_addr : out std_logic_vector(CONV5_ADDR_WIDTH_C - 1 downto 0);
        conv5_wr_data : out std_logic_vector(MEM_WORD_WIDTH_G - 1 downto 0);

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
end Network_Reg_Bank;

architecture rtl of Network_Reg_Bank is

    -- Constant declarations
    constant ADDR_LSB_C : integer := (AXIL_DATA_WIDTH_G/32) + 1;
    constant ADDR_MSB_C : integer := 5;
    -- AXI4LITE signals
    signal axi_awaddr : std_logic_vector(AXIL_ADDR_WIDTH_G - 1 downto 0);
    signal axi_awready : std_logic;
    signal axi_wready : std_logic;
    signal axi_bresp : std_logic_vector(1 downto 0);
    signal axi_bvalid : std_logic;
    signal axi_araddr : std_logic_vector(AXIL_ADDR_WIDTH_G - 1 downto 0);
    signal axi_arready : std_logic;
    signal axi_rdata : std_logic_vector(AXIL_DATA_WIDTH_G - 1 downto 0);
    signal axi_rresp : std_logic_vector(1 downto 0);
    signal axi_rvalid : std_logic;

    -- Common signals
    signal awaddr_valid : std_logic;
    signal enable_operation_q : std_logic_vector(0 downto 0);

    -- Signals for user logic register space
    -- CONTROL Register
    signal load_mode_q : std_logic_vector(0 downto 0);
    signal soft_reset_q : std_logic_vector(0 downto 0);
    signal conv1_commit_word : std_logic_vector(0 downto 0);
    signal conv2_commit_word : std_logic_vector(0 downto 0);
    signal conv3_commit_word : std_logic_vector(0 downto 0);
    signal conv4_commit_word : std_logic_vector(0 downto 0);
    signal conv5_commit_word : std_logic_vector(0 downto 0);
    -- Memory data reg
    signal conv1_data_reg : std_logic_vector(MEM_WORD_WIDTH_G - 1 downto 0);
    signal conv2_data_reg : std_logic_vector(MEM_WORD_WIDTH_G - 1 downto 0);
    signal conv3_data_reg : std_logic_vector(MEM_WORD_WIDTH_G - 1 downto 0);
    signal conv4_data_reg : std_logic_vector(MEM_WORD_WIDTH_G - 1 downto 0);
    signal conv5_data_reg : std_logic_vector(MEM_WORD_WIDTH_G - 1 downto 0);
    -- Memory addr reg
    signal conv1_addr_reg : std_logic_vector(CONV1_ADDR_WIDTH_C - 1 downto 0);
    signal conv2_addr_reg : std_logic_vector(CONV2_ADDR_WIDTH_C - 1 downto 0);
    signal conv3_addr_reg : std_logic_vector(CONV3_ADDR_WIDTH_C - 1 downto 0);
    signal conv4_addr_reg : std_logic_vector(CONV4_ADDR_WIDTH_C - 1 downto 0);
    signal conv5_addr_reg : std_logic_vector(CONV5_ADDR_WIDTH_C - 1 downto 0);
begin

    -- AXI4-Lite output signals assignements
    s_axi_awready <= axi_awready;
    s_axi_wready <= axi_wready; -- axi_wready is identical to axi_awready, we could remove it
    s_axi_bresp <= axi_bresp;
    s_axi_bvalid <= axi_bvalid;
    s_axi_arready <= axi_arready;
    s_axi_rdata <= axi_rdata;
    s_axi_rresp <= axi_rresp;
    s_axi_rvalid <= axi_rvalid;

    -- Registers output signals assignements
    load_mode_o <= load_mode_q(0);
    soft_reset_o <= soft_reset_q(0);
    enable_operation_o <= enable_operation_q(0);

    --------------------------------------------------------------------------------
    -- Memory 
    --------------------------------------------------------------------------------
    process (conv1_commit_word, conv2_commit_word, conv3_commit_word, conv4_commit_word, conv5_commit_word)
    begin
        conv1_wr_en <= '0';
        conv2_wr_en <= '0';
        conv3_wr_en <= '0';
        conv4_wr_en <= '0';
        conv5_wr_en <= '0';

        if conv1_commit_word(0) = '1' then
            conv1_wr_en <= '1';
            conv1_wr_data <= conv1_data_reg;
            conv1_wr_addr <= conv1_addr_reg;
        end if;
        if conv2_commit_word(0) = '1' then
            conv2_wr_en <= '1';
            conv2_wr_data <= conv2_data_reg;
            conv2_wr_addr <= conv2_addr_reg;
        end if;
        if conv3_commit_word(0) = '1' then
            conv3_wr_en <= '1';
            conv3_wr_data <= conv3_data_reg;
            conv3_wr_addr <= conv3_addr_reg;
        end if;
        if conv4_commit_word(0) = '1' then
            conv4_wr_en <= '1';
            conv4_wr_data <= conv4_data_reg;
            conv4_wr_addr <= conv4_addr_reg;
        end if;
        if conv5_commit_word(0) = '1' then
            conv5_wr_en <= '1';
            conv5_wr_data <= conv5_data_reg;
            conv5_wr_addr <= conv5_addr_reg;
        end if;

    end process;
    ---------------------------
    -- Write address channel --
    ---------------------------

    -- axi_awready: Write address ready
    -- This signal indicates that the slave is ready to accept an address and associated control signals.
    -- It is asserted for one clock cycle when both s_axi_awvalid and s_axi_wvalid are asserted.
    -- It is de-asserted when reset is low.
    -- Note: aw_en = '1' has been replaced by (s_axi_bvalid = '0' or s_axi_bready = '1'), see https://zipcpu.com/blog/2021/05/22/vhdlaxil.html
    process (s_axi_aclk)
    begin
        if rising_edge(s_axi_aclk) then
            -- The reset signal can be asserted asynchronously, but deassertion must be synchronous with a rising edge of s_axi_aclk
            if s_axi_aresetn = '0' then
                axi_awready <= '0';
            else
                if (axi_awready = '0' and s_axi_awvalid = '1' and s_axi_wvalid = '1' and (axi_bvalid = '0' or s_axi_bready = '1')) then
                    -- Slave is ready to accept write address when there is a valid write address and write data
                    -- on the write address and data bus. This design expects no outstanding transactions.
                    axi_awready <= '1';
                else
                    axi_awready <= '0';
                end if;
            end if;
        end if;
    end process;

    -- axi_awaddr: Write address
    -- The write address gives the address of the first transfer in a write transaction (no burst in AXI4-LITE).
    -- This process is used to latch the address when both s_axi_awvalid and s_axi_wvalid are valid.
    -- Note: aw_en = '1' has been replaced by (s_axi_bvalid = '0' or s_axi_bready = '1'), see https://zipcpu.com/blog/2021/05/22/vhdlaxil.html
    process (s_axi_aclk)
    begin
        if rising_edge(s_axi_aclk) then
            if s_axi_aresetn = '0' then
                axi_awaddr <= (others => '0');
            else
                if (axi_awready = '0' and s_axi_awvalid = '1' and s_axi_wvalid = '1' and (axi_bvalid = '0' or s_axi_bready = '1')) then
                    axi_awaddr <= s_axi_awaddr;
                end if;
            end if;
        end if;
    end process;

    ------------------------
    -- Write data channel --
    ------------------------

    -- axi_wready: Write ready
    -- This signal indicates that the slave can accept the write data.
    -- It is asserted for one s_axi_aclk clock cycle when both s_axi_awvalid and s_axi_wvalid are asserted.
    -- It is de-asserted when reset is low.
    -- Slave is ready to accept write data when there is a valid write address and write data
    -- on the write address and data bus. This design expects no outstanding transactions.
    -- Note: aw_en = '1' has been replaced by (s_axi_bvalid = '0' or s_axi_bready = '1'), see https://zipcpu.com/blog/2021/05/22/vhdlaxil.html
    process (s_axi_aclk)
    begin
        if rising_edge(s_axi_aclk) then
            if s_axi_aresetn = '0' then
                -- write ready
                axi_wready <= '0';
            else
                if (axi_wready = '0' and s_axi_wvalid = '1' and s_axi_awvalid = '1' and (axi_bvalid = '0' or s_axi_bready = '1')) then
                    axi_wready <= '1';
                else
                    axi_wready <= '0';
                end if;
            end if;
        end if;
    end process;

    -- Memory mapped register select and write logic
    -- The write data is accepted and written to memory mapped registers when
    -- axi_awready, s_axi_awvalid, axi_wready and s_axi_wvalid are asserted.
    -- Write strobes are used to select byte enables of slave registers while writing.
    -- These registers are cleared when reset (active low) is applied.
    -- Slave register write enable is asserted when valid address and data are available
    -- and the slave is ready to accept the write address and write data.
    -- Note: s_axi_awvalid = '1' and axi_wready = '1' and s_axi_wvalid = '1' have been removed, see https://zipcpu.com/blog/2021/05/22/vhdlaxil.html
    process (s_axi_aclk)
    begin
        if rising_edge(s_axi_aclk) then
            conv1_commit_word(0 downto 0) <= (others => '0');
            conv2_commit_word(0 downto 0) <= (others => '0');
            conv3_commit_word(0 downto 0) <= (others => '0');
            conv4_commit_word(0 downto 0) <= (others => '0');
            conv5_commit_word(0 downto 0) <= (others => '0');

            if s_axi_aresetn = '0' then
                -- Clear registers (values by default)
                load_mode_q(0 downto 0) <= (others => '0');
                soft_reset_q(0 downto 0) <= (others => '0');
                enable_operation_q(0 downto 0) <= (others => '0');
            else
                -- Trigger Register (reset to default value every clock cycle)
                if axi_awready = '1' then
                    case axi_awaddr(ADDR_MSB_C downto ADDR_LSB_C) is
                        when CONTROL_ADDR(ADDR_MSB_C downto ADDR_LSB_C) =>
                            enable_operation_q <= s_axi_wdata(LOAD_MODE_MSB downto LOAD_MODE_LSB);
                            load_mode_q <= s_axi_wdata(LOAD_MODE_MSB downto LOAD_MODE_LSB);
                            soft_reset_q <= s_axi_wdata(SOFT_RESET_MSB downto SOFT_RESET_LSB);
                        when STATUS_ADDR(ADDR_MSB_C downto ADDR_LSB_C) =>
                        when CONV1_CONTROL_ADDR(ADDR_MSB_C downto ADDR_LSB_C) =>
                            conv1_commit_word(COMMIT_WORD_WIDTH - 1 downto 0) <= s_axi_wdata(COMMIT_WORD_MSB downto COMMIT_WORD_LSB);
                        when CONV1_KERNEL_ADDR(ADDR_MSB_C downto ADDR_LSB_C) =>
                            conv1_addr_reg <= s_axi_wdata(CONV1_ADDR_WIDTH_C - 1 downto 0);
                        when CONV1_KERNEL_WORD0_ADDR(ADDR_MSB_C downto ADDR_LSB_C) =>
                            conv1_data_reg(3 * CONV1_PRECISION - 1 downto 0) <= s_axi_wdata(CONV1_PRECISION * 3 - 1 downto 0);
                        when CONV1_KERNEL_WORD1_ADDR(ADDR_MSB_C downto ADDR_LSB_C) =>
                            conv1_data_reg(6 * CONV1_PRECISION - 1 downto 3 * CONV1_PRECISION) <= s_axi_wdata(CONV1_PRECISION * 3 - 1 downto 0);
                        when CONV1_KERNEL_WORD2_ADDR(ADDR_MSB_C downto ADDR_LSB_C) =>
                            conv1_data_reg(9 * CONV1_PRECISION - 1 downto 6 * CONV1_PRECISION) <= s_axi_wdata(CONV1_PRECISION * 3 - 1 downto 0);

                        when others =>
                            -- Unknown address
                            load_mode_q <= load_mode_q;
                            enable_operation_q <= enable_operation_q;
                            soft_reset_q <= soft_reset_q;
                            conv1_data_reg <= conv1_data_reg;
                            conv1_addr_reg <= conv1_addr_reg;
                    end case;
                end if;
            end if;
        end if;
    end process;

    -- Address valid decoding for axi_bresp signal below
    awaddr_valid <= '1' when axi_awaddr(ADDR_MSB_C downto ADDR_LSB_C) = CONTROL_ADDR(ADDR_MSB_C downto ADDR_LSB_C) else
        '1' when axi_awaddr(ADDR_MSB_C downto ADDR_LSB_C) = CONV1_CONTROL_ADDR(ADDR_MSB_C downto ADDR_LSB_C) else
        '1' when axi_awaddr(ADDR_MSB_C downto ADDR_LSB_C) = CONV1_MEM_DEPTH_ADDR(ADDR_MSB_C downto ADDR_LSB_C) else
        '1' when axi_awaddr(ADDR_MSB_C downto ADDR_LSB_C) = CONV1_KERNEL_ADDR(ADDR_MSB_C downto ADDR_LSB_C) else
        '1' when axi_awaddr(ADDR_MSB_C downto ADDR_LSB_C) = CONV1_KERNEL_WORD0_ADDR(ADDR_MSB_C downto ADDR_LSB_C) else
        '1' when axi_awaddr(ADDR_MSB_C downto ADDR_LSB_C) = CONV1_KERNEL_WORD1_ADDR(ADDR_MSB_C downto ADDR_LSB_C) else
        '1' when axi_awaddr(ADDR_MSB_C downto ADDR_LSB_C) = CONV1_KERNEL_WORD2_ADDR(ADDR_MSB_C downto ADDR_LSB_C) else
        '0';

    ----------------------------
    -- Write response channel --
    ----------------------------

    -- axi_bvalid & axi_bresp: Write response
    -- The write response and response valid signals are asserted by the slave when
    -- axi_awready, s_axi_awvalid, axi_wready and s_axi_wvalid are asserted. This marks the acceptance of
    -- address and indicates the status of write transaction.
    process (s_axi_aclk)
    begin
        if rising_edge(s_axi_aclk) then
            if s_axi_aresetn = '0' then
                axi_bvalid <= '0';
                axi_bresp <= "00";
            else
                if (axi_awready = '1' and s_axi_awvalid = '1' and axi_wready = '1' and s_axi_wvalid = '1' and axi_bvalid = '0') then
                    -- axi_bvalid: Write response valid
                    -- This signal indicates that the channel is signaling a valid write response.
                    axi_bvalid <= '1';
                    -- axi_bresp: Write response
                    -- This signal indicates the status of the write transaction.
                    if (awaddr_valid = '1') then
                        axi_bresp <= "00";
                    else
                        axi_bresp <= "10"; -- SLVERR
                    end if;
                    -- Check if bready is asserted while bvalid is high (there is a possibility that bready is always asserted high)
                elsif (s_axi_bready = '1' and axi_bvalid = '1') then
                    axi_bvalid <= '0';
                end if;
            end if;
        end if;
    end process;

    --------------------------
    -- Read address channel --
    --------------------------

    -- axi_arready: Read address ready
    -- This signal indicates that the slave is ready to accept an address and associated control signals.
    -- It is asserted for one s_axi_aclk clock cycle when s_axi_arvalid is asserted.
    -- It is de-asserted when reset (active low) is asserted.
    -- The read address is also latched when s_axi_arvalid is asserted.
    -- It is reset to zero on reset assertion.
    -- Note: (s_axi_rvalid = '0' or s_axi_rready = '1') has been added from the equation (see https://zipcpu.com/blog/2021/05/22/vhdlaxil.html)
    process (s_axi_aclk)
    begin
        if rising_edge(s_axi_aclk) then
            if s_axi_aresetn = '0' then
                -- read ready
                axi_arready <= '0';
                axi_araddr <= (others => '0');
            else
                if (axi_arready = '0' and s_axi_arvalid = '1' and (axi_rvalid = '0' or s_axi_rready = '1')) then
                    -- Indicates that the slave has accepted the valid read address
                    axi_arready <= '1';
                    -- Read address latching
                    axi_araddr <= s_axi_araddr;
                else
                    axi_arready <= '0';
                end if;
            end if;
        end if;
    end process;

    --------------------------
    -- Read address channel --
    --------------------------

    -- axi_rvalid: Read valid
    -- This signal indicates that the channel is signaling the required read data.
    -- It is asserted for one clock cycle when both s_axi_arvalid and axi_arready are asserted.
    -- The slave registers data are available on the axi_rdata bus at this instance. The assertion of
    -- axi_rvalid marks the validity of read data on the bus and axi_rresp indicates the status of the
    -- read transaction.
    -- axi_rvalid is deasserted on reset (active low).
    -- axi_rresp and axi_rdata are cleared to zero on reset (active low).
    -- Note: (not axi_rvalid) has been removed from the equation (see https://zipcpu.com/blog/2021/05/22/vhdlaxil.html)
    process (s_axi_aclk)
    begin
        if rising_edge(s_axi_aclk) then
            if s_axi_aresetn = '0' then
                axi_rvalid <= '0';
                axi_rresp <= "00";
                -- read data
                axi_rdata <= (others => '0');

            else
                if (axi_arready = '1' and s_axi_arvalid = '1') then
                    -- Valid read data is available at the read data bus
                    axi_rvalid <= '1';
                    -- By default the slave respond with an OKAY status, which will be overriden if the address is not recognized
                    axi_rresp <= "00";

                    -- Fill the bits that are not used with zeros
                    axi_rdata <= (others => '0');

                    -- When there is a valid read address (s_axi_arvalid) with acceptance of read address by the
                    -- slave (axi_arready), output the read data

                    -- Read address mux
                    case axi_araddr(ADDR_MSB_C downto ADDR_LSB_C) is
                        when CONTROL_ADDR(ADDR_MSB_C downto ADDR_LSB_C) =>
                            axi_rdata(LOAD_MODE_MSB downto LOAD_MODE_LSB) <= load_mode_q;
                            axi_rdata(SOFT_RESET_MSB downto SOFT_RESET_LSB) <= soft_reset_q;
                            axi_rdata(ENABLE_OPERATION_MSB downto ENABLE_OPERATION_LSB) <= enable_operation_q;
                        when STATUS_ADDR(ADDR_MSB_C downto ADDR_LSB_C) =>
                        when CONV1_MEM_DEPTH_ADDR(ADDR_MSB_C downto ADDR_LSB_C) =>
                            axi_rdata(MEM_DEPTH_MSB downto MEM_DEPTH_LSB) <= std_logic_vector(to_unsigned(CONV1_MEM_DEPTH, MEM_DEPTH_WIDTH));
                        when CONV1_KERNEL_ADDR(ADDR_MSB_C downto ADDR_LSB_C) =>
                            axi_rdata(CONV1_ADDR_WIDTH_C - 1 downto 0) <= conv1_addr_reg;
                        when CONV1_KERNEL_WORD0_ADDR(ADDR_MSB_C downto ADDR_LSB_C) =>
                            axi_rdata(CONV1_PRECISION * 3 - 1 downto 0) <= conv1_data_reg(3 * CONV1_PRECISION - 1 downto 0);
                        when CONV1_KERNEL_WORD1_ADDR(ADDR_MSB_C downto ADDR_LSB_C) =>
                            axi_rdata(CONV1_PRECISION * 3 - 1 downto 0) <= conv1_data_reg(6 * CONV1_PRECISION - 1 downto 3 * CONV1_PRECISION);
                        when CONV1_KERNEL_WORD2_ADDR(ADDR_MSB_C downto ADDR_LSB_C) =>
                            axi_rdata(CONV1_PRECISION * 3 - 1 downto 0) <= conv1_data_reg(9 * CONV1_PRECISION - 1 downto 6 * CONV1_PRECISION);
                        when others =>
                            -- unknown address
                            axi_rresp <= "10"; -- SLVERR
                    end case;

                elsif (axi_rvalid = '1' and s_axi_rready = '1') then
                    -- Read data is accepted by the master
                    axi_rvalid <= '0';
                end if;
            end if;
        end if;
    end process;
end rtl;