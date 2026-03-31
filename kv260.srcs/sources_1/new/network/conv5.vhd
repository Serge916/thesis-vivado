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

entity Conv5_ROM is
    port (
        -- Clock and Reset
        clk : in std_logic;

        -- Input
        en : in std_logic;
        addr : in std_logic_vector(CONV5_ADDR_WIDTH_C - 1 downto 0);
        -- Output
        dout : out std_logic_vector(CONV5_KERNEL_SIZE ** 2 * CONV5_PRECISION - 1 downto 0)
    );
end entity Conv5_ROM;

architecture rtl of Conv5_ROM is

    signal rom : conv5_mem_t := to_conv5_mem(CONV5_WEIGHTS);
    -- constant WEIGHT_INIT : std_logic_vector(8 * 9 - 1 downto 0) := (
    -- x"7F" & x"7F" & x"7F" &
    -- x"7F" & x"7F" & x"7F" &
    -- x"7F" & x"7F" & x"7F");

    -- signal rom : conv5_mem_t := (others => (WEIGHT_INIT));

    attribute ram_style : string;
    attribute ram_style of rom : signal is "block";

    signal dout_q : std_logic_vector(CONV5_KERNEL_SIZE ** 2 * CONV5_PRECISION - 1 downto 0);

begin

    dout <= dout_q;

    read : process (clk)
    begin
        if rising_edge(clk) then
            if en = '1' then
                dout_q <= rom(to_integer(unsigned(addr)));
                -- else
                --     dout_q <= (others => '0');
            end if;
        end if;
    end process;
end rtl;
--------------------------------------------------------------------------------
-- NEURON MEMORY
--------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library xil_defaultlib;
use xil_defaultlib.constants_pkg.all;
use xil_defaultlib.weights_pkg.all;
use xil_defaultlib.weights_value_pkg.all;

entity Conv5_Neuron_Mem is
    port (
        -- Clock and Reset
        clk : in std_logic;

        -- Input
        wr_addr : in std_logic_vector(CONV5_NEURON_ADDR_WIDTH - 1 downto 0);
        wr_en : in std_logic;
        din : in conv5_neuron_word_t;
        -- Output
        rd_en : in std_logic;
        dout : out conv5_neuron_word_t;
        rd_addr : in std_logic_vector(CONV5_NEURON_ADDR_WIDTH - 1 downto 0)
    );
end entity Conv5_Neuron_Mem;

