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

## Desafio do roteador: true depois que o jogador entrou no painel.
var _router_logged_in: bool = false

## Desafio de evidências: índices (em "targets") dos indícios já reportados.
var _report_found: Array = []

## Máquinas simuladas do desafio ("hosts"): em qual o jogador está, de onde
## veio e por onde passou. Ver HostSim.gd.
const HostSim := preload("res://scripts/terminal/HostSim.gd")
var _sim := HostSim.new()

## ssh esperando a senha: {"user": ..., "host": ...}. Vazio = nenhum.
var _ssh_pending: Dictionary = {}

## Desafio "hosts": true depois que o jogador leu o arquivo-objetivo (a flag).
var _flag_captured: bool = false

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
	_router_logged_in = false
	_report_found = []
	_sim.setup(_challenge)
	_ssh_pending = {}
	_flag_captured = false
	input_line.secret = false
	_host = host
	_active = true
	visible = true
	_refresh_prompt()

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
		"router":
			intro = "Roteador doméstico detectado. Digite 'files' e leia o manual com 'read manual.txt'."
		"report", "hosts":
			intro = String(_challenge.get("intro", ""))

	# Quanto o terminal explica depende do nível de guia do desafio.
	var guidance: int = _guidance()
	if guidance >= 3:
		return ""
	if guidance == 2:
		intro = "Computador aberto. Digite 'ls' para ver os arquivos e 'help' para ver os comandos."

	if intro != "" and not PhoneManager.get_all_clues(_hint_mission_id()).is_empty():
		intro += " Travou? Digite 'dica'."
	return intro


## Nível de guia do desafio ("guidance" no ChallengeData, padrão 1):
##   1 - o terminal diz o que o computador tem e quais comandos usar
##   2 - só diz que o computador está aberto
##   3 - não explica nada (nem a abertura, nem a lista de comandos do
##       desafio, nem a lista do 'report'); a ajuda vem só pelas dicas
func _guidance() -> int:
	return clampi(int(_challenge.get("guidance", 1)), 1, 3)


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
	return "[color=%s]┌──([/color][b][color=%s]%s㉿%s[/color][/b][color=%s])-[lb][/color][b][color=%s]~[/color][/b][color=%s][rb][/color]" % [
		C_GREEN, C_BLUE, _escape(_sim.current_user), _escape(_shown_host()), C_GREEN, C_WHITE, C_GREEN]


## Nome da máquina que aparece no prompt: a remota (depois de um ssh) ou a
## local, onde o terminal foi aberto.
func _shown_host() -> String:
	return _sim.current_host if _sim.is_remote() else _host


## Atualiza a barra de título e o prompt (ao abrir e a cada ssh/exit).
func _refresh_prompt() -> void:
	title_label.text = "%s@%s: ~" % [_sim.current_user, _shown_host()]
	prompt_top.text = _prompt_top_bbcode()
	prompt_label.text = _prompt_bottom_bbcode()


func _prompt_bottom_bbcode() -> String:
	return "[color=%s]└─[/color][b][color=%s]$[/color][/b] " % [C_GREEN, C_BLUE]


func close() -> void:
	_active = false
	visible = false
	_ssh_pending = {}
	input_line.secret = false
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
	input_line.text = ""

	# Depois de 'ssh', a próxima linha é a senha (não vai para o histórico
	# nem aparece na tela).
	if not _ssh_pending.is_empty():
		_handle_ssh_password(text)
		_keep_focus()
		return

	var command := text.strip_edges()

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
			_cmd_files(args)
		"read", "cat":
			_cmd_read(args)
		"grep":
			_cmd_grep(args)
		"whoami":
			_print_line(_sim.current_user)
		"pwd":
			_print_line("/home/" + _sim.current_user)
		"hostname":
			_print_line(_shown_host())
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
		"dica", "dicas":
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
		"passwd":
			_cmd_passwd(rest)
		"ssh":
			_cmd_ssh(args)
		"curl":
			_cmd_curl(args)
		"relatorio", "relatório":
			_cmd_relatorio()
		"exit", "sair", "logout":
			_cmd_exit()
		_:
			_print_error("zsh: comando não encontrado: " + cmd)
			_print_rich("[color=%s]Digite 'help' para ver os comandos disponíveis.[/color]" % C_DIM)


