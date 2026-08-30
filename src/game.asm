; Game states, stage load, camera, pause, dying, clear, win/game over.

.BANK 0 SLOT 0
.SECTION "Game" FREE

UpdateBoot:
    rep #$20
    dec boot_timer
    bne UBDone
    sep #$20
    jsr EnterTitle
UBDone:
    sep #$20
    rts

EnterTitle:
    sep #$20
    stz NMITIMEN
    lda #INIDISP_FORCEBLANK.b
    sta INIDISP
    jsr RestoreMode1
    jsr LoadSharedGraphics
    jsr LoadMenuBG
    jsr ClearBG3
    jsr HideAllSprites
    jsr DMAOAM
    rep #$10
    .INDEX 16
    ldx #STR_TITLE1
    ldy #8
    jsr PrintStringRow
    ldx #STR_TITLE2
    ldy #10
    jsr PrintStringRow
    ldx #STR_CREDIT
    ldy #16
    jsr PrintStringRow
    ldx #STR_START
    ldy #20
    jsr PrintStringRow
    rep #$20
    stz cam_x
    sep #$20
    stz nmi_col_need
    stz BG1HOFS
    stz BG1HOFS
    stz BG2HOFS
    stz BG2HOFS
    lda #TM_TITLE.b
    sta TM
    rep #$20
    stz state_timer
    stz street_scroll
    sep #$20
    stz street_row_need
    lda #INIDISP_FULLBRIGHT.b
    sta INIDISP
    lda #STATE_TITLE.b
    sta game_state
    lda #NMITIMEN_NMI_JOY.b
    sta NMITIMEN
    rts

UpdateTitle:
    sep #$20
    rep #$20
    lda joy_pressed
    and #BUTTON_START.w
    sep #$20
    beq UTIdle
    jsr EnterMenu
    rts
UTIdle:
    rep #$20
    inc state_timer
    lda state_timer
    cmp #TITLE_IDLE_FRAMES.w
    sep #$20
    bcc UTDone
    jsr EnterStreets
UTDone:
    rts

NewGame:
    sep #$20
    lda #START_LIVES.b
    sta lives
    stz coins
    stz score_lo
    stz score_lo+1
    stz score_hi
    stz stage_index
    lda menu_unlock
    beq NGGo
    lda menu_stage
    dec a
    sta stage_index
    lda menu_lives
    sta lives
NGGo:
    jsr EnterStage
    rts

EnterStage:
    sep #$20
    stz NMITIMEN
    lda #INIDISP_FORCEBLANK.b
    sta INIDISP
    jsr RestoreMode1
    jsr LoadStageBlob
    jsr LoadSharedGraphics
    jsr LoadStageBG
    jsr InitPlayerFromStage
    jsr InitEnemies
    jsr InitCoins
    jsr HideAllSprites
    jsr UpdateCamera
    jsr FillBG1FromCamera
    stz nmi_col_need
    jsr ClearBG3
    jsr DrawHUD
    jsr DmaHUD
    jsr BuildOAM
    jsr DMAOAM
    lda #BGMODE_1_BG3PRI.b
    sta BGMODE
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
    lda #TM_PLAY.b
    sta TM
    lda #STATE_PLAY.b
    sta game_state
    jsr ApplyScroll
    lda #INIDISP_FULLBRIGHT.b
    sta INIDISP
    lda #NMITIMEN_NMI_JOY.b
    sta NMITIMEN
    rts

StagePtr:
    .dw Stage0, Stage1, Stage2, Stage3, Stage4
StageLen:
    .dw STAGE0_BYTES, STAGE1_BYTES, STAGE2_BYTES, STAGE3_BYTES, STAGE4_BYTES
StageBank:
    .db :Stage0, :Stage1, :Stage2, :Stage3, :Stage4

