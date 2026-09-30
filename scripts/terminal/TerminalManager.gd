extends CanvasLayer
## TerminalManager.gd
## Autoload que controla o terminal fictício do jogo (CYBER-OS).
## Todos os comandos são interpretados aqui mesmo, dentro do jogo —
## nada disso executa comandos reais do sistema operacional.

@onready var output: RichTextLabel = $Monitor/Panel/Output
@onready var input_line: LineEdit = $Monitor/Panel/InputRow/InputLine
@onready var monitor: Panel = $Monitor

## "Sistema de arquivos" simulado. Cada terminal (por enquanto) vê os
## mesmos arquivos fictícios — dá pra tornar isso específico por
## computador/missão nas próximas fases.
const VIRTUAL_FILES := {
	"readme.txt": "Bem-vindo ao CYBER-OS.\nDigite 'help' para ver os comandos disponíveis.",
	"email_suspeito.eml": "De: suporte@empresaa-seguranca.com\nAssunto: URGENTE!!!\nMensagem: Clique imediatamente no link para nao perder o acesso a sua conta.\n\n(Isso te parece confiável? Vale desconfiar de remetentes estranhos e mensagens com urgência forçada.)",
}

var _active: bool = false
var _command_history: PackedStringArray = PackedStringArray()
var _history_index: int = -1

## Desafio educativo associado ao computador que abriu este terminal
## (vazio quando o computador não tem desafio nenhum).
var _challenge_id: String = ""
var _challenge: Dictionary = {}

## Estado do desafio de firewall em andamento: porta (int) -> "allow"/"block".
var _firewall_rules: Dictionary = {}


func _ready() -> void:
	visible = false
	input_line.keep_editing_on_text_submit = true
	input_line.text_submitted.connect(_on_command_submitted)


func open(challenge_id: String = "") -> void:
	_challenge_id = challenge_id
	_challenge = ChallengeData.get_challenge(challenge_id)
	_firewall_rules = {}
	_active = true
	visible = true
	monitor.modulate.a = 0.0
	var tween: Tween = create_tween()
	tween.tween_property(monitor, "modulate:a", 1.0, 0.15)
	output.clear()
	_print_line("CYBER-OS TERMINAL v1.0")
	_print_line("Digite 'help' para ver os comandos disponíveis.")
	_print_line(_challenge_hint())
	_print_line("")
	input_line.text = ""
	# Deferido: o foco só "gruda" depois que o painel realmente ficou visível.
	input_line.call_deferred("grab_focus")


## Mensagem mostrada ao abrir o terminal, que muda conforme o tipo de
## desafio associado a este computador (quiz, rede ou firewall).
func _challenge_hint() -> String:
	if _challenge.is_empty():
		return ""

	var intro := ""
	match String(_challenge.get("type", "")):
		"quiz":
			intro = "Um desafio de segurança está disponível: digite 'desafio'."
		"network":
			intro = "Rede local detectada. Digite 'scan' para mapear os dispositivos."
		"firewall":
			intro = "Conexões pendentes de análise. Digite 'firewall status' para ver."
		"logs":
			intro = "Registro de acessos disponível. Digite 'logs' para consultar."
		"sqli":
			intro = "Formulário de login simulado. Digite 'login <algo>' para testar."
		"xss":
			intro = "Campo de comentário simulado. Digite 'postar <mensagem>' para testar."

	if intro != "" and _challenge.has("hint"):
		intro += " Travou? Digite 'dica'."
	return intro


func close() -> void:
	_active = false
	visible = false
	input_line.release_focus()


func is_active() -> bool:
	return _active


## Rede de segurança extra: a cada frame com o terminal aberto, garante
## que o campo de texto está com o foco. Cobre qualquer caso em que o
## foco se perca (não só logo após enviar um comando).
func _process(_delta: float) -> void:
	if _active and not input_line.has_focus():
		input_line.grab_focus()


func _on_command_submitted(text: String) -> void:
	SoundManager.play("keypress")
	var command := text.strip_edges()
	input_line.text = ""

	if command == "":
		_keep_focus()
		return

	_command_history.append(command)
	_history_index = _command_history.size()

	_print_line("user@cybercity:~$ " + command)
	_run_command(command)
	_keep_focus()


