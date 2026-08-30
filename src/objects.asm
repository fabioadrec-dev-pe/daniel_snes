; Enemies and coins. Same patrol/stomp rules as the Java game, without audio.
; Walker/fast/tank: ground patrol. Flyer: sine flight + wall turn. Boss: patrol + jump.

.BANK 0 SLOT 0
.SECTION "Objects" FREE

HpTab:
    .db 1,1,1,3,5
SpdTab:
    .dw SPD_WALKER, SPD_FLYER, SPD_FAST, SPD_TANK, SPD_BOSS
; OAM attr: pri2 | pal<<1. walker=1 flyer=2 fast=4 tank=5 boss=6 (coin=3 castle=7)
AttrTab:
    .db $22,$24,$28,$2A,$2C
SizeTab:
    .db 1,0,0,1,2                    ; 32 / 16 / 16 / 32 / 48 (boss metasprite)
TileBase:
    .dw SPR_WALKER_TILE, SPR_FLYER_TILE, SPR_FAST_TILE, SPR_TANK_TILE, SPR_BOSS_TILE
TileStep:
    .db 4,2,2,4,6                    ; 32px stride 4, 16px stride 2, 48px stride 6
HitW:
    .db 24,16,16,24,48
HitH:
    .db 24,16,16,24,48
SprH:
    .db 32,16,16,32,48
SprXOff:
    .db 4,0,0,4,0                    ; 32px pad around 24px boxes
AnimDelay:
    .db 9,12,5,15,18                 ; ~0.15 / 0.20 / 0.08 / 0.25 / 0.30 s
AnimFrames:
    .db 4,2,4,2,2
PtsTab:
    .dw 200,250,300,500,5000

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
    sta.l $7E0000+EN_OFF_TYPE,x
    lda #EF_ALIVE.b
    sta.l $7E0000+EN_OFF_FLAGS,x
    lda.l $7E0000+EN_OFF_TYPE,x
    phx
    rep #$20
    and #$00FF.w
    tay
    sep #$20
    lda HpTab.w,y
    plx
    sta.l $7E0000+EN_OFF_HP,x
    jsr Read7EInc
    sep #$20
    ldx tmp2
    sta.l $7E0000+EN_OFF_X,x
    jsr Read7EInc
    sep #$20
    ldx tmp2
    sta.l $7E0000+EN_OFF_X+1,x
    jsr Read7EInc
    sep #$20
    ldx tmp2
    sta.l $7E0000+EN_OFF_Y,x
    sta.l $7E0000+EN_OFF_BASEY,x
    jsr Read7EInc
    sep #$20
    ldx tmp2
    sta.l $7E0000+EN_OFF_Y+1,x
    lda.l $7E0000+EN_OFF_TYPE,x
    rep #$20
    and #$00FF.w
    asl a
    tay
    lda SpdTab.w,y
    eor #$FFFF
    inc a
    sta.l $7E0000+EN_OFF_VX,x
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
    lda.l $7E0000+EN_OFF_FLAGS,x
    and #EF_ALIVE.b
    beq UENext
    lda.l $7E0000+EN_OFF_TYPE,x
    cmp #EN_FLYER
    beq UEFlyer
    jsr EnemyPatrol
    bra UEAnim
UEFlyer:
    jsr EnemyFlyer
UEAnim:
    lda.l $7E0000+EN_OFF_ATIMER,x
    inc a
    sta.l $7E0000+EN_OFF_ATIMER,x
    lda.l $7E0000+EN_OFF_TYPE,x
    rep #$20
    and #$00FF.w
    tay
    sep #$20
    lda.l $7E0000+EN_OFF_ATIMER,x
    cmp AnimDelay.w,y
    bcc UENext
    lda #$00.b
    sta.l $7E0000+EN_OFF_ATIMER,x
    lda.l $7E0000+EN_OFF_ANIM,x
    inc a
    sta.l $7E0000+EN_OFF_ANIM,x
    cmp AnimFrames.w,y
    bcc UENext
    lda #$00.b
    sta.l $7E0000+EN_OFF_ANIM,x
UENext:
    inc obj_i
    jmp UELoop

