; Java ending trilogy: story crawl, credits crawl, then the yacht photo.
; BG2 holds the 16-color ending bitmap (veiled for text, full for the photo).
; BG3 streams wrapped 32-column rows because the 32x32 map cannot hold the script.

.BANK 0 SLOT 0
.SECTION "Ending" FREE

EnterEnding:
    sep #$20
    stz end_screen
    jmp EndStartScreen

EndStartScreen:
    sep #$20
    stz NMITIMEN
    lda #INIDISP_FORCEBLANK.b
    sta INIDISP
    lda end_screen
    bne ESSNotFirst
    jsr RestoreMode1
    jsr LoadEndingBG
    jsr HideAllSprites
    jsr DMAOAM
    bra ESSText
ESSNotFirst:
    cmp #2.b
    bne ESSText
    jsr LoadEndingFullPal
    jsr ClearBG3
    lda #TM_BG2.b
    sta TM
    jmp ESSFade
ESSText:
    lda end_screen
    beq ESSHaveGfx
    jsr LoadEndingVeilPal
ESSHaveGfx:
    jsr ClearBG3
    jsr FillEndingMap
    lda #TM_TITLE.b
    sta TM
ESSFade:
    rep #$20
    stz end_scroll
    lda #31.w
    sta end_last
    stz state_timer
    sep #$20
    stz end_phase
    stz end_bright
    stz end_div
    stz end_row_need
    lda #STATE_ENDING.b
    sta game_state
    lda #INIDISP_FORCEBLANK.b
    sta INIDISP
    lda #NMITIMEN_NMI_JOY.b
    sta NMITIMEN
    rts

FillEndingMap:
    php
    sep #$20
    .ACCU 8
    rep #$10
    .INDEX 16
    ldx #0
FEMLoop:
    stx end_line
    phx
    jsr EndPaintLine
    plx
    inx
    cpx #32
    bne FEMLoop
    plp
    rts

EndAdvance:
    sep #$20
    lda end_screen
    inc a
    sta end_screen
    cmp #3.b
    bcc EndAdvNext
    jmp EnterMenu
EndAdvNext:
    jmp EndStartScreen

UpdateEnding:
    sep #$20
    rep #$20
    lda joy_pressed
    ora joy2_pressed
    and #BUTTON_START.w
    sep #$20
    beq UENoSkip
    jmp EndAdvance
UENoSkip:
    lda end_phase
    beq UEFadeIn
    cmp #1.b
    beq UEMain
    cmp #2.b
    bne UEToFadeOut
    jmp UEHold
UEToFadeOut:
    jmp UEFadeOut

UEFadeIn:
    inc end_div
    lda end_div
    cmp #END_FADE_DIV.b
    bcc EndTickDone
    stz end_div
    lda end_bright
    cmp #15.b
    bcs UEFadeInDone
    inc end_bright
    rts
UEFadeInDone:
    lda #1.b
    sta end_phase
    lda end_screen
    cmp #2.b
    bne EndTickDone
    rep #$20
    lda #END_HOLD_PHOTO.w
    sta state_timer
    sep #$20
EndTickDone:
    rts

UEMain:
    lda end_screen
    cmp #2.b
    beq UEPhoto
    inc end_div
    lda end_div
    cmp #END_SCROLL_DIV.b
    bcc UEStream
    stz end_div
    rep #$20
    inc end_scroll
    sep #$20
    lda end_screen
    bne UEMainCred
    rep #$20
    lda end_scroll
    cmp #END_STORY_SCROLL_END.w
    bcc UEStream16
    bra UEMainHold
UEMainCred:
    rep #$20
    lda end_scroll
    cmp #END_CREDITS_SCROLL_END.w
    bcc UEStream16
UEMainHold:
    sep #$20
    lda #2.b
    sta end_phase
    lda end_screen
    beq UEHoldStory
    lda #<END_HOLD_CREDITS
    sta state_timer
    lda #>END_HOLD_CREDITS
    sta state_timer+1
    rts
UEHoldStory:
    lda #<END_HOLD_STORY
    sta state_timer
    lda #>END_HOLD_STORY
    sta state_timer+1
    rts
UEStream16:
    sep #$20
UEStream:
    jsr EndRequestRow
    rts

UEPhoto:
    rep #$20
    dec state_timer
    bne UEPhotoWait
    sep #$20
    lda #3.b
    sta end_phase
    rts
UEPhotoWait:
    sep #$20
    rts

