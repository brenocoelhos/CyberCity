extends Node
## ChallengeData.gd — Autoload
## Banco de dados dos desafios educativos, separado da lógica de
## apresentação (ChallengeManager). Assim, adicionar um desafio novo é
## só acrescentar uma entrada aqui — nada de mexer na interface.
##
## Campos de cada desafio:
##   title       - nome mostrado no topo da tela
##   prompt      - enunciado / cenário apresentado ao jogador
##   options     - alternativas (2 a 4)
##   correct     - índice da alternativa correta (começa em 0)
##   hints       - dicas em camadas, da mais vaga para a mais direta:
##                 1) direção (onde olhar), 2) método (como abordar),
##                 3) quase-resposta (o padrão exato; o jogador ainda
##                 precisa executar). A 1ª chega de graça com a missão;
##                 as outras o jogador pede (comando 'dica', botão de dica
##                 do quiz ou app Pistas do celular). Ver ChallengeSession.
##   mission     - id da missão ligada a este desafio

const CHALLENGES := {
	"c_senhas": {
		"type": "quiz",
		"title": "DESAFIO — Segurança de senhas",
		"prompt": "O morador precisa escolher uma nova senha.\n\nQual das opções abaixo é a MAIS segura?",
		"options": [
			"123456",
			"senha2024",
			"J7#vq!Lm92$tR",
			"nomedocachorro",
		],
		"correct": 2,
		"hints": [
			"Senhas curtas podem ser descobertas em segundos por um programa.",
			"Palavras comuns, sequências e dados pessoais estão nas listas de ataque.",
			"Pense em tamanho e previsibilidade: senhas curtas, com palavras comuns ou dados pessoais são fáceis de adivinhar.",
		],
		"mission": "m02",
	},
	"c_hash": {
		"type": "quiz",
		"title": "DESAFIO — Hash",
		"prompt": "Um sistema guarda esta informação no banco de dados:\n\n  usuario: joao\n  hash armazenado: 8f14e45fceea167a5a36dedd4bea2543\n\nO que esse valor representa?",
		"options": [
			"A senha do usuário, apenas escrita ao contrário.",
			"O resultado de aplicar uma função de hash sobre a senha.",
			"A senha criptografada, que o sistema descriptografa no login.",
			"Um número aleatório sem relação com a senha.",
		],
		"correct": 1,
		"hints": [
			"Um hash funciona como uma \"impressão digital\" da senha.",
			"O sistema compara hashes no login — ele nunca precisa ver a senha original.",
			"Hash não é o mesmo que criptografia: a ideia é justamente NÃO conseguir voltar ao texto original.",
		],
		"mission": "m03",
	},
	"c_cripto": {
		"type": "quiz",
		"title": "DESAFIO — Criptografia",
		"prompt": "Uma mensagem foi cifrada com a Cifra de César, deslocando cada letra 3 posições para frente no alfabeto.\n\nTexto cifrado:  VHJXUR\nChave: 3\n\nQual é o texto original?",
		"options": [
			"SEGURO",
			"SENHAS",
			"SISTEMA",
			"SERVER",
		],
		"correct": 0,
		"hints": [
			"Na Cifra de César, todas as letras andam o mesmo número de casas no alfabeto.",
			"A chave é 3. Para decifrar, ande 3 casas para TRÁS.",
			"Volte cada letra 3 posições: V→S, H→E, J→G... e siga o mesmo padrão até o fim.",
		],
		"mission": "m04",
	},
	"c_phishing": {
		"type": "quiz",
		"title": "DESAFIO — Phishing",
		"prompt": "A empresa recebeu dois e-mails.\n\nEMAIL 1\nDe: suporte@empresa.com\nAssunto: Atualização de segurança\nMensagem: Informamos que na próxima terça faremos uma manutenção programada.\n\nEMAIL 2\nDe: suporte@empresaa-seguranca.com\nAssunto: URGENTE!!! CONTA SERÁ EXCLUÍDA\nMensagem: Clique imediatamente neste link e confirme sua senha.\n\nQual é o principal sinal de que o EMAIL 2 é phishing?",
		"options": [
			"Ele foi enviado durante o horário comercial.",
			"O domínio imita o real e a mensagem força urgência pedindo a senha.",
			"Ele tem um assunto mais curto que o outro.",
			"Ele menciona a palavra 'segurança'.",
		],
		"correct": 1,
		"hints": [
			"Leia o endereço do remetente letra por letra.",
			"Desconfie de mensagens que pedem pressa ou a sua senha.",
			"Compare os remetentes com atenção e veja o que cada mensagem PEDE que você faça.",
		],
		"mission": "m05",
	},

	## A partir daqui: desafios "de rede", resolvidos digitando comandos
	## no terminal (scan/connect/firewall) em vez de escolher opções.
	"c_rede": {
		"type": "network",
		"title": "Investigação de rede",
		"mission": "m06",
		"devices": {
			"192.168.1.1": {"name": "ROUTER", "suspicious": false, "info": "Roteador principal da empresa. Configuração normal, sem anomalias."},
			"192.168.1.10": {"name": "OFFICE-PC", "suspicious": false, "info": "Estação de trabalho cadastrada no inventário. Sem anomalias."},
			"192.168.1.20": {"name": "SERVER", "suspicious": false, "info": "Servidor de arquivos da empresa. Tráfego normal."},
			"192.168.1.50": {"name": "UNKNOWN", "suspicious": true, "info": "Dispositivo não cadastrado no inventário. Está enviando pacotes para um endereço externo desconhecido, fora do horário comercial."},
		},
		"correct_ip": "192.168.1.50",
		"hints": [
			"No Servidor, o comando 'scan' mostra todos os dispositivos da rede.",
			"Todo dispositivo deveria estar no inventário da empresa. Algum não tem nome conhecido?",
			"Repare em qual dispositivo NÃO tem um nome reconhecível (ROUTER, OFFICE-PC, SERVER) — o UNKNOWN é o candidato certo pra investigar com 'connect <ip>'.",
		],
		"explanation": "Todo dispositivo numa rede deveria estar cadastrado no inventário. Um IP desconhecido, sem dono definido e mandando dados pra fora da rede fora de hora é um padrão clássico de dispositivo comprometido (ou até um invasor dentro da rede).",
	},
	"c_firewall": {
		"type": "firewall",
		"title": "Configuração de firewall",
		"mission": "m07",
		"connections": [
			{"port": 80, "service": "HTTP (site da empresa)", "recommended": "allow"},
			{"port": 443, "service": "HTTPS (site da empresa, com criptografia)", "recommended": "allow"},
			{"port": 23, "service": "TELNET (login remoto sem criptografia)", "recommended": "block"},
			{"port": 4444, "service": "porta não documentada, tráfego constante para fora", "recommended": "block"},
		],
		"hints": [
			"No computador de Firewall, 'firewall status' lista as conexões.",
			"O site da empresa precisa continuar funcionando (HTTP e HTTPS).",
			"HTTP (80) e HTTPS (443) de um site normal costumam poder ficar liberados. TELNET (23) não é criptografado, e uma porta sem nenhuma explicação (tipo a 4444) é sinal clássico de backdoor — considere bloquear os dois.",
		],
		"explanation": "Um firewall bem configurado libera só o que o serviço realmente precisa (aqui, o site em HTTP/HTTPS) e bloqueia o que é arriscado por natureza (Telnet, sem criptografia) ou não tem explicação nenhuma (porta desconhecida com tráfego constante — clássico sinal de backdoor).",
	},

	## Análise de logs: o jogador olha o registro de acessos e aponta
	## a linha suspeita com 'report <linha>'.
	"c_logs": {
		"type": "logs",
		"title": "Análise de logs",
		"mission": "m08",
		"entries": [
			{"line": 1, "time": "10:31", "text": "Login successful (user: admin)"},
			{"line": 2, "time": "10:32", "text": "Login failed (user: admin)"},
			{"line": 3, "time": "10:32", "text": "Login failed (user: admin)"},
			{"line": 4, "time": "10:33", "text": "Login failed (user: admin)"},
			{"line": 5, "time": "10:33", "text": "Login successful (user: admin)"},
			{"line": 6, "time": "10:34", "text": "File accessed (contract.pdf)"},
		],
		"correct_line": 5,
		"hints": [
			"No Registro de Acessos, 'logs' mostra cada linha numerada.",
			"Várias falhas de login seguidas, no mesmo minuto, são suspeitas.",
			"Procure a sequência de falhas seguida por um sucesso, tudo bem pertinho no tempo — é aí que a tentativa deu certo.",
		],
		"explanation": "Três tentativas de login falhando seguidas, e logo depois um sucesso — tudo no mesmo minuto — é o padrão clássico de força bruta bem-sucedida: alguém tentou senhas até acertar. A linha 5 é o momento em que o invasor conseguiu entrar.",
	},

	## Laboratório fictício de SQL Injection: um "login" simulado que
	## aceita entradas que sempre avaliam como verdadeiras. Nada aqui
	## se conecta a um banco de dados de verdade.
	"c_sqli": {
		"type": "sqli",
		"title": "Login vulnerável",
		"mission": "m09",
		"hints": [
			"O sistema cola o que você digita direto dentro de uma consulta SQL.",
			"Aspas simples ( ' ) podem \"fechar\" o texto que o sistema esperava.",
			"Pense numa entrada que faça a condição da consulta virar sempre verdadeira — algo como comparar um valor com ele mesmo, usando aspas pra 'fechar' a parte que o sistema espera.",
		],
		"explanation": "O sistema provavelmente monta a consulta colando a senha direto no SQL (algo como SELECT * FROM usuarios WHERE senha = '<o que você digitou>'). Uma entrada como ' OR '1'='1 faz essa condição virar sempre verdadeira, então o sistema autentica sem saber a senha real. Por isso todo dado que o usuário digita precisa ser validado antes de entrar numa consulta.",
	},

	## Laboratório fictício de XSS: um "campo de comentário" simulado.
	## Nenhum HTML/JS é realmente executado — é só uma simulação de texto.
	"c_xss": {
		"type": "xss",
		"title": "Campo de comentário vulnerável",
		"mission": "m10",
		"hints": [
			"O sistema mostra o comentário na página sem tratar o conteúdo.",
			"E se o comentário tivesse uma tag HTML, como <b> ou <script>?",
			"Tente publicar algo que pareça uma tag de código, tipo <script>...</script>, e veja o que o sistema faz com isso sem tratar o conteúdo.",
		],
		"explanation": "Se o site pegasse o comentário e mostrasse na página sem tratar o conteúdo, uma tag <script> digitada por qualquer visitante rodaria no navegador de quem lesse o comentário — podendo roubar sessão, redirecionar a página, etc. Por isso todo conteúdo enviado por usuários precisa ser sanitizado antes de ser exibido.",
	},

	## Roteador doméstico ainda com a senha de fábrica. Duas etapas: entrar
	## usando a credencial padrão (que está no manual) e depois trocá-la por
	## uma senha forte. Tudo simulado em texto.
	## "files" são os arquivos que só existem neste computador.
	"c_roteador": {
		"type": "router",
		"title": "Roteador de fábrica",
		"mission": "m11",
		"device": "NetLink R-200",
		"files": {
			"manual.txt": "NetLink R-200 — Guia rápido\n\n1. Ligue o roteador na tomada e na internet.\n2. Acesse o painel de administração com o usuário e a senha de fábrica:\n     usuário: admin\n     senha:   admin\n3. Configure o nome e a senha do seu wi-fi.\n\n(Dica do fabricante: troque a senha de fábrica depois do primeiro acesso.)",
		},
		"default_user": "admin",
		"default_password": "admin",
		"min_length": 10,
		"hints": [
			"O manual do roteador está num arquivo deste computador. Use 'files' e depois 'read manual.txt'.",
			"Equipamentos saem de fábrica com um usuário e uma senha conhecidos, e o manual os mostra. Tente 'login <usuário> <senha>'.",
			"Depois de entrar, troque a senha com 'passwd <nova senha>'. Use pelo menos 10 caracteres, misturando letras, números e símbolos, e nada de 'admin'.",
		],
		"explanation": "Roteadores e outros equipamentos saem de fábrica com usuário e senha conhecidos (como admin/admin), listados nos manuais. Se ninguém troca, qualquer pessoa entra no painel. Troque sempre a credencial padrão por uma senha longa, única e sem palavras óbvias.",
	},
}


func get_challenge(challenge_id: String) -> Dictionary:
	return CHALLENGES.get(challenge_id, {})


## Id do desafio ligado a uma missão ("" se a missão não tem desafio, como a m01).
func get_challenge_id_for_mission(mission_id: String) -> String:
	for challenge_id in CHALLENGES.keys():
		if String(CHALLENGES[challenge_id].get("mission", "")) == mission_id:
			return String(challenge_id)
	return ""


## Acha o desafio ligado a uma missão (busca reversa pelo campo "mission").
## Usado pelo CYBER PHONE para mostrar a dica da missão ativa.
func get_challenge_for_mission(mission_id: String) -> Dictionary:
	for challenge in CHALLENGES.values():
		if String(challenge.get("mission", "")) == mission_id:
			return challenge
	return {}
