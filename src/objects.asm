; Enemies and coins. Same patrol/stomp rules as the Java game, without audio.

.BANK 0 SLOT 0
.SECTION "Objects" FREE

HpTab:
    .db 1,1,1,3,5
SpdTab:
    .dw SPD_WALKER, SPD_FLYER, SPD_FAST, SPD_TANK, SPD_BOSS
PalTab:
    .db 2,4,8,10,12
    ; OAM pal bits 1-3: walker=1 flyer=2 fast=4 tank=5 boss=6 (coin=3 castle=7)
SizeTab:
    .db 1,0,0,1,1                    ; 32px vs 16px
TileBase:
    .dw SPR_WALKER_TILE, SPR_FLYER_TILE, SPR_FAST_TILE, SPR_TANK_TILE, SPR_BOSS_TILE
TileStep:
    .db 4,2,2,4,4                    ; SNES 16-wide sheet: 32px stride 4, 16px stride 2

; A = byte at $7E:tmp1, tmp1++. Uses X.
Read7EInc:
    php
    sep #$20
    .ACCU 8
    rep #$10
    .INDEX 16
    ldx tmp1
    lda.l $7E0000,x
    inx
    stx tmp1
    plp
    rts

InitEnemies:
    sep #$20
    rep #$10
    ldx #ENEMY_WRAM & $FFFF
    ldy #ENEMY_MAX * ENEMY_SIZE
IEClr:
    lda #$00.b
    sta.l $7E0000,x
    inx
    dey
    bne IEClr
    lda n_enemies
    bne IECap
    rts
IECap:
    cmp #ENEMY_MAX.b
    bcc IEHas
    lda #ENEMY_MAX.b
    sta n_enemies
IEHas:
    sep #$20
    .ACCU 8
    lda map_rows
    sta tmp2
    stz tmp2+1
    rep #$20
    lda #0
    ldy tmp2
    beq IEMulZ
IEMul:
    clc
    adc map_cols
    dey
    bne IEMul
IEMulZ:
    clc
    adc #MAP_HEADER
    clc
    adc #MAP_WRAM & $FFFF
    sta tmp1
    stz tmp0
IELoop:
    sep #$20
    lda tmp0
    cmp n_enemies
    bcc IEBody
    rts
IEBody:
    sta WRMPYA
    lda #ENEMY_SIZE
    sta WRMPYB
    nop
    nop
    nop
    nop
    rep #$20
    lda RDMPYL
    clc
    adc #ENEMY_WRAM & $FFFF
    sta tmp2
    jsr Read7EInc
    sep #$20
    ldx tmp2
    sta.l $7E0001,x
    lda #EF_ALIVE.b
    sta.l $7E0000,x
    lda.l $7E0001,x
    phx
    tay
    lda HpTab.w,y
    plx
    sta.l $7E0002,x
    jsr Read7EInc
    sep #$20
    ldx tmp2
    sta.l $7E0004,x
    jsr Read7EInc
    sep #$20
    ldx tmp2
    sta.l $7E0005,x
    jsr Read7EInc
    sep #$20
    ldx tmp2
    sta.l $7E0006,x
    sta.l $7E000F,x
    jsr Read7EInc
    sep #$20
    ldx tmp2
    sta.l $7E0007,x
    lda.l $7E0001,x
    asl a
    tay
    rep #$20
    lda SpdTab.w,y
    eor #$FFFF
    inc a
    sta.l $7E0008,x
    sep #$20
    inc tmp0
    jmp IELoop
IEDone:
    rts

InitCoins:
    sep #$20
    rep #$10
    ldx #COIN_WRAM & $FFFF
    ldy #COIN_MAX * COIN_SIZE
ICClr:
    lda #$00.b
    sta.l $7E0000,x
    inx
    dey
    bne ICClr
    lda n_coins
    bne ICHas
    rts
ICHas:
    lda map_rows
    sta WRMPYA
    lda map_cols
    sta WRMPYB
    nop
    nop
    nop
    nop
    rep #$20
    lda RDMPYL
    clc
    adc #MAP_HEADER
    sta tmp1
    sep #$20
    lda n_enemies
    sta WRMPYA
    lda #5
    sta WRMPYB
    nop
    nop
    nop
    nop
    rep #$20
    lda RDMPYL
    clc
    adc tmp1
    clc
    adc #MAP_WRAM & $FFFF
    sta tmp1
    stz tmp0
ICLoop:
    sep #$20
    lda tmp0
    cmp n_coins
    bcc ICChkMax
    rts
