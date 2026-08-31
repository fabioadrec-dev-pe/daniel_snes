; 65816 ↔ SPC700: IPL upload once, then port commands (play/sfx/stop).

.BANK 0 SLOT 0
.SECTION "Audio" FREE

InitAudio:
    php
    sep #$20
    .ACCU 8
    rep #$10
    .INDEX 16
    lda #$FF.b
    sta spc_song
    sta spc_loaded
    jsr SpcUploadDriver
    ; Menu song in ARAM before the PRESS START screen (upload only, no PLAY).
    lda #SONG_MENU.b
    sta spc_song
    jsr SpcUploadSong
    lda #$FF.b
    sta spc_song
    plp
    rts

; IPL ROM transfer of the driver+samples+songs to ARAM $0200 (blargg/libSFX).
SpcUploadDriver:
    php
    sep #$20
    .ACCU 8
    rep #$10
    .INDEX 16
    ; Wait AA BB
    ldx #$BBAA.w
SpcWaitIpl:
    cpx APUIO0
    bne SpcWaitIpl
    lda #<SPC_ENTRY
    sta APUIO2
    lda #>SPC_ENTRY
    sta APUIO3
    lda #$CC.b
    sta APUIO1
    sta APUIO0
SpcWaitCc:
    cmp APUIO0
    bne SpcWaitCc
    ldx #0
SpcCopy:
    lda.l SpcBoot,x
    sta APUIO1
    txa
    sta APUIO0
SpcWaitY:
    cmp APUIO0
    bne SpcWaitY
    inx
    cpx #SPC_BOOT_SIZE.w
    bne SpcCopy
    ; Execute at $0200
    lda #<SPC_ENTRY
    sta APUIO2
    lda #>SPC_ENTRY
    sta APUIO3
    stz APUIO1
    lda APUIO0
    inc a
    inc a
    bne SpcKick
    inc a
SpcKick:
    sta APUIO0
SpcWaitRun:
    cmp APUIO0
    bne SpcWaitRun
    ; Driver zeros port0 when idle.
    ldx #0
SpcWaitReady:
    lda APUIO0
    beq SpcReady
    dex
    bne SpcWaitReady
SpcReady:
    plp
    rts

; A = song id. Uploads when ARAM does not already have it, then always sends PLAY.
SpcPlaySong:
    php
    sep #$20
    sta spc_song
    cmp spc_loaded
    beq SpcSongPlay
    jsr SpcUploadSong
    lda spc_song
    cmp spc_loaded
    bne SpcSongSame
SpcSongPlay:
    lda #1.b
    jsr SpcCommand
    lda spc_song
    sta spc_loaded
SpcSongSame:
    plp
    rts

; Copy the current spc_song into ARAM $8000 via the driver loader.
; Leaves NMITIMEN off — the caller re-enables NMI after the screen is ready.
SpcUploadSong:
    php
    sep #$20
    .ACCU 8
    rep #$10
    .INDEX 16
    stz NMITIMEN
    phk
    plb
    lda spc_song
    rep #$20
    .ACCU 16
    and #$00FF.w
    asl a
    tax
    lsr a
    pha
    sep #$20
    .ACCU 8
    lda SongLen.w,x
    sta dma_len
    lda SongLen.w+1,x
    sta dma_len+1
    lda SongPtr.w,x
    sta dma_src
    lda SongPtr.w+1,x
    sta dma_src+1
    plx
    lda SongBank.w,x
    sta dma_bank
    ; Pad to a multiple of 3 (3 bytes per handshake).
    rep #$20
    .ACCU 16
    lda dma_len
    bne SpcULPad
    sep #$20
    .ACCU 8
    plp
    rts
SpcULPad:
    sta tmp0
    sec
SpcULMod:
    sbc #3.w
    bcs SpcULMod
    adc #3.w
    beq SpcULPadded
    eor #$FFFF.w
    inc a
    clc
    adc #3.w
    clc
    adc dma_len
    sta dma_len
SpcULPadded:
    sep #$20
    .ACCU 8
    lda dma_len
    sta APUIO2
    lda dma_len+1
    sta APUIO3
    ldx #$4000.w
SpcULIdle:
    lda APUIO0
    beq SpcULSend
    dex
    bne SpcULIdle
    plp
    rts
SpcULSend:
    lda dma_len
    sta APUIO2
    lda dma_len+1
    sta APUIO3
    lda #4.b
    sta APUIO0
    ldx #$8000.w
SpcULEcho:
    cmp APUIO0
    beq SpcULGo
    dex
    bne SpcULEcho
    plp
    rts
SpcULGo:
    phb
    lda dma_bank
    pha
    plb
    ldy #0
SpcULCopy:
    tya
    sta tmp2
    lda (dma_src),y
    sta APUIO1
    iny
    lda (dma_src),y
    sta APUIO2
    iny
    lda (dma_src),y
    sta APUIO3
    iny
    lda tmp2
    sta APUIO0
    ldx #$8000.w
SpcULWait:
    cmp APUIO0
    beq SpcULNext
    dex
    bne SpcULWait
    plb
    plp
    rts
SpcULNext:
    rep #$20
    .ACCU 16
    tya
    cmp dma_len
    sep #$20
    .ACCU 8
    bcc SpcULCopy
    plb
    ldx #$4000.w
SpcULDone:
    lda APUIO0
    beq SpcULOk
    dex
    bne SpcULDone
    plp
    rts
SpcULOk:
    lda spc_song
    sta spc_loaded
    plp
    rts

SongPtr:
    .dw SongMenu, SongStage, SongBoss, SongVictory, SongGameOver
SongLen:
    .dw SONG_MENU_BYTES, SONG_STAGE_BYTES, SONG_BOSS_BYTES, SONG_VICTORY_BYTES, SONG_GAMEOVER_BYTES
SongBank:
    .db :SongMenu, :SongStage, :SongBoss, :SongVictory, :SongGameOver

; A = sfx id 0-9
SpcPlaySfx:
    php
    sep #$20
    sta spc_sfx
    lda #2.b
    jsr SpcCommandSfx
    plp
    rts

SpcStop:
    php
    sep #$20
    lda #$FF.b
    sta spc_song
    stz APUIO1
    lda #3.b
    jsr SpcCommandRaw
    plp
    rts

; A = play command (1). Argument is spc_song.
SpcCommand:
    pha
    lda spc_song
    sta APUIO1
    pla
    jsr SpcCommandRaw
    rts

SpcCommandSfx:
    pha
    lda spc_sfx
    sta APUIO1
    pla
    jsr SpcCommandRaw
    rts

; A = command already, APUIO1 preset. Handshake: wait idle, send, wait echo, wait idle.
SpcCommandRaw:
    php
    sep #$20
    .ACCU 8
    rep #$10
    .INDEX 16
    pha
    ldx #$FFFF.w
SpcIdle1:
    lda APUIO0
    beq SpcSend
    dex
    bne SpcIdle1
    pla
    plp
    rts
SpcSend:
    pla
    sta APUIO0
    sta tmp0
    ldx #$FFFF.w
SpcEcho:
    lda APUIO0
    cmp tmp0
    beq SpcEchoOk
    dex
    bne SpcEcho
SpcEchoOk:
    ldx #$FFFF.w
SpcIdle2:
    lda APUIO0
    beq SpcCmdDone
    dex
    bne SpcIdle2
SpcCmdDone:
    plp
    rts

.ENDS
