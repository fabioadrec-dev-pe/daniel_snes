; Title menu: 1 JOGADOR (AI on the right) or 2 JOGADOR (joy 2).

.BANK 0 SLOT 0
.SECTION "Title" FREE

StrPong:
    .DB TILE_P, TILE_O, TILE_N, TILE_G, $FF

Str1Jogador:
    .DB (TILE_DIGIT_0 + 1), TILE_SPACE
    .DB TILE_J, TILE_O, TILE_G, TILE_A, TILE_D, TILE_O, TILE_R, $FF

Str2Jogador:
    .DB (TILE_DIGIT_0 + 2), TILE_SPACE
    .DB TILE_J, TILE_O, TILE_G, TILE_A, TILE_D, TILE_O, TILE_R, $FF

DrawTitleScreen:
    sep #$20
    .ACCU 8
    rep #$10
    .INDEX 16
    lda #VMAIN_INC_HIGH.b
    sta VMAIN
    ldx #TITLE_PONG_VRAM.w
    jsr SetVRAMAddress
    ldx #$0000.w
DrawPongLoop:
    lda StrPong.w,x
    cmp #$FF.b
    beq DrawPongDone
    sta VMDATAL
    stz VMDATAH
    inx
    bra DrawPongLoop
DrawPongDone:
    ldx #TITLE_MENU1_VRAM.w
    jsr SetVRAMAddress
    ldx #$0000.w
Draw1PLoop:
    lda Str1Jogador.w,x
    cmp #$FF.b
    beq Draw1PDone
    sta VMDATAL
    stz VMDATAH
    inx
    bra Draw1PLoop
Draw1PDone:
    ldx #TITLE_MENU2_VRAM.w
    jsr SetVRAMAddress
    ldx #$0000.w
Draw2PLoop:
    lda Str2Jogador.w,x
    cmp #$FF.b
    beq Draw2PDone
    sta VMDATAL
    stz VMDATAH
    inx
    bra Draw2PLoop
Draw2PDone:
    jsr DrawCursor
    rts

DrawCursor:
    sep #$20
    .ACCU 8
    rep #$10
    .INDEX 16
    lda #VMAIN_INC_HIGH.b
    sta VMAIN
    ldx #TITLE_CURSOR1_VRAM.w
    jsr SetVRAMAddress
    lda menu_index
    beq CursorOn1P
    lda #TILE_SPACE.b
    bra StoreCursor1
CursorOn1P:
    lda #TILE_CURSOR.b
StoreCursor1:
    sta VMDATAL
    stz VMDATAH
    ldx #TITLE_CURSOR2_VRAM.w
    jsr SetVRAMAddress
    lda menu_index
    bne CursorOn2P
    lda #TILE_SPACE.b
    bra StoreCursor2
CursorOn2P:
    lda #TILE_CURSOR.b
StoreCursor2:
    sta VMDATAL
    stz VMDATAH
    rts

; Up/Down move the cursor. Start confirms and enters the game.
UpdateTitle:
    rep #$20
    .ACCU 16
    lda joy_pressed
    and #BUTTON_UP.w
    beq TitleCheckDown
    sep #$20
    .ACCU 8
    lda menu_index
    beq TitleCheckStart
    dec menu_index
    jsr DrawCursor
    bra TitleCheckStart
TitleCheckDown:
    lda joy_pressed
    and #BUTTON_DOWN.w
    beq TitleCheckStart
    sep #$20
    .ACCU 8
    lda menu_index
    bne TitleCheckStart
    inc menu_index
    jsr DrawCursor
TitleCheckStart:
    rep #$20
    .ACCU 16
    lda joy_pressed
    and #BUTTON_START.w
    sep #$20
    .ACCU 8
    beq UpdateTitleDone
    lda menu_index
    sta two_player
    jsr EnterGame
UpdateTitleDone:
    rts

.ENDS