UEHold:
    rep #$20
    dec state_timer
    bne UEHoldWait
    sep #$20
    lda #3.b
    sta end_phase
    rts
UEHoldWait:
    sep #$20
    rts

UEFadeOut:
    inc end_div
    lda end_div
    cmp #END_FADE_DIV.b
    bcc UEFadeOutWait
    stz end_div
    lda end_bright
    beq UEFadeOutDone
    dec end_bright
    rts
UEFadeOutDone:
    jmp EndAdvance
UEFadeOutWait:
    rts

EndRequestRow:
    php
    sep #$20
    .ACCU 8
    lda end_screen
    cmp #2.b
    bcs ERRDone
    rep #$20
    .ACCU 16
    lda end_scroll
    lsr a
    lsr a
    lsr a
    clc
    adc #31.w
    cmp end_last
    beq ERRDone
    bcc ERRDone
    inc end_last
    lda end_last
    sta end_line
    sep #$20
    lda #1.b
    sta end_row_need
ERRDone:
    plp
    rts

; Write one 32-tile BG3 row from the baked story/credits blob. Force blank or NMI.
EndPaintLine:
    php
    sep #$20
    .ACCU 8
    rep #$10
    .INDEX 16
    lda #VMAIN_INC_HIGH.b
    sta VMAIN
    rep #$20
    .ACCU 16
    lda end_line
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
    sep #$20
    .ACCU 8
    lda end_screen
    cmp #1.b
    beq EPLCredits
    jsr EndCopyStory
    bra EPLWrite
EPLCredits:
    jsr EndCopyCredits
EPLWrite:
    jsr EndPatchScore
    ldx #0
EPLWr:
    lda hud_buf.w,x
    sta VMDATAL
    lda #$24.b
    sta VMDATAH
    inx
    cpx #32
    bne EPLWr
    plp
    rts

EndCopyStory:
    php
    sep #$20
    .ACCU 8
    rep #$10
    .INDEX 16
    rep #$20
    lda end_line
    cmp #END_STORY_COUNT.w
    bcs ECBlank
    asl a
    asl a
    asl a
    asl a
    asl a
    tax
    sep #$20
    ldy #0
ECSLoop:
    lda.l EndingStory,x
    sta hud_buf.w,y
    inx
    iny
    cpy #32
    bne ECSLoop
    plp
    rts

EndCopyCredits:
    php
    sep #$20
    .ACCU 8
    rep #$10
    .INDEX 16
    rep #$20
    lda end_line
    cmp #END_CREDITS_COUNT.w
    bcs ECBlank
    asl a
    asl a
    asl a
    asl a
    asl a
    tax
    sep #$20
    ldy #0
ECCLoop:
    lda.l EndingCredits,x
    sta hud_buf.w,y
    inx
    iny
    cpy #32
    bne ECCLoop
    plp
    rts

ECBlank:
    sep #$20
    ldx #0
    lda #0
ECBLoop:
    sta hud_buf.w,x
    inx
    cpx #32
    bne ECBLoop
    plp
    rts

EndPatchScore:
    php
    sep #$20
    lda end_screen
    cmp #1.b
    bne EPSDone
    rep #$20
    lda end_line
    cmp #END_SCORE_LINE.w
    bne EPSDone
    ldx #END_SCORE_COL.w
    lda score_lo
    sta tmp0
    lda #10000.w
    jsr EndOneDigit
    lda #1000.w
    jsr EndOneDigit
    lda #100.w
    jsr EndOneDigit
    lda #10.w
    jsr EndOneDigit
    lda #1.w
    jsr EndOneDigit
EPSDone:
    plp
    rts

; A.w = divisor. tmp0 = value. X = hud_buf column. Writes one digit, inx.
EndOneDigit:
    sta tmp1
    lda tmp0
    stz tmp2
EODLoop:
    cmp tmp1
    bcc EODOut
    sbc tmp1
    inc tmp2
    bra EODLoop
EODOut:
    sta tmp0
    sep #$20
    lda tmp2
    clc
    adc #FONT_0.b
    sta hud_buf.w,x
    inx
    rep #$20
    rts

EndingNMI:
    sep #$20
    lda game_state
    cmp #STATE_ENDING.b
    bne ENDone
    lda end_bright
    bne ENShow
    lda #INIDISP_FORCEBLANK.b
    sta INIDISP
    bra ENPaint
ENShow:
    sta INIDISP
ENPaint:
    lda end_row_need
    beq ENDone
    stz end_row_need
    jsr EndPaintLine
ENDone:
    rts

.ENDS