ICChkMax:
    cmp #COIN_MAX
    bcc ICBody
    rts
ICBody:
    sta WRMPYA
    lda #COIN_SIZE
    sta WRMPYB
    nop
    nop
    nop
    nop
    rep #$20
    lda RDMPYL
    clc
    adc #COIN_WRAM & $FFFF
    sta tmp2
    sep #$20
    ldx tmp2
    lda #1
    sta.l $7E0000,x
    jsr Read7EInc
    sep #$20
    ldx tmp2
    sta.l $7E0002,x
    jsr Read7EInc
    sep #$20
    ldx tmp2
    sta.l $7E0003,x
    jsr Read7EInc
    sep #$20
    ldx tmp2
    sta.l $7E0004,x
    jsr Read7EInc
    sep #$20
    ldx tmp2
    sta.l $7E0005,x
    inc tmp0
    jmp ICLoop
ICDone:
    rts

UpdateEnemies:
    sep #$20
    .ACCU 8
    rep #$10
    .INDEX 16
    stz obj_i
UELoop:
    lda obj_i
    cmp n_enemies
    bcc UEGo
    rts
UEGo:
    jsr EnemyPtr
    lda.l $7E0000,x
    and #EF_ALIVE.b
    beq UENext
    lda.l $7E0001,x
    cmp #EN_FLYER
    beq UEFlyer
    jsr EnemyPatrol
    bra UEAnim
UEFlyer:
    jsr EnemyFlyer
UEAnim:
    lda frame_counter
    lsr a
    lsr a
    lsr a
    and #1
    sta.l $7E0003,x
UENext:
    inc obj_i
    jmp UELoop

EnemyPtr:
    ; obj_i = index -> X = ENEMY_WRAM + i*16
    sep #$20
    lda obj_i
    sta WRMPYA
    lda #ENEMY_SIZE
    sta WRMPYB
    nop
    nop
    nop
    nop
    rep #$20
    lda RDMPYL
    clc
    adc #ENEMY_WRAM & $FFFF
    tax
    sep #$20
    rts

EnemyPatrol:
    ; gravity + move + turn on wall/ledge. X = ptr
    php
    sep #$20
    .ACCU 8
    rep #$10
    .INDEX 16
    phx
    lda.l $7E0001,x
    cmp #EN_BOSS
    bne EPNoBoss
    lda.l $7E000E,x
    inc a
    sta.l $7E000E,x
    lda.l $7E000E,x
    cmp #BOSS_JUMP_T
    bcc EPNoBoss
    lda.l $7E0000,x
    and #EF_GROUND.b
    beq EPNoBoss
    lda #$00.b
    sta.l $7E000E,x
    rep #$20
    lda #BOSS_JUMP_V
    sta.l $7E000A,x
    sep #$20
    lda.l $7E0000,x
    and #$FB.b
    sta.l $7E0000,x
EPNoBoss:
    plx
    ; gravity
    rep #$20
    .ACCU 16
    lda.l $7E000A,x
    sec
    sbc #GRAVITY_F.w
    sta.l $7E000A,x
    ; pixel step from vx/vy high bytes (signed)
    sep #$20
    lda.l $7E0009,x
    sta tmp1
    bmi EPXNeg
    stz tmp1+1
    bra EPXAdd
EPXNeg:
    lda #$FF
    sta tmp1+1
EPXAdd:
    rep #$20
    .ACCU 16
    lda.l $7E0004,x
    clc
    adc tmp1
    sta.l $7E0004,x
    sep #$20
    lda.l $7E000B,x
    sta tmp1
    bmi EPYNeg
    stz tmp1+1
    bra EPYAdd
EPYNeg:
    lda #$FF
    sta tmp1+1
EPYAdd:
    rep #$20
    .ACCU 16
    lda.l $7E0006,x
    clc
    adc tmp1
    sta.l $7E0006,x
    ; collide feet
    lda.l $7E0004,x
    clc
    adc #8.w
    sta tile_px
    lda.l $7E0006,x
    sta tile_py
    phx
    jsr GetTile
    jsr IsSolid
    plx
    beq EPAir
    sep #$20
    lda.l $7E0000,x
    ora #EF_GROUND.b
    sta.l $7E0000,x
    lda #$00.b
    sta.l $7E000A,x
    sta.l $7E000B,x
    ; snap y
    rep #$20
    lda tile_py
    lsr a
    lsr a
    lsr a
    lsr a
    inc a
    asl a
    asl a
    asl a
    asl a
    sta.l $7E0006,x
    bra EPTurn
