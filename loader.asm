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
LDINIT: 	DI
			LD	H, LS373/256	; IN-PORT, staci vyssi bajt
		RET
LDR58:		DI
		LD	H, LS373/256	; IN-PORT, staci vyssi bajt
		LD	IX, RDHDR1	; navratova adresa po nacitani typu bloku
		PUSH	IX		; na zasobnik
		LD	A, 110b		; ram + port od E000
		OUT	(LS174)	, A

; --------------------------------

; nacitaju sa 3 alebo 5 bajtov hlavicky

RDHDR:		JP	R57K6		; 10T	nacitaj typ bloku
RDHDR1:		LD	C, L		;  4T	pocas dvoch citani zostane uchovany v C
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

RDDATA:		JR	RDBYTE		; 12T	nacitaj uplne prvy bajt
JPERR:		JP	ERROR		; 10T	odkaz na hlasenie chyby

; --- nacitanie jedneho bajtu dat ---

RDBYTE: 	LD	A, 110b		;  7T		mapuj port
		OUT	(LS174)	, A	; 11T		pre nedostatok T sa nevyuziva
STOP2:		LD	A, (HL)		;  4T		nacitaj port
		AND	01000000b	;  7T		vymaskuj 6. bit
		JR	Z, JPERR	; 12T/7T	este musi trvat stop-bit
START2:		LD	A, (HL)		;  4T		nacitaj port
		AND	01000000b	;  7T		zisti, ci uz je start-bit
		JP	NZ, START2	; 10T           ak nie, este cakaj
	                        
; v najlepsom pripade zo start-bitu uplynie 11T, v najhorsom 23T
; pri dlzke bitu necelych 35T je potrebna prestavka, kym zacne 0. bit,
; do uvahy treba zobrat oba extremy

RDBITS:		AND	0h		;  7T		cakaj 14T
		AND	0h		;  7T

; nacitanie osmych bitov po start-bite

		LD	A, (HL)		;  7T	nacitaj stav portu
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
		RLCA			;  4T
		RLCA			;  4T

; --- slucka na citanie dat, pocet bajtov je v BC ---

; ulozenie nacitaneho bajtu do RAM

RDATA1:		LD	A, 010b		;  7T	video off, map allram
		OUT	(LS174)	, A	; 11T
		LD	A, L		;  4T
		RRA			;  4T	docitaj 7. bit
		LD	(DE), A		;  7T	uloz nacitany bajt
		LD	A, B		;  4T	skontroluj, ci je koniec
		OR	C		;  4T
		JP	NZ, RDBYTE	; 10T   priamy skok na citanie
				;       navrat cez RET na RDATA1
				; spolu 33T
; po nacitani celej dlzky dat musi nasledovat hlavicka
; kvoli setreniu T nenasleduje skok, ale priamo pokracuje R57K6
; navrat spat je cez ulozenu hodnotu IX v zasobniku na RDHDR1

; --- synchronizacia podla hrany stop-bitu a start-bitu (zmena 1->0)

; nacitanie stop-bitu a start-bitu sa lisi podla toho,
; ci sa jedna o hlavicku alebo data - maju ale rovnaky pocet T	

; --- nacitanie jedneho bajtu hlavicky ---

R57K6:		LD	A, 110b		;  7T		mapuj port
		OUT	(LS174)	, A	; 11T
STOP1:		LD	A, (HL)		;  4T
		AND	01000000b	;  7T		vymaskuj 6. bit
		JR	Z, ERROR	; 12T/7T	este musi trvat stop-bit
START1:		LD	A, (HL)		;  4T
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

LAUNCH:		JP      RUN

; ak dojde k chybe (nebol zisteny stop-bit), tak to oznam

ERROR:		LD	C, 128		; zapipaj SOS
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
; koniec rutiny LOADER 58
; -------------------------------

; -------------------------------
; nacteni jednoho bajtu pri taktu CPU 4 MHz -> L
; -------------------------------
; Pri 4 MHz trva bitova bunka 57600 Bd 69T misto 35T, takze se cteni
; vejde do smycky a nemusi byt rozbalene jako verze pro 2 MHz.
;
; Pozor na vstupni prodlevu: neda se odvodit zdvojnasobenim hodnoty pro 2 MHz.
; Samotna detekce start-bitu trva v obou taktech stejnych 17-41T (je to
; ta sama smycka), ale bunka je dvakrat sirsi - s pouhym zdvojnasobenim by
; prvni vzorek padl jeste do start-bitu a cely bajt by vysel posunuty o bit.
; Vzorkuje se proto ~103T po hrane, tedy ve stredu bunky 0. bitu.
;
; Pocet bitu se nepocita v B, ale zarazkou 80h v L: po osmi posunech
; vypadne z L do Carry. Priznaky pri navratu jsou stejne jako u R57K6 -
; posledni instrukce je RR L, takze Z plati pro nacteny bajt.
; -------------------------------
R57K64:		LD	A, 110b		;  7T	namapuj port
		OUT	(LS174)	, A	; 11T
		LD	L, 80h		;  7T	zarazka pro pocitani 8 bitu
RSTOP4:		LD	A, (HL)		;  7T	nacti port
		AND	01000000b	;  7T	vymaskuj 6. bit
		JP	Z, ERROR	; 10T	jeste musi trvat stop-bit
RSTRT4:		LD	A, (HL)		;  7T	nacti port
		AND	01000000b	;  7T	zjisti, zda uz je start-bit
		JP	NZ, RSTRT4	; 10T	pokud ne, jeste cekej
		PUSH	BC		; 11T	vypln, aby prvni vzorek padl
		POP	BC		; 10T	do stredu bunky 0. bitu
		LD	A, (TPAD)	; 13T	(dohromady 34T)
RBIT4:		PUSH	BC		; 11T	vypln
		POP	BC		; 10T
		LD	A, (TPAD)	; 13T	(dohromady 34T)
		LD	A, (HL)		;  7T	vzorkuj port
		RLCA			;  4T	dvakrat odrotuj
		RLCA			;  4T	do Carry
		RR	L		;  8T	z Carry buduj vysledny bajt v L
		JR	NC, RBIT4	; 12T	dohromady 69T na bit
		RET			; 10T
; -------------------------------