LoadStageBlob:
    sep #$20
    rep #$10
    lda stage_index
    asl a
    tax
    rep #$20
    lda StagePtr.w,x
    sta dma_src
    lda StageLen.w,x
    sta dma_len
    sep #$20
    lda stage_index
    tax
    lda StageBank.w,x
    sta dma_bank
    jsr CopyToMapWRAM
    ; parse header
    sep #$20
    lda.l $7E2000
    sta map_cols
    lda.l $7E2001
    sta map_cols+1
    lda.l $7E2002
    sta map_rows
    lda.l $7E2003
    sta boss_flag
    lda.l $7E2004
    sta respawn_x
    lda.l $7E2005
    sta respawn_x+1
    lda.l $7E2006
    sta respawn_y
    lda.l $7E2007
    sta respawn_y+1
    lda.l $7E2008
    sta goal_x
    lda.l $7E2009
    sta goal_x+1
    lda.l $7E200A
    sta goal_y
    lda.l $7E200B
    sta goal_y+1
    lda.l $7E200C
    sta n_enemies
    lda.l $7E200D
    sta n_coins
    lda.l $7E200E
    sta n_chk
    lda n_enemies
    cmp #ENEMY_MAX.b+1
    bcc LSBEnOk
    lda #ENEMY_MAX.b
    sta n_enemies
LSBEnOk:
    lda n_coins
    cmp #COIN_MAX.b+1
    bcc LSBCnOk
    lda #COIN_MAX.b
    sta n_coins
LSBCnOk:
    stz chk_reached
    ; world_w = cols * 16
    lda map_cols
    sta WRMPYA
    lda #16
    sta WRMPYB
    nop
    nop
    nop
    nop
    rep #$20
    lda RDMPYL
    sta world_w
    lda #START_TIME
    sta time_sec
    sep #$20
    lda #60
    sta time_frames
    rts

InitPlayerFromStage:
    jsr SpawnPlayer
    rts

UpdateCamera:
    php
    rep #$20
    .ACCU 16
    lda pl_x
    sec
    sbc #120.w                      ; center-ish
    bpl UC0
    lda #0
UC0:
    sta cam_x
    lda world_w
    sec
    sbc #256.w
    bcs UCHas
    lda #0
    sta cam_x
    bra UCDone
UCHas:
    cmp cam_x
    bcs UCDone
    sta cam_x
UCDone:
    ; stream one metatile column when the camera crosses a 16px boundary
    lda cam_x
    lsr a
    lsr a
    lsr a
    lsr a
    cmp last_cam_mt
    beq UCSame
    bcs UCRight
    sta last_cam_mt
    sta nmi_col_mc
    bra UCNeed
UCRight:
    sta last_cam_mt
    clc
    adc #BG1_MT_COLS - 1
    sta nmi_col_mc
UCNeed:
    jsr PrepareMetaColumn
    sep #$20
    lda #1
    sta nmi_col_need
UCSame:
    plp
    rts

UpdatePlay:
    rep #$30
    .ACCU 16
    .INDEX 16
    sep #$20
    .ACCU 8
    rep #$20
    lda joy_pressed
    and #BUTTON_START.w
    sep #$20
    beq UPGo
    lda #STATE_PAUSE.b
    sta game_state
    jsr PpuBlankOn
    ldx #STR_PAUSA
    ldy #12
    jsr PrintStringRow
    jsr PpuBlankOff
    rts
UPGo:
    jsr TickTime
    jsr UpdatePlayer
    jsr UpdateEnemies
    jsr HandleCoins
    jsr HandleStomp
    jsr HandleCheckpoints
    jsr CheckGoal
    jsr UpdateCamera
    jsr DrawHUD
    jsr BuildOAM
    lda pl_flags
    and #PF_DEAD.b
    beq UPAlive
    lda #STATE_DYING.b
    sta game_state
    rep #$20
    lda #DEAD_FRAMES
    sta state_timer
UPAlive:
    sep #$20
    rts

