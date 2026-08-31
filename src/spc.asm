; SPC700 driver: 6 music voices + 2 SFX. Sequences are 60 Hz MIDI-derived
; events; samples are BRR. This is how the S-DSP is meant to be used.

.MEMORYMAP
    SLOTSIZE $10000
    DEFAULTSLOT 0
    SLOT 0 $0000
.ENDME

.ROMBANKSIZE $10000
.ROMBANKS 1

.DEFINE APUIO0      $F4
.DEFINE APUIO1      $F5
.DEFINE APUIO2      $F6
.DEFINE APUIO3      $F7
.DEFINE TIMER0      $FA
.DEFINE COUNTER0    $FD
.DEFINE CONTROL     $F1
.DEFINE DSPADDR     $F2
.DEFINE DSPDATA     $F3

.DEFINE CMD_PLAY    1
.DEFINE CMD_SFX     2
.DEFINE CMD_STOP    3
.DEFINE CMD_LOAD    4

.DEFINE OP_REST     $80
.DEFINE OP_INST     $81
.DEFINE OP_VOL      $82
.DEFINE OP_PAN      $83
.DEFINE OP_LOOP     $FE

.DEFINE INST_KICK   9
.DEFINE INST_SFX0   12

.ENUM $00
    ch_wait     ds 6
    ch_dur      ds 6
    ch_vol      ds 6
    ch_inst     ds 6
    ch_pan      ds 6              ; 0=hard left, 1=left, 2=center, 3=right
    ch_op       ds 6
    ch_arg      ds 6
    ch_plo      ds 6
    ch_phi      ds 6
    ch_slo      ds 6
    ch_shi      ds 6
    song_lo     db
    song_hi     db
    playing     db
    sfx_rr      db
    sfx_used    db
    sfx_t6      db
    sfx_t7      db
    sfx_k6      db              ; KOFF hold ticks for voice 6
    sfx_k7      db              ; KOFF hold ticks for voice 7
    sfx_last    db              ; last accepted SFX id
    sfx_gap     db              ; frames needed before same id can rearm
    tmp0        db
    tmp1        db
    tmp2        db
    tmp3        db
    ch          db
    kon_bits    db
    koff_bits   db
    ptr_lo      db
    ptr_hi      db
    cmd_id      db
    cmd_arg     db
.ENDE

.BANK 0 SLOT 0
.ORGA $0200
.SECTION "SpcDriver" FORCE

SpcStart:
    CLRP
    MOV     X, #$EF
    MOV     SP, X
    ; The CPU waits for the exact kick value before continuing the IPL
    ; upload handshake. Echo it before the DSP initialization work.
    MOV     A, APUIO0
    MOV     APUIO0, A
    MOV     A, #133             ; 8000/133 ≈ 60.15 Hz
    MOV     TIMER0, A
    MOV     A, #$01             ; IPL unmapped, timer0 on
    MOV     CONTROL, A
    CALL    !DspInit
    MOV     A, COUNTER0         ; ack
    MOV     APUIO0, #$00
    MOV     APUIO1, #$00
    MOV     playing, #$00
    MOV     sfx_rr, #$00
    MOV     sfx_used, #$00
    MOV     sfx_t6, #$00
    MOV     sfx_t7, #$00
    MOV     sfx_k6, #$00
    MOV     sfx_k7, #$00
    MOV     sfx_last, #$FF
    MOV     sfx_gap, #$00

MainLoop:
    CALL    !CheckCmd
    MOV     A, COUNTER0
    BEQ     MainLoop
TickAccum:
    MOV     tmp3, A
TickOne:
    CALL    !TickMusic
    DBNZ    tmp3, TickOne
    BRA     MainLoop

CheckCmd:
    MOV     A, APUIO0
    BEQ     CmdDone
    MOV     cmd_id, A
    MOV     A, APUIO1
    MOV     cmd_arg, A
    MOV     A, cmd_id
    CMP     A, #CMD_LOAD
    BNE     CheckPlayCmd
    JMP     !DoLoad
CheckPlayCmd:
    MOV     APUIO0, A           ; echo play/sfx/stop
    CMP     A, #CMD_PLAY
    BNE     CheckSfxCmd
    JMP     !DoPlay
CheckSfxCmd:
    CMP     A, #CMD_SFX
    BNE     CheckStopCmd
    JMP     !DoSfx
CheckStopCmd:
    CMP     A, #CMD_STOP
    BNE     CmdAck
    JMP     !DoStop