EnemyPtr:
    ; obj_i = index -> X = ENEMY_WRAM + i*ENEMY_SIZE
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
    ; 8-bit TAY/TAX copies hidden B into YH/XH. Pointers live in $30xx, so
    ; leave B=0 or type-as-index becomes $30tt and every .w,y table reads 0.
    lda #$0000.w
    sep #$20
    rts

; 8.8 vx -> x,xf. X = enemy ptr.
EnemyAddVelX:
    php
    sep #$20
    lda #$00.b
    lda.l $7E0000+EN_OFF_VX+1,x
    bpl EAXPos
    lda #$FF.b
    bra EAXSign
EAXPos:
    lda #$00.b
EAXSign:
    pha
    lda.l $7E0000+EN_OFF_XF,x
    clc
    adc.l $7E0000+EN_OFF_VX,x
    sta.l $7E0000+EN_OFF_XF,x
    lda.l $7E0000+EN_OFF_X,x
    adc.l $7E0000+EN_OFF_VX+1,x
    sta.l $7E0000+EN_OFF_X,x
    pla
    adc.l $7E0000+EN_OFF_X+1,x
    sta.l $7E0000+EN_OFF_X+1,x
    plp
    rts

EnemyAddVelY:
    php
    sep #$20
    lda.l $7E0000+EN_OFF_VY+1,x
    bpl EAYPos
    lda #$FF.b
    bra EAYSign
EAYPos:
    lda #$00.b
EAYSign:
    pha
    lda.l $7E0000+EN_OFF_YF,x
    clc
    adc.l $7E0000+EN_OFF_VY,x
    sta.l $7E0000+EN_OFF_YF,x
    lda.l $7E0000+EN_OFF_Y,x
    adc.l $7E0000+EN_OFF_VY+1,x
    sta.l $7E0000+EN_OFF_Y,x
    pla
    adc.l $7E0000+EN_OFF_Y+1,x
    sta.l $7E0000+EN_OFF_Y+1,x
    plp
    rts

EnemyFlipVx:
    php
    rep #$20
    .ACCU 16
    lda.l $7E0000+EN_OFF_VX,x
    eor #$FFFF
    inc a
    sta.l $7E0000+EN_OFF_VX,x
    plp
    rts

EnemyPatrol:
    ; gravity + 8.8 move + turn on wall / grounded ledge. X = ptr
    php
    sep #$20
    .ACCU 8
    rep #$10
    .INDEX 16
    phx
    lda.l $7E0000+EN_OFF_TYPE,x
    cmp #EN_BOSS
    bne EPNoBoss
    lda.l $7E0000+EN_OFF_TIMER,x
    inc a
    sta.l $7E0000+EN_OFF_TIMER,x
    cmp #BOSS_JUMP_T
    bcc EPNoBoss
    lda.l $7E0000+EN_OFF_FLAGS,x
    and #EF_GROUND.b
    beq EPNoBoss
    lda #$00.b
    sta.l $7E0000+EN_OFF_TIMER,x
    rep #$20
    lda #BOSS_JUMP_V
    sta.l $7E0000+EN_OFF_VY,x
    sep #$20
    lda.l $7E0000+EN_OFF_FLAGS,x
    and #$FB.b
    sta.l $7E0000+EN_OFF_FLAGS,x
EPNoBoss:
    plx
    ; gravity
    rep #$20
    .ACCU 16
    lda.l $7E0000+EN_OFF_VY,x
    sec
    sbc #GRAVITY_F.w
    sta.l $7E0000+EN_OFF_VY,x
    jsr EnemyAddVelX
    jsr EnemyAddVelY
    ; feet: center-x, y-1. While rising, do not treat a platform we jump
    ; into as a floor — that snapped the 48px boss up onto every ledge.
    sep #$20
    lda.l $7E0000+EN_OFF_TYPE,x
    rep #$20
    and #$00FF.w
    tay
    sep #$20
    lda HitW.w,y
    lsr a
    sta tmp0
    stz tmp0+1
    rep #$20
    lda.l $7E0000+EN_OFF_X,x
    clc
    adc tmp0
    sta tile_px
    lda.l $7E0000+EN_OFF_VY,x
    beq EPFloor
    bmi EPFloor
    jmp EPAir