func _cmd_help() -> void:
	_print_rich("[color=%s][b]Comandos disponíveis:[/b][/color]" % C_WHITE)
	_print_line("  help                - mostra esta lista")
	_print_line("  clear               - limpa a tela")
	_print_line("  ls / files          - lista os arquivos deste sistema")
	_print_line("  cat / read <arq>    - mostra o conteúdo de um arquivo")
	_print_line("  grep <termo> <arq>  - mostra só as linhas do arquivo que têm o termo")
	_print_line("  whoami, pwd, date   - informações do usuário e do sistema")
	_print_line("  neofetch, ifconfig  - resumo do sistema e da rede")
	_print_line("  history             - comandos digitados nesta sessão")
	var challenge_type: String = String(_challenge.get("type", ""))
	if _guidance() >= 3:
		challenge_type = ""
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
	elif challenge_type == "router":
		_print_line("  login <usuário> <senha> - entra no painel do roteador")
		_print_line("  passwd <nova senha>     - troca a senha do painel (depois do login)")
	elif challenge_type == "report":
		_print_line("  report              - mostra o que você precisa achar neste desafio")
		_print_line("  report <achado>     - aponta, em poucas palavras, algo que você encontrou")
	if _sim.has_hosts() and _guidance() < 3:
		_print_line("  scan                - mapeia as máquinas da rede e suas portas")
		_print_line("  ssh <usuário>@<máquina> - entra em uma máquina (pede a senha)")
		_print_line("  curl <endereço>     - mostra o conteúdo de uma página web")
		if bool(_challenge.get("final_report", false)):
			_print_line("  relatorio           - entrega o relatório do teste (depois de cumprir o objetivo)")
	if not PhoneManager.get_all_clues(_hint_mission_id()).is_empty():
		_print_line("  dica                - revela a próxima dica da missão")
	_print_line("  exit                - sai da máquina atual (ou fecha o terminal)")


## Missão cujas dicas o comando 'dica' mostra neste computador: a do
## desafio, ou a m01 nos computadores das casas (que não têm desafio e onde
## ela é a única missão possível). "" se não houver missão em andamento.
func _hint_mission_id() -> String:
	var mission_id: String = String(_challenge.get("mission", ""))
	if mission_id != "":
		return mission_id
	if MissionManager.is_active("m01"):
		return "m01"
	return ""


func _cmd_dica() -> void:
	var mission_id: String = _hint_mission_id()
	var hints: PackedStringArray = PhoneManager.get_all_clues(mission_id)
	if mission_id == "" or hints.is_empty():
		_print_line("Nenhuma dica disponível neste sistema.")
		return
	SoundManager.play("blip")

	# As dicas são as mesmas do app Pistas do celular. Cada pedido revela a
	# próxima camada. Depois da última, cada pedido mostra todas de novo.
	var revealed_before: int = PhoneManager.get_revealed_clues(mission_id).size()
	var got_new: bool = PhoneManager.reveal_next_clue(mission_id)

	# Mostra o que já estava revelado (apagado) e a camada nova (amarelo).
	# Sem camada nova, todas aparecem em amarelo para o jogador reler.
	var revealed: PackedStringArray = PhoneManager.get_revealed_clues(mission_id)
	for i in range(revealed.size()):
		var is_new: bool = i >= revealed_before or not got_new
		var color: String = C_YELLOW if is_new else C_DIM
		_print_rich("[color=%s][lb]*[rb] Dica %d/%d:[/color] %s" % [color, i + 1, hints.size(), _escape(revealed[i])])
	if not got_new:
		_print_rich("[color=%s]Essas são todas as dicas deste desafio.[/color]" % C_DIM)


func _cmd_desafio() -> void:
	if String(_challenge.get("type", "")) != "quiz":
		_print_line("Nenhum desafio disponível neste sistema.")
		return
	close()
	ChallengeManager.start(_challenge_id)


## --- Desafio de rede (scan / connect) -------------------------------

