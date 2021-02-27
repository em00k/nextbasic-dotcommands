getstringsplit:
        ; hl = source 
        ; de = needle 
        ; a = index to get 
		; out hl = point to string or zero if not found
        
		ld (source),hl									; save index 
        call countdelimters                             ; 
        ld ix,currentindex                              ; point ix to index table 
        ld hl,(source)                                    ; source string 

        ld (indextoget),a                               ; save index to get 
        or a : jr z,getfirstindex                       

subloop:
        ld de,needle                                    ; point to needle 
        ld a,(de)                                       ; get needle
        ld bc,0
        cpir 
        jr z,foundneedle
        ret 

foundneedle:
        ; hl = location
        push hl                                         ; save hl on stack 
        ld b,a                                          ; save needle in b 
        inc (ix+0)                                      ; inc currentindex 
        ld a,(indextoget)                               ; get the index we want to look for
        cp (ix+0)                                       ; does it match what we're on?
        jr z,wefoundourindex                            ; found our index 
        pop hl                                          ; pop hl from stack
        jr subloop                                      ; loop around 

getfirstindex:
        ; used when index is 0 
        push hl 
        ld a,(needle) : ld b,a : ld c,$ff               ; max  size of string out = $ff

wefoundourindex:
        ; hl = start of string slice 
        ld de,stringtemp                                ; tempstring 

wefoundourindexloop:
        ld a,(hl)                                       ; 
        or a : jr z,copyends                            ; is this next char zero? 
        cp b : jr z,copyends                            ; or the needle?
        ldi                                             ; no then copy to tempstring
        jr wefoundourindexloop                          ; and keep looping 

copyends:
        ex de,hl                                        ; swap de / hl 
        ld (hl), 0                                      ; zero terminate temp string
        ;call printrst                                   ; print it 
        ;ld a,13 : rst 16                                ; add a return 
        xor a : ld (currentindex),a                     ; reset current index for next run 
        pop hl                                          ; pop hl off stack 
		ld hl,stringtemp                                ; point to start of tempstring 
        ret                                             ; done ret

countdelimters
        ld c,a                                          ; save index count 
        ld hl,totalindex
        ld (hl),0
        ld de,(source)
        ld hl,needle
        ld b,(hl)                                       ; pop needle into b 

countdelimtersloop: 
        ld a,(de) : or a : jp z,indexcountdone          ; retrun if zero found
        cp b : call z,increasedelimetercount        
        inc de 
        jr countdelimtersloop

indexcountdone: 
        ld a,(totalindex)
        cp c : jr c,failed 
        ld a,c
        ret  

failed:
        pop hl
		ld hl,0
        ret 

increasedelimetercount:
        ld hl,totalindex
        inc (hl)
        ret 

totalindex:
        db 0 

currentindex:
        db 0     

indextoget:
        db 0 

stringtemp:
        ds 32,0
source:
        dw 0000
needle:
        db " "
        db 0 
