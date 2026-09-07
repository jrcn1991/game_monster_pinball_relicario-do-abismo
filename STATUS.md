# STATUS — Relicário do Abismo

## Estado atual
- **Fase:** Fases 0–5 implementadas em protótipo (preparação, caixa cinza, objetivos/pontuação, combate, chefe/multiball, arte/áudio/acessibilidade provisórios). Fase 6 (empacotamento): presets criados; ver seção Exportação.
- **Funciona:** mesa vertical completa em três zonas; bola RigidBody2D com CCD e limite de velocidade; dois flippers cinemáticos com correção de varredura; lançador carregável com portão de mão única; paredes, canaletas, 4 rollovers (E-L-O-S → ball save 8 s), 2 bumpers, 2 slingshots, 3 drop targets (banco com reset), 3 runas; dreno, 3 bolas, ball save de serviço, reinício; placar (abreviado + completo na pausa), multiplicador x1–x10, combo (janela 2,5 s, só alvos diferentes), mana; 3 inimigos (esqueleto com lança telegrafada, morcego em 3 pontos que solta mana, guardião com escudo frontal -80% desativado por runas, projéteis lentos destrutíveis); chefe Bispo Sem-Rosto em 3 fases (pontos fracos alternados → invocação de 4 esqueletos + projéteis → olho vulnerável), barra de vida, derrota +25.000, portal de jackpot e sequência bônus de 30 s; Bola Consagrada (100 de mana, 8 s, 2× dano, atravessa projéteis, onda de dano, não acumula); trava de 2 bolas + multiball de 3; TILT por nudge; pausa, menu, game over/vitória; teclado e gamepad (InputMap em código); efeitos (partículas com pooling, flash, tremor) com opções de redução; recorde e configurações em `user://relicario.cfg`; README, CREDITS, LICENSES.
- **Falta:** arte final (sprites são placeholders procedurais em pixel art); animações de inimigos (só flash/escala); rampa física real (a "rampa de retorno" é a órbita superior); power-ups além da Bola Consagrada (apenas dados em `data/powerups/`); localização além de pt-BR (estrutura pronta em `Loc.gd`); balanceamento por playtest humano.
- **Bugs conhecidos:** ver seção abaixo.

## Testes executados (headless, `./run_tests.sh`)
- Execução final em 2026-09-07 (Godot 4.7.2 headless, física 120 Hz): **114 verificações passaram, 0 falharam** (`tests/results/last_run.txt`).
- 100 lançamentos automatizados (mín/méd/máx e aleatórios) com flippers automáticos: `drenos: 77 / 100 | frames: 83364 (6.9 s/lançamento) | vel. máx: 2500 px/s | bolas paradas (amostras): 0 | fora da mesa: 0 | falha de saída da canaleta: 0 | out_of_bounds: 0 | resgates: 0 | contatos c/ flipper (máx por bola): 66`
- Força do flipper: `velocidade vertical máxima após flip: 1446 px/s`; bola não atravessa flipper nem paredes; dois flippers simultâneos chegam ao topo.
- Cobertos por código: dano por velocidade (1/2/3, crítico, 2× consagrada), invulnerabilidade 100 ms, morte única; combo só com alvos diferentes, expira em 2,5 s, multiplicador; carregamento de todas as cenas e recursos; máquina de estados (transições inválidas recusadas, sem duplicar serviço); portão da canaleta; drenar 3 bolas no mesmo frame perde 1 vida; ball save; trava 2 bolas → multiball de 3; esqueleto/guardião (escudo -80%, runa desliga escudo)/morcego (fragmento de mana)/respawn; magia (custo, renovação sem acumular, projétil destruído); chefe (selos, intro, 3 fases, invulnerabilidade de transição, invocação de 4 esqueletos, inimigo morto na troca de fase, projéteis, derrota, jackpot, RESULTS com vitória, reinício durante o chefe); pausa congela a bola e retoma; 3 bolas → GAME_OVER; voltar ao menu limpa a mesa; recorde e configurações persistem; nenhum script carrega URL.
- Build Linux exportado (`exports/linux/RelicarioDoAbismo.x86_64`) executado fora do editor com `--autoplay --screenshots`: abre, joga e chega ao fim de jogo.

## Bugs conhecidos
- Nenhum bloqueante conhecido. Avisos benignos ao sair: "2 ObjectDB instances leaked" e "1 resource still in use" (tweens/streams no encerramento).
- Balanceamento não validado por pessoa: a IA de teste perde as 3 bolas em ~15 s; a partida humana deve durar bem mais.

## Atualização 2026-09-07 (após playtest do autor)
- Corrigido: bola apoiada na pá era empurrada para baixo quando o flipper descia (correção de varredura agia em bolas atrás do movimento).
- Bola fora da mesa agora volta ao lançador sem perder vida; poste no topo da canaleta.
- Impacto: hit-stop, números de dano, anéis de choque, partículas maiores, tremor e sons mais fortes (`scripts/ui/HitFeel.gd`).
- Três fases (`StageData`, `data/stages/`), arte original gerada por IA em pixel art gótica 32-bit para fundos, chefes, inimigos, props e UI.
- Controles de toque para celular (`TouchControls`), build Web publicado em GitHub Pages.
- Suíte: 121 verificações passando (inclui avanço de fase e vida do chefe por fase).

## Verificação visual
- `godot --path . -- --autoplay --screenshots=DIR` gera 8 capturas jogando sozinho; conferidas manualmente: HUD, mesa, inimigos, chefe, mensagens e flippers renderizam na RTX 3060 (OpenGL Compatibility).

## Testes manuais pendentes (exigem pessoa)
- Sensação dos flippers a 60/120/144 FPS (a física é fixa em 120 Hz; a lógica é independente do FPS).
- Redimensionar janela e tela cheia (opção existe e usa `DisplayServer.window_set_mode`).
- Desconectar/reconectar gamepad (InputMap usa device -1 = qualquer dispositivo).
- Pausar durante impacto, magia e multiball (a árvore inteira é pausada; testado por código apenas para bola).

## Exportação
- Templates oficiais 4.7.2 instalados em `~/.local/share/godot/export_templates/4.7.2.stable/` (SHA512 verificado).
- Exportados em 2026-09-07 com `godot --headless --export-release`: `exports/linux/RelicarioDoAbismo.x86_64` (76 MB, testado), `exports/windows/RelicarioDoAbismo.exe` (112 MB, não testado — sem Windows nesta máquina), `exports/web/` (41 MB, não testado — precisa de servidor HTTP: `cd exports/web && python3 -m http.server`).
- Atalho de aplicativo criado em `~/.local/share/applications/relicario-do-abismo.desktop`.

## Comandos
```bash
./run_game.sh                      # jogar
./run_tests.sh                     # testes (100 lançamentos)
./run_tests.sh --launches=10       # testes rápidos
godot --headless --path . --import # reimportar assets
```

## Próximo passo
- Playtest humano e ajuste fino de gravidade (1300), força dos flippers (1500°/s), impulsos de bumper/slingshot.
- Substituir sprites procedurais por arte final; adicionar animações (idle/hit/death).
- Implementar power-ups restantes usando `PowerupData` e `MagicSystem`.
