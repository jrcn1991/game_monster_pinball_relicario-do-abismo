# Referência de mecânicas: "Tales of the Arabian Nights" (Williams, 1996)

> Documento de estudo de design. Descreve, de forma abstrata e em nossas próprias palavras, a estrutura de elementos físicos e regras da máquina TOTAN (design de John Popadiuk, software de Louis Koziarz, ~3.128 unidades, maio/1996). Nada aqui deve ser copiado literalmente (layout, nomes, arte, áudio); o objetivo é entender a **profundidade de gameplay** para construir uma mesa original, "Relicário do Abismo".
>
> Fonte principal de regras: rulesheet v1.2 (Joshua Lehan, 23/06/1997), reproduzida em pinball.org e GameFAQs. Cruzada com Wikipedia, TV Tropes, cheatsheet do San Diego Pinball Club (baseado no rulesheet da PAPA), A&F Pinball (lista de componentes), Pinball Mag, tópico "TOTAN and its code" do Pinside e tópico de estratégia do Digital Pinball Fans. Onde as fontes divergem, está indicado.

---

## 1. Inventário de elementos físicos

Visão geral: mesa de dois flippers, fundo "italiano" padrão (slingshots + inlane/outlane de cada lado), **uma única rampa** com várias saídas, **dois orbits**, um brinquedo central giratório (a Lâmpada), um vilão "bash toy" ao fundo (o Gênio) com ímã, **dois** conjuntos de bolas cativas, **três** pop bumpers escondidos no canto superior direito, **dois** buracos/scoops (Bazar e Harém/trava) e um sistema de salvamento por pinos que sobem nas outlanes. Total de standups: 11 (A&F). Não há rollover lanes superiores tradicionais (as "top lanes" clássicas) — o papel delas é assumido pelos três cestos do skill shot e pelos bumpers.

