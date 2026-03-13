library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library xil_defaultlib;
use xil_defaultlib.constants_pkg.all;
use xil_defaultlib.weights_pkg.all;

entity Maxpool1_Layer is
    generic (
        S_AXIS_TDATA_WIDTH_G : positive := 128;
        M_AXIS_TDATA_WIDTH_G : positive := 64
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
        m_axis_tlast : out std_logic;

        -- Debug Output
        d_output : out std_logic_vector(CONV1_ACCUM_WIDTH_C - 1 downto 0)
    );
end entity Maxpool1_Layer;

architecture rtl of Maxpool1_Layer is

    --------------------------------------------------------------------------------
    -- Output Queue
    --------------------------------------------------------------------------------
    constant OUT_FIFO_DEPTH_C : positive := 8;
    type axis_word_t is record
        tdata : std_logic_vector(M_AXIS_TDATA_WIDTH_G - 1 downto 0);
        -- tkeep : std_logic_vector((M_AXIS_TDATA_WIDTH_G/8) - 1 downto 0);
        tuser : std_logic_vector(AXIS_TUSER_WIDTH_C - 1 downto 0);
        -- tlast : std_logic;
    end record;
    type axis_word_array_t is array (0 to OUT_FIFO_DEPTH_C - 1) of axis_word_t;
    signal out_fifo : axis_word_array_t;
    signal out_wr_ptr : natural range 0 to OUT_FIFO_DEPTH_C - 1 := 0;
    signal out_rd_ptr : natural range 0 to OUT_FIFO_DEPTH_C - 1 := 0;
    signal out_count : natural range 0 to OUT_FIFO_DEPTH_C := 0;
    signal out_fifo_full : std_logic := '0';
    signal out_fifo_empty : std_logic := '0';
    signal push_queue : std_logic := '0';
    signal pop_queue : std_logic := '0';
    --------------------------------------------------------------------------------
    -- AXI Stream signals
    --------------------------------------------------------------------------------
    signal axi_in_ready : std_logic;
    signal axi_out_ready : std_logic;

    --------------------------------------------------------------------------------
    -- Calculation signals
    --------------------------------------------------------------------------------
    signal output_line : axis_word_t;
    type channel_line_buffer_t is array (0 to 1) of std_logic_vector(MAXPOOL1_OUTPUT_WIDTH - 1 downto 0);
    type line_buffer_t is array (0 to CONV1_CONCURRENT_KERNELS - 1) of channel_line_buffer_t;
    signal line_buffer : line_buffer_t := (others => (others => (others => '0')));
begin

    axi_in_ready <= not out_fifo_full;

    axi_out_queue : process (aclk)
    begin
        out_fifo_full <= '0';
        if out_count = OUT_FIFO_DEPTH_C then
            out_fifo_full <= '1';
        end if;

        out_fifo_empty <= '0';
        if out_count = 0 then
            out_fifo_empty <= '1';
        end if;

        if rising_edge(aclk) then
            -- Push item to queue
            if push_queue = '1' and out_fifo_full = '0' then
                out_fifo(out_wr_ptr) <= output_line;

                if out_wr_ptr = OUT_FIFO_DEPTH_C - 1 then
                    out_wr_ptr <= 0;
                else
                    out_wr_ptr <= out_wr_ptr + 1;
                end if;
            end if;
            -- Pop last read item
            if pop_queue = '1' and out_fifo_empty = '0' then
                if out_rd_ptr = OUT_FIFO_DEPTH_C - 1 then
                    out_rd_ptr <= 0;
                else
                    out_rd_ptr <= out_rd_ptr + 1;
                end if;
            end if;
            -- Update count (although it could be done by tracking the pointers)
            case (push_queue & pop_queue) is
                when "10" =>
                    if out_count < OUT_FIFO_DEPTH_G then
                        out_count <= out_count + 1;
                    end if;

                when "01" =>
                    if out_count > 0 then
                        out_count <= out_count - 1;
                    end if;

                when others =>
                    null; -- "00" or "11": count unchanged
            end case;
        end if;
    end process;

    lines_in : process (aclk)
    begin
        if rising_edge(aclk) then
            if axi_in_ready = '1' and s_axis_tvalid = '1' then
                -- Place 
                line_buffer(s_axis_tuser mod CONV1_CONCURRENT_KERNELS) <= (others => '0')
            end if;
        end if;
    end process;
end architecture rtl;