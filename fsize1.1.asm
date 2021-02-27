; fsize = returns file size in variable for NextBasic  
; em00k / David Saphier 2021 
; 

F_SIZE	EQU 	$AC
	
	device zxspectrumnext
	
	
	macro ESXDOS command
		; macro for calling esxdos commands 
		rst 8
		db command
	endm
	
	macro MP3DOS command,bank
		; macro for call NextBasic PLUS3DOS commands 
		exx
		ld de,command
		ld c,bank
		rst $08
		db $94
	endm

	org 2000h
	
mainstart:
			 
			push iy 									; save IY incase we use it 
						
			ld a,h : or l								; check if a command line is empty 
			jr nz,commandlineOK							; get hl if = 0 then no command line given, else jump to commandlineOK
			ld hl,emptyline								; show help text 
			call print_rst16							; print message 
			jp finish									; else show default help text 
			
commandlineOK:											; command line passed lets parse it, copy to textbuffer 

			ld de,textbuffer : ld b,0
scanline:
			ld a,(hl)									; load char into a 
			cp ":" : jr z,finishscan					; was it : ? then we're done 
			or a : jr z,finishscan						; was it 0 ? 
			cp 13: jr z,finishscan						; or was it return 13 ?
			
			ld (de),a : inc hl : inc de					; none of the above so copy to de and inc addresses 
			djnz scanline								; keep going until b = 0 
finishscan:	

			xor a : ld (de),a							; ensure end of filename has a zero 

			ld hl,textbuffer 							; split textbuffer into strings, start at index 0 (xor a)
			ld de,needle 								; needle = " " 
			call getstringsplit 						; on exit hl = string at index position 0 

			push hl										; for dotcommands  hl 
			pop ix 										; for normal code 
			call getfilesize 							; call esxdos f_stat and retrieve file size as 4byte LONG
			call b2d32									; convert filesize to string  
			ld de,sizevalue								; copy ascii digits to our "BASIC code" 
			ldir 
			
			ld a,1 : ld hl,textbuffer : ld de,needle	; split command line and get index 1 
			call getstringsplit							; hl = var 
			ld a,h : or l : jr z,skipvarsetting			; skip if hl = 0 
			ld a,(hl) : res 5,a							; capitalise 
			cp 65 : jr c,skipvarsetting					; A 
			cp 91 : jr nc,skipvarsetting				; Z 
			
			ld hl,untokenised+4							; save the var in our untokenised basic 
			ld (hl),a 									; we only support 1 char variables 

skipvarsetting:			
			
			ld a,$56 : call getreg : ld (bank6),a 		; store bank thats in slot 6 
			call getbank : push af : nextreg $56,a 		; set slot 6 with a new reserved bank $c000 + 
			ld hl,untokenised							; point to untokenised data 
			ld de,$c000 								; copy it to our bank 
			ld bc,untokenisedend-untokenised			; length 
			ldir 
			call tokenisebasic							; call the tokeniser (also runs the code) 
			ld a,(bank6) : nextreg $56,a 				; get back original slot 6 
			pop af : call free 							; free the bank we reserved 
finish			
			
			xor	a										; xor a 
			pop iy 										; ensure iy is happy 
			ei 
			ret											; back to basic 


; --- main routines 

tokenisebasic:											; a has bank with untokensise basic 
			
			ld b, 0                         			; IN: B=0, tokenise BASIC line
			ld c, a                         			; IN: C=8K bank containing buffer for untokenised BASIC line
			ld hl, $0000              					; IN: HL=offset in bank of buffer for untokenised line
			MP3DOS $01D8,0               				; API IDE_TOKENIZE ($01D8, bank 0) (see NextZXOS_and_esxDOS_APIs.pdf page 22)
			jr nc, Error                    			; If Carry flag unset, tokenize failed
			jr z, Error                     			; If Zero flag set, tokenize failed
						
			; hl offset in bank and still set to 0 
			MP3DOS $01C0,0              				; API IDE_BASIC ($01C0, bank 0) (see NextZXOS_API.pdf page 18)
Error:
			ret 


untokenised:
			db "LET T = "
sizevalue:
			ds 14,13 
untokenisedend: 

getfilesize: 
			; ix = filename 
			push ix : pop hl 							; hl = filename  
			ld de,bufferfs								; buffer to write data to 
			ld a, '*' 
			ESXDOS F_SIZE								; esxdos f_stat 
			jr c,failopen								; failed to open 
			jr nc,successfs								; success 
			jr donefsizefs
failopen: 
			ld hl,0										; zero file size 
			ld de,0
			jr donefsizefs
successfs:
			ld hl,(bufferfs+7)							; file size success, hlde = size 
			ld de,(bufferfs+9)
donefsizefs:
			ret 
			
			db "em00k 2021"
			
print_rst16	ld a,(hl):inc hl:cp 255:ret z:rst 16:jr print_rst16
print_fname	ld a,(hl):inc hl:cp 0:ret z:rst 16:jr print_fname

getreg:		; in register in a, out value in a 
			ld bc,$243B									; Register Select 
			out(c),a									; 
			ld bc,$253B									; reg access 
			in a,(c)
			ret


getbank:	; returns free bank in a 
			ld hl,$0001  	; H=banktype (ZX=0, 1=MMC); L=reason (1=allocate)
			exx
			ld c,7 										; RAM 7 required for most IDEDOS calls
			ld de,$01bd 								; IDE_bank
			rst $8:defb $94 							; M_P3DOS
			ld a,e 										; bank is in a 
			ret 
				
free:		; in a = bank to free 
			ld hl,$0003  								; H=banktype (ZX=0, 1=MMC); L=reason (1=allocate)
			ld e,a							
			exx							
			ld c,7 										; RAM 7 required for most IDEDOS calls
			ld de,$01bd 								; IDE_bank
			rst $8:defb $94 							; M_P3DOS
			ret 							

