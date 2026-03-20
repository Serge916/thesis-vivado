library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library xil_defaultlib;
use xil_defaultlib.constants_pkg.all;
use xil_defaultlib.weights_pkg.all;

entity Maxpool2_Layer is
    generic (
        S_AXIS_TDATA_WIDTH_G : positive := 64;
        M_AXIS_TDATA_WIDTH_G : positive := 32
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
        d_output : out std_logic_vector(11 downto 0)
    );
end entity Maxpool2_Layer;

architecture rtl of Maxpool2_Layer is

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
    -- signal pop_queue : std_logic := '0';
    --------------------------------------------------------------------------------
    -- AXI Stream signals
    --------------------------------------------------------------------------------
    signal axi_in_ready : std_logic := '0';
    signal axi_out_valid : std_logic := '0';
    constant FINISH_CONDITION : std_logic_vector(AXIS_TUSER_WIDTH_C - 1 downto 0) := std_logic_vector(to_unsigned(MAXPOOL2_OUTPUT_HEIGHT - 1, ROW_ID_WIDTH_C) & to_unsigned(CONV2_CHAN_OUTPUT - 1, CHANNEL_ID_WIDTH_C));

    --------------------------------------------------------------------------------
    -- Calculation signals
    --------------------------------------------------------------------------------
    signal output_line : axis_word_t;
    subtype channel_line_buffer_t is std_logic_vector(MAXPOOL2_TDATA_WIDTH - 1 downto 0);
    type line_buffer_t is array (0 to CONV2_CONCURRENT_KERNELS - 1) of channel_line_buffer_t;
    signal line_buffer : line_buffer_t := (others => (others => '0'));
begin
    m_axis_tvalid <= axi_out_valid;
    s_axis_tready <= axi_in_ready;
    axi_in_ready <= not out_fifo_full;

    m_axis_tkeep <= (others => '1');
    d_output <= (others => '0');

    axi_master : process (out_rd_ptr, out_count, out_fifo_empty, out_fifo)
    begin
        axi_out_valid <= not out_fifo_empty;
        m_axis_tdata <= out_fifo(out_rd_ptr).tdata;
        m_axis_tuser <= out_fifo(out_rd_ptr).tuser;
        m_axis_tlast <= '0';
        if out_fifo(out_rd_ptr).tuser = FINISH_CONDITION and out_fifo_empty = '0' then
            m_axis_tlast <= '1';
        end if;
    end process;

    fifo_flags : process (out_count)
    begin

        out_fifo_full <= '0';
        out_fifo_empty <= '0';

        if out_count = OUT_FIFO_DEPTH_C then
            out_fifo_full <= '1';
        end if;

        if out_count = 0 then
            out_fifo_empty <= '1';
        end if;
    end process;

    axi_out_queue : process (aclk)
        variable pop_queue : std_logic := '0';
    begin

        if rising_edge(aclk) then
            pop_queue := '0';
            if (out_count > 0) and (m_axis_tready = '1') and (axi_out_valid) = '1' and out_fifo_empty = '0' then
                pop_queue := '1';
            end if;

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
            if push_queue = '1' and pop_queue = '0' and out_fifo_full = '0' then
                if out_count < OUT_FIFO_DEPTH_C then
                    out_count <= out_count + 1;
                end if;
            end if;
            if push_queue = '0' and pop_queue = '1' and out_fifo_empty = '0'then
                out_count <= out_count - 1;
            end if;

        end if;
    end process;

    lines_in : process (aclk)
        variable row_id : std_logic_vector(ROW_ID_WIDTH_C - 1 downto 0) := (others => '0');
        variable channel_id : natural range 0 to CONV2_CHAN_OUTPUT - 1 := 0;
    begin

        if rising_edge(aclk) then
            push_queue <= '0';
            if axi_in_ready = '1' and s_axis_tvalid = '1' then
                -- Decode metadata
                row_id := s_axis_tuser(ROW_ID_WIDTH_C + CHANNEL_ID_WIDTH_C - 1 downto CHANNEL_ID_WIDTH_C);
                channel_id := to_integer(unsigned(s_axis_tuser(CHANNEL_ID_WIDTH_C - 1 downto 0)));
                if row_id(0) = '0' then
                    -- Place in the buffers, first row
                    line_buffer(channel_id mod CONV2_CONCURRENT_KERNELS) <= s_axis_tdata; -- First index depends on how big the batch is. Second index is 0 if even, 1 if uneven row
                else
                    -- Compute
                    for c in 0 to MAXPOOL2_OUTPUT_WIDTH - 1 loop -- The 2 is for the stride
                        output_line.tdata(c) <= line_buffer(channel_id mod CONV2_CONCURRENT_KERNELS)(2 * c) or s_axis_tdata(2 * c) or line_buffer(channel_id mod CONV2_CONCURRENT_KERNELS)(2 * c + 1) or s_axis_tdata(2 * c + 1);
                    end loop;
                    output_line.tuser <= ('0' & row_id(ROW_ID_WIDTH_C - 1 downto 1)) & std_logic_vector(to_unsigned(channel_id, CHANNEL_ID_WIDTH_C)); -- The row id should be divided by 2
                    push_queue <= '1';
                end if;
            end if;
        end if;
    end process;
end architecture rtl;