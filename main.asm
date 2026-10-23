; --------------------------------------------
;
; --------------------------------------------
; definicia konstant
; --------------------------------------------
;
LS174		EQU	11110111b		; memory mapping, audio_out, timers	(PORT3)
LS374		EQU	11111101b		; printer port	      			(PORT9)
LS175		EQU	11111110b		; beeper and relay    			(PORT10)
LS173		EQU	11111110b		; LED, strobe and serial_out		(PORT10)
LS373		EQU	0FFE0h			; keyboard, audio_in and serial_in      (IN-PORT)
TOPLINE 	EQU	03			; horna hranica ramu
BTMLINE		EQU	30			; dolna hranica ramu
WIDTH		EQU	49			; sirka ramu
LLEFT		EQU	2			; pozicia vlavo prvej polozky v zozname
LTOP		EQU	TOPLINE+1		; pozicia hore prvej polozky v zozname
LROWS		EQU	26			; pocet zaznamov v stlpci
LCOLW		EQU	15			; sirka stlpca
EXTSEP		EQU	20h			; oddelovac pripony
RECLIST		EQU	8000h			; docasny priestor na ukladanie adresara
TAPEBUF 	EQU	0CFA0h			; tape buffer
;TOTAL		EQU	40
;
; ---------------------------------------------
; hlavny program
; --------------------------------------------
;
; tu zacina progrma
;
start:  	DI
;		LD	SP, TAPEBUF+1023
		LD	A, 010b		; video off, allram [FAST]
		OUT	(LS174)	, A
		LD	A, 010b		; zmer takt CPU jeste pred prvnim bajtem
		CALL	MEASUR		; pro modul - casovky i WAIT na nem zavisi
		CALL	TONES		; zapipaj
		LD	A, 'N'		; prikaz NOLDR - Zastav loader
		CALL	T9600
		LD	A, 'A'		; prikaz ALTER - Zmena nastavenia interfejsu
		CALL	T9600
		LD	A, 3		; nastavenie prenosovej rychlosti 57 600 Bd
		CALL	T9600
		LD	HL, 2000        ; cakaj, kym dojde k prestaveniu modulu Ondra-SD na vyssiu rychlost
		CALL	WAIT
		LD	A, 'I'		; prikaz ILLUMINATE - LED
		CALL	T57k6
		LD	A, 0		; vypni
		CALL	T57k6
		LD	A, 'K'		; prikaz VER
		CALL	T57k6
		CALL	LDINIT
RDVER:		CALL	R57K6		; nacitaj cislo verzie ako jeden bajt
					; cil CALLu prepisuje SETRD podle taktu
		LD	A, L
		LD	(VERFW), A	; uloz verziu FW
		LD	HL, 2000
		CALL	WAIT
; nacitanie root adresara
		CALL    ROOTDIR
RET_FROM_SORT:      ; sem se vracime po setrideni zaznamu
; pociatocne nastavenie zobrazenia
		CALL	GRINIT		; inicializacia grafiky
DVIEW:		LD	A, 010b		; video off, allram [FAST]
		OUT	(LS174)	, A
        	CALL	CLS		; vymaz obrazovku
		CALL	NORMAL		; zatial bez inverzie
	        CALL    LAYOUT          ; zakladny ram a texty
        	CALL    DIRLST          ; zobraz zaznamy
; ---------------------------------------------
; hlavna slucka, caka sa na stlacenie klavesy a podla toho sa vykona cinnost	
MAIN:		CALL	FOOTER
		LD	C, 64
		LD	B, 3
		CALL	BEEP
		LD	A, 011b		; port, video-on [SLOW]
		OUT	(LS174)	, A
		CALL	REC0		; nastav kurzor na prvy zaznam
