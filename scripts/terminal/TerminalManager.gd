extends CanvasLayer
## TerminalManager.gd
## Autoload que controla o terminal fictício do jogo (CYBER-OS).
## Todos os comandos são interpretados aqui mesmo, dentro do jogo —
## nada disso executa comandos reais do sistema operacional.
##
## Visual inspirado no terminal do Kali Linux: janela com barra de título,
## prompt de duas linhas (┌──(kali㉿host)-[~] / └─$), texto verde,
## "digitação" animada das respostas e efeito de monitor CRT.

## Cores (formato BBCode do RichTextLabel).
const C_GREEN := "#3dff6e"
const C_BLUE := "#2f8cff"
const C_WHITE := "#e8ece9"
const C_RED := "#ff5f5f"
const C_YELLOW := "#ffd75f"
const C_DIM := "#5f8f6a"

## Velocidade do efeito de "digitação" das respostas (caracteres/segundo).
const TYPE_SPEED := 1100.0

@onready var output: RichTextLabel = $Monitor/Body/Output
@onready var input_line: LineEdit = $Monitor/Body/InputRow/InputLine
@onready var prompt_top: RichTextLabel = $Monitor/Body/PromptTop
@onready var prompt_label: RichTextLabel = $Monitor/Body/InputRow/PromptLabel
@onready var title_label: Label = $Monitor/TitleBar/TitleLabel
@onready var close_button: Button = $Monitor/TitleBar/WindowButtons/CloseButton
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

## Nome da máquina mostrado no prompt (kali㉿<host>).
var _host: String = "cybercity"
## Acumulador do efeito de digitação (frações de caractere por frame).
var _type_progress: float = 0.0


func _ready() -> void:
	visible = false
	input_line.keep_editing_on_text_submit = true
	input_line.text_submitted.connect(_on_command_submitted)
	close_button.pressed.connect(close)


