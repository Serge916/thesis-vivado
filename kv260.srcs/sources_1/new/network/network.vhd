library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library xil_defaultlib;
use xil_defaultlib.constants_pkg.all;
use xil_defaultlib.weights_pkg.all;

entity SpikeVision is
    generic (
        AXIS_TDATA_WIDTH_G : positive := 128;
        AXIS_TUSER_WIDTH_G : positive := 1;
        CONCURRENT_KERNELS : positive := 16
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

        -- Debug Output
        d_output : out std_logic_vector(CONV1_PRECISION * CONV1_KERNEL_SIZE ** 2 - 1 downto 0)
    );
end entity SpikeVision;

architecture rtl of SpikeVision is
    signal conv1_en : std_logic;
    signal conv1_addr : std_logic_vector(CONV1_ADDR_WIDTH_C - 1 downto 0);
    signal conv1_chan : std_logic_vector(CONV1_CHAN_WIDTH_C - 1 downto 0);
    signal conv1_dout : std_logic_vector(CONV1_PRECISION * CONV1_KERNEL_SIZE ** 2 - 1 downto 0);

    -- Signals for FSM
    type state_t is (LOAD_WEIGHTS, CALCULATE, IDLE);
    signal state : state_t := IDLE;
    signal next_state : state_t;

    -- Signals for Kernel
    -- Index 0 is top left, index 8 is bottom right
    type single_kernel_buffer_t is array (0 to (CONV1_KERNEL_SIZE ** 2) - 1) of std_logic_vector(CONV1_PRECISION - 1 downto 0);
    type kernel_buffer_t is array (0 to CONCURRENT_KERNELS - 1) of single_kernel_buffer_t;
    signal kernel_buffer : kernel_buffer_t;
    signal weight_batch_idx : integer range 0 to (CONV1_CHAN_INPUT * CONV1_CHAN_OUTPUT)/CONCURRENT_KERNELS - 1 := 0;
    signal weight_load_rdy : std_logic := '0';
    signal weight_load_init : std_logic := '0';
    signal weight_valid : std_logic := '0';
    signal weight_valid_addr : std_logic_vector(CONV1_ADDR_WIDTH_C - 1 downto 0);

    -- Signals for Line Fetch
    -- Index 0 is top, index 2 is bottom
    type line_buffer_t is array (0 to CONV1_KERNEL_SIZE - 1) of std_logic_vector(CONV1_FRAME_WIDTH - 1 downto 0);
    signal line_buffer : line_buffer_t;
    signal advance_lines : integer range 0 to CONV1_KERNEL_SIZE := 0;
    signal line_load_rdy : std_logic := '0';

    -- Signals for AXI_S
    signal axi_in_ready : std_logic := '0';

    -- Varied debug signals
    signal debug_remaining_kernels : integer;

begin
    conv1_mem : entity xil_defaultlib.Conv1_ROM
        port map(
            clk => aclk,
            en => conv1_en,
            addr => conv1_addr,
            channel => conv1_chan,
            dout => conv1_dout
        );

    s_axis_tready <= axi_in_ready;

    fetch_lines : process (aclk)
    begin
        if rising_edge(aclk) then
            -- By default, do not accept data in
            axi_in_ready <= '0';
            -- Make the ready flag a pulse
            line_load_rdy <= '0';

            if advance_lines > 0 then
                -- AXI Stream in
                -- If lines can be accepted, signal it
                axi_in_ready <= '1';
                if s_axis_tvalid = '1' then
                    -- Move one line down the buffer.
                    line_buffer(2) <= line_buffer(1);
                    line_buffer(1) <= line_buffer(0);
                    -- Insert the incoming line
                    line_buffer(0) <= s_axis_tdata;
                    -- Decrease counter
                    advance_lines <= advance_lines - 1;
                    -- If last iteration, signal that operation is complete
                    if advance_lines = 1 then
                        line_load_rdy <= '1';
                    end if;
                end if;
            end if;
        end if;
    end process;

    fetch_weights : process (aclk)
        variable read_kernels : integer range 0 to CONCURRENT_KERNELS := 0;
        variable write_kernels : integer range 0 to CONCURRENT_KERNELS := 0;

    begin
        debug_remaining_kernels <= read_kernels;
        -- I assume one word contains one kernel
        if rising_edge(aclk) then
            weight_load_rdy <= '0';

            -- Initial read
            if weight_load_init = '1' then
                read_kernels := CONCURRENT_KERNELS - 1;
                write_kernels := CONCURRENT_KERNELS - 1;
                conv1_addr <= std_logic_vector(to_unsigned(weight_batch_idx * CONCURRENT_KERNELS + CONCURRENT_KERNELS - 1, conv1_addr'length));
                conv1_en <= '1';
                -- Load next address
            elsif read_kernels > 0 and weight_load_init = '0' then
                read_kernels := read_kernels - 1;
                conv1_addr <= std_logic_vector(to_unsigned(weight_batch_idx * CONCURRENT_KERNELS + read_kernels, conv1_addr'length));
                conv1_en <= '1';
                weight_valid <= '1';
            end if;

            -- Split the word into the several weights
            if weight_valid = '1' then
                for j in 0 to (CONV1_KERNEL_SIZE ** 2) - 1 loop
                    kernel_buffer(write_kernels)(j) <= conv1_dout((j + 1) * CONV1_PRECISION - 1 downto (j) * CONV1_PRECISION);
                end loop;
                if write_kernels = 0 then
                    conv1_en <= '0';
                    weight_valid <= '0';
                    weight_load_rdy <= '1';
                else
                    write_kernels := write_kernels - 1;
                end if;
            end if;
        end if;

    end process;

    FSM : process (aclk, aresetn)
    begin
        if rising_edge(aclk) then
            state <= next_state;
        end if;

        case state is
            when IDLE =>
                next_state <= LOAD_WEIGHTS;
                weight_load_init <= '1';
                conv1_chan <= std_logic_vector(to_unsigned(0, conv1_chan'length));
                weight_batch_idx <= 1;
                -- next_state <= IDLE;
            when LOAD_WEIGHTS =>
                weight_load_init <= '0';
                next_state <= LOAD_WEIGHTS;
                if weight_load_rdy = '1' then
                    next_state <= IDLE;
                end if;
            when CALCULATE =>
                next_state <= CALCULATE;
        end case;

    end process;
end rtl;