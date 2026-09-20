# Créditos e licenças

## Projeto

- **Relicário do Abismo** — design, código GDScript, layout da mesa, textos: criados para este projeto.
- Licença do projeto: MIT (`LICENSES/PROJECT-MIT.txt`).

## Motor

- **Godot Engine 4.7.2** — MIT License. https://godotengine.org — texto em `LICENSES/GODOT-MIT.txt`.
  Binário oficial baixado de https://github.com/godotengine/godot/releases (SHA512 conferido com `SHA512-SUMS.txt`).

## Arte

- `assets/art/stages/`, `assets/art/props/` e `assets/art/ui/`: imagens ORIGINAIS geradas para este projeto em
  2026-09-07 com o gerador de imagens do ChatGPT (GPT-5, conta do autor), a partir de descrições próprias
  (estilo "pixel art gótica 32-bit"), sem citar jogos ou artistas; recortadas/redimensionadas por
  `tools/process_stage_art.py` e `tools/process_props.py`. Runas e símbolos são ficcionais.
- Fallback procedural: `tools/gen_sprites.py` (Python + Pillow + numpy) gera os placeholders de `assets/art/*.png`.
- Nenhuma imagem foi copiada de jogos de referência (Devil's Crush, Demon's Tilt, Xenotilt) ou de terceiros.

## Áudio

- Todos os efeitos sonoros e as duas músicas em `assets/audio/` são sintetizados por `tools/gen_audio.py`
  (Python + numpy), criados para este projeto.

## Fontes

- Fonte padrão do Godot (Open Sans/Noto integradas ao motor, licença do motor).

## Ferramentas usadas na geração

- Python 3, Pillow (MIT-CMU), numpy (BSD) — apenas como ferramentas; nada delas é distribuído no jogo.

## Assets externos

- Nenhum. Nada foi baixado de OpenGameArt, Kenney, itch.io ou outros. Caso sejam adicionados no futuro,
  registrar aqui URL, autor, licença, data e alterações, e guardar o texto da licença em `LICENSES/`.