| Elemento | O que é | Como a bola chega | O que premia |
|---|---|---|---|
| **Flippers (2)** | Par padrão, posição convencional. Sem flipper superior. | — | — |
| **Slingshots (2)** | Padrão. | Ricochetes na parte baixa. | Pontos mínimos; em ajuste "difícil" alternam qual bola cativa está acesa para o multiplicador; antes da partida alternam a seleção de modo. |
| **Inlanes (2)** | Padrão. | Retorno da bola. | Cada inlane acende o **orbit oposto** por tempo limitado para "Voltas do Tigre" (loops), como as Freeways de High Speed. |
| **Outlanes (2)** | Padrão, com micro‑switch. | Drenagem lateral. | Podem acender Special. Acima delas ficam os pinos das "Estrelas Cadentes" (ver ball save). |
| **Ball save "Estrelas Cadentes"** | Dois pinos mecânicos que sobem entre inlane e outlane, um de cada lado, quando um sensor óptico detecta a bola indo para a outlane. Seguram a bola e a devolvem ao inlane. | Acende‑se cada lado batendo no banco de standups do respectivo lado (esq.: 3 alvos acima do inlane esquerdo; dir.: 3 alvos escondidos atrás da Lâmpada). | Salva a bola. Se o pino falha, o software compensa devolvendo a bola (exceto em multiball). Ficam acesas até serem usadas; são um recurso "cronometrado" que não pode ser reiniciado antes de expirar. |
| **Banco de standups esquerdo (3)** | Três alvos retangulares vermelhos acima do inlane esquerdo. | Tiro de flipper direito, ângulo aberto. | Qualquer um acende a Estrela Cadente esquerda; funcionam como um dos cinco "Símbolos Dourados" (alvos de modo); no modo Ali Babá soletram letras. |
| **Banco de standups direito (3)** | Três alvos em arco, escondidos atrás da Lâmpada, abaixo do Gênio. | Tiro de flipper esquerdo, difícil de enxergar. | Acende a Estrela Cadente direita; é outro Símbolo Dourado; letras no modo Ali Babá. |
| **Mini‑standups amarelos (2)** | Dois alvos pequenos ladeando a entrada da rampa. | Ricochetes ou tiro direto fraco. | Cada um concede uma letra do Bazar. |
| **Standup "Tesouro Escondido" (1)** | Alvo quase invisível ao lado do Gênio. | Sorte / ricochete. | Conta como um acerto no Gênio (compensação para quando o ímã não registra). |
| **Standups nas áreas de bola cativa (2)** | Atrás/junto das bolas cativas. | Idem. | Registro do "acerto pleno" da bola cativa. |
| **Bolas cativas "Orbes" (2)** | Cada uma é uma bola presa atrás de uma bola fixa; bate‑se na fixa e o momento transfere para a presa. A esquerda tem um **saucer** à frente que captura tiros fracos; a direita fica mais baixa e perto da borda, sem saucer. | Esquerda: flipper direito; direita: flipper esquerdo. | Acerto pleno na cativa acesa: **+1 no multiplicador de bônus** (máx 12x, talvez 28x por ajuste). Saucer/cativas: no modo Ciclope são o tiro do modo; o saucer acumula acertos para acender o "Bola de Fogo". |
| **Orbit esquerdo** | Loop que sobe pelo lado esquerdo e contorna o fundo. Tem um **diverter** no topo: aberto, manda a bola para os pop bumpers; fechado, a bola volta pelo lado direito. | Flipper direito. | Pode estar aceso para Trava (multiball), letra H‑A‑R‑E‑M, Volta do Tigre; é um Símbolo Dourado. |
| **Orbit direito** | Loop simétrico, sem diverter; no retorno pode cair numa lane estreita "sem nome" atrás da cativa esquerda que despeja a bola perto da entrada da rampa (perigo de dreno central). | Flipper esquerdo. | Pode estar aceso para Trava, Volta do Tigre e **Bola Extra**; é um Símbolo Dourado. |
| **Pop bumpers (3)** | Trio no canto superior direito, isolado, alcançado só pelo diverter do orbit esquerdo ou por tiros fracos na rampa que caem na espiral. Desligados durante tiros cronometrados. | Indireto. | Cada acerto soma um valor ao "Jackpot do Harém"; no modo Sinbad/Rocs cada acerto derruba um pássaro. |
| **"Entrada furtiva" do Harém** | Pequena calha no fundo central, abaixo da lane dos bumpers; uma bola sortuda saída dos bumpers entra nela. | Só por ricochete dos bumpers. | Conta 1 "entrada furtiva"; 3 delas iniciam o Multiball do Harém. A bola sai pela entrada do Bazar. |
| **Rampa (1, lado esquerdo)** | Única rampa, mas com **pelo menos cinco caminhos** de habitrail. Subida: contorna o Gênio, passa por um diverter no canto superior direito. Diverter fechado → bola entra numa **espiral transparente horária** suspensa sobre os bumpers; se tem força, atravessa e desce para o **flipper direito**; se não, cai nos bumpers (ponto alto ou baixo). Diverter ativo (quando há algo para coletar à esquerda) → bola é mandada de volta pelo trajeto oposto até o canto superior esquerdo, onde um **anel magnético** (o "Anel do Espírito" de Theatre of Magic, deitado) a segura durante a animação e depois a solta num wireform que cruza a mesa para o flipper direito; anel inativo → a bola desce para o **flipper esquerdo** (um dos poucos jeitos de alimentar o flipper esquerdo). | Flipper esquerdo, precisa de força. | Símbolo Dourado; acesa para **Tapete Voador** (coletar a Joia do modo) e para **Bola de Fogo** (hurry‑up). Tiro fraco que cai da espiral na área de trava → "Trava Secreta" (1 por jogo: acende todas as travas e credita uma). Super Skill Shot logo após o lançamento. |
| **Lâmpada giratória (brinquedo central)** | Lâmpada dourada montada sobre um disco giratório com dois postes; a bola bate nos postes e o conjunto gira. **14 luzes azuis** mostram o progresso; cada meia‑volta (180°) = 1 "giro". Um bom acerto rende ~12 giros. A posição de repouso dos postes muda o risco: alinhados na vertical, o tiro é ruim (devolve para o centro); na horizontal, um tiro pode completar o caminho azul. | Praticamente de qualquer flipper; ocupa o centro e atrapalha o tiro do flipper direito ao Gênio. | Cada giro: +10.000 no bônus de fim de bola (contador de giros persiste entre bolas, máx 119). A cada **15 giros**: acende "Lâmpada Relâmpago" (rodada rápida cronometrada) e um **Desejo** (máx 3 acumulados). Em multiball, giros aumentam o jackpot. |
| **Gênio (bash toy) + ímã vertical** | Figura larga articulada horizontalmente atrás da Lâmpada; o acerto registra quando ela é empurrada. Na base há um **ímã vertical/diverter** ("primeira vez na indústria"): pode agarrar a bola e arremessá‑la de volta ao jogador, ou capturá‑la e levá‑la para baixo da mesa (início de modo/multiball). Se o ímã falha, o jogo não credita o acerto (há ajuste de compensação). | Flipper direito, ângulo estreito atrás da Lâmpada; flipper esquerdo às vezes. | Soletra G‑E‑N‑I‑E (5 acertos) para acender travas; inicia modo quando a "garrafa" está acesa; inicia multiball; recebe Jackpot; alvo da Bola de Fogo; 10.000 de bônus por acerto não aceso. |
| **Lane de trava + Lane do Harém + ímã de trava** | Lane estreita acima do centro, escondida pela Lâmpada, que dobra à esquerda e desemboca numa lane vertical (Harém) que desce até um **saucer de trava** onde as bolas presas se empilham. Acima da entrada há um **ímã de trava** que, quando a trava está acesa nos orbits, intercepta tiros de orbit e derruba a bola pela lane do Harém (o modo mais fácil de travar). Com o ímã desligado, a entrada é estreita e difícil. | Orbits (via ímã) ou tiro direto na lane. | Trava de bola para multiball; entrada não acesa = prêmio pequeno aleatório (7k–50k). O saucer cospe as 3 bolas no início do multiball. |
| **Scoop do Bazar** | Buraco à direita da Lâmpada (posição parecida com o "Final Draw" de World Cup Soccer, mais fácil). | Flipper esquerdo. | Coleta letra B‑A‑Z‑A‑A‑R; com as 6 letras dá prêmio aleatório; é onde se realiza o **Desejo**; é o tiro de "Revanche" do multiball. |
| **Skill shot "cestos do encantador de serpentes"** | Plunger manual (sem auto‑lançador). A lane de lançamento tem **três buracos** (cestos); o display mostra qual está aceso. Cesto alto = força total; médio = meio termo (o mais difícil); baixo = lançamento suave (tentativas ilimitadas se for fraco demais). | Plunger. | 50k, +25k por acerto, máx 125k. **Super Skill Shot**: logo após acertar, a rampa acende — acertá‑la vale 2× o valor do skill shot. |
| **Diverters e ímãs auxiliares** | Diverter no orbit esquerdo (bumpers), diverter no topo da rampa (espiral ou retorno), anel magnético no canto superior esquerdo (segura a bola para animação). | — | Controlam fluxo e encenação. |

