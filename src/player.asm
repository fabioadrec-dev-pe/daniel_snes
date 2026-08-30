; Player physics (8.8), tile collision, Y-up world matching the Java game.

.BANK 0 SLOT 0
.SECTION "Player" FREE

SolidTab:
    .db 0,1,1,1,1,0,1,0
HazardTab:
    .db 0,0,0,0,0,1,0,0

; A = tile id -> A = 1 if solid. Always 8-bit A and Z on return.
IsSolid:
    phx
    php
    sep #$30
    .ACCU 8
    .INDEX 8
    cmp #8
    bcc ISDo
    lda #0
    bra ISDone
ISDo:
    tax
    lda SolidTab.w,x
ISDone:
    plp
    plx
    sep #$20
    .ACCU 8
    cmp #0
    rts

IsHazard:
    phx
    php
    sep #$30
    .ACCU 8
    .INDEX 8
    cmp #8
    bcc IHDo
    lda #0
    bra IHDone
IHDo:
    tax
    lda HazardTab.w,x
IHDone:
    plp
    plx
    sep #$20
    .ACCU 8
    cmp #0
    rts

; tile_px, tile_py pixels -> A tile id
GetTile:
    php
    sep #$20
    .ACCU 8
    rep #$10
    .INDEX 16
    rep #$20
    lda tile_py
    bmi GTAir
    lsr a
    lsr a
    lsr a
    lsr a
    cmp #14
    bcs GTAir
    sta tmp_row
    lda tile_px
    bmi GTAir
    lsr a
    lsr a
    lsr a
    lsr a
    cmp map_cols
    bcs GTAir
    sta tmp_col
    lda tmp_row
    and #$00FF.w
    tay
    lda #0.w
    cpy #0.w
    beq GTMulZ
GTMul:
    clc
    adc map_cols
    dey
    bne GTMul
GTMulZ:
    clc
    adc tmp_col
    clc
    adc #MAP_HEADER
    tax
    sep #$20
    lda.l $7E2000,x
    sta tile_id
    plp
    sep #$20
    lda tile_id
    rts
GTAir:
    sep #$20
    lda #0
    sta tile_id
    plp
    sep #$20
    lda #0
    rts

; Add 8.8 vel at (tmp0.w) to pos dw at (tmp1) and frac at (tmp2 as addr)... 
; Specialized: pl_vx -> pl_x/pl_xf
AddVelX:
    php
    sep #$20
    lda #$00.b
    bit pl_vx+1
    bpl AVXPos
    lda #$FF.b
AVXPos:
    pha
    lda pl_xf
    clc
    adc pl_vx
    sta pl_xf
    lda pl_x
    adc pl_vx+1
    sta pl_x
    pla
    adc pl_x+1
    sta pl_x+1
    plp
    rts

AddVelY:
    php
    sep #$20
    lda #$00.b
    bit pl_vy+1
    bpl AVYPos
    lda #$FF.b
AVYPos:
    pha
    lda pl_yf
    clc
    adc pl_vy
    sta pl_yf
    lda pl_y
    adc pl_vy+1
    sta pl_y
    pla
    adc pl_y+1
    sta pl_y+1
    plp
    rts

; Clamp pl_x to [0, world_w - 16]
ClampPlayerX:
    rep #$20
    lda pl_x
    bpl CPX0
    lda #0
    sta pl_x
    stz pl_vx
    bra CPXHi
CPX0:
    lda world_w
    sec
    sbc #PLAYER_W
    cmp pl_x
    bcs CPXHi
    sta pl_x
    stz pl_vx
CPXHi:
    sep #$20
    rts

SpawnPlayer:
    sep #$20
    lda respawn_x
    sta pl_x
    lda respawn_x+1
    sta pl_x+1
    lda respawn_y
    sta pl_y
    lda respawn_y+1
    sta pl_y+1
    stz pl_xf
    stz pl_yf
    stz pl_vx
    stz pl_vx+1
    stz pl_vy
    stz pl_vy+1
    lda #PF_FACE_R.b
    ora #PF_GROUND.b
    sta pl_flags
    stz pl_frame
    stz pl_invuln
    rts

UpdatePlayer:
    sep #$20
    lda pl_flags
    and #PF_DEAD.b
    beq UPNotDead
    jsr UpdatePlayerDead
    rts