func _cmd_scan() -> void:
	# 'scan' também serve aos desafios com máquinas simuladas ("hosts").
	if _sim.has_hosts():
		_print_line("Starting scan (simulado) ...")
		_print_line("%-15s %-10s %s" % ["ENDEREÇO", "MÁQUINA", "PORTAS ABERTAS"])
		for line in _sim.scan_lines():
			_print_line(line)
		return
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
	# 'report' existe em dois desafios: o de logs (número da linha) e o de
	# evidências (texto livre).
	if String(_challenge.get("type", "")) == "report":
		_cmd_report_evidence(" ".join(args))
		return
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
	# 'login' existe em dois desafios: o SQL Injection e o roteador.
	if String(_challenge.get("type", "")) == "router":
		_cmd_login_router(senha)
		return
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


## --- Desafio de evidências (report <indício>) ---------------------------
## O jogador lê os arquivos deste computador e aponta o que indica o problema.
## Cada alvo ("targets" no ChallengeData) tem palavras-chave, um "hit" (true =
## indício de verdade, false = isca que parece suspeita mas não prova nada) e a
## mensagem mostrada. O desafio termina ao reportar "required" indícios.

func _cmd_report_evidence(answer: String) -> void:
	# 'report' sozinho mostra o que falta achar, sem entregar as respostas.
	if answer.strip_edges() == "":
		_print_report_checklist()
		return

	var targets: Array = _challenge["targets"]
	var index: int = _find_report_target(answer, targets)
	if index == -1:
		# Palavra que não bate com nada: não conta como erro, só pede para reler.
		_print_line(String(_challenge.get("unknown_message", "Isso não bate com nada do material. Releia os arquivos e tente outro indício.")))
		if _guidance() < 3:
			_print_rich("[color=%s]Dica: digite 'report' sozinho para ver o que procurar.[/color]" % C_DIM)
		return

	var target: Dictionary = targets[index]
	if not bool(target.get("hit", false)):
		ChallengeSession.record_attempt(_challenge_id, false)
		SoundManager.play("error")
		_print_error(String(target["message"]))
		return
	if _report_found.has(index):
		_print_line("Você já reportou esse indício.")
		return

	_report_found.append(index)
	ChallengeSession.record_attempt(_challenge_id, true)
	var required: int = _report_required()
	_print_success(String(target["message"]))
	if _guidance() >= 3:
		_print_line("Indícios encontrados: %d" % _report_found.size())
	else:
		_print_line("Indícios encontrados: %d/%d" % [mini(_report_found.size(), required), required])
	if _report_found.size() >= required:
		_print_line("")
		_finish_challenge(String(_challenge.get("success_message", "Objetivo cumprido.")))
	elif _guidance() < 3:
		_print_rich("[color=%s]Digite 'report' sozinho para ver o que falta.[/color]" % C_DIM)


## Lista o que o jogador precisa achar, uma pergunta por indício verdadeiro
## ("label" no alvo), marcando os que já foram reportados. Não mostra as
## respostas, e as iscas não aparecem.
func _print_report_checklist() -> void:
	var required: int = _report_required()
	# Quanto a lista mostra depende do nível de guia (ver _guidance).
	if _guidance() >= 3:
		_print_line("Indícios reportados até agora: %d. Neste nível o terminal não diz o que procurar." % _report_found.size())
		return
	if _guidance() == 2:
		_print_line("Indícios reportados: %d de %d necessários." % [mini(_report_found.size(), required), required])
		return
	_print_rich("[color=%s][b]O que procurar[/b][/color] (precisa de %d de %d):" % [C_WHITE, required, _report_hits_total()])
	var number := 0
	for i in range(_challenge["targets"].size()):
		var target: Dictionary = _challenge["targets"][i]
		if not bool(target.get("hit", false)):
			continue
		number += 1
		var label: String = String(target.get("label", "Achado %d" % number))
		if _report_found.has(i):
			label = String(target.get("found_label", label))
			_print_rich("  [color=%s][lb]x[rb] %s[/color]" % [C_GREEN, _escape(label)])
		else:
			_print_rich("  [lb] [rb] %s" % _escape(label))
	_print_line(String(_challenge.get("report_help", "Escreva em poucas palavras o que achou: report <achado>. O jogo entende sinônimos; se não reconhecer, tente outra palavra.")))


func _report_hits_total() -> int:
	var hits := 0
	for target in _challenge["targets"]:
		if bool(target.get("hit", false)):
			hits += 1
	return hits


## Quantos indícios o jogador precisa reportar (padrão: todos os "hit").
func _report_required() -> int:
	return int(_challenge.get("required", _report_hits_total()))


