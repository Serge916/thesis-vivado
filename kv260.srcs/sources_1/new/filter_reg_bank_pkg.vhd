library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package filter_reg_bank_pkg is

    --------------------------------------
    -- Global Register Bank Definitions --
    --------------------------------------

    constant AXIL_ADDR_WIDTH : integer := 32;

    -------------------------------------
    -- Register and Fields Definitions --
    -------------------------------------

    -- CONTROL Register
    constant CONTROL_ADDR : std_logic_vector(AXIL_ADDR_WIDTH - 1 downto 0) := std_logic_vector(to_unsigned(16#00000000#, AXIL_ADDR_WIDTH));
    constant CONTROL_ENABLE_WIDTH : natural := 1;
    constant CONTROL_ENABLE_MSB : natural := 0;
    constant CONTROL_ENABLE_LSB : natural := 0;
    constant CONTROL_ENABLE_DEFAULT : std_logic_vector(CONTROL_ENABLE_WIDTH - 1 downto 0) := "0";
    constant CONTROL_GLOBAL_RESET_WIDTH : natural := 1;
    constant CONTROL_GLOBAL_RESET_MSB : natural := 1;
    constant CONTROL_GLOBAL_RESET_LSB : natural := 1;
    constant CONTROL_GLOBAL_RESET_DEFAULT : std_logic_vector(CONTROL_GLOBAL_RESET_WIDTH - 1 downto 0) := "0";
    constant CONTROL_CLEAR_WIDTH : natural := 1;
    constant CONTROL_CLEAR_MSB : natural := 2;
    constant CONTROL_CLEAR_LSB : natural := 2;
    constant CONTROL_CLEAR_DEFAULT : std_logic_vector(CONTROL_CLEAR_WIDTH - 1 downto 0) := "0";
    -- CONFIG Register
    constant CONFIG_ADDR : std_logic_vector(AXIL_ADDR_WIDTH - 1 downto 0) := std_logic_vector(to_unsigned(16#00000004#, AXIL_ADDR_WIDTH));
    constant CONFIG_RESERVED_WIDTH : natural := 1;
    constant CONFIG_RESERVED_MSB : natural := 0;
    constant CONFIG_RESERVED_LSB : natural := 0;
    constant CONFIG_TEST_PATTERN_WIDTH : natural := 1;
    constant CONFIG_TEST_PATTERN_MSB : natural := 1;
    constant CONFIG_TEST_PATTERN_LSB : natural := 1;
    constant CONFIG_TEST_PATTERN_DEFAULT : std_logic_vector(CONFIG_TEST_PATTERN_WIDTH - 1 downto 0) := "0";
    constant CONFIG_TIMEOUT_ENABLE_WIDTH : natural := 1;
    constant CONFIG_TIMEOUT_ENABLE_MSB : natural := 2;
    constant CONFIG_TIMEOUT_ENABLE_LSB : natural := 2;
    constant CONFIG_TIMEOUT_ENABLE_DEFAULT : std_logic_vector(CONFIG_TIMEOUT_ENABLE_WIDTH - 1 downto 0) := "0";
    -- VERSION Register
    constant VERSION_ADDR : std_logic_vector(AXIL_ADDR_WIDTH - 1 downto 0) := std_logic_vector(to_unsigned(16#00000020#, AXIL_ADDR_WIDTH));
    constant VERSION_MINOR_WIDTH : natural := 16;
    constant VERSION_MINOR_MSB : natural := 15;
    constant VERSION_MINOR_LSB : natural := 0;
    constant VERSION_MAJOR_WIDTH : natural := 16;
    constant VERSION_MAJOR_MSB : natural := 31;
    constant VERSION_MAJOR_LSB : natural := 16;

    -- DECAY_COUNTER_LIMIT Register
    constant DECAY_COUNTER_LIMIT_ADDR : std_logic_vector(AXIL_ADDR_WIDTH - 1 downto 0) := std_logic_vector(to_unsigned(16#00000008#, AXIL_ADDR_WIDTH));
    constant DECAY_COUNTER_LIMIT_WIDTH : natural := 32;
    constant DECAY_COUNTER_LIMIT_MSB : natural := 31;
    constant DECAY_COUNTER_LIMIT_LSB : natural := 0;
    constant DECAY_COUNTER_LIMIT_DEFAULT : std_logic_vector(DECAY_COUNTER_LIMIT_WIDTH - 1 downto 0) := x"00989680";
    -- SPIKE_ACCUMULATION_LIMIT Register
    constant SPIKE_ACCUMULATION_LIMIT_ADDR : std_logic_vector(AXIL_ADDR_WIDTH - 1 downto 0) := std_logic_vector(to_unsigned(16#0000000C#, AXIL_ADDR_WIDTH));
    constant SPIKE_ACCUMULATION_LIMIT_WIDTH : natural := 32;
    constant SPIKE_ACCUMULATION_LIMIT_MSB : natural := 31;
    constant SPIKE_ACCUMULATION_LIMIT_LSB : natural := 0;
    constant SPIKE_ACCUMULATION_LIMIT_DEFAULT : std_logic_vector(SPIKE_ACCUMULATION_LIMIT_WIDTH - 1 downto 0) := x"00000320";
    -- EXCITATION_FACTOR Register
    constant EXCITATION_FACTOR_ADDR : std_logic_vector(AXIL_ADDR_WIDTH - 1 downto 0) := std_logic_vector(to_unsigned(16#00000010#, AXIL_ADDR_WIDTH));
    constant EXCITATION_FACTOR_WIDTH : natural := 32;
    constant EXCITATION_FACTOR_MSB : natural := 31;
    constant EXCITATION_FACTOR_LSB : natural := 0;
    constant EXCITATION_FACTOR_DEFAULT : std_logic_vector(EXCITATION_FACTOR_WIDTH - 1 downto 0) := x"00000001";
end filter_reg_bank_pkg;

---------------------
-- Empty Package Body
package body filter_reg_bank_pkg is
end package body;