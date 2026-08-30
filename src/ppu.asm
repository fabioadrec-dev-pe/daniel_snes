; PPU init, DMA helpers, VRAM/CGRAM/OAM-safe transfers (Force Blank or NMI).

.BANK 0 SLOT 0
.SECTION "PPU" FREE

InitPPU:
    sep #$20
    .ACCU 8
    rep #$10
    .INDEX 16

    lda #INIDISP_FORCEBLANK.b
    sta INIDISP

    lda #BGMODE_1_BG3PRI.b
    sta BGMODE
    stz MOSAIC
    lda #OBJSEL_16_32_AT_6000.b
    sta OBJSEL
    lda #BG1SC_64X32_AT_1000.b
    sta BG1SC
    lda #BG2SC_32X32_AT_1800.b
    sta BG2SC
    lda #BG3SC_32X32_AT_1C00.b
    sta BG3SC
    lda #BG12NBA_BG1_0_BG2_2.b
    sta BG12NBA
    lda #BG34NBA_BG3_5.b
    sta BG34NBA

    stz BG1HOFS
    stz BG1HOFS
    lda #$FF.b
    sta BG1VOFS
    lda #$03.b
    sta BG1VOFS
    stz BG2HOFS
    stz BG2HOFS
    lda #$FF.b
    sta BG2VOFS
    lda #$03.b
    sta BG2VOFS
    stz BG3HOFS
    stz BG3HOFS
    lda #$FF.b
    sta BG3VOFS
    lda #$03.b
    sta BG3VOFS

    stz TM
    stz TS
    stz TMW
    stz TSW
    stz CGWSEL
    stz CGADSUB
    stz SETINI
    stz MEMSEL

    jsr ClearCGRAMBackdrop
    jsr HideAllSprites
    rts

; Main-thread VRAM must run in force blank with NMI off. Otherwise each VMDATA
; write waits for vblank (~1/60s) and FillBG1's 2048-tile clear takes ~30s.
PpuBlankOn:
    php
    sep #$20
    stz NMITIMEN
    lda #INIDISP_FORCEBLANK.b
    sta INIDISP
    plp
    rts

PpuBlankOff:
    php
    sep #$20
    lda #INIDISP_FULLBRIGHT.b
    sta INIDISP
    lda #NMITIMEN_NMI_JOY.b
    sta NMITIMEN
    plp
    rts

; Copy BG2 pal color 0 (CGRAM $10) into backdrop so 4bpp index 0 is not a hole.
CopyBackdropFromBG2:
    sep #$20
    stz dma_dst
    rep #$20
    lda #2
    sta dma_len
    jsr DmaToCGRAM
    rts

LoadFont:
    sep #$20
    rep #$10
    rep #$20
    lda #FontChr
    sta dma_src
    lda #FONT_TILE_COUNT * 16
    sta dma_len
    sep #$20
    lda #:FontChr
    sta dma_bank
    ldx #VRAM_BG3_TILES.w
    jsr DmaToVRAM
    ; BG3 2bpp pal 1 at CGRAM $04. Color 0 clear, 1 white, 2 dark outline.
    ; Words 4–6 overlap BG1 pal 0 colors 4–6; 0–3 of the tileset stay intact.
    lda #$04.b
    sta CGADD
    stz CGDATA
    stz CGDATA
    lda #$FF.b                      ; color 1: white fill
    sta CGDATA
    lda #$7F.b
    sta CGDATA
    lda #$42.b                      ; color 2: dark navy outline (BGR555 $0C42)
    sta CGDATA
    lda #$0C.b
    sta CGDATA
    rts

ClearCGRAMBackdrop:
    sep #$20
    stz CGADD
    lda #BACKDROP_LO.b
    sta CGDATA
    lda #BACKDROP_HI.b
    sta CGDATA
    rts

; X = VRAM word address. A 8-bit on exit.
SetVRAMAddress:
    rep #$20
    .ACCU 16
    txa
    sep #$20
    .ACCU 8
    sta VMADDL
    xba
    sta VMADDH
    rts

