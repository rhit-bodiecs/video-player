.nolist
#include "ti83plus.inc"
.list
.org userMem - 2
.db t2ByteTok, tAsmCmp

Start:
    BCALL(_RunIndicOff)      ; Turn off run indicator
    BCALL(_ClrLCDFull)       ; Clear the LCD completely
    ; Clear screen
    LD     HL, PlotSScreen
    LD     (HL), 0
    LD     DE, PlotSScreen + 1
    LD     BC, 767
    LDIR
    
    LD     HL, videoName
    rst    20h
    CALL   FindData

    CALL   FindData         ; A = page, HL = offset, DE = size
    
    ; DEBUG: Display the values
    PUSH   AF
    PUSH   HL
    PUSH   DE
    
    ; Show size returned by FindData
    LD     H, 2
    LD     L, 0
    LD     (CurRow), HL
    EX     DE, HL
    BCALL(_DispHL)
    EX     DE, HL

    
    ; Wait for keypress
    BCALL(_GetKey)
    
    POP    DE
    POP    HL
    POP    AF
    
    ; Now continue with your init...
    
    ; Initialize ALL state (including decompression state!)
    LD     (FlashPage), A
    INC    HL
    LD     (FlashOffset), HL
    DEC    DE
    LD     (TotalDataSize), DE
    
    XOR    A              ; A = 0
    LD     H, A
    LD     L, A
    LD     (DataConsumed), HL
    LD     (BuffPtr), HL
    LD     (ScreenPtr), HL
    LD     (Mode), A      ; Initialize decompression state!
    LD     (Remain), A
    LD     (CurByte), A

FrameLoop:
    ; Check if we've consumed all data
    LD     HL, (DataConsumed)
    LD     DE, (TotalDataSize)
    OR     A
    SBC    HL, DE
    JP     Z, EndVid
    JP     NC, EndVid
    
    ; Check if next read would cross page boundary
    LD     HL, (FlashOffset)
    LD     DE, 768
    ADD    HL, DE              ; HL = FlashOffset + 768 (where we'd end up)
    BIT    6, H                ; Check if >= 0x4000
    JR     Z, SimpleLoad       ; No crossing, simple case
    
    ; Page crossing case - need to load in two chunks
    ; First chunk: from current offset to end of page (0x4000)
    LD     HL, (FlashOffset)
    LD     DE, 4000h
    OR     A
    SBC    HL, DE              ; HL = FlashOffset - 0x4000
    LD     H, D
    LD     L, E
    LD     DE, (FlashOffset)
    OR     A
    SBC    HL, DE              ; HL = bytes remaining in current page
    PUSH   HL                  ; save chunk1 size
    
              ; BC = chunk1 size
    LD     B, H
    LD     C, L
    LD     A, (FlashPage)
    LD     HL, (FlashOffset)
    LD     DE, SaveSScreen
    BCALL(_FlashToRAM)
    
    ; Second chunk: from start of next page
    POP    BC                  ; BC = chunk1 size
    LD     HL, SaveSScreen
    ADD    HL, BC              ; HL = SaveSScreen + chunk1_size
    EX     DE, HL              ; DE = destination for chunk2
    
    LD     A, (FlashPage)
    INC    A
    LD     (FlashPage), A      ; increment page
    
    LD     HL, 0               ; start of new page
    LD     (FlashOffset), HL
    
    LD     HL, 768
    OR     A
    SBC    HL, BC              ; HL = 768 - chunk1_size = chunk2_size
    LD     B, H
    LD     C, L                ; BC = chunk2_size
    BCALL(_FlashToRAM)
    
    JR     LoadDone

SimpleLoad:
    ; Normal case - single FlashToRAM call
    LD     A, (FlashPage)
    LD     HL, (FlashOffset)
    LD     DE, SaveSScreen
    LD     BC, 768
    BCALL(_FlashToRAM)

LoadDone:
    ; Reset buffer pointer for new frame
    LD     HL, 0
    LD     (BuffPtr), HL
    
    ; Continue to DecompLoop...
    
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
    INC A                       ;get count 
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

    ; Update DataConsumed
    LD     HL, (BuffPtr)
    LD     DE, (DataConsumed)
    ADD    HL, DE
    LD     (DataConsumed), HL
    
    ; Update FlashOffset (simple add, boundary handled in FrameLoop)
    LD     HL, (FlashOffset)
    LD     DE, (BuffPtr)
    ADD    HL, DE
    LD     (FlashOffset), HL
    
    ; Reset state
    XOR    A
    LD     H, A
    LD     L, A
    LD     (ScreenPtr), HL
    LD     (BuffPtr), HL
    LD     (Mode), A
    LD     (Remain), A
    LD     (CurByte), A

    JP     FrameLoop

FindData:
    BCALL(_ChkFindSym)
    jr     c, errorNotFound
    ld     a, b
    or     a
    jr     z, itemIsInRAM
    push   de
    ex     de, hl
    ld     de, 8000h
    ld     bc, 30
    BCALL(_FlashToRAM)
    ld     a, (8009h)
    ld     hl, 800Ah
    add    a, l
    ld     l, a          
    adc    a, h
    sub    l
    ld     h, a
    ld     e, (hl)
    inc    hl
    ld     d, (hl)
    ld     a, (8008h)
    pop    bc
    res    7, h
    add    hl, bc
    bit    7, h
    ret    z
    res    7, h
    inc    a
    ret

errorNotFound:
    RET
    
itemIsInRAM:
    RET

videoName:
    .DB    15h, "VIDEO", 0, 0, 0

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