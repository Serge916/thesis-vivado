--------------------------------------------------------------------------------
-- WEIGHT MEMORY
--------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library xil_defaultlib;
use xil_defaultlib.constants_pkg.all;
use xil_defaultlib.weights_pkg.all;
use xil_defaultlib.weights_value_pkg.all;

entity Conv2_ROM is
    port (
        -- Clock and Reset
        clk : in std_logic;

        -- Input
        en : in std_logic;
        addr : in std_logic_vector(CONV2_ADDR_WIDTH_C - 1 downto 0);
        -- Output
        dout : out std_logic_vector(CONV2_KERNEL_SIZE ** 2 * CONV2_PRECISION - 1 downto 0)
    );
end entity Conv2_ROM;

architecture rtl of Conv2_ROM is

    signal rom : conv2_mem_t := to_conv2_mem(CONV2_WEIGHTS);
    -- constant WEIGHT_INIT : std_logic_vector(8 * 9 - 1 downto 0) := (
    -- x"7F" & x"7F" & x"7F" &
    -- x"7F" & x"7F" & x"7F" &
    -- x"7F" & x"7F" & x"7F");

    -- signal rom : conv2_mem_t := (others => (WEIGHT_INIT));

    attribute ram_style : string;
    attribute ram_style of rom : signal is "block";

    signal dout_q : std_logic_vector(CONV2_KERNEL_SIZE ** 2 * CONV2_PRECISION - 1 downto 0);

begin

    dout <= dout_q;

    read : process (clk)
    begin
        if rising_edge(clk) then
            dout_q <= rom(to_integer(unsigned(addr)));
        end if;
    end process;

end rtl;
--------------------------------------------------------------------------------
-- CONV2 LAYER
--------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library xil_defaultlib;
use xil_defaultlib.constants_pkg.all;
use xil_defaultlib.weights_pkg.all;