EPAir:
    sep #$20
    lda.l $7E0000,x
    and #$FB.b
    sta.l $7E0000,x
EPTurn:
    ; turn if wall ahead or no floor
    sep #$20
    lda.l $7E0009,x
    bmi EPLeft
    ; facing right (vx>0) wait vx high
    lda.l $7E0009,x
    bpl EPRightF
EPLeft:
    rep #$20
    .ACCU 16
    lda.l $7E0004,x
    dec a
    sta tile_px
    bra EPWall
EPRightF:
    rep #$20
    .ACCU 16
    lda.l $7E0004,x
    clc
    adc #16.w
    sta tile_px
EPWall:
    lda.l $7E0006,x
    clc
    adc #8.w
    sta tile_py
    phx
    jsr GetTile
    jsr IsSolid
    plx
    bne EPFlip
    ; ledge: tile below ahead
    rep #$20
    lda.l $7E0006,x
    dec a
    sta tile_py
    phx
    jsr GetTile
    jsr IsSolid
    plx
    bne EPNoFlip
EPFlip:
    ; negate vx
    rep #$20
    lda.l $7E0008,x
    eor #$FFFF
    inc a
    sta.l $7E0008,x
EPNoFlip:
    plp
    rts

EnemyFlyer:
    ; horizontal pixel step from vx high
    sep #$20
    lda.l $7E0009,x
    sta tmp1
    bmi EFNeg
    stz tmp1+1
    bra EFAdd
EFNeg:
    lda #$FF
    sta tmp1+1
EFAdd:
    rep #$20
    lda.l $7E0004,x
    clc
    adc tmp1
    sta.l $7E0004,x
    ; y = base_y + sine[phase]
    sep #$20
    lda.l $7E000E,x
    inc a
    inc a
    sta.l $7E000E,x
    phx
    lda.l $7E000E,x
    tax
    lda.l SineTab,x
    plx
    sta tmp1
    stz tmp1+1
    cmp #$80
    bcc EFPos
    lda #$FF
    sta tmp1+1
EFPos:
    sep #$20
    lda.l $7E000F,x
    sta tmp2
    stz tmp2+1
    rep #$20
    lda tmp2
    clc
    adc tmp1
    sta.l $7E0006,x
    ; turn at world edges
    lda.l $7E0004,x
    bpl EFNotL
    lda #$00.b
    sta.l $7E0004,x
    sta.l $7E0005,x
    jsr EPFlip
    rts
EFNotL:
    cmp world_w
    bcc EFOk
    lda world_w
    sec
    sbc #16
    sta.l $7E0004,x
    jsr EPFlip
EFOk:
    rts

DrawEnemiesSpr:
    sep #$20
    stz obj_i
DESLoop:
    lda obj_i
    cmp n_enemies
    bcc DESGo
    rts
DESGo:
    jsr EnemyPtr
    lda.l $7E0000,x
    and #EF_ALIVE.b
    beq DESNext
    rep #$20
    lda.l $7E0004,x
    sec
    sbc cam_x
    sta spr_x
    lda.l $7E0006,x
    sta tmp1
    sep #$20
    lda.l $7E0001,x
    tay
    lda SizeTab.w,y
    sta spr_large
    lda #32
    cpy #EN_FLYER
    beq DES16
    cpy #EN_FAST
    bne DESH
DES16:
    lda #16
DESH:
    jsr WorldToScreenY
    lda.l $7E0001,x
    asl a
    tay
    rep #$20
    lda TileBase.w,y
    sta spr_tile
    sep #$20
    lda.l $7E0003,x
    sta WRMPYA
    lda.l $7E0001,x
    tay
    lda TileStep.w,y
    sta WRMPYB
    nop
    nop
    nop
    nop
    rep #$20
    lda RDMPYL
    clc
    adc spr_tile
    sta spr_tile
    sep #$20
    lda PalTab.w,y
    ora #OAM_ATTR_PRI2.b
    sta spr_attr
    lda.l $7E0009,x
    bmi DESFlip
    lda spr_attr
    ora #$40.b
    sta spr_attr
DESFlip:
    phx
    jsr WriteSprite
    plx
DESNext:
    inc obj_i
    jmp DESLoop

DrawCoinsSpr:
    sep #$20
    stz coin_drawn
    stz tmp0
DCSLoop:
    lda tmp0
    cmp n_coins
    bcc DCSGo
    rts