## Devolve o foco ao campo de texto para o jogador poder continuar
## digitando sem precisar clicar no terminal de novo a cada comando.
## É deferido porque o LineEdit perde o foco no mesmo frame em que
## o comando é enviado.
func _keep_focus() -> void:
	if _active:
		input_line.call_deferred("grab_focus")


func _run_command(command: String) -> void:
	var parts: PackedStringArray = command.split(" ", false)
	if parts.is_empty():
		return

	var cmd: String = parts[0].to_lower()
	var args: PackedStringArray = PackedStringArray()
	for i in range(1, parts.size()):
		args.append(parts[i])

	# Para comandos que recebem texto livre (pode ter espaços/aspas),
	# reconstrói tudo que vem depois da primeira palavra sem quebrar em tokens.
	var first_space: int = command.find(" ")
	var rest: String = "" if first_space == -1 else command.substr(first_space + 1).strip_edges()

	match cmd:
		"help":
			_cmd_help()
		"clear":
			_cmd_clear()
		"files":
			_cmd_files()
		"read":
			_cmd_read(args)
		"desafio":
			_cmd_desafio()
		"dica":
			_cmd_dica()
		"scan":
			_cmd_scan()
		"connect":
			_cmd_connect(args)
		"firewall":
			_cmd_firewall(args)
		"logs":
			_cmd_logs()
		"report":
			_cmd_report(args)
		"login":
			_cmd_login(rest)
		"postar":
			_cmd_postar(rest)
		"exit", "sair":
			close()
		_:
			_print_line("Comando não reconhecido: " + cmd)
			_print_line("Digite 'help' para ver os comandos disponíveis.")


func _cmd_help() -> void:
	_print_line("Comandos disponíveis:")
	_print_line("  help            - mostra esta lista")
	_print_line("  clear           - limpa a tela")
	_print_line("  files           - lista os arquivos deste sistema")
	_print_line("  read <arquivo>  - mostra o conteúdo de um arquivo")
	var challenge_type: String = String(_challenge.get("type", ""))
	if challenge_type == "quiz":
		_print_line("  desafio             - inicia o desafio de segurança deste sistema")
	elif challenge_type == "network":
		_print_line("  scan                - mapeia os dispositivos da rede local")
		_print_line("  connect <ip>        - conecta a um dispositivo da rede")
	elif challenge_type == "firewall":
		_print_line("  firewall status     - lista as conexões pendentes de análise")
		_print_line("  firewall allow <p>  - libera a porta <p>")
		_print_line("  firewall block <p>  - bloqueia a porta <p>")
	elif challenge_type == "logs":
		_print_line("  logs                - mostra o registro de acessos")
		_print_line("  report <linha>      - aponta a linha suspeita")
	elif challenge_type == "sqli":
		_print_line("  login <senha>       - tenta autenticar no sistema simulado")
	elif challenge_type == "xss":
		_print_line("  postar <mensagem>   - publica um comentário no sistema simulado")
	if _challenge.has("hint"):
		_print_line("  dica                - mostra uma dica pra este desafio")
	_print_line("  exit            - fecha o terminal")


func _cmd_dica() -> void:
	if not _challenge.has("hint"):
		_print_line("Nenhuma dica disponível neste sistema.")
		return
	SoundManager.play("blip")
	_print_line("💡 Dica: " + String(_challenge["hint"]))


func _cmd_desafio() -> void:
	if String(_challenge.get("type", "")) != "quiz":
		_print_line("Nenhum desafio disponível neste sistema.")
		return
	close()
	ChallengeManager.start(_challenge_id)


## --- Desafio de rede (scan / connect) -------------------------------

func _cmd_scan() -> void:
	if String(_challenge.get("type", "")) != "network":
		_print_line("Comando não disponível neste sistema.")
		return

	_print_line("Escaneando rede local...")
	_print_line("")
	var devices: Dictionary = _challenge["devices"]
	var found_suspicious := false
	for ip in devices.keys():
		var device: Dictionary = devices[ip]
		_print_line("%s\t%s" % [String(ip), String(device["name"])])
		if bool(device["suspicious"]):
			found_suspicious = true

	_print_line("")
	if found_suspicious:
		_print_line("Dispositivo suspeito detectado. Use 'connect <ip>' para investigar.")