architecture rtl of Conv5_Neuron_Mem is

    signal mem : conv5_neuron_mem_t := (others => (others => to_signed(0, conv5_neuron_potential_t'length)));

    attribute ram_style : string;
    attribute ram_style of mem : signal is "block";

    signal dout_q : conv5_neuron_word_t;

begin

    dout <= dout_q;

    read : process (clk)
    begin
        if rising_edge(clk) then
            if wr_en = '1' then
                mem(to_integer(unsigned(wr_addr))) <= din;
            end if;

            if rd_en = '1' then
                dout_q <= mem(to_integer(unsigned(rd_addr)));
            end if;
        end if;
    end process;
end rtl;
--------------------------------------------------------------------------------
-- CONV5 LAYER
--------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library xil_defaultlib;
use xil_defaultlib.constants_pkg.all;
use xil_defaultlib.weights_pkg.all;

entity Conv5_Layer is
    generic (
        S_AXIS_TDATA_WIDTH_G : positive := 8; -- 128 per line * 2 input channels
        M_AXIS_TDATA_WIDTH_G : positive := 8 -- 128 per line * 2 input channels
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
end entity Conv5_Layer;

architecture rtl of Conv5_Layer is
    signal conv5_en : std_logic;
    signal conv5_addr : std_logic_vector(CONV5_ADDR_WIDTH_C - 1 downto 0);
    signal conv5_dout : std_logic_vector(CONV5_KERNEL_SIZE ** 2 * CONV5_PRECISION - 1 downto 0);

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
    signal out_y : integer range 0 to CONV5_FRAME_HEIGHT - 1 := 0;
    signal batch_idx : integer range 0 to (CONV5_CHAN_OUTPUT)/CONV5_CONCURRENT_KERNELS - 1 := 0;
    signal first_window : std_logic := '1';
    signal weight_rdy_seen : std_logic := '0';
    signal line_rdy_seen : std_logic := '0';
    signal pad_bottom : std_logic := '0';
    signal clean_up_init : std_logic := '0';
    signal clean_up_rdy : std_logic := '0';
    signal clean_up_active : std_logic := '0';
    constant FINISH_CONDITION : std_logic_vector(AXIS_TUSER_WIDTH_C - 1 downto 0) := std_logic_vector(to_unsigned(CONV5_FRAME_HEIGHT - 1, ROW_ID_WIDTH_C) & to_unsigned(CONV5_CHAN_OUTPUT - 1, CHANNEL_ID_WIDTH_C));

    -- Signals for Kernel
    -- Index 0 is top left, index 8 is bottom right
    type single_kernel_buffer_t is array (0 to (CONV5_KERNEL_SIZE ** 2) - 1) of std_logic_vector(CONV5_PRECISION - 1 downto 0);
    type channel_kernel_buffer_t is array (0 to CONV5_CONCURRENT_KERNELS - 1) of single_kernel_buffer_t;
    type kernel_buffer_t is array (0 to CONV5_CHAN_INPUT - 1) of channel_kernel_buffer_t;
    signal kernel_buffer : kernel_buffer_t;
    signal weight_batch_idx : integer range 0 to CONV5_CHAN_OUTPUT/CONV5_CONCURRENT_KERNELS - 1 := 0;
    signal weight_load_rdy : std_logic := '0';
    signal weight_load_init : std_logic := '0';
    signal weight_valid : std_logic := '0';

    -- Signals for Line Fetch
    -- Index 0 is top, index 2 is bottom
    subtype single_line_buffer_t is std_logic_vector(CONV5_FRAME_WIDTH + 1 downto 0);
    type channel_line_buffer_t is array (0 to CONV5_KERNEL_SIZE - 1) of single_line_buffer_t;
    type line_buffer_t is array (0 to CONV5_CHAN_INPUT - 1) of channel_line_buffer_t;
    signal line_buffer : line_buffer_t := (others => (others => (others => '0')));
    signal advance_lines : integer range 0 to CONV5_KERNEL_SIZE := 0;
    signal line_load_rdy : std_logic := '0';
    signal line_load_init : std_logic := '0';
    signal line_load_active : std_logic := '0';
    signal remaining_lines : natural range 0 to CONV5_KERNEL_SIZE * CONV5_CHAN_INPUT := 0;

    -- Signals for Convolution
    signal convolution_init : std_logic := '0';
    signal convolution_rdy : std_logic := '0';
    signal convolution_active : std_logic := '0';
    type output_line_buffer_t is array (0 to CONV5_CONCURRENT_KERNELS - 1) of std_logic_vector(CONV5_FRAME_WIDTH - 1 downto 0);
    signal output_line_buffer : output_line_buffer_t;
    subtype accumulate_t is signed(CONV5_INTERMEDIATE_WIDTH_C - 1 downto 0);
    subtype intermediate_t is signed(CONV5_INTERMEDIATE_WIDTH_C - 1 downto 0);
    type intermediate_reg_t is array (0 to CONV5_CONCURRENT_KERNELS - 1) of intermediate_t;
    signal convolution_col_idx : integer range 0 to CONV5_FRAME_WIDTH - 1;
    signal remaining_operations : natural range 0 to CONV5_CHAN_INPUT;
    type accumulate_reg_t is array (0 to CONV5_CONCURRENT_KERNELS - 1) of accumulate_t;
    signal value : accumulate_reg_t := (others => (others => '0'));
    type operation_fsm_t is (
        ISSUE,
        READ_MEM,
        WRITE_BACK
    );
    signal operation_fsm : operation_fsm_t;
    signal pipeline_issue_idx : natural range 0 to CONV5_CHAN_INPUT := 0;
    signal pipeline_retire_cnt : natural range 0 to CONV5_CHAN_INPUT := 0;

    -- Signals for convolution pipeline
    signal line_buffer_operation : channel_line_buffer_t;
    signal kernel_buffer_operation : channel_kernel_buffer_t;
    signal kernel_buffer_operation_reg : channel_kernel_buffer_t;
    signal column_operation : integer range 0 to CONV5_FRAME_WIDTH - 1;
    type convolution_terms_channel_t is array (0 to CONV5_KERNEL_SIZE ** 2 - 1) of signed(CONV5_PRECISION - 1 downto 0);
    type convolution_terms_t is array (0 to CONV5_CONCURRENT_KERNELS - 1) of convolution_terms_channel_t;
    signal convolution_terms : convolution_terms_t := (others => (others => (to_signed(0, CONV5_PRECISION))));
    type adder_tree_first_channel_t is array (0 to 4) of accumulate_t;
    type adder_tree_first_t is array (0 to CONV5_CONCURRENT_KERNELS - 1) of adder_tree_first_channel_t;
    signal adder_tree_first : adder_tree_first_t;
    type adder_tree_second_channel_t is array (0 to 2) of accumulate_t;
    type adder_tree_second_t is array (0 to CONV5_CONCURRENT_KERNELS - 1) of adder_tree_second_channel_t;
    signal adder_tree_second : adder_tree_second_t;
    signal result : accumulate_reg_t := (others => (others => '0'));
    signal convolution_engine_rdy : std_logic := '0';
    signal convolution_engine_init : std_logic := '0';
    signal convolution_engine_stage_valid : std_logic_vector(0 to 3) := (others => '0');
    type window_mask_t is array (0 to CONV5_KERNEL_SIZE ** 2 - 1) of std_logic;
    signal window_mask : window_mask_t := (others => '0');
    -- Signals for AXI_S
    signal axi_in_ready : std_logic := '0';
    signal axi_out_valid : std_logic := '0';
    signal axi_out_init : std_logic := '0';
    signal axi_out_active : std_logic := '0';
    signal axi_out_rdy : std_logic := '0';
    signal axi_out_tuser : std_logic_vector(AXIS_TUSER_WIDTH_C - 1 downto 0);
    -- Signals for neuron memory
    signal neuron_wr_en : std_logic := '0';
    signal neuron_rd_en : std_logic := '0';
    signal neuron_rd_addr : std_logic_vector(CONV5_NEURON_ADDR_WIDTH - 1 downto 0);
    signal neuron_wr_addr : std_logic_vector(CONV5_NEURON_ADDR_WIDTH - 1 downto 0);
    signal neuron_dout : conv5_neuron_word_t;
    signal neuron_din : conv5_neuron_word_t;

    -- Varied debug signals

begin
    conv5_mem : entity xil_defaultlib.Conv5_ROM
        port map(
            clk => aclk,
            en => conv5_en,
            addr => conv5_addr,
            dout => conv5_dout
        );
    conv5_neuron_mem : entity xil_defaultlib.Conv5_Neuron_Mem
        port map(
            clk => aclk,
            wr_en => neuron_wr_en,
            rd_en => neuron_rd_en,
            wr_addr => neuron_wr_addr,
            rd_addr => neuron_rd_addr,
            dout => neuron_dout,
            din => neuron_din
        );

    s_axis_tready <= axi_in_ready;
    m_axis_tvalid <= axi_out_valid;
    m_axis_tkeep <= (others => '1');
    d_output <= (others => '0');

    process (axi_out_tuser)
    begin
        if axi_out_tuser = FINISH_CONDITION then
            m_axis_tlast <= '1';
        else
            m_axis_tlast <= '0';
        end if;
        m_axis_tuser <= axi_out_tuser;
    end process;

    ingress_lines : process (aclk)
        variable channel_id : natural range 0 to CONV5_CHAN_INPUT - 1 := 0;
        -- variable row_id : natural range 0 to CONV5_FRAME_HEIGHT - 1 := 0;
        variable clean_up_lines : natural range 0 to CONV5_KERNEL_SIZE - 1;
    begin
        if rising_edge(aclk) then
            -- By default, do not accept data in
            axi_in_ready <= '0';
            -- Make the ready flag a pulse
            line_load_rdy <= '0';
            -- Same for clean up
            clean_up_rdy <= '0';

            if line_load_init = '1' then
                remaining_lines <= advance_lines * CONV5_CHAN_INPUT; -- Per row, I need INPUT amount of channels
                line_load_active <= '1';

            elsif line_load_active = '1' then
                if remaining_lines > 0 then
                    -- Insert last row padding
                    if pad_bottom = '1' then
                        for chan in 0 to (CONV5_CHAN_INPUT - 1) loop
                            line_buffer(chan)(0) <= line_buffer(chan)(1);
                            line_buffer(chan)(1) <= line_buffer(chan)(2);
                            -- Insert an empty line
                            line_buffer(chan)(2) <= (others => '0');
                        end loop;
                        remaining_lines <= 0;
                    else
                        -- AXI Stream in
                        -- If lines can be accepted, signal it
                        axi_in_ready <= '1';
                        if s_axis_tvalid = '1' and axi_in_ready = '1' then
                            channel_id := to_integer(unsigned(s_axis_tuser(CHANNEL_ID_WIDTH_C - 1 downto 0)));
                            -- row_id := to_integer(unsigned(s_axis_tuser(ROW_ID_WIDTH_C + CHANNEL_ID_WIDTH_C - 1 downto CHANNEL_ID_WIDTH_C)));
                            -- Move one line down the buffer.
                            line_buffer(channel_id)(0) <= line_buffer(channel_id)(1);
                            line_buffer(channel_id)(1) <= line_buffer(channel_id)(2);
                            -- Insert the incoming line
                            line_buffer(channel_id)(2) <= '0' & s_axis_tdata & '0';
                            if remaining_lines = 1 then
                                axi_in_ready <= '0';
                            end if;
                            remaining_lines <= remaining_lines - 1;
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
                clean_up_lines := CONV5_KERNEL_SIZE - 1;
            elsif clean_up_active = '1' then
                for chan in 0 to (CONV5_CHAN_INPUT - 1) loop
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
        variable read_kernels : integer range 0 to CONV5_CONCURRENT_KERNELS * CONV5_CHAN_INPUT := 0;
        variable write_kernels : integer range 0 to CONV5_CONCURRENT_KERNELS * CONV5_CHAN_INPUT := 0;

    begin
        -- I assume one word contains one kernel
        if rising_edge(aclk) then
            weight_load_rdy <= '0';

            -- Initial read
            if weight_load_init = '1' then
                read_kernels := CONV5_CONCURRENT_KERNELS * CONV5_CHAN_INPUT - 1;
                write_kernels := CONV5_CONCURRENT_KERNELS * CONV5_CHAN_INPUT - 1;
                conv5_addr <= std_logic_vector(to_unsigned(weight_batch_idx * (CONV5_CONCURRENT_KERNELS * CONV5_CHAN_INPUT) + (CONV5_CONCURRENT_KERNELS * CONV5_CHAN_INPUT) - 1, conv5_addr'length));
                conv5_en <= '1';
                -- Load next address
            elsif read_kernels > 0 and weight_load_init = '0' then
                read_kernels := read_kernels - 1;

                conv5_addr <= std_logic_vector(to_unsigned(weight_batch_idx * (CONV5_CONCURRENT_KERNELS * CONV5_CHAN_INPUT) + read_kernels, conv5_addr'length));
                conv5_en <= '1';
                weight_valid <= '1';
            end if;

            -- Split the word into the several weights
            if weight_valid = '1' then
                for j in 0 to (CONV5_KERNEL_SIZE ** 2) - 1 loop
                    -- input = write/concurrent
                    -- output = write % concurrent
                    kernel_buffer(write_kernels mod CONV5_CHAN_INPUT)(write_kernels/CONV5_CHAN_INPUT)(j) <= conv5_dout((j + 1) * CONV5_PRECISION - 1 downto j * CONV5_PRECISION);
                end loop;
                if write_kernels = 0 then
                    conv5_en <= '0';
                    weight_valid <= '0';
                    weight_load_rdy <= '1';
                else
                    write_kernels := write_kernels - 1;
                end if;
            end if;
        end if;

    end process;

    convolution : process (aclk)
        variable temp_accumulation : signed(CONV5_INTERMEDIATE_WIDTH_C - 1 downto 0);
        variable residual_connection : intermediate_reg_t;
        variable channel_residual_idx : natural range 0 to CONV5_CHAN_OUTPUT - 1;
    begin
        if rising_edge(aclk) then
            convolution_rdy <= '0';
            convolution_engine_init <= '0';
            neuron_wr_en <= '0';
            neuron_rd_en <= '0';

            if convolution_init = '1' then
                convolution_active <= '1';
                convolution_col_idx <= 0;
                pipeline_issue_idx <= CONV5_CHAN_INPUT;
                pipeline_retire_cnt <= CONV5_CHAN_INPUT;
                value <= (others => to_signed(0, CONV5_INTERMEDIATE_WIDTH_C));
                operation_fsm <= ISSUE;

            elsif convolution_active = '1' then

                case operation_fsm is
                    when ISSUE =>
                        if pipeline_issue_idx > 0 then
                            line_buffer_operation <= line_buffer(pipeline_issue_idx - 1); -- Substract by one to simplify the control logic
                            kernel_buffer_operation <= kernel_buffer(pipeline_issue_idx - 1);
                            column_operation <= convolution_col_idx;
                            convolution_engine_init <= '1';
                            pipeline_issue_idx <= pipeline_issue_idx - 1;
                        end if;

                        if convolution_engine_rdy = '1' then
                            for k in 0 to CONV5_CONCURRENT_KERNELS - 1 loop
                                value(k) <= value(k) + result(k);
                            end loop;

                            if pipeline_retire_cnt = 1 then
                                operation_fsm <= READ_MEM;
                                -- batch*Kernels : out_chan. out_chan*width*row+col
                                neuron_rd_en <= '1';
                                neuron_rd_addr <= std_logic_vector(to_unsigned(batch_idx * CONV5_FRAME_WIDTH + out_y * CONV5_FRAME_WIDTH * CONV5_CHAN_OUTPUT/CONV5_CONCURRENT_KERNELS + convolution_col_idx, CONV5_NEURON_ADDR_WIDTH));
                            end if;

                            pipeline_retire_cnt <= pipeline_retire_cnt - 1;
                        end if;

                    when READ_MEM =>
                        -- fetch value from memory
                        operation_fsm <= WRITE_BACK;

                    when WRITE_BACK =>
                        -- Assign the output pixel its binary value
                        neuron_wr_en <= '1';
                        neuron_wr_addr <= std_logic_vector(to_unsigned(batch_idx * CONV5_FRAME_WIDTH + out_y * CONV5_FRAME_WIDTH * CONV5_CHAN_OUTPUT/CONV5_CONCURRENT_KERNELS + convolution_col_idx, CONV5_NEURON_ADDR_WIDTH));

                        for k in 0 to CONV5_CONCURRENT_KERNELS - 1 loop
                            channel_residual_idx := batch_idx * CONV5_CONCURRENT_KERNELS + k;
                            -- Divide by 2 and add the convolution result
                            if line_buffer(channel_residual_idx)(1)(convolution_col_idx + 1) = '1' then
                                residual_connection(k) := to_signed(256, CONV5_INTERMEDIATE_WIDTH_C);
                            else
                                residual_connection(k) := to_signed(0, CONV5_INTERMEDIATE_WIDTH_C);
                            end if;

                            temp_accumulation := shift_right(neuron_dout(k), 1) + resize(value(k), temp_accumulation'length) + residual_connection(k);
                            output_line_buffer(k)(convolution_col_idx) <= '0';

                            if temp_accumulation < 0 then
                                neuron_din(k) <= to_signed(0, CONV5_MEMBRANE_POTENTIAL_WIDTH);
                            elsif temp_accumulation > to_signed(CONV5_MEMBRANE_POTENTIAL_THRESHOLD, temp_accumulation'length) then
                                neuron_din(k) <= to_signed(0, CONV5_MEMBRANE_POTENTIAL_WIDTH);
                                output_line_buffer(k)(convolution_col_idx) <= '1';
                            else
                                neuron_din(k) <= resize(temp_accumulation, CONV5_MEMBRANE_POTENTIAL_WIDTH);
                            end if;
                        end loop;
                        -- Reset value for next cycle
                        value <= (others => to_signed(0, CONV5_INTERMEDIATE_WIDTH_C));

                        -- Move on to the next column or finish
                        if convolution_col_idx < CONV5_FRAME_WIDTH - 1 then
                            convolution_col_idx <= convolution_col_idx + 1;
                            pipeline_issue_idx <= CONV5_CHAN_INPUT;
                            pipeline_retire_cnt <= CONV5_CHAN_INPUT;
                            operation_fsm <= ISSUE;
                        else
                            convolution_rdy <= '1';
                            convolution_active <= '0';
                        end if;
                end case;
            end if;

        end if;
    end process;

    convolution_pipeline : process (aclk)
    begin
        if rising_edge(aclk) then
            -- Move the validity flag forward
            convolution_engine_rdy <= convolution_engine_stage_valid(3);
            convolution_engine_stage_valid(3) <= convolution_engine_stage_valid(2);
            convolution_engine_stage_valid(2) <= convolution_engine_stage_valid(1);
            convolution_engine_stage_valid(1) <= convolution_engine_stage_valid(0);
            convolution_engine_stage_valid(0) <= convolution_engine_init;

            -- Stage 1: Get the window mask
            if convolution_engine_init = '1' then
                for r in 0 to CONV5_KERNEL_SIZE - 1 loop
                    for c in - (CONV5_KERNEL_SIZE/2) to (CONV5_KERNEL_SIZE/2) loop
                        window_mask(CONV5_KERNEL_SIZE * r + c + (CONV5_KERNEL_SIZE/2))
                        <= line_buffer_operation(r)(column_operation + 1 + c);
                    end loop;
                end loop;
                kernel_buffer_operation_reg <= kernel_buffer_operation;
            end if;

            -- Stage 2: Get the valid terms
            if convolution_engine_stage_valid(0) = '1' then
                for k in 0 to CONV5_CONCURRENT_KERNELS - 1 loop
                    for t in 0 to CONV5_KERNEL_SIZE ** 2 - 1 loop
                        if window_mask(t) = '1' then
                            convolution_terms(k)(t) <= signed(kernel_buffer_operation_reg(k)(t));
                        else
                            convolution_terms(k)(t) <= to_signed(0, CONV5_PRECISION);
                        end if;
                    end loop;
                end loop;
            end if;

            -- Stage 3: First adder tree instance
            if convolution_engine_stage_valid(1) = '1' then
                for k in 0 to CONV5_CONCURRENT_KERNELS - 1 loop
                    adder_tree_first(k)(0) <= resize(convolution_terms(k)(0) + convolution_terms(k)(1), CONV5_INTERMEDIATE_WIDTH_C);
                    adder_tree_first(k)(1) <= resize(convolution_terms(k)(2) + convolution_terms(k)(3), CONV5_INTERMEDIATE_WIDTH_C);
                    adder_tree_first(k)(2) <= resize(convolution_terms(k)(4) + convolution_terms(k)(5), CONV5_INTERMEDIATE_WIDTH_C);
                    adder_tree_first(k)(3) <= resize(convolution_terms(k)(6) + convolution_terms(k)(7), CONV5_INTERMEDIATE_WIDTH_C);
                    adder_tree_first(k)(4) <= resize(convolution_terms(k)(8), CONV5_INTERMEDIATE_WIDTH_C);
                end loop;
            end if;

            -- Stage 4: Second adder tree instance
            if convolution_engine_stage_valid(2) = '1' then
                for k in 0 to CONV5_CONCURRENT_KERNELS - 1 loop
                    adder_tree_second(k)(0) <= adder_tree_first(k)(0) + adder_tree_first(k)(1);
                    adder_tree_second(k)(1) <= adder_tree_first(k)(2) + adder_tree_first(k)(3);
                    adder_tree_second(k)(2) <= adder_tree_first(k)(4);
                end loop;
            end if;

            -- Stage 5: Last adder tree instance
            if convolution_engine_stage_valid(3) = '1' then
                for k in 0 to CONV5_CONCURRENT_KERNELS - 1 loop
                    result(k) <= adder_tree_second(k)(0) + adder_tree_second(k)(1) + adder_tree_second(k)(2);
                end loop;
            end if;

        end if;
    end process;

    flush : process (aclk, aresetn)
        variable channel_id : integer range 0 to CONV5_CHAN_OUTPUT - 1 := 0;
        variable tuser : std_logic_vector(AXIS_TUSER_WIDTH_C - 1 downto 0) := (others => '0');
    begin

        if aresetn = '0' then
            m_axis_tdata <= (others => '0');
            axi_out_valid <= '0';
            axi_out_rdy <= '0';

        elsif rising_edge(aclk) then
            axi_out_rdy <= '0';

            if axi_out_active = '1' then
                -- currently holding a valid beat
                if m_axis_tready = '1' then

                    if channel_id < CONV5_CONCURRENT_KERNELS - 1 then
                        -- handshake old beat, immediately load next beat
                        channel_id := channel_id + 1;
                        tuser := std_logic_vector(to_unsigned(out_y, ROW_ID_WIDTH_C)) & std_logic_vector(to_unsigned(channel_id + batch_idx * CONV5_CONCURRENT_KERNELS, CHANNEL_ID_WIDTH_C));
                        m_axis_tdata <= output_line_buffer(channel_id);
                        axi_out_tuser <= tuser;
                        axi_out_valid <= '1';

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
                    axi_out_tuser <= std_logic_vector(to_unsigned(out_y, ROW_ID_WIDTH_C)) & std_logic_vector(to_unsigned(0 + batch_idx * CONV5_CONCURRENT_KERNELS, CHANNEL_ID_WIDTH_C)); -- I keep the 0 for readability
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
            first_window <= '0';

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
                        advance_lines <= CONV5_KERNEL_SIZE - 1;
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
                    if batch_idx < (CONV5_CHAN_OUTPUT / CONV5_CONCURRENT_KERNELS) - 1 then
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
                    if out_y < CONV5_FRAME_HEIGHT - 1 then
                        out_y <= out_y + 1;
                        advance_lines <= 1;

                        if out_y = CONV5_FRAME_HEIGHT - 2 then
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