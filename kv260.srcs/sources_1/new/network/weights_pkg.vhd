library ieee;
use ieee.std_logic_1164.all;
use ieee.math_real.all;

package weights_pkg is

    -- constant CONV1_SIZE : integer := 64;
    constant CONV1_CHAN_INPUT : positive := 2;
    constant CONV1_CHAN_OUTPUT : positive := 32; -- Output 3rd dimension
    constant CONV1_ADDR_WIDTH_C : positive := integer(ceil(log2(real(CONV1_CHAN_OUTPUT))));
    constant CONV1_CHAN_WIDTH_C : positive := integer(ceil(log2(real(CONV1_CHAN_INPUT))));
    constant CONV1_KERNEL_SIZE : positive := 3;
    constant CONV1_PRECISION : positive := 8;
    constant CONV1_ACCUM_WIDTH_C : positive := integer(ceil(log2(real((2 ** CONV1_PRECISION) * 9)))); -- Biggest value if all 9 kernel are max value and spiked
    constant CONV1_INTERMEDIATE_WIDTH_C : positive := integer(ceil(log2(real((2 ** CONV1_PRECISION) * 9 * CONV1_CHAN_INPUT)))); -- Biggest value if all channels were at max
    constant CONV1_FRAME_WIDTH : positive := 128;
    constant CONV1_FRAME_HEIGHT : positive := 128;

    type conv1_mem_t is array (0 to CONV1_CHAN_OUTPUT - 1) of std_logic_vector(CONV1_CHAN_INPUT * CONV1_PRECISION * CONV1_KERNEL_SIZE ** 2 - 1 downto 0);
    constant CONV1_WEIGHTS : conv1_mem_t := (
        0 => x"08A701EED2B3F3FE08" & x"02FC3901D5DBD9CBF8",
        1 => x"0727101D3408E60DD4" & x"401DEBFA4E1E1D202B",
        2 => x"DA01FC1FF3DA0C32D2" & x"EBEBDBEDFCC3D0EAE5",
        3 => x"FA5405350C05F22019" & x"10E9D100F80EF31A32",
        4 => x"BA0CBA2F4B3F36062B" & x"80F6D1412716E4DC11",
        5 => x"F59F97E1C0D1B5B9C3" & x"44314A372B494C2A33",
        6 => x"5650FE49282A3C490F" & x"060EE900E5E90EDEE6",
        7 => x"334E1E1E1F403E3830" & x"E5C8FAD1F6BACAFCF0",
        8 => x"EC19ECDDFD0D051AD7" & x"EA0534F91BE531FE26",
        9 => x"0525960825CD4303F4" & x"D81EC93B67EA56EAE6",
        10 => x"F510CBB71C06D41114" & x"C5FCDEC30833CB431B",
        11 => x"40F807D7C803A12D28" & x"FC14090A21DFB41022",
        12 => x"153A240E1B21E84E07" & x"C6C328CCC9BDB0EFF6",
        13 => x"220DF80D121D0AF7E7" & x"07FCF1E808F8EAE514",
        14 => x"04BB223CDA49051947" & x"24E6001FC4EBFADF17",
        15 => x"4AFB2745E841111BFA" & x"2D2B59724E627F3E3A",
        16 => x"15FFD9F6E9DBE3ECEE" & x"0F46234036213F3D0C",
        17 => x"EE9F35A1A3EBC0CCD3" & x"452355170D2D2A0912",
        18 => x"05C1BEAD01CAE6F60C" & x"34F1DBA436FC9E1B29",
        19 => x"384A1D46223D2C1F1C" & x"35E7DAE791E808D8D9",
        20 => x"0346FA0FECF60F4223" & x"133C2D4A612C5C651E",
        21 => x"F5CD7FD0C37ABF113E" & x"01D436BAE427A2392C",
        22 => x"CAEFEB93B1E8808AD6" & x"DB2B3900C20ACAFCD7",
        23 => x"4C42DB25CCCEF71BB6" & x"38EFD8EEE2C4CCD98C",
        24 => x"23E4D2F21C1A0017B7" & x"24F1F027500D0F23D6",
        25 => x"E34E1C0D32F20428F0" & x"E5F9CEED25D3C8F3F3",
        26 => x"5E0A0207ECE6E52402" & x"FE0AD5EB2721E64126",
        27 => x"0E6CFBBD15D6DFEDB0" & x"400AFDC2041ADF27E5",
        28 => x"FA003CED3620FAC3E5" & x"EFF010D52D16F20406",
        29 => x"8580C8B7C3E6B30023" & x"99F6F119D7AFEFE726",
        30 => x"C900CEF1B9DF18090D" & x"EAF33D3CFC314802F7",
        31 => x"1026F91234272820E5" & x"0C24EC142A181325F9"
    );

end package;

package body weights_pkg is
end package body;