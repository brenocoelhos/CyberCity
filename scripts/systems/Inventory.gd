extends Node
## Inventory.gd — Autoload
## Mochila do agente: itens ganhos ao concluir missões (um por missão) e
## itens achados pela cidade. Aparece no app "Mochila" do celular.
##
## Os itens das missões sempre batem com as missões concluídas (até em saves
## antigos, feitos antes de existir a mochila). Itens extras, que não vêm de
## missão, ficam guardados no save (SaveManager, chave "inventory").

signal item_added(item_id: String)

const CyberIcon := preload("res://scripts/ui/CyberIcon.gd")

## id -> [nome, descrição, ícone, cor]
const ITEMS := {
	"badge": ["Crachá de agente", "Identificação da Central Cyber City. Abre as portas dos prédios com missão.", CyberIcon.Kind.EMBLEM, Color("#0a84ff")],
	"phish_guide": ["Guia anti-phishing", "Checklist: remetente, domínio, urgência, links e anexos. Desconfie antes de clicar.", CyberIcon.Kind.MAIL, Color("#ff9f0a")],
	"password_vault": ["Cofre de senhas", "Gerenciador de senhas: uma senha longa e diferente para cada serviço.", CyberIcon.Kind.LOCK, Color("#34c759")],
	"hash_scanner": ["Leitor de hash", "Compara impressões digitais SHA-256 para saber se um arquivo foi alterado.", CyberIcon.Kind.DOCUMENT, Color("#64d2ff")],
	"cipher_key": ["Chave de decifragem", "A chave usada para abrir a mensagem cifrada. Criptografia protege o conteúdo.", CyberIcon.Kind.LOCK, Color("#bf5af2")],
	"phish_net": ["Rede de phishing", "Filtro treinado com os golpes que você caçou. Detecta links falsos.", CyberIcon.Kind.MAIL, Color("#ff375f")],
	"network_probe": ["Sonda de rede", "Lista os dispositivos conectados. Aparelho desconhecido na rede é sinal de alerta.", CyberIcon.Kind.WIFI, Color("#30d158")],
	"firewall_rules": ["Regras de firewall", "Cartão com as regras que você configurou: bloquear tudo, liberar só o necessário.", CyberIcon.Kind.SHIELD, Color("#ff453a")],
	"log_lens": ["Lupa de logs", "Destaca horários e IPs estranhos nos registros de acesso.", CyberIcon.Kind.MAGNIFIER, Color("#ffd60a")],
	"sql_shield": ["Escudo anti-SQLi", "Consultas parametrizadas: o que o usuário digita nunca vira comando.", CyberIcon.Kind.DATABASE, Color("#5e5ce6")],
	"xss_filter": ["Filtro anti-XSS", "Escapa < e > antes de mostrar comentários na página.", CyberIcon.Kind.SHIELD, Color("#ff9f0a")],
	"router_key": ["Chave do roteador", "Nova senha do roteador. Senha de fábrica é a primeira que o invasor tenta.", CyberIcon.Kind.LOCK, Color("#64d2ff")],
	"header_scope": ["Lente de cabeçalhos", "Mostra Return-Path e Received: de onde o e-mail veio de verdade.", CyberIcon.Kind.MAIL, Color("#ffd60a")],
	"spam_filter": ["Filtro de spam", "Regras para separar a caixa de entrada lotada de golpes em massa.", CyberIcon.Kind.FOLDER, Color("#30d158")],
	"twofa_token": ["Token 2FA", "Segundo fator de login: senha vazada sozinha não basta para entrar.", CyberIcon.Kind.PHONE, Color("#bf5af2")],
	"trace_map": ["Mapa da invasão", "O caminho que o invasor fez de máquina em máquina (movimento lateral).", CyberIcon.Kind.SERVER, Color("#ff453a")],
	"crawler": ["Rastreador de arquivos", "Encontra arquivos esquecidos expostos no site (backup, .env...).", CyberIcon.Kind.GLOBE, Color("#0a84ff")],
	"secret_scanner": ["Detector de segredos", "Procura senhas e chaves esquecidas no histórico do git.", CyberIcon.Kind.TERMINAL, Color("#34c759")],
}

## Item ganho ao concluir cada missão.
const MISSION_REWARDS := {
	"m01": "phish_guide", "m02": "password_vault", "m03": "hash_scanner", "m04": "cipher_key",
	"m05": "phish_net", "m06": "network_probe", "m07": "firewall_rules", "m08": "log_lens",
	"m09": "sql_shield", "m10": "xss_filter", "m11": "router_key", "m12": "header_scope",
	"m13": "spam_filter", "m14": "twofa_token", "m15": "trace_map", "m16": "crawler",
	"m17": "secret_scanner",
}

const STARTING_ITEMS := ["badge"]

## Itens extras (fora das missões), na ordem em que foram pegos.
var _extra: Array[String] = []


func _ready() -> void:
	MissionManager.mission_completed.connect(_on_mission_completed)


func reset() -> void:
	_extra.clear()


func get_save_data() -> Dictionary:
	return {"extra": _extra.duplicate()}


func load_save_data(data: Dictionary) -> void:
	_extra.clear()
	for id in Array(data.get("extra", [])):
		if ITEMS.has(String(id)) and not _extra.has(String(id)):
			_extra.append(String(id))


## Todos os itens que o jogador tem, na ordem: iniciais, missões, extras.
func get_items() -> Array[String]:
	var out: Array[String] = []
	for id in STARTING_ITEMS:
		out.append(id)
	for mission_id in MISSION_REWARDS.keys():
		if MissionManager.is_completed(mission_id):
			out.append(String(MISSION_REWARDS[mission_id]))
	for id in _extra:
		if not out.has(id):
			out.append(id)
	return out


func has_item(item_id: String) -> bool:
	return get_items().has(item_id)


func count() -> int:
	return get_items().size()


func item_name(item_id: String) -> String:
	return String(ITEMS.get(item_id, [item_id])[0])


func item_info(item_id: String) -> Array:
	return ITEMS.get(item_id, [item_id, "", CyberIcon.Kind.DIAMOND, Color.WHITE])


## Missão que dá este item ("" se não vem de missão).
func source_mission(item_id: String) -> String:
	for mission_id in MISSION_REWARDS.keys():
		if MISSION_REWARDS[mission_id] == item_id:
			return String(mission_id)
	return ""


## Adiciona um item que não vem de missão (ex.: achado num prédio).
func add_item(item_id: String) -> bool:
	if not ITEMS.has(item_id) or has_item(item_id):
		return false
	_extra.append(item_id)
	_announce(item_id)
	return true


func _on_mission_completed(mission_id: String) -> void:
	var item_id: String = String(MISSION_REWARDS.get(mission_id, ""))
	# O aviso vem junto da mensagem de "missão concluída" (PhoneManager.gd).
	if item_id != "":
		item_added.emit(item_id)


func _announce(item_id: String) -> void:
	item_added.emit(item_id)
	HUD.show_notice("Item na mochila", "%s — veja no app Mochila do celular." % item_name(item_id))