MLOOP:		LD	HL, TIME0	; cas
		LD	A, (HL)		; nacitaj hodnotu
		INC	A		; zvys
		JR	Z, INCTIME	; pri preteceni skok
		LD	(HL), A
		LD	HL, 20h
		CALL	WAIT
		CALL	KEYSCAN         ; je nieco stlacene
		LD	C, E            ; uloz index klavesy do C (potrebny pre rutinu KEYCODE)
		INC     E               ; ak nic nebolo stlacene, tak v E je FF
		JR      Z, MLOOP	; a bude sa cakat dalej
		LD	HL, TIME0	; cas
		LD	(HL), 00h	; vynuluj pocitadlo casu
		LD	A, 011b
		OUT	(LS174)	, A	; mapuj RAM (bol namapovany port, kvoli citaniu klavesnice)
		LD	A, C	        ; index klavesy do A
		PUSH	AF
		LD	C, 96
		LD	B, 1
		CALL	BEEP
		POP	AF
		LD	HL, MLOOPD	; navrat pres MLOOPD - pri 4 MHz doplni zpozdeni
		PUSH	HL		; vytvor navratovu adresu
		LD	HL, ACTPOS	; nastav na aktualnu poziciu, vyuzije sa neskor
		CP	43
		JP	Z, LEFT         ; stlacene sipky
		CP	40
		JP	Z, RIGHT
		CP	42
		JP 	Z, DOWN
		CP	37
		JP	Z, UP
		CP	48         ; joystick left
		JP	Z,LEFT
		CP	49         ; joystick right
		JP	Z,RIGHT
		CP	46         ; joystick down
		JP	Z,DOWN
		CP	47         ; joystick up 
		JP	Z,UP
		POP     HL              ; zrus navratovu adresu
		CP	3		; "E"
		JP	Z, MEMTEST 	; memory test
		CP	35		; "CTRL"
		JR 	Z, GOROM        ; vracia do ViLi
		CP	10		; "Symbol"
		JR 	Z, GOROM        ; vracia do ViLi
		CP	25
		JR	Z, LOADIT       ; stlaceny Enter, bude sa citat adresar alebo subor
		CP	20		; "Caps"
		JR	Z, ROOTRD       ; nacita ROOT
;added
		CP	45        ; joystick FIRE
		JR	Z, LOADIT       ; stlaceny Enter, bude sa citat adresar alebo subor
		CP	7         ; "S"
		JP	Z, SORT_FILENAMES
;end of added
		JR	MLOOP
INCTIME:	LD	(HL), A
		INC	HL
		LD	A, (HL)
		INC	A
		LD	(HL), A
		JR	Z, CHTXT	; ak pretieklo, zmen text
		JP	MLOOP
CHTXT:		LD	A, 0FBh		; uprav hodnotu
		LD	(HL), A
		CALL	FOOTER		; zmen text
		JP	MLOOP
; ---------------------------------------------
; navrat do ViLi
; --------------------------------------------
GOROM:		LD	A, 011b		; zmer takt (prepinac mohl cvaknout v menu)
		CALL	MEASUR
		LD	A, 'X'		; prikaz RESET, uvedie modul do vychodiskoveho stavu
		CALL	T57k6
		LD	A, 000b		; mapuj ROM
		OUT	(LS174)	, A
		EI
		JP	0000		; RESET/NMI
; ---------------------------------------------
; nacitanie adresara alebo celeho suboru
; --------------------------------------------
LOADIT:		LD	C, 128
		LD	B, 5
		CALL	BEEP
		LD	A, 010b
		OUT	(LS174)	, A	; video off
		LD	A, 010b		; zmer takt jeste pred vetvenim na CHDIR,
		CALL	MEASUR		; obe vetve posilaji prikaz modulu
		LD	A, (ACTPOS)	; aktualny index
		CALL	RECMEM          ; vrat fyzicku adresu zaznamu
		PUSH    HL
		LD      DE, 11          ; najdi atribut zaznamu (je hned za nazvom)
		ADD     HL, DE
		LD      A, (HL)         ; vyzdvihni atribut
		POP     HL
		AND	100000b		; je to adresar?
		JP	Z, CHDIR        ; tak zmen a nacitaj novy adresar
		PUSH	HL		; zahraj
		CALL	TONES
		POP	HL
		LD	A, 010b		; zavadec v TAPE BUFFER ma vlastni priznak
		CALL	TAPEBUF+6	; taktu - nech ho premerit (CPUDET).
					; Musi to byt JESTE PRED prikazem pro modul:
					; mereni trva 20-40 ms s povolenym prerusenim
					; a odpoved modulu by se do nej ztratila.
		LD	A, 'I'		; prikaz ILLUMINATE zapni LED
		CALL	T57k6
		LD	A, 1		; ON
		CALL	T57k6
		CALL	LINES252   ; nastav standardnich 252 linek
		LD	B, 11		; inak sa bude citat subor, nazov suboru ma 8+3 znakov
		LD	A, 'F'		; prikaz FILE
		CALL	T57k6
