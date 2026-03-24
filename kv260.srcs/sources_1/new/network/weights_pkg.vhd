library ieee;
use ieee.std_logic_1164.all;
use ieee.math_real.all;
package weights_pkg is

    --------------------------------------------------------------------------------
    -- Shared accross layers
    --------------------------------------------------------------------------------
    constant CHANNEL_ID_WIDTH_C : positive := 8; -- Up to 256 channels
    constant ROW_ID_WIDTH_C : positive := 7; -- Up to 128 channels
    constant AXIS_TUSER_WIDTH_C : positive := CHANNEL_ID_WIDTH_C + ROW_ID_WIDTH_C; -- Encodes channel and row metadata

    --------------------------------------------------------------------------------
    -- Convolution 1 
    --------------------------------------------------------------------------------
    constant CONV1_CHAN_INPUT : positive := 2;
    constant CONV1_CHAN_OUTPUT : positive := 8; -- Output 3rd dimension
    constant CONV1_ADDR_WIDTH_C : positive := integer(ceil(log2(real(CONV1_CHAN_OUTPUT))));
    constant CONV1_CHAN_WIDTH_C : positive := integer(ceil(log2(real(CONV1_CHAN_INPUT))));
    constant CONV1_KERNEL_SIZE : positive := 3;
    constant CONV1_PRECISION : positive := 8;
    constant CONV1_ACCUM_WIDTH_C : positive := integer(ceil(log2(real((2 ** CONV1_PRECISION) * 9)))); -- Biggest value if all 9 kernel are max value and spiked
    constant CONV1_INTERMEDIATE_WIDTH_C : positive := integer(ceil(log2(real((2 ** CONV1_PRECISION) * 9 * CONV1_CHAN_INPUT)))); -- Biggest value if all channels were at max
    constant CONV1_FRAME_WIDTH : positive := 128;
    constant CONV1_FRAME_HEIGHT : positive := 128;
    constant CONV1_CONCURRENT_KERNELS : positive := 4;
    constant CONV1_TDATA_WIDTH : positive := 256;

    type conv1_mem_t is array (0 to 32 - 1) of std_logic_vector(CONV1_CHAN_INPUT * CONV1_PRECISION * CONV1_KERNEL_SIZE ** 2 - 1 downto 0);
    --------------------------------------------------------------------------------
    -- Maxpool 1
    --------------------------------------------------------------------------------
    constant MAXPOOL1_OUTPUT_WIDTH : positive := 64;
    constant MAXPOOL1_OUTPUT_HEIGHT : positive := 64;
    constant MAXPOOL1_TDATA_WIDTH : positive := 128;
    --------------------------------------------------------------------------------
    -- Convolution 2
    --------------------------------------------------------------------------------
    constant CONV2_CHAN_INPUT : positive := CONV1_CHAN_OUTPUT;
    constant CONV2_CHAN_OUTPUT : positive := 16; -- Output 3rd dimension
    constant CONV2_ADDR_WIDTH_C : positive := integer(ceil(log2(real(CONV2_CHAN_OUTPUT * CONV2_CHAN_INPUT))));
    constant CONV2_KERNEL_SIZE : positive := 3;
    constant CONV2_PRECISION : positive := 8;
    constant CONV2_ACCUM_WIDTH_C : positive := integer(ceil(log2(real((2 ** CONV2_PRECISION) * 9)))); -- Biggest value if all 9 kernel are max value and spiked
    constant CONV2_INTERMEDIATE_WIDTH_C : positive := integer(ceil(log2(real((2 ** CONV2_PRECISION) * 9 * CONV2_CHAN_INPUT)))); -- Biggest value if all channels were at max
    constant CONV2_FRAME_WIDTH : positive := MAXPOOL1_OUTPUT_WIDTH;
    constant CONV2_FRAME_HEIGHT : positive := MAXPOOL1_OUTPUT_HEIGHT;
    constant CONV2_CONCURRENT_KERNELS : positive := 8;
    constant CONV2_TDATA_WIDTH : positive := MAXPOOL1_OUTPUT_WIDTH;
    constant CONV2_BUFFER_ADDR_WIDTH_C : positive := integer(ceil(log2(real(CONV2_KERNEL_SIZE * CONV2_CHAN_INPUT))));

    -- constant CONV2_KERNELS_PER_WORD : positive := 4;
    -- type conv2_single_channel_mem_t is array (0 to CONV2_CHAN_OUTPUT/CONV2_KERNELS_PER_WORD - 1) of std_logic_vector(CONV2_KERNELS_PER_WORD * CONV2_PRECISION * CONV2_KERNEL_SIZE ** 2 - 1 downto 0);
    -- type conv2_mem_t is array (0 to CONV2_CHAN_INPUT - 1) of conv2_single_channel_mem_t;
    type conv2_full_t is array (0 to 63) of std_logic_vector(2303 downto 0);
    type conv2_mem_t is array (0 to CONV2_CHAN_OUTPUT * CONV2_CHAN_INPUT - 1) of std_logic_vector(CONV2_PRECISION * CONV2_KERNEL_SIZE ** 2 - 1 downto 0);
    function to_conv2_mem(w : conv2_full_t) return conv2_mem_t;
    --------------------------------------------------------------------------------
    -- Maxpool 2
    --------------------------------------------------------------------------------
    constant MAXPOOL2_OUTPUT_WIDTH : positive := 32;
    constant MAXPOOL2_OUTPUT_HEIGHT : positive := 32;
    constant MAXPOOL2_TDATA_WIDTH : positive := 64;
    --------------------------------------------------------------------------------
    -- Convolution 3
    --------------------------------------------------------------------------------
    constant CONV3_CHAN_INPUT : positive := CONV2_CHAN_OUTPUT;
    constant CONV3_CHAN_OUTPUT : positive := 32; -- Output 3rd dimension
    constant CONV3_ADDR_WIDTH_C : positive := integer(ceil(log2(real(CONV3_CHAN_OUTPUT * CONV3_CHAN_INPUT))));
    constant CONV3_KERNEL_SIZE : positive := 3;
    constant CONV3_PRECISION : positive := 8;
    constant CONV3_ACCUM_WIDTH_C : positive := integer(ceil(log2(real((2 ** CONV3_PRECISION) * 9)))); -- Biggest value if all 9 kernel are max value and spiked
    constant CONV3_INTERMEDIATE_WIDTH_C : positive := integer(ceil(log2(real((2 ** CONV3_PRECISION) * 9 * CONV3_CHAN_INPUT)))); -- Biggest value if all channels were at max
    constant CONV3_FRAME_WIDTH : positive := MAXPOOL2_OUTPUT_WIDTH;
    constant CONV3_FRAME_HEIGHT : positive := MAXPOOL2_OUTPUT_HEIGHT;
    constant CONV3_CONCURRENT_KERNELS : positive := 16;
    constant CONV3_TDATA_WIDTH : positive := MAXPOOL2_OUTPUT_WIDTH;
    constant CONV3_BUFFER_ADDR_WIDTH_C : positive := integer(ceil(log2(real(CONV3_KERNEL_SIZE * CONV3_CHAN_INPUT))));

    type conv3_full_t is array (0 to 255) of std_logic_vector(2303 downto 0);
    type conv3_mem_t is array (0 to CONV3_CHAN_OUTPUT * CONV3_CHAN_INPUT - 1) of std_logic_vector(CONV3_PRECISION * CONV3_KERNEL_SIZE ** 2 - 1 downto 0);
    function to_conv3_mem(w : conv3_full_t) return conv3_mem_t;
    --------------------------------------------------------------------------------
    -- Maxpool 3
    --------------------------------------------------------------------------------
    constant MAXPOOL3_OUTPUT_WIDTH : positive := 16;
    constant MAXPOOL3_OUTPUT_HEIGHT : positive := 16;
    constant MAXPOOL3_TDATA_WIDTH : positive := 32;
    --------------------------------------------------------------------------------
    -- Convolution 4
    --------------------------------------------------------------------------------
    constant CONV4_CHAN_INPUT : positive := CONV3_CHAN_OUTPUT;
    constant CONV4_CHAN_OUTPUT : positive := 64; -- Output 3rd dimension
    constant CONV4_ADDR_WIDTH_C : positive := integer(ceil(log2(real(CONV4_CHAN_OUTPUT * CONV4_CHAN_INPUT))));
    constant CONV4_KERNEL_SIZE : positive := 3;
    constant CONV4_PRECISION : positive := 8;
    constant CONV4_ACCUM_WIDTH_C : positive := integer(ceil(log2(real((2 ** CONV4_PRECISION) * 9)))); -- Biggest value if all 9 kernel are max value and spiked
    constant CONV4_INTERMEDIATE_WIDTH_C : positive := integer(ceil(log2(real((2 ** CONV4_PRECISION) * 9 * CONV4_CHAN_INPUT)))); -- Biggest value if all channels were at max
    constant CONV4_FRAME_WIDTH : positive := MAXPOOL3_OUTPUT_WIDTH;
    constant CONV4_FRAME_HEIGHT : positive := MAXPOOL3_OUTPUT_HEIGHT;
    constant CONV4_CONCURRENT_KERNELS : positive := 16;
    constant CONV4_TDATA_WIDTH : positive := MAXPOOL3_OUTPUT_WIDTH;
    constant CONV4_BUFFER_ADDR_WIDTH_C : positive := integer(ceil(log2(real(CONV4_KERNEL_SIZE * CONV4_CHAN_INPUT))));

    type conv4_full_t is array (0 to 1023) of std_logic_vector(2303 downto 0);
    type conv4_mem_t is array (0 to CONV4_CHAN_OUTPUT * CONV4_CHAN_INPUT - 1) of std_logic_vector(CONV4_PRECISION * CONV4_KERNEL_SIZE ** 2 - 1 downto 0);
    function to_conv4_mem(w : conv4_full_t) return conv4_mem_t;
    --------------------------------------------------------------------------------
    -- Maxpool 4
    --------------------------------------------------------------------------------
    constant MAXPOOL4_OUTPUT_WIDTH : positive := 8;
    constant MAXPOOL4_OUTPUT_HEIGHT : positive := 8;
    constant MAXPOOL4_TDATA_WIDTH : positive := 16;
    --------------------------------------------------------------------------------
    -- Convolution 5
    --------------------------------------------------------------------------------
    constant CONV5_CHAN_INPUT : positive := CONV4_CHAN_OUTPUT;
    constant CONV5_CHAN_OUTPUT : positive := 128; -- Output 3rd dimension
    constant CONV5_ADDR_WIDTH_C : positive := integer(ceil(log2(real(CONV5_CHAN_OUTPUT * CONV5_CHAN_INPUT))));
    constant CONV5_KERNEL_SIZE : positive := 3;
    constant CONV5_PRECISION : positive := 8;
    constant CONV5_ACCUM_WIDTH_C : positive := integer(ceil(log2(real((2 ** CONV5_PRECISION) * 9)))); -- Biggest value if all 9 kernel are max value and spiked
    constant CONV5_INTERMEDIATE_WIDTH_C : positive := integer(ceil(log2(real((2 ** CONV5_PRECISION) * 9 * CONV5_CHAN_INPUT)))); -- Biggest value if all channels were at max
    constant CONV5_FRAME_WIDTH : positive := MAXPOOL4_OUTPUT_WIDTH;
    constant CONV5_FRAME_HEIGHT : positive := MAXPOOL4_OUTPUT_HEIGHT;
    constant CONV5_CONCURRENT_KERNELS : positive := 16;
    constant CONV5_TDATA_WIDTH : positive := MAXPOOL4_OUTPUT_WIDTH;
    constant CONV5_BUFFER_ADDR_WIDTH_C : positive := integer(ceil(log2(real(CONV5_KERNEL_SIZE * CONV5_CHAN_INPUT))));

    type conv5_full_t is array (0 to 2047) of std_logic_vector(2303 downto 0);
    type conv5_mem_t is array (0 to CONV5_CHAN_OUTPUT * CONV5_CHAN_INPUT - 1) of std_logic_vector(CONV5_PRECISION * CONV5_KERNEL_SIZE ** 2 - 1 downto 0);
    function to_conv5_mem(w : conv5_full_t) return conv5_mem_t;
