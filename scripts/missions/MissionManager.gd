extends Node
## MissionManager.gd — Autoload
## Controla as missões do jogo: definição, estado atual, objetivos e
## recompensas. Mantido simples de propósito (dicionários em vez de
## Resources customizados) para ficar fácil de ler e manter.

signal mission_started(mission_id: String)
signal mission_completed(mission_id: String)

enum State { LOCKED, AVAILABLE, ACTIVE, COMPLETED, FAILED }

## Definição das missões. Cada missão tem os campos pedidos no escopo:
## id, título, descrição, objetivo, local, estado, recompensa em XP e
## dificuldade. "concept" é o conceito de cibersegurança ensinado, e
## "explanation" é o texto mostrado na tela de missão concluída.
var missions: Dictionary = {
	"m01": {
		"id": "m01",
		"title": "Missão 01 — O e-mail suspeito",
		"description": "Um morador abriu um e-mail e seu computador começou a apresentar comportamentos estranhos.",
		"objective": "Leia o e-mail no computador da casa (use 'files' e 'read' no terminal).",
		"location": "Casa (qualquer uma)",
		"state": State.AVAILABLE,
		"xp": 100,
		"difficulty": "Fácil",
		"concept": "Phishing",
		"explanation": "O e-mail vinha de um domínio parecido com o verdadeiro (empresaa-seguranca.com) e usava urgência para pressionar um clique imediato. Esses são dois sinais clássicos de phishing.",
	},
	"m02": {
		"id": "m02",
		"title": "Missão 02 — A senha esquecida",
		"description": "Um morador precisa trocar de senha e quer saber se a escolha dele é segura.",
		"objective": "Na empresa, use a Estação 1 e digite 'desafio' no terminal.",
		"location": "Empresa (Estação 1)",
		"state": State.AVAILABLE,
		"xp": 100,
		"difficulty": "Fácil",
		"concept": "Senhas",
		"explanation": "Senhas maiores, sem palavras comuns e misturando letras, números e símbolos são muito mais difíceis de adivinhar. Já '123456', 'senha2024' ou o nome do cachorro são previsíveis: estão nas primeiras tentativas de qualquer ataque.",
	},
	"m03": {
		"id": "m03",
		"title": "Missão 03 — O hash no banco de dados",
		"description": "Um sistema guarda hashes em vez de senhas, e a equipe não entende a diferença.",
		"objective": "Na empresa, use a Estação 2 e digite 'desafio' no terminal.",
		"location": "Empresa (Estação 2)",
		"state": State.AVAILABLE,
		"xp": 150,
		"difficulty": "Média",
		"concept": "Hash",
		"explanation": "Hash é um caminho de mão única: a partir da senha se gera o hash, mas não dá para voltar do hash para a senha. Por isso sistemas guardam o hash — no login, eles aplicam a mesma função na senha digitada e comparam os dois resultados.",
	},
	"m04": {
		"id": "m04",
		"title": "Missão 04 — Mensagem cifrada",
		"description": "Uma mensagem interceptada está cifrada e precisa ser lida.",
		"objective": "No Centro de Tecnologia, use a Estação 1 e digite 'desafio'.",
		"location": "Centro de Tecnologia (Estação 1)",
		"state": State.AVAILABLE,
		"xp": 150,
		"difficulty": "Média",
		"concept": "Criptografia",
		"explanation": "Diferente do hash, a criptografia é reversível: com a chave certa dá para voltar ao texto original. Na Cifra de César a chave é o número de posições deslocadas — aqui, 3 posições para trás transformam VHJXUR em SEGURO.",
	},
	"m05": {
		"id": "m05",
		"title": "Missão 05 — Caça ao phishing",
		"description": "A empresa recebeu mensagens suspeitas e quer treinar a equipe a identificá-las.",
		"objective": "No Centro de Tecnologia, use a Estação 2 e digite 'desafio'.",
		"location": "Centro de Tecnologia (Estação 2)",
		"state": State.AVAILABLE,
		"xp": 200,
		"difficulty": "Média",
		"concept": "Phishing",
		"explanation": "Os sinais mais fortes de phishing são o domínio imitando o verdadeiro (empresaa-seguranca.com no lugar de empresa.com) e a urgência artificial pedindo dados. Nenhum suporte legítimo pede sua senha por e-mail.",
	},
	"m06": {
		"id": "m06",
		"title": "Missão 06 — Dispositivo desconhecido",
		"description": "A empresa suspeita que um dispositivo não autorizado está na rede local.",
		"objective": "Na empresa, use o Servidor: digite 'scan' para mapear a rede e 'connect <ip>' no dispositivo suspeito.",
		"location": "Empresa (Servidor)",
		"state": State.AVAILABLE,
		"xp": 200,
		"difficulty": "Média",
		"concept": "Redes",
		"explanation": "Todo dispositivo numa rede deveria estar cadastrado no inventário. Um IP desconhecido, sem dono definido e mandando dados pra fora da rede fora de hora é um padrão clássico de dispositivo comprometido.",
	},
	"m07": {
		"id": "m07",
		"title": "Missão 07 — Configurar o firewall",
		"description": "O Centro de Tecnologia recebeu várias tentativas de conexão e precisa de regras de firewall.",
		"objective": "No Centro de Tecnologia, use o computador de Firewall: digite 'firewall status' e depois 'firewall allow/block <porta>' para cada conexão.",
		"location": "Centro de Tecnologia (Firewall)",
		"state": State.AVAILABLE,
		"xp": 250,
		"difficulty": "Difícil",
		"concept": "Firewall",
		"explanation": "Um firewall bem configurado libera só o que o serviço realmente precisa e bloqueia o que é arriscado por natureza ou não tem explicação nenhuma — como uma porta desconhecida com tráfego constante, sinal clássico de backdoor.",
	},
	"m08": {
		"id": "m08",
		"title": "Missão 08 — Login suspeito nos logs",
		"description": "O servidor da loja registrou vários acessos e a equipe quer saber se algo suspeito aconteceu.",
		"objective": "Na Loja Eletrônica, use o Registro de Acessos: digite 'logs' e depois 'report <linha>'.",
		"location": "Loja Eletrônica (Registro de Acessos)",
		"state": State.AVAILABLE,
		"xp": 200,
		"difficulty": "Média",
		"concept": "Logs",
		"explanation": "Três tentativas de login falhando seguidas, e logo depois um sucesso — tudo no mesmo minuto — é o padrão clássico de força bruta bem-sucedida: alguém tentou senhas até acertar.",
	},
	"m09": {
		"id": "m09",
		"title": "Missão 09 — Login vulnerável",
		"description": "O sistema de login da loja parece aceitar entradas estranhas sem travar.",
		"objective": "Na Loja Eletrônica, use o Sistema de Login: digite 'login <alguma coisa>' e tente burlar a autenticação.",
		"location": "Loja Eletrônica (Sistema de Login)",
		"state": State.AVAILABLE,
		"xp": 250,
		"difficulty": "Difícil",
		"concept": "SQL Injection",
		"explanation": "O sistema provavelmente monta a consulta colando a senha direto no SQL. Uma entrada que sempre avalia como verdadeira (como ' OR '1'='1) faz o sistema autenticar sem saber a senha real — por isso todo dado do usuário precisa ser validado antes de entrar numa consulta.",
	},
	"m10": {
		"id": "m10",
		"title": "Missão 10 — Comentário perigoso",
		"description": "O sistema de comentários da loja publica qualquer coisa sem checar o conteúdo.",
		"objective": "Na Loja Eletrônica, use o Sistema de Comentários: digite 'postar <mensagem>' e teste um conteúdo perigoso.",
		"location": "Loja Eletrônica (Sistema de Comentários)",
		"state": State.AVAILABLE,
		"xp": 250,
		"difficulty": "Difícil",
		"concept": "XSS",
		"explanation": "Se o site mostrasse o comentário na página sem tratar o conteúdo, uma tag <script> digitada por qualquer visitante rodaria no navegador de quem lesse o comentário. Por isso todo conteúdo enviado por usuários precisa ser sanitizado antes de ser exibido.",
	},
	"m11": {
		"id": "m11",
		"title": "Missão 11 — O roteador de fábrica",
		"description": "O wi-fi de uma casa está lento e a moradora desconfia que alguém está usando a rede dela.",
		"objective": "Na Casa 6, use o computador: leia o manual do roteador, entre com 'login <usuário> <senha>' e troque a senha com 'passwd <nova senha>'.",
		"location": "Casa 6 (Roteador)",
		"state": State.AVAILABLE,
		"xp": 200,
		"difficulty": "Média",
		"concept": "Credenciais padrão",
		"explanation": "Roteadores e outros equipamentos saem de fábrica com usuário e senha conhecidos (como admin/admin), listados nos manuais. Se ninguém troca, qualquer pessoa entra no painel. Troque sempre a credencial padrão por uma senha longa, única e sem palavras óbvias.",
	},
	"m12": {
		"id": "m12",
		"title": "Missão 12 — Cabeçalho suspeito",
		"description": "A vizinha da Casa 2 recebeu um e-mail do \"banco\" e quer saber se pode confiar nele.",
		"objective": "Na Casa 2, use o computador: leia o e-mail com 'cat email.eml' e aponte pelo menos 3 indícios de fraude com 'report <indício>'.",
		"location": "Casa 2 (E-mail)",
		"state": State.AVAILABLE,
		"xp": 150,
		"difficulty": "Média",
		"concept": "Cabeçalhos de e-mail",
		"explanation": "Um e-mail fraudulento costuma se denunciar nos cabeçalhos: SPF, DKIM e DMARC reprovados (o servidor não confirma o remetente), Reply-To em outro domínio, domínio parecido com o real, link cujo destino difere do texto e pressão de tempo. Antes de clicar, confira o remetente real, os cabeçalhos de autenticação e para onde o link realmente aponta.",
	},
	"m13": {
		"id": "m13",
		"title": "Missão 13 — Caixa de entrada lotada",
		"description": "O morador da Casa 3 recebeu seis mensagens de uma vez e não sabe em quais confiar.",
		"objective": "Na Casa 3, use o computador: leia 'cat inbox.txt', abra cada mensagem com 'cat msg1.eml' etc. e aponte os golpes com 'report <número>'.",
		"location": "Casa 3 (Caixa de entrada)",
		"state": State.AVAILABLE,
		"xp": 200,
		"difficulty": "Média",
		"concept": "Phishing em massa",
		"explanation": "Golpes de phishing combinam um pretexto (encomenda, banco, chefe, TI), pressa e um link ou pedido fora do normal. Confira o domínio do remetente e do link, desconfie de pedidos de dinheiro, cartões ou senha e lembre que um e-mail pode passar na autenticação (SPF) e ainda ser golpe, como um 'diretor' escrevendo de um e-mail pessoal. Mensagens legítimas também têm prazos: o que decide é o conjunto de sinais.",
	},
	"m14": {
		"id": "m14",
		"title": "Missão 14 — Senha reutilizada",
		"description": "A LojaFácil avisou que vazou dados de clientes, e o morador da Casa 4 usa a mesma senha em tudo.",
		"objective": "Na Casa 4, use o computador: leia o aviso, filtre o log com 'grep <termo> acessos_email.log' e aponte pelo menos 4 achados com 'report <achado>'.",
		"location": "Casa 4 (E-mail)",
		"state": State.AVAILABLE,
		"xp": 250,
		"difficulty": "Difícil",
		"concept": "Reutilização de senhas",
		"explanation": "Quando um site vaza senhas, os atacantes testam as mesmas combinações de e-mail e senha em outros serviços: é o credential stuffing, e só dá certo porque muita gente reutiliza a senha. Depois de entrar, costumam criar regras de encaminhamento para manter acesso mesmo se a senha for trocada. Use uma senha diferente em cada serviço (com um gerenciador de senhas), ative a verificação em duas etapas e revise as regras da conta depois de qualquer suspeita.",
	},
	"m15": {
		"id": "m15",
		"title": "Missão 15 — Invasão em cadeia",
		"description": "A Orion Logística contratou um teste de invasão autorizado: mostrar até onde um atacante chegaria a partir do site da empresa.",
		"objective": "No Terminal Público da praça: leia as notas do teste, avance de máquina em máquina até a flag e entregue o relatório com 'relatorio'.",
		"location": "Praça Central (Terminal Público)",
		"state": State.AVAILABLE,
		"xp": 400,
		"difficulty": "Difícil",
		"concept": "Movimento lateral",
		"explanation": "Um teste de invasão segue o caminho de um atacante real, mas só dentro do escopo autorizado: reconhecimento, descoberta de um arquivo esquecido, uso de credenciais expostas, reutilização de senha entre sistemas (movimento lateral) e, no fim, um relatório com achados e recomendações. Os problemas foram um backup acessível pela web, credenciais em texto puro, senha reutilizada e falta de segmentação entre o servidor web e o banco.",
	},
	"m16": {
		"id": "m16",
		"title": "Missão 16 — O site esquecido",
		"description": "A DataSoft quer saber o que um visitante qualquer consegue descobrir sobre o site da empresa.",
		"objective": "Na DataSoft, Estação 1: use 'curl' no site (192.168.1.50), siga as pistas do que ele mostra e encontre um arquivo que não deveria estar público.",
		"location": "DataSoft (Estação 1)",
		"state": State.AVAILABLE,
		"xp": 250,
		"difficulty": "Média",
		"concept": "Exposição de arquivos",
		"explanation": "Visitantes comuns podem ler o que o servidor entrega, e o robots.txt não protege nada: ele só pede aos buscadores que ignorem os caminhos, e acaba listando o que a empresa queria esconder. Comentários esquecidos no HTML e arquivos de backup (.bak, .old) com senhas em texto puro são achados clássicos. Remova arquivos antigos do servidor, nunca deixe credenciais em arquivos acessíveis e restrinja o acesso a pastas internas.",
	},
	"m17": {
		"id": "m17",
		"title": "Missão 17 — Acesso emprestado",
		"description": "A DataSoft emprestou um acesso comum a um estagiário e quer saber até onde ele chegaria.",
		"objective": "Na DataSoft, Estação 2: leia o chamado, entre na máquina com 'ssh usuário@máquina', procure o que ficou esquecido (inclusive arquivos ocultos com 'ls -a') e chegue à flag do servidor de arquivos.",
		"location": "DataSoft (Estação 2)",
		"state": State.AVAILABLE,
		"xp": 300,
		"difficulty": "Difícil",
		"concept": "Segredos no histórico",
		"explanation": "O shell guarda os comandos digitados num arquivo de histórico (.bash_history), então qualquer senha escrita na linha de comando fica gravada ali, à vista de quem ganhar acesso à conta. Um acesso comum e emprestado já bastou para chegar a um servidor com dados importantes. Evite senhas em comandos (use chaves SSH ou peça a senha de forma interativa), limpe o histórico e remova acessos que não são mais necessários.",
	},
}