## Acha o alvo cuja palavra-chave bate com o que o jogador digitou. Palavra
## curta (até 3 letras ou um número, como "2fa" ou "3") só vale se aparecer
## como palavra inteira no texto; as maiores valem se estiverem contidas
## nele. -1 se nenhum bater.
func _find_report_target(answer: String, targets: Array) -> int:
	var text: String = _fold(answer)
	var words: PackedStringArray = _split_words(text)
	for i in range(targets.size()):
		for keyword in targets[i]["keywords"]:
			var word: String = _fold(String(keyword))
			if word == text:
				return i
			if word.length() > 3:
				if text.contains(word):
					return i
			elif words.has(word):
				return i
	return -1


## Minúsculas e sem acentos, para "urgência" e "urgencia" serem a mesma coisa.
func _fold(text: String) -> String:
	var folded: String = text.strip_edges().to_lower()
	var map := {"á": "a", "à": "a", "â": "a", "ã": "a", "é": "e", "ê": "e", "í": "i", "ó": "o", "ô": "o", "õ": "o", "ú": "u", "ç": "c"}
	for accented in map.keys():
		folded = folded.replace(accented, map[accented])
	return folded


## Quebra o texto em palavras (letras e números), ignorando pontuação.
func _split_words(text: String) -> PackedStringArray:
	var regex := RegEx.new()
	regex.compile("[^\\p{L}\\p{N}]+")
	return regex.sub(text, " ", true).split(" ", false)


## --- Máquinas simuladas (ssh / curl / relatorio) -----------------------
## Desafios com "hosts": o jogador descobre as máquinas com 'scan', acha
## credenciais em arquivos e páginas, entra com 'ssh' e segue de máquina em
## máquina. O que ele descobre numa libera a próxima; não há etapas na tela.

func _cmd_ssh(args: PackedStringArray) -> void:
	if not _sim.has_hosts():
		_print_error("Comando não disponível neste sistema.")
		return
	if args.is_empty() or not args[0].contains("@"):
		_print_line("Uso: ssh <usuário>@<máquina>")
		return

	var user: String = args[0].get_slice("@", 0)
	var target: String = args[0].get_slice("@", 1)
	var host_name: String = _sim.find(target)
	if host_name == "":
		_print_error("ssh: Could not resolve hostname %s: Name or service not known" % target)
		return
	if not _check_scope(host_name):
		return

	# A próxima linha digitada é a senha (campo mascarado).
	_ssh_pending = {"user": user, "host": host_name}
	input_line.secret = true
	_print_line("%s@%s's password:" % [user, host_name])


## Recusa (e conta como erro) alvos fora do escopo autorizado do teste.
func _check_scope(host_name: String) -> bool:
	if _sim.in_scope(host_name):
		return true
	ChallengeSession.record_attempt(_challenge_id, false)
	SoundManager.play("error")
	_print_error("Abortado: %s está FORA do escopo autorizado do teste. Atacar um sistema sem autorização é crime." % host_name)
	return false


func _handle_ssh_password(password: String) -> void:
	var user: String = String(_ssh_pending["user"])
	var host_name: String = String(_ssh_pending["host"])
	_ssh_pending = {}
	input_line.secret = false

	if _sim.check_password(host_name, user, password):
		_sim.connect_to(host_name, user)
		_refresh_prompt()
		ChallengeSession.record_attempt(_challenge_id, true)
		_print_success("Acesso concedido: %s@%s" % [user, host_name])
	else:
		ChallengeSession.record_attempt(_challenge_id, false)
		SoundManager.play("error")
		_print_error("Permission denied, please try again.")


func _cmd_curl(args: PackedStringArray) -> void:
	if not _sim.has_hosts():
		_print_error("Comando não disponível neste sistema.")
		return
	if args.is_empty():
		_print_line("Uso: curl <endereço>   (ex.: curl http://máquina/caminho)")
		return

	var url: String = args[args.size() - 1].trim_prefix("http://").trim_prefix("https://")
	var slash: int = url.find("/")
	var host_part: String = url if slash == -1 else url.substr(0, slash)
	var path: String = "/" if slash == -1 else url.substr(slash)
	var host_name: String = _sim.find(host_part)
	if host_name == "":
		_print_error("curl: (6) Could not resolve host: %s" % host_part)
		return
	if not _check_scope(host_name):
		return

	var body: Variant = _sim.page(host_name, path)
	if body == null:
		_print_line("<html><body><h1>404 Not Found</h1></body></html>")
	else:
		_print_line(String(body))
		_check_objective_page(host_name, path)


