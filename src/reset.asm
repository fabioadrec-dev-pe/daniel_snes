; CPU bring-up. All of this stays in bank $00.
; NMI is enabled only after the vector is valid. Boot shows solid COLOR (T1–T3).

.BANK 0 SLOT 0
.SECTION "Reset" FREE

Reset:
    sei
    clc
    xce

    rep #$38
    .ACCU 16
    .INDEX 16

    ldx #$1FFF.w
    txs
    lda #$0000.w
    tcd

    sep #$20
    .ACCU 8
    phk
    plb

    lda #INIDISP_FORCEBLANK.b
    sta INIDISP
    stz NMITIMEN
    stz MDMAEN
    stz HDMAEN

    jsr InitPPU
    jsr HideAllSprites
    jsr DMAOAM

    stz game_state
    stz nmi_ready
    stz hud_dirty
    stz nmi_col_need
    stz stage_index
    lda #START_LIVES.b
    sta lives
    stz coins
    stz score_lo
    stz score_lo+1
    stz score_hi

    rep #$20
    stz frame_counter
    stz cam_x
    stz last_cam_mt
    stz joy_current
    stz joy_previous
    stz joy_pressed
    stz joy2_current
    stz joy2_previous
    stz joy2_pressed
    lda #BOOT_FRAMES
    sta boot_timer
    sep #$20

    lda #INIDISP_FULLBRIGHT.b
    sta INIDISP
    stz TM                          ; backdrop only (T1–T3 color test)
    lda #NMITIMEN_NMI_JOY.b
    sta NMITIMEN

MainLoop:
    jsr WaitNMI
    lda game_state
    cmp #STATE_BOOT.b
    bne MLNotBoot
    jsr UpdateBoot
    jmp MainLoop
MLNotBoot:
    cmp #STATE_TITLE.b
    bne MLNotTitle
    jsr UpdateTitle
    jmp MainLoop
MLNotTitle:
    cmp #STATE_MENU.b
    bne MLNotMenu
    jsr UpdateMenu
    jmp MainLoop
MLNotMenu:
    cmp #STATE_STREETS.b
    bne MLNotStreets
    jsr UpdateStreets
    jmp MainLoop
MLNotStreets:
    cmp #STATE_PAUSE.b
    bne MLNotPause
    jsr UpdatePause
    jmp MainLoop
MLNotPause:
    cmp #STATE_PLAY.b
    bne MLNotPlay
    jsr UpdatePlay
    jmp MainLoop
MLNotPlay:
    cmp #STATE_DYING.b
    bne MLNotDying
    jsr UpdateDying
    jmp MainLoop
MLNotDying:
    cmp #STATE_CLEAR.b
    bne MLNotClear
    jsr UpdateClear
    jmp MainLoop
MLNotClear:
    cmp #STATE_ENDING.b
    bne MLNotEnding
    jsr UpdateEnding
    jmp MainLoop
MLNotEnding:
    jsr UpdateEndScreen
    jmp MainLoop

.ENDS
