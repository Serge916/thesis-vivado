library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package network_reg_bank_pkg is

    --------------------------------------
    -- Global Register Bank Definitions --
    --------------------------------------

    constant AXIL_ADDR_WIDTH : integer := 32;

    -------------------------------------
    -- Register and Fields Definitions --
    -------------------------------------

    -- Trigger execution
    -- Reg to check clock cycles spent
    -- Signals to reset all the blocks
    -- Reg to read the class
    -- Interrupt to signal a ready

    -- CONTROL Register
    constant CONTROL_ADDR : std_logic_vector(AXIL_ADDR_WIDTH - 1 downto 0) := std_logic_vector(to_unsigned(16#00000000#, AXIL_ADDR_WIDTH));
    constant CONTROL_ENABLE_WIDTH : natural := 1;
    constant CONTROL_ENABLE_MSB : natural := 0;
    constant CONTROL_ENABLE_LSB : natural := 0;
    constant CONTROL_ENABLE_DEFAULT : std_logic_vector(CONTROL_ENABLE_WIDTH - 1 downto 0) := "0";
    constant LOAD_MODE_WIDTH : natural := 1;
    constant LOAD_MODE_MSB : natural := 1;
    constant LOAD_MODE_LSB : natural := 1;
    constant LOAD_MODE_DEFAULT : std_logic_vector(LOAD_MODE_WIDTH - 1 downto 0) := "0";
    constant SOFT_RESET_WIDTH : natural := 1;
    constant SOFT_RESET_MSB : natural := 3;
    constant SOFT_RESET_LSB : natural := 3;
    constant SOFT_RESET_DEFAULT : std_logic_vector(SOFT_RESET_WIDTH - 1 downto 0) := "1";
    -- Status Register
    constant STATUS_ADDR : std_logic_vector(AXIL_ADDR_WIDTH - 1 downto 0) := std_logic_vector(to_unsigned(16#00000004#, AXIL_ADDR_WIDTH));
    constant ENABLE_OPERATION_WIDTH : natural := 1;
    constant ENABLE_OPERATION_MSB : natural := 0;
    constant ENABLE_OPERATION_LSB : natural := 0;
    -- RESULT_CLASS Register
    constant RESULT_CLASS_ADDR : std_logic_vector(AXIL_ADDR_WIDTH - 1 downto 0) := std_logic_vector(to_unsigned(16#00000008#, AXIL_ADDR_WIDTH));
    constant RESULT_CLASS_WIDTH : natural := 32;
    constant RESULT_CLASS_MSB : natural := 31;
    constant RESULT_CLASS_LSB : natural := 0;
    constant RESULT_CLASS_DEFAULT : std_logic_vector(RESULT_CLASS_WIDTH - 1 downto 0) := x"FFFFFFFF";
    -- INFERENCE_TIME Register
    constant INFERENCE_TIME_ADDR : std_logic_vector(AXIL_ADDR_WIDTH - 1 downto 0) := std_logic_vector(to_unsigned(16#0000000C#, AXIL_ADDR_WIDTH));
    constant INFERENCE_TIME_WIDTH : natural := 32;
    constant INFERENCE_TIME_MSB : natural := 31;
    constant INFERENCE_TIME_LSB : natural := 0;
    constant INFERENCE_TIME_DEFAULT : std_logic_vector(INFERENCE_TIME_WIDTH - 1 downto 0) := x"00000000";
    -- Layer Registers and Offsets
    constant CONTROL_OFFSET : unsigned(AXIL_ADDR_WIDTH - 1 downto 0) := to_unsigned(16#00000000#, AXIL_ADDR_WIDTH);
    constant STATUS_OFFSET : unsigned(AXIL_ADDR_WIDTH - 1 downto 0) := to_unsigned(16#00000004#, AXIL_ADDR_WIDTH);
    constant MEM_DEPTH_OFFSET : unsigned(AXIL_ADDR_WIDTH - 1 downto 0) := to_unsigned(16#00000008#, AXIL_ADDR_WIDTH);
    -- One register holds the target address, the rest hold the different parts of the word
    constant KERNEL_OFFSET : unsigned(AXIL_ADDR_WIDTH - 1 downto 0) := to_unsigned(16#00000010#, AXIL_ADDR_WIDTH);
    constant KERNEL_WORD0_OFFSET : unsigned(AXIL_ADDR_WIDTH - 1 downto 0) := to_unsigned(16#00000014#, AXIL_ADDR_WIDTH);
    constant KERNEL_WORD1_OFFSET : unsigned(AXIL_ADDR_WIDTH - 1 downto 0) := to_unsigned(16#00000018#, AXIL_ADDR_WIDTH);
    constant KERNEL_WORD2_OFFSET : unsigned(AXIL_ADDR_WIDTH - 1 downto 0) := to_unsigned(16#0000001C#, AXIL_ADDR_WIDTH);
    -- Base addresses per layer
    constant CONV1_BASE_ADDR : unsigned(AXIL_ADDR_WIDTH - 1 downto 0) := to_unsigned(16#00000100#, AXIL_ADDR_WIDTH);
    constant CONV2_BASE_ADDR : unsigned(AXIL_ADDR_WIDTH - 1 downto 0) := to_unsigned(16#00000120#, AXIL_ADDR_WIDTH);
    constant CONV3_BASE_ADDR : unsigned(AXIL_ADDR_WIDTH - 1 downto 0) := to_unsigned(16#00000140#, AXIL_ADDR_WIDTH);
    constant CONV4_BASE_ADDR : unsigned(AXIL_ADDR_WIDTH - 1 downto 0) := to_unsigned(16#00000160#, AXIL_ADDR_WIDTH);
    constant CONV5_BASE_ADDR : unsigned(AXIL_ADDR_WIDTH - 1 downto 0) := to_unsigned(16#00000180#, AXIL_ADDR_WIDTH);
    -- Signal indexes
    -- Layer Control Register
    constant COMMIT_WORD_WIDTH : natural := 1;
    constant COMMIT_WORD_MSB : natural := 0;
    constant COMMIT_WORD_LSB : natural := 0;
    constant COMMIT_WORD_DEFAULT : std_logic_vector(COMMIT_WORD_WIDTH - 1 downto 0) := "0";
    -- Other Registers
    constant MEM_DEPTH_WIDTH : natural := 32;
    constant MEM_DEPTH_MSB : natural := 31;
    constant MEM_DEPTH_LSB : natural := 0;
    -- Final Addresses
    -- Conv1
    constant CONV1_CONTROL_ADDR : std_logic_vector(AXIL_ADDR_WIDTH - 1 downto 0) := std_logic_vector(CONV1_BASE_ADDR + CONTROL_OFFSET);
    constant CONV1_STATUS_ADDR : std_logic_vector(AXIL_ADDR_WIDTH - 1 downto 0) := std_logic_vector(CONV1_BASE_ADDR + STATUS_OFFSET);
    constant CONV1_MEM_DEPTH_ADDR : std_logic_vector(AXIL_ADDR_WIDTH - 1 downto 0) := std_logic_vector(CONV1_BASE_ADDR + MEM_DEPTH_OFFSET);
    constant CONV1_KERNEL_ADDR : std_logic_vector(AXIL_ADDR_WIDTH - 1 downto 0) := std_logic_vector(CONV1_BASE_ADDR + KERNEL_OFFSET);
    constant CONV1_KERNEL_WORD0_ADDR : std_logic_vector(AXIL_ADDR_WIDTH - 1 downto 0) := std_logic_vector(CONV1_BASE_ADDR + KERNEL_WORD0_OFFSET);
    constant CONV1_KERNEL_WORD1_ADDR : std_logic_vector(AXIL_ADDR_WIDTH - 1 downto 0) := std_logic_vector(CONV1_BASE_ADDR + KERNEL_WORD1_OFFSET);
    constant CONV1_KERNEL_WORD2_ADDR : std_logic_vector(AXIL_ADDR_WIDTH - 1 downto 0) := std_logic_vector(CONV1_BASE_ADDR + KERNEL_WORD2_OFFSET);
    -- Conv2
    constant CONV2_CONTROL_ADDR : std_logic_vector(AXIL_ADDR_WIDTH - 1 downto 0) := std_logic_vector(CONV2_BASE_ADDR + CONTROL_OFFSET);
    constant CONV2_STATUS_ADDR : std_logic_vector(AXIL_ADDR_WIDTH - 1 downto 0) := std_logic_vector(CONV2_BASE_ADDR + STATUS_OFFSET);
    constant CONV2_MEM_DEPTH_ADDR : std_logic_vector(AXIL_ADDR_WIDTH - 1 downto 0) := std_logic_vector(CONV2_BASE_ADDR + MEM_DEPTH_OFFSET);
    constant CONV2_KERNEL_ADDR : std_logic_vector(AXIL_ADDR_WIDTH - 1 downto 0) := std_logic_vector(CONV2_BASE_ADDR + KERNEL_OFFSET);
    constant CONV2_KERNEL_WORD0_ADDR : std_logic_vector(AXIL_ADDR_WIDTH - 1 downto 0) := std_logic_vector(CONV2_BASE_ADDR + KERNEL_WORD0_OFFSET);
    constant CONV2_KERNEL_WORD1_ADDR : std_logic_vector(AXIL_ADDR_WIDTH - 1 downto 0) := std_logic_vector(CONV2_BASE_ADDR + KERNEL_WORD1_OFFSET);
    constant CONV2_KERNEL_WORD2_ADDR : std_logic_vector(AXIL_ADDR_WIDTH - 1 downto 0) := std_logic_vector(CONV2_BASE_ADDR + KERNEL_WORD2_OFFSET);
    -- Conv3
    constant CONV3_CONTROL_ADDR : std_logic_vector(AXIL_ADDR_WIDTH - 1 downto 0) := std_logic_vector(CONV3_BASE_ADDR + CONTROL_OFFSET);
    constant CONV3_STATUS_ADDR : std_logic_vector(AXIL_ADDR_WIDTH - 1 downto 0) := std_logic_vector(CONV3_BASE_ADDR + STATUS_OFFSET);
    constant CONV3_MEM_DEPTH_ADDR : std_logic_vector(AXIL_ADDR_WIDTH - 1 downto 0) := std_logic_vector(CONV3_BASE_ADDR + MEM_DEPTH_OFFSET);
    constant CONV3_KERNEL_ADDR : std_logic_vector(AXIL_ADDR_WIDTH - 1 downto 0) := std_logic_vector(CONV3_BASE_ADDR + KERNEL_OFFSET);
    constant CONV3_KERNEL_WORD0_ADDR : std_logic_vector(AXIL_ADDR_WIDTH - 1 downto 0) := std_logic_vector(CONV3_BASE_ADDR + KERNEL_WORD0_OFFSET);
    constant CONV3_KERNEL_WORD1_ADDR : std_logic_vector(AXIL_ADDR_WIDTH - 1 downto 0) := std_logic_vector(CONV3_BASE_ADDR + KERNEL_WORD1_OFFSET);
    constant CONV3_KERNEL_WORD2_ADDR : std_logic_vector(AXIL_ADDR_WIDTH - 1 downto 0) := std_logic_vector(CONV3_BASE_ADDR + KERNEL_WORD2_OFFSET);
    -- Conv4
    constant CONV4_CONTROL_ADDR : std_logic_vector(AXIL_ADDR_WIDTH - 1 downto 0) := std_logic_vector(CONV4_BASE_ADDR + CONTROL_OFFSET);
    constant CONV4_STATUS_ADDR : std_logic_vector(AXIL_ADDR_WIDTH - 1 downto 0) := std_logic_vector(CONV4_BASE_ADDR + STATUS_OFFSET);
    constant CONV4_MEM_DEPTH_ADDR : std_logic_vector(AXIL_ADDR_WIDTH - 1 downto 0) := std_logic_vector(CONV4_BASE_ADDR + MEM_DEPTH_OFFSET);
    constant CONV4_KERNEL_ADDR : std_logic_vector(AXIL_ADDR_WIDTH - 1 downto 0) := std_logic_vector(CONV4_BASE_ADDR + KERNEL_OFFSET);
    constant CONV4_KERNEL_WORD0_ADDR : std_logic_vector(AXIL_ADDR_WIDTH - 1 downto 0) := std_logic_vector(CONV4_BASE_ADDR + KERNEL_WORD0_OFFSET);
    constant CONV4_KERNEL_WORD1_ADDR : std_logic_vector(AXIL_ADDR_WIDTH - 1 downto 0) := std_logic_vector(CONV4_BASE_ADDR + KERNEL_WORD1_OFFSET);
    constant CONV4_KERNEL_WORD2_ADDR : std_logic_vector(AXIL_ADDR_WIDTH - 1 downto 0) := std_logic_vector(CONV4_BASE_ADDR + KERNEL_WORD2_OFFSET);
    -- Conv5
    constant CONV5_CONTROL_ADDR : std_logic_vector(AXIL_ADDR_WIDTH - 1 downto 0) := std_logic_vector(CONV5_BASE_ADDR + CONTROL_OFFSET);
    constant CONV5_STATUS_ADDR : std_logic_vector(AXIL_ADDR_WIDTH - 1 downto 0) := std_logic_vector(CONV5_BASE_ADDR + STATUS_OFFSET);
    constant CONV5_MEM_DEPTH_ADDR : std_logic_vector(AXIL_ADDR_WIDTH - 1 downto 0) := std_logic_vector(CONV5_BASE_ADDR + MEM_DEPTH_OFFSET);
    constant CONV5_KERNEL_ADDR : std_logic_vector(AXIL_ADDR_WIDTH - 1 downto 0) := std_logic_vector(CONV5_BASE_ADDR + KERNEL_OFFSET);
    constant CONV5_KERNEL_WORD0_ADDR : std_logic_vector(AXIL_ADDR_WIDTH - 1 downto 0) := std_logic_vector(CONV5_BASE_ADDR + KERNEL_WORD0_OFFSET);
    constant CONV5_KERNEL_WORD1_ADDR : std_logic_vector(AXIL_ADDR_WIDTH - 1 downto 0) := std_logic_vector(CONV5_BASE_ADDR + KERNEL_WORD1_OFFSET);
    constant CONV5_KERNEL_WORD2_ADDR : std_logic_vector(AXIL_ADDR_WIDTH - 1 downto 0) := std_logic_vector(CONV5_BASE_ADDR + KERNEL_WORD2_OFFSET);
end network_reg_bank_pkg;

---------------------
-- Empty Package Body
package body network_reg_bank_pkg is
end package body;