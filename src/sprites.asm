; OAM buffer in WRAM. DMA in Force Blank or NMI. 16x16 and 32x32.

.BANK 0 SLOT 0
.SECTION "Sprites" FREE

HideAllSprites:
    sep #$20
    .ACCU 8
    rep #$10
    .INDEX 16
    ldx #$0000.w
HideOAMLow:
    stz oam_buffer.w,x
    lda #OAM_Y_OFFSCREEN.b
    sta oam_buffer+1.w,x
    stz oam_buffer+2.w,x
    stz oam_buffer+3.w,x
    inx
    inx
    inx
    inx
    cpx #512.w
    bne HideOAMLow
    ldx #$0000.w
HideOAMHi:
    stz oam_hi.w,x
    inx
    cpx #OAM_HI_BYTES.w
    bne HideOAMHi
    rts

; spr_index = sprite #, spr_x.w (signed screen), spr_y, spr_tile.w, spr_attr, spr_large
WriteSprite:
    php
    sep #$20
    .ACCU 8
    rep #$10
    .INDEX 16
    lda spr_y
    cmp #$E0.b
    bcc WSYok
    jmp WSSkip
WSYok:
    ; Accept x in [-32, 255]. 9-bit OAM X covers [-256,-1] as 256..511.
    rep #$20
    .ACCU 16
    lda spr_x
    clc
    adc #32.w
    cmp #288.w                      ; 256+32
    bcc WSDo
    jmp WSSkip
WSDo:
    rep #$20
    .ACCU 16
    lda spr_index
    asl a
    asl a
    tax
    sep #$20
    .ACCU 8
    lda spr_x
    sta oam_buffer.w,x
    lda spr_y
    sta oam_buffer+1.w,x
    lda spr_tile
    sta oam_buffer+2.w,x
    lda spr_attr
    and #$FE.b
    sta tmp0
    lda spr_tile+1
    and #$01.b
    ora tmp0
    sta oam_buffer+3.w,x
    sep #$10
    lda spr_index
    and #$03.b
    tay
    lda spr_index
    lsr a
    lsr a
    tax
    lda #$03.b
    cpy #0
    beq WSShift0
WSShiftLoop:
    asl a
    asl a
    dey
    bne WSShiftLoop
WSShift0:
    eor #$FF.b
    and oam_hi.w,x
    sta oam_hi.w,x
    lda spr_large
    beq WSNoSz
    lda spr_index
    and #$03.b
    tay
    lda #$02.b
    cpy #0
    beq WSOr
WSShift2:
    asl a
    asl a
    dey
    bne WSShift2
WSOr:
    ora oam_hi.w,x
    sta oam_hi.w,x
WSNoSz:
    lda spr_x+1
    beq WSNoX9
    lda spr_index
    and #$03.b
    tay
    lda #$01.b
    cpy #0
    beq WSOrX9
WSShiftX9:
    asl a
    asl a
    dey
    bne WSShiftX9
WSOrX9:
    ora oam_hi.w,x
    sta oam_hi.w,x
WSNoX9:
    rep #$10
    inc spr_index
WSSkip:
    plp
    rts

DMAOAM:
    sep #$20
    stz OAMADDL
    stz OAMADDH
    stz DMAP0
    lda #$04.b
    sta BBAD0
    rep #$20
    lda #oam_buffer
    sep #$20
    sta A1T0L
    xba
    sta A1T0H
    lda #$7E.b
    sta A1B0
    lda #$20.b
    sta DAS0L
    lda #$02.b
    sta DAS0H
    lda #$01.b
    sta MDMAEN
    rts

; Screen Y from world Y-up: 224 - y - height. In: A=height, tmp1=world y. Out spr_y
WorldToScreenY:
    php
    sep #$20
    sta tmp0
    stz tmp0+1
    rep #$20
    .ACCU 16
    lda #224.w
    sec
    sbc tmp1
    bmi WSYOff
    sec
    sbc tmp0
    bmi WSYOff
    cmp #224
    bcs WSYOff
    sep #$20
    sta spr_y
    plp
    rts
WSYOff:
    sep #$20
    lda #OAM_Y_OFFSCREEN.b
    sta spr_y
    plp
    rts

BuildOAM:
    php
    sep #$20
    rep #$10
    jsr HideAllSprites
    stz spr_index
    stz spr_index+1
    jsr DrawPlayerSpr
    jsr DrawEnemiesSpr
    jsr DrawCoinsSpr
    jsr DrawCastleSpr
    plp
    rts

DrawPlayerSpr:
    lda pl_flags
    and #PF_DEAD.b
    beq DPSAlive
DPSAlive:
    lda pl_invuln
    beq DPSShow
    lda frame_counter
    and #$04.b
    beq DPSShow
    rts
DPSShow:
    rep #$20
    .ACCU 16
    lda pl_x
    sec
    sbc cam_x
    sec
    sbc #8.w                        ; 32px sprite centered on 16px box
    bpl DPSXOk
    lda #0.w                        ; keep on-screen at the left edge
DPSXOk:
    sta spr_x
    lda pl_y
    sta tmp1
    sep #$20
    lda #PLAYER_SPR_H.b
    jsr WorldToScreenY
    ; 32x32 frames: 4 per 16-tile row → tile = base + (frame&3)*4 + (frame>>2)*64
    lda pl_frame
    and #3
    asl a
    asl a
    sta tmp0
    stz tmp0+1
    lda pl_frame
    lsr a
    lsr a
    sta tmp2
    stz tmp2+1
    rep #$20
    lda tmp2
    asl a
    asl a
    asl a
    asl a
    asl a
    asl a                       ; *64
    clc
    adc tmp0
    clc
    adc #SPR_PLAYER_TILE
    sta spr_tile
    sep #$20
    lda #OAM_ATTR_PRI2.b
    sta spr_attr
    lda pl_flags
    and #PF_FACE_R.b
    bne DPSRight
    lda spr_attr
    ora #$40.b                      ; hflip
    sta spr_attr
DPSRight:
    lda #1
    sta spr_large
    jsr WriteSprite
    rts

DrawCastleSpr:
    php
    rep #$20
    .ACCU 16
    lda goal_x
    sec
    sbc cam_x
    sta spr_x
    lda goal_y
    sta tmp1
    sep #$20
    .ACCU 8
    lda #64
    jsr WorldToScreenY
    lda #OAM_ATTR_PRI2.b
    ora #$0E.b                      ; pal 7
    sta spr_attr
    lda #1
    sta spr_large
    rep #$20
    .ACCU 16
    lda #SPR_CASTLE_TILE
    sta spr_tile
    jsr WriteSprite                 ; top-left
    rep #$20
    .ACCU 16
    lda spr_x
    clc
    adc #32.w
    sta spr_x
    lda #SPR_CASTLE_TILE + 4
    sta spr_tile
    jsr WriteSprite                 ; top-right
    sep #$20
    lda spr_y
    clc
    adc #32
    sta spr_y
    rep #$20
    .ACCU 16
    lda #SPR_CASTLE_TILE + 12
    sta spr_tile
    jsr WriteSprite                 ; bottom-right
    lda spr_x
    sec
    sbc #32.w
    sta spr_x
    lda #SPR_CASTLE_TILE + 8
    sta spr_tile
    jsr WriteSprite                 ; bottom-left
    plp
    rts

.ENDS