func _cmd_connect(args: PackedStringArray) -> void:
	if String(_challenge.get("type", "")) != "network":
		_print_line("Comando não disponível neste sistema.")
		return
	if args.is_empty():
		_print_line("Uso: connect <ip>")
		return

	var ip: String = args[0]
	var devices: Dictionary = _challenge["devices"]
	if not devices.has(ip):
		_print_line("Host inacessível: " + ip)
		return

	var device: Dictionary = devices[ip]
	_print_line("Conectando a %s (%s)..." % [ip, String(device["name"])])
	_print_line(String(device["info"]))

	if ip == String(_challenge["correct_ip"]) and MissionManager.is_active(String(_challenge["mission"])):
		_print_line("")
		_print_line(">> Objetivo cumprido: dispositivo suspeito identificado.")
		var mission_id: String = String(_challenge["mission"])
		close()
		MissionManager.complete_mission(mission_id)


## --- Desafio de firewall (status / allow / block) -------------------

func _cmd_firewall(args: PackedStringArray) -> void:
	if String(_challenge.get("type", "")) != "firewall":
		_print_line("Comando não disponível neste sistema.")
		return
	if args.is_empty():
		_print_line("Uso: firewall status | firewall allow <porta> | firewall block <porta>")
		return

	var sub: String = args[0].to_lower()
	if sub == "status":
		_print_firewall_status()
	elif sub == "allow" or sub == "block":
		_set_firewall_rule(args, sub)
	else:
		_print_line("Subcomando desconhecido: " + sub)


func _print_firewall_status() -> void:
	_print_line("Conexões pendentes de análise:")
	_print_line("")
	var connections: Array = _challenge["connections"]
	for entry in connections:
		var port: int = int(entry["port"])
		var current_rule: String = String(_firewall_rules.get(port, "???"))
		_print_line("  porta %d  -  %s  [%s]" % [port, String(entry["service"]), current_rule])
	_print_line("")
	_print_line("Use 'firewall allow <porta>' ou 'firewall block <porta>' para cada uma.")


func _set_firewall_rule(args: PackedStringArray, action: String) -> void:
	if args.size() < 2 or not args[1].is_valid_int():
		_print_line("Uso: firewall %s <porta>" % action)
		return

	var port: int = int(args[1])
	var connections: Array = _challenge["connections"]
	var known := false
	for entry in connections:
		if int(entry["port"]) == port:
			known = true
			break

	if not known:
		_print_line("Porta %d não está na lista de conexões pendentes." % port)
		return

	_firewall_rules[port] = action
	_print_line("Porta %d agora está: %s" % [port, action])
	_check_firewall_complete()


func _check_firewall_complete() -> void:
	var connections: Array = _challenge["connections"]
	for entry in connections:
		var port: int = int(entry["port"])
		var recommended: String = String(entry["recommended"])
		if String(_firewall_rules.get(port, "")) != recommended:
			return

	# Todas as portas receberam a regra correta.
	_print_line("")
	_print_line(">> Objetivo cumprido: firewall configurado corretamente.")
	var mission_id: String = String(_challenge["mission"])
	close()
	MissionManager.complete_mission(mission_id)


## --- Desafio de logs (logs / report) ---------------------------------

func _cmd_logs() -> void:
	if String(_challenge.get("type", "")) != "logs":
		_print_line("Comando não disponível neste sistema.")
		return

	_print_line("Registro de acessos:")
	_print_line("")
	var entries: Array = _challenge["entries"]
	for entry in entries:
		_print_line("[%d] %s  %s" % [int(entry["line"]), String(entry["time"]), String(entry["text"])])
	_print_line("")
	_print_line("Use 'report <linha>' para apontar o que parece suspeito.")


func _cmd_report(args: PackedStringArray) -> void:
	if String(_challenge.get("type", "")) != "logs":
		_print_line("Comando não disponível neste sistema.")
		return
	if args.is_empty() or not args[0].is_valid_int():
		_print_line("Uso: report <linha>")
		return

	var line: int = int(args[0])
	if line == int(_challenge["correct_line"]):
		_print_line(">> Objetivo cumprido: comportamento suspeito identificado.")
		var mission_id: String = String(_challenge["mission"])
		close()
		MissionManager.complete_mission(mission_id)
	else:
		SoundManager.play("error")
		_print_line("Essa linha, sozinha, não é o problema. Olhe o padrão ao redor dela — o que aconteceu antes?")


## --- Laboratório fictício de SQL Injection ---------------------------