entity Conv2_Layer is
    generic (
        S_AXIS_TDATA_WIDTH_G : positive := 64; -- 128 per line * 2 input channels
        M_AXIS_TDATA_WIDTH_G : positive := 64; -- 128 per line * 2 input channels
        COLUMS_PER_CYCLE : positive := 32
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
end entity Conv2_Layer;

architecture rtl of Conv2_Layer is
    signal conv2_en : std_logic;
    signal conv2_addr : std_logic_vector(CONV2_ADDR_WIDTH_C - 1 downto 0);
    signal conv2_dout : std_logic_vector(CONV2_KERNEL_SIZE ** 2 * CONV2_PRECISION - 1 downto 0);

    -- Signals for FSM
    type state_t is (
        IDLE,
        START_WINDOW,
        WAIT_LOAD,
        START_CONV,
        WAIT_CONV,
        WAIT_FLUSH,
        NEXT_BATCH,
        NEXT_POSITION,
        CLEAN_UP,
        DONE
    );
    signal state : state_t := IDLE;
    signal out_y : integer range 0 to CONV2_FRAME_HEIGHT - 1 := 0;
    signal batch_idx : integer range 0 to (CONV2_CHAN_OUTPUT)/CONV2_CONCURRENT_KERNELS - 1 := 0;
    signal first_window : std_logic := '1';
    signal weight_rdy_seen : std_logic := '0';
    signal line_rdy_seen : std_logic := '0';
    signal pad_bottom : std_logic := '0';
    signal clean_up_init : std_logic := '0';
    signal clean_up_rdy : std_logic := '0';
    signal clean_up_active : std_logic := '0';
    constant FINISH_CONDITION : std_logic_vector(AXIS_TUSER_WIDTH_C - 1 downto 0) := std_logic_vector(to_unsigned(CONV2_FRAME_HEIGHT - 1, ROW_ID_WIDTH_C) & to_unsigned(CONV2_CHAN_OUTPUT - 1, CHANNEL_ID_WIDTH_C));

    -- Signals for Kernel
    -- Index 0 is top left, index 8 is bottom right
    type single_kernel_buffer_t is array (0 to (CONV2_KERNEL_SIZE ** 2) - 1) of std_logic_vector(CONV2_PRECISION - 1 downto 0);
    type channel_kernel_buffer_t is array (0 to CONV2_CONCURRENT_KERNELS - 1) of single_kernel_buffer_t;
    type kernel_buffer_t is array (0 to CONV2_CHAN_INPUT - 1) of channel_kernel_buffer_t;
    signal kernel_buffer : kernel_buffer_t;
    signal weight_batch_idx : integer range 0 to CONV2_CHAN_OUTPUT/CONV2_CONCURRENT_KERNELS - 1 := 0;
    signal weight_load_rdy : std_logic := '0';
    signal weight_load_init : std_logic := '0';
    signal weight_valid : std_logic := '0';

    -- Signals for Line Fetch
    -- Index 0 is top, index 2 is bottom
    subtype single_line_buffer_t is std_logic_vector(CONV2_FRAME_WIDTH - 1 downto 0);
    type channel_line_buffer_t is array (0 to CONV2_KERNEL_SIZE - 1) of single_line_buffer_t;
    type line_buffer_t is array (0 to CONV2_CHAN_INPUT - 1) of channel_line_buffer_t;
    signal line_buffer : line_buffer_t := (others => (others => (others => '0')));
    signal advance_lines : integer range 0 to CONV2_KERNEL_SIZE := 0;
    signal line_load_rdy : std_logic := '0';
    signal line_load_init : std_logic := '0';
    signal line_load_active : std_logic := '0';

    -- Signals for Convolution
    signal convolution_init : std_logic := '0';
    signal convolution_rdy : std_logic := '0';
    signal convolution_active : std_logic := '0';
    type output_line_buffer_t is array (0 to CONV2_CONCURRENT_KERNELS - 1) of single_line_buffer_t;
    signal output_line_buffer : output_line_buffer_t;
    subtype accumulate_t is signed(CONV2_ACCUM_WIDTH_C - 1 downto 0);
    signal convolution_col_idx : integer range 0 to CONV2_FRAME_WIDTH - 1;

    -- Signals for AXI_S
    signal axi_in_ready : std_logic := '0';
    signal axi_out_valid : std_logic := '0';
    signal axi_out_init : std_logic := '0';
    signal axi_out_active : std_logic := '0';
    signal axi_out_rdy : std_logic := '0';

    -- Varied debug signals

    function convolution_func(lines : channel_line_buffer_t; kernel : single_kernel_buffer_t; central_column : natural) return accumulate_t is
        variable accumulated : accumulate_t := (others => '0');
    begin
        case central_column is
            when 0 =>
                for r in 0 to CONV2_KERNEL_SIZE - 1 loop
                    for c in 0 to (CONV2_KERNEL_SIZE/2) loop
                        if lines(r)(central_column + c) = '1' then
                            accumulated := accumulated + signed(kernel((c + (CONV2_KERNEL_SIZE/2)) + r * CONV2_KERNEL_SIZE));
                        end if;
                    end loop;
                end loop;
            when (CONV2_FRAME_WIDTH - 1) =>
                for r in 0 to CONV2_KERNEL_SIZE - 1 loop
                    for c in - (CONV2_KERNEL_SIZE/2) to 0 loop
                        if lines(r)(central_column + c) = '1' then
                            accumulated := accumulated + signed(kernel((c + (CONV2_KERNEL_SIZE/2)) + r * CONV2_KERNEL_SIZE));
                        end if;
                    end loop;
                end loop;
            when others =>
                for r in 0 to CONV2_KERNEL_SIZE - 1 loop
                    for c in - (CONV2_KERNEL_SIZE/2) to (CONV2_KERNEL_SIZE/2) loop
                        if lines(r)(central_column + c) = '1' then
                            accumulated := accumulated + signed(kernel((c + (CONV2_KERNEL_SIZE/2)) + r * CONV2_KERNEL_SIZE)); -- The kernel is from 0 to 8, that's why I add the limit
                        end if;
                    end loop;
                end loop;
        end case;
        return accumulated;
    end function;

begin
    conv2_mem : entity xil_defaultlib.Conv2_ROM
        port map(
            clk => aclk,
            en => conv2_en,
            addr => conv2_addr,
            dout => conv2_dout
        );
    s_axis_tready <= axi_in_ready;
    m_axis_tvalid <= axi_out_valid;
    m_axis_tkeep <= (others => '1');
    d_output <= (others => '0');

    ingress_lines : process (aclk)
        variable remaining_lines : natural range 0 to CONV2_KERNEL_SIZE * CONV2_CHAN_INPUT := 0;
        variable channel_id : natural range 0 to CONV2_CHAN_INPUT - 1 := 0;
        -- variable row_id : natural range 0 to CONV2_FRAME_HEIGHT - 1 := 0;
        variable clean_up_lines : natural range 0 to CONV2_CHAN_INPUT - 1;
    begin
        if rising_edge(aclk) then
            -- By default, do not accept data in
            axi_in_ready <= '0';
            -- Make the ready flag a pulse
            line_load_rdy <= '0';
            -- Same for clean up
            clean_up_rdy <= '0';

            if line_load_init = '1' then
                remaining_lines := advance_lines * CONV2_CHAN_INPUT; -- Per row, I need INPUT amount of channels
                line_load_active <= '1';

            elsif line_load_active = '1' then
                if remaining_lines > 0 then
                    -- Insert last row padding
                    if pad_bottom = '1' then
                        for chan in 0 to (CONV2_CHAN_INPUT - 1) loop
                            line_buffer(chan)(2) <= line_buffer(chan)(1);
                            line_buffer(chan)(1) <= line_buffer(chan)(0);
                            -- Insert an empty line
                            line_buffer(chan)(0) <= (others => '0');
                        end loop;
                        remaining_lines := 0;
                    else
                        -- AXI Stream in
                        -- If lines can be accepted, signal it
                        axi_in_ready <= '1';
                        if s_axis_tvalid = '1' and axi_in_ready = '1' then
                            channel_id := to_integer(unsigned(s_axis_tuser(CHANNEL_ID_WIDTH_C - 1 downto 0)));
                            -- row_id := to_integer(unsigned(s_axis_tuser(ROW_ID_WIDTH_C + CHANNEL_ID_WIDTH_C - 1 downto CHANNEL_ID_WIDTH_C)));
                            -- Move one line down the buffer.
                            line_buffer(channel_id)(2) <= line_buffer(channel_id)(1);
                            line_buffer(channel_id)(1) <= line_buffer(channel_id)(0);
                            -- Insert the incoming line
                            line_buffer(channel_id)(0) <= s_axis_tdata;
                            if remaining_lines = 1 then
                                axi_in_ready <= '0';
                            end if;
                            remaining_lines := remaining_lines - 1;
                        end if;
                    end if;
                else
                    -- If last iteration, signal that operation is complete
                    line_load_rdy <= '1';
                    line_load_active <= '0';
                end if;

            elsif clean_up_init = '1' then
                -- I am making boilerplate code for a clean up that takes more cycles, in case that ends up being the case
                clean_up_active <= '1';
                clean_up_lines := CONV2_KERNEL_SIZE - 1;
            elsif clean_up_active = '1' then
                for chan in 0 to (CONV2_CHAN_INPUT - 1) loop
                    line_buffer(chan)(clean_up_lines) <= (others => '0');
                end loop;
                if clean_up_lines = 1 then
                    clean_up_active <= '0';
                    clean_up_rdy <= '1';
                end if;
                clean_up_lines := clean_up_lines - 1;
            end if;
        end if;
    end process;

    fetch_weights : process (aclk)
        variable read_kernels : integer range 0 to CONV2_CONCURRENT_KERNELS * CONV2_CHAN_INPUT := 0;
        variable write_kernels : integer range 0 to CONV2_CONCURRENT_KERNELS * CONV2_CHAN_INPUT := 0;

    begin
        -- I assume one word contains one kernel
        if rising_edge(aclk) then
            weight_load_rdy <= '0';

            -- Initial read
            if weight_load_init = '1' then
                read_kernels := CONV2_CONCURRENT_KERNELS * CONV2_CHAN_INPUT - 1;
                write_kernels := CONV2_CONCURRENT_KERNELS * CONV2_CHAN_INPUT - 1;
                conv2_addr <= std_logic_vector(to_unsigned(weight_batch_idx * (CONV2_CONCURRENT_KERNELS * CONV2_CHAN_INPUT) + (CONV2_CONCURRENT_KERNELS * CONV2_CHAN_INPUT) - 1, conv2_addr'length));
                conv2_en <= '1';
                -- Load next address
            elsif read_kernels > 0 and weight_load_init = '0' then
                read_kernels := read_kernels - 1;

                conv2_addr <= std_logic_vector(to_unsigned(weight_batch_idx * (CONV2_CONCURRENT_KERNELS * CONV2_CHAN_INPUT) + read_kernels, conv2_addr'length));
                conv2_en <= '1';
                weight_valid <= '1';
            end if;

            -- Split the word into the several weights
            if weight_valid = '1' then
                for j in 0 to (CONV2_KERNEL_SIZE ** 2) - 1 loop
                    -- input = write/concurrent
                    -- output = write % concurrent
                    kernel_buffer(write_kernels mod CONV2_CHAN_INPUT)(write_kernels/CONV2_CHAN_INPUT)(j) <= conv2_dout((j + 1) * CONV2_PRECISION - 1 downto j * CONV2_PRECISION);
                end loop;
                if write_kernels = 0 then
                    conv2_en <= '0';
                    weight_valid <= '0';
                    weight_load_rdy <= '1';
                else
                    write_kernels := write_kernels - 1;
                end if;
            end if;
        end if;

    end process;

    convolution : process (aclk, aresetn)
        variable value : accumulate_t := (others => '0');
    begin
        if rising_edge(aclk) then
            convolution_rdy <= '0';

            if convolution_init = '1' then
                convolution_active <= '1';
                convolution_col_idx <= 0;
                -- output_line_buffer <= (others => '0');

            elsif convolution_active = '1' then
                for k in 0 to CONV2_CONCURRENT_KERNELS - 1 loop
                    for c in 0 to COLUMS_PER_CYCLE - 1 loop
                        value := (others => '0');
                        for i in 0 to CONV2_CHAN_INPUT - 1 loop
                            value := convolution_func(line_buffer(i), kernel_buffer(i)(k), c + convolution_col_idx) + value;
                        end loop;

                        output_line_buffer(k)(c + convolution_col_idx) <= '0';
                        if value > 255 then
                            output_line_buffer(k)(c + convolution_col_idx) <= '1';
                        end if;
                    end loop;
                end loop;
                if convolution_col_idx < CONV2_FRAME_WIDTH - COLUMS_PER_CYCLE - 1 then
                    convolution_col_idx <= convolution_col_idx + COLUMS_PER_CYCLE;
                else
                    convolution_rdy <= '1';
                    convolution_active <= '0';
                end if;
            end if;
        end if;
    end process;

    flush : process (aclk, aresetn)
        variable channel_id : integer range 0 to CONV2_CHAN_OUTPUT - 1 := 0;
        variable tuser : std_logic_vector(AXIS_TUSER_WIDTH_C - 1 downto 0) := (others => '0');
    begin

        if aresetn = '0' then
            m_axis_tdata <= (others => '0');
            axi_out_valid <= '0';
            axi_out_rdy <= '0';

        elsif rising_edge(aclk) then
            axi_out_rdy <= '0';
            m_axis_tlast <= '0';

            if axi_out_active = '1' then
                -- currently holding a valid beat
                if m_axis_tready = '1' then

                    if channel_id < CONV2_CONCURRENT_KERNELS - 1 then
                        -- handshake old beat, immediately load next beat
                        channel_id := channel_id + 1;
                        tuser := std_logic_vector(to_unsigned(out_y, ROW_ID_WIDTH_C)) & std_logic_vector(to_unsigned(channel_id + batch_idx * CONV2_CONCURRENT_KERNELS, CHANNEL_ID_WIDTH_C));
                        m_axis_tdata <= output_line_buffer(channel_id);
                        m_axis_tuser <= tuser;
                        axi_out_valid <= '1';
                        if tuser = FINISH_CONDITION then
                            m_axis_tlast <= '1';
                        end if;
                    else
                        -- finished burst
                        axi_out_rdy <= '1';
                        axi_out_valid <= '0';
                        axi_out_active <= '0';
                    end if;
                end if;

            else
                -- idle, can accept a new burst
                if axi_out_init = '1' then
                    axi_out_active <= '1';
                    channel_id := 0;
                    m_axis_tdata <= output_line_buffer(0);
                    m_axis_tuser <= std_logic_vector(to_unsigned(out_y, ROW_ID_WIDTH_C)) & std_logic_vector(to_unsigned(0 + batch_idx * CONV2_CONCURRENT_KERNELS, CHANNEL_ID_WIDTH_C)); -- I keep the 0 for readability
                    axi_out_valid <= '1';
                end if;
            end if;
        end if;
    end process;

    FSM : process (aclk, aresetn)
    begin
        if aresetn = '0' then
            state <= IDLE;
            weight_load_init <= '0';
            line_load_init <= '0';
            convolution_init <= '0';
            weight_batch_idx <= 0;
            batch_idx <= 0;
            out_y <= 0;
            advance_lines <= 0;
            first_window <= '1';

        elsif rising_edge(aclk) then
            -- default: init signals are pulses
            weight_load_init <= '0';
            line_load_init <= '0';
            convolution_init <= '0';
            axi_out_init <= '0';
            clean_up_init <= '0';

            case state is
                when IDLE =>
                    out_y <= 0;
                    batch_idx <= 0;
                    weight_batch_idx <= 0;
                    first_window <= '1';
                    state <= START_WINDOW;

                when START_WINDOW =>
                    -- first output pixel needs 2 fresh lines
                    if first_window = '1' then
                        advance_lines <= CONV2_KERNEL_SIZE - 1;
                        line_load_init <= '1';
                        line_rdy_seen <= '0';
                        first_window <= '0';
                    end if;

                    weight_batch_idx <= batch_idx;
                    weight_load_init <= '1';
                    weight_rdy_seen <= '0';
                    state <= WAIT_LOAD;

                when WAIT_LOAD =>
                    if weight_load_rdy = '1' then
                        weight_rdy_seen <= '1';
                    end if;

                    if line_load_rdy = '1' then
                        line_rdy_seen <= '1';
                    end if;
                    -- Either of the signals means load is ready
                    if (weight_rdy_seen = '1' or weight_load_rdy = '1') and
                        (line_rdy_seen = '1' or line_load_rdy = '1') then
                        state <= START_CONV;
                    end if;

                when START_CONV =>
                    convolution_init <= '1';
                    state <= WAIT_CONV;

                when WAIT_CONV =>
                    if convolution_rdy = '1' then
                        axi_out_init <= '1';
                        state <= WAIT_FLUSH;
                    end if;

                when WAIT_FLUSH =>
                    if axi_out_rdy = '1' then
                        state <= NEXT_BATCH;
                    end if;

                when NEXT_BATCH =>
                    if batch_idx < (CONV2_CHAN_OUTPUT / CONV2_CONCURRENT_KERNELS) - 1 then
                        batch_idx <= batch_idx + 1;
                        weight_batch_idx <= batch_idx + 1;
                        weight_load_init <= '1';
                        weight_rdy_seen <= '0';
                        state <= WAIT_LOAD;
                    else
                        batch_idx <= 0;
                        weight_batch_idx <= 0;
                        state <= NEXT_POSITION;
                    end if;

                when NEXT_POSITION =>
                    if out_y < CONV2_FRAME_HEIGHT - 1 then
                        out_y <= out_y + 1;
                        advance_lines <= 1;

                        if out_y = CONV2_FRAME_HEIGHT - 2 then
                            pad_bottom <= '1'; -- next window inserts zero row
                        else
                            pad_bottom <= '0';
                        end if;

                        line_load_init <= '1';
                        line_rdy_seen <= '0';
                        state <= START_WINDOW;
                    else
                        clean_up_init <= '1';
                        state <= CLEAN_UP;
                    end if;

                when CLEAN_UP =>
                    if clean_up_rdy = '1' then
                        state <= DONE;
                    end if;

                when DONE =>
                    state <= DONE;
            end case;
        end if;
    end process;

end rtl;