# Daniel do Bolo Adventure — SNES LoROM 512 KiB, NTSC, ROM only.
# Backup of the Pong template: /home/fabio/snes_game_pong_backup
#
#   make                # backdrop azul (T2)
#   make COLOR=black    # T1
#   make COLOR=red      # T3
#   make colors
#   make verify

WLA     ?= $(firstword $(wildcard tools/bin/wla-65816) $(shell command -v wla-65816 2>/dev/null))
WLALINK ?= $(firstword $(wildcard tools/bin/wlalink) $(shell command -v wlalink 2>/dev/null))

ifeq ($(strip $(WLA)),)
$(error wla-65816 not found. Run: make toolchain)
endif

COLOR   ?= blue
ROM     := build/daniel-$(COLOR).sfc
OBJ     := build/main-$(COLOR).o
LINK    := build/link-$(COLOR)

JAVA_ASSETS ?= /run/media/fabio/Dados/Fabio/dan-java/DanielDoBolosAdventure/assets

SRC := \
	src/main.asm \
	src/header.inc \
	src/hardware.inc \
	src/ram.inc \
	src/vectors.asm \
	src/reset.asm \
	src/nmi.asm \
	src/ppu.asm \
	src/input.asm \
	src/sprites.asm \
	src/player.asm \
	src/objects.asm \
	src/hud.asm \
	src/game.asm \
	src/data.asm \
	src/gen/meta.inc

ifeq ($(COLOR),black)
	COLOR_FLAG := -D BACKDROP_LO=0 -D BACKDROP_HI=0
else ifeq ($(COLOR),blue)
	COLOR_FLAG := -D BACKDROP_LO=0 -D BACKDROP_HI=124
else ifeq ($(COLOR),red)
	COLOR_FLAG := -D BACKDROP_LO=31 -D BACKDROP_HI=0
else
	$(error COLOR must be black, blue, or red)
endif

.PHONY: all colors clean verify toolchain assets

all: $(ROM)
	@cp -f $(ROM) build/daniel.sfc
	@cp -f $(ROM) build/pong.sfc

src/gen/meta.inc: tools/port_assets.py
	python3 tools/port_assets.py --assets $(JAVA_ASSETS) --out src/gen

$(OBJ): $(SRC)
	@mkdir -p build
	$(WLA) -o $@ -I src $(COLOR_FLAG) src/main.asm

$(LINK):
	@mkdir -p build
	@printf '[objects]\n%s\n' $(OBJ) > $@

$(ROM): $(OBJ) $(LINK)
	$(WLALINK) -S $(LINK) $@

colors:
	$(MAKE) COLOR=black
	$(MAKE) COLOR=red
	$(MAKE) COLOR=blue

verify: $(ROM)
	python3 tools/verify_rom.py $(ROM)

clean:
	rm -f build/*.o build/*.sfc build/*.sym build/link-*

assets:
	python3 tools/port_assets.py --assets $(JAVA_ASSETS) --out src/gen

toolchain:
	@mkdir -p tools
	@if [ ! -d tools/wla-dx/.git ]; then \
		git clone --depth 1 https://github.com/vhelin/wla-dx.git tools/wla-dx; \
	fi
	cmake -S tools/wla-dx -B tools/wla-dx/build -DCMAKE_BUILD_TYPE=Release
	cmake --build tools/wla-dx/build --target wla-65816 wlalink -j$$(nproc)
	mkdir -p tools/bin
	cp tools/wla-dx/build/binaries/wla-65816 tools/wla-dx/build/binaries/wlalink tools/bin/
	@echo "Installed WLA-DX to tools/bin"