; dma_src.w, dma_bank.b, dma_len.w, X = VRAM dest word (16-bit index required)
DmaToVRAM:
    php
    sep #$20
    .ACCU 8
    rep #$10
    .INDEX 16
    lda #VMAIN_INC_HIGH.b
    sta VMAIN
    jsr SetVRAMAddress
    lda #$01.b
    sta DMAP0
    lda #$18.b
    sta BBAD0
    lda dma_src
    sta A1T0L
    lda dma_src+1
    sta A1T0H
    lda dma_bank
    sta A1B0
    lda dma_len
    sta DAS0L
    lda dma_len+1
    sta DAS0H
    lda #$01.b
    sta MDMAEN
    plp
    rts

; Drop Mode 7: Mode 1, identity matrix. Scroll is left to RestoreMode1 / ApplyScroll.
ForceMode1Regs:
    sep #$20
    .ACCU 8
    phk
    plb
    stz HDMAEN
    stz MOSAIC
    lda #BG1SC_64X32_AT_1000.b
    sta BG1SC
    lda #BG2SC_32X32_AT_1800.b
    sta BG2SC
    lda #BG3SC_32X32_AT_1C00.b
    sta BG3SC
    lda #BG12NBA_BG1_0_BG2_2.b
    sta BG12NBA
    lda #BG34NBA_BG3_5.b
    sta BG34NBA
    lda #OBJSEL_16_32_AT_6000.b
    sta OBJSEL
    stz M7SEL
    lda #$00.b
    sta M7A
    lda #$01.b
    sta M7A
    lda #$00.b
    sta M7A
    lda #$01.b
    sta M7A
    stz M7B
    stz M7B
    stz M7C
    stz M7C
    lda #$00.b
    sta M7D
    lda #$01.b
    sta M7D
    stz M7X
    stz M7X
    stz M7Y
    stz M7Y
    stz W12SEL
    stz W34SEL
    stz WOBJSEL
    stz WH0
    lda #$FF.b
    sta WH1
    stz WH2
    lda #$FF.b
    sta WH3
    stz WBGLOG
    stz WOBJLOG
    stz TS
    stz TMW
    stz TSW
    stz CGWSEL
    stz CGADSUB
    stz SETINI
    lda #BGMODE_1_BG3PRI.b
    sta.l $002105
    rts

; After Mode 7 attract: Mode 1 + SNES-typical scroll.
RestoreMode1:
    php
    sep #$20
    jsr ForceMode1Regs
    stz BG1HOFS
    stz BG1HOFS
    lda #$FF.b
    sta BG1VOFS
    lda #$03.b
    sta BG1VOFS
    stz BG2HOFS
    stz BG2HOFS
    lda #$FF.b
    sta BG2VOFS
    lda #$03.b
    sta BG2VOFS
    stz BG3HOFS
    stz BG3HOFS
    lda #$FF.b
    sta BG3VOFS
    lda #$03.b
    sta BG3VOFS
    plp
    rts

; dma_src, dma_bank, dma_len, dma_dst = CGRAM index
DmaToCGRAM:
    sep #$20
    lda dma_dst
    sta CGADD
    stz DMAP0
    lda #$22.b
    sta BBAD0
    lda dma_src
    sta A1T0L
    lda dma_src+1
    sta A1T0H
    lda dma_bank
    sta A1B0
    lda dma_len
    sta DAS0L
    lda dma_len+1
    sta DAS0H
    lda #$01.b
    sta MDMAEN
    rts

; dma_src, dma_bank, dma_len -> WRAM dma_dst (24-bit in dma_dst.w + bank $7E)
DmaToWRAM:
    sep #$20
    lda dma_dst
    sta WMADDL
    lda dma_dst+1
    sta WMADDM
    lda #$7E.b
    sta WMADDH
    stz DMAP0
    lda #$80.b
    sta BBAD0
    lda dma_src
    sta A1T0L
    lda dma_src+1
    sta A1T0H
    lda dma_bank
    sta A1B0
    lda dma_len
    sta DAS0L
    lda dma_len+1
    sta DAS0H
    lda #$01.b
    sta MDMAEN
    rts

; Same dispatch as CopyStageChrCPU. JMP (abs,X) is unreliable here across cores.
CopyToMapWRAM:
    php
    sep #$20
    .ACCU 8
    rep #$10
    .INDEX 16
    lda stage_index
    beq CTFrom0
    cmp #1
    beq CTFrom1
    cmp #2
    beq CTFrom2
    cmp #3
    beq CTFrom3
    ldx #0
CT4L:
    lda.l Stage4,x
    sta.l $7E2000,x
    inx
    cpx dma_len
    beq CTDone
    jmp CT4L