EPFloor:
    lda.l $7E0000+EN_OFF_Y,x
    dec a
    sta tile_py
    phx
    jsr GetTile
    jsr IsSolid
    plx
    beq EPAir
    sep #$20
    lda tile_id
    cmp #TILE_PLATFORM
    beq EPAir
    lda.l $7E0000+EN_OFF_TYPE,x
    cmp #EN_BOSS
    bne EPSnap
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
    cmp #40.w
    bcc EPSnap16
    jmp EPAir
EPSnap:
    rep #$20
EPSnap16:
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
    sta tmp1
    lda.l $7E0000+EN_OFF_Y,x
    sta tmp0
    lda tmp1
    sec
    sbc tmp0
    beq EPLand
    bcc EPLand
    cmp #8.w
    bcc EPLand
    jmp EPAir
EPLand:
    lda tmp1
    sta.l $7E0000+EN_OFF_Y,x
    sep #$20
    lda.l $7E0000+EN_OFF_FLAGS,x
    ora #EF_GROUND.b
    sta.l $7E0000+EN_OFF_FLAGS,x
    lda #$00.b
    sta.l $7E0000+EN_OFF_VY,x
    sta.l $7E0000+EN_OFF_VY+1,x
    sta.l $7E0000+EN_OFF_YF,x
    bra EPTurn
EPAir:
    sep #$20
    lda.l $7E0000+EN_OFF_FLAGS,x
    and #$FB.b
    sta.l $7E0000+EN_OFF_FLAGS,x
EPTurn:
    ; Ahead tile at the feet. Skip a mid-body wall probe: the 48px boss
    ; treated floating platforms as walls and spun in place.
    sep #$20
    lda.l $7E0000+EN_OFF_TYPE,x
    rep #$20
    and #$00FF.w
    tay
    sep #$20
    lda HitW.w,y
    sta tmp0
    stz tmp0+1
    lda.l $7E0000+EN_OFF_VX+1,x
    bmi EPLeft
    rep #$20
    lda.l $7E0000+EN_OFF_X,x
    clc
    adc tmp0
    sta tile_px
    bra EPLedge
EPLeft:
    rep #$20
    lda.l $7E0000+EN_OFF_X,x
    dec a
    sta tile_px
EPLedge:
    sep #$20
    lda.l $7E0000+EN_OFF_FLAGS,x
    and #EF_GROUND.b
    beq EPEdge
    rep #$20
    lda.l $7E0000+EN_OFF_Y,x
    dec a
    sta tile_py
    phx
    jsr GetTile
    jsr IsSolid
    plx
    bne EPEdge
    jsr EnemyFlipVx
EPEdge:
    rep #$20
    lda.l $7E0000+EN_OFF_X,x
    bpl EPNotL
    lda #0
    sta.l $7E0000+EN_OFF_X,x
    jsr EnemyFlipVx
    bra EPNoFlip
EPNotL:
    lda world_w
    sec
    sbc tmp0
    cmp.l $7E0000+EN_OFF_X,x
    bcs EPNoFlip
    sta.l $7E0000+EN_OFF_X,x
    jsr EnemyFlipVx
EPNoFlip:
    plp
    rts

EnemyFlyer:
    jsr EnemyAddVelX
    ; y = base_y + sine[phase]
    sep #$20
    lda.l $7E0000+EN_OFF_TIMER,x
    inc a
    inc a
    sta.l $7E0000+EN_OFF_TIMER,x
    phx
    lda.l $7E0000+EN_OFF_TIMER,x
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
    lda.l $7E0000+EN_OFF_BASEY,x
    sta tmp2
    stz tmp2+1
    rep #$20
    lda tmp2
    clc
    adc tmp1
    sta.l $7E0000+EN_OFF_Y,x
    ; wall at ahead x, center y
    sep #$20
    lda.l $7E0000+EN_OFF_VX+1,x
    bmi EFWallL
    rep #$20
    lda.l $7E0000+EN_OFF_X,x
    clc
    adc #16.w
    sta tile_px
    bra EFWallY