## Abre o terminal. "host" é o nome da máquina no prompt (ex.: "estacao1").
func open(challenge_id: String = "", host: String = "cybercity") -> void:
	_challenge_id = challenge_id
	_challenge = ChallengeData.get_challenge(challenge_id)
	# Abrir o computador de um desafio aceita a missão ligada a ele.
	if not _challenge.is_empty():
		ChallengeSession.begin(challenge_id)
	_firewall_rules = {}
	_host = host
	_active = true
	visible = true
	title_label.text = "kali@%s: ~" % _host
	prompt_top.text = _prompt_top_bbcode()
	prompt_label.text = _prompt_bottom_bbcode()

	# A janela "abre" crescendo um pouco, como num desktop.
	monitor.modulate.a = 0.0
	monitor.scale = Vector2(0.96, 0.96)
	var tween: Tween = create_tween().set_parallel()
	tween.tween_property(monitor, "modulate:a", 1.0, 0.15)
	tween.tween_property(monitor, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	SoundManager.play("blip")

	output.clear()
	output.visible_characters = 0
	_type_progress = 0.0
	_print_boot()
	var hint := _challenge_hint()
	if hint != "":
		_print_rich("[color=%s][[/color][color=%s]*[/color][color=%s]] [/color]%s" % [C_BLUE, C_YELLOW, C_BLUE, _escape(hint)])
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


## Mensagens de "inicialização" mostradas a cada vez que o terminal abre.
func _print_boot() -> void:
	var ok := "[color=%s][  [/color][color=%s]OK[/color][color=%s]  ][/color] " % [C_WHITE, C_GREEN, C_WHITE]
	_print_rich(ok + "Montando sistema de arquivos virtual")
	_print_rich(ok + "Conectando à rede da Cyber City")
	_print_rich(ok + "Carregando ferramentas de análise")
	_print_rich("")
	for line in [
		"  ______   ______  ___________     ____  _____",
		" / ___\\ \\ / / __ )| ____|  _ \\   / __ \\/ ___/",
		"| |    \\ V /|  _ \\|  _| | |_) | | |  | \\___ \\",
		"| |___  | | | |_) | |___|  _ <  | |__| |___) |",
		" \\____| |_| |____/|_____|_| \\_\\  \\____/|____/",
	]:
		_print_rich("[color=%s][b]%s[/b][/color]" % [C_BLUE, _escape(line)])
	_print_rich("")
	_print_rich("[color=%s]CYBER-OS 2026.4 (ambiente de treino simulado) — host: %s[/color]" % [C_DIM, _escape(_host)])
	_print_line("Digite 'help' para ver os comandos disponíveis.")


func _prompt_top_bbcode() -> String:
	return "[color=%s]┌──([/color][b][color=%s]kali㉿%s[/color][/b][color=%s])-[lb][/color][b][color=%s]~[/color][/b][color=%s][rb][/color]" % [
		C_GREEN, C_BLUE, _escape(_host), C_GREEN, C_WHITE, C_GREEN]


func _prompt_bottom_bbcode() -> String:
	return "[color=%s]└─[/color][b][color=%s]$[/color][/b] " % [C_GREEN, C_BLUE]


func close() -> void:
	_active = false
	visible = false
	input_line.release_focus()


func is_active() -> bool:
	return _active


## Rede de segurança extra: a cada frame com o terminal aberto, garante
## que o campo de texto está com o foco. Cobre qualquer caso em que o
## foco se perca (não só logo após enviar um comando).
func _process(delta: float) -> void:
	if _active and not input_line.has_focus():
		input_line.grab_focus()
	_advance_typing(delta)


## Efeito de "digitação": o texto já está no RichTextLabel, mas só uma
## parte fica visível (visible_characters), aumentando a cada frame.
func _advance_typing(delta: float) -> void:
	if output.visible_characters < 0:
		return
	_type_progress += TYPE_SPEED * delta
	var step := int(_type_progress)
	_type_progress -= step
	output.visible_characters += step
	if output.visible_characters >= output.get_total_character_count():
		output.visible_characters = -1


func _on_command_submitted(text: String) -> void:
	SoundManager.play("keypress")
	var command := text.strip_edges()
	input_line.text = ""

	if command == "":
		_keep_focus()
		return

	_command_history.append(command)
	_history_index = _command_history.size()

	# Repete o prompt de duas linhas com o comando digitado, como no Kali.
	_print_rich(_prompt_top_bbcode())
	_print_rich(_prompt_bottom_bbcode() + "[color=%s]%s[/color]" % [C_WHITE, _escape(command)])
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
		"files", "ls":
			_cmd_files()
		"read", "cat":
			_cmd_read(args)
		"whoami":
			_print_line("kali")
		"pwd":
			_print_line("/home/kali")
		"hostname":
			_print_line(_host)
		"date":
			_print_line(Time.get_datetime_string_from_system().replace("T", " "))
		"uname":
			_print_line("CyberOS %s 6.6.0-cyber-amd64 #1 SMP Debian x86_64 GNU/Linux (simulado)" % _host)
		"echo":
			_print_line(rest)
		"history":
			_cmd_history()
		"neofetch", "fastfetch":
			_cmd_neofetch()
		"ifconfig", "ip":
			_cmd_ifconfig()
		"sudo":
			_print_error("[sudo] acesso negado: este é um ambiente de treino. Nada aqui roda de verdade ;)")
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
			_print_error("zsh: comando não encontrado: " + cmd)
			_print_rich("[color=%s]Digite 'help' para ver os comandos disponíveis.[/color]" % C_DIM)


func _cmd_help() -> void:
	_print_rich("[color=%s][b]Comandos disponíveis:[/b][/color]" % C_WHITE)
	_print_line("  help                - mostra esta lista")
	_print_line("  clear               - limpa a tela")
	_print_line("  ls / files          - lista os arquivos deste sistema")
	_print_line("  cat / read <arq>    - mostra o conteúdo de um arquivo")
	_print_line("  whoami, pwd, date   - informações do usuário e do sistema")
	_print_line("  neofetch, ifconfig  - resumo do sistema e da rede")
	_print_line("  history             - comandos digitados nesta sessão")
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
	_print_line("  exit                - fecha o terminal")


func _cmd_dica() -> void:
	if not _challenge.has("hint"):
		_print_line("Nenhuma dica disponível neste sistema.")
		return
	SoundManager.play("blip")
	_print_rich("[color=%s][lb]*[rb] Dica:[/color] %s" % [C_YELLOW, _escape(String(_challenge["hint"]))])


func _cmd_desafio() -> void:
	if String(_challenge.get("type", "")) != "quiz":
		_print_line("Nenhum desafio disponível neste sistema.")
		return
	close()
	ChallengeManager.start(_challenge_id)


## --- Desafio de rede (scan / connect) -------------------------------

func _cmd_scan() -> void:
	if String(_challenge.get("type", "")) != "network":
		_print_error("Comando não disponível neste sistema.")
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
		_print_error("Comando não disponível neste sistema.")
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

	# Conectar num dispositivo normal é exploração, não conta como erro.
	if ip == String(_challenge["correct_ip"]):
		ChallengeSession.record_attempt(_challenge_id, true)
		_print_line("")
		_finish_challenge("Objetivo cumprido: dispositivo suspeito identificado.")


## --- Desafio de firewall (status / allow / block) -------------------

func _cmd_firewall(args: PackedStringArray) -> void:
	if String(_challenge.get("type", "")) != "firewall":
		_print_error("Comando não disponível neste sistema.")
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
	ChallengeSession.record_attempt(_challenge_id, true)
	_print_line("")
	_finish_challenge("Objetivo cumprido: firewall configurado corretamente.")


## --- Desafio de logs (logs / report) ---------------------------------

func _cmd_logs() -> void:
	if String(_challenge.get("type", "")) != "logs":
		_print_error("Comando não disponível neste sistema.")
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
		_print_error("Comando não disponível neste sistema.")
		return
	if args.is_empty() or not args[0].is_valid_int():
		_print_line("Uso: report <linha>")
		return

	var line: int = int(args[0])
	if line == int(_challenge["correct_line"]):
		ChallengeSession.record_attempt(_challenge_id, true)
		_finish_challenge("Objetivo cumprido: comportamento suspeito identificado.")
	else:
		ChallengeSession.record_attempt(_challenge_id, false)
		SoundManager.play("error")
		_print_line("Essa linha, sozinha, não é o problema. Olhe o padrão ao redor dela — o que aconteceu antes?")


## --- Laboratório fictício de SQL Injection ---------------------------

func _cmd_login(senha: String) -> void:
	if String(_challenge.get("type", "")) != "sqli":
		_print_error("Comando não disponível neste sistema.")
		return
	if senha == "":
		_print_line("Uso: login <senha>")
		return

	_print_line('Tentando autenticar com: "%s"' % senha)

	if _looks_like_sqli_bypass(senha):
		_print_line("Login aceito. O sistema autenticou sem validar a senha real!")
		_print_line("")
		ChallengeSession.record_attempt(_challenge_id, true)
		_finish_challenge("Objetivo cumprido: vulnerabilidade de SQL Injection explorada.")
	else:
		ChallengeSession.record_attempt(_challenge_id, false)
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
		_print_error("Comando não disponível neste sistema.")
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
		ChallengeSession.record_attempt(_challenge_id, true)
		_finish_challenge("Objetivo cumprido: vulnerabilidade de XSS demonstrada.")
	else:
		# Um comentário comum é uso normal do sistema, não conta como erro.
		_print_line("Comentário publicado: " + mensagem)
		_print_line("(Nada de especial aconteceu. Tente algo que pareça código.)")


func _cmd_clear() -> void:
	output.clear()
	output.visible_characters = 0


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
		_print_error("cat: " + filename + ": arquivo não encontrado")


## Conclui o desafio deste computador. Centraliza o que antes se repetia em
## cada tipo de desafio: mostrar o sucesso, fechar o terminal e entregar a
## missão (XP, conceito e explicação). Se o desafio já foi concluído antes,
## só avisa e não entrega nada de novo.
func _finish_challenge(success_message: String) -> void:
	if ChallengeSession.is_completed(_challenge_id):
		_print_rich("[color=%s]Este desafio já foi concluído antes (sem XP novo).[/color]" % C_DIM)
		return
	_print_success(success_message)
	close()
	ChallengeSession.complete(_challenge_id)


## Ler o e-mail suspeito é o objetivo da Missão 01 — ao ler, a missão
## é concluída (o jogador ganha XP e vê a explicação do conceito).
func _check_mission_progress(filename: String) -> void:
	if filename == "email_suspeito.eml" and MissionManager.is_active("m01"):
		_print_line("")
		_print_success("Objetivo cumprido: e-mail analisado.")
		close()
		MissionManager.complete_mission("m01")


## Escreve uma linha de texto comum (verde). Colchetes digitados pelo
## jogador são "escapados" para não virarem códigos BBCode.
func _print_line(text: String) -> void:
	_print_rich(_escape(text))


func _print_success(text: String) -> void:
	_print_rich("[color=%s][b][lb]+[rb] %s[/b][/color]" % [C_GREEN, _escape(text)])


func _print_error(text: String) -> void:
	_print_rich("[color=%s]%s[/color]" % [C_RED, _escape(text)])


## Escreve uma linha já formatada em BBCode. O texto novo começa
## invisível e aparece aos poucos (_advance_typing).
func _print_rich(bbcode: String) -> void:
	if output.visible_characters < 0:
		output.visible_characters = output.get_total_character_count()
	output.append_text(bbcode + "\n")


func _escape(text: String) -> String:
	return text.replace("[", "[lb]")


func _cmd_history() -> void:
	for i in range(_command_history.size()):
		_print_line("%5d  %s" % [i + 1, _command_history[i]])


func _cmd_neofetch() -> void:
	var art := [
		"      .--.      ",
		"     |o_o |     ",
		"     |:_/ |     ",
		"    //   \\ \\    ",
		"   (|     | )   ",
		"  /'\\_   _/`\\  ",
		"  \\___)=(___/  ",
	]
	var info := [
		"[color=%s][b]kali[/b][/color]@[color=%s][b]%s[/b][/color]" % [C_BLUE, C_BLUE, _escape(_host)],
		"------------------",
		"[color=%s]OS:[/color] CyberOS 2026.4 (simulado)" % C_BLUE,
		"[color=%s]Shell:[/color] zsh 5.9" % C_BLUE,
		"[color=%s]Terminal:[/color] qterminal" % C_BLUE,
		"[color=%s]Nível:[/color] %d   [color=%s]XP:[/color] %d" % [C_BLUE, GameManager.level, C_BLUE, GameManager.total_xp_earned],
		"[color=%s]Missões concluídas:[/color] %d" % [C_BLUE, _completed_mission_count()],
	]
	for i in range(art.size()):
		var right: String = info[i] if i < info.size() else ""
		_print_rich("[color=%s]%s[/color]  %s" % [C_GREEN, _escape(art[i]), right])


func _completed_mission_count() -> int:
	var count := 0
	for mission in MissionManager.missions.values():
		if mission["state"] == MissionManager.State.COMPLETED:
			count += 1
	return count


func _cmd_ifconfig() -> void:
	_print_rich("[color=%s][b]eth0[/b][/color]: flags=4163<UP,BROADCAST,RUNNING,MULTICAST>  mtu 1500" % C_WHITE)
	_print_line("        inet 192.168.1.%d  netmask 255.255.255.0  broadcast 192.168.1.255" % (100 + absi(_host.hash()) % 100))
	_print_line("        ether 08:00:27:%02x:%02x:%02x  (simulado)" % [absi(_host.hash()) % 256, 0x1c, 0xa7])
	_print_rich("[color=%s][b]lo[/b][/color]: flags=73<UP,LOOPBACK,RUNNING>  mtu 65536" % C_WHITE)
	_print_line("        inet 127.0.0.1  netmask 255.0.0.0")


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