func _cmd_login(senha: String) -> void:
	if String(_challenge.get("type", "")) != "sqli":
		_print_line("Comando não disponível neste sistema.")
		return
	if senha == "":
		_print_line("Uso: login <senha>")
		return

	_print_line('Tentando autenticar com: "%s"' % senha)

	if _looks_like_sqli_bypass(senha):
		_print_line("Login aceito. O sistema autenticou sem validar a senha real!")
		_print_line("")
		_print_line(">> Objetivo cumprido: vulnerabilidade de SQL Injection explorada.")
		var mission_id: String = String(_challenge["mission"])
		close()
		MissionManager.complete_mission(mission_id)
	else:
		SoundManager.play("error")
		_print_line("Acesso negado.")
		_print_line("Dica: pense numa entrada que faça a condição da consulta virar sempre verdadeira.")


## Checagem simples e proposital (isto é uma simulação de texto, não um
## interpretador de SQL de verdade): aceita entradas clássicas de
## SQL Injection do tipo "sempre verdadeiro".
func _looks_like_sqli_bypass(senha: String) -> bool:
	var s: String = senha.to_lower()
	var has_quote: bool = s.find("'") != -1
	var has_or: bool = s.find(" or ") != -1 or s.find("'or'") != -1
	var always_true: bool = s.find("1=1") != -1 or s.find("1='1") != -1 or s.find("'1'='1") != -1
	return has_quote and has_or and always_true


## --- Laboratório fictício de XSS --------------------------------------

func _cmd_postar(mensagem: String) -> void:
	if String(_challenge.get("type", "")) != "xss":
		_print_line("Comando não disponível neste sistema.")
		return
	if mensagem == "":
		_print_line("Uso: postar <mensagem>")
		return

	if mensagem.to_lower().find("<script") != -1:
		_print_line("Comentário publicado sem nenhum tratamento:")
		_print_line("  " + mensagem)
		_print_line("")
		_print_line("Como o site não trata o que o usuário digita, esse <script> rodaria")
		_print_line("de verdade no navegador de quem lesse o comentário.")
		_print_line("")
		_print_line(">> Objetivo cumprido: vulnerabilidade de XSS demonstrada.")
		var mission_id: String = String(_challenge["mission"])
		close()
		MissionManager.complete_mission(mission_id)
	else:
		_print_line("Comentário publicado: " + mensagem)
		_print_line("(Nada de especial aconteceu. Tente algo que pareça código.)")


func _cmd_clear() -> void:
	output.clear()


func _cmd_files() -> void:
	_print_line("Arquivos encontrados:")
	for filename in VIRTUAL_FILES.keys():
		_print_line("  " + filename)


func _cmd_read(args: PackedStringArray) -> void:
	if args.is_empty():
		_print_line("Uso: read <arquivo>")
		return

	var filename: String = args[0]
	if VIRTUAL_FILES.has(filename):
		_print_line(VIRTUAL_FILES[filename])
		_check_mission_progress(filename)
	else:
		_print_line("Arquivo não encontrado: " + filename)


## Ler o e-mail suspeito é o objetivo da Missão 01 — ao ler, a missão
## é concluída (o jogador ganha XP e vê a explicação do conceito).
func _check_mission_progress(filename: String) -> void:
	if filename == "email_suspeito.eml" and MissionManager.is_active("m01"):
		_print_line("")
		_print_line(">> Objetivo cumprido: e-mail analisado.")
		close()
		MissionManager.complete_mission("m01")


func _print_line(text: String) -> void:
	output.append_text(text + "\n")


func _unhandled_input(event: InputEvent) -> void:
	if not _active:
		return
	if not (event is InputEventKey) or not event.pressed:
		return

	if event.keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_UP:
		_history_prev()
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_DOWN:
		_history_next()
		get_viewport().set_input_as_handled()
	else:
		# Rede de segurança: se o foco tiver se perdido por qualquer
		# motivo, qualquer tecla digitada devolve o foco ao campo.
		_keep_focus()


func _history_prev() -> void:
	if _command_history.is_empty():
		return
	_history_index = max(0, _history_index - 1)
	input_line.text = _command_history[_history_index]
	input_line.caret_column = input_line.text.length()


func _history_next() -> void:
	if _command_history.is_empty():
		return
	_history_index = min(_command_history.size(), _history_index + 1)
	if _history_index >= _command_history.size():
		input_line.text = ""
	else:
		input_line.text = _command_history[_history_index]
	input_line.caret_column = input_line.text.length()
