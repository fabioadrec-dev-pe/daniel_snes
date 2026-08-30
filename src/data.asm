; Banked graphics and baked stages. CPU code stays in bank $00 (no JSL/JML).

.BANK 1 SLOT 0
.ORGA $8000
.SECTION "SharedGfx" FORCE
TilesetChr: .INCBIN "gen/tileset.chr"
SpriteChr:  .INCBIN "gen/sprites.chr"
FontChr:    .INCBIN "gen/font.chr"
SharedPal:  .INCBIN "gen/shared_pal.bin"
SpritePal:  .INCBIN "gen/sprite_pal.bin"
SineTab:    .INCBIN "gen/sine.bin"
Strings:    .INCBIN "gen/strings.bin"
Streets:    .INCBIN "gen/streets.bin"
FontM7:     .INCBIN "gen/font_m7.bin"
M7Persp:    .INCBIN "gen/m7persp.bin"
.ENDS

.BANK 2 SLOT 0
.ORGA $8000
.SECTION "BGStage1" FORCE
Bg1Chr: .INCBIN "gen/bg1.chr"
Bg1Map: .INCBIN "gen/bg1.map"
Bg1Pal: .INCBIN "gen/bg1.pal"
.ENDS

.BANK 3 SLOT 0
.ORGA $8000
.SECTION "BGStage2" FORCE
Bg2Chr: .INCBIN "gen/bg2.chr"
Bg2Map: .INCBIN "gen/bg2.map"
Bg2Pal: .INCBIN "gen/bg2.pal"
.ENDS

.BANK 4 SLOT 0
.ORGA $8000
.SECTION "BGStage3" FORCE
Bg3Chr: .INCBIN "gen/bg3.chr"
Bg3Map: .INCBIN "gen/bg3.map"
Bg3Pal: .INCBIN "gen/bg3.pal"
.ENDS

.BANK 5 SLOT 0
.ORGA $8000
.SECTION "BGStage4" FORCE
Bg4Chr: .INCBIN "gen/bg4.chr"
Bg4Map: .INCBIN "gen/bg4.map"
Bg4Pal: .INCBIN "gen/bg4.pal"
.ENDS

.BANK 6 SLOT 0
.ORGA $8000
.SECTION "BGStage5" FORCE
Bg5Chr: .INCBIN "gen/bg5.chr"
Bg5Map: .INCBIN "gen/bg5.map"
Bg5Pal: .INCBIN "gen/bg5.pal"
.ENDS

.BANK 7 SLOT 0
.ORGA $8000
.SECTION "BGMenu" FORCE
MenuChr: .INCBIN "gen/menu.chr"
MenuMap: .INCBIN "gen/menu.map"
MenuPal: .INCBIN "gen/menu.pal"
.ENDS

.BANK 8 SLOT 0
.ORGA $8000
.SECTION "StageBlob" FORCE
Stage0: .INCBIN "gen/stage0.bin"
Stage1: .INCBIN "gen/stage1.bin"
Stage2: .INCBIN "gen/stage2.bin"
Stage3: .INCBIN "gen/stage3.bin"
Stage4: .INCBIN "gen/stage4.bin"
.ENDS