EFWallL:
    rep #$20
    lda.l $7E0000+EN_OFF_X,x
    dec a
    sta tile_px
EFWallY:
    lda.l $7E0000+EN_OFF_Y,x
    clc
    adc #8.w
    sta tile_py
    phx
    jsr GetTile
    jsr IsSolid
    plx
    beq EFNoWall
    jsr EnemyFlipVx
EFNoWall:
    ; world edges
    rep #$20
    lda.l $7E0000+EN_OFF_X,x
    bpl EFNotL
    lda #0
    sta.l $7E0000+EN_OFF_X,x
    jsr EnemyFlipVx
    rts
EFNotL:
    cmp world_w
    bcc EFOk
    lda world_w
    sec
    sbc #16
    sta.l $7E0000+EN_OFF_X,x
    jsr EnemyFlipVx
EFOk:
    rts

DrawEnemiesSpr:
    sep #$20
    .ACCU 8
    rep #$10
    .INDEX 16
    stz obj_i
DESLoop:
    lda obj_i
    cmp n_enemies
    bcc DESGo
    rts
DESGo:
    jsr EnemyPtr
    lda.l $7E0000+EN_OFF_FLAGS,x
    and #EF_ALIVE.b
    bne DESAlive
    jmp DESNext
DESAlive:
    lda.l $7E0000+EN_OFF_TYPE,x
    cmp #EN_BOSS
    bne DESNorm
    jsr DrawBossSpr
    jmp DESNext
DESNorm:
    sep #$20
    .ACCU 8
    lda.l $7E0000+EN_OFF_TYPE,x
    rep #$20
    and #$00FF.w
    tay
    sep #$20
    lda SprXOff.w,y
    sta tmp0
    stz tmp0+1
    lda SizeTab.w,y
    sta spr_large
    lda AttrTab.w,y
    sta spr_attr
    lda SprH.w,y
    sta tmp2
    lda TileStep.w,y
    sta tmp2+1
    rep #$20
    lda.l $7E0000+EN_OFF_X,x
    sec
    sbc cam_x
    sec
    sbc tmp0
    sta spr_x
    lda.l $7E0000+EN_OFF_Y,x
    sta tmp1
    sep #$20
    lda tmp2
    jsr WorldToScreenY
    lda.l $7E0000+EN_OFF_TYPE,x
    rep #$20
    and #$00FF.w
    asl a
    tay
    lda TileBase.w,y
    sta spr_tile
    sep #$20
    lda.l $7E0000+EN_OFF_ANIM,x
    sta WRMPYA
    lda tmp2+1
    sta WRMPYB
    nop
    nop
    nop
    nop
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
    lda.l $7E0000+EN_OFF_VX+1,x
    bpl DESNoFlip
    lda spr_attr
    ora #$40.b
    sta spr_attr
DESNoFlip:
    phx
    jsr WriteSprite
    plx
DESNext:
    inc obj_i
    jmp DESLoop

; 48×48 boss = 3×3 of 16×16. Frame 1 sits 6 tiles to the right of frame 0.
; tmp2 = origin screen X, hit_d = origin screen Y. WriteSprite only clobbers tmp0.
DrawBossSpr:
    php
    sep #$20
    .ACCU 8
    rep #$10
    .INDEX 16
    phx
    rep #$20
    lda.l $7E0000+EN_OFF_Y,x
    sta tmp1
    sep #$20
    lda #48
    jsr WorldToScreenY
    lda spr_y
    sta hit_d
    ldy #EN_BOSS
    lda AttrTab.w,y
    sta spr_attr
    lda.l $7E0000+EN_OFF_VX+1,x
    bpl DBSAttr
    lda spr_attr
    ora #$40.b
    sta spr_attr
DBSAttr:
    stz spr_large
    rep #$20
    lda.l $7E0000+EN_OFF_X,x
    sec
    sbc cam_x
    sta tmp2                        ; origin screen X
    sep #$20
    stz tmp_row
    stz tmp_row+1
