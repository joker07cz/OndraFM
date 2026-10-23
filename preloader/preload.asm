; =============================================================================
;  __LOADER.BIN  -  "preloader" pro OndraSD interface
; =============================================================================
;
;  Kratky nahradni __LOADER.BIN. Modul OndraSD po resetu dokola vysila tenhle
;  soubor na 9600 Bd a obsluha musi "#" + ENTER zadat v pauze mezi opakovanimi,
;  tedy ne ve chvili, kdy modul vysila. Preloader proto zastavi autoboot ('N'),
;  vyzada si od modulu skutecny zavadec ('F' + "_LOADER2BIN") a nacteni preda
;  systemove rutine LOADER v ROM (1972h). Je radove kratsi (122 B ~ 153 ms
;  proti ~625 ms u puvodniho zavadece), takze "zakazane okno" temer zmizi.
;
;  Na karte musi byt:
;     __LOADER.BIN   tenhle preloader
;     _LOADER2.BIN   zavadec z ../loader/ (NE ../loader/orig/ - ten ma pred
;                    prvnim prikazem jen ~135 ms a v ceste pres preloader to
;                    modul nestihne)
;     _ONDRAFM.BIN   FileManager
;
;  Na cem to stoji (podrobne, i s merenim casu, v README.md):
;   1) Prodleva pred prikazy pro modul - UART jednocipu nema frontu.
;   2) Navratova adresa pro chybovou cestu LOADERu: SP = SPBAZE a v nem
;      LOADFAIL, jinak stroj po chybe vypada zamrzly.
;
;  Zduvodneni, kalkulace casu a postup prekladu: README.md v tomhle adresari.
;
; =============================================================================

  OUTPUT "../dist/__LOADER.BIN"

; --- konfigurace ---------------------------------------------------------
PROBES     EQU 1              ; 1 = pipani (start + hlaseni chyby)
                              ; 0 = ticha minimalni verze
                              ; Chovani se jinak nelisi - pri chybe se oba
                              ; buildy vraci do systemu, viz LOADFAIL.

; --- ROM Ondry (SSM ROM) -------------------------------------------------
WRB        EQU 0x2232         ; vystup jednoho bajtu do souboru
LOADER     EQU 0x1972         ; SYSTEM LOADER

; --- systemove promenne ---------------------------------------------------
FCBFLAGS   EQU 0xD6AE         ; priznaky FCB
PORT3STATE EQU 0xD627         ; stinova promenna portu 03H
SPBAZE     EQU 0xD4C2         ; DW - vrchol systemoveho zasobniku (0D4A0h)

; --- porty ----------------------------------------------------------------
; Dekoduji se jen A0, A1 a A3, takze 0F7h je alias portu 03H
; a 0FEh alias portu 0AH.
PORT3      EQU 0xF7
PORT10     EQU 0xFE

; --- bity FCBFLAGS --------------------------------------------------------
FCB_SERIAL EQU 0b00000100     ; bit 2 - SERIAL I/O misto magnetofonu
FCB_WRITE  EQU 0b00010000     ; bit 4 - WRITE (nastavuje si WRB samo)

; --- port 03H -------------------------------------------------------------
; Bity: 0 VEN (1 = video DMA), 1 MP1 (0 = ROM v 0000h-3FFFh, 1 = RAM),
; 2 MP0 (1 = I/O okno od 0E000h), 3 K0, 4-5 SA0/SA1 pro i8253.
;
; Pro prenos: video off (casovky SERIN/SEROUT s tim pocitaji a CPU ma plnou
; sbernici), ROM namapovana, I/O okno zapnute - odtud cte SERIN vstupni bit.
P3_ROM_IO  EQU 0b00000100
; Pro navrat do systemu: video zapnute, RAM dole (na 0000h je pak RAM stub
; JP RMAIN, tedy teply start), I/O okno pro klavesnici.
P3_SYSTEM  EQU 0b00000111

; --- port 0AH -------------------------------------------------------------
; bit0,1 LED zhasnute, bit2 TXD v klidu (log.1), bit3 /STB neaktivni,
; bit4 rele magnetofonu vypnute
P10_IDLE   EQU 0b00001111

; --- prodlevy (v jednotkach po 256 pruchodech WAITHL, ~3,3 ms na jednotku) -
DLY_CMD    EQU 15             ; ~50 ms mezi prikazy pro modul (x 256 pruchodu)

PRGSTART   EQU 0x4000

; --- hlavicka .BIN: datovy blok ------------------------------------------
  DB 1
  DW PRGSTART
  DW PRGLEN

  ORG PRGSTART

; =============================================================================
START:
  DI

; Stav portu vcetne stinove promenne - SERIN i SEROUT se na jejim konci
; vraci prave sem (SERRET, 2207h).
  LD A, P3_ROM_IO
  LD (PORT3STATE), A
  OUT (PORT3), A

; FCB: seriova linka. Bit 4 (WRITE) si WRB stejne nastavi samo, uvadi se
; jen kvuli citelnosti - RDB ho pri cteni ignoruje.
  LD A, FCB_SERIAL | FCB_WRITE
  LD (FCBFLAGS), A

  IF PROBES
