#define EQU .equ
#define END .end
#define DB   .DB
#define DW   .DW
#define DM   .TEXT
#define ORG .org

; pstart urcuje zaciatok programu

pstart  EQU 8000h		; tape buffer

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
start:  LD	SP, $
LDSTRT: DI
	LD	A, 010b		; video off, allram [FAST]
	OUT	(LS174)	, A
	LD	C, 32           ; zapipaj
	LD	B, 20
	CALL	BEEP
	LD	C, 64
	LD	B, 20
	CALL	BEEP
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
#include "loader.asm"
#include "txd.asm"
#include "beep.asm"
; --------------------------------------------

LOADER: DM      "MAKECPM BIN"  	; nazov suboru, ktory bude automaticky nahrany z SD karty


; definovanie startovacej adresy

lnchr:	DB	02h	
	DW	pstart

; vypocet adries

fstart  EQU 	pstart - 5
length  EQU 	lnchr - pstart
	END