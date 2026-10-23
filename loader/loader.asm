; *********** L O A D E R   5 8 **********
; -------------------------------

; rutina vyuziva registre A, B, C, D, E, H, L, IX
; A	vstupna hodnota z portu a ine rozne vyuzitie
; BC	dlzka bloku
; DE	aktualna adresa pre zapis
; H	adres vstupneho portu
; L	citany bajt
; IX	navratova adresa

; -------------------------------
LDINIT: DI
	LD	H, LS373/256	; IN-PORT, staci vyssi bajt
	RET
LDR58:	DI
	LD	H, LS373/256	; IN-PORT, staci vyssi bajt
	LD	A, (CPU4)	; pri 4 MHz je bitova bunka dvakrat sirsi v T,
	OR	A		; cte se proto jinou rutinou
	JP	NZ, LDR584
	LD	IX, RDHDR1	; navratova adresa po nacitani typu bloku
	PUSH	IX		; na zasobnik
	LD	A, 110b		; ram + port od E000
	OUT	(LS174)	, A

; --------------------------------

; nacitaju sa 3 alebo 5 bajtov hlavicky

RDHDR:	JP	R57K6		; 10T	nacitaj typ bloku
RDHDR1:	LD	C, L		;  4T	pocas dvoch citani zostane uchovany v C
	PUSH	IX		; 15T	navratovu adresu treba obnovit
	CALL	R57K6		; 17T	adresa do DE
	LD	E, L		;  4T	
	CALL	R57K6		; 17T
	LD	D, L		;  4T	
	DEC	C		;  4T	je typ bloku 2?
	JP	NZ, LAUNCH	; 10T	ak ano, tak priprav spustenie
	CALL	R57K6		; 17T	ak nie, citaj data
	LD	C, L		;  4T	dlzka dat do BC 
	DEC	DE		;  6T	zniz o 1, v RDBITS sa zvysi naspat
	CALL	R57K6		; 17T
	LD	B, L		;  4T

; a potom sa citaju data

RDDATA:	JR	RDBYTE		; 12T	nacitaj uplne prvy bajt
JPERR:	JP	ERROR		; 10T	odkaz na hlasenie chyby

; --- nacitanie jedneho bajtu dat ---

RDBYTE: LD	A, 110b		;  7T(73)	mapuj port
	OUT	(LS174)	, A	; 11T(84)
STOP2:	LD	A, (HL)		;  7T(91)	nacitaj port
	AND	01000000b	;  7T(14)	vymaskuj 6. bit
	JR	Z, JPERR	; 12T/7T(26/21)	este musi trvat stop-bit
START2:	LD	A, (HL)		;  7T		nacitaj port
	AND	01000000b	;  7T(14)	zisti, ci uz je start-bit
	JP	NZ, START2	; 10T(24)	ak nie, este cakaj
	                        