## exit/logout: dentro de uma máquina remota volta para a anterior; na
## máquina local fecha o terminal.
func _cmd_exit() -> void:
	var left: String = _sim.current_host
	if _sim.disconnect_one():
		_refresh_prompt()
		_print_line("logout")
		_print_line("Connection to %s closed." % left)
		return
	close()


## Ler o arquivo-objetivo do desafio ("win_file": {host, file}) conclui o
## desafio, ou, com "final_report", libera a entrega do relatório.
func _check_objective_file(filename: String) -> void:
	var win: Dictionary = Dictionary(_challenge.get("win_file", {}))
	if win.is_empty() or _flag_captured:
		return
	if _sim.current_host != String(win.get("host", "")) or filename != String(win.get("file", "")):
		return
	_objective_reached()


## Abrir com 'curl' a página-objetivo do desafio ("win_page": {host, path})
## também alcança o objetivo (ex.: achar um arquivo exposto no site).
func _check_objective_page(host_name: String, path: String) -> void:
	var win: Dictionary = Dictionary(_challenge.get("win_page", {}))
	if win.is_empty() or _flag_captured:
		return
	if host_name != String(win.get("host", "")) or path != String(win.get("path", "")):
		return
	_objective_reached()


## O jogador chegou ao objetivo: conclui o desafio ou, com "final_report",
## libera a entrega do 'relatorio'.
func _objective_reached() -> void:
	_flag_captured = true
	ChallengeSession.record_attempt(_challenge_id, true)
	_print_line("")
	if bool(_challenge.get("final_report", false)):
		_print_success("Objetivo alcançado: a flag foi capturada. Entregue o relatório do teste com 'relatorio'.")
	else:
		_finish_challenge(String(_challenge.get("success_message", "Objetivo cumprido.")))


## relatorio: entrega final de um teste de invasão. Só vale depois de
## alcançar o objetivo; mostra por onde o jogador passou e conclui o desafio.
func _cmd_relatorio() -> void:
	if not bool(_challenge.get("final_report", false)):
		_print_error("Comando não disponível neste sistema.")
		return
	if not _flag_captured:
		_print_line("Ainda não há o que relatar: o objetivo do teste não foi alcançado.")
		return

	_print_rich("[color=%s][b]RELATÓRIO DO TESTE DE INVASÃO[/b][/color]" % C_WHITE)
	_print_line("Alvo: " + String(_challenge.get("title", "")))
	_print_line("Máquinas acessadas: " + ", ".join(PackedStringArray(_sim.visited)))
	_print_line("")
	_print_line("Achados:")
	for finding in _challenge.get("report_findings", []):
		_print_line("  - " + String(finding))
	_print_line("")
	_print_line("Recomendações:")
	for recommendation in _challenge.get("report_recommendations", []):
		_print_line("  - " + String(recommendation))
	_print_line("")
	_finish_challenge(String(_challenge.get("success_message", "Objetivo cumprido.")))


## --- Roteador doméstico (login / passwd) ------------------------------
## Duas etapas: entrar com a credencial de fábrica (está no manual) e depois
## trocá-la por uma senha forte. Tudo simulado em texto.

func _cmd_login_router(args_text: String) -> void:
	var parts: PackedStringArray = args_text.split(" ", false)
	if parts.size() < 2:
		_print_line("Uso: login <usuário> <senha>")
		return

	_print_line("Autenticando em %s como '%s'..." % [String(_challenge["device"]), parts[0]])
	if parts[0] == String(_challenge["default_user"]) and parts[1] == String(_challenge["default_password"]):
		_router_logged_in = true
		ChallengeSession.record_attempt(_challenge_id, true)
		_print_success("Acesso concedido: o roteador ainda usa a senha de fábrica!")
		_print_line("Qualquer pessoa com o manual entraria aqui. Troque a senha: passwd <nova senha>")
	else:
		ChallengeSession.record_attempt(_challenge_id, false)
		SoundManager.play("error")
		_print_error("Acesso negado: usuário ou senha incorretos.")