DBSRow:
    stz tmp_col
    stz tmp_col+1
DBSCol:
    lda spr_attr
    and #$40.b
    beq DBSColN
    lda #2
    sec
    sbc tmp_col
    bra DBSColX
DBSColN:
    lda tmp_col
DBSColX:
    sta WRMPYA
    lda #16
    sta WRMPYB
    nop
    nop
    nop
    nop
    rep #$20
    lda RDMPYL
    clc
    adc tmp2
    sta spr_x
    lda #SPR_BOSS_TILE
    sta spr_tile
    sep #$20
    lda.l $7E0000+EN_OFF_ANIM,x
    sta WRMPYA
    lda #6
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
    lda tmp_col
    asl a
    rep #$20
    and #$00FF.w
    clc
    adc spr_tile
    sta spr_tile
    sep #$20
    lda tmp_row
    asl a
    asl a
    asl a
    asl a
    asl a                           ; *32
    rep #$20
    and #$00FF.w
    clc
    adc spr_tile
    sta spr_tile
    sep #$20
    lda tmp_row
    sta WRMPYA
    lda #16
    sta WRMPYB
    nop
    nop
    nop
    nop
    lda hit_d
    clc
    adc RDMPYL
    sta spr_y
    phx
    jsr WriteSprite
    plx
    sep #$20
    inc tmp_col
    lda tmp_col
    cmp #3
    bcs DBSNextRow
    jmp DBSCol
DBSNextRow:
    inc tmp_row
    lda tmp_row
    cmp #3
    bcs DBSDone
    jmp DBSRow
DBSDone:
    plx
    plp
    rts

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
    lda.l $7E0000+EN_OFF_FLAGS,x
    and #EF_ALIVE.b
    beq HSNext
    jsr OverlapPlayer
    bcc HSNext
    ; stomp if falling and feet above enemy center (Java)
    rep #$20
    lda pl_vy
    bpl HSHurt16
    sep #$20
    lda.l $7E0000+EN_OFF_TYPE,x
    rep #$20
    and #$00FF.w
    tay
    sep #$20
    lda HitH.w,y
    lsr a
    sta tmp0
    stz tmp0+1
    rep #$20
    lda.l $7E0000+EN_OFF_Y,x
    clc
    adc tmp0
    sta tmp0
    lda pl_y
    cmp tmp0
    bcc HSHurt16
    ; stomp: always score (Java awards every successful stomp)
    sep #$20
    lda.l $7E0000+EN_OFF_TYPE,x
    rep #$20
    and #$00FF.w
    asl a
    tay
    lda PtsTab.w,y
    clc
    adc score_lo
    sta score_lo
    sep #$20
    lda score_hi
    adc #0
    sta score_hi
    lda #1
    sta hud_dirty
    lda.l $7E0000+EN_OFF_HP,x
    dec a
    sta.l $7E0000+EN_OFF_HP,x
    bne HSBounce
    lda.l $7E0000+EN_OFF_FLAGS,x
    and #$FE.b
    sta.l $7E0000+EN_OFF_FLAGS,x
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

; X = enemy. Carry set if overlap. Uses type hitbox (Java sizes).
OverlapPlayer:
    php
    sep #$20
    lda.l $7E0000+EN_OFF_TYPE,x
    rep #$20
    and #$00FF.w
    tay
    sep #$20
    lda HitW.w,y
    sta tmp0
    stz tmp0+1
    lda HitH.w,y
    sta tmp2
    stz tmp2+1
    rep #$20
    lda.l $7E0000+EN_OFF_X,x
    clc
    adc tmp0
    cmp pl_x
    bcc OPNo
    lda pl_x
    clc
    adc #PLAYER_W
    cmp.l $7E0000+EN_OFF_X,x
    bcc OPNo
    lda.l $7E0000+EN_OFF_Y,x
    clc
    adc tmp2
    cmp pl_y
    bcc OPNo
    lda pl_y
    clc
    adc #PLAYER_H
    cmp.l $7E0000+EN_OFF_Y,x
    bcc OPNo
    plp
    sec
    rts
OPNo:
    plp
    clc
    rts

.ENDS
