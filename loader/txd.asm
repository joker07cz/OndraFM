; seriove rutiny pre odvysielanie dat
; pred volanim je potrebne
; - zakazat prerusenie
;           DI
; - vypnut zobrazovanie
;           LD	A, 010b		; video off, map allram
;	    OUT	(LS174), A	;
;-------------------------------------------------------------------
;	D7	D6	D5	D4	D3	D2	D1	D0
;	BEEP	BEEP	BEEP	RELE	STB	TXD	LEDY	LEDG
;-------------------------------------------------------------------
TXSTOP	EQU	00001111b
TXSTART	EQU	00001011b
TXMASK	EQU	00000110b	; TXD a zlta LED
TXFILL	EQU	00001010b	; zlta LED


; --------------------------------------------
; odvysielanie bajtu z reg. A na seriovu linku
; rychlostou 9600 Bd, sirka bitu je 208T
; --------------------------------------------
T9600:	;DI
	PUSH	HL		; uloz registre
	PUSH	BC
	LD	L, A		; uschovaj byte
	LD	A, (T96BIT)	; casova konstanta, nastavuje ji CPUDET
	LD	H, A		; podle taktu CPU (12 pri 2 MHz, 28 pri 4 MHz)
	LD	C, 8		; bude 8 bitov
;	LD	A, 010b		; video off, map allram
;	OUT	(LS174), A	;
	LD      A, TXSTART	; ponechaj STB, rele vypni
	OUT	(LS175), A	; 11T      zapni start-bit (log.0)
	RLC	L               ;  8T
	RLC	L		;  8T      0.bit odrotuj na 2.bit	
	LD	B, H		;  4T      casova konstanta dlzky bitu
	NOP			;  4T	   cakaj
	NOP			;  4T
TBIT:	DJNZ	$		; 13T/8T   cakaj
	LD	A, L		;  4T      pouzi uschovany bajt
	AND	TXMASK		;  7T      len 2.bit
	OR	TXFILL		;  7T      a este STB a vypni rele
	OUT	(LS175), A	; 11T      odvysielaj      
	RRC	L		;  8T      prichystaj dalsi bit
	LD	B, H		;  4T      casova konstanta dlzky bitu
	DEC	C               ;  4T
	JR	NZ, TBIT	; 12T/7T   opakuj 8-krat
	DJNZ	$		; 13T/8T   a este stop-bit
	RRC	L		;  8T	   dummy	
	RRC	L		;  8T	   dummy
	LD	A, TXSTOP	;  7T	   nastav stop-bit, vypni LED aj rele
	OUT	(LS175), A	; 11T      odvysielaj 
	LD	A, (T96STP)	; 13T      casova konstanta delky stop-bitu
	LD	B, A		;  4T      (21 pri 2 MHz, 44 pri 4 MHz)
	DJNZ	$		; 13T/8T
	POP	BC		; 10T
	POP	HL		; obnov registre
;	EI
	RET
; --------------------------------------------
; odvysielanie bajtu z reg. A na seriovu linku
; rychlostou 57600 Bd, sirka bitu je 35T (odchylka 1%)
; --------------------------------------------
T57k6:	;DI
	PUSH	AF		; pri 4 MHz je bit dvakrat sirsi v T, odbocit
	LD	A, (CPU4)	; na rutinu casovanou pro 4 MHz
	OR	A
	JR	NZ, T57k6A
	POP	AF
       	PUSH	HL		; uloz registre
	PUSH	BC
	RLCA                    ; prvy posun o jeden bit (vysiela sa cez 2. bit)
	LD	L, A		; uschovaj byte