; v najlepsom pripade zo start-bitu uplynie 17T, v najhorsom 41T (co uz je bit0
; do uvahy treba zobrat oba extremy

RDBITS:	AND	0h		;  7T		cakaj 14T
	AND	0h		;  7T		cize 31T až 54T

; nacitanie osmych bitov po start-bite

	LD	A, (HL)		;  7T	nacitaj stav portu ( 38T {35+3} až 61T {70-9} )
	RLCA			;  4T	dvakrat odrotuj 
	RLCA			;  4T	do Carry
	RR	L		;  8T	z Carry buduj vysledny bajt v reg. L
	INC	DE		;  6T	povys adresu 2x, nasledne sa znizi spat o 1
	INC	DE              ;  6T   (35T)
	LD	A, (HL)		;  7T	a opakuj este 7-krat
	RLCA			;  4T
	RLCA			;  4T
	RR	L		;  8T
	DEC	BC		;  6T   zniz pocitadlo dat
	DEC     DE              ;  6T   (35T)
	LD	A, (HL)		;  7T
	RLCA			;  4T	
	RLCA			;  4T	
	RR	L		;  8T	
	NOP			;  4T	dummy 11T
	LD	A, (HL)		;  7T
	LD	A, (HL)		;  7T	
	RLCA			;  4T	
	RLCA			;  4T	
	RR	L		;  8T	
	BIT	6, (HL)		; 12T   dummy 12T
	LD	A, (HL)		;  7T	
	RLCA			;  4T	
	RLCA			;  4T	
	RR	L		;  8T	
	BIT	6, (HL)		; 12T   dummy 12T
	LD	A, (HL)		;  7T	
	RLCA			;  4T	
	RLCA			;  4T	
	RR	L		;  8T	
	NOP			;  4T	dummy 11T
	LD	A, (HL)		;  7T
	LD	A, (HL)		;  7T	
	RLCA			;  4T	
	RLCA			;  4T	
	RR	L		;  8T	
	BIT	6, (HL)		; 12T   dummy 12T
	LD	A, (HL)		;  7T	
	RLCA			;  4T(11)
	RLCA			;  4T(15)

; --- slucka na citanie dat, pocet bajtov je v BC ---
	
; ulozenie nacitaneho bajtu do RAM

RDATA1:	LD	A, 010b		;  7T(22)	video off, map allram
	OUT	(LS174)	, A	; 11T(33)
	LD	A, L		;  4T(37)
	RRA			;  4T(41)	docitaj 7. bit
	LD	(DE), A		;  7T(48)	uloz nacitany bajt
	LD	A, B		;  4T(52)	skontroluj, ci je koniec
	OR	C		;  4T(56)
	JP	NZ, RDBYTE	; 10T(66)	priamy skok na citanie

; po nacitani celej dlzky dat musi nasledovat hlavicka
; kvoli setreniu T nenasleduje skok, ale priamo pokracuje R57K6
; navrat spat je cez ulozenu hodnotu IX v zasobniku na RDHDR1

; --- synchronizacia podla hrany stop-bitu a start-bitu (zmena 1->0)

; nacitanie stop-bitu a start-bitu sa lisi podla toho,
; ci sa jedna o hlavicku alebo data - maju ale rovnaky pocet T	

; --- nacitanie jedneho bajtu hlavicky ---

R57K6:	LD	A, 110b		;  7T		mapuj port
	OUT	(LS174)	, A	; 11T
STOP1:	LD	A, (HL)		;  4T
	AND	01000000b	;  7T		vymaskuj 6. bit
	JR	Z, ERROR	; 12T/7T	este musi trvat stop-bit
START1:	LD	A, (HL)		;  4T
	AND	01000000b	;  7T		zisti, ci uz je start-bit
	JP	NZ, START1	; 10T		ak nie, este cakaj
	
; po zisteni start-bitu sa caka na 0. bit

	AND	0h		;  7T   dummy
	AND	0h		;  7T
		
; nacitanie 8 bitov hlavicky	                        

        LD	A, (HL)		;  7T
	RLCA			;  4T
	RLCA			;  4T	
	RR	L		;  8T	
	BIT	6, (HL)		; 12T   dummy
	LD	A, (HL)		;  7T	
	RLCA			;  4T	
	RLCA			;  4T	
	RR	L		;  8T	
	BIT	6, (HL)		; 12T   dummy
	LD	A, (HL)		;  7T	
	RLCA			;  4T	
	RLCA			;  4T	
	RR	L		;  8T		
	NOP
	LD	A, (HL)		;  7T	dummy
	LD	A, (HL)		;  7T	
	RLCA			;  4T	
	RLCA			;  4T	
	RR	L		;  8T	
	BIT	6, (HL)		; 12T   dummy
	LD	A, (HL)		;  7T
        RLCA			;  4T
	RLCA			;  4T	
	RR	L		;  8T	
	BIT	6, (HL)		; 12T   dummy
	LD	A, (HL)		;  7T	
	RLCA			;  4T	
	RLCA			;  4T	
	RR	L		;  8T	
	BIT	6, (HL)		; 12T   dummy
	LD	A, (HL)		;  7T	
	RLCA			;  4T	
	RLCA			;  4T	
	RR	L		;  8T	
	NOP
	LD	A, (HL)		;  7T	dummy
	LD	A, (HL)		;  7T	
	RLCA			;  4T	
	RLCA			;  4T	
	RR	L		;  8T	
        RET                     ; 10T

; ak vsetko dobre dopadlo, moze sa program spustit
	
LAUNCH:	JP      RUN

; ak dojde k chybe (nebol zisteny stop-bit), tak to oznam	
	
ERROR:	LD	C, 128		; zapipaj SOS
	LD	B, 15
	CALL    BEEP
	LD	HL, 4000h
	CALL    WAIT
	LD	C, 128
	LD	B, 15
	CALL    BEEP
	LD	HL, 4000h
	CALL    WAIT
	LD	C, 128
	LD	B, 15
	CALL    BEEP
	LD	A, 000b		;  map ROM
	OUT	(LS174)	, A
 	JP      0000h           ; a cold boot


; -------------------------------
; L O A D E R   5 8   pro takt CPU 4 MHz
; -------------------------------
; Pri 4 MHz trva bitova bunka 57600 Bd 69T misto 35T, takze se cteni
; bajtu vejde do smycky a nemusi byt rozbalene jako verze pro 2 MHz - tento
; kod je kratsi nez ta.
;
; Casovani NENI jen zdvojnasobene oproti verzi pro 2 MHz: samotna detekce
; start-bitu trva v obou taktech stejnych 17-41T (je to ta sama smycka),
; ale bunka je dvakrat sirsi. Vzorkuje se proto ve stredu bunky:
;   - od detekce start-bitu po prvni vzorek 75T (2 MHz: 21T)
;   - mezi vzorky 69T            (2 MHz: 35T, obe -0,6% / +0,8%)
;   - od posledniho vzorku po kontrolu stop-bitu nejvyse 107T (2 MHz: 91T)
;
; Pocet bitu se nepocita v B, ale zarazkou 80h v L: po osmi posunech
; vypadne z L do Carry. B tak zustava volne pro pocitadlo delky dat.
; -------------------------------
LDR584:	LD	A, 110b		; ram + port od E000
	OUT	(LS174)	, A

; nacitaji se 3 nebo 5 bajtu hlavicky

HDR4:	CALL	RB584		; typ bloku
	LD	C, L
	CALL	RB584		; adresa do DE
	LD	E, L
	CALL	RB584
	LD	D, L
	DEC	C		; je typ bloku 2?
	JP	NZ, LAUNCH	; pokud ano, tak priprav spusteni
	CALL	RB584		; pokud ne, cti delku dat
	LD	C, L
	CALL	RB584
	LD	B, L

; --- smycka pro cteni dat, pocet bajtu je v BC ---
; cteni bajtu je tu rozepsane, aby se ulozeni do RAM a pocitadla stihly
; jeste v mezere mezi bajty

DATA4:	LD	A, 110b		;  7T	namapuj port
	OUT	(LS174)	, A	; 11T
	LD	L, 80h		;  7T	zarazka pro pocitani 8 bitu
DSTOP4:	LD	A, (HL)		;  7T	nacti port
	AND	01000000b	;  7T	vymaskuj 6. bit
	JP	Z, ERROR	; 10T	jeste musi trvat stop-bit
DSTRT4:	LD	A, (HL)		;  7T	nacti port
	AND	01000000b	;  7T	zjisti, zda uz je start-bit
	JP	NZ, DSTRT4	; 10T	pokud ne, jeste cekej
	PUSH	BC		; 11T	vypln navic: detekce start-bitu trva
	POP	BC		; 10T	stejnych 17-41T jako pri 2 MHz, ale bunka
	LD	A, (TPAD)	; 13T	je dvakrat sirsi - bez toho by prvni
				;	vzorek padl jeste do start-bitu
DBIT4:	PUSH	BC		; 11T	vypln
	POP	BC		; 10T
	LD	A, (TPAD)	; 13T	(dohromady 34T)
	LD	A, (HL)		;  7T	vzorkuj port
	RLCA			;  4T	dvakrat odrotuj
	RLCA			;  4T	do Carry
	RR	L		;  8T	z Carry buduj vysledny bajt v reg. L
	JR	NC, DBIT4	; 12T	dohromady 69T na bit, po 8. vypadne zarazka
	LD	A, 010b		;  7T	video off, map allram
	OUT	(LS174)	, A	; 11T
	LD	A, L		;  4T
	LD	(DE), A		;  7T	uloz nacteny bajt
	INC	DE		;  6T
	DEC	BC		;  6T	sniz pocitadlo dat
	LD	A, B		;  4T	zkontroluj, zda je konec
	OR	C		;  4T
	JP	NZ, DATA4	; 10T	(dohromady 59T)
	JP	HDR4		; po datech nasleduje dalsi hlavicka

; --- nacteni jednoho bajtu hlavicky do L ---

RB584:	LD	A, 110b		;  7T	namapuj port
	OUT	(LS174)	, A	; 11T
	LD	L, 80h		;  7T	zarazka pro pocitani 8 bitu
RSTOP4:	LD	A, (HL)		;  7T	nacti port
	AND	01000000b	;  7T	vymaskuj 6. bit
	JP	Z, ERROR	; 10T	jeste musi trvat stop-bit
RSTRT4:	LD	A, (HL)		;  7T	nacti port
	AND	01000000b	;  7T	zjisti, zda uz je start-bit
	JP	NZ, RSTRT4	; 10T	pokud ne, jeste cekej
	PUSH	BC		; 11T	vypln navic: detekce start-bitu trva
	POP	BC		; 10T	stejnych 17-41T jako pri 2 MHz, ale bunka
	LD	A, (TPAD)	; 13T	je dvakrat sirsi - bez toho by prvni
				;	vzorek padl jeste do start-bitu
RBIT4:	PUSH	BC		; 11T	vypln
	POP	BC		; 10T
	LD	A, (TPAD)	; 13T	(dohromady 34T)
	LD	A, (HL)		;  7T	vzorkuj port
	RLCA			;  4T
	RLCA			;  4T
	RR	L		;  8T
	JR	NC, RBIT4	; 12T	dohromady 69T na bit
	RET			; 10T
; -------------------------------
; konec rutiny LOADER 58 pro 4 MHz
; -------------------------------
