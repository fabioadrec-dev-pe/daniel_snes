# Daniel do Bolo's Adventure — SNES

Port LoROM NTSC de 512 KiB do jogo Java em
`/run/media/fabio/Dados/Fabio/dan-java/DanielDoBolosAdventure/`.
Sem SRAM. O port agora inclui música, efeitos sonoros, tela de apresentação e ending.

**Rollback:** o template Pong está intacto em `/home/fabio/snes_game_pong_backup`.

Assembler: [WLA-DX](https://github.com/vhelin/wla-dx). Depuração: [bsnes-plus](https://github.com/devinacker/bsnes-plus).

## Funcionalidades implementadas

- ROM LoROM NTSC de 512 KiB, sem SRAM
- Tileset 16×16, mapas das 5 fases e fundos quantizados para 16 cores
- Plataforma completa: andar, correr, pulo variável, gravidade, colisão por tiles, espinhos e buracos
- Walker, flyer, fast, tank e boss com pisão e HP
- Moedas, vidas extras, placar, checkpoints, HUD e limite de 300 segundos
- Menu **NOVO JOGO**, confirmação por controle e sequência secreta para liberar seleção de fase e vidas
- Tela de apresentação com nomes das ruas de Brasília Teimosa em Mode 7, perspectiva por HDMA e rolagem automática
- Telas de GAME OVER, vitória e retorno ao menu
- Ending em três partes: história, créditos e bitmap/foto final, com avanço por START
- Pausa por START e transições com force blank para evitar lixo gráfico
- NMI com DMA de OAM, scroll, colunas de BG1, HUD, auto-joy e atualização do Mode 7

### Áudio

O áudio usa o SPC700, com driver próprio e sequenciador de eventos residente na APU:

- Música do menu/NOVO JOGO, fases e chefe convertidas dos MIDIs originais Java
- Instrumentos sintetizados em BRR, com volumes, panorâmica e mixagem ajustados para reduzir ruído e sujeira
- Notas longas preservadas com maior audibilidade
- Efeitos sonoros convertidos dos WAVs originais: pulo, moeda, dano, derrota, quebra, vitória, menu, seleção e chefe
- A música do menu toca automaticamente no título, GAME OVER e ending, permanecendo até uma tela de fase/chefe ser aberta

## Limitações conhecidas

- O menu Sair do jogo Java não foi portado
- A câmera das fases é somente horizontal
- Checkpoints ainda não reativam o respawn; ao perder, o jogador volta ao início da fase
- Sprites: player 32×32 (11 frames), walker 32×32 (4), flyer/fast 16×16 (2/4), tank 32×32 (2), boss 48×48 (2 frames, 9 OAM), castelo 64×64
- Fundos usam a paleta SNES de 16 cores, enquanto os PNGs originais têm aproximadamente 170–220 cores

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

## Protocolo T1–T12 (emulador e hardware)

| # | ROM / ação | Passa se | Falha se |
|---|------------|----------|----------|
| T1 | `daniel-black.sfc` power-on | ~1,5 s de tela **preta**, depois título | Tela preta permanente, lixo, freeze |
| T2 | `daniel-blue.sfc` | Fundo **azul** no boot, depois título | Cor errada ou hang |
| T3 | `daniel-red.sfc` | Fundo **vermelho** no boot, depois título | Idem |
| T4 | Título/menu | Texto visível, **NOVO JOGO** e música automática | Tilemap lixo, sprites no título ou silêncio |
| T5 | Menu sem entrada | Abre a apresentação das ruas em Mode 7; qualquer botão retorna | Mode 7 deformado, HDMA instável ou freeze |
| T6 | Confirmar NOVO JOGO | Entra na fase 1 com HUD, Daniel, chão, fundo e música | Tela preta após confirmar, sem tiles ou áudio |
| T7 | Esquerda/direita + B/A + X/Y | Anda, pula, corre e câmera segue | Travado, cai através do chão ou SFX ausente |
| T8 | Pisão num walker / pegar moeda | Inimigo some; PEIXES sobe; SFX toca | Freeze, OAM some ou SFX ausente |
| T9 | Start no jogo | PAUSA; START de novo continua | NMI para, input morto ou música interrompida |
| T10 | GAME OVER | Tema de NOVO JOGO toca; START retorna ao menu com o tema mantido | Música incorreta, ausência de SFX ou silêncio no retorno |
| T11 | Completar as 5 fases | Ending mostra história, créditos e bitmap/foto; tema de NOVO JOGO continua | Ending incompleto, bitmap lixo ou música interrompida |
| T12 | Power-on 5× no hardware + as três cores | Boot estável em preto, azul e vermelho | Hang no reset ou após START |

Se T1–T3 falharem, **não avance**: o bring-up da PPU quebrou. Volte ao backup Pong.

## NMI (ciclo de vida)

- Vetor nativo → `NMI` (`RTI`). Emulação NMI / IRQ / COP → `RTI`.
- Liga: `NMITIMEN = $81` depois do boot gráfico e de novo após cada transição de título, apresentação, fase, GAME OVER e ending.
- Desliga: Force Blank nas transições (título, fase, game over).
- No NMI: ack `$4210`, DMA OAM (544 B), scroll HOFS/Mode 7, 1 coluna BG1 se pedida, HUD se dirty, auto-joy, `frame_counter++`, `nmi_ready=1`.
- DMA de tiles/CGRAM/mapas só em Force Blank na init de tela.

O SPC700 é inicializado uma vez no reset. O driver recebe comandos pelos registradores
`APUIO0`–`APUIO3` (`$2140`–`$2143`) para carregar músicas, reproduzir temas, parar
áudio e disparar efeitos sonoros.

## Controles

| Ação | SNES |
|------|------|
| Andar | Esquerda / Direita |
| Pular (variável) | B ou A |
| Correr | X ou Y |
| Abaixar | Baixo |
| Pausa / confirmar | Start, A ou B |

## Fases

1. Orla de Brasília Teimosa  
2. Ruas do bairro  
3. Cais e jangadas  
4. Ferro-velho  
5. Castelo do chefe  

## Histórico pós-commit inicial

Principais entregas realizadas depois do commit inicial `31a831e`:

- `ddead23` — primeira versão jogável, com mapas, inimigos, colisões e fases
- `66036b0` — tela de apresentação com as ruas do bairro
- `c8e7407` — conversão da apresentação para Mode 7 com perspectiva por HDMA
- `7b2dc3b` — menu de seleção de fases e vidas por sequência secreta
- `6af0779` — tela final com história, créditos e bitmap/foto
- `92b8c2a` / `c2269e7` — integração do SPC700, músicas e efeitos sonoros
- `9a073a7` — correção da colisão com buracos
- `a7a7750` — melhoria da mixagem, panorâmica e legibilidade das notas longas
- `e2ff973` — início automático da música do menu
- `392dbfc` — música do menu em GAME OVER e ENDING, até a abertura de uma fase

## Layout

```
src/reset.asm nmi.asm ppu.asm input.asm
src/player.asm objects.asm hud.asm game.asm sprites.asm
src/streets.asm       apresentação Mode 7 e HDMA
src/ending.asm        história, créditos e bitmap final
src/audio.asm         comunicação 65816 ↔ SPC700
src/spc.asm           driver e sequenciador SPC700
src/data.asm          bancos 1–8 (CHR, BGs, stages.bin, áudio)
src/gen/              saída de tools/port_assets.py e tools/build_spc.py
```
