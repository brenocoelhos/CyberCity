# Exterior cyberpunk

Fonte: assets/source/cyber_exterior.jpg; referencia geral: cyber_overview.jpg.
A fonte environment_reference.png foi preservada.

Reproduzir assets: Godot --headless --path . --script res://tools/import_environment.gd
Depois importar os PNGs no editor. O importador chama import_cyber_exterior.gd,
que registra os retangulos de recorte e usa escala proporcional Nearest.

Terreno: TileMapLayer de 32x32. Fachadas: sprites independentes.
As dez entradas originais mantem interiores e missoes. Fachadas adicionais
sao decorativas, com colisao na base, criadas em City.gd.
A praca central preserva vegetacao; os demais patios usam piso urbano.

Verificacao: tools/verify_environment.gd; adicionar -- --preview para imagem.

Variedade adicional: 12 fachadas em cyber_buildings_variety.png, atlas 6x2, importadas como building_8 a building_19. As fileiras de cada bairro usam sequencias distintas. Os modelos originais e a paleta cyberpunk foram mantidos.
