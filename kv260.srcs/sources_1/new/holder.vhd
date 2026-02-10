library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity axis_event_spacer is
    generic (
        G_TDATA_W : positive := 64;
        G_TUSER_W : positive := 1;
        -- clock cycles per timestamp tick (1us @125MHz => 125)
        G_TS_UNIT_CYCLES : positive := 125
    );
    port (
        aclk : in std_logic;
        aresetn : in std_logic;

        -- AXI4-Stream input
        s_axis_tdata : in std_logic_vector(G_TDATA_W - 1 downto 0);
        s_axis_tkeep : in std_logic_vector((G_TDATA_W/8) - 1 downto 0);
        s_axis_tvalid : in std_logic;
        s_axis_tready : out std_logic;
        s_axis_tlast : in std_logic;
        s_axis_tuser : in std_logic_vector(G_TUSER_W - 1 downto 0);

        -- AXI4-Stream output
        m_axis_tdata : out std_logic_vector(G_TDATA_W - 1 downto 0);
        m_axis_tkeep : out std_logic_vector((G_TDATA_W/8) - 1 downto 0);
        m_axis_tvalid : out std_logic;
        m_axis_tready : in std_logic;
        m_axis_tlast : out std_logic;
        m_axis_tuser : out std_logic_vector(G_TUSER_W - 1 downto 0)
    );
end entity;

architecture rtl of axis_event_spacer is
    constant C_TKEEP_W : positive := G_TDATA_W/8;

    -- timestamp recon
    signal time_high28 : unsigned(27 downto 0) := (others => '0');
    signal prev_ts : unsigned(33 downto 0) := (others => '0');
    signal first_event : std_logic := '1';

    -- one-beat holding regs (skid buffer)
    signal hold_data : std_logic_vector(G_TDATA_W - 1 downto 0) := (others => '0');
    signal hold_keep : std_logic_vector(C_TKEEP_W - 1 downto 0) := (others => '0');
    signal hold_user : std_logic_vector(G_TUSER_W - 1 downto 0) := (others => '0');
    signal hold_last : std_logic := '0';
    signal hold_valid : std_logic := '0';
    signal slave_ready : std_logic := '0';

    -- wait counter (cycles)
    signal wait_cnt : unsigned(63 downto 0) := (others => '0');

    type t_state is (ST_IDLE, ST_WAIT, ST_SEND);
    signal st : t_state := ST_IDLE;

    -- handshake helpers
    signal out_fire : std_logic;
    signal in_fire : std_logic;

    -- endianess swap
    signal in_data_sw : std_logic_vector(G_TDATA_W - 1 downto 0);

    function f_rev_bytes(d : std_logic_vector) return std_logic_vector is
        constant W : natural := d'length;
        constant B : natural := W/8;
        variable r : std_logic_vector(W - 1 downto 0);
    begin
        -- reverse byte lanes: byte i <-> byte (B-1-i)
        for i in 0 to B - 1 loop
            r((i + 1) * 8 - 1 downto i * 8) := d((B - i) * 8 - 1 downto (B - 1 - i) * 8);
        end loop;
        return r;
    end function;

    function f_rev_keep(k : std_logic_vector) return std_logic_vector is
        constant B : natural := k'length;
        variable r : std_logic_vector(B - 1 downto 0);
    begin
        for i in 0 to B - 1 loop
            r(i) := k(B - 1 - i);
        end loop;
        return r;
    end function;

begin
    in_data_sw <= f_rev_bytes(s_axis_tdata);
    m_axis_tdata <= hold_data;
    m_axis_tkeep <= hold_keep;
    m_axis_tuser <= hold_user;
    m_axis_tlast <= hold_last;
    m_axis_tvalid <= hold_valid;
    s_axis_tready <= slave_ready;

    out_fire <= hold_valid and m_axis_tready;
    in_fire <= s_axis_tvalid and slave_ready;

    -- Ready when we're able to accept a new beat.
    -- With no FIFO, we accept only in ST_IDLE (empty) and only when not already holding a beat.
    slave_ready <= '1' when (st = ST_IDLE and hold_valid = '0') else
        '0';

    process (aclk)
        variable hdr4 : std_logic_vector(3 downto 0);
        variable low6 : unsigned(5 downto 0);
        variable ts : unsigned(33 downto 0);
        variable dt : unsigned(33 downto 0);
        variable cycles : unsigned(63 downto 0);
    begin
        if rising_edge(aclk) then
            if aresetn = '0' then
                time_high28 <= (others => '0');
                prev_ts <= (others => '0');
                first_event <= '1';

                hold_data <= (others => '0');
                hold_keep <= (others => '0');
                hold_user <= (others => '0');
                hold_last <= '0';
                hold_valid <= '0';

                wait_cnt <= (others => '0');
                st <= ST_IDLE;

            else
                case st is

                    when ST_IDLE =>
                        -- capture one incoming beat
                        if in_fire = '1' then
                            hold_data <= f_rev_bytes(s_axis_tdata);
                            hold_keep <= f_rev_keep(s_axis_tkeep);
                            hold_user <= s_axis_tuser;
                            hold_last <= s_axis_tlast;
                            hold_valid <= '1';

                            hdr4 := in_data_sw(G_TDATA_W - 1 downto G_TDATA_W - 4);

                            if hdr4 = x"8" then
                                -- TIME HIGH: update & forward immediately (no extra spacing)
                                time_high28 <= unsigned(s_axis_tdata(59 downto 32));
                                wait_cnt <= (others => '0');
                                st <= ST_SEND;
                            else
                                -- NORMAL EVENT: compute spacing from timestamp
                                low6 := unsigned(s_axis_tdata(59 downto 54));
                                ts := (resize(time_high28, 34) sll 6) or resize(low6, 34);

                                if first_event = '1' then
                                    first_event <= '0';
                                    prev_ts <= ts;
                                    wait_cnt <= (others => '0');
                                    st <= ST_SEND;
                                else
                                    if ts >= prev_ts then
                                        dt := ts - prev_ts;
                                    else
                                        dt := (others => '0'); -- clamp non-monotonic to 0 delay
                                    end if;
                                    prev_ts <= ts;

                                    cycles := resize(resize(dt, 64) * to_unsigned(G_TS_UNIT_CYCLES, 64), 64);
                                    wait_cnt <= cycles;

                                    if cycles = 0 then
                                        st <= ST_SEND;
                                    else
                                        st <= ST_WAIT;
                                    end if;
                                end if;
                            end if;
                        end if;

                    when ST_WAIT =>
                        -- count down delay; keep hold_valid asserted but do NOT send yet
                        if wait_cnt = 0 then
                            st <= ST_SEND;
                        else
                            wait_cnt <= wait_cnt - 1;
                        end if;

                    when ST_SEND =>
                        -- present held beat until accepted
                        if out_fire = '1' then
                            hold_valid <= '0';
                            st <= ST_IDLE;
                        end if;

                end case;
            end if;
        end if;
    end process;

end architecture;