; Main menu from the Java MenuScreen: NOVO JOGO / SAIR, plus a secret
; sequence (U D L R B Y) that unlocks FASE and VIDAS.

.BANK 0 SLOT 0
.SECTION "Menu" FREE

EnterMenu:
    sep #$20
    stz NMITIMEN
    lda #INIDISP_FORCEBLANK.b
    sta INIDISP
    jsr RestoreMode1
    jsr LoadSharedGraphics
    jsr LoadMenuBG
    jsr HideAllSprites
    jsr DMAOAM
    stz menu_sel
    stz menu_cheat
    stz menu_unlock
    stz menu_swallow
    lda #1.b
    sta menu_stage
    lda #START_LIVES.b
    sta menu_lives
    jsr DrawMenuBody
    lda #TM_TITLE.b
    sta TM
    lda #INIDISP_FULLBRIGHT.b
    sta INIDISP
    lda #STATE_MENU.b
    sta game_state
    lda #NMITIMEN_NMI_JOY.b
    sta NMITIMEN
    rts

RedrawMenu:
    jsr PpuBlankOn
    jsr DrawMenuBody
    jsr PpuBlankOff
    rts

DrawMenuBody:
    php
    sep #$20
    .ACCU 8
    rep #$10
    .INDEX 16
    jsr ClearBG3
    ldx #STR_TITLE1
    ldy #5
    jsr PrintStringRow
    ldx #STR_TITLE2
    ldy #7
    jsr PrintStringRow
    lda menu_unlock
    bne DMBCheat
    ldx #STR_NOVO
    ldy #14
    jsr PrintStringRow
    ldx #STR_SAIR
    ldy #16
    jsr PrintStringRow
    lda menu_sel
    beq DMBSel0
    lda #FONT_X62.b
    ldx #9
    ldy #16
    jsr PokeBG3
    lda #FONT_X60.b
    ldx #22
    ldy #16
    jsr PokeBG3
    jmp DMBHint
DMBSel0:
    lda #FONT_X62.b
    ldx #9
    ldy #14
    jsr PokeBG3
    lda #FONT_X60.b
    ldx #22
    ldy #14
    jsr PokeBG3
    jmp DMBHint
DMBCheat:
    ldx #STR_NOVO
    ldy #12
    jsr PrintStringRow
    ldx #STR_MFASE
    ldy #14
    jsr PrintStringRow
    lda menu_stage
    clc
    adc #FONT_0.b
    ldx #18
    ldy #14
    jsr PokeBG3
    ldx #STR_MVIDAS
    ldy #16
    jsr PrintStringRow
    lda menu_lives
    clc
    adc #FONT_0.b
    ldx #19
    ldy #16
    jsr PokeBG3
    ldx #STR_SAIR
    ldy #18
    jsr PrintStringRow
    lda menu_sel
    asl a
    clc
    adc #12.b
    tay
    lda #FONT_X62.b
    ldx #9
    jsr PokeBG3
    lda #FONT_X60.b
    ldx #22
    jsr PokeBG3
    lda menu_sel
    cmp #1.b
    beq DMBAdj
    cmp #2.b
    bne DMBHint
DMBAdj:
    ldx #STR_HINTADJ
    ldy #22
    jsr PrintStringRow
DMBHint:
    ldx #STR_HINTGO
    ldy #24
    jsr PrintStringRow
    plp
    rts

UpdateMenu:
    sep #$20
    .ACCU 8
    jsr MenuCheat
    jsr MenuMove
    lda menu_unlock
    beq UMConfirm
    jsr MenuAdjust
UMConfirm:
    rep #$20
    .ACCU 16
    lda joy_pressed
    and #BUTTON_START.w
    bne UMDo
    lda joy_pressed
    and #(BUTTON_B|BUTTON_A).w
    beq UMDone
    sep #$20
    lda menu_swallow
    bne UMDone
    bra UMDo8
UMDo:
    sep #$20
UMDo8:
    jsr MenuConfirm
UMDone:
    sep #$20
    rts

MenuMove:
    rep #$20
    .ACCU 16
    lda joy_pressed
    and #BUTTON_UP.w
    beq MMDown
    sep #$20
    lda menu_sel
    bne MMDec
    jsr MenuCount
    sta menu_sel
MMDec:
    dec menu_sel
    jsr RedrawMenu
    rts
MMDown:
    lda joy_pressed
    and #BUTTON_DOWN.w
    beq MMNone
    sep #$20
    inc menu_sel
    jsr MenuCount
    cmp menu_sel
    bne MMDraw
    stz menu_sel