end package;

package body weights_pkg is

    function to_conv2_mem(w : conv2_full_t) return conv2_mem_t is
        variable r : conv2_mem_t;
        constant KERNEL_BITS_C : integer := CONV2_PRECISION * CONV2_KERNEL_SIZE ** 2;
    begin
        for oc in 0 to CONV2_CHAN_OUTPUT - 1 loop
            for ic in 0 to CONV2_CHAN_INPUT - 1 loop
                r(oc * CONV2_CHAN_INPUT + ic) :=
                w(oc)((ic + 1) * KERNEL_BITS_C - 1 downto ic * KERNEL_BITS_C);
            end loop;
        end loop;
        return r;
    end function;

    function to_conv3_mem(w : conv3_full_t) return conv3_mem_t is
        variable r : conv3_mem_t;
        constant KERNEL_BITS_C : integer := CONV3_PRECISION * CONV3_KERNEL_SIZE ** 2;
    begin
        for oc in 0 to CONV3_CHAN_OUTPUT - 1 loop
            for ic in 0 to CONV3_CHAN_INPUT - 1 loop
                r(oc * CONV3_CHAN_INPUT + ic) :=
                w(oc)((ic + 1) * KERNEL_BITS_C - 1 downto ic * KERNEL_BITS_C);
            end loop;
        end loop;
        return r;
    end function;

    function to_conv4_mem(w : conv4_full_t) return conv4_mem_t is
        variable r : conv4_mem_t;
        constant KERNEL_BITS_C : integer := CONV4_PRECISION * CONV4_KERNEL_SIZE ** 2;
    begin
        for oc in 0 to CONV4_CHAN_OUTPUT - 1 loop
            for ic in 0 to CONV4_CHAN_INPUT - 1 loop
                r(oc * CONV4_CHAN_INPUT + ic) :=
                w(oc)((ic + 1) * KERNEL_BITS_C - 1 downto ic * KERNEL_BITS_C);
            end loop;
        end loop;
        return r;
    end function;

    function to_conv5_mem(w : conv5_full_t) return conv5_mem_t is
        variable r : conv5_mem_t;
        constant KERNEL_BITS_C : integer := CONV5_PRECISION * CONV5_KERNEL_SIZE ** 2;
    begin
        for oc in 0 to CONV5_CHAN_OUTPUT - 1 loop
            for ic in 0 to CONV5_CHAN_INPUT - 1 loop
                r(oc * CONV5_CHAN_INPUT + ic) :=
                w(oc)((ic + 1) * KERNEL_BITS_C - 1 downto ic * KERNEL_BITS_C);
            end loop;
        end loop;
        return r;
    end function;

end package body;