CmdAck:
    MOV     APUIO0, #$00
CmdDone:
    RET

DoLoad:
    MOV     A, APUIO2
    MOV     tmp0, A
    MOV     A, APUIO3
    MOV     tmp1, A
    MOV     A, #CMD_LOAD
    MOV     APUIO0, A           ; echo after length is latched
    MOV     ptr_lo, #$00
    MOV     ptr_hi, #$80
    MOV     Y, #$00
LoadByte:
    MOV     A, tmp0
    OR      A, tmp1
    BEQ     LoadDone
LoadWaitY:
    MOV     A, APUIO0
    MOV     tmp2, A
    MOV     A, Y
    CMP     A, tmp2
    BNE     LoadWaitY
    MOV     X, #$00
    MOV     A, APUIO1
    MOV     [ptr_lo+X], A
    INC     ptr_lo
    BNE     LoadB1
    INC     ptr_hi
LoadB1:
    MOV     A, APUIO2
    MOV     [ptr_lo+X], A
    INC     ptr_lo
    BNE     LoadB2
    INC     ptr_hi
LoadB2:
    MOV     A, APUIO3
    MOV     [ptr_lo+X], A
    INC     ptr_lo
    BNE     LoadB3
    INC     ptr_hi
LoadB3:
    MOV     A, Y
    MOV     APUIO0, A
    INC     Y
    INC     Y
    INC     Y
    MOV     A, tmp0
    SETC
    SBC     A, #3
    MOV     tmp0, A
    BCS     LoadByte
    DEC     tmp1
    BRA     LoadByte
LoadDone:
    ; Start every newly uploaded song immediately, without waiting for a
    ; later CPU input or PLAY handshake.
    CALL    !StartSong
    JMP     !CmdAck

DoStop:
    MOV     playing, #$00
    MOV     sfx_used, #$00
    MOV     sfx_t6, #$00
    MOV     sfx_t7, #$00
    MOV     sfx_k6, #$00
    MOV     sfx_k7, #$00
    MOV     sfx_last, #$FF
    MOV     sfx_gap, #$00
    MOV     A, #$FF
    MOV     Y, #$5C
    CALL    !DspW
    JMP     !CmdAck

DoPlay:
    CALL    !StartSong
    JMP     !CmdAck

DoSfx:
    CALL    !PlaySfx
    JMP     !CmdAck

StartSong:
    MOV     song_lo, #$00
    MOV     song_hi, #$80
    MOV     playing, #$01
    MOV     sfx_used, #$00
    MOV     sfx_t6, #$00
    MOV     sfx_t7, #$00
    MOV     sfx_k6, #$00
    MOV     sfx_k7, #$00
    MOV     sfx_last, #$FF
    MOV     sfx_gap, #$00
    MOV     A, #$FF             ; koff music and SFX voices
    MOV     Y, #$5C
    CALL    !DspW
    MOV     ch, #$00
InitCh:
    MOV     X, ch
    MOV     A, #$50
    MOV     ch_vol+X, A
    MOV     A, #$00
    MOV     ch_dur+X, A
    MOV     ch_inst+X, A
    MOV     A, #$02
    MOV     ch_pan+X, A
    ; track offset = word at song+2+ch*2
    MOV     A, ch
    ASL     A
    MOV     tmp0, A
    MOV     A, song_lo
    CLRC
    ADC     A, #$02
    MOV     ptr_lo, A
    MOV     A, song_hi
    ADC     A, #$00
    MOV     ptr_hi, A
    MOV     A, ptr_lo
    CLRC
    ADC     A, tmp0
    MOV     ptr_lo, A
    MOV     A, ptr_hi
    ADC     A, #$00
    MOV     ptr_hi, A
    CALL    !ReadPtr
    MOV     tmp0, A             ; offset lo
    CALL    !IncPtr
    CALL    !ReadPtr
    MOV     tmp1, A             ; offset hi
    MOV     A, song_lo
    CLRC
    ADC     A, tmp0
    MOV     X, ch
    MOV     ch_plo+X, A
    MOV     ch_slo+X, A
    MOV     A, song_hi
    ADC     A, tmp1
    MOV     ch_phi+X, A
    MOV     ch_shi+X, A
    CALL    !FetchCh
    INC     ch
    MOV     A, ch
    CMP     A, #$06
    BNE     InitCh
    RET

