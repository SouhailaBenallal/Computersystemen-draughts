; -------------------------------------------------------------------
; 80386
; 32-bit x86 assembly language
; TASM
;
; author:	Niels Koops
; date:		20/11/2021
; program:	dammen (tussentijds)
; -------------------------------------------------------------------

IDEAL
P386
MODEL FLAT, C
ASSUME cs:_TEXT,ds:FLAT,es:FLAT,fs:FLAT,gs:FLAT

INCLUDE "mouse.inc"

SCREEN_WIDTH EQU 320	; screen width
SCREEN_HEIGHT EQU 200	; screen height
VMEMADR EQU 0A0000h	; video memory address

; -------------------------------------------------------------------
CODESEG


STRUC Piece
	position	dd 0 ; positions, from left to right, top down every black field + 1, see wiki
	color		dd 0 ; 0 for white, 1 for black
	dame		dd 0 ; 0 for normal piece, 1 for dame
	sprite 		dd 0 ; 0 on initialization, but gets pointer
ENDS Piece

;______________________________________________

PROC drawSprite
	ARG @@spritePtr :dword, \
		@@dstPtr :dword, \
		@@x:dword, \
		@@y:dword
	LOCAL @@w:dword, @@h:dword
	USES eax , ebx , ecx , edx , esi , edi
	mov esi , [ @@spritePtr ]
	xor eax , eax
	lodsw ; read width in AX
	mov [@@w] , eax
	lodsw ; read he igh t in AX
	mov [@@h] , eax
	mov edi , [ @@dstPtr ]
	mov eax , [@@y]
	mov ebx , SCREEN_WIDTH
	mul ebx
	add edi , eax
	add edi , [@@x] ; EDI po in ts to f i r s t p i x e l
	mov ecx , [@@h]
	@@drawLine :
	push ecx
	mov ecx , [@@w] ; need to copy a l in e o f the s p r i t e
	rep movsb ; copy from e s i to ed i
	add edi , SCREEN_WIDTH
	sub edi , [@@w] ; ed i now po in ts to the next l in e in d s t
	pop ecx
	dec ecx
	jnz @@drawLine
	ret
ENDP drawSprite

;______________________________________________

PROC setVideoMode
	ARG 	@@VM:byte
	USES 	eax

	movzx ax,[@@VM]
	int 10h

	ret
ENDP setVideoMode

;______________________________________________

; Fill the background (for mode 13h) faster
; (uses stosd optimization)
;	* fillcolor: input color
PROC fillBackgroundFaster
	ARG 	@@fillcolor:byte
	USES 	eax, ecx, edi

	; Initialize video memory address.
	mov	edi, VMEMADR
	
	; copy color value across all bytes of eax
	mov al, [@@fillcolor]	; ???B
	mov ah, al				; ??BB
	mov cx, ax			
	shl eax, 16				; BB00
	mov ax, cx				; BBBB

	; Scan the whole video memory and assign the background colour.
	mov	ecx, SCREEN_WIDTH*SCREEN_HEIGHT/4
	rep	stosd

	ret
ENDP fillBackgroundFaster

;______________________________________________

PROC terminateProcess
	USES eax,ecx
	call setVideoMode, 03h
	mov	ax,04C00h
	int 21h
	ret
ENDP terminateProcess

;______________________________________________

PROC waitForSpecificKeystroke
	ARG 	@@key:byte
	USES 	eax

	@@waitForKeystroke:
		mov	ah,00h
		int	16h
		cmp	al,[@@key]
	jne	@@waitForKeystroke

	ret
ENDP waitForSpecificKeystroke

;______________________________________________

PROC drawboard
	USES eax ,ebx ,ecx, edx
	
	mov edx, offset whitetile
	
	mov ecx, 10
	
	xor ebx, ebx
	mov ebx, 0
	
@@loopheight:
	
	push ecx
	mov ecx, 10
	xor eax,eax
	
@@loopwidth:
	call drawSprite, edx, VMEMADR, eax, ebx
	
	call flipbrownwhitetile, edx

	add eax, 20
	loop @@loopwidth
	
	call flipbrownwhitetile, edx
	
	add ebx, 20	
	pop ecx
	loop @@loopheight
	
	ret
ENDP drawboard

;______________________________________________

PROC flipbrownwhitetile
	ARG @@currenttile:dword RETURNS edx
	
	mov edx, [@@currenttile]
	cmp edx, offset browntile
	je @@changetowhite
	mov edx, offset browntile
	jmp @@changedtile
@@changetowhite:
	mov edx, offset whitetile
@@changedtile:

	ret
ENDP flipbrownwhitetile

;______________________________________________

PROC mouseHandler
    USES    eax, ebx, ecx, edx
	
	call 	drawboard
	call 	displaypieces, offset whitePieces
	call 	displaypieces, offset blackPieces
	
	and bl, 3			; check for two mouse buttons (2 low end bits)
	;jz @@skipit			; only execute if a mousebutton is pressed

    movzx eax, dx		; get mouse height
	mov edx, SCREEN_WIDTH
	mul edx				; obtain vertical offset in eax
	sar cx, 1			; horizontal cursor position is doubled in input 
	add ax, cx			; add horizontal offset
	add eax, VMEMADR	; eax now contains pixel address mouse is pointing to
	
	call drawSprite, offset mousecursor, eax, 0,0
	
	;mov [eax], bl	; change color

	@@skipit:
    ret
ENDP mouseHandler

;______________________________________________

