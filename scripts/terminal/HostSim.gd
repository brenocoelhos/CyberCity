extends RefCounted
## HostSim.gd
## Máquinas simuladas de um desafio ("hosts" no ChallengeData). Guarda só a
## lógica: em qual máquina o jogador está, com qual usuário, de onde veio
## (para o 'exit' voltar) e por onde passou (para o relatório). Quem escreve
## na tela é o TerminalManager.
##
## Cada máquina é um dicionário:
##   ip     - endereço (também aceito no lugar do nome em ssh/curl)
##   ports  - texto das portas abertas mostrado pelo 'scan'
##   scope  - false = fora do escopo autorizado (ssh/curl são recusados)
##   users  - usuário -> senha
##   files  - nome do arquivo -> conteúdo (nomes com "." na frente são ocultos)
##   web    - caminho -> conteúdo (páginas para o 'curl')

const LOCAL_USER := "kali"

var _hosts: Dictionary = {}
var _stack: Array = []

## "" = a máquina local (o computador onde o terminal foi aberto).
var current_host: String = ""
var current_user: String = LOCAL_USER
## Nomes das máquinas em que o jogador entrou, na ordem.
var visited: Array = []


func setup(challenge: Dictionary) -> void:
	_hosts = Dictionary(challenge.get("hosts", {}))
	_stack = []
	current_host = ""
	current_user = LOCAL_USER
	visited = []


func has_hosts() -> bool:
	return not _hosts.is_empty()


func is_remote() -> bool:
	return current_host != ""


## Nome da máquina a partir do nome ou do IP digitado ("" se não existe).
func find(target: String) -> String:
	var wanted: String = target.strip_edges().to_lower()
	for host_name in _hosts.keys():
		if String(host_name).to_lower() == wanted or String(_hosts[host_name].get("ip", "")) == wanted:
			return String(host_name)
	return ""


func in_scope(host_name: String) -> bool:
	return bool(_hosts.get(host_name, {}).get("scope", true))


func check_password(host_name: String, user: String, password: String) -> bool:
	var users: Dictionary = _hosts.get(host_name, {}).get("users", {})
	return users.has(user) and String(users[user]) == password


## Entra na máquina (guarda de onde veio, para o exit voltar).
func connect_to(host_name: String, user: String) -> void:
	_stack.append({"host": current_host, "user": current_user})
	current_host = host_name
	current_user = user
	if not visited.has(host_name):
		visited.append(host_name)


## Volta uma máquina. false se já está na máquina local.
func disconnect_one() -> bool:
	if _stack.is_empty():
		return false
	var previous: Dictionary = _stack.pop_back()
	current_host = String(previous["host"])
	current_user = String(previous["user"])
	return true


## Arquivos da máquina atual (vazio na máquina local: lá valem os do desafio).
func files() -> Dictionary:
	if not is_remote():
		return {}
	return Dictionary(_hosts[current_host].get("files", {}))


## Página que o 'curl' encontra, ou null se o caminho não existe.
func page(host_name: String, path: String) -> Variant:
	var pages: Dictionary = _hosts.get(host_name, {}).get("web", {})
	if pages.has(path):
		return String(pages[path])
	return null


## Uma linha por máquina para o 'scan': IP, nome e portas abertas.
func scan_lines() -> PackedStringArray:
	var lines := PackedStringArray()
	for host_name in _hosts.keys():
		var host: Dictionary = _hosts[host_name]
		lines.append("%-15s %-10s %s" % [String(host.get("ip", "?")), String(host_name), String(host.get("ports", ""))])
	return lines