FNAME:		LD	A, (HL)		; nacitaj nazov
		CALL	T57k6		; a odvysielaj
		INC	HL              ; znak za znakom
		DJNZ	FNAME		; vsetky znaky nazvu
		JP	TAPEBUF+3       ; a nacitaj subor pomocou loader-a v TAPE BUFFER
; ---------------------------------------------
; navrat do ROOT adresara
; --------------------------------------------
ROOTRD: 	LD	A, 010b		; video off, allram [FAST]
		OUT	(LS174)	, A
        	CALL    ROOTDIR         ; nacitaj root adresar
        	JP      DVIEW           ; a zobraz
; ---------------------------------------------
; tony
; --------------------------------------------
TONES:	;	LD	C, 32
	;	LD	B, 20
	;	CALL    BEEP
	;	LD	C, 64
	;	LD	B, 20
	;	CALL    BEEP
		LD	C, 128
		LD	B, 5
		CALL    BEEP
; ---------------------------------------------
; vykreslenie ramu                                             [FAST]
; --------------------------------------------
LAYOUT:		LD	HL, TOPLINE	; nastav poziciu
		CALL	SETPOS
		LD	A, 0C9h		; LH roh
		CALL	SHCHAR
		CALL	MOVEPOS
		LD	B, WIDTH-2
		LD	A, 0CDh		; vodorovne 0BAh
		CALL	SHHORZ
		LD	A, 0BBh		; PH roh
		CALL	SHCHAR
		LD	HL, BTMLINE	; nastav poziciu
		CALL	SETPOS
		LD	A, 0C8h		; LD roh
		CALL	SHCHAR
		CALL	MOVEPOS
		LD	B, WIDTH-2
		LD	A, 0CDh
		CALL	SHHORZ		; PD roh
		LD	A, 0BCh
		CALL	SHCHAR
		LD	HL, TOPLINE+1
		CALL	SETPOS
		LD	B, BTMLINE-TOPLINE-1
		LD	A, 0BAh		; vertikalne
		CALL	SHVERT
		LD	HL, (WIDTH-1)*256+TOPLINE+1
		CALL	SETPOS
		LD	B, BTMLINE-TOPLINE-1
		LD	A, 0BAh
		CALL	SHVERT
; --------------------------------------------
; logo
        	LD      L, 0FFh         ; pozicia loga na obrazovke (linka)
        	LD      DE, LOGODATA    ; zdroj dat
        	LD      B, 10h          ; 16 liniek
LOGO0:  	LD      H, 0FFh         ; zaciatok loga (stlpec)
        	LD      C, 13h          ; 19 bajtov na riadok
LOGO1:  	LD      A, (DE)         ; skopiruj bajt
		CPL
        	LD      (HL), A
        	INC     DE              ; dalsi bajt
        	DEC     H               ; posun na dalsi stlpec
	        DEC     C               ; zniz pocitadlo
        	JR      NZ, LOGO1       ; opakuj na celu linku
		RLC	L
        	DEC     L               ; presun na dalsiu linku
		RRC	L
        	DJNZ    LOGO0           ; opakuj pre vsetky linky
; texty
		LD	HL, 32*256+64     ; +64 => +1 po 2 rotacich => o 2 mikroradky niz
		CALL	SETPOS
		LD	HL, LINE1
		CALL	SHTEXT          ; "Ondra-SD"
		LD	HL, 32*256+1+64
		CALL	SETPOS
		LD	HL, LINE2
		CALL	SHTEXT          ; "Ondra-SD"
		LD	HL, (LINE2B-LINE2+32)*256+1+64
		CALL	SETPOS
		LD	A, (VERFW)	; cislo verzie FW
		SRL	A		; vyssi polbajt na nizsi
		SRL	A
		SRL	A
		SRL	A
		INC	A
		ADD	A, 30h		; vytvor cislo
		CALL	SHMCHAR		; zobraz
		LD	A, '.'
		CALL	SHMCHAR
		LD	A, (VERFW)	; znova nacitaj
		AND	1111b		; nizsi polbajt
		ADD	A, 30h
		CALL	SHCHAR		; zobraz