TickTime:
    sep #$20
    dec time_frames
    bne TTDone
    lda #60
    sta time_frames
    rep #$20
    lda time_sec
    beq TTKill
    dec time_sec
    sep #$20
    lda #1
    sta hud_dirty
    rts
TTKill:
    sep #$20
    jsr KillPlayer
TTDone:
    rts

HandleCheckpoints:
    ; two checkpoints baked; activate when pl_x >= cp.x
    ; skip if already reached
    rts

CheckGoal:
    sep #$20
    lda pl_flags
    and #$18.b
    bne CGNo
    rep #$20
    lda pl_x
    cmp goal_x
    bcc CGNo16
    sep #$20
    lda pl_flags
    ora #PF_WIN.b
    sta pl_flags
    lda #STATE_CLEAR.b
    sta game_state
    rep #$20
    lda #CLEAR_FRAMES
    sta state_timer
CGNo16:
CGNo:
    sep #$20
    rts

UpdatePause:
    rep #$20
    lda joy_pressed
    and #BUTTON_START.w
    sep #$20
    beq UPz
    jsr PpuBlankOn
    jsr ClearBG3
    jsr DrawHUD
    jsr DmaHUD
    jsr PpuBlankOff
    lda #STATE_PLAY.b
    sta game_state
UPz:
    rts

UpdateDying:
    jsr UpdatePlayer
    jsr UpdateCamera
    jsr BuildOAM
    rep #$20
    dec state_timer
    bne UDWait
    sep #$20
    lda lives
    beq UDOver
    dec lives
    lda lives
    beq UDOver
    jsr SpawnPlayer
    lda #INVULN_FRAMES.b
    sta pl_invuln
    lda #1
    sta hud_dirty
    jsr UpdateCamera
    jsr PpuBlankOn
    jsr FillBG1FromCamera
    stz nmi_col_need
    jsr PpuBlankOff
    lda #STATE_PLAY.b
    sta game_state
    rts
UDOver:
    jsr EnterGameOver
UDWait:
    sep #$20
    rts

UpdateClear:
    jsr UpdatePlayer
    jsr BuildOAM
    rep #$20
    dec state_timer
    bne UClWait
    sep #$20
    lda stage_index
    inc a
    sta stage_index
    cmp #TOTAL_STAGES.b
    bcs UCWin
    jsr EnterStage
    rts
UCWin:
    jsr EnterWin
UClWait:
    sep #$20
    rts

EnterGameOver:
    sep #$20
    stz NMITIMEN
    lda #INIDISP_FORCEBLANK.b
    sta INIDISP
    jsr LoadMenuBG
    jsr ClearBG3
    ldx #STR_OVER
    ldy #12
    jsr PrintStringRow
    ldx #STR_START
    ldy #16
    jsr PrintStringRow
    lda #TM_TITLE.b
    sta TM
    lda #INIDISP_FULLBRIGHT.b
    sta INIDISP
    lda #STATE_OVER.b
    sta game_state
    lda #NMITIMEN_NMI_JOY.b
    sta NMITIMEN
    rts

EnterWin:
    sep #$20
    stz NMITIMEN
    lda #INIDISP_FORCEBLANK.b
    sta INIDISP
    jsr LoadMenuBG
    jsr ClearBG3
    ldx #STR_WIN
    ldy #12
    jsr PrintStringRow
    ldx #STR_START
    ldy #16
    jsr PrintStringRow
    lda #TM_TITLE.b
    sta TM
    lda #INIDISP_FULLBRIGHT.b
    sta INIDISP
    lda #STATE_WIN.b
    sta game_state
    lda #NMITIMEN_NMI_JOY.b
    sta NMITIMEN
    rts

UpdateEndScreen:
    rep #$20
    lda joy_pressed
    and #BUTTON_START.w
    sep #$20
    beq UEDone
    jsr EnterMenu
UEDone:
    rts

.ENDS