Observação sobre divergência: a Wikipedia descreve o ímã do Gênio como responsável pela captura e a Pinball Mag cita "Magna‑Save nos outlanes"; o rulesheet e a Wikipedia descrevem as Estrelas Cadentes como **pinos mecânicos**, não ímãs. Adotamos a versão do rulesheet (pinos).

---

## 2. Estrutura de regras

### 2.1 Os sete Contos (modos) e a coleta de Joias

* Só **um modo por vez**; o progresso do modo **persiste entre bolas** (não zera ao drenar). Isso é uma decisão de design polêmica: bom para casuais, criticado por veteranos porque, com os Desejos, chega‑se ao modo final em minutos.
* **Seleção**: o próximo modo fica aceso (a "garrafa" abaixo do Gênio). No início da bola o jogador troca o modo com o flipper esquerdo; acertos nos slingshots também mudam a seleção. **Início**: acertar o Gênio com a garrafa acesa (o ímã captura a bola durante a animação).
* **Conclusão**: atingir o objetivo do modo acende o **Tapete Voador** na rampa; acertar a rampa coleta a **Joia** daquele conto (+50.000 no bônus). Sete joias no total.
* Os tiros de modo são os **cinco Símbolos Dourados**: banco de standups esquerdo, orbit esquerdo, rampa, orbit direito, banco de standups direito.

| # | Conto (tema) | Objetivo abstrato | Forma de pontuação | Dificuldade |
|---|---|---|---|---|
| 1 | Pássaros gigantes | Bumpers ativados e orbit esquerdo aceso (diverter sempre aberto). Cada acerto de bumper "derruba um pássaro"; **basta 1** para acender a Joia. | Pontos por bumper. | Muito fácil (tecnicamente; o tiro do orbit é o difícil). |
| 2 | Caverna dos ladrões | Os dois bancos de standups acendem; acertar alvos até **soletrar 6 letras**; a caverna abre e revela a Joia. | Por letra. | Difícil e lento; candidato a "desejar". |
| 3 | Cavalo voador | Os 5 Símbolos são "estátuas"; a Joia está escondida aleatoriamente numa delas (normalmente a última). Quebrar estátuas até achar. | Por estátua. | Difícil (até 5 tiros diferentes). |
| 4 | A contadora de histórias | Todos os Símbolos acendem; **1 acerto** conclui; acertos extras dão pontos. | Por símbolo. | Trivial. |
| 5 | Corrida de camelos | Todos os 5 Símbolos acesos; acertar **4–5 vezes** (ajustável) **qualquer** símbolo — pode repetir o mesmo tiro (ex.: loop do orbit esquerdo). | Por avanço na corrida. | Fácil/médio. |
| 6 | Tapete voador / quarenta ladrões | Rampa acesa; **1 acerto** na rampa conclui, o **segundo** coleta a Joia. | Fixo. | Fácil. |
| 7 | Ciclope | Único modo que **não usa** os Símbolos: acertar **qualquer bola cativa** (ou cair no saucer esquerdo) lança um "orbe" no monstro; **1 acerto** basta. | 10k, +10k por acerto. | Fácil. Bloqueia o avanço de multiplicador durante o modo. |