;		CALL	FOOTER		; spodny infotext
;		LD	HL, BTMLINE+4	; a este posledny text
;		CALL	SETPOS
;		LD	HL, INFO5
;		CALL	SHTEXT
		RET
; ---------------------------------------------
; zrusenie vysvieteneho zaznamu                                [SLOW]
; --------------------------------------------
DARK:		LD	B, A		; index do B
		CALL	NORMAL		; normalne zobrazenie
		CALL	RDREC		; zobraz
		LD	HL, ACTPOS	; nachystaj adresu
		RET
; ---------------------------------------------
; vysvietenie zaznamu                                          [SLOW]
; --------------------------------------------
REC0:		LD	A, 0		; prvy zaznam
WHITE:		LD	(ACTPOS), A	; uloz poziciu
		LD	B, A
		CALL	INVERSE		; cierne na bielom
		CALL	RDREC		; zobraz
		RET
; ---------------------------------------------
; zmena indexu po stlaceni smeroveho tlacidla                  [SLOW]
; --------------------------------------------
LEFT:		LD	A, (HL)		; zhasni
		CALL	DARK
		LD	A, (HL)		; aktualny zaznam
		CP	LROWS		; prvy stlpec?
		JR	C, FIRSTREC	; tak na prvy zaznam
		XOR	A		; CF = 0
		LD	A, (HL)
		SBC	A, LROWS	; odpocitaj pocet riadkov v stlpci
		JR	WHITE
; --------------------------------------------
RIGHT:		LD	A, (HL)
		CALL	DARK		; zhasni
		LD	A, (HL)		; aktualny zaznam
		LD	HL, RECORDS	; ukazatel na pocet zaznamov
		ADD	A, LROWS	; pripocitaj pocet riadkov v stlpci
		LD	HL, RECORDS
		CP	(HL)
		JR	C, WHITE	; este sa da zobrazit
; --------------------------------------------
LASTREC:	LD	A, (RECORDS)	; pocet zaznamov
		DEC	A		; posledny ma index mensi o 1
		JR	WHITE
; --------------------------------------------
FIRSTREC:	XOR	A		; prvy zaznam
		JR	WHITE        
; --------------------------------------------
UP:		LD	A, (HL)
		CALL	DARK		; rovno zhasni
		LD	A, (HL)
		OR	A
		JR	Z, LASTREC	; ak bol prvy, musi sa nastavit na posledny
		DEC	A		; inak zmensi index o 1
		JR	WHITE		; a vysviet novy
; --------------------------------------------
DOWN:		LD	A, (HL)
		CALL	DARK		; rovno zhasni
		LD	A, (HL)
		LD	HL, RECORDS
		INC	A		; zvacsi index o 1
		CP	(HL)		; existuje taky zaznam?
		JR	NC, REC0	; ak nie, daj prvy
		JR	WHITE		; vysviet novy
; ---------------------------------------------
; zmena adresara                                               [FAST]
; --------------------------------------------
CHDIR:  	LD	B, 11		; aj nazov adresara ma 11 znakov (8+3)
		LD	A, 'C'		; prikaz CHDIR
		CALL	T57k6
DNAME:		LD	A, (HL)		; nacitaj nazov
		CALL	T57k6		; a odvysielaj
		INC	HL              ; znak za znakom
		DJNZ	DNAME		; vsetky znaky nazvu
		CALL    READDIR         ; nacitaj obsah adresara
		JP      DVIEW           ; a zobraz
; ---------------------------------------------
; nastavenie root adresara                                     [FAST]
; --------------------------------------------
ROOTDIR:	LD	A, 010b		; zmer takt pred prikazem pro modul
		CALL	MEASUR
		LD	A, 'C'		; prikaz CHDIR
		CALL	T57k6
		LD	A, '/'		; ROOT
		CALL	T57k6
		LD	B, 10
SPACE:		LD	A, 20h		; a este 10 medzier
		CALL	T57k6
		DJNZ	SPACE
;		CALL	READDIR          ; nacitaj adresar
; ---------------------------------------------
; nacitanie adresara z Ondra-SD modulu                         [FAST]
; --------------------------------------------
READDIR:	LD	A, 0
;	RET			; pre testy
		LD	(RECORDS), A	; vynuluj pocitadlo zaznamov
		LD	A, 00001110b	; zelena LED (bit 0 = 0); bit 4 = rele musi zustat 0
		OUT	(LS173), A
		LD	A, 'D'		; prikaz DIR
		CALL	T57k6
		CALL	LDINIT
		LD	DE, RECLIST
