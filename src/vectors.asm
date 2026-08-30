; Interrupt vectors for native and emulation mode.
; Unused vectors must still point at a valid RTI. An enabled NMI without a
; safe handler is a classic cause of lockups after the title screen.

.SNESNATIVEVECTOR
    COP    UnusedInterrupt
    BRK    UnusedInterrupt
    ABORT  UnusedInterrupt
    NMI    NMI
    IRQ    UnusedInterrupt
.ENDNATIVEVECTOR

.SNESEMUVECTOR
    COP    UnusedInterrupt
    ABORT  UnusedInterrupt
    NMI    UnusedInterrupt
    RESET  Reset
    IRQBRK UnusedInterrupt
.ENDEMUVECTOR

.BANK 0 SLOT 0
.SECTION "Vectors" FREE

UnusedInterrupt:
    rti

.ENDS