;	LD	A, 010b		; video off, map allram
;	OUT	(LS174), A	;
	LD      H, TXMASK	; v H bude maska pre skratenie instrukcie AND zo 7T na 4T
	LD	C, TXFILL	; dtto v C
        LD	A, C		; ponechaj STB, rele vypni, zapni LED
	OUT	(LS175), A	; zapni start-bit (log. 0)
				; priprav 0. bit
	RLC	L		;  8T	este jeden posun na 2. bit
	LD	A, L		;  4T    pouzi uschovany bajt
	AND	H       	;  4T    len 2.bit
	OR	C		;  4T    a este STB
	NOP			;  4T	 pockaj
	OUT	(LS175), A	; 11T    odvysielaj
				; spolu 35T, bude sa opakovat este 7-krat
	RRC	L		;  8T    prichystaj dalsi bit
        LD	A, L		;  4T    1
	AND	H       	;  4T
	OR	C		;  4T
	NOP
	OUT	(LS175), A	; 11T
	RRC	L		;  8T
        LD	A, L		;  4T    2
	AND	H       	;  4T
	OR	C		;  4T
	NOP
	OUT	(LS175), A	; 11T
	RRC	L		;  8T
	LD	A, L		;  4T    3
	AND	H       	;  4T
	OR	C		;  4T
	NOP
	OUT	(LS175), A	; 11T
	RRC	L		;  8T
        LD	A, L		;  4T    4
	AND	H       	;  4T
	OR	C		;  4T
	NOP
	OUT	(LS175), A	; 11T
	RRC	L		;  8T
        LD	A, L		;  4T    5
	AND	H       	;  4T
	OR	C		;  4T
	NOP
	OUT	(LS175), A	; 11T
	RRC	L		;  8T
        LD	A, L		;  4T    6
	AND	H       	;  4T
	OR	C		;  4T
	NOP
	OUT	(LS175), A	; 11T
	RRC	L		;  8T
        LD	A, L		;  4T    7
	AND	H       	;  4T
	OR	C		;  4T
	NOP
	OUT	(LS175), A	; 11T
	NOP			;  8T
	NOP
	LD	A, R		;  9T
	LD	A, TXSTOP	;  7T
	OUT	(LS175), A	; 11T	 zapni stop-bit, vypni LED
	POP	BC
	POP	HL		; obnov registre
;	EI
	RET                     ; sirka stop-bitu vznikne automaticky
	                        ; z casov dalsich instrukcii
; --------------------------------------------
; vyslani bajtu z reg. A na seriovou linku
; rychlosti 57600 Bd pri taktu CPU 4 MHz
; sirka bitu je 69T (odchylka -0,6%; u verze pro 2 MHz je 35T, tj. +0,8%)
; --------------------------------------------
; Pri 4 MHz je v bitove bunce dost mista na smycku, takze rutina je
; kratsi nez rozbalena verze pro 2 MHz. Vypln drzi kazdy pruchod na 69T.
; --------------------------------------------
T57k6A:	POP	AF		; sem skace rozbocka na zacatku T57k6
T57k64:	PUSH	HL		; uloz registry
	PUSH	BC
	RLCA			; prvni posun o jeden bit (vysila se pres 2. bit)
	LD	L, A		; uschovej bajt
	LD	H, TXMASK	; maska 2. bitu
	LD	C, TXFILL
	LD	B, 8		; bude 8 bitu
	RLC	L		; druhy posun, 0. bit je na 2. bitu
	LD	A, C		; ponech STB, rele vypni, zapni LED
	OUT	(LS175), A	; 11T	 zapni start-bit (log.0)
	PUSH	BC		; 11T	 vypln, aby 0. bit vysel 69T po start-bitu
	POP	BC		; 10T
TB4:	LD	A, R		;  9T	 vypln
	LD	A, R		;  9T
	LD	A, 0		;  7T	 (dohromady 25T)
	LD	A, L		;  4T	 pouzij uschovany bajt
	AND	H		;  4T	 jen 2. bit
	OR	C		;  4T	 a jeste STB
	OUT	(LS175), A	; 11T	 vysli
	RRC	L		;  8T	 priprav dalsi bit
	DJNZ	TB4		; 13T	 dohromady 69T na bit
	LD	A, (TPAD)	; 13T	 vypln do konce 8. bitu
	LD	A, (TPAD)	; 13T
	LD	A, R		;  9T
	LD	A, TXSTOP	;  7T	 nastav stop-bit, vypni LED i rele
	OUT	(LS175), A	; 11T	 69T po poslednim datovem bitu
	POP	BC
	POP	HL		; obnov registry
	RET
	                        ; z casov dalsich instrukcii