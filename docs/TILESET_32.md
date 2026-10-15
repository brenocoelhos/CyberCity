# Cenário da imagem enviada — grade fixa de 32×32

O arquivo original tem **1254×1254 pixels**, com margens e espaçamentos irregulares.
Ele está preservado em `assets/source/environment_reference.png`.
Os recortes usam seus pixels, sem redesenho por IA, e são reduzidos com Nearest.
A redução perde detalhes da imagem grande; não usa suavização e não estica as casas.

## O que está no projeto

- `assets/environment/extracted/terrain_32.png`: atlas de **352×160**, 11 colunas × 5 linhas de 32×32. São **53 peças**, com duas células vazias no fim.
- `scenes/world/CityTileSet.tres`: Tile Size e Texture Region Size = **32×32**, sem margens ou separação.
- `scenes/world/City.tscn`: cidade com 6 quarteirões, 10 construções, praça, decoração, placas e o Guia.
- `scripts/world/City.gd`: pinta o terreno no início do jogo (ruas, calçadas, faixas e áreas calçadas), cria as bordas e liga o minimapa.
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
de terreno automaticamente. A cidade atual usa retas, curvas, T, cruzamentos e faixas.

## Quarteirões da cidade

O mapa tem **62×27 tiles** (1984×864 pixels). As ruas formam um anel em volta
da cidade e dividem o centro em **6 quarteirões** de 16×8 tiles, cada um com
calçada em volta. Os prédios ficam na parte de baixo do quarteirão, com a porta
na calçada, de frente para a rua. A parte de cima é quintal, praça ou pátio.

| Quarteirão | Tiles (x, y) | Prédios | Desafios |
|---|---|---|---|
| Bairro Residencial | 4–19, 4–11 | Casa 1, Casa 2, Casa 6 | Missão 01 |
| Praça Central | 23–38, 4–11 | — (praça com o Guia) | ponto de partida |
| Distrito Empresarial | 42–57, 4–11 | TechCorp Ltda., DataSoft Sistemas | Missões 02, 03 e 06 |
| Vila Residencial | 4–19, 15–22 | Casa 3, Casa 4, Casa 5 | Missão 01 |
| Centro de Tecnologia | 23–38, 15–22 | Centro de Tecnologia (trancado até a Missão 01) | Missões 04, 05 e 07 |
| Comércio | 42–57, 15–22 | Loja Eletrônica | Missões 08, 09 e 10 |

- Ruas: colunas `ROADS_X = [2, 21, 40, 59]` e linhas `ROADS_Y = [2, 13, 24]`
  em `scripts/world/City.gd`. A peça certa (reta, curva, T ou cruzamento) é
  escolhida sozinha olhando os vizinhos (`ROAD_PIECES`).
- Faixas de pedestre ficam a 3 tiles de cada cruzamento. Nas ruas verticais a
  mesma peça `(7,2)` é usada girada (alternativa com **Transpose**).
- Praça, pátios e caminhos calçados: lista `PAVED_AREAS` em `City.gd`.
- Placas com o nome do quarteirão e suas missões: nó **Districts** da cidade.
- Prédios: o "!" amarelo aparece sobre o prédio quando uma das missões em
  **Inspector → Mission Ids** é do capítulo atual (ou está em andamento).
- Bordas: `City.gd` cria paredes invisíveis na faixa de grama em volta do mapa.
- Minimapa: mostra a cidade inteira e um ponto vermelho no lugar do jogador.

### Novo prédio ou nova rua

1. Para um prédio, selecione **Buildings**, clique com o botão direito →
   **Instantiate Child Scene** e escolha `scenes/world/Building.tscn`.
2. Em **Position**, use **y = 384** (quarteirões de cima) ou **y = 736**
   (de baixo), para a porta cair na calçada. Para **x**, um prédio de 3 tiles
   começando no tile `L` fica em `L × 32 + 48`.
3. Preencha **Facade**, **Building Name**, **Interior Path** e **Mission Ids**.
4. Para outra rua, acrescente o número da coluna em `ROADS_X` ou da linha em
   `ROADS_Y` e, se o mapa crescer, aumente `MAP_WIDTH`/`MAP_HEIGHT`.

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
O teste verifica as 1674 células, as peças de rua e faixas, as entradas
acessíveis das dez construções (porta sobre a calçada), os destinos dos
interiores e os tamanhos.

Para renderizar uma visão geral sem a interface:

```text
godot --path . --script res://tools/verify_environment.gd -- --preview
```

O resultado é `docs/city_preview.png`.
