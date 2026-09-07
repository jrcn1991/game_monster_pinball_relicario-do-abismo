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

## Fases

Três mesas com a mesma geometria e arte, inimigos, chefe e dificuldade próprios: **Catedral Profanada** (Bispo Sem-Rosto),
**Claustro dos Ecos** (Sineiro Enforcado) e **Olho do Abismo** (O Relicário). Derrotar o chefe e cumprir a sequência bônus
avança de fase com +1 bola; vencer a terceira encerra a partida com vitória. Dados em `data/stages/*.tres`.

## Caminhos da mesa

Órbitas esquerda e direita com spinners, três lanes no topo da arena (completar = multiplicador +1), rampa elevada
(entrada à esquerda, passa por cima da arena e desce na inlane direita), banco de alvos, runas, trava de bolas,
bumpers, slingshots, lanes E-L-O-S e a arena do chefe. Inimigos: esqueleto-sentinela, morcego de cinzas, guardião do
vitral e torre de runas, com variantes próprias em cada fase.

## Regras profundas (mesa v3)

Inspirada na estrutura de regras das grandes mesas clássicas (ver `docs/REFERENCE_TOTAN_MECHANICS.md`), com nomes e layout próprios:

- **7 Capítulos** (modos): Gárgulas, Litania, Sepulcros, Sussurro, Procissão, Ascensão, Behemoth. Troque o capítulo com A/← enquanto a bola está no lançador; inicie acertando o corpo do Guardião. O progresso persiste entre bolas. Concluir acende a rampa para coletar a **Relíquia** (7 no total; 4 relíquias = bola extra).
- **5 Vitrais** (os tiros de modo): banco de alvos esquerdo, órbita esquerda, rampa, órbita direita, banco de alvos direito.
- **Sacristia** (scoop): soletra S-A-C-R-I-S (3, 2, 1 letras por visita) e dá um prêmio aleatório; com **Indulgência** acesa, segura a bola e oferece uma escolha: flipper esquerdo = relíquia do capítulo atual, direito = prêmio contextual (3× Fogo-Fátuo, 3× Oração, Oração Relâmpago, +3 voltas, coletar bônus).
- **Turíbulo**: disco giratório central; cada meia-volta é um "sopro" que persiste a partida inteira; aos 15/30/60/90 sopros começa a **Oração Relâmpago** (10 s, cada sopro paga e reinicia o timer) e concede uma Indulgência.
- **Sinos** (bolas cativas): acerto forte = +1 no multiplicador de bônus (até 12×) e acende o **Fogo-Fátuo** (hurry-up de 20 s iniciado na rampa e coletado no Guardião; o custo sobe a cada uso).
- **Voltas do Claustro**: inlane acende a órbita oposta; loops encadeados; 6 e 20 loops = bola extra.
- **Frenesi das Catacumbas**: 5 órbitas esquerdas iniciam um multiball de 2 bolas em que todo acerto paga um jackpot que cresce com os sinos (bumpers).
- **Multiball do Abismo**: jackpot no Guardião cresce com os sopros, reacende na órbita sorteada; se acabar sem jackpot, a Sacristia dá **Revanche** por 8 s.
- **Guardiões das outlanes**: completar um banco de alvos ergue o poste daquele lado, que devolve a bola uma vez.
- **Skill shot**: lançar na lane do topo acesa (I, II ou III).
- **Rosário**: bônus de fim de bola = (1k × sopros + 5k × relíquias) × multiplicador de bônus.
- **Exorcismo Final** (com as 7 relíquias, no Guardião): fase 1 com 1 bola elimina 7 Possessos que ressuscitam até 3 em campo; fase 2 com bolas ilimitadas (até 4) em que cada Vitral puxa a Alma para você enquanto o Abismo puxa de volta (bola parada no lançador acelera o Abismo). Vitória = 300.000; derrota zera as relíquias.

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