## Estado inicial de cada missão, guardado para o "Novo jogo".
var _initial_states: Dictionary = {}


func _ready() -> void:
	for mission_id in missions.keys():
		_initial_states[mission_id] = missions[mission_id]["state"]


## Volta todas as missões ao estado inicial (usado por "Novo jogo").
func reset() -> void:
	for mission_id in _initial_states.keys():
		missions[mission_id]["state"] = _initial_states[mission_id]


## Dados para o save: estado de cada missão (ver SaveManager.gd).
func get_save_data() -> Dictionary:
	var states := {}
	for mission_id in missions.keys():
		states[mission_id] = int(missions[mission_id]["state"])
	return {"states": states}


## Restaura os estados salvos. Missões que não estão no save ficam como estão.
func load_save_data(data: Dictionary) -> void:
	var states: Dictionary = data.get("states", {})
	for mission_id in states.keys():
		if missions.has(mission_id):
			var value: int = clampi(int(states[mission_id]), 0, State.size() - 1)
			missions[mission_id]["state"] = value


func get_mission(mission_id: String) -> Dictionary:
	return missions.get(mission_id, {})


func get_state(mission_id: String) -> State:
	var mission: Dictionary = get_mission(mission_id)
	if mission.is_empty():
		return State.LOCKED
	return mission["state"]


