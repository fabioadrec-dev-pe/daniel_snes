; Attract crawl: Brasilia Teimosa street names (text only, black BG).
; Enters after TITLE_IDLE_FRAMES on the title. Any button or end of list
; returns to the title. One BG3 32×32 map; rows stream in as it scrolls.

.BANK 0 SLOT 0
.SECTION "Streets" FREE

.DEFINE STREET_ATTR     $24
.DEFINE STREET_PRE_ROWS 4           ; 32px waiting below the 224px screen

EnterStreets:
    sep #$20
    stz NMITIMEN
    lda #INIDISP_FORCEBLANK.b
    sta INIDISP
    jsr HideAllSprites
    jsr DMAOAM
    jsr ClearBG3
    jsr LoadFont
    ; Solid black backdrop (no menu bitmap).
    stz CGADD
    stz CGDATA
    stz CGDATA
    stz MOSAIC
    stz HDMAEN
    rep #$20
    stz street_scroll
    stz street_next
    stz street_src
    sep #$20
    stz street_div
    stz street_row_need
    stz street_map_row
    ; Prime the 4 tile-rows just below the visible area.
    lda #STREET_PRE_ROWS.b
    sta tmp0
ESPrime:
    jsr StreetsSetupFromContent
    jsr StreetsPaintRow
    rep #$20
    inc street_next
    sep #$20
    dec tmp0
    bne ESPrime
    lda #TM_BG3.b
    sta TM
    lda #STATE_STREETS.b
    sta game_state
    lda #INIDISP_FULLBRIGHT.b
    sta INIDISP
    lda #NMITIMEN_NMI_JOY.b
    sta NMITIMEN
    rts

; street_next = content row. Sets street_map_row and street_src.
StreetsSetupFromContent:
    php
    rep #$20
    .ACCU 16
    lda street_next
    clc
    adc #28.w                       ; first new row sits at tile-row 28
    and #$001F.w
    sep #$20
    .ACCU 8
    sta street_map_row
    rep #$20
    .ACCU 16
    lda street_next
    lsr a
    bcs SSCBlank                    ; odd 8px row = gap between names
    cmp #STREET_COUNT.w
    bcs SSCBlank
    asl a
    asl a
    asl a
    asl a
    asl a                           ; line * 32
    sta street_src
    plp
    rts
SSCBlank:
    lda #$FFFF.w
    sta street_src
    plp
    rts

; Write 32 tiles at street_map_row from Streets[street_src], or blanks.
; Force Blank or NMI only.
StreetsPaintRow:
    php
    sep #$20
    .ACCU 8
    rep #$10
    .INDEX 16
    lda #VMAIN_INC_HIGH.b
    sta VMAIN
    lda street_map_row
    rep #$20
    .ACCU 16
    and #$001F.w
    asl a
    asl a
    asl a
    asl a
    asl a
    clc
    adc #VRAM_BG3_MAP
    tax
    jsr SetVRAMAddress
    ; SetVRAMAddress returns with 8-bit A; need 16-bit for street_src / $FFFF.
    rep #$20
    .ACCU 16
    lda street_src
    cmp #$FFFF.w
    beq SPRBlank
    tax
    ldy #32.w
SPRCopy:
    sep #$20
    .ACCU 8
    lda.l Streets,x
    sta VMDATAL
    lda #STREET_ATTR.b
    sta VMDATAH
    inx
    dey
    bne SPRCopy
    plp
    rts
SPRBlank:
    ldy #32.w
SPRBlankL:
    sep #$20
    .ACCU 8
    stz VMDATAL
    stz VMDATAH
    dey
    bne SPRBlankL
    plp
    rts

UpdateStreets:
    sep #$20
    .ACCU 8
    rep #$20
    .ACCU 16
    lda joy_pressed
    ora joy2_pressed
    beq USNoBtn
    jsr EnterTitle
    rts
USNoBtn:
    sep #$20
    .ACCU 8
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
    bcc USKeep
    jsr EnterTitle
    rts
USKeep:
    lda street_scroll
    and #$0007.w
    bne USDone16
    lda street_scroll
    lsr a
    lsr a
    lsr a
    sta street_next
    cmp #STREET_PRE_ROWS.w
    bcc USDone16
    jsr StreetsSetupFromContent
    sep #$20
    .ACCU 8
    lda #1
    sta street_row_need
    rts
USDone16:
    sep #$20
USDone:
    rts

; NMI: optional BG3 row + palette cycle. A 8-bit, index 16-bit on entry.
StreetsNMI:
    sep #$20
    .ACCU 8
    lda game_state
    cmp #STATE_STREETS.b
    bne SNDone
    lda street_row_need
    beq SNPal
    stz street_row_need
    jsr StreetsPaintRow
SNPal:
    ; Cycle BG3 pal 1 color 1 (CGRAM word $05). Mask before TAX (B is not 0).
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
    lda #$05.b
    sta CGADD
    lda StreetPal.w,x
    sta CGDATA
    lda StreetPal+1.w,x
    sta CGDATA
SNDone:
    rts

; BGR555, readable on black with the dark outline.
StreetPal:
    .dw $7FFF, $7FE0, $3FF, $7D1F, $03E0, $3DFF, $7E10, $7FFF

.ENDS
