; --------------------------------------------
; zjisteni taktu CPU (2 nebo 4 MHz)
; --------------------------------------------
; Ondra muze mit hardwarovou upravu s mechanickym prepinacem taktu 2/4 MHz.
; Zdvojnasobuje se jen procesor - obvody 8253 a video bezi dal na puvodnim
; taktu, takze systemovy citac snimku FRAMES, ktery zvysuje obsluha preruseni
; v ROM, tika 50x za sekundu nezavisle na taktu CPU. Pocet pruchodu odpocitavaci
; smyckou mezi dvema tiky je proto primo merou taktu procesoru.
;
; Prepinac je mechanicky - software ho neprepne ani neprecte a da se cvaknout
; i za behu. Merit se proto musi pred kazdou akci, ktera posila prikazy modulu
; (start, vstup do adresare, nacteni souboru, ...), ne jen jednou pri startu.
;
; Mereni potrebuje povolene preruseni a namapovanou ROM - obsluha je v ROM
; a na 0038h je jen RAM stub, ktery do ni skace. Rutina si port 03H a stinove
; promenne portu 03H a 0AH nastavi sama a na konci obnovi (port 03H na hodnotu
; z A, stiny na puvodni).
;
; vstup:  A = hodnota portu 03H, ktera ma platit po navratu
; vystup: (CPU4) = 0 pri 2 MHz, 1 pri 4 MHz
;         (T96BIT), (T96STP) = casove konstanty pro T9600
; meni:   AF; po navratu je preruseni zakazano (DI)
; pozor:  behem mereni jsou na ~20-40 ms povolena preruseni, takze bezi
;         systemova obsluha - scan klavesnice a blikani kurzoru. Potrebuje
;         platny SP, obsluha uklada 8 polozek.
; --------------------------------------------
FRAMES		EQU	0D62Fh		; systemovy citac snimku (zvysuje ho obsluha preruseni)
PORT3S		EQU	0D627h		; stinova promenna portu 03H
PORT10S		EQU	0D628h		; stinova promenna portu 0AH (obsluha ji zapisuje na port)
; --------------------------------------------
CPUDET:		LD	(SAVPRT), A	; stav portu, ktery ma platit po navratu
		PUSH	HL
		PUSH	DE
		PUSH	BC
		LD	A, (PORT3S)	; uschovej stin portu 03H
		LD	(SAVP3), A
		LD	A, 000b		; ROM dole, video off, bez I/O okna
		LD	(PORT3S), A	; obsluha si port obnovuje ze stinu
		OUT	(LS174), A
; Obsluha preruseni pri kazdem preruseni zapise na port 0AH stinovou promennou
; PORT10. Kdyz v ni je bit 2 (TXD) nebo bit 3 (/STB) v nule - menu ROM+ v1.5
; tam po volbe "Zavest ze site" necha 01 - drzi se linka do modulu OndraSD
; behem celeho mereni v nule a modul pred prvnim prikazem uvidi break misto
; startbitu. Stin se proto na dobu mereni upravi a pak vrati.
		LD	A, (PORT10S)	; uschovej stin portu 0AH
		LD	(SAVP10), A
		OR	00001100b	; TXD a /STB do klidu (1), LED, rele a ton
		LD	(PORT10S), A	; zustavaji, jak byly
		LD	HL, FRAMES
		LD	A, (HL)		; vychozi hodnota citace
		LD	B, 0		; pojistka: kdyby preruseni nechodilo,
		LD	C, 60		; po ~0,2 s to vzda (B ani C nemeni A)
		IM	1		; bez toho by v rezimu 0 skocil CPU tam,
		EI			; co zrovna visi na sbernici (overeno v JOndrovi)
SYNC:		CP	(HL)		;  7T	citac tikl?
		JR	NZ, SYNCED	;  7T
		DJNZ	SYNC		; 13T
		DEC	C
		JR	NZ, SYNC
		XOR	A		; preruseni nechodi -> ber to jako 2 MHz
		JR	STORE
; --- vlastni mereni, overeno na stroji: smycka ma presne 25 T ---
SYNCED:		LD	A, (HL)		; hodnota citace po tiku
		LD	DE, 0
COUNT:		INC	DE		;  6T
		CP	(HL)		;  7T
		JR	Z, COUNT	; 12T	dohromady 25T
		LD	A, D
		CP	9		; hranice mezi 2 a 4 MHz
		LD	A, 0		; (CP nastavil CY, LD priznaky nemeni)
		JR	C, STORE	; D < 9 -> 2 MHz
		INC	A		; jinak 4 MHz
STORE:		DI
		LD	(CPU4), A
		OR	A
		LD	A, 12		; 2 MHz: 208T na bit
		LD	B, 21		;        a 268T na stop-bit
		JR	Z, SETCON
		LD	A, 28		; 4 MHz: 416T na bit
		LD	B, 44		;        a 567T na stop-bit
SETCON:		LD	(T96BIT), A
		LD	A, B
		LD	(T96STP), A
		LD	A, (SAVP10)	; obnov stin portu 0AH
		LD	(PORT10S), A
		LD	A, (SAVP3)	; obnov stin portu
		LD	(PORT3S), A
		POP	BC
		POP	DE
		POP	HL
		LD	A, (SAVPRT)	; a stav portu, ktery si pral volajici
		OUT	(LS174), A
		RET
; --------------------------------------------
CPU4:		DB	0		; 0 = 2 MHz, 1 = 4 MHz
T96BIT:		DB	12		; casova konstanta sirky bitu pro T9600
T96STP:		DB	21		; casova konstanta sirky stop-bitu pro T9600
SAVP3:		DB	0		; uschovany stin portu 03H
SAVP10:		DB	0		; uschovany stin portu 0AH
SAVPRT:		DB	0		; uschovany stav portu 03H pro navrat
TPAD:		DB	0		; cil vyplnovych cteni v 4MHz casovkach
; --------------------------------------------