Um jogador do Pinside resume: "nove tiros concluem cinco dos sete contos". A repetitividade ("todos são 'acerte os símbolos'") é a principal crítica ao código.

### 2.2 Lâmpada, Lâmpada Relâmpago e Desejos

* Cada meia‑volta da Lâmpada = 1 giro. 14 luzes azuis; ao completar o caminho acendem marcos "15", "30", "60" (persistem entre bolas, estilo Centaur). Contador máximo 119 giros; cada giro vale 10.000 no bônus × multiplicador (máx teórico 119 × 12x = 14,28 milhões, acima do replay médio de 10–20 milhões).
* **Lâmpada Relâmpago** (a cada 15 giros): rodada de ~10 segundos em que cada giro paga um valor base (250k) e **reinicia o timer**; giros rápidos encadeiam efeitos e valores maiores; edições posteriores pagam mais por giro. Giros adicionais não contam para o próximo marco enquanto a rodada está ativa. Ao terminar, concede **1 Desejo** (máx 3).
* **Desejo ("Faça um pedido")**: acende no scoop do Bazar junto com a Lâmpada Relâmpago. Ao entrar, o jogador escolhe com os flippers:
  * **Flipper esquerdo — Joia**: encerra o modo atual e entrega a Joia dele (ou **2 Joias** se o "Rubi" estiver aceso); se todas as joias já foram coletadas, inicia o modo final. É possível trocar o modo alvo apertando o flipper esquerdo durante a animação.
  * **Flipper direito — prêmio contextual "aleatório"**: Coletar Bônus; 3× valor da Bola de Fogo (se o hurry‑up está rodando); 3× pontuação da Lâmpada (se a Relâmpago está ativa); iniciar Lâmpada Relâmpago; 3 Voltas do Tigre; Bola Extra (raro, só em partidas fracas).
  * Estratégia canônica: sempre pegar Joias (dos modos difíceis), exceto quando faltam 3 loops para a bola extra ou quando se quer 3× Lâmpada antes de um multiball.
* **Rubi**: luz vermelha que acende quando, com Desejo aceso, as duas Estrelas Cadentes estão acesas e se acende uma terceira vez uma Estrela; dobra a Joia do Desejo. Zera a cada bola; consumido ao usar.

### 2.3 Multiball do Gênio (3 bolas)

1. **Soletrar** 5 letras com acertos no Gênio → acende **Trava** em três lugares: orbit esquerdo, orbit direito e a lane central de trava (o ímã de trava intercepta os orbits).
2. **Travar bola 1** (travas continuam acesas) e **bola 2** (travas apagam, Gênio acende). Tiros fracos que caem da espiral da rampa contam como "trava secreta" (1 por jogo). O prêmio "Acender Travas" do Bazar acende as três de uma vez.
3. **Iniciar**: acertar o Gênio aceso; o ímã puxa a bola para baixo (animação do gênio destruindo a cidade); o saucer de trava libera **3 bolas**. **Sem ball save** no início e **sem compensação** das Estrelas durante o multiball.
4. **Jackpot**: o Gênio começa aceso; **giros da Lâmpada aumentam o valor**; acertar o Gênio coleta e acende uma Trava em um orbit aleatório; acertar esse orbit **reacende** o Jackpot. Múltiplos jackpots são fáceis. **Não existe Super Jackpot** (crítica frequente; sugerem que o alvo amarelo à direita do Gênio deveria sê‑lo).
5. **Revanche**: se restar 1 bola sem nenhum Jackpot coletado, o Bazar acende por alguns segundos; acertá‑lo devolve uma bola ao plunger e reinicia o multiball sem animação.
6. Truque avançado: obter o Desejo "3× Lâmpada" **antes** de iniciar o multiball e então bater na Lâmpada em vez de caçar jackpots.

### 2.4 Multiball do Harém (2 bolas, "frenesi")

* Duas formas de acender: (a) **5 tiros no orbit esquerdo** com a letra do Harém acesa — cada tiro dá 1 letra e abre o diverter para os bumpers; (b) **3 "entradas furtivas"** vindas dos bumpers.
* Sutileza de prioridade: o Harém está aceso no orbit esquerdo **no início de cada bola**, mas cada tiro no orbit acende Voltas do Tigre/Trava que **têm prioridade**; o Harém só reacende quando **todos os outros prêmios daquele tiro expirarem** (segurar a bola no flipper e esperar é a tática).
* Durante o multiball, **todo switch da mesa** paga o "Jackpot do Harém" (base 10k ou 25k), que sobe **+1k por acerto de bumper** (inclusive durante o multiball via orbit esquerdo). Fontes divergem sobre o número de bolas: rulesheet v1.2 não especifica; Wikipedia, TV Tropes e Pinside dizem **2 bolas**. Adotado: 2.
* Exploit famoso: levar o Harém (ou a Lâmpada 3×) para dentro do modo final, cujas bolas são ilimitadas, gera pontuação virtualmente infinita (jackpot > 500k por switch). É a única forma realista de "virar" o placar em 1 bilhão e a razão de TOTAN ser evitado em torneios.

