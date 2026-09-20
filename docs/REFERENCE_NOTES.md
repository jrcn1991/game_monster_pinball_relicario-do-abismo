# Notas de referência (princípios abstratos, sem conteúdo protegido)

Estas notas registram apenas princípios de design observados nas referências indicadas no plano.
Nada de layout, nomes, sprites, áudio ou texto foi reproduzido.

## Ritmo
- Sessões curtas com metas visíveis a cada momento (alvo aceso, selo pendente, chefe com barra de vida).
- Momentos de calma (bola no lançador) alternando com caos legível (multiball, chefe).

## Feedback
- Cada impacto tem três intensidades (lento / médio / crítico) com som, partícula e flash proporcionais.
- A bola é sempre o elemento mais luminoso; inimigos têm silhuetas reconhecíveis e piscam ao sofrer dano.
- Ataques inimigos telegrafados com ≥ 400 ms de antecipação (lança do esqueleto, projéteis lentos).

## Clareza da bola
- Rastro curto e halo; efeitos nunca cobrem o dreno ou os flippers.
- Limite de velocidade e CCD para evitar comportamentos ilegíveis.

## Tipos de objetivo
- Alvos simples (bumpers, slingshots, rollovers), bancos (drop targets), coleta (runas), estados (trava, portal).
- Inimigos como alvos vivos com vida, escudo e comportamento próprio.

## Progressão
- Selos → chefe → jackpot: uma partida completa cabe em 10–20 minutos.
- Multiplicador cresce com variedade de alvos e cai ao perder a bola (consequência compreensível).

## Controle
- Flippers com resposta imediata (sem atraso de animação), nudge com custo (TILT), magia como decisão de gasto.