; Apply pending events whose wait has expired, then tick durations.
TickSfx:
    MOV     A, sfx_gap
    BEQ     TickSfxGapDone
    DEC     A
    MOV     sfx_gap, A
TickSfxGapDone:
    ; KOFF is sampled by the DSP asynchronously. Hold each stop request for
    ; four 60 Hz ticks so a busy DSP cannot lose the only KOFF write.
    MOV     A, sfx_k6
    BEQ     TickSfx6Run
    DEC     A
    MOV     sfx_k6, A
    CALL    !StopSfx6
    BRA     TickSfx7
TickSfx6Run:
    MOV     A, sfx_t6
    BEQ     TickSfx6Idle
    DEC     A
    MOV     sfx_t6, A
    BNE     TickSfx7
    MOV     sfx_k6, #$04
    CALL    !StopSfx6
    BRA     TickSfx7
TickSfx6Idle:
    ; Keep an inactive SFX voice electrically silent even if a previous
    ; KOFF was missed by the DSP.
    CALL    !MuteSfx6
TickSfx7:
    MOV     A, sfx_k7
    BEQ     TickSfx7Run
    DEC     A
    MOV     sfx_k7, A
    CALL    !StopSfx7
    RET
TickSfx7Run:
    MOV     A, sfx_t7
    BEQ     TickSfx7Idle
    DEC     A
    MOV     sfx_t7, A
    BNE     TickSfxDone
    MOV     sfx_k7, #$04
    CALL    !StopSfx7
    BRA     TickSfxDone
TickSfx7Idle:
    CALL    !MuteSfx7
TickSfxDone:
    RET

StopSfx6:
    MOV     A, #$80
    ; Replace the voice-7 bit with voice 6's bit.
    LSR     A
    MOV     Y, #$5C
    CALL    !DspW
    MOV     A, #$00
    MOV     Y, #$60
    CALL    !DspW
    MOV     Y, #$61
    CALL    !DspW
    RET

StopSfx7:
    MOV     A, #$80
    MOV     Y, #$5C
    CALL    !DspW
    MOV     A, #$00
    MOV     Y, #$70
    CALL    !DspW
    MOV     Y, #$71
    CALL    !DspW
    RET

MuteSfx6:
    MOV     A, #$00
    MOV     Y, #$60
    CALL    !DspW
    MOV     Y, #$61
    CALL    !DspW
    RET

MuteSfx7:
    MOV     A, #$00
    MOV     Y, #$70
    CALL    !DspW
    MOV     Y, #$71
    CALL    !DspW
    RET

TickMusic:
    CALL    !TickSfx
    MOV     A, playing
    BEQ     TickDone
    MOV     kon_bits, #$00
    MOV     koff_bits, #$00
    MOV     ch, #$00
TickCh:
    MOV     X, ch
    MOV     A, ch_dur+X
    BEQ     TickWait
    DEC     A
    MOV     ch_dur+X, A
    BNE     TickWait
    MOV     A, ch
    ASL     A
    ASL     A
    ASL     A
    ASL     A
    MOV     tmp0, A             ; v*16
    SETC
    SBC     A, tmp0             ; 0? want bit ch
    ; koff this voice: kon_bits handled below
    MOV     A, #$01
    MOV     Y, ch
ShiftKoff:
    BEQ     StoreKoff
    ASL     A
    DEC     Y
    BRA     ShiftKoff
StoreKoff:
    OR      A, koff_bits
    MOV     koff_bits, A
TickWait:
    MOV     X, ch
    MOV     A, ch_wait+X
    BEQ     NeedApply
    DEC     A
    MOV     ch_wait+X, A
    BNE     NextCh
NeedApply:
    CALL    !ApplyCh
NextCh:
    INC     ch
    MOV     A, ch
    CMP     A, #$06
    BNE     TickCh
    MOV     A, koff_bits
    BEQ     DoKon
    MOV     Y, #$5C
    CALL    !DspW
DoKon:
    MOV     A, kon_bits
    BEQ     TickDone
    MOV     Y, #$4C
    CALL    !DspW
TickDone:
    RET

ApplyCh:
    MOV     X, ch
ApplyLoop:
    MOV     A, ch_wait+X
    BNE     ApplyRet
    MOV     A, ch_op+X
    CMP     A, #OP_LOOP
    BEQ     DoLoop
    CMP     A, #OP_INST
    BEQ     DoInst
    CMP     A, #OP_VOL
    BEQ     DoVol
    CMP     A, #OP_PAN
    BEQ     DoPan
    CMP     A, #OP_REST
    BEQ     DoRest
    ; note 0-127
    CALL    !VoiceOn
    MOV     X, ch
    MOV     A, ch_arg+X
    MOV     ch_dur+X, A
    CALL    !FetchCh
    RET