GETREC:		CALL	R57K6		; 17T	nacitaj nazov suboru po znakoch
		LD	A, L		;  4T
		LD	(DE), A		;  7T	uloz znak
		INC	DE		;  6T	zvys pocitadlo
		JR	Z, FEND		; 12T	koniec nazvu?
		INC	A		;  4T
		JR	NZ, GETREC	; 12T	posledny zaznam? ak nie, citaj dalsi
		JR	DEND		; 12T	inak skonci
FEND:		LD	A, 00001111b	;  7T   nizsi polbajt sa doplni do F
		OR	E               ;  4T
		LD	E, A		;  4T
		INC	DE		; a potom staci zvysit DE o 1
		PUSH	HL
		LD	HL, RECORDS	; zvys pocitadlo suborov
		LD	A, (HL)		; ale naskor zisti, ci uz ich nie je
		CP	LROWS*3+1	; 3 stlpce * pocet riadkov + 1 rezerva pre adresar "."
		JR	NC, LIMIT
		INC	(HL)
LIMIT:		POP	HL
		JR	GETREC	        ; 12T
DEND:		LD	C, 128		; zapipaj a zhasni LED
		LD	B, 5
		CALL	BEEP
		LD	DE, RECLIST     ; skontroluj prvy zaznam
		LD      A, (DE)
		CP      '.'             ; je to podadresar? ak ano, prvy zaznam "." bude zmazany
		JR      Z, REMDOT       ; zmaz zaznam "."
		LD	HL, RECORDS
		LD	A, (HL)		; pocet zaznamov
		CP	48		; viac ako 48?
		RET	C		; ak nie, tak koniec
		DEC	(HL)		; inak este zniz o jeden
		RET
REMDOT:		LD	HL, RECORDS
	        LD      A, (HL)		; pocet zaznamov spolu
		DEC	(HL)		; nakoniec bude o jeden menej
	        CALL    RECMEM          ; vypocitaj koniec zaznamov
        	SBC     HL, DE          ; vypocet obsadenia pamate
	        LD      B, H            ; vysledok do BC
	        LD      C, L
		LD      HL, 16          ; bude sa rusit prvy zaznam
		ADD     HL, DE
        	LDIR                    ; posun o 16 bajtov dole
		RET
; ---------------------------------------------
; nacitaj zoznam suborov a adresarov na obrazovku              [FAST]
; --------------------------------------------
DIRLST: 	;LD	A, 011b		; port, video-on [SLOW]
		LD	A, 010b		; port, video-off [FAST]
		OUT	(LS174)	, A	; animovane zobrazenie
		LD	B, 0		; prvy zaznam ma index 0
RFILL:		PUSH	BC		; uschovaj pocitadlo
		CALL	RDREC		; nacitaj a zobraz zaznam
		POP	BC
		INC	B		; dalsi zaznam
		LD	A, B
		LD	HL, RECORDS
		CP	(HL)		; je posledny?
		JR	C, RFILL	; ak nie, citaj dalsi zaznam
		RET
; ---------------------------------------------
; prepocita index (v A) zaznamu na fyzicku adresu v RAM (do HL)
; --------------------------------------------
RECMEM: 	LD	HL, RECLIST
		LD	E, A		; index do E
		LD	D, 0		; vynuluj E
		SLA	E		; vynasob 16
		RL	D
		SLA	E
		RL	D
		SLA	E
		RL	D
		SLA	E
		RL	D
		ADD	HL, DE		; v HL je ukazatel na aktualny zaznam
		RET
; ---------------------------------------------
; zobrazi jeden zaznam, na ktory ukazuje index (v B)           [SLOW]
; --------------------------------------------
RDREC:  	LD      A, B            ; index do A
	        CALL    RECMEM          ; prepocitaj index na adresu
		PUSH	HL		; uschovaj
		LD	H, LLEFT	; offset vlavo
		LD	A, B
		SUB	LROWS		; prvy stlpec?
		JR	C, RDREC1	; tak netreba nic
		LD	H, LLEFT+LCOLW	; druhy stlpec
		SUB	LROWS		; prepocitaj na riadok
		JR	C, RDREC1	; druhy stlpec
		LD	H, LLEFT+LCOLW+LCOLW
		SUB	LROWS		; docasne odpocitaj