### 2.5 Bazar (prêmio aleatório) e "Vaca"

* Seis letras; começam acesas por padrão (ajustável). Completar o scoop ou os mini‑standups amarelos soletra: primeira vez **3 letras por acerto**, depois 2, depois 1 (fica progressivamente mais difícil).
* Com as 6 letras, o scoop entrega um prêmio: Acender Bola Extra (muito raro), Bola Extra (raro), +3 multiplicadores, 15 giros de Lâmpada (concede Desejo mas **não** inicia a Relâmpago), 250k, 500k, Segurar multiplicador, Acender Travas, Iniciar Multiball (só se 2 bolas já travadas), Acender Desejo, Acender Estrelas Cadentes.
* **Easter egg**: apertar os dois flippers para parar a animação em três Bazares consecutivos; no quarto, o mercador dá uma vaca de 1 milhão.
* Se o Desejo estiver aceso no scoop, o prêmio do Bazar não pode ser coletado naquele tiro (o Desejo tem prioridade).

### 2.6 Bola de Fogo (hurry‑up)

* Acende‑se caindo no saucer da cativa esquerda **N vezes** (1–2 no início; **+1 a cada Bola de Fogo** completada). Com a luz roxa acesa, acertar a **rampa** inicia uma contagem regressiva de ~20 s a partir de **400k (+200k por saucer acumulado)**; acertar o **Gênio** antes de zerar coleta (o gênio "recebe de volta" a bola de fogo). A rampa durante a contagem soma 200k sem ultrapassar o valor inicial. O Desejo pode triplicar o valor.

### 2.7 Voltas do Tigre, Bolas Extras e Specials

* **Voltas do Tigre**: cada inlane acende o orbit oposto por um tempo; loops consecutivos mantêm a luz (estilo Terminator 2). Desligadas durante modos que usam orbits.
* **Bola Extra** por: **6 loops** (ajustável), **20 loops** (segunda; há boato de terceira com 40–50); **4 Joias** (ajustável); Bazar (raro); Desejo (raro). É **coletada no orbit direito**, com animação do ímã de trava (apenas cênica).
* **Special** acende nas outlanes após o modo final (vitória ou derrota).

### 2.8 Bônus e multiplicador

* Bônus de fim de bola = (10k × giros acumulados [máx 119] + 10k × acertos no Gênio não acesos + 50k × Joias) × **Multiplicador (1x–12x)**.
* **O contador de giros persiste entre bolas** (estilo KISS); os marcos 15/30/60 também. O **multiplicador zera a cada bola**, salvo "Segurar multiplicador" do Bazar.
* Multiplicador sobe **+1 por acerto pleno na bola cativa acesa** (rulesheet e cheatsheet PAPA). A Wikipedia afirma que "sobe com giros da Lâmpada" — provável imprecisão; adotamos a versão das fontes de regras. Em ajuste difícil só uma cativa está acesa por vez, alternando com os slingshots. O jogo não avisa quando chega ao máximo.
* Estratégia: construir giros cedo e gastar a última bola em multiplicador; a contagem final toca a música em sincronia com cada giro (recompensa audiovisual).

### 2.9 Modo final: "Batalha contra o Gênio" / "Resgatar a Princesa"

* **Requisito**: as 7 Joias. O Gênio acende (luz vermelha pisca entre os flippers); inicia‑se como um modo normal (acertar o Gênio) ou via Desejo.
* **Fase 1 — esqueletos (1 bola)**: os Símbolos Dourados acendem; cada acerto (ou orbe/cativa) elimina um esqueleto; o Gênio **ressuscita** reposições até haver 3 em campo (TV Tropes) — o rulesheet fala em "cerca de 6 a 8 eliminados" no total. O último esqueleto está sempre num tiro que permite travar a bola (orbit). Drenar nesta fase **não perde progresso** (continua na próxima bola). Ao vencer, o jogo trava a bola e serve outra ao plunger.
* **Fase 2 — cabo de guerra com bolas ilimitadas**: até **4 bolas** em jogo (máx da máquina). No display, o Gênio à esquerda, o herói à direita e a princesa numa garrafa entre eles; **todos os 5 Símbolos** acesos: cada acerto puxa a princesa para o jogador; o Gênio puxa constantemente para ele. Bolas drenadas voltam **imediatamente** ao plunger manual — **deixar bola parada no plunger acelera o Gênio** (penalidade), então o jogador precisa lançar sem parar. Estrelas Cadentes desligadas.
* **Vitória**: 20 milhões (enorme para a escala do jogo; um "ótimo jogo" é ~50 M) + animação de fuga no tapete voador. **Derrota**: o Gênio leva a princesa; é preciso coletar as 7 Joias de novo; Specials acendem para a próxima tentativa.
* Crítica dos jogadores: o modo pode durar "para sempre" (bolas ilimitadas), o que abre os exploits do §2.4; a defesa é que plunger manual e cansaço limitam na prática.

