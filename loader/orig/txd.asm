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
	LD	H, 12		; casova konstanta
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
	LD	B, 21		;  4T      casova konstanta dlzky stop-bitu
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