RDREC1:		ADD	A, LROWS		; vrat spat
		ADD	A, LTOP		; horny offset
		LD	L, A		; v HL je pociatocna suradnica (x,y) zobrazenia zaznamu
		CALL	SETPOS		; a je tu pozicia textu
		POP	HL		; obnov ukazatel na zaznam
		LD	B, 8
RNAME:		LD	A, (HL)
		PUSH	BC
		PUSH	HL
		CALL	SHMCHAR		; a zobraz
		POP	HL
		POP	BC
		INC	HL              ; dalsi znak
		DJNZ	RNAME
		PUSH	HL
		LD	A, EXTSEP	; medzera
		CALL	SHMCHAR
		POP	HL
		LD	B, 3
FEXT:		LD	A, (HL)
		PUSH	BC
		PUSH	HL
		CALL	SHMCHAR		; a zobraz
		POP	HL
		POP	BC
		INC	HL              ; dalsi znak
		DJNZ	FEXT
		LD	A, (HL)		; nacitaj typ
		AND	100000b		; je to adresar?
		JR	Z, DIR
;		LD	A, '{'		; zobraz ikonu pasky
;		CALL	SHMCHAR
;		LD	A, '}'		; zobraz ikonu pasky
;		CALL	SHCHAR
		RET
DIR:		LD	A, '['		; zobraz ikonu adresara
		CALL	SHMCHAR
		LD	A, ']'		; zobraz ikonu adresara
		CALL	SHCHAR
        	RET			; koniec zaznamu
; ---------------------------------------------
; texty na dolnej casti
; --------------------------------------------
FOOTER: 	LD	HL, FOOTNO
		LD	E, (HL)		; posledne cislo zaznamu
		INC	E
		LD	(HL), E
		SLA	E		; vynasob dvomi
		LD	HL, FOOTTAB	; adresa tabulky textov
		LD	D, 0
		ADD	HL, DE		; vypocitaj adresu v tabulke
		LD	E, (HL)		; nacitaj hodnotu z tabulky
		INC	HL
		LD	D, (HL)
		LD	A, D		; ak je 0, zacni prvym textom
		OR	A
		JR	Z, FOOTER0
		LD	A, 011b		; port, video-on [SLOW]
		OUT	(LS174)	, A
		PUSH	DE		; uschova adresu textu
		CALL	NORMAL		; bez zvyraznenia
		LD	HL, BTMLINE+1	; nastav poziciu na obrazovke
		CALL	SETPOS
		CALL	CLINE		; vymaz riadok
		POP	HL		; nacitaj adresu textu
		CALL	SHTEXT
		RET
FOOTER0:	LD	HL, FOOTNO	; nastav na poziciu 0
		LD	(HL), 0FFh	; nasledne sa zvysi na 0
		JR	FOOTER
; --------------------------------------------
; spustenie programu
; --------------------------------------------
RUN:		PUSH	DE		; urob z DE navratovu adresu programu
		LD	A, 010b		; zmer takt - priznak je z doby pred
		CALL	MEASUR		; nactenim souboru, mohl zastarat
		LD	C, 32		; zapipaj
		LD	B, 5
		CALL	BEEP
		LD	A, 'I'		; LED
		CALL	T57k6
		LD	A, 0		; OFF
		CALL	T57k6
		LD	A, 'A'		; Zmena nastavenia interfejsu - Settings
		CALL	T57k6
		LD	A, 0		; nastavenie 9 600 Bd
		CALL	T57k6
		LD	C, 128
		LD	B, 9
		CALL	BEEP
		LD	A, 011b		; video on, map allram
		OUT	(LS174)	, A
		RET			; skok na startovaciu adresu programu
		;