func _cmd_passwd(nova_senha: String) -> void:
	if String(_challenge.get("type", "")) != "router":
		_print_error("Comando não disponível neste sistema.")
		return
	if not _router_logged_in:
		_print_error("Acesso negado: entre no painel do roteador primeiro (login <usuário> <senha>).")
		return
	if nova_senha == "":
		_print_line("Uso: passwd <nova senha>")
		return

	var problems: PackedStringArray = _password_problems(nova_senha)
	if not problems.is_empty():
		ChallengeSession.record_attempt(_challenge_id, false)
		SoundManager.play("error")
		_print_error("Senha recusada: ainda está fraca.")
		for problem in problems:
			_print_line("  - " + problem)
		return

	ChallengeSession.record_attempt(_challenge_id, true)
	_print_line("Senha do painel alterada.")
	_print_line("")
	_finish_challenge("Objetivo cumprido: roteador protegido com uma senha forte.")


## O que falta para a senha ser considerada forte (lista vazia = forte).
func _password_problems(password: String) -> PackedStringArray:
	var problems := PackedStringArray()
	var min_length: int = int(_challenge.get("min_length", 10))
	if password.length() < min_length:
		problems.append("precisa ter pelo menos %d caracteres" % min_length)

	var has_letter := false
	var has_digit := false
	var has_symbol := false
	for character in password:
		if character.to_upper() != character.to_lower():
			has_letter = true
		elif "0123456789".contains(character):
			has_digit = true
		elif character != " ":
			has_symbol = true
	if not has_letter:
		problems.append("precisa de letras")
	if not has_digit:
		problems.append("precisa de pelo menos um número")
	if not has_symbol:
		problems.append("precisa de pelo menos um símbolo (como ! # $ %)")

	var lowered: String = password.to_lower()
	for obvious in [String(_challenge.get("default_password", "")), "admin", "senha", "1234"]:
		if obvious != "" and lowered.contains(obvious):
			problems.append("não use palavras óbvias como '%s'" % obvious)
			break
	return problems


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


## Arquivos que este computador mostra: os comuns (VIRTUAL_FILES) mais os
## que o desafio define em "files", que só existem neste computador.
func _available_files() -> Dictionary:
	# Dentro de uma máquina remota (depois do ssh) valem só os arquivos dela.
	if _sim.is_remote():
		return _sim.files()
	var files: Dictionary = VIRTUAL_FILES.duplicate()
	files.merge(Dictionary(_challenge.get("files", {})), true)
	return files


## ls / files. Arquivos cujo nome começa com "." ficam ocultos, como no
## Linux, e só aparecem com 'ls -a'.
func _cmd_files(args: PackedStringArray = PackedStringArray()) -> void:
	var show_hidden := false
	for arg in args:
		if arg.begins_with("-") and arg.contains("a"):
			show_hidden = true
	_print_line("Arquivos encontrados:")
	for filename in _available_files().keys():
		if String(filename).begins_with(".") and not show_hidden:
			continue
		_print_line("  " + filename)


func _cmd_read(args: PackedStringArray) -> void:
	if args.is_empty():
		_print_line("Uso: read <arquivo>")
		return

	var filename: String = args[0]
	var files: Dictionary = _available_files()
	if files.has(filename):
		_print_line(String(files[filename]))
		_check_mission_progress(filename)
		_check_objective_file(filename)
	else:
		_print_error("cat: " + filename + ": arquivo não encontrado")


## grep <termo> <arquivo>: mostra só as linhas que contêm o termo (sem
## diferenciar maiúsculas de minúsculas). Como o grep de verdade, não
## escreve nada quando nenhuma linha bate.
func _cmd_grep(args: PackedStringArray) -> void:
	if args.size() < 2:
		_print_line("Uso: grep <termo> <arquivo>")
		return

	var filename: String = args[args.size() - 1]
	var term: String = " ".join(args.slice(0, args.size() - 1))
	term = term.trim_prefix("\"").trim_suffix("\"").to_lower()

	var files: Dictionary = _available_files()
	if not files.has(filename):
		_print_error("grep: " + filename + ": arquivo não encontrado")
		return

	for line in String(files[filename]).split("\n"):
		if term != "" and line.to_lower().contains(term):
			_print_line(line)


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