### 2.10 Skill shot e ball save (resumo)

* Skill shot de **três cestos** por dosagem do plunger (50k→125k) + **Super Skill Shot** na rampa (2× valor). Sensores conhecidos por não registrarem bem.
* Ball save convencional no início da bola **mais** o sistema físico de Estrelas Cadentes (acendíveis pelos bancos de standups, com compensação por falha). Sem ball save no início do multiball.

---

## 3. Fluxo típico de uma partida (jogador forte)

O jogador lança dosando o plunger para o cesto aceso e imediatamente sobe a **rampa** (super skill shot), que devolve ao flipper direito. Dali o tiro natural é a **Lâmpada** (quando os postes estão na horizontal) ou o **orbit esquerdo**; ele alterna entre bater na Lâmpada para acumular giros (bônus persistente e Desejos a cada 15) e acertar o **Gênio** para soletrar as 5 letras e acender as travas. Com trava acesa, os orbits viram tiros de trava graças ao ímã, então ele usa as **Voltas do Tigre** (inlane → orbit oposto) para travar duas bolas enquanto acumula loops rumo à bola extra dos 6 loops. Antes de iniciar o multiball, se tiver um Desejo, ele espera a Lâmpada Relâmpago e pega **3× Lâmpada**, então inicia o multiball no Gênio e passa a martelar a Lâmpada (jackpot crescente) alternando Gênio/orbit para reacender jackpots. Entre multiballs, inicia um Conto no Gênio: os fáceis (Contadora, Tapete, Ciclope, Camelos, Pássaros) são concluídos em 1–5 tiros e a Joia coletada na rampa; os difíceis (Caverna, Cavalo) são "desejados" no Bazar — de preferência com o Rubi aceso para pegar duas de uma vez. Quatro Joias dão outra bola extra. As **decisões** recorrentes são: (1) gastar o Desejo em Joia ou em 3× (Lâmpada/Bola de Fogo)/loops; (2) atirar na Lâmpada agora (risco de devolução para o centro) ou esperar a posição dos postes; (3) segurar a bola no flipper para o Harém reacender no orbit esquerdo em vez de aceitar Tigre/trava; (4) na última bola, deixar de coletar Joias e bater nas cativas para multiplicar um bônus construído desde a bola 1; (5) levar Harém ou 3× Lâmpada vivos para dentro da Batalha final, onde bolas são ilimitadas. A partida termina na Batalha: fase de esqueletos com uma bola, depois o cabo de guerra frenético de 4 bolas com lançamentos manuais contínuos.

---

## 4. Mapa de adaptação para "Relicário do Abismo"

Legenda da coluna "Status": **JÁ TEMOS** = recurso existente cobre; **ADAPTAR** = existe algo parecido, falta regra; **NOVO** = não temos.

