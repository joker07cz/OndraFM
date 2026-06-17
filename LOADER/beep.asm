; --------------------------------------------
BEEP:   LD	A, C		; ton do A
	AND	11100000b
	OR	00001111b	; ostatne linky zostanu hore, rele zapnute
	OUT	(LS175), A
	LD	H, B
	CALL	WAIT		; cakaj
NOBEEP:	LD	A, 00001111b	; vypni zvuk, rele zapnute
	OUT	(LS175), A
	RET
; --------------------------------------------
WAIT:	DEC	HL		; 11T cakacia slucka
	LD	A, H		; 4T
	OR	L		; 4T
	JR	NZ, WAIT	; 12T, spolu 31T (15,5us) * 65536 = 1s
	RET
