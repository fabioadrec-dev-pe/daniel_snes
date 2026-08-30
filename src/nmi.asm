; NMI: ack, OAM DMA, optional BG1 column, scroll, HUD DMA, auto-joy, frame++, nmi_ready.
; Game logic stays in the main thread.

.BANK 0 SLOT 0
.SECTION "NMI" FREE

NMI:
    php
    rep #$30
    .ACCU 16
    .INDEX 16
    pha
    phx
    phy
    lda tmp0
    pha
    lda tmp1
    pha
    lda tmp2
    pha
    lda tmp_row
    pha

    sep #$20
    .ACCU 8
    phb
    phk
    plb
    lda RDNMI

    jsr DMAOAM
    jsr ApplyScroll
    jsr StreetsNMI
    jsr EndingNMI

    lda nmi_col_need
    beq NMINoCol
    stz nmi_col_need
    jsr WritePreparedColumn
NMINoCol:
    lda hud_dirty
    beq NMINoHud
    stz hud_dirty
    jsr DmaHUD
NMINoHud:
    jsr CopyAutoJoy

    rep #$20
    inc frame_counter
    sep #$20
    lda #$01.b
    sta nmi_ready
    plb

    rep #$30
    pla
    sta tmp_row
    pla
    sta tmp2
    pla
    sta tmp1
    pla
    sta tmp0
    ply
    plx
    pla
    plp
    rti

WaitNMI:
    sep #$20
    .ACCU 8
    stz nmi_ready
WaitNMILoop:
    lda nmi_ready
    beq WaitNMILoop
    stz nmi_ready
    rts

.ENDS