CTFrom0:
    ldx #0
CT0L:
    lda.l Stage0,x
    sta.l $7E2000,x
    inx
    cpx dma_len
    beq CTDone
    jmp CT0L
CTFrom1:
    ldx #0
CT1L:
    lda.l Stage1,x
    sta.l $7E2000,x
    inx
    cpx dma_len
    beq CTDone
    jmp CT1L
CTFrom2:
    ldx #0
CT2L:
    lda.l Stage2,x
    sta.l $7E2000,x
    inx
    cpx dma_len
    beq CTDone
    jmp CT2L
CTFrom3:
    ldx #0
CT3L:
    lda.l Stage3,x
    sta.l $7E2000,x
    inx
    cpx dma_len
    beq CTDone
    jmp CT3L
CTDone:
    plp
    rts

LoadSharedGraphics:
    sep #$20
    rep #$10
    ; OBJ first. 512 tiles fill $6000-$7FFF; extra bytes wrap onto BG1 tileset.
    rep #$20
    lda #SpriteChr
    sta dma_src
    lda #16384
    sta dma_len
    sep #$20
    lda #:SpriteChr
    sta dma_bank
    ldx #VRAM_OBJ_TILES.w
    jsr DmaToVRAM
    ; BG1 tileset after OBJ so a wrap cannot clobber dirt/grass CHR.
    rep #$20
    lda #TilesetChr
    sta dma_src
    lda #TILESET_CHR_BYTES
    sta dma_len
    sep #$20
    lda #:TilesetChr
    sta dma_bank
    ldx #VRAM_BG1_TILES.w
    jsr DmaToVRAM
    ; BG1 palette at CGRAM 0
    rep #$20
    lda #SharedPal
    sta dma_src
    lda #32
    sta dma_len
    sep #$20
    lda #:SharedPal
    sta dma_bank
    stz dma_dst
    jsr DmaToCGRAM
    ; Keep tileset pal 0 for BG1; do not wipe CGRAM[0] here.
    ; BG3 pal at $20 (16 colors, we use 4)
    rep #$20
    lda #SharedPal
    clc
    adc #64
    sta dma_src
    lda #32
    sta dma_len
    sep #$20
    lda #:SharedPal
    sta dma_bank
    lda #$20.b
    sta dma_dst
    jsr DmaToCGRAM
    ; Sprite palettes CGRAM $80
    rep #$20
    lda #SpritePal
    sta dma_src
    lda #256
    sta dma_len
    sep #$20
    lda #:SpritePal
    sta dma_bank
    lda #CGRAM_SPRITE0.b
    sta dma_dst
    jsr DmaToCGRAM
    rts

LoadMenuBG:
    sep #$20
    rep #$10
    rep #$20
    lda #MenuChr
    sta dma_src
    lda #MENU_CHR_BYTES
    sta dma_len
    sep #$20
    lda #:MenuChr
    sta dma_bank
    ldx #VRAM_BG2_TILES.w
    jsr DmaToVRAM
    rep #$20
    lda #MenuMap
    sta dma_src
    lda #BG_MAP_BYTES
    sta dma_len
    sep #$20
    lda #:MenuMap
    sta dma_bank
    ldx #VRAM_BG2_MAP.w
    jsr DmaToVRAM
    rep #$20
    lda #MenuPal
    sta dma_src
    lda #32
    sta dma_len
    sep #$20
    lda #:MenuPal
    sta dma_bank
    lda #$10.b
    sta dma_dst
    jsr DmaToCGRAM
    jsr CopyBackdropFromBG2
    jsr LoadFont
    rts

LoadEndingBG:
    sep #$20
    rep #$10
    rep #$20
    lda #EndingChr
    sta dma_src
    lda #ENDING_CHR_BYTES
    sta dma_len
    sep #$20
    lda #:EndingChr
    sta dma_bank
    ldx #VRAM_BG2_TILES.w
    jsr DmaToVRAM
    rep #$20
    lda #EndingMap
    sta dma_src
    lda #BG_MAP_BYTES
    sta dma_len
    sep #$20
    lda #:EndingMap
    sta dma_bank
    ldx #VRAM_BG2_MAP.w
    jsr DmaToVRAM
