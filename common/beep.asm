; --------------------------------------------
; rutina pre zahratie tonu
; --------------------------------------------
BEEP:		LD	A, C		; ton do A
		AND	11100000b
		OR	00001111b	; ostatne linky zostanu hore, rele zapnute
		OUT	(LS175), A
		LD	H, B
		CALL	WAIT		; cakaj
NOBEEP:		LD	A, 00001111b	; vypni zvuk, rele zapnute
		OUT	(LS175), A
		RET
; --------------------------------------------
; Pri 4 MHz by smycka trvala polovinu realneho casu, coz by prodlevy mezi
; prikazy pro modul Ondra-SD zkratilo pod jeho mez. Projde se proto dvakrat -
; vysledek je stejny realny cas jako pri 2 MHz.
; Pozor: jedna iterace smycky ma 26 T (DEC HL 6, LD A,H 4, OR L 4, JR NZ 12),
; ne 31 T, jak uvadi puvodni komentar u WAIT1 nize.
WAIT:		LD	A, (CPU4)
		OR	A
		JR	Z, WAIT1	; 2 MHz - jeden pruchod
		PUSH	HL		; 4 MHz - dva pruchody
		CALL	WAIT1
		POP	HL
WAIT1:		DEC	HL		; 11T cakacia slucka
		LD	A, H		; 4T
		OR	L		; 4T
		JR	NZ, WAIT1	; 12T, spolu 31T (15,5us) * 65536 = 1s
		RET
; --------------------------------------------