UPNotDead:
    lda pl_flags
    and #PF_WIN.b
    beq UPNotWin
    jsr ApplyGravity
    jsr MoveCollide
    rts
UPNotWin:
    lda pl_invuln
    beq UPNoInv
    dec pl_invuln
UPNoInv:
    jsr HandleHoriz
    jsr HandleJump
    jsr ApplyGravity
    jsr MoveCollide
    jsr AnimPlayer
    jsr CheckPit
    jsr CheckSpike
    rts

UpdatePlayerDead:
    jsr ApplyGravity
    jsr AddVelY
    rts

HandleHoriz:
    sep #$20
    .ACCU 8
    lda pl_flags
    and #PF_GROUND.b
    beq HHMove
    rep #$20
    lda joy_current
    and #BUTTON_DOWN.w
    sep #$20
    beq HHMove
    ; crouch: friction only
    jmp ApplyFriction
HHMove:
    rep #$20
    .ACCU 16
    lda #WALK_SPEED
    sta tmp1
    lda joy_current
    and #BUTTON_X.w
    bne HHRun
    lda joy_current
    and #BUTTON_Y.w
    beq HHMax
HHRun:
    lda #RUN_SPEED
    sta tmp1
HHMax:
    lda joy_current
    and #BUTTON_LEFT.w
    beq HHRight
    ; accel left
    sep #$20
    lda pl_flags
    and #$FD.b
    sta pl_flags
    rep #$20
    lda pl_vx
    sec
    sbc #PLAYER_ACCEL
    sta pl_vx
    jsr ClampVX
    rts
HHRight:
    rep #$20
    .ACCU 16
    lda joy_current
    and #BUTTON_RIGHT.w
    beq HHFric
    sep #$20
    lda pl_flags
    ora #PF_FACE_R.b
    sta pl_flags
    rep #$20
    lda pl_vx
    clc
    adc #PLAYER_ACCEL
    sta pl_vx
    jsr ClampVX
    rts
HHFric:
    jmp ApplyFriction

ClampVX:
    ; tmp1 = max speed. pl_vx signed
    php
    rep #$20
    lda pl_vx
    bmi CVXNeg
    cmp tmp1
    bcc CVXOk
    lda tmp1
    sta pl_vx
    bra CVXOk
CVXNeg:
    lda tmp1
    eor #$FFFF
    inc a
    sta tmp2
    lda pl_vx
    cmp tmp2
    bcs CVXOk
    lda tmp2
    sta pl_vx
CVXOk:
    plp
    rts

ApplyFriction:
    php
    rep #$20
    lda pl_vx
    beq AFDone
    bmi AFNeg
    sec
    sbc #PLAYER_FRICTION
    bpl AFStore
    lda #0
    bra AFStore
AFNeg:
    clc
    adc #PLAYER_FRICTION
    bmi AFStore
    lda #0
AFStore:
    sta pl_vx
AFDone:
    plp
    rts

HandleJump:
    sep #$20
    lda pl_flags
    and #PF_GROUND.b
    beq HJAir
    rep #$20
    lda joy_pressed
    and #BUTTON_B.w
    bne HJDo
    lda joy_pressed
    and #BUTTON_A.w
    beq HJHeld
HJDo:
    lda #JUMP_VEL
    sta pl_vy
    sep #$20
    lda pl_flags
    and #$FE.b
    ora #PF_JUMPHELD.b
    sta pl_flags
    rts
HJAir:
HJHeld:
    rep #$20
    lda joy_current
    and #$8080.w
    sep #$20
    bne HJStill
    lda pl_flags
    and #PF_JUMPHELD.b
    beq HJDone
    ; cut jump if rising
    rep #$20
    lda pl_vy
    bmi HJClr
    lsr a
    sta pl_vy
HJClr:
    sep #$20
    lda pl_flags
    and #$FB.b
    sta pl_flags
HJStill:
HJDone:
    rts

ApplyGravity:
    php
    sep #$20
    lda pl_flags
    and #PF_GROUND.b
    beq AGDo
    plp
    rts
AGDo:
    rep #$20
    lda pl_vy
    bmi AGFull
    ; rising: maybe hold gravity
    sep #$20
    lda pl_flags
    and #PF_JUMPHELD.b
    beq AGFull8
    rep #$20
    lda joy_current
    and #$8080.w
    beq AGFull16
    lda pl_vy
    sec
    sbc #JUMP_HOLD_G
    sta pl_vy
    bra AGClamp
