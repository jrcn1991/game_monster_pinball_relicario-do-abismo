# Relicário do Abismo

Pinball de ação gótico em **Godot 4.7 (GDScript)**: a bola é projétil, arma e vida.
Uma catedral demoníaca em três zonas, hordas de criaturas, magia, multiball e o chefe **Bispo Sem-Rosto**.

> Protótipo MVP jogável. Arte e áudio são provisórios, gerados proceduralmente para este projeto (originais).

## Jogar no navegador

https://jrcn1991.github.io/relicario-do-abismo/ (build Web; em celular há controles de toque: metade esquerda/direita da tela = flippers, botões LANÇAR, MAGIA e PAUSA).

## Como jogar (Linux, esta máquina)

```bash
cd "/home/pc/Área de trabalho/game_monster_pinball"
./run_game.sh
```

Ou abra a pasta no editor Godot 4.7 (`godot --path . -e`) e pressione F5.
O binário do Godot está em `~/.local/bin/godot` (oficial, SHA512 verificado).

## Controles

| Ação | Teclado | Gamepad |
| --- | --- | --- |
| Flipper esquerdo | `A` ou `←` | LB |
| Flipper direito | `D` ou `→` | RB |
| Lançar (segure para carregar) | `Espaço` | A |
| Nudge esquerdo / direito | `Q` / `E` | D-pad ← / → |
| Magia (Bola Consagrada, 100 de mana) | `Shift` | X |
| Pausa | `Esc` | Start |
| Debug | `F3` | — |

Abusar do nudge enche a barra de **TILT** e trava os flippers por 3 s.

## Objetivo

1. Quebre os **três Selos do Abismo**: derrube o banco de alvos, derrote o Guardião do Vitral e acenda as três runas.
2. O **Bispo Sem-Rosto** desperta: três fases (pontos fracos alternados → invocação e projéteis → olho vulnerável).
3. Derrote-o para abrir o **portal de jackpot** e uma sequência bônus de 30 s.

Trave duas bolas na trava superior esquerda e acerte-a de novo para o **Multiball Profano**.
Complete as lanes **E-L-O-S** (inlanes/outlanes) para 8 s de salvamento de bola.

## Estrutura

```
project.godot          configuração (1920x1080, 120 Hz de física, GL Compatibility)
scripts/autoload/      GameManager, ScoreManager, AudioManager, SaveManager, SignalBus, Loc
scripts/physics/       Ball, Flipper, Plunger
scripts/table/         GameTable (layout e regras), componentes (bumpers, slingshots, alvos, lanes, trava, portal)
scripts/combat/        Combat (dano), HealthComponent, inimigos, chefe, magia, projéteis
scripts/ui/            HUD, menus, opções, resultados, debug, efeitos
scenes/                cenas .tscn (raiz + script; filhos construídos em código)
data/                  Resources configuráveis (inimigos, power-ups, pontuação)
assets/art, audio      arte pixel e áudio procedurais (tools/gen_sprites.py, tools/gen_audio.py)
tests/                 suíte automatizada headless
```

## Testes

```bash
./run_tests.sh                 # suíte completa (100 lançamentos automatizados)
./run_tests.sh --launches=10   # rápido
```

Resultado em `tests/results/last_run.txt`. Detalhes em `STATUS.md`.

## Exportação

Requer os *export templates* do Godot 4.7.2 (download dentro do editor: Editor → Manage Export Templates, ou
`Godot_v4.7.2-stable_export_templates.tpz` do GitHub oficial). Depois:

```bash
godot --headless --path . --export-release "Windows Desktop" exports/windows/RelicarioDoAbismo.exe
godot --headless --path . --export-release "Web" exports/web/index.html
godot --headless --path . --export-release "Linux" exports/linux/RelicarioDoAbismo.x86_64
```

Os presets estão em `export_presets.cfg`. Para Web, sirva a pasta `exports/web` por HTTP (ex.: `python3 -m http.server`).

## Regenerar assets

```bash
python3 tools/gen_sprites.py   # PNGs em assets/art
python3 tools/gen_audio.py     # WAVs em assets/audio
godot --headless --path . --import
```

## Licenças

Código e conteúdo deste projeto: MIT (veja `LICENSES/`). Godot Engine: MIT. Nenhum asset externo foi baixado.
Veja `CREDITS.md`.
