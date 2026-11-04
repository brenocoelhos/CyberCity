extends Node
## PlayerNotes.gd — Autoload
## O bloco de notas do jogador, no app "Notas" do celular. É só um texto livre
## que o jogador escreve para si (pistas, senhas achadas, IPs, o que falta
## fazer). O jogo nunca lê nem altera esse texto: serve para quem quer
## resolver os enigmas anotando por conta própria, sem o dossiê automático.
## É gravado junto do save (ver SaveManager.gd).

signal changed

## Limite de caracteres, para o save não crescer sem fim.
const MAX_LENGTH := 6000

var text: String = ""


func set_text(value: String) -> void:
	var limited: String = value.left(MAX_LENGTH)
	if limited == text:
		return
	text = limited
	changed.emit()


## Apaga as notas (usado por "Novo jogo").
func reset() -> void:
	text = ""
	changed.emit()


func get_save_data() -> Dictionary:
	return {"text": text}


func load_save_data(data: Dictionary) -> void:
	text = String(data.get("text", "")).left(MAX_LENGTH)
	changed.emit()