; combined routine for conversion of different sized binary numbers into
; directly printable ascii(z)-string
; input value in registers, number size and -related to that- registers to fill
; is selected by calling the correct entry:
;
;  entry  inputregister(s)  decimal value 0 to:
;   b2d8             a                    255  (3 digits)
;   b2d16           hl                  65535   5   "
;   b2d24         e:hl               16777215   8   "
;   b2d32        de:hl             4294967295  10   "
;   b2d48     bc:de:hl        281474976710655  15   "
;   b2d64  ix:bc:de:hl   18446744073709551615  20   "
;
; the resulting string is placed into a small buffer attached to this routine,
; this buffer needs no initialization and can be modified as desired.
; the number is aligned to the right, and leading 0's are replaced with spaces.
; on exit hl points to the first digit, (b)c = number of decimals
; this way any re-alignment / postprocessing is made easy.
; changes: af,bc,de,hl,ix
; p.s. some examples below

; by alwin henseler

b2d8:    	ld h,0
			ld l,a
b2d16:   	ld e,0
b2d24:   	ld d,0
b2d32:   	ld bc,0
b2d48:   	ld ix,0          ; zero all non-used bits
b2d64:   	ld (b2dinv),hl
			ld (b2dinv+2),de
			ld (b2dinv+4),bc
			ld (b2dinv+6),ix ; place full 64-bit input value in buffer
			ld hl,b2dbuf
			ld de,b2dbuf+1
			ld (hl)," "
b2dfilc: equ $-1         ; address of fill-character
			ld bc,18
			ldir            ; fill 1st 19 bytes of buffer with spaces
			ld (b2dend-1),bc ;set bcd value to "0" & place terminating 0
			ld e,1          ; no. of bytes in bcd value
			ld hl,b2dinv+8  ; (address msb input)+1
			ld bc,#0909
			xor a
b2dskp0:	dec b
			jr z,b2dsiz     ; all 0: continue with postprocessing
			dec hl
			or (hl)         ; find first byte <>0
			jr z,b2dskp0
b2dfnd1:	dec c
			rla
			jr nc,b2dfnd1   ; determine no. of most significant 1-bit
			rra
			ld d,a          ; byte from binary input value
b2dlus2:	push hl
			push bc
b2dlus1: 	ld hl,b2dend-1  ; address lsb of bcd value
			ld b,e          ; current length of bcd value in bytes
			rl d            ; highest bit from input value -> carry
b2dlus0: 	ld a,(hl)
			adc a,a
			daa
			ld (hl),a       ; double 1 bcd byte from intermediate result
			dec hl
			djnz b2dlus0    ; and go on to double entire bcd value (+carry!)
			jr nc,bfinishscanxt
			inc e           ; carry at msb -> bcd value grew 1 byte larger
			ld (hl),1       ; initialize new msb of bcd value
bfinishscanxt:  	
			dec c
			jr nz,b2dlus1   ; repeat for remaining bits from 1 input byte
			pop bc          ; no. of remaining bytes in input value
			ld c,8          ; reset bit-counter
			pop hl          ; pointer to byte from input value
			dec hl
			ld d,(hl)       ; get next group of 8 bits
			djnz b2dlus2    ; and repeat until last byte from input value
b2dsiz:  	ld hl,b2dend    ; address of terminating 0
			ld c,e          ; size of bcd value in bytes
			or a
			sbc hl,bc       ; calculate address of msb bcd
			ld d,h
			ld e,l
			sbc hl,bc
			ex de,hl        ; hl=address bcd value, de=start of decimal value
			ld b,c          ; no. of bytes bcd
			sla c           ; no. of bytes decimal (possibly 1 too high)
			ld a,"0"
			rld             ; shift bits 4-7 of (hl) into bit 0-3 of a
			cp "0"          ; (hl) was > 9h?
			jr nz,b2dexph   ; if yes, start with recording high digit
			dec c           ; correct number of decimals
			inc de          ; correct start address
			jr b2dexpl      ; continue with converting low digit
b2dexp:  	rld             ; shift high digit (hl) into low digit of a
b2dexph: 	ld (de),a       ; record resulting ascii-code
			inc de
b2dexpl: 	rld
			ld (de),a
			inc de
			inc hl          ; next bcd-byte
			djnz b2dexp     ; and go on to convert each bcd-byte into 2 ascii
			sbc hl,bc       ; return with hl pointing to 1st decimal
			ret

b2dinv:  	ds 8            ; space for 64-bit input value (lsb first)
b2dbuf:  	ds 20           ; space for 20 decimal digits
b2dend:  	ds 1            ; space for terminating 0


stackb		dw 		0
textbuffer  ds 		256,0
emptyline	db		"v1.1 fsize - David Saphier",13,13,".fsize filename [var]",13,13
			db 		"[var] is a BASIC variable.",13 
			db 		"If left empty the size will be",13 
			db		"returned in T.",13,13
			db 		"eg.",13,13," .fsize TBBLUE.FW a",13 
			db 		"Returns the filesize in a",13
			db		255

bank4		db 	4
bank5		db 	5
bank6		db 	0
bank7		db 	1
bufferfs:	defs 11,0

	include "splitstring.asm" 

endofprog

	savebin "fsize",mainstart,endofprog-mainstart

	IF ((_ERRORS = 0) && (_WARNINGS = 0))
    ;    SHELLEXEC "hdfmonkey.exe put /cygdrive/c/NextBuildv7/Emu/CSpect/cspect-next-2gb.img fsize /dot/fsize"
    ENDIF


;-------------------------------
