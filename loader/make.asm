; #define EQU .equ
; #define END .end
; #define DB   .DB
; #define DW   .DW
; #define DM   .TEXT
; #define ORG .org

; pstart urcuje zaciatok programu

pstart  EQU 0CFA0h		; tape buffer


;pstart  EQU 05h

; zahlavie prveho bloku dat

 	ORG 	fstart
	DB	01h
	DW	pstart
	DW	length

; ---------------------------------------------
; hlavny program
; rutina pre zavedenie definovaneho programu z Ondra-SD modulu do pamate a jeho spustenie

LS174	EQU 11110111b		; memory mapping, audio_out, timers	(PORT3)
LS374	EQU 11111101b		; printer port	      			(PORT9)
LS175	EQU 11111110b		; beeper and relay    			(PORT10)
LS173	EQU 11111110b		; LED, strobe and serial_out		(PORT10)
LS373	EQU 0FFE0h		; keyboard, audio_in and serial_in      (IN-PORT)

	ORG pstart
start:  JP      LDSTRT         	; TAPE BUFFER
        JP      LDR58           ; TAPE BUFFER+3      nacitanie suboru a skok na RUN
        JP      CPUDET          ; TAPE BUFFER+6      zmereni taktu CPU, A = stav
                                ;                    portu 03H po navratu
LDSTRT: DI
	LD	A, 010b		; video off, allram [FAST]
	OUT	(LS174)	, A
; Takt CPU se musi zmerit drive, nez padne prvni bajt do modulu - casovky
; vysilani i prodlevy WAIT na nem zavisi. Prepinac 2/4 MHz je mechanicky,
; takze se da cvaknout i za behu; FileManager si proto pred kazdym nactenim
; souboru zavola toto mereni znovu pres vektor TAPE BUFFER+6.
	LD	A, 010b		; stav portu, ktery ma platit po mereni
	CALL	CPUDET
	LD	C, 32           ; zapipaj
	LD	B, 20
	CALL	BEEP
	LD	C, 64
	LD	B, 20
	CALL	BEEP
; --- pridana prodleva pro cestu pres preloader -----------------------------
; Puvodni dve pipnuti davaji dohromady jen ~135 ms. Pri autobootu to staci,
; pri zavedeni pres preloader ne - modul prvni prikazy zahodi a zavadec pak
; visi v LDR58. Overeno na stroji: s touhle prodlevou to projde.
; Casy jsou pocitane s 26 T na pruchod WAIT (DEC HL 6, LD A,H 4, OR L 4, JR NZ 12);
; puvodni odhady ~165 ms a ~1 s pocitaly s 31 T, ktere uvadel komentar u WAIT.
	LD	HL, 0D000h      ; ~690 ms (53 248 x 26 T), celkem s pipnutimi ~0,83 s
	CALL	WAIT
	LD	A, 'N'		; prikaz NOLDR - Zastav loader
	CALL	T9600
	LD	A, 'A'		; prikaz ALTER - Zmena nastavenia interfejsu
	CALL	T9600
	LD	A, 3		; nastavenie prenosovej rychlosti 57 600 Bd
	CALL	T9600
	LD	C, 128          ; kym dojde k prestaveniu modulu Ondra-SD na vyssiu rychlost
	LD	B, 20           ; tak este jeden ton
	CALL	BEEP
	LD	A, 'I'		; prikaz ILLUMINATE zapni LED
	CALL	T57k6
	LD	A, 1		; ON
	CALL	T57k6
	LD	B, 11		; inak sa bude citat subor, nazov suboru ma 8+3 znakov
	LD	A, 'F'		; prikaz FILE
	CALL	T57k6
	LD      HL, LOADER      ; odkaz na nazov suboru
FNAME:	LD	A, (HL)		; nacitaj nazov
	CALL	T57k6		; a odvysielaj
	INC	HL              ; znak za znakom
	DJNZ	FNAME		; vsetky znaky nazvu
	JP	LDR58           ; a nacitaj subor
RUN:	PUSH	DE		; urob z DE navratovu adresu programu
	LD	C, 64
	LD	B, 40
	CALL	BEEP
	LD	A, 'I'		; prikaz ILLUMINATE vypni LED
	CALL	T57k6
	LD	A, 0		; OFF
	CALL	T57k6
	LD	HL, 200
	CALL	WAIT
	LD	A, 'A'		; prikaz ALTER - Zmena nastavenia interfejsu
	CALL	T57k6
	LD	A, 0		; nastavenie prenosovej rychlosti 9 600 Bd
	CALL	T57k6
	RET			; skok na startovaciu adresu programu
; --------------------------------------------
  include "loader.asm"
  include "txd.asm"
  include "../common/beep.asm"
  include "../common/speed.asm"
; --------------------------------------------

LOADER: DM      "_ONDRAFMBIN"  	; nazov suboru, ktor ybude automaticky nahrany z SD karty


; definovanie startovacej adresy

lnchr:	DB	02h	
	DW	pstart

; vypocet adries

fstart  EQU 	pstart - 5
length  EQU 	lnchr - pstart
	END