; ---------------------------------------------
; autorepeat pri 4 MHz
; ---------------------------------------------
; Opakovani klavesy nema zadny casovac, je to jen rychlost smycky MLOOP. WAIT se
; pri 4 MHz projde dvakrat, takze jeho cas zustane stejny, ale KEYSCAN a obsluha
; sipek jsou jen kod a bezi na 4 MHz za polovicni cas - kurzor pak projizdi
; seznam rychleji. Namereno v JOndrovi s drzenou sipkou dolu:
;   2 MHz: 59 189 T na pruchod = 7,70 snimku (~154 ms)
;   4 MHz: 72 772 T na pruchod = 4,73 snimku (~95 ms)
; Cil na 4 MHz je 7,70 snimku = 118 320 T, chybi 45 548 T. WAIT pri 4 MHz projde
; smycku dvakrat, jedna iterace ma 26 T (DEC HL 6, LD A,H 4, OR L 4, JR NZ 12 -
; komentar "31T" u WAIT je nepresny). Prvni pokus s HL = 734 pridal namerenych
; 38 901 T, tedy 53,0 T na HL vcetne rezie: HL = 45 548 / 53,0 = 859.
; Zpozdeni se prida za obsluhu klavesy, aby prvni reakce na stisk zustala hned.
; Hodnota zavisi na delce obsluhy klaves; pri uprave kodu v MLOOP/LEFT/RIGHT/UP/
; DOWN/BEEP ji znovu zmerit. Takt se tu nemeri znovu - pouziva se CPU4 z
; posledniho MEASUR (start, nacteni adresare apod.), takze po cvaknuti
; prepinace behem prochazeni slozky se rychlost srovna az pri dalsim mereni.
RPTWT		EQU	859
MLOOPD:		LD	A, (CPU4)
		OR	A
		JP	Z, MLOOP	; 2 MHz - bez zpozdeni
		LD	HL, RPTWT
		CALL	WAIT		; WAIT se pri 4 MHz projde 2x
		JP	MLOOP
; ---------------------------------------------
; zmereni taktu CPU a nastaveni vseho, co na nem zavisi
; ---------------------------------------------
; vstup: A = stav portu 03H, ktery ma platit po navratu
; meni:  AF, HL
; ---------------------------------------------
MEASUR:		CALL	CPUDET		; prepinac 2/4 MHz je mechanicky a da se
					; cvaknout i za behu, proto se meri pred
					; kazdou akci, ktera posila prikazy modulu
; ---------------------------------------------
; Cteci smycka v GETREC ma mezi bajty vyuzity kazdy T, takze tam nesmi
; pribyt zadna rozbocka podle taktu. Cil CALLu se proto prepise primo
; v kodu - jednou za mereni misto jednou za bajt.
; ---------------------------------------------
SETRD:		LD	HL, R57K6	; 2 MHz - rozbalena verze
		LD	A, (CPU4)
		OR	A
		JR	Z, SETRD1
		LD	HL, R57K64	; 4 MHz - verze se smyckou
SETRD1:		LD	(GETREC+1), HL
		LD	(RDVER+1), HL
		RET
; ---------------------------------------------
VERFW:		DB	00h		; cislo verzie FW
POSX:		DB	00h		; pozicia vykreslovaneho znaku
POSY:		DB	00h
INVER:  	DB      00h		; flag: invezny znak
ACTPOS:		DB	0		; aktualna pozicia kurzora
RECORDS:	DB	0		; pocet zaznamov
FOOTNO:		DB	0FFh		; aktualna sprava
TIME0:		DB	0		; hodnota casovaca pre texty
TIME1:		DB	0FAh
LINE1:		DM	"CARD MANAGER 1.50"
		DB	0
LINE2:		DM	"(FW "
LINE2B: 	DM	" . ) "
		DB	0ABh
		DM	"2026"
		DB	0
FOOTTAB:	DW	INFO1
		DW	INFO2
		DW	INFO6
		DW	INFO3
		DW	INFO4
		DW	INFO5
		DW	INFO7
		DW	INFO8
		DW	0000h
INFO1:		DM	"Use arrow keys "
		DB	0F2h, 0F4h, 20h, 0F1h, 20h, 0F0h, 20h, 0F4h, 0F3h
		DM	" or joystick to navigate."
		DB	0
INFO2:		DM	"Press Enter or Fire to start data transfer."
		DB	0
INFO6:		DM	"It takes up to 10 seconds to load 48kB file."
		DB	0
INFO3:		DM	"Press ` to load root directory."
		DB	0
INFO4:		DM	"Press "
		DB	7Fh
		DM	" to restart."
		DB	0
INFO5:		DM	"Visit https://sites.google.com/site/ondraspo186"
		DB	0
INFO7:		DM	"Press E to run memory test."
		DB      0
