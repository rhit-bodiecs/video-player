.nolist
#include "ti83plus.inc"
.list
.org userMem - 2
.db t2ByteTok, tAsmCmp
Start:
    BCALL(_RunIndicOff)
    BCALL(_ClrLCDFull)
    ; Clear screen
    LD     HL, PlotSScreen
    LD     (HL), 0
    LD     DE, PlotSScreen + 1
    LD     BC, 767
    LDIR
    
    ; SKIP FLASH LOADING - use test data instead
    LD     HL, testData
    LD     DE, SaveSScreen
    LD     BC, 635         ; copy 635 bytes of test data
    LDIR
    
    XOR    A
    LD     H, A
    LD     L, A
    LD     (BuffPtr), HL
    LD     (ScreenPtr), HL
    LD     (Mode), A
    LD     (Remain), A
    LD     (CurByte), A
    
    ; Jump straight to decompression
    JP     DecompLoop

; ... rest of your DecompLoop code ...
DecompLoop:
    ; Finished frame?
    LD HL, (ScreenPtr)
    LD DE, 768
    OR A
    SBC HL, DE
    JP Z, NewFrame
    LD A, (Mode)
    OR A
    JR NZ, HaveMode

    ; --- Read header ---
    LD HL, (BuffPtr)            ;ld buff pointer
    LD DE, SaveSScreen          ;ld savescreen address
    ADD HL, DE                  ;get relevant header address
    LD A, (HL)                  ;header byte -> A
    LD HL, (BuffPtr)            ;get fresh buff pointer again
    INC HL                      ;incrament to next position
    LD (BuffPtr), HL            ;write back buff pointer
    

    BIT 7, A                    ;check header flag
    JR Z, HeaderLiteral         ;if literal (flag = 0), jump to literal logic

    ; Run
    AND 7Fh                     ;isolate (count-1)
    INC A    
    LD (Remain), A              ;populate Remain counter
    LD A, 2                     ;set Mode to 2 (run)
    LD (Mode), A

    ; Read run byte
    LD HL, (BuffPtr)            
    LD DE, SaveSScreen
    ADD HL, DE
    LD A, (HL)                  ;get run byte
    LD HL, (BuffPtr)
    INC HL
    LD (BuffPtr), HL            ;incrament buff ptr to next header (after run byte)
    LD (CurByte), A             ;populate CurByte appropriately
    JR HaveMode                 ;jump to HaveMode

HeaderLiteral:
    AND 7Fh                     ;isolate (count -1)
    INC A                       ;get count
    LD (Remain), A              ;count -> remain
    LD A, 1                     ;update Mode to 1
    LD (Mode), A
HaveMode:
    LD A, (Mode)                ;Check mode
    CP 1                        ;if 1, jump to literal logic
    JR Z, LiteralMode

    ; Run mode - use stored CurByte
    LD A, (CurByte)             ;run byte -> A
    LD B, A                     ;juggle A -> B
    JR UseRunByte               ;jump to UseRunByte

LiteralMode:
    ; Fetch next literal byte
    LD HL, (BuffPtr)            
    LD DE, SaveSScreen
    ADD HL, DE
    LD B, (HL)                  ;Current Buffer Byte -> B
    LD HL, (BuffPtr)            ;incrament buffer to next pos
    INC HL
    LD (BuffPtr), HL

UseRunByte:
    LD A, B                 ;data byte (run or literal) -> A 
    
    ; XOR into screen
    LD HL, (ScreenPtr)      
    LD DE, PlotSScreen
    ADD HL, DE              ;screen pos -> HL
    XOR (HL)                ; curByte xor prevByte -> A
    LD (HL), A              ; store A into screen pos

    ; Advance screen
    LD HL, (ScreenPtr)      ;clean screen ptr
    INC HL                  ;incrament 
    LD (ScreenPtr), HL      ;write back

    ; Decrement remaining
    LD A, (Remain)          ;remain count -> A
    DEC A                   ;decrease 
    LD (Remain), A          ;writeback 
    JP NZ, DecompLoop       ;if remain != 0, go to decomp loop

    ; Finished this run/literal
    XOR A                   ;0 -> A
    LD (Mode), A            ;reset mode
    JP DecompLoop           ;back to decomp loop
NewFrame:
    BCALL(_GrBufCpy)
    ; For testing - just halt here
    JR $                ; or use: halt / jr $-1