LoadEndingVeilPal:
    rep #$20
    lda #EndingVeilPal
    sta dma_src
    lda #32
    sta dma_len
    sep #$20
    lda #:EndingVeilPal
    sta dma_bank
    lda #$10.b
    sta dma_dst
    jsr DmaToCGRAM
    jsr CopyBackdropFromBG2
    jsr LoadFont
    rts

LoadEndingFullPal:
    rep #$20
    lda #EndingPal
    sta dma_src
    lda #32
    sta dma_len
    sep #$20
    lda #:EndingPal
    sta dma_bank
    lda #$10.b
    sta dma_dst
    jsr DmaToCGRAM
    jsr CopyBackdropFromBG2
    jsr LoadFont
    rts

BgChrLo:
    .dw Bg1Chr, Bg2Chr, Bg3Chr, Bg4Chr, Bg5Chr
BgMapLo:
    .dw Bg1Map, Bg2Map, Bg3Map, Bg4Map, Bg5Map
BgPalLo:
    .dw Bg1Pal, Bg2Pal, Bg3Pal, Bg4Pal, Bg5Pal
BgChrBank:
    .db :Bg1Chr, :Bg2Chr, :Bg3Chr, :Bg4Chr, :Bg5Chr
BgChrLen:
    .dw BG1_CHR_BYTES, BG2_CHR_BYTES, BG3_CHR_BYTES, BG4_CHR_BYTES, BG5_CHR_BYTES

LoadStageBG:
    php
    sep #$20
    .ACCU 8
    rep #$10
    .INDEX 16
    jsr CopyStageChrCPU
    jsr CopyStageMapCPU
    lda stage_index
    asl a
    tax
    rep #$20
    lda BgPalLo.w,x
    sta dma_src
    lda #32
    sta dma_len
    sep #$20
    lda stage_index
    tax
    lda BgChrBank.w,x
    sta dma_bank
    lda #$10.b
    sta dma_dst
    jsr DmaToCGRAM
    jsr CopyBackdropFromBG2
    jsr LoadFont
    plp
    rts

; DMA from bank 2 CHR filled VRAM with open-bus $01. lda.l matches the working map copy.
CopyStageChrCPU:
    php
    sep #$20
    .ACCU 8
    rep #$10
    .INDEX 16
    lda #VMAIN_INC_HIGH.b
    sta VMAIN
    ldx #VRAM_BG2_TILES.w
    jsr SetVRAMAddress
    lda stage_index
    beq CSC0
    cmp #1
    beq CSC1
    cmp #2
    beq CSC2
    cmp #3
    beq CSC3
    ldx #0
CSC4L:
    lda.l Bg5Chr,x
    sta VMDATAL
    inx
    lda.l Bg5Chr,x
    sta VMDATAH
    inx
    cpx #BG5_CHR_BYTES.w
    bne CSC4L
    plp
    rts
CSC0:
    ldx #0
CSC0L:
    lda.l Bg1Chr,x
    sta VMDATAL
    inx
    lda.l Bg1Chr,x
    sta VMDATAH
    inx
    cpx #BG1_CHR_BYTES.w
    bne CSC0L
    plp
    rts
CSC1:
    ldx #0
CSC1L:
    lda.l Bg2Chr,x
    sta VMDATAL
    inx
    lda.l Bg2Chr,x
    sta VMDATAH
    inx
    cpx #BG2_CHR_BYTES.w
    bne CSC1L
    plp
    rts
CSC2:
    ldx #0
CSC2L:
    lda.l Bg3Chr,x
    sta VMDATAL
    inx
    lda.l Bg3Chr,x
    sta VMDATAH
    inx
    cpx #BG3_CHR_BYTES.w
    bne CSC2L
    plp
    rts
CSC3:
    ldx #0
CSC3L:
    lda.l Bg4Chr,x
    sta VMDATAL
    inx
    lda.l Bg4Chr,x
    sta VMDATAH
    inx
    cpx #BG4_CHR_BYTES.w
    bne CSC3L
    plp
    rts

CopyStageMapCPU:
    php
    sep #$20
    .ACCU 8
    rep #$10
    .INDEX 16
    lda #VMAIN_INC_HIGH.b
    sta VMAIN
    ldx #VRAM_BG2_MAP.w
    jsr SetVRAMAddress
    lda stage_index
    beq CSM0
    cmp #1
    beq CSM1
    cmp #2
    beq CSM2
    cmp #3
    beq CSM3
    ldx #0
