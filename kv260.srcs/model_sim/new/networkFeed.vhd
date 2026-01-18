library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;

entity networkFeed is
end entity;

architecture sim of networkFeed is
    constant WIDTH_PIXELS : integer := 128;
    constant HEIGHT_PIXELS : integer := 128;
    constant C_TDATA_W : positive := 64;
    constant C_TUSER_W : positive := 1;
    constant C_TKEEP_W : positive := C_TDATA_W/8;
    constant G_FILE : string := "../../../../eventFilter.srcs/sources_1/new/frameInputFiles/input_data.txt";
    constant O_FILE : string := "../../../../eventFilter/eventFilter.srcs/sources_1/new/networkOutput.txt";
    constant CLK_PERIOD : time := 10 ns;

    -- AXI4-Stream signals
    signal aclk : std_logic := '0';
    signal aresetn : std_logic := '0';

    -- AXIS master (TB -> DUT)
    signal s_axis_tdata : std_logic_vector(C_TDATA_W - 1 downto 0) := (others => '0');
    signal s_axis_tkeep : std_logic_vector(C_TKEEP_W - 1 downto 0) := (others => '0');
    signal s_axis_tvalid : std_logic := '0';
    signal s_axis_tready : std_logic;
    signal s_axis_tlast : std_logic := '0';
    signal s_axis_tuser : std_logic_vector(C_TUSER_W - 1 downto 0) := (others => '0');

    -- AXIS slave (DUT -> TB)
    signal m_axis_tdata : std_logic_vector(C_TDATA_W - 1 downto 0);
    signal m_axis_tkeep : std_logic_vector(C_TKEEP_W - 1 downto 0);
    signal m_axis_tvalid : std_logic;
    signal m_axis_tready : std_logic := '1';
    signal m_axis_tlast : std_logic;
    signal m_axis_tuser : std_logic_vector(C_TUSER_W - 1 downto 0);

    file inputFile : text open read_mode is G_FILE;
    file log_f : text open write_mode is O_FILE;

    -- Extract next '0'/'1' from a line, skipping separators.
    procedure next_bit(variable L : inout line; variable b : out std_logic) is
        variable ch : character;
    begin
        loop
            if L = null or L'length = 0 then
                assert false report "Ran out of bits in line" severity failure;
            end if;
            read(L, ch);
            if ch = '0' then
                b := '0';
                exit;
            elsif ch = '1' then
                b := '1';
                exit;
            else
                -- skip commas/spaces/tabs etc.
                null;
            end if;
        end loop;
    end procedure;

begin
    -- clock
    clk_p : process
    begin
        aclk <= '0';
        wait for CLK_PERIOD/2;
        aclk <= '1';
        wait for CLK_PERIOD/2;
    end process;

    -- reset
    rst_p : process
    begin
        aresetn <= '0';
        wait for 50 ns;
        aresetn <= '1';
        wait;
    end process;

    -- streamer
    stim : process
        variable L : line;
        variable b : std_logic;
        variable row : integer;
        variable col : integer;
        variable beat : std_logic_vector(63 downto 0);
    begin
        -- wait reset
        wait until aresetn = '1';
        wait until rising_edge(aclk);

        for row in 0 to HEIGHT_PIXELS - 1 loop
            readline(inputFile, L);

            -- Two 64-bit beats per row
            for col in 0 to (WIDTH_PIXELS/C_TDATA_W) - 1 loop -- 0..1
                -- pack 64 bits
                for i in 0 to C_TDATA_W - 1 loop
                    next_bit(L, b);
                    beat(C_TDATA_W - 1 - i) := b; -- beat(63)=first bit, beat(0)=last
                end loop;

                -- drive AXI beat with backpressure handling
                s_axis_tdata <= beat;
                s_axis_tvalid <= '1';

                -- Indicate tlast at the end of the frame
                if (row = HEIGHT_PIXELS - 1 and col = (WIDTH_PIXELS/C_TDATA_W) - 1) then
                    s_axis_tlast <= '1';
                else
                    s_axis_tlast <= '0';
                end if;

                -- wait for handshake
                loop
                    wait until rising_edge(aclk);
                    if s_axis_tready = '1' then
                        exit;
                    end if;
                end loop;
            end loop;
        end loop;

        -- done
        s_axis_tvalid <= '0';
        s_axis_tlast <= '0';
        wait;
    end process;

    -- DUT
    uut : entity work.spikingNetwork
        generic map(
            AXIS_TDATA_WIDTH_G => C_TDATA_W,
            AXIS_TUSER_WIDTH_G => C_TUSER_W
        )
        port map(
            aclk => aclk,
            aresetn => aresetn,
            s_axis_tready => s_axis_tready,
            s_axis_tvalid => s_axis_tvalid,
            s_axis_tdata => s_axis_tdata,
            s_axis_tkeep => s_axis_tkeep,
            s_axis_tuser => s_axis_tuser,
            s_axis_tlast => s_axis_tlast,
            m_axis_tready => m_axis_tready,
            m_axis_tvalid => m_axis_tvalid,
            m_axis_tdata => m_axis_tdata,
            m_axis_tkeep => m_axis_tkeep,
            m_axis_tuser => m_axis_tuser,
            m_axis_tlast => m_axis_tlast
        );

end architecture;