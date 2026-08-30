; Auto-joy copy. NMI enables $4200 bit 0; wait until $4212 bit 0 clears.

.BANK 0 SLOT 0
.SECTION "Input" FREE

CopyAutoJoy:
    sep #$20
    .ACCU 8
    rep #$10
    ldx #4000
CopyAutoJoyWait:
    lda HVBJOY
    and #HVBJOY_AUTOJOY.b
    beq CopyAutoJoyDone
    dex
    bne CopyAutoJoyWait
CopyAutoJoyDone:

    rep #$20
    .ACCU 16
    lda joy_current
    sta joy_previous
    lda JOY1L
    sta joy_current
    lda joy_previous
    eor #$FFFF.w
    and joy_current
    sta joy_pressed
    lda joy2_current
    sta joy2_previous
    lda JOY2L
    sta joy2_current
    lda joy2_previous
    eor #$FFFF.w
    and joy2_current
    sta joy2_pressed
    sep #$20
    .ACCU 8
    rts

.ENDS
