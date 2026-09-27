# Personagem principal — Godot 4

Implementado em `scenes/player/Player.tscn`, com o script em `scripts/player/Player.gd`.
A imagem `assets/characters/player_sheet.png` é uma cópia idêntica do PNG enviado.
O mapa continua usando tiles de **32×32**. O tamanho de um frame do personagem não altera essa grade.

## Atenção à imagem original

O PNG mede **1254×1254**. Sua divisão lógica é 4×4, mas 1254 ÷ 4 = 313,5.
O recurso preparado usa limites inteiros 0, 313, 627, 940 e 1254. Os recortes
ficam dentro das células correspondentes. As margens transparentes de AtlasTexture
alinham os pés em um canvas virtual de 314×314, sem editar ou redesenhar o PNG.

Na segunda linha, os frames 3 e 4 olham para a direita. Conforme sua escolha,
`andar_esquerda` usa **1–2–1–2**, e não espelha nenhum frame.

## Conferir a implementação pronta

1. No painel **FileSystem**, abra `scenes/player/Player.tscn`.
2. Na árvore **Scene**, selecione **AnimatedSprite2D**.
3. No **Inspector → Animation → Sprite Frames**, clique no recurso **PlayerFrames**.
4. No painel **SpriteFrames**, selecione uma animação e clique **Play** para visualizá-la.
5. Selecione o nó raiz **Player**. A propriedade **Speed** está em **160 pixels/s** e pode ser alterada.
6. Pressione **F5** para testar na cidade. WASD e setas já estão configurados.

## Como montar manualmente no editor

### Importar e criar os nós

1. Copie o PNG para a pasta `assets/characters` do projeto usando o Explorador de Arquivos. O Godot importa automaticamente. Para esta imagem, o arquivo já está em `player_sheet.png`.
2. Para uma cena nova: **Scene → New Scene → Other Node**, procure **CharacterBody2D** e clique **Create**. Renomeie para **Player**.
3. Selecione **Player**, pressione **Ctrl+A** (**Add Child Node**) e adicione **AnimatedSprite2D**.
4. Repita para adicionar **CollisionShape2D**.
5. No projeto atual também existem **Camera2D** e **FootstepTimer**, que o código utiliza.
6. Selecione **AnimatedSprite2D → Inspector → Texture → Filter → Nearest**. Deixe **Flip H** e **Flip V** desmarcados.

### Criar SpriteFrames e selecionar a grade

1. Selecione **AnimatedSprite2D**.
2. Em **Inspector → Animation → Sprite Frames**, abra a seta à direita de **<empty>** e escolha **New SpriteFrames**.
3. Clique no recurso criado para abrir o painel **SpriteFrames**, na parte inferior.
4. Renomeie `default` para `andar_baixo`, dando dois cliques no nome.
5. Clique **Add frames from a Sprite Sheet**, o botão com ícone de grade na barra de frames.
6. Escolha `player_sheet.png` e clique **Open**.
7. Na janela de seleção, configure **Horizontal = 4** e **Vertical = 4**. Selecione as quatro células da primeira linha, da esquerda para a direita, e clique **Add 4 Frames**.
8. Configure **Speed (FPS) = 8** e habilite **Loop**.
9. Use **Add Animation** para criar as outras animações e repita a seleção seguindo a tabela abaixo.
10. Para a esquerda, adicione apenas as duas primeiras células da segunda linha. Abra novamente **Add frames from a Sprite Sheet** e adicione as mesmas duas células ao final: resultado **1–2–1–2**.
11. Para cada animação parada, adicione apenas o primeiro frame de sua direção. Configure **FPS = 1**; o loop com um frame mantém a pose imóvel.
12. No menu do recurso **Sprite Frames**, escolha **Save As** para salvar o arquivo `.tres`.