DCSGo:
    lda coin_drawn
    cmp #COIN_DRAW_MAX
    bcs DCSDone
    jsr CoinPtr
    lda.l $7E0000,x
    beq DCSNext
    rep #$20
    lda.l $7E0002,x
    sec
    sbc cam_x
    sta spr_x
    cmp #256
    bcs DCSNext16
    lda.l $7E0004,x
    sta tmp1
    sep #$20
    lda #16
    jsr WorldToScreenY
    lda frame_counter
    lsr a
    lsr a
    lsr a
    and #1
    sta WRMPYA
    lda #2
    sta WRMPYB
    nop
    nop
    nop
    nop
    rep #$20
    lda RDMPYL
    clc
    adc #SPR_COIN_TILE
    sta spr_tile
    sep #$20
    lda #OAM_ATTR_PRI2.b
    ora #$06.b                      ; pal 3 (packed next to flyer)
    sta spr_attr
    stz spr_large
    phx
    jsr WriteSprite
    plx
    inc coin_drawn
DCSNext:
    inc tmp0
    jmp DCSLoop
DCSNext16:
    sep #$20
    bra DCSNext
DCSDone:
    rts

CoinPtr:
    sep #$20
    lda tmp0
    sta WRMPYA
    lda #COIN_SIZE
    sta WRMPYB
    nop
    nop
    nop
    nop
    rep #$20
    lda RDMPYL
    clc
    adc #COIN_WRAM & $FFFF
    tax
    sep #$20
    rts

HandleCoins:
    sep #$20
    stz tmp0
HCLoop:
    lda tmp0
    cmp n_coins
    bcc HCGo
    rts
HCGo:
    jsr CoinPtr
    lda.l $7E0000,x
    beq HCNext
    ; AABB vs player 16x24
    rep #$20
    lda.l $7E0002,x
    clc
    adc #16
    cmp pl_x
    bcc HCNext16
    lda pl_x
    clc
    adc #PLAYER_W
    cmp.l $7E0002,x
    bcc HCNext16
    lda.l $7E0004,x
    clc
    adc #16
    cmp pl_y
    bcc HCNext16
    lda pl_y
    clc
    adc #PLAYER_H
    cmp.l $7E0004,x
    bcc HCNext16
    sep #$20
    lda #$00.b
    sta.l $7E0000,x
    inc coins
    lda coins
    cmp #100
    bcc HCScore
    sbc #100
    sta coins
    inc lives
HCScore:
    ; score += 100
    rep #$20
    lda score_lo
    clc
    adc #100
    sta score_lo
    sep #$20
    lda score_hi
    adc #0
    sta score_hi
    lda #1
    sta hud_dirty
HCNext:
    inc tmp0
    jmp HCLoop
HCNext16:
    sep #$20
    bra HCNext

HandleStomp:
    sep #$20
    lda pl_flags
    and #PF_DEAD.b
    beq HSGo
    rts
HSGo:
    stz obj_i
HSLoop:
    lda obj_i
    cmp n_enemies
    bcc HSDo
    rts
HSDo:
    jsr EnemyPtr
    lda.l $7E0000,x
    and #EF_ALIVE.b
    beq HSNext
    jsr OverlapPlayer
    bcc HSNext
    ; stomp if falling (vy < 0) and feet above enemy center
    rep #$20
    lda pl_vy
    bpl HSHurt16
    lda pl_y
    cmp.l $7E0006,x
    bcc HSHurt16
    ; stomp
    sep #$20
    lda.l $7E0002,x
    dec a
    sta.l $7E0002,x
    bne HSBounce
    lda.l $7E0000,x
    and #$FE.b
    sta.l $7E0000,x
    rep #$20
    lda score_lo
    clc
    adc #200
    sta score_lo
    sep #$20
    lda score_hi
    adc #0
    sta score_hi
    lda #1
    sta hud_dirty
HSBounce:
    rep #$20
    lda #BOUNCE_VEL
    sta pl_vy
    sep #$20
    bra HSNext
HSHurt16:
    sep #$20
    jsr HurtPlayer
HSNext:
    inc obj_i
    jmp HSLoop

; X = enemy. Carry set if overlap
OverlapPlayer:
    php
    rep #$20
    lda.l $7E0004,x
    clc
    adc #16
    cmp pl_x
    bcc OPNo
    lda pl_x
    clc
    adc #PLAYER_W
    cmp.l $7E0004,x
    bcc OPNo
    lda.l $7E0006,x
    clc
    adc #16
    cmp pl_y
    bcc OPNo
    lda pl_y
    clc
    adc #PLAYER_H
    cmp.l $7E0006,x
    bcc OPNo
    plp
    sec
    rts
OPNo:
    plp
    clc
    rts

.ENDS