AGFull8:
    rep #$20
AGFull16:
AGFull:
    lda pl_vy
    sec
    sbc #GRAVITY_F
    sta pl_vy
AGClamp:
    lda pl_vy
    cmp #$8000
    bcc AGPosCheck
    ; negative (falling in Y-up): pl_vy is more negative
    lda #MAX_FALL
    eor #$FFFF
    inc a
    sta tmp0
    lda pl_vy
    cmp tmp0
    bcs AGDone
    lda tmp0
    sta pl_vy
    bra AGDone
AGPosCheck:
AGDone:
    plp
    rts

MoveCollide:
    sep #$20
    stz hit_l
    stz hit_r
    stz hit_u
    stz hit_d
    jsr AddVelX
    jsr ClampPlayerX
    jsr ResolveX
    jsr AddVelY
    jsr ResolveY
    rts

; Probe two points on the vertical edges
ResolveX:
    php
    rep #$20
    .ACCU 16
    lda pl_vx
    beq RXDone
    bmi RXLeft
    ; moving right: x+15, y+2 and y+23
    lda pl_x
    clc
    adc #15.w
    sta tile_px
    jsr RXProbe
    bcc RXDone
    ; snap: col*16 - 16
    lda tile_px
    lsr a
    lsr a
    lsr a
    lsr a
    asl a
    asl a
    asl a
    asl a
    sec
    sbc #PLAYER_W.w
    sta pl_x
    stz pl_vx
    sep #$20
    lda #1
    sta hit_r
    bra RXDone
RXLeft:
    rep #$20
    .ACCU 16
    lda pl_x
    sta tile_px
    jsr RXProbe
    bcc RXDone
    lda tile_px
    lsr a
    lsr a
    lsr a
    lsr a
    inc a
    asl a
    asl a
    asl a
    asl a
    sta pl_x
    stz pl_vx
    sep #$20
    lda #1
    sta hit_l
RXDone:
    plp
    rts

RXProbe:
    ; tile_px set. Check y+2 and y+22
    php
    rep #$20
    .ACCU 16
    lda pl_y
    clc
    adc #2.w
    sta tile_py
    jsr GetTile
    jsr IsSolid
    bne RXPHit
    rep #$20
    .ACCU 16
    lda pl_y
    clc
    adc #22.w
    sta tile_py
    jsr GetTile
    jsr IsSolid
    bne RXPHit
    plp
    clc
    rts
RXPHit:
    plp
    sec
    rts

ResolveY:
    php
    sep #$20
    lda pl_flags
    and #$FE.b
    sta pl_flags
    rep #$20
    .ACCU 16
    lda pl_vy
    bne RYMove
    ; vy=0: keep grounded if feet are on solid
    lda pl_y
    sec
    sbc #1.w
    sta tile_py
    jsr RYProbe
    bcc RYDone
    sep #$20
    lda pl_flags
    ora #PF_GROUND.b
    sta pl_flags
    bra RYDone
RYMove:
    rep #$20
    .ACCU 16
    lda pl_vy
    bpl RYUp
    ; falling (vy negative in Y-up): probe just below feet so y=32 stands on grass y=16..31
    lda pl_y
    sec
    sbc #1.w
    sta tile_py
    jsr RYProbe
    bcc RYDone
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
    sta pl_y
    stz pl_vy
    sep #$20
    lda pl_flags
    ora #PF_GROUND.b
    sta pl_flags
    lda #1
    sta hit_d
    bra RYDone
RYUp:
    rep #$20
    .ACCU 16
    lda pl_y
    clc
    adc #23.w
    sta tile_py
    jsr RYProbe
    bcc RYDone
    lda tile_py
    lsr a
    lsr a
    lsr a
    lsr a
    asl a
    asl a
    asl a
    asl a
    sec
    sbc #PLAYER_H.w
    sta pl_y
    stz pl_vy
    sep #$20
    lda #1
    sta hit_u
RYDone:
    plp
    rts