MMDraw:
    jsr RedrawMenu
MMNone:
    sep #$20
    rts

; A = option count (2 or 4)
MenuCount:
    lda menu_unlock
    beq MCTwo
    lda #4.b
    rts
MCTwo:
    lda #2.b
    rts

MenuAdjust:
    sep #$20
    lda menu_sel
    cmp #1.b
    beq MAStage
    cmp #2.b
    beq MALives
    rts
MAStage:
    rep #$20
    lda joy_pressed
    and #BUTTON_LEFT.w
    beq MASRight
    sep #$20
    lda menu_stage
    cmp #1.b
    beq MADone
    dec menu_stage
    jsr RedrawMenu
    rts
MASRight:
    lda joy_pressed
    and #BUTTON_RIGHT.w
    beq MADone16
    sep #$20
    lda menu_stage
    cmp #TOTAL_STAGES.b
    bcs MADone
    inc menu_stage
    jsr RedrawMenu
    rts
MALives:
    rep #$20
    lda joy_pressed
    and #BUTTON_LEFT.w
    beq MALRight
    sep #$20
    lda menu_lives
    cmp #MIN_LIVES.b
    beq MADone
    dec menu_lives
    jsr RedrawMenu
    rts
MALRight:
    lda joy_pressed
    and #BUTTON_RIGHT.w
    beq MADone16
    sep #$20
    lda menu_lives
    cmp #MAX_LIVES.b
    bcs MADone
    inc menu_lives
    jsr RedrawMenu
    rts
MADone16:
    sep #$20
MADone:
    rts

MenuConfirm:
    sep #$20
    lda menu_sel
    bne MCNotNovo
    jsr NewGame
    rts
MCNotNovo:
    lda menu_unlock
    bne MCCheat
    jsr EnterTitle
    rts
MCCheat:
    lda menu_sel
    cmp #3.b
    bne MCStay
    jsr EnterTitle
MCStay:
    rts

; Secret: UP DOWN LEFT RIGHT B/A Y/X. JUMP on step 5 must not confirm.
MenuCheat:
    sep #$20
    stz menu_swallow
    lda menu_unlock
    beq MChGo
    rts
MChGo:
    jsr MenuCheatPressed
    cmp #$FF.b
    bne MChHave
    rts
MChHave:
    sta tmp0
    sep #$30
    .ACCU 8
    .INDEX 8
    lda menu_cheat
    tax
    lda CheatStep.w,x
    cmp tmp0
    beq MChMatch
    lda tmp0
    cmp #$00.b                      ; UP is step 0
    bne MChReset
    lda #1.b
    sta menu_cheat
    rts
MChReset:
    stz menu_cheat
    rts
MChMatch:
    inc menu_cheat
    lda tmp0
    cmp #4.b                        ; JUMP
    bne MChNoSw
    lda #1.b
    sta menu_swallow
MChNoSw:
    lda menu_cheat
    cmp #6.b
    bcc MChDone
    lda #1.b
    sta menu_unlock
    stz menu_cheat
    lda menu_sel
    cmp #4.b
    bcc MChDraw
    lda #3.b
    sta menu_sel
MChDraw:
    jsr RedrawMenu
MChDone:
    rts

; Out: A = 0 UP, 1 DOWN, 2 LEFT, 3 RIGHT, 4 JUMP, 5 RUN, $FF none
MenuCheatPressed:
    rep #$20
    .ACCU 16
    lda joy_pressed
    bit #BUTTON_UP.w
    bne MCPUp
    bit #BUTTON_DOWN.w
    bne MCPDown
    bit #BUTTON_LEFT.w
    bne MCPLeft
    bit #BUTTON_RIGHT.w
    bne MCPRight
    bit #(BUTTON_B|BUTTON_A).w
    bne MCPJump
    bit #(BUTTON_Y|BUTTON_X).w
    bne MCPRun
    sep #$20
    lda #$FF.b
    rts
MCPUp:
    sep #$20
    lda #0.b
    rts
MCPDown:
    sep #$20
    lda #1.b
    rts
MCPRight:
    sep #$20
    lda #3.b
    rts
MCPLeft:
    sep #$20
    lda #2.b
    rts
MCPJump:
    sep #$20
    lda #4.b
    rts
MCPRun:
    sep #$20
    lda #5.b
    rts

CheatStep:
    .db 0, 1, 2, 3, 4, 5

.ENDS