DoInst:
    MOV     A, ch_arg+X
    MOV     ch_inst+X, A
    CALL    !FetchCh
    MOV     X, ch
    BRA     ApplyLoop
DoVol:
    MOV     A, ch_arg+X
    MOV     ch_vol+X, A
    CALL    !FetchCh
    MOV     X, ch
    BRA     ApplyLoop
DoPan:
    MOV     A, ch_arg+X
    MOV     ch_pan+X, A
    CALL    !FetchCh
    MOV     X, ch
    BRA     ApplyLoop
DoRest:
    MOV     A, ch_arg+X
    MOV     ch_dur+X, A
    CALL    !FetchCh
    RET
DoLoop:
    MOV     X, ch
    MOV     A, ch_slo+X
    MOV     ch_plo+X, A
    MOV     A, ch_shi+X
    MOV     ch_phi+X, A
    CALL    !FetchCh
    MOV     X, ch
    BRA     ApplyLoop
ApplyRet:
    RET

FetchCh:
    MOV     X, ch
    MOV     A, ch_plo+X
    MOV     ptr_lo, A
    MOV     A, ch_phi+X
    MOV     ptr_hi, A
    CALL    !ReadPtr
    MOV     X, ch
    MOV     ch_wait+X, A
    CALL    !IncPtr
    CALL    !ReadPtr
    MOV     X, ch
    MOV     ch_op+X, A
    CALL    !IncPtr
    CALL    !ReadPtr
    MOV     X, ch
    MOV     ch_arg+X, A
    CALL    !IncPtr
    MOV     X, ch
    MOV     A, ptr_lo
    MOV     ch_plo+X, A
    MOV     A, ptr_hi
    MOV     ch_phi+X, A
    RET

ReadPtr:
    MOV     X, #$00
    MOV     A, [ptr_lo+X]
    RET

IncPtr:
    INC     ptr_lo
    BNE     IncPtrDone
    INC     ptr_hi
IncPtrDone:
    RET

; Start note on music voice `ch`. Uses ch_op as MIDI note, ch_inst, ch_vol.
VoiceOn:
    MOV     A, ch
    ASL     A
    ASL     A
    ASL     A
    ASL     A
    MOV     tmp2, A             ; v*16
    MOV     X, ch
    MOV     A, ch_inst+X
    MOV     Y, tmp2
    ; Y = v*16 + 4 (SRCN)
    MOV     A, Y
    CLRC
    ADC     A, #$04
    MOV     Y, A
    MOV     A, ch_inst+X
    CALL    !DspW
    ; ADSR
    MOV     A, tmp2
    CLRC
    ADC     A, #$05
    MOV     Y, A
    MOV     A, ch_inst+X
    CMP     A, #INST_KICK
    BCS     PercAdsr
    MOV     A, #$8F
    CALL    !DspW
    MOV     A, tmp2
    CLRC
    ADC     A, #$06
    MOV     Y, A
    MOV     A, #$E8
    CALL    !DspW
    BRA     SetPitch
PercAdsr:
    MOV     A, #$00             ; GAIN mode
    CALL    !DspW
    MOV     A, tmp2
    CLRC
    ADC     A, #$07
    MOV     Y, A
    MOV     A, #$7F
    CALL    !DspW
SetPitch:
    MOV     X, ch
    MOV     A, ch_inst+X
    CMP     A, #INST_KICK
    BCS     PercPUse
    MOV     A, ch_op+X          ; MIDI note
    ASL     A
    MOV     Y, A
    MOV     A, !PitchTab+Y
    MOV     tmp0, A
    INC     Y
    MOV     A, !PitchTab+Y
    MOV     tmp1, A
    BRA     WritePitch
PercPUse:
    SETC
    SBC     A, #INST_KICK
    ASL     A
    MOV     Y, A
    MOV     A, !PercPTab+Y
    MOV     tmp0, A
    INC     Y
    MOV     A, !PercPTab+Y
    MOV     tmp1, A
