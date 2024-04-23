-- cpu.vhd: Simple 8-bit CPU (BrainFuck interpreter)
-- Copyright (C) 2023 Brno University of Technology,
--                    Faculty of Information Technology
-- Author(s): Filip Botlo <xbotlo01@stud.fit.vutbr.cz>
--
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

-- ----------------------------------------------------------------------------
--                        Entity declaration
-- ----------------------------------------------------------------------------
entity cpu is
 port (
   CLK   : in std_logic;  -- hodinovy signal
   RESET : in std_logic;  -- asynchronni reset procesoru
   EN    : in std_logic;  -- povoleni cinnosti procesoru
 
   -- synchronni pamet RAM
   DATA_ADDR  : out std_logic_vector(12 downto 0); -- adresa do pameti
   DATA_WDATA : out std_logic_vector(7 downto 0); -- mem[DATA_ADDR] <- DATA_WDATA pokud DATA_EN='1'
   DATA_RDATA : in std_logic_vector(7 downto 0);  -- DATA_RDATA <- ram[DATA_ADDR] pokud DATA_EN='1'
   DATA_RDWR  : out std_logic;                    -- cteni (0) / zapis (1)
   DATA_EN    : out std_logic;                    -- povoleni cinnosti
   
   -- vstupni port
   IN_DATA   : in std_logic_vector(7 downto 0);   -- IN_DATA <- stav klavesnice pokud IN_VLD='1' a IN_REQ='1'
   IN_VLD    : in std_logic;                      -- data platna
   IN_REQ    : out std_logic;                     -- pozadavek na vstup data
   
   -- vystupni port
   OUT_DATA : out  std_logic_vector(7 downto 0);  -- zapisovana data
   OUT_BUSY : in std_logic;                       -- LCD je zaneprazdnen (1), nelze zapisovat
   OUT_WE   : out std_logic;                      -- LCD <- OUT_DATA pokud OUT_WE='1' a OUT_BUSY='0'

   -- stavove signaly
   READY    : out std_logic;                      -- hodnota 1 znamena, ze byl procesor inicializovan a zacina vykonavat program
   DONE     : out std_logic                       -- hodnota 1 znamena, ze procesor ukoncil vykonavani programu (narazil na instrukci halt)
 );
end cpu;


architecture behavioral of cpu is
  
-- FSM stavy (FSM States)
type fsm_state is (
  s_start,
  s_fetch,
  s_ready,
  s_init, 
  s_decode,
  s_done,
  s_ptr_up,
  s_ptr_down,
  s_val_up,
  s_val_up2,
  s_val_up3,
  s_val_down,
  s_val_down2,
  s_print,
  s_print2,
  s_print3,
  s_read,
  s_read2,
  s_read3,
  s_while_start,
  s_while_end,
  break,
  chill
);

  
signal state    :  fsm_state := s_start;
signal n_state  :  fsm_state;

-- Signaly (Signals)
  signal PC: std_logic_vector(12 downto 0);
  signal PTR: std_logic_vector(12 downto 0);
  signal CNT: std_logic_vector(7 downto 0);


  signal pc_inc, pc_dec: std_logic;
  signal ptr_inc, ptr_dec: std_logic;
  signal cnt_inc, cnt_dec: std_logic;

  signal mux1 : std_logic;
  signal mux2: std_logic_vector(1 downto 0);

begin

-- Proces pre registre (Register Process)
  registers: process(CLK, RESET)
  begin
      if RESET = '1' then
          PC <= (others => '0');
          PTR <= (others => '0');
      elsif rising_edge(CLK) then
          if pc_inc = '1' then
              PC <= PC + 1;
          elsif pc_dec = '1' then
              PC <= PC - 1;
          end if;
          
          if ptr_inc = '1' then
              PTR <= PTR + 1;
          elsif ptr_dec = '1' then
              PTR <= PTR - 1;
          end if;
      end if;
  end process;


  cnt_reg: process(CLK, RESET)
  begin
    if RESET = '1' then
      CNT <= "00000000";
    elsif rising_edge(CLK) then
      if cnt_inc = '1' then
        CNT <= CNT + 1;
      elsif cnt_dec = '1' then
        CNT <= CNT - 1;
      end if;    
    end if;
  end process;
    
  with mux1 select
	DATA_ADDR <= PC when '0',
			PTR when '1',
			(others => '0') when others;

  with mux2 select
    DATA_WDATA <= IN_DATA when "00",
        (DATA_RDATA - 1) when "01",
        (DATA_RDATA + 1) when "10",
        (others => '0') when others;

-- Proces pre riadenie stavoveho automatu (State Machine Process)
 state_machine: process(CLK, RESET, EN)
 begin
   if RESET = '1' then
     state <= s_start;
   elsif rising_edge(CLK) and EN = '1' then
     state <= n_state ;
   end if;
 end process;


 fsm_n_state : process (state, OUT_BUSY, IN_VLD, DATA_RDATA, CNT)
