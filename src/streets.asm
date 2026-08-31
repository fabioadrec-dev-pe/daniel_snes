; Attract crawl: Brasilia Teimosa street names on a Mode 7 plane.
; Star Wars trapezoid via HDMA on M7A (narrow at the top, wide at the bottom).
; Glyph height stays 1:1. The list scrolls up into the horizon.

.BANK 0 SLOT 0
.SECTION "Streets" FREE

EnterStreets:
    sep #$20
    stz NMITIMEN
    lda #INIDISP_FORCEBLANK.b
    sta INIDISP
    stz HDMAEN
    stz MOSAIC
    jsr HideAllSprites
    jsr DMAOAM
    jsr StreetsLoadM7
    jsr StreetsSetupHDMA
    lda #BGMODE_7.b
    sta BGMODE
    lda #M7SEL_NOWRAP.b
    sta M7SEL
    lda #TM_BG1.b
    sta TM
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
    rep #$20
    stz street_scroll
    stz street_next
    sep #$20
    stz street_div
    stz street_row_need
    lda #STATE_STREETS.b
    sta game_state
    lda #INIDISP_FULLBRIGHT.b
    sta INIDISP
    lda #NMITIMEN_NMI_JOY.b
    sta NMITIMEN
    rts

; Pack Mode 7 VRAM in WRAM: even=map tile, odd=8bpp pixel, then one 16-bit DMA.
StreetsLoadM7:
    php
    sep #$20
    .ACCU 8
    rep #$10
    .INDEX 16
    stz CGADD
    ldx #32.w
SLGPal:
    stz CGDATA
    stz CGDATA
    dex
    bne SLGPal
    lda #$01.b
    sta CGADD
    lda #$FF.b
    sta CGDATA
    lda #$7F.b
    sta CGDATA
    lda #$42.b
    sta CGDATA
    lda #$0C.b
    sta CGDATA
    jsr StreetsPackVRAM
    rep #$20
    .ACCU 16
    lda #$2000.w
    sta dma_src
    lda #32768.w
    sta dma_len
    sep #$20
    .ACCU 8
    lda #$7E.b
    sta dma_bank
    ldx #$0000.w
    jsr DmaToVRAM
    plp
    rts

; 16384 words at $7E2000: font pixels in high bytes, street names in low.
StreetsPackVRAM:
    php
    rep #$30
    .ACCU 16
    .INDEX 16
    lda #$0000.w
    tax
SBMZero:
    sta.l $7E2000,x
    inx
    inx
    cpx #$8000.w                    ; 32 KiB
    bne SBMZero
    ; Font 8bpp -> high bytes of words 0..FONT_M7_BYTES-1
    ldx #$0000.w
SBMFont:
    sep #$20
    .ACCU 8
    lda.l FontM7,x
    sta tmp0
    phx
    rep #$20
    .ACCU 16
    txa
    asl a
    inc a
    tax
    sep #$20
    .ACCU 8
    lda tmp0
    sta.l $7E2000,x
    plx
    inx
    cpx #FONT_M7_BYTES.w
    bne SBMFont
    rep #$20
    .ACCU 16
    stz tmp0                        ; line index
SBMLine:
    lda tmp0
    cmp #STREET_COUNT.w
    bcs SBMDone
    xba
    and #$FF00.w
    clc
    adc #48.w
    asl a                           ; byte offset in interleaved buffer
    sta tmp2
    lda tmp0
    asl a
    asl a
    asl a
    asl a
    asl a
    tax
    lda #32.w
    sta tmp1
SBMCopy:
    sep #$20
    .ACCU 8
    lda.l Streets,x
    phx
    ldx tmp2
    sta.l $7E2000,x
    plx
    inx
    rep #$20
    .ACCU 16
    inc tmp2
    inc tmp2
    dec tmp1
    bne SBMCopy
    inc tmp0
    bra SBMLine
SBMDone:
    plp
    rts

; Direct HDMA mode 2: 8.8 scale to M7A only (width taper). Reset A1T every vblank.
StreetsSetupHDMA:
    sep #$20
    .ACCU 8
    lda #DMAP_WRITETWICE.b
    sta DMAP1
    lda #$1B.b                      ; M7A
    sta BBAD1
    rep #$20
    .ACCU 16
    lda #M7Persp
    sep #$20
    .ACCU 8
    sta A1T1L
    xba
    sta A1T1H
    lda #:M7Persp
    sta A1B1
    rts

UpdateStreets:
    sep #$20
    .ACCU 8
    rep #$20
    .ACCU 16
    lda joy_pressed
    ora joy2_pressed
    beq USNoBtn
    jsr EnterMenu
    rts
USNoBtn:
    sep #$20
    .ACCU 8
    ; street_next = frames in this screen (mosaic + unused high)
    rep #$20
    inc street_next
    sep #$20
    inc street_div
    lda street_div
    cmp #STREET_SCROLL_DIV.b
    bcc USDone
    stz street_div
    rep #$20
    .ACCU 16
    inc street_scroll
    lda street_scroll
    cmp #STREET_SCROLL_END.w
    bcc USDone16
    jsr EnterMenu
    rts
USDone16:
    sep #$20
USDone:
    rts

; NMI: arm HDMA, cycle Mode 7 color 1. A 8-bit, index 16-bit.
StreetsNMI:
    sep #$20
    .ACCU 8
    lda game_state
    cmp #STATE_STREETS.b
    bne SNOff
    jsr StreetsSetupHDMA
    lda #HDMAEN_M7.b
    sta HDMAEN
    stz MOSAIC
    lda frame_counter
    lsr a
    lsr a
    lsr a
    and #$07.b
    rep #$20
    .ACCU 16
    and #$00FF.w
    asl a
    tax
    sep #$20
    .ACCU 8
    lda #$01.b
    sta CGADD
    lda StreetPal.w,x
    sta CGDATA
    lda StreetPal+1.w,x
    sta CGDATA
    rts
SNOff:
    stz HDMAEN
    rts

StreetPal:
    .dw $7FFF, $7FE0, $3FF, $7D1F, $03E0, $3DFF, $7E10, $7FFF

.ENDS