WritePitch:
    MOV     A, tmp2
    CLRC
    ADC     A, #$02
    MOV     Y, A
    MOV     A, tmp0
    CALL    !DspW
    MOV     A, tmp2
    CLRC
    ADC     A, #$03
    MOV     Y, A
    MOV     A, tmp1
    CALL    !DspW
    ; volume L/R.  The Java MIDI pans the accompaniment away from the
    ; center; retain a gentle version of that separation on the SNES.
    MOV     X, ch
    MOV     A, ch_vol+X
    LSR     A                   ; 0-63-ish
    MOV     tmp0, A
    MOV     A, ch_pan+X
    CMP     A, #$01
    BEQ     PanLeft
    CMP     A, #$03
    BEQ     PanRight
PanCenter:
    MOV     A, tmp2
    MOV     Y, A                ; VOLL
    MOV     A, tmp0
    CALL    !DspW
    MOV     A, tmp2
    INC     A
    MOV     Y, A                ; VOLR
    MOV     A, tmp0
    CALL    !DspW
    BRA     PanDone
PanLeft:
    MOV     A, tmp2
    MOV     Y, A                ; VOLL
    MOV     A, tmp0
    CALL    !DspW
    MOV     A, tmp2
    INC     A
    MOV     Y, A                ; VOLR
    MOV     A, tmp0
    LSR     A
    CALL    !DspW
    BRA     PanDone
PanRight:
    MOV     A, tmp2
    MOV     Y, A                ; VOLL
    MOV     A, tmp0
    LSR     A
    CALL    !DspW
    MOV     A, tmp2
    INC     A
    MOV     Y, A                ; VOLR
    MOV     A, tmp0
    CALL    !DspW
PanDone:
    ; KON bit
    MOV     A, #$01
    MOV     Y, ch
KonShift:
    BEQ     KonStore
    ASL     A
    DEC     Y
    BRA     KonShift
KonStore:
    OR      A, kon_bits
    MOV     kon_bits, A
    RET

PlaySfx:
    ; A duplicated command or a collision that remains true must not turn
    ; one event into an endless retrigger. The same id is rearmed only after
    ; three ticks without another copy of that command.
    MOV     A, cmd_arg
    CMP     A, sfx_last
    BNE     SfxNotRepeat
    MOV     A, sfx_gap
    BEQ     SfxNotRepeat
    MOV     sfx_gap, #$03
    RET
SfxNotRepeat:
    ; Select a free voice 6 or 7. Never retrigger a voice while its BRR
    ; sample is active: that restart is what produces phase noise.
    MOV     A, sfx_rr
    EOR     A, #$01
    MOV     sfx_rr, A
    CLRC
    ADC     A, #$06
    MOV     tmp3, A             ; preferred voice
    MOV     tmp1, #$00          ; alternate-attempt flag
SfxChooseVoice:
    MOV     A, tmp3
    ASL     A
    ASL     A
    ASL     A
    ASL     A
    MOV     tmp2, A             ; v*16
    MOV     A, tmp3
    CMP     A, #$07
    BEQ     SfxChoose7
    MOV     A, #$40
    BRA     SfxChooseMask
SfxChoose7:
    MOV     A, #$80
SfxChooseMask:
    MOV     tmp0, A             ; selected voice bit
    MOV     A, sfx_used
    AND     A, tmp0
    BEQ     SfxVoiceFree
    MOV     A, tmp3
    CMP     A, #$07
    BEQ     SfxCheckTimer7
    MOV     A, sfx_t6
    BRA     SfxCheckTimer
SfxCheckTimer7:
    MOV     A, sfx_t7
SfxCheckTimer:
    BNE     SfxVoiceBusy
    MOV     A, tmp3
    CMP     A, #$07
    BEQ     SfxCheckKill7
    MOV     A, sfx_k6
    BRA     SfxCheckKill
SfxCheckKill7:
    MOV     A, sfx_k7
SfxCheckKill:
    BEQ     SfxVoiceFree        ; KOFF hold has finished
SfxVoiceBusy:
    MOV     A, tmp1
    BEQ     SfxTryAlternate
    JMP     !SfxDrop            ; both SFX voices are still active
SfxTryAlternate:
    MOV     tmp1, #$01
    MOV     A, tmp3
    EOR     A, #$01
    MOV     tmp3, A
    BRA     SfxChooseVoice