; Dve pipnuti - zaroven signalizace "preloader bezi" a prodleva, nez se
; modul po autoboot prenosu dostane do cekaci smycky. Presne to, co dela
; puvodni zavadec (OndraFM loader/orig/make.asm, LDSTRT).
  LD A, 32
  CALL BEEP20
  LD A, 64
  CALL BEEP20
  ELSE
  LD H, DLY_CMD*3
  CALL WAITHL
  ENDIF

; --- 'N' - zastav opakovane vysilani zavadece -----------------------------
; Prodleva za nim kryje az 'F' a jmeno souboru; samotne 'N' se ztratit
; nemuze, protoze je to prvni bajt (viz hlavicka a README.md).
  LD A, 'N'
  CALL WRB
  LD H, DLY_CMD
  CALL WAITHL

; --- 'F' + jmeno souboru --------------------------------------------------
; Modul po 11. bajtu jmena prohleda adresar na karte (nekolik ms), takze
; nasledujici skok do rutiny LOADER se stihne s velkou rezervou.
  LD A, 'F'
  CALL WRB

  LD B, 11
  LD HL, FILENAME
.NEXTCHAR:
  LD A, (HL)
  CALL WRB
  INC HL
  DJNZ .NEXTCHAR

; --- predani rizeni systemovemu zavadeci ----------------------------------
; Znamy zasobnik + vlastni navratova adresa pro chybovou cestu LOADERu.
; Pri uspechu se LOADER nevraci - konci "JP RAMCALL" na start _LOADER2.BIN.
  LD SP, (SPBAZE)
  LD HL, LOADFAIL
  PUSH HL
  JP LOADER

; =============================================================================
;  Sem se dostaneme jen pri chybe cteni (TRDERROR -> TPOFF -> RET).
;
;  Chyba cteni neni duvod stroj restartovat - OS se s ni umi vyporadat sam.
;  '?' uz vypsal TRDERROR, takze staci vratit stroj do stavu, ve kterem ho
;  system ocekava, a predat mu rizeni; zpatky do celoobrazovkoveho editoru
;  se dostane sam.
;
;  Preloader po sobe musi uklidit tri veci: vypnute video (SERIN/SEROUT ho
;  nechaly vypnute kvuli casovkam), namapovanou ROM (0000h ma byt RAM stub,
;  ne vstupni bod ROM, jinak je to cold boot) a DI z uvodu. Prvni verze
;  preloaderu neuklidila nic a stroj pak vypadal zamrzly - cerna obrazovka
;  a klavesnice bez reakce.
; =============================================================================
LOADFAIL:
  IF PROBES
  LD A, 128                   ; dlouhy nizky ton = "nenacetlo se"
  LD H, 40
  CALL BEEP
  ENDIF

; Preloader bezi od 4000h, tedy nad hranici mapovani - prepnuti MP1 mu kod
; pod rukama nevymeni. Stinovou promennou je potreba srovnat taky: rutiny
; ROM z ni port 03H obnovuji (SERRET).
;
; Overeno v JOndrovi (ONDRA+ v1.5, polozka "System SSM ONDRA"): testovaci
; program uvede stroj do stavu, ve kterem bezi prenos (DI, port 03H = 04h),
; chvili v nem zustane a pak projde touhle sekvenci. Vrati se do editoru
; s nedotcenym obsahem obrazovky a klavesnice reaguje; system si vzapeti
; prepise stin portu 03H na 05h.
;
; Pozor na rozsah toho overeni: na Ondrovi s OndraSD je vyzkousene uspesne
; zavedeni (preloader -> zavadec -> FileManager), ne tahle chybova cesta.
; Ta zatim stoji jen na tom testu v emulatoru.
  LD A, P3_SYSTEM
  LD (PORT3STATE), A
  OUT (PORT3), A
  EI                          ; po EI jeste dobehne nasledujici instrukce,
                              ; takze se skok stihne bez preruseni
  JP 0x0000                   ; RAM stub JP RMAIN = teply start

FILENAME: db "_LOADER2","BIN"

; =============================================================================
;  Pomocne rutiny
; =============================================================================

  IF PROBES
; A = vyska tonu (bity 5..7), H = delka (x 256 pruchodu WAITHL).
; Parametry jdou rovnou v tech registrech, ve kterych je rutina potrebuje:
; A se hned maskuje a H si bere WAITHL, takze odpada prekladani z C a B.
; BEEP20 je vstup s prednastavenou delkou 20.
; Na preruseni nezavisle - ROM rutina BEEP (19B0h) pouziva EI/HALT,
; coz tady pri DI nejde.
BEEP20:
  LD H, 20
BEEP:
  AND 0b11100000
  OR  P10_IDLE
  OUT (PORT10), A
  CALL WAITHL
  LD A, P10_IDLE
  OUT (PORT10), A
  RET
  ENDIF

; H = pocet pruchodu / 256, jeden pruchod ~26 T (~13 us pri 2 MHz a VEN=0),
; tedy ~3,3 ms na jednotku v H. Volajici nastavuje jen H, L si rutina nuluje
; sama - usetri to bajt na kazdem volani.
WAITHL:
  LD L, 0
.LOOP:
  DEC HL
  LD A, H
  OR L
  JR NZ, .LOOP
  RET

PRGEND:
PRGLEN EQU (PRGEND-PRGSTART)

; --- hlavicka .BIN: startovaci blok --------------------------------------
  DB 2
  DW PRGSTART
