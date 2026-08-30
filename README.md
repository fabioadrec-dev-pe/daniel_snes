# Daniel do Bolo's Adventure — SNES

Port LoROM NTSC de 512 KiB do jogo Java em
`/run/media/fabio/Dados/Fabio/dan-java/DanielDoBolosAdventure/`.
Sem SRAM, sem áudio (música/SFX ficam para um milestone posterior).

**Rollback:** o template Pong está intacto em `/home/fabio/snes_game_pong_backup`.

Assembler: [WLA-DX](https://github.com/vhelin/wla-dx). Depuração: [bsnes-plus](https://github.com/devinacker/bsnes-plus).

## Recorte deste port

Mantido:

- Tileset 16×16 (8 tipos), mapas das 5 fases (mesma `StageFactory` / `java.util.Random`)
- Fundos por fase (quantizados para 16 cores, Mode 1 BG2)
- Jogabilidade de plataforma: andar, correr (X/Y), pulo variável (B/A), gravidade, colisão por tiles, espinhos, buracos
- Walker, flyer, fast, tank, boss (pisão, HP)
- Moedas (100 = vida extra), placar, tempo 300s, 3 vidas
- Título, pausa (Start), game over, vitória
- NMI mínimo: DMA OAM, scroll, coluna BG1, HUD, auto-joy. Lógica fora do NMI.

Reduzido:

- Sem áudio / SPC700
- Sem tela de apresentação (ruas), sem foto de ending, sem menu Sair
- Câmera só horizontal
- Checkpoints ainda não reativam o respawn (volta ao início da fase)
- Sprites: player 32×32 (11 frames), boss/castelo 32×32
- Fundos em 16 cores (os PNG originais têm ~170–220)

## Compilar

```bash
make toolchain          # uma vez
make                    # azul → build/daniel-blue.sfc e build/daniel.sfc
make COLOR=black        # T1
make COLOR=blue         # T2
make COLOR=red          # T3
make colors
make verify
```

`COLOR` só muda o backdrop dos ~1,5 s iniciais (teste de PPU). Depois o jogo é o mesmo.

Para regerar CHR/mapas a partir do Java (disco montado):

```bash
make assets
```

## Protocolo T1–T9 (emulador e hardware)

| # | ROM / ação | Passa se | Falha se |
|---|------------|----------|----------|
| T1 | `daniel-black.sfc` power-on | ~1,5 s de tela **preta**, depois título | Tela preta permanente, lixo, freeze |
| T2 | `daniel-blue.sfc` | Fundo **azul** no boot, depois título | Cor errada ou hang |
| T3 | `daniel-red.sfc` | Fundo **vermelho** no boot, depois título | Idem |
| T4 | Título | Texto visível; **PRESS START** | Tilemap lixo, sprites no título |
| T5 | Start | Entra na fase 1 (orla), HUD, Daniel, chão, fundo | Tela preta após Start, sem tiles |
| T6 | Esquerda/direita + B (pulo) + X (correr) | Anda, pula, câmera segue | Travado, cai através do chão |
| T7 | Pisão num walker / pegar moeda | Inimigo some; PEIXES sobe | Freeze, OAM some |
| T8 | Start no jogo | PAUSA; Start de novo continua | NMI pára, input morto |
| T9 | Power-on 5× no hardware + as três cores | Boot estável | Hang no reset ou após Start |

Se T1–T3 falharem, **não avance**: o bring-up da PPU quebrou. Volte ao backup Pong.

## NMI (ciclo de vida)

- Vetor nativo → `NMI` (`RTI`). Emulação NMI / IRQ / COP → `RTI`.
- Liga: `NMITIMEN = $81` depois do boot gráfico e de novo após cada `EnterStage` / título.
- Desliga: Force Blank nas transições (título, fase, game over).
- No NMI: ack `$4210`, DMA OAM (544 B), scroll HOFS, 1 coluna BG1 se pedida, HUD se dirty, auto-joy, `frame_counter++`, `nmi_ready=1`.
- DMA de tiles/CGRAM/mapas só em Force Blank na init de tela.

## Controles

| Ação | SNES |
|------|------|
| Andar | Esquerda / Direita |
| Pular (variável) | B ou A |
| Correr | X ou Y |
| Abaixar | Baixo |
| Pausa / confirmar | Start |

## Fases

1. Orla de Brasília Teimosa  
2. Ruas do bairro  
3. Cais e jangadas  
4. Ferro-velho  
5. Castelo do chefe  

## Layout

```
src/reset.asm nmi.asm ppu.asm input.asm
src/player.asm objects.asm hud.asm game.asm sprites.asm
src/data.asm          bancos 1–8 (CHR, BGs, stages.bin)
src/gen/              saída de tools/port_assets.py
```