CSM4L:
    lda.l Bg5Map,x
    sta VMDATAL
    inx
    lda.l Bg5Map,x
    sta VMDATAH
    inx
    cpx #BG_MAP_BYTES.w
    bne CSM4L
    plp
    rts
CSM0:
    ldx #0
CSM0L:
    lda.l Bg1Map,x
    sta VMDATAL
    inx
    lda.l Bg1Map,x
    sta VMDATAH
    inx
    cpx #BG_MAP_BYTES.w
    bne CSM0L
    plp
    rts
CSM1:
    ldx #0
CSM1L:
    lda.l Bg2Map,x
    sta VMDATAL
    inx
    lda.l Bg2Map,x
    sta VMDATAH
    inx
    cpx #BG_MAP_BYTES.w
    bne CSM1L
    plp
    rts
CSM2:
    ldx #0
CSM2L:
    lda.l Bg3Map,x
    sta VMDATAL
    inx
    lda.l Bg3Map,x
    sta VMDATAH
    inx
    cpx #BG_MAP_BYTES.w
    bne CSM2L
    plp
    rts
CSM3:
    ldx #0
CSM3L:
    lda.l Bg4Map,x
    sta VMDATAL
    inx
    lda.l Bg4Map,x
    sta VMDATAH
    inx
    cpx #BG_MAP_BYTES.w
    bne CSM3L
    plp
    rts


ApplyScroll:
    sep #$20
    lda game_state
    cmp #STATE_STREETS.b
    beq ASStreets
    jsr ForceMode1Regs
    lda game_state
    cmp #STATE_ENDING.b
    bne ASAfterEnd
    jmp ASEnding
ASAfterEnd:
    lda game_state
    cmp #STATE_PLAY.b
    bcc ASZeroJmp
    cmp #STATE_OVER.b
    bcc ASPlay
ASZeroJmp:
    jmp ASZero
ASPlay:
    lda cam_x
    sta BG1HOFS
    lda cam_x+1
    sta BG1HOFS
    ; Far BG: cam/8 so the 32×32 map does not wrap on a 1536px stage.
    rep #$20
    .ACCU 16
    lda cam_x
    lsr a
    lsr a
    lsr a
    sta tmp0
    sep #$20
    .ACCU 8
    lda tmp0
    sta BG2HOFS
    lda tmp0+1
    sta BG2HOFS
    rts
ASStreets:
    ; Mode 7 + HDMA M7A taper. VOFS = +scroll (names recede toward the horizon).
    lda #<M7_HOFS
    sta BG1HOFS
    lda #>M7_HOFS
    sta BG1HOFS
    lda street_scroll
    sta BG1VOFS
    lda street_scroll+1
    sta BG1VOFS
    ; Identity D (glyph height). HDMA overwrites A per band for the taper.
    lda #$00.b
    sta M7A
    lda #$01.b
    sta M7A
    stz M7B
    stz M7B
    stz M7C
    stz M7C
    lda #$00.b
    sta M7D
    lda #$01.b
    sta M7D
    lda #<M7_CENTER
    sta M7X
    lda #>M7_CENTER
    sta M7X
    stz M7Y
    stz M7Y
    stz BG2HOFS
    stz BG2HOFS
    stz BG3HOFS
    stz BG3HOFS
    rts
ASEnding:
    stz BG1HOFS
    stz BG1HOFS
    stz BG1VOFS
    stz BG1VOFS
    stz BG2HOFS
    stz BG2HOFS
    stz BG2VOFS
    stz BG2VOFS
    stz BG3HOFS
    stz BG3HOFS
    lda end_scroll
    sta BG3VOFS
    lda end_scroll+1
    sta BG3VOFS
    rts
ASZero:
    stz BG1HOFS
    stz BG1HOFS
    lda #$FF.b
    sta BG1VOFS
    lda #$03.b
    sta BG1VOFS
    stz BG2HOFS
    stz BG2HOFS
    lda #$FF.b
    sta BG2VOFS
    lda #$03.b
    sta BG2VOFS
    stz BG3HOFS
    stz BG3HOFS
    lda #$FF.b
    sta BG3VOFS
    lda #$03.b
    sta BG3VOFS
    rts

; Read 14 map rows for nmi_col_mc into col_tiles. Main thread / Force Blank only.
PrepareMetaColumn:
    php
    sep #$20
    .ACCU 8
    rep #$10
    .INDEX 16
    ldy #0