begin
    -- Inicializacia signalov
    DATA_RDWR <= '0'; 
    ptr_inc <= '0';
    ptr_dec <= '0';
    pc_inc <= '0';
    pc_dec <= '0';
    IN_REQ <= '0';
    OUT_WE <= '0';
    DATA_EN   <= '1';
    OUT_DATA  <= X"00";

    case state is 
        -- Zaciatocny stav
        when s_start =>
            READY <= '0';
            DONE <= '0';
            mux1 <= '1';    
            DATA_EN <= '1';
            n_state <= s_init;

        -- Inicializacny stav
        when  s_init =>
            ptr_inc <= '1';
            if DATA_RDATA = X"40" then
                n_state  <= s_ready;
            else
                n_state  <= s_start;  
            end if;

        -- Stav pripravenosti
        when s_ready =>
            READY <= '1';
            n_state  <= s_fetch;  

        -- Stav nacitania dat
        when s_fetch =>
            mux1  <= '0';
            n_state  <= s_decode;

        -- Dekodovanie prijatych dat
        when s_decode =>
            case DATA_RDATA is
                when X"3E" =>
                 n_state  <= s_ptr_up; -- Prikaz pre inkrementaciu ukazovatela
                when X"3C" =>
                 n_state  <= s_ptr_down; -- Prikaz pre dekrementaciu ukazovatela
                when X"2B" =>
                 n_state  <= s_val_up; -- Prikaz pre zvysenie hodnoty
                when X"2D" =>
                 n_state  <= s_val_down; -- Prikaz pre znizenie hodnoty
                when X"2E" =>
                 n_state  <= s_print; -- Prikaz pre vypis
                when X"2C" =>
                 n_state  <= s_read; -- Prikaz pre citanie
                when X"5B" =>
                 n_state <= s_while_start; -- Zaciatok while cyklu
                when X"5D" => 
                 n_state <= s_while_end; -- Koniec while cyklu
                when X"40" =>
                 n_state  <= s_done; -- Koncovy stav
                when others => n_state  <= chill; -- Neznamy prikaz, prestavka
            end case;


        when chill => 
            pc_inc <='1'; -- Inkrementuje programovy citac
            n_state <= s_fetch; -- Prechod do stavu nacitania
        
        when s_ptr_up=>
            ptr_inc <='1'; -- Inkrementuje ukazovatel
            pc_inc <= '1'; -- Inkrementuje programovy citac
            n_state <= s_fetch; -- Prechod do stavu nacitania
        
        when s_ptr_down =>
            ptr_dec <= '1'; -- Dekrementuje ukazovatel
            pc_inc <= '1'; -- Inkrementuje programovy citac
            n_state <= s_fetch; -- Prechod do stavu nacitania
        
        when s_val_up =>
            mux1 <= '1'; -- Nastavi multiplexor
            n_state <= s_val_up2; -- Prechod do dalsieho stavu pre zvysenie hodnoty
        
        when s_val_up2 =>
            mux2 <= "10"; -- Nastavi operaciu inkrementacie
            DATA_RDWR <= '1'; -- Povoli zapis/ctenie
            pc_inc <= '1'; -- Inkrementuje programovy citac
            n_state <= s_fetch; -- Prechod do stavu nacitania
        
        when s_val_down=>
            mux1 <= '1'; -- Nastavi multiplexor
            n_state <= s_val_down2; -- Prechod do dalsieho stavu pre znizenie hodnoty
        
        when s_val_down2 =>
            mux2 <= "01"; -- Nastavi operaciu dekrementacie
            DATA_RDWR <= '1'; -- Povoli zapis/ctenie
            pc_inc <= '1'; -- Inkrementuje programovy citac
            n_state <= s_fetch; -- Prechod do stavu nacitania
        
        when s_print =>
            mux1 <= '1'; -- Nastavi multiplexor
            DATA_EN <= '1'; -- Povoli manipulaciu s datami
            DATA_RDWR <= '0'; -- Nastavi mod len na citanie
            if OUT_BUSY = '0' then
                n_state <= s_print2; -- Ak vystup nie je zaneprazdneny, prechod do dalsieho stavu
            else
                n_state <= s_print; -- Inak zostava v tomto stave
            end if;
        
        when s_print2 =>
            OUT_DATA <= DATA_RDATA; -- Vystupne data sa rovnaju citanym datam
            OUT_WE <= '1'; -- Povoli zapis na vystup
            n_state <= s_print3; -- Prechod do dalsieho stavu
        
        when s_print3 =>
            OUT_WE <= '0'; -- Zakaze zapis na vystup
            pc_inc <= '1'; -- Inkrementuje programovy citac
            n_state <= s_fetch; -- Prechod do stavu nacitania
        
        when s_read =>
            IN_REQ <= '1'; -- Vyzaduje vstupne data
            if (IN_VLD = '1') then
                n_state <= s_read2; -- Ak su vstupne data platne, prechod do dalsieho stavu
            else
                n_state <= s_read; -- Inak zostava v tomto stave
            end if;
        
        when s_read2 =>
            PC_INC <= '1'; -- Inkrementuje programovy citac
            mux1 <= '1'; -- Nastavi multiplexor
            mux2 <= "00"; -- Nastavi operaciu pre citanie vstupnych dat
            DATA_RDWR <= '1'; -- Povoli zapis/ctenie
            DATA_EN <= '1'; -- Povoli manipulaciu s datami
            n_state <= s_fetch; -- Prechod do stavu nacitania
        
        when s_done =>
            DONE <= '1'; -- Signalizuje dokoncenie operacie
            n_state <= s_done; -- Zostava v tomto stave
        
        when others =>
            n_state <= s_start; -- V pripade neznameho stavu prechod na zaciatok
        
end case;
end process; 
end behavioral;