SfxVoiceFree:
    MOV     A, sfx_used
    OR      A, tmp0
    MOV     sfx_used, A
    MOV     A, cmd_arg
    MOV     sfx_last, A
    MOV     sfx_gap, #$03
    ; Duration in 60 Hz ticks for the 12 kHz one-shot samples.
    MOV     Y, cmd_arg
    MOV     A, !SfxFrames+Y
    MOV     tmp1, A
    MOV     A, tmp3
    CMP     A, #$07
    BEQ     SfxTimer7
    MOV     A, tmp1
    MOV     sfx_t6, A
    BRA     SfxTimerDone
SfxTimer7:
    MOV     A, tmp1
    MOV     sfx_t7, A
SfxTimerDone:
    MOV     A, cmd_arg
    CLRC
    ADC     A, #INST_SFX0
    MOV     tmp1, A             ; srcn
    ; SRCN
    MOV     A, tmp2
    CLRC
    ADC     A, #$04
    MOV     Y, A
    MOV     A, tmp1
    CALL    !DspW
    ; GAIN
    MOV     A, tmp2
    CLRC
    ADC     A, #$05
    MOV     Y, A
    MOV     A, #$00
    CALL    !DspW
    MOV     A, tmp2
    CLRC
    ADC     A, #$07
    MOV     Y, A
    MOV     A, #$7F
    CALL    !DspW
    ; pitch $0800
    MOV     A, tmp2
    CLRC
    ADC     A, #$02
    MOV     Y, A
    MOV     A, #$00
    CALL    !DspW
    MOV     A, tmp2
    CLRC
    ADC     A, #$03
    MOV     Y, A
    MOV     A, #$06
    CALL    !DspW
    ; vol
    MOV     A, tmp2
    MOV     Y, A
    MOV     A, #$48
    CALL    !DspW
    MOV     A, tmp2
    INC     A
    MOV     Y, A
    MOV     A, #$48
    CALL    !DspW
    MOV     A, tmp3
    CMP     A, #$07
    BEQ     SfxKon7
    MOV     A, #$40
    BRA     SfxKon
SfxKon7:
    MOV     A, #$80
SfxKon:
    MOV     tmp0, A
    MOV     Y, #$4C
    MOV     A, tmp0
    CALL    !DspW
    RET
SfxDrop:
    RET

DspInit:
    MOV     A, #$E0             ; reset, mute, echo off
    MOV     Y, #$6C
    CALL    !DspW
    MOV     A, #$00
    MOV     Y, #$2C             ; evol L
    CALL    !DspW
    MOV     Y, #$3C
    CALL    !DspW
    MOV     Y, #$4D             ; eon
    CALL    !DspW
    MOV     Y, #$3D             ; noise
    CALL    !DspW
    MOV     Y, #$2D             ; pmon
    CALL    !DspW
    MOV     Y, #$5D
    MOV     A, #$0F             ; DIR page $0F00
    CALL    !DspW
    MOV     A, #$50             ; lower master music level; leave headroom
    MOV     Y, #$0C             ; mvol L
    CALL    !DspW
    MOV     Y, #$1C
    CALL    !DspW
    MOV     A, #$FF
    MOV     Y, #$5C
    CALL    !DspW
    MOV     A, #$20             ; unmute, echo stays off
    MOV     Y, #$6C
    CALL    !DspW
    RET

; A = value, Y = DSP register
DspW:
    MOV     DSPADDR, Y
    ; The S-DSP port needs a short settle time between address and data.
    ; Without it, consecutive KON/KOFF/volume writes can be dropped.
    NOP
    NOP
    NOP
    NOP
    NOP
    NOP
    NOP
    NOP
    MOV     DSPDATA, A
    NOP
    NOP
    NOP
    NOP
    RET

; Percussion / one-shot default pitches (14-bit), INST_KICK.. and extra.
PercPTab:
    .dw $0600, $0800, $0C00     ; kick snare hat
    .dw $0A00                   ; hit unused here
    .dw $0800, $0800, $0800, $0800, $0800, $0800, $0800, $0800, $0800, $0800

; BRR lengths at pitch $0600, rounded up to 60 Hz ticks.
SfxFrames:
    .db 10, 10, 18, 14, 10, 33, 48, 4, 5, 24

.ENDS

.ORGA $0E00
.SECTION "PitchTab" FORCE
PitchTab:
    .INCBIN "gen/spc_pitch.bin"
.ENDS

.ORGA $0F00
.SECTION "SampleDir" FORCE
SampleDir:
    .INCBIN "gen/spc_dir.bin"
.ENDS

.ORGA $1000
.SECTION "BrrData" FORCE
BrrData:
    .INCBIN "gen/spc_brr.bin"
.ENDS