| Elemento/regra de TOTAN | Equivalente original proposto (nome PT) | Regra em uma linha | Status |
|---|---|---|---|
| 2 flippers, slingshots, inlanes/outlanes | Base padrão | — | JÁ TEMOS |
| Rampa única com 3 saídas e diverters | **Nave Central** (rampa esquerda) com **Bifurcação do Coro**: saída normal ao flipper direito; saída "consagrada" (diverter) que devolve pelo lado esquerdo passando pelo **Ostensório** (anel de retenção) | Quando há relíquia a coletar ou hurry‑up ativo, a rampa muda de rota e o Ostensório segura a esfera para a cena, soltando‑a no flipper esquerdo. | ADAPTAR (temos rampa esquerda; faltam rota alternativa + retenção) |
| Espiral transparente sobre os bumpers | **Rosácea** — espiral que, se a esfera perde força, cai no ninho de bumpers | Tiro fraco na rampa alimenta os bumpers; tiro muito fraco = "Trava Furtiva" (1 por partida). | NOVO |
| 2 orbits (um com diverter para bumpers) | **Deambulatórios** esquerdo/direito | Orbit esquerdo com portão que desvia para as **Gárgulas** (bumpers) quando o Sangue‑de‑Pedra (Harém) está aceso. | JÁ TEMOS orbits; falta diverter |
| 3 pop bumpers isolados no canto | **Gárgulas** (3) | Cada acerto soma +1k ao Jackpot das Catacumbas (frenesi). | JÁ TEMOS? (verificar se existem bumpers) |
| Entrada furtiva do Harém (calha atrás dos bumpers) | **Fresta da Cripta** | 3 entradas por sorte iniciam o Frenesi das Catacumbas. | NOVO |
| Lâmpada giratória (giros → bônus persistente, marcos 15/30/60, Desejos) | **Turíbulo** — incensário pendurado em dois postes num disco giratório | Cada meia‑volta = 1 "Sopro de Incenso" (+bônus persistente); a cada 15 sopros acende **Oração Relâmpago** e concede 1 **Indulgência** (máx 3). Disco para em ângulo aleatório, alterando o risco. | NOVO (nossa **torre de runas** pode ser a base física; a mecânica de giro é nova) |
| Lâmpada Relâmpago (rodada de 10 s reiniciada a cada giro) | **Oração Relâmpago** | 10 s; cada sopro paga 250k+ e reinicia o timer; sopros extras não contam para o próximo marco. | NOVO |
| Desejo (escolha Joia × prêmio contextual) | **Indulgência** no scoop | Flipper esq.: conclui a missão/estágio atual e concede seu **Selo/Relíquia** (2 se o **Estigma** estiver aceso); flipper dir.: prêmio contextual (Coletar bônus, 3× hurry‑up, 3× Oração, +3 Voltas, Bola extra rara). | NOVO |
| Rubi (dobra a Joia do Desejo) | **Estigma** | Acende com Indulgência acesa + os dois **Guardiões das Outlanes** acesos + um terceiro acendimento; consumido ao usar; zera por bola. | NOVO |
| Gênio (bash toy + ímã que captura ou arremessa) | **Guardião** (já existe, com escudo) + **Ímã do Abismo** | 5 acertos soletram uma palavra e acendem travas; com a "cripta" acesa, o ímã suga a esfera para iniciar estágio/multiball, ou a cospe de volta (susto). | ADAPTAR (guardião existe; ímã e captura são novos) |
| Trava por ímã nos orbits + lane oculta + saucer empilhador | **Trava do Altar** | Com trava acesa, o ímã acima do deambulatório intercepta o tiro e derruba a esfera na lane oculta até o saucer; tiros diretos na lane sem trava acesa dão prêmio pequeno. | JÁ TEMOS trava de 2 bolas; faltam ímã e "entrada não acesa" |
| Multiball do Gênio (3 bolas, jackpot no bash toy, reacende no orbit, Revanche) | **Multiball do Abismo** | Jackpot no Guardião; sopros do Turíbulo elevam o jackpot; após coletar, um deambulatório aleatório reacende; se sobrar 1 bola sem jackpot, o scoop dá **Revanche** (bola de volta). | JÁ TEMOS 3‑ball; faltam jackpot crescente, reacender, revanche |
| Harém Multiball (2 bolas, frenesi de switches, prioridade de tiros) | **Frenesi das Catacumbas** (2 bolas) | 5 tiros no deambulatório esquerdo (só quando Voltas/Trava expiraram) ou 3 Frestas; todo switch paga um jackpot que cresce com Gárgulas. | NOVO |
| 5 Símbolos Dourados (tiros de modo) | **5 Vitrais** (banco esq., orbit esq., rampa, orbit dir., banco dir.) | Os estágios/bosses usam subconjuntos desses cinco tiros; luz dedicada por vitral. | ADAPTAR (temos drop bank, rampa, orbits; falta o quinto tiro) |
| 7 Contos persistentes com objetivos variados | **7 Capítulos do Relicário** (dentro dos 3 estágios) | Selecionáveis pelo flipper esq. no início da bola; progresso persiste entre bolas; conclusão acende a rampa para coletar a **Relíquia**. | ADAPTAR (temos 3 estágios/3 selos; falta variedade e persistência) |
| Conto "bumpers" | *Cap. Gárgulas* | 1+ acerto de Gárgula com o portão aberto. | NOVO |
| Conto "soletrar 6 letras nos standups" | *Cap. Litania* | Soletrar 6 letras nos dois bancos de alvos. | ADAPTAR (drop bank) |
| Conto "achar a relíquia oculta em 5 alvos" | *Cap. Sepulcros* | Relíquia escondida aleatoriamente num dos 5 Vitrais (geralmente o último). | NOVO |
| Conto "1 tiro em qualquer símbolo" | *Cap. Sussurro* | Qualquer Vitral conclui; extras dão pontos. | NOVO |
| Conto "N tiros em qualquer símbolo (corrida)" | *Cap. Procissão* | 4–5 acertos em qualquer Vitral; barra de corrida no display. | NOVO |
| Conto "rampa 2×" | *Cap. Ascensão* | 1 rampa conclui, a 2ª coleta. | NOVO |
| Conto "bola cativa 1×" | *Cap. Behemoth* | Qualquer cativa/saucer lança um golpe; valor +10k por acerto. | NOVO (precisa de cativas) |
| 2 bolas cativas (+ saucer na esquerda) e multiplicador de bônus | **Sinos** esq./dir. | Acerto pleno no Sino aceso = +1× bônus (máx 12×); saucer do Sino esquerdo acumula para acender o **Fogo‑Fátuo**. | NOVO |
| Fireball (hurry‑up rampa → bash toy) | **Fogo‑Fátuo** | Acende com N saucers (N cresce +1 por uso); rampa inicia contagem de 20 s desde 400k+200k×N; acertar o Guardião coleta; Indulgência pode triplicar. | NOVO |
| Bazar (6 letras, prêmio aleatório, 3→2→1 letras, easter egg da vaca) | **Sacristia** (scoop) | Letras S‑A‑C‑R‑I‑S via scoop/mini‑alvos; prêmio aleatório da lista; segredo de apertar os dois flippers 4 vezes → **Relíquia Profana** de 1 M. | NOVO |
| Voltas do Tigre (inlane acende orbit oposto; 6/20 loops = bola extra) | **Voltas do Claustro** | Inlane acende o deambulatório oposto por tempo; loops encadeiam; 6 = bola extra, 20 = 2ª. | NOVO |
| Bola extra por 4 Joias, coletada no orbit direito | **Vida por 4 Relíquias** | 4 relíquias acendem bola extra no deambulatório direito. | NOVO |
| Estrelas Cadentes (pinos físicos nas outlanes, acendíveis pelos bancos de alvos, com compensação) | **Guardiões das Outlanes** | Qualquer alvo do banco de um lado acende o guardião daquele lado; ele sobe e devolve a esfera; falha = esfera devolvida por software (não em multiball). | NOVO (o **guardião com escudo** existente pode ser a metáfora, mas aqui é um ball‑save físico) |
| Skill shot de 3 cestos + super skill na rampa | **Três Naves** do lançamento | Plunger manual dosado no cesto aceso (50k→125k); rampa em seguida = 2×. | ADAPTAR (temos top lanes I/II/III; usar como os 3 cestos) |
| Bônus persistente entre bolas × multiplicador que zera | **Rosário** | Contas (sopros) acumulam a partida inteira; multiplicador zera por bola salvo "Segurar" da Sacristia; contagem final sincronizada com música. | NOVO |
| Modo final em 2 fases (esqueletos → cabo de guerra com bolas ilimitadas e plunger manual) | **Exorcismo Final** | Fase 1: Vitrais matam **Possessos** que ressuscitam até 3; fase 2: até 4 esferas, todos os Vitrais acesos puxam a **Alma** para o jogador enquanto o Abismo a puxa de volta; esfera parada no plunger acelera o Abismo; vitória = 20 M + Specials. | ADAPTAR (temos 3 bosses; falta o modo final com esta estrutura) |
| Consecrated Ball / mana | Sem equivalente em TOTAN | Manter: é nosso diferencial; pode substituir a "Indulgência" ou coexistir. | JÁ TEMOS |