func is_active(mission_id: String) -> bool:
	return get_state(mission_id) == State.ACTIVE


func is_completed(mission_id: String) -> bool:
	return get_state(mission_id) == State.COMPLETED


## Devolve a missão em andamento (ou um dicionário vazio se não houver).
func get_active_mission() -> Dictionary:
	for mission in missions.values():
		if mission["state"] == State.ACTIVE:
			return mission
	return {}


## Aceita/inicia uma missão que esteja disponível.
func start_mission(mission_id: String) -> void:
	if get_state(mission_id) != State.AVAILABLE:
		return
	missions[mission_id]["state"] = State.ACTIVE
	mission_started.emit(mission_id)


## Conclui uma missão ativa, entregando XP e registrando o conceito
## aprendido no GameManager.
func complete_mission(mission_id: String) -> void:
	if not is_active(mission_id):
		return

	var mission: Dictionary = missions[mission_id]
	mission["state"] = State.COMPLETED

	GameManager.add_xp(int(mission["xp"]))
	GameManager.add_knowledge(String(mission["concept"]))

	mission_completed.emit(mission_id)


## Nome legível do estado, usado no menu de missões.
func state_to_text(state: State) -> String:
	match state:
		State.LOCKED:
			return "BLOQUEADA"
		State.AVAILABLE:
			return "DISPONÍVEL"
		State.ACTIVE:
			return "EM ANDAMENTO"
		State.COMPLETED:
			return "CONCLUÍDA"
		State.FAILED:
			return "FALHOU"
	return "?"