RYProbe:
    ; tile_py set. Check x+2 and x+14
    php
    rep #$20
    .ACCU 16
    lda pl_x
    clc
    adc #2.w
    sta tile_px
    jsr GetTile
    jsr IsSolid
    bne RYPHit
    rep #$20
    .ACCU 16
    lda pl_x
    clc
    adc #14.w
    sta tile_px
    jsr GetTile
    jsr IsSolid
    bne RYPHit
    plp
    clc
    rts
RYPHit:
    plp
    sec
    rts

CheckPit:
    rep #$20
    lda pl_y
    bpl CPOk                        ; y >= 0
    cmp #$FFD0.w                    ; y < -48
    bcs CPOk
    sep #$20
    jsr KillPlayer
CPOk:
    sep #$20
    rts

CheckSpike:
    sep #$20
    lda pl_invuln
    bne CSSkip
    lda pl_flags
    and #PF_DEAD.b
    bne CSSkip
    rep #$20
    lda pl_x
    clc
    adc #8
    sta tile_px
    lda pl_y
    sta tile_py
    jsr GetTile
    jsr IsHazard
    beq CSSkip
    jsr KillPlayer
CSSkip:
    rts

KillPlayer:
    sep #$20
    lda pl_flags
    ora #PF_DEAD.b
    sta pl_flags
    stz pl_vx
    stz pl_vx+1
    stz pl_invuln
    rep #$20
    lda #DEAD_VY
    sta pl_vy
    sep #$20
    lda #PL_PLAYER_DEAD
    sta pl_frame
    rts

HurtPlayer:
    sep #$20
    lda pl_invuln
    bne HPNo
    lda pl_flags
    and #PF_DEAD.b
    bne HPNo
    lda lives
    cmp #2
    bcc HPKill
    dec lives
    lda #INVULN_FRAMES.b
    sta pl_invuln
    lda pl_flags
    ora #PF_HURT.b
    sta pl_flags
    lda pl_flags
    and #PF_FACE_R.b
    beq HPRight
    rep #$20
    lda #HURT_VX
    eor #$FFFF
    inc a
    sta pl_vx
    bra HPVy
HPRight:
    rep #$20
    lda #HURT_VX
    sta pl_vx
HPVy:
    lda #HURT_VY
    sta pl_vy
    sep #$20
    lda #1
    sta hud_dirty
    lda #PL_PLAYER_HURT
    sta pl_frame
HPNo:
    rts
HPKill:
    jsr KillPlayer
    rts

AnimPlayer:
    sep #$20
    lda pl_flags
    and #PF_DEAD.b
    beq APAlive
    jmp APEnd
APAlive:
    lda pl_flags
    and #PF_WIN.b
    beq APNotWin
    lda #PL_PLAYER_WIN
    sta pl_frame
    rts
APNotWin:
    lda pl_invuln
    beq APNoHurt
    lda pl_flags
    and #PF_HURT.b
    beq APNoHurt
    lda pl_invuln
    cmp #160
    bcs APEnd
    lda pl_flags
    and #$DF.b
    sta pl_flags
APNoHurt:
    lda pl_flags
    and #PF_GROUND.b
    bne APGround
    rep #$20
    lda pl_vy
    sep #$20
    bmi APFall
    lda #PL_PLAYER_JUMP
    sta pl_frame
    rts
APFall:
    lda #PL_PLAYER_FALL
    sta pl_frame
    rts
APGround:
    rep #$20
    lda joy_current
    and #BUTTON_DOWN.w
    sep #$20
    beq APWalk
    lda #PL_PLAYER_CROUCH
    sta pl_frame
    rts
APWalk:
    rep #$20
    lda pl_vx
    beq APIdle
    bpl APAbs
    eor #$FFFF
    inc a
APAbs:
    cmp #WALK_SPEED + 20
    sep #$20
    bcc APWalkF
    lda frame_counter
    lsr a
    lsr a
    and #1
    clc
    adc #PL_PLAYER_WALK0
    ; run uses same two frames offset
    lda #PL_PLAYER_RUN
    sta pl_frame
    rts
APWalkF:
    lda frame_counter
    lsr a
    lsr a
    lsr a
    and #1
    clc
    adc #PL_PLAYER_WALK0
    sta pl_frame
    rts
APIdle:
    sep #$20
    lda frame_counter
    lsr a
    lsr a
    lsr a
    lsr a
    and #1
    sta pl_frame
APEnd:
    rts

.ENDS
