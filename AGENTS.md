# Convenções do projeto

- Unidade fixa do mapa: 32×32 pixels. Não alterar sem pedido do usuário.
- Terreno, estrada e calçada: peças de 32×32 em TileMapLayer.
- Casas: sprites independentes sobre o terreno, podendo ocupar vários tiles.
- Pixel art: Nearest e redimensionamento proporcional sem suavização.
- Preservar assets/source/environment_reference.png; recortes reproduzíveis em tools/import_environment.gd.
- Explicações em português, simples, com nomes dos menus e propriedades do Godot.