PROC initpieces
	ARG	@@arrayptr:dword, @@spriteptr:dword
	USES eax, ebx, ecx, edx
	
	mov ebx, [@@arrayptr]
	mov ecx, 20

@@loopinit:
	
	mov eax, [@@spriteptr]
	mov [ebx + Piece.sprite], eax
	add [ebx + Piece.position], ecx
	
	add ebx, 16
	
	loop @@loopinit
	
	ret
ENDP initpieces

;______________________________________________

PROC displaypieces
	ARG	@@arrayptr:dword
	USES eax, ebx, ecx, edx
	
	mov ebx, [@@arrayptr]
	mov ecx, 20
	
@@loopdisplay:
	push ecx
	mov eax, [ebx + Piece.position]
	sub eax, 1
	
	xor edx, edx
	mov ecx, 5
	div ecx
	
	push edx
	
	mov ecx, eax
	
	mov edx, 20
	mul edx
	
	xchg eax, ecx
	
	and ax, 1
	jz @@even
	jmp @@odd
@@even:
	pop eax
	mov edx, 40
	mul edx
	add eax, 20
	jmp @@done
@@odd:
	pop eax
	mov edx, 40
	mul edx
@@done:
	
	call drawSprite, [ebx + Piece.sprite], VMEMADR, eax, ecx
	add ebx, 16
	
	pop ecx
	loop @@loopdisplay
	
	ret

ENDP displaypieces

;______________________________________________

PROC main
	sti
	cld
	
	push ds
	pop	es
	
	call    mouse_present
    cmp     eax, 1
    je      @@mouse_present

    mov     ah, 9
    mov     edx, offset msg_no_mouse
    int     21h

@@mouse_present:
	
	call	setVideoMode,13h
	
	call 	mouse_install, offset mouseHandler
;______________________________________________
	
	call	fillBackgroundFaster, 0

	call 	drawboard
	call 	initpieces, offset whitePieces, offset whitepiecesprite
	call 	initpieces, offset blackPieces, offset blackpiecesprite
	
	call 	displaypieces, offset whitePieces
	call 	displaypieces, offset blackPieces
;______________________________________________

	call	waitForSpecificKeystroke, 001Bh
	call 	mouse_uninstall
	call 	terminateProcess
ENDP main

; -------------------------------------------------------------------
DATASEG

	whitePieces Piece 20 DUP (<0,0,0,0>)
	blackPieces Piece 20 DUP (<30,1,0,0>)
		
	browntile dw 20, 20
		db 400 DUP (6)
		
		
	whitetile dw 20, 20
		db 400 DUP (15)
		
	blackpiecesprite dw 20, 20
		db 68 	DUP (6)
		db 4 	DUP (0)
		db 14 	DUP (6)
		db 8 	DUP	(0)
		db 11 	DUP (6)
		db 10 	DUP (0)
		db 9 	DUP (6)
		db 12 	DUP (0)
		db 8 	DUP (6)
		db 12 	DUP	(0)
		db 7 	DUP (6)
		db 6	DUP (0)
		db 2 	DUP (8)
		db 6	DUP (0)
		db 6	DUP (6)
		db 5	DUP (0)
		db 4 	DUP (8)
		db 5 	DUP (0)
		db 6	DUP (6)
		db 5	DUP (0)
		db 4 	DUP (8)
		db 5 	DUP (0)
		db 6 	DUP (6)
		db 6	DUP (0)
		db 2 	DUP (8)
		db 6	DUP (0)
		db 7	DUP (6)
		db 12 	DUP	(0)
		db 8 	DUP (6)
		db 12 	DUP (0)
		db 9 	DUP (6)
		db 10 	DUP (0)
		db 11 	DUP (6)
		db 8 	DUP	(0)
		db 14 	DUP (6)
		db 4 	DUP (0)
		db 68 	DUP (6)
		
	
	whitepiecesprite dw 20, 20
		db 68 	DUP (6)
		db 4 	DUP (15)
		db 14 	DUP (6)
		db 8 	DUP	(15)
		db 11 	DUP (6)
		db 10 	DUP (15)
		db 9 	DUP (6)
		db 12 	DUP (15)
		db 8 	DUP (6)
		db 12 	DUP	(15)
		db 7 	DUP (6)
		db 6	DUP (15)
		db 2 	DUP (8)
		db 6	DUP (15)
		db 6	DUP (6)
		db 5	DUP (15)
		db 4 	DUP (8)
		db 5 	DUP (15)
		db 6	DUP (6)
		db 5	DUP (15)
		db 4 	DUP (8)
		db 5 	DUP (15)
		db 6 	DUP (6)
		db 6	DUP (15)
		db 2 	DUP (8)
		db 6	DUP (15)
		db 7	DUP (6)
		db 12 	DUP	(15)
		db 8 	DUP (6)
		db 12 	DUP (15)
		db 9 	DUP (6)
		db 10 	DUP (15)
		db 11 	DUP (6)
		db 8 	DUP	(15)
		db 14 	DUP (6)
		db 4 	DUP (15)
		db 68 	DUP (6)
		
	mousecursor dw 6 , 6 ; W = 8 , h = 8
		db 6 DUP (0)
		db 0
		db 4 DUP (15)
		db 0
		db 0
		db 4 DUP (15)
		db 0
		db 0
		db 4 DUP (15)
		db 0
		db 0
		db 4 DUP (15)
		db 0
		db 6 DUP (0)
	
	msg_no_mouse    db 'No mouse found!', 0dh, 0ah, '$'
		
; -------------------------------------------------------------------
; STACK
; -------------------------------------------------------------------
STACK 100h

END main