---

## 5. Fontes consultadas

* Rulesheet v1.2 (Joshua Lehan, 23/06/1997) — https://pinball.org/rules/talesofthearabiannights.html
* Mesmo rulesheet no GameFAQs — https://gamefaqs.gamespot.com/pinball/915959-tales-of-the-arabian-nights/faqs/1482
* Wikipedia (EN) — https://en.wikipedia.org/wiki/Tales_of_the_Arabian_Nights_(pinball)
* TV Tropes — https://tvtropes.org/pmwiki/pmwiki.php/Pinball/TalesOfTheArabianNights
* San Diego Pinball Club Cheatsheet (aponta para o rulesheet da PAPA) — https://pinball.miraheze.org/wiki/Tales_of_the_Arabian_Nights
* A&F Pinball Restorations (lista de componentes) — https://www.afpinball.com/p/tales-of-the-arabian-nights
* Pinball Mag (review) — https://pinballmag.fr/en/tales-of-the-arabian-nights-williams-2/
* Pinside, tópico "Tales of the Arabian Nights and its Code" — https://pinside.com/pinball/forum/topic/tales-of-the-arabian-nights-and-its-code
* Digital Pinball Fans, "TOTAN Tactics and Strategies" — https://digitalpinballfans.com/threads/totan-tactics-and-strategies.584/
* OPDB (dados básicos) — https://opdb.org/machines/594
* Kineticist, tutorial (só trechos via busca; página bloqueada) — https://www.kineticist.com/news/tales-of-the-arabian-nights-tutorial
* IPDB #3824 (bloqueado por proteção anti‑bot; dados de produção obtidos via OPDB/Wikipedia) — https://www.ipdb.org/machine.cgi?id=3824
* Rulesheet espelhado no IPDB (bloqueado) — https://www.ipdb.org/rulesheets/3824/TOTAN.HTM