testData:
    .DB $84, $00, $02, $57, $75, $50, $83, $00, $00, $A2, $81, $22, $05, $2A, $AA, $3F 
    .DB $FF, $FA, $A2, $82, $22, $84, $00, $02, $5F, $FF, $D4, $83, $00, $84, $AA, $02
    .DB $BF, $FF, $FA, $81, $AA, $01, $A8, $AA, $84, $00, $81, $77, $00, $70, $82, $00
    .DB $01, $01, $A2, $83, $22, $02, $3F, $FF, $FA, $82, $22, $00, $02, $84, $00, $02
    .DB $57, $FF, $F0, $83, $00, $07, $8A, $A8, $AA, $A8, $AA, $BF, $FF, $FA, $82, $88
    .DB $00, $8A, $84, $00, $02, $17, $F7, $F5, $82, $00, $03, $01, $A2, $22, $20, $81
    .DB $22, $00, $BF, $81, $FF, $00, $A2, $82, $22, $83, $00, $03, $04, $7D, $FF, $DF
    .DB $83, $00, $83, $88, $00, $AF, $82, $FF, $03, $E8, $8B, $88, $8A, $83, $00, $0C
    .DB $55, $57, $FF, $7F, $C0, $17, $00, $17, $A0, $02, $22, $23, $FB, $82, $FF, $03
    .DB $E2, $3F, $A2, $BF, $82, $00, $02, $01, $5F, $DF, $81, $FF, $03, $D5, $1F, $C5
    .DB $DD, $82, $88, $00, $8A, $87, $FF, $82, $00, $00, $01, $81, $77, $00, $7F, $81
    .DB $77, $81, $57, $02, $75, $80, $00, $81, $22, $00, $BF, $86, $FF, $00, $44, $81
    .DB $00, $01, $01, $5F, $81, $FF, $08, $DF, $F5, $5D, $5F, $FD, $FE, $A8, $88, $8A
    .DB $87, $FF, $09, $55, $50, $00, $01, $77, $7F, $77, $FF, $F5, $75, $81, $77, $04
    .DB $BB, $B8, $00, $23, $BF, $86, $FF, $05, $55, $54, $00, $05, $5F, $DF, $81, $FF
    .DB $81, $FD, $00, $5F, $81, $FF, $02, $E8, $88, $AB, $87, $FF, $03, $55, $51, $00
    .DB $11, $83, $77, $04, $F5, $75, $77, $55, $AA, $81, $AB, $00, $BB, $87, $FF, $83
    .DB $55, $01, $FF, $DF, $81, $FF, $81, $D5, $01, $DF, $D5, $87, $FF, $01, $AF, $EA
    .DB $81, $FF, $83, $55, $07, $57, $77, $FF, $F5, $41, $00, $57, $75, $87, $FF, $03
    .DB $FA, $20, $BE, $BB, $83, $DD, $07, $55, $5F, $FD, $DD, $D5, $00, $5D, $55, $88
    .DB $FF, $81, $EA, $01, $AF, $55, $81, $77, $81, $55, $06, $57, $7F, $75, $55, $54
    .DB $10, $01, $82, $FF, $01, $FB, $BB, $84, $FF, $01, $A2, $2A, $81, $DD, $82, $55
    .DB $01, $DF, $FD, $82, $55, $01, $54, $00, $83, $FF, $00, $FE, $85, $FF, $01, $A8
    .DB $F5, $82, $55, $02, $40, $17, $7D, $84, $55, $82, $BB, $02, $AA, $00, $03, $85
    .DB $FF, $02, $54, $01, $44, $81, $00, $02, $01, $DD, $D5, $83, $55, $00, $E8, $81
    .DB $00, $81, $08, $00, $8F, $85, $FF, $84, $00, $00, $17, $85, $55, $84, $00, $04
    .DB $BF, $FF, $FB, $FF, $FB, $81, $FF, $83, $00, $02, $01, $DD, $5D, $84, $55, $00
    .DB $88, $81, $08, $01, $88, $0F, $86, $FF, $83, $00, $00, $15, $86, $55, $00, $80
    .DB $82, $00, $00, $BB, $82, $BF, $00, $BB, $81, $FB, $00, $FF, $83, $00, $87, $55
    .DB $03, $88, $00, $88, $8B, $84, $FF, $00, $EF, $81, $FF, $82, $00, $00, $15, $87
    .DB $55, $00, $80, $81, $00, $08, $3B, $FF, $BB, $FB, $FF, $FB, $AB, $FF, $BB, $82
    .DB $00, $88, $55, $82, $88, $84, $FF, $01, $FE, $AE, $81, $FF, $82, $00, $88, $55
    .DB $00, $80, $81, $00, $08, $FB, $BB, $FF, $BF, $BB, $FB, $AB, $AF, $BF, $82, $00
    .DB $87, $55, $00, $D5, $81, $80, $00, $00, $84, $FF, $03, $FE, $AE, $EF, $FF, $82
    .DB $00, $88, $55, $81, $00, $00, $02, $84, $FF, $00, $FA, $81, $AB, $00, $BB, $81
    .DB $00, $00, $05, $81, $55, $03, $5D, $55, $45, $DD, $82, $55, $02, $88, $08, $8F
    .DB $83, $FF, $04, $EE, $FE, $AE, $EF, $FF, $81, $00, $01, $15, $57, $81, $77, $02
    .DB $55, $57, $75, $82, $55, $01, $80, $00, $81, $BF, $0D, $FF, $FB, $FF, $FE, $FA
    .DB $AA, $AB, $FF, $00, $01, $55, $5F, $77, $7F, $81, $DD, $00, $FD, $82, $55, $01
    .DB $80, $8B, $84, $FF, $03, $EE, $FE, $EE, $EF, $00, $FF
    
; State variables (in RAM, after program code)
FlashPage:      .DB 0
FlashOffset:    .DW 0
TotalDataSize:  .DW 0
DataConsumed:   .DW 0
BuffPtr:        .DW 0
ScreenPtr:      .DW 0
; Decompression state (persistent across frames)
Mode:        .DB 0     ; 0 = need header, 1 = literal, 2 = run
Remain:      .DB 0     ; remaining bytes in current run/literal
CurByte:     .DB 0     ; literal/run byte value
EndVid:
.end
