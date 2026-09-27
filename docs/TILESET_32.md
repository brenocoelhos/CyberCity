# Cenário da imagem enviada — grade fixa de 32×32

O arquivo original tem **1254×1254 pixels**, com margens e espaçamentos irregulares.
Ele está preservado em `assets/source/environment_reference.png`.
Os recortes usam seus pixels, sem redesenho por IA, e são reduzidos com Nearest.
A redução perde detalhes da imagem grande; não usa suavização e não estica as casas.

## O que está no projeto

- `assets/environment/extracted/terrain_32.png`: atlas de **352×160**, 11 colunas × 5 linhas de 32×32. São **53 peças**, com duas células vazias no fim.
- `scenes/world/CityTileSet.tres`: Tile Size e Texture Region Size = **32×32**, sem margens ou separação.
- `scenes/world/City.tscn`: cidade com as casas, árvores, arbustos, bancos, cercas e postes extraídos.
- `scripts/world/City.gd`: pinta o terreno no início do jogo. Cada segmento de rua ocupa uma célula; há um único cruzamento central.
- `scripts/world/Building.gd`: controla o sprite completo, o nome, a base de colisão e a entrada de cada construção.
- `assets/environment/extracted/manifest.json`: coordenadas exatas dos recortes e dimensões dos sprites.

## Peças do atlas

As coordenadas abaixo começam em **zero**: `(coluna, linha)`.

| Peça | Coordenadas |
|---|---|
| Grama e variações com flores | `(0,0)` a `(5,0)` |
| Terra e transições de grama | `(6,0)` a `(10,0)` |
| Calçadas e transições para terra/grama | `(0,1)` a `(10,1)` |
| Reta vertical | `(0,2)` |
| Reta horizontal | `(1,2)`; alternativa `(3,2)` |
| Curva esquerda/baixo | `(2,2)` |
| Curvas nas outras três orientações | `(0,4)` a `(2,4)` |
| Cruzamento de quatro vias | `(4,2)`; alternativa `(5,2)` |
| T com saída para baixo | `(6,2)` |
| T nas outras três orientações | `(3,4)` a `(5,4)` |
| Faixa de pedestre | `(7,2)` |
| Marcação de final de rua | `(8,2)` |
| Marcação de final nas outras orientações | `(6,4)` a `(8,4)` |
| Asfalto com borda / sem sinalização | `(9,2)` / `(10,2)` |
| Guias, cantos, bordas e bueiro | `(0,3)` a `(10,3)` |

Os finais representam a sinalização da imagem original. Para uma rua fisicamente
fechada, combine a marcação com uma guia e uma colisão. O TileSet não cria colisões
de terreno automaticamente. A cidade atual usa retas, cruzamento e faixas; as demais
peças estão disponíveis para ampliar o mapa.

## Tamanho dos objetos no mapa

| Arquivo | Pixels | Tiles |
|---|---|---|
| `house_01.png` | 64×64 | 2×2 |
| `house_02.png` a `house_07.png` | 96×96 | 3×3 |
| `shop_01.png`, `shop_02.png` | 96×96 | 3×3 |
| `house_wide.png` | 128×96 | 4×3 |
| `tree_round.png`, `tree_tall.png` | 64×64 | 2×2 |
| `bush*.png`, `rock.png`, `planter.png` | 32×32 | 1×1 |
| `lamp.png` | 32×64 | 1×2 |
| `bench.png`, `fence.png` | 64×32 | 2×1 |

Esses tamanhos são os canvases dos PNGs. O desenho mantém a proporção e pode ter
margem transparente. As casas usam escala **1,1**. As colisões cobrem a base da
construção, não o telhado. Árvores e objetos de decoração permanecem sem colisão.

## Conferir no Godot

1. Abra `scenes/world/City.tscn` e pressione **F5**. O chão é gerado quando o jogo começa.
2. Selecione **Ground → Inspector → Tile Set**: **Tile Size = 32×32**.
3. No painel inferior **TileSet**, selecione a fonte Atlas: **Texture Region Size = 32×32**, **Margins = 0,0**, **Separation = 0,0**.
4. Em **Project → Project Settings → Rendering → Textures → Canvas Textures**, confirme **Default Texture Filter = Nearest**.
5. Para trocar uma casa, selecione **Buildings → Casa1** (ou outra). No Inspector, arraste o PNG para **Facade**. **Building Name**, **Interior Path** e **Entrance X** configuram o nome, o destino e a posição horizontal da porta.
6. Para mover uma construção, mova seu nó raiz. O sprite, o nome e a colisão acompanham. Use encaixe de posição de **32×32** no editor 2D.

O terreno é procedural: pinturas manuais em Ground são substituídas por City.gd
ao iniciar. Para alterar o layout atual permanentemente, edite `_tile_for()`.

## Reproduzir os recortes e validar

Execute a partir da pasta do projeto, substituindo `godot` pelo caminho do executável:

```text
godot --headless --path . --script res://tools/import_environment.gd
godot --headless --path . --editor --import --quit
godot --headless --path . --script res://tools/verify_environment.gd
```

O importador é uma ferramenta local de preparação, não é executado pelo jogo.
O teste verifica as 1176 células, as entradas acessíveis das nove construções,
os destinos dos interiores, os tamanhos e o cruzamento.

Para renderizar uma visão geral sem a interface:

```text
godot --path . --script res://tools/verify_environment.gd -- --preview
```

O resultado é `docs/city_preview.png`.
