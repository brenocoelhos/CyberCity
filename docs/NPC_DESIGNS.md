# NPCs: 11 identidades

Todos estaticos, Sprite2D, canvas 314x314, escala 0.125, Nearest.

| Local | NPC | Asset |
|---|---|---|
| Praca | Guia | guide |
| Casa 1 | Morador | house1 |
| Casa 2 | Vizinha | house2 |
| Casa 3 | Morador | house3 |
| Casa 4 | Vizinho | house4 |
| Casa 5 | Desconhecido | house5 |
| Casa 6 | Moradora | house6 |
| TechCorp | Funcionario | techcorp |
| DataSoft | Funcionario | datasoft |
| Centro de Tecnologia | Pesquisadora | scientist |
| Loja Eletronica | Desenvolvedora | developer |

Fonte: assets/characters/npcs/unique_designs_source.png. Reproduzir os recortes:
Godot --headless --path . --script res://tools/import_npc_designs.gd

NPCVisual.gd resolve a identidade pelo local, pois nomes e cenas se repetem.
verify_npc_designs.gd instancia os dez interiores reais e o guia para detectar duplicatas.