INFO8:		DM	"Press S to sort directories and files (A-Z)."
		DB      0

LOGODATA:
		DB	0E0h, 030h, 018h, 00Fh, 0FFh, 0FFh, 0FFh, 0FFh, 0F0h, 0FFh, 0FFh, 0FFh, 0FFh, 0FFh, 0FFh, 0FFh, 0FFh, 0FFh, 0FFh
		DB	0E0h, 030h, 018h, 00Fh, 0FFh, 0FFh, 0FFh, 0FFh, 0F0h, 0FFh, 0FFh, 0FFh, 0FFh, 0FCh, 000h, 007h, 000h, 0FFh, 0FFh
		DB	0E0h, 030h, 018h, 00Fh, 0FFh, 0FFh, 0FFh, 0FFh, 0F0h, 0FFh, 0FFh, 0FFh, 0FFh, 0E0h, 000h, 006h, 003h, 0C7h, 0FFh
		DB	0E0h, 030h, 018h, 00Fh, 0FFh, 0FFh, 0FFh, 0FFh, 0F0h, 0FFh, 0FFh, 0FFh, 0FFh, 0C0h, 000h, 00Fh, 006h, 01Ch, 0FFh
		DB	0C0h, 060h, 030h, 01Fh, 0F0h, 07Fh, 081h, 0FEh, 000h, 0F8h, 01Fh, 003h, 0FFh, 0C0h, 07Fh, 0FFh, 0F8h, 0C0h, 03Fh
		DB	0C0h, 060h, 030h, 01Fh, 0C0h, 01Fh, 000h, 0FCh, 000h, 0F0h, 01Eh, 001h, 0FFh, 0C0h, 07Fh, 0FFh, 0FEh, 000h, 01Fh
		DB	0C0h, 060h, 030h, 01Fh, 080h, 00Eh, 000h, 078h, 000h, 0E0h, 01Ch, 000h, 0FFh, 0C0h, 00Fh, 0FFh, 0FCh, 000h, 01Fh
		DB	0C0h, 060h, 030h, 01Fh, 082h, 00Eh, 000h, 038h, 000h, 0E0h, 038h, 000h, 0FFh, 0E0h, 001h, 0FFh, 0FCh, 000h, 01Fh
		DB	080h, 0C0h, 060h, 03Fh, 007h, 006h, 008h, 030h, 060h, 0C1h, 0F8h, 030h, 07Fh, 0F8h, 000h, 07Fh, 0F0h, 000h, 01Fh
		DB	080h, 0C0h, 060h, 03Fh, 007h, 006h, 01Ch, 030h, 0F0h, 0C1h, 0F8h, 078h, 07Fh, 0FFh, 000h, 03Fh, 000h, 000h, 01Fh
		DB	080h, 0C0h, 060h, 03Fh, 007h, 006h, 01Ch, 030h, 0F0h, 0C1h, 0F8h, 078h, 07Fh, 0FFh, 0C0h, 038h, 000h, 000h, 03Fh
		DB	080h, 0C0h, 060h, 03Fh, 082h, 00Eh, 01Ch, 030h, 060h, 0C1h, 0F8h, 030h, 07Ch, 000h, 000h, 030h, 000h, 000h, 0FFh
		DB	001h, 080h, 0C0h, 07Fh, 080h, 00Eh, 01Ch, 030h, 001h, 0C1h, 0F8h, 000h, 07Ch, 000h, 000h, 030h, 000h, 001h, 0FFh
		DB	001h, 080h, 0C0h, 07Fh, 0C0h, 01Eh, 01Ch, 038h, 001h, 0C1h, 0FCh, 000h, 078h, 000h, 000h, 070h, 000h, 00Fh, 0FFh
		DB	001h, 080h, 0C0h, 07Fh, 0E0h, 03Eh, 01Ch, 03Ch, 003h, 0C1h, 0FEh, 000h, 078h, 000h, 000h, 0E0h, 000h, 07Fh, 0FFh
		DB	001h, 080h, 0C0h, 07Fh, 0FFh, 0FFh, 0FFh, 0FFh, 0FFh, 0FFh, 0FFh, 0FFh, 0F8h, 000h, 003h, 0E0h, 00Fh, 0FFh, 0FFh
; --------------------------------------------
;		END
; --------------------------------------------