PMCLoop:
    tya
    sta tmp0
    phy
    jsr GetTileColRow
    ply
    sep #$20
    sta col_tiles,y
    iny
    cpy #14
    bne PMCLoop
    plp
    rts

; Paint col_tiles[14] at nmi_col_mc into the 64×32 BG1 map. NMI / Force Blank.
WritePreparedColumn:
    php
    sep #$20
    .ACCU 8
    rep #$10
    .INDEX 16
    lda #VMAIN_INC_HIGH.b
    sta VMAIN
    ldy #0
WPCRow:
    sty tmp_row
    stz tmp_row+1
    lda col_tiles,y
    cmp #8
    bcc WPCIdOk
    lda #0
WPCIdOk:
    asl a
    sta tmp1
    ; SNES 64×32 = two 32×32 screens: addr = $1000 + (x&32)*32 + y*32 + (x&31)
    ; x8 = (mc*2) & 63; y8 = (13-row)*2
    rep #$20
    .ACCU 16
    lda nmi_col_mc
    asl a
    and #63.w
    sta tmp2
    lda #13.w
    sec
    sbc tmp_row
    asl a
    sta tmp0                        ; y8
    lda tmp2
    and #32.w
    asl a
    asl a
    asl a
    asl a
    asl a                           ; (x&32)<<5 = $0000 or $0400
    clc
    adc #VRAM_BG1_MAP
    sta tmp_col                     ; base + screen
    lda tmp0
    asl a
    asl a
    asl a
    asl a
    asl a                           ; y8*32
    clc
    adc tmp_col
    sta tmp_col
    lda tmp2
    and #31.w
    clc
    adc tmp_col
    tax
    jsr SetVRAMAddress
    sep #$20
    .ACCU 8
    lda tmp1
    sta VMDATAL
    stz VMDATAH
    lda tmp1
    inc a
    sta VMDATAL
    stz VMDATAH
    rep #$20
    .ACCU 16
    txa
    clc
    adc #32.w                       ; next 8×8 row in a 32-wide screen
    tax
    jsr SetVRAMAddress
    sep #$20
    .ACCU 8
    lda tmp1
    clc
    adc #16
    sta VMDATAL
    stz VMDATAH
    lda tmp1
    clc
    adc #17
    sta VMDATAL
    stz VMDATAH
    iny
    cpy #14
    beq WPCDone
    jmp WPCRow
WPCDone:
    plp
    rts

WriteMetaColumn:
    jsr PrepareMetaColumn
    jsr WritePreparedColumn
    rts

; tmp0 = row (8), nmi_col_mc = col. Out A = tile
GetTileColRow:
    php
    sep #$20
    .ACCU 8
    rep #$10
    .INDEX 16
    lda tmp0
    cmp #14
    bcs GTCAir
    sta tmp2
    stz tmp2+1
    rep #$20
    .ACCU 16
    lda nmi_col_mc
    cmp map_cols
    bcs GTCAir16
    lda tmp2
    and #$00FF.w
    tay
    lda #0.w
    cpy #0.w
    beq GTCMulZ
GTCMul:
    clc
    adc map_cols
    dey
    bne GTCMul
GTCMulZ:
    clc
    adc nmi_col_mc
    clc
    adc #MAP_HEADER.w
    tax
    sep #$20
    .ACCU 8
    lda.l $7E2000,x
    plp
    rts
GTCAir16:
    sep #$20
GTCAir:
    lda #0
    plp
    rts

FillBG1FromCamera:
    php
    sep #$20
    .ACCU 8
    rep #$10
    .INDEX 16
    lda #VMAIN_INC_HIGH.b
    sta VMAIN
    ldx #VRAM_BG1_MAP.w
    jsr SetVRAMAddress
    ldx #2048.w                     ; 64×32
FBCClr:
    stz VMDATAL
    stz VMDATAH
    dex
    bne FBCClr
    rep #$20
    .ACCU 16
    lda cam_x
    lsr a
    lsr a
    lsr a
    lsr a
    sta last_cam_mt
    ldy #0
FBCLoop:
    rep #$20
    .ACCU 16
    tya
    clc
    adc last_cam_mt
    sta nmi_col_mc
    phy
    jsr WriteMetaColumn
    ply
    iny
    cpy #BG1_MT_COLS
    bne FBCLoop
    plp
    rts

.ENDS