O fluxo de seleção por grade é o [documentado pelo Godot](https://docs.godotengine.org/en/stable/tutorials/2d/2d_sprite_animation.html).
**Horizontal/Vertical** são campos da janela de importação de frames. Não procure
`Hframes/Vframes` no AnimatedSprite2D: essas propriedades pertencem ao Sprite2D.

A seleção manual uniforme pode deixar margens diferentes e causar oscilação na posição
aparente. Para usar os recortes inteiros e o alinhamento já preparados para este PNG,
escolha **Sprite Frames → Load** e carregue `assets/characters/PlayerFrames.tres`.
Isso preserva o arquivo original e não exige redimensionar a imagem.

| Animação | Linha (contagem a partir de 1) | Colunas / sequência | FPS |
|---|---|---|---|
| andar_baixo | 1 | 1, 2, 3, 4 | 8 |
| andar_esquerda | 2 | 1, 2, 1, 2 | 8 |
| andar_direita | 3 | 1, 2, 3, 4 | 8 |
| andar_cima | 4 | 1, 2, 3, 4 | 8 |
| parado_baixo | 1 | 1 | 1 |
| parado_esquerda | 2 | 1 | 1 |
| parado_direita | 3 | 1 | 1 |
| parado_cima | 4 | 1 | 1 |

### Tamanho, colisão e controles

1. No **AnimatedSprite2D → Transform → Scale**, configure **X = 0.125, Y = 0.125**. Em **Position**, use **X = 0, Y = -19.625**. Isso corresponde ao recurso preparado, cujo canvas é 314×314; o personagem aparece com cerca de 36 pixels de altura visível.
2. No **CollisionShape2D → Shape**, escolha **New RectangleShape2D**. Clique no recurso e configure **Size = 18×12**. No nó, configure **Transform → Position = (0,-6)**. A colisão fica nos pés.
3. No **Player → Collision**, use **Layer = 2** e **Mask = 1**, conforme o mundo do projeto.
4. Adicione **Timer** como filho de Player e renomeie **FootstepTimer**. Configure **Wait Time = 0.32**, **One Shot = On** e **Autostart = Off**.
5. Abra **Project → Project Settings → Input Map**. Crie as ações abaixo se ainda não existirem. Em cada ação, clique **+**, pressione a tecla e confirme **OK**. Adicione as duas teclas separadamente.

| Ação | Teclas |
|---|---|
| move_up | W e seta para cima |
| move_down | S e seta para baixo |
| move_left | A e seta para esquerda |
| move_right | D e seta para direita |

6. Selecione **Player → Attach Script**, escolha GDScript, herança **CharacterBody2D**, e salve como `scripts/player/Player.gd`.
7. Cole o código completo abaixo. No projeto atual ele já está aplicado, preservando os menus, desafios e sons.

A cena fica assim:

```text
Player (CharacterBody2D) ← Player.gd
├── AnimatedSprite2D
├── CollisionShape2D
├── Camera2D
└── FootstepTimer
```

## Código completo aplicado

Este código é para o **Cyber City atual**: usa seus autoloads de interface e som.
Na diagonal, a animação horizontal tem prioridade. Ao parar, a última direção
é mantida. A normalização mantém a velocidade igual em todas as oito direções.

```gdscript
extends CharacterBody2D

## Velocidade em pixels por segundo, editável no Inspector.
@export var speed: float = 160.0

var last_direction: Vector2 = Vector2.DOWN
var _facing: String = "baixo"

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var footstep_timer: Timer = $FootstepTimer

func _ready() -> void:
	sprite.play("parado_baixo")

func _physics_process(_delta: float) -> void:
	var direction := Vector2.ZERO
	if not _is_ui_blocking():
		direction = Vector2(
			Input.get_axis("move_left", "move_right"),
			Input.get_axis("move_up", "move_down")
		).normalized()

	velocity = direction * speed
	move_and_slide()
	_update_animation(direction)
	_update_footsteps(direction)

func _update_animation(direction: Vector2) -> void:
	if direction != Vector2.ZERO:
		last_direction = direction
		# Nas diagonais, a direção horizontal tem prioridade visual.
		if direction.x < 0.0:
			_facing = "esquerda"
		elif direction.x > 0.0:
			_facing = "direita"
		elif direction.y < 0.0:
			_facing = "cima"
		else:
			_facing = "baixo"

	var prefix := "parado_" if direction == Vector2.ZERO else "andar_"
	var animation_name := StringName(prefix + _facing)
	# Não reinicia o mesmo ciclo a cada frame.
	if sprite.animation != animation_name or not sprite.is_playing():
		sprite.play(animation_name)

func _is_ui_blocking() -> bool:
	# Integração com os menus e desafios já existentes no Cyber City.
	return DialogueManager.is_active() \
		or TerminalManager.is_active() \
		or ChallengeManager.is_active() \
		or GameMenu.is_active() \
		or HUD.is_popup_active()

func _update_footsteps(direction: Vector2) -> void:
	if direction == Vector2.ZERO or get_real_velocity().length() < 1.0:
		footstep_timer.stop()
		return
	if footstep_timer.is_stopped():
		SoundManager.play("footstep", -8.0)
		footstep_timer.start()
```

## Verificação

`tools/verify_player.gd` verifica animações, linhas de origem, movimento, velocidade
diagonal, direção parada, avanço dos frames e pausa por diálogo. O teste de ambiente
também passou com a nova colisão do personagem. A comparação SHA-256 confirmou
que o PNG do projeto é idêntico ao anexo.

Para recriar apenas o recurso de frames, sem editar a imagem:

```text
godot --headless --path . --script res://tools/build_player_frames.gd
godot --headless --path . --script res://tools/verify_player.gd
```

