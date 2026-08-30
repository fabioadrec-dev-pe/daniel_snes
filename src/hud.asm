; BG3 HUD and title text. VRAM writes only in Force Blank or NMI.

.BANK 0 SLOT 0
.SECTION "HUD" FREE

DmaHUD:
    php
    sep #$20
    .ACCU 8
    rep #$10
    .INDEX 16
    lda #VMAIN_INC_HIGH.b
    sta VMAIN
    ldx #VRAM_BG3_MAP.w
    jsr SetVRAMAddress
    ldx #0
DHLoop:
    lda hud_buf.w,x
    sta VMDATAL
    lda #$24.b                      ; priority + BG3 pal 1
    sta VMDATAH
    inx
    cpx #32
    bne DHLoop
    plp
    rts

ClearHUD:
    sep #$20
    rep #$10
    ldx #0
    lda #0
CHLoop:
    sta hud_buf.w,x
    inx
    cpx #64
    bne CHLoop
    rts

ClearBG3:
    php
    sep #$20
    .ACCU 8
    rep #$10
    .INDEX 16
    lda #VMAIN_INC_HIGH.b
    sta VMAIN
    ldx #VRAM_BG3_MAP.w
    jsr SetVRAMAddress
    ldx #1024.w
CB3:
    stz VMDATAL
    stz VMDATAH
    dex
    bne CB3
    plp
    rts

; X.w = string offset in Strings, Y = BG3 row 0-31. Force Blank/NMI.
PrintStringRow:
    php
    sep #$20
    .ACCU 8
    rep #$10
    .INDEX 16
    sty tmp1
    stz tmp1+1
    stx tmp0
    lda #VMAIN_INC_HIGH.b
    sta VMAIN
    rep #$20
    .ACCU 16
    lda tmp1
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
    ldx tmp0
    ldy #32
PSRLoop:
    sep #$20
    lda.l Strings,x
    sta VMDATAL
    lda #$24.b
    sta VMDATAH
    inx
    dey
    bne PSRLoop
    plp
    rts

; A = tile, X = col 0-31, Y = row 0-31. Force Blank/NMI.
PokeBG3:
    php
    sep #$30
    .ACCU 8
    .INDEX 8
    sta tmp0
    stx tmp1
    stz tmp1+1
    sty tmp2
    stz tmp2+1
    lda #VMAIN_INC_HIGH.b
    sta VMAIN
    rep #$30
    .ACCU 16
    .INDEX 16
    lda tmp2
    and #$001F.w
    asl a
    asl a
    asl a
    asl a
    asl a
    clc
    adc tmp1
    clc
    adc #VRAM_BG3_MAP
    tax
    jsr SetVRAMAddress
    sep #$20
    .ACCU 8
    lda tmp0
    sta VMDATAL
    lda #$24.b
    sta VMDATAH
    plp
    rts

DrawHUD:
    php
    jsr ClearHUD
    sep #$20
    rep #$10
    ldx #0
    lda #FONT_D
    sta hud_buf.w,x
    inx
    lda #FONT_A
    sta hud_buf.w,x
    inx
    lda #FONT_N
    sta hud_buf.w,x
    inx
    lda #FONT_I
    sta hud_buf.w,x
    inx
    lda #FONT_E
    sta hud_buf.w,x
    inx
    lda #FONT_L
    sta hud_buf.w,x
    inx
    inx
    lda #FONT_X
    sta hud_buf.w,x
    inx
    lda lives
    clc
    adc #FONT_0
    sta hud_buf.w,x
    ldx #12
    lda coins
    jsr Store2Digits
    ldx #20
    lda stage_index
    inc a
    clc
    adc #FONT_0
    sta hud_buf.w,x
    ldx #24
    jsr Store3Digits
    lda #1
    sta hud_dirty
    plp
    rts

; A = 0-99, X = dest in HUD line 0
Store2Digits:
    sta tmp0
    lda #0
    sta tmp1
S2T:
    lda tmp0
    cmp #10
    bcc S2O
    sec
    sbc #10
    sta tmp0
    inc tmp1
    bra S2T
S2O:
    lda tmp1
    clc
    adc #FONT_0
    sta hud_buf.w,x
    inx
    lda tmp0
    clc
    adc #FONT_0
    sta hud_buf.w,x
    rts

Store3Digits:
    phx
    rep #$20
    lda time_sec
    sta tmp0
    sep #$20
    lda #0
    sta tmp1
S3H:
    rep #$20
    lda tmp0
    cmp #100
    bcc S3T
    sec
    sbc #100
    sta tmp0
    sep #$20
    inc tmp1
    bra S3H
S3T:
    sep #$20
    plx
    lda tmp1
    clc
    adc #FONT_0
    sta hud_buf.w,x
    inx
    lda tmp0
    jsr Store2Digits
    rts

.ENDS
