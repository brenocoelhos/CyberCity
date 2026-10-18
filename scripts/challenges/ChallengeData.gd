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

	## Análise de e-mail: o jogador lê um e-mail com cabeçalhos completos e
	## aponta (com 'report') os indícios de fraude. Tipo "report": cada alvo
	## tem palavras-chave; "hit" false é uma isca (campo normal que não prova
	## nada). Termina ao reportar "required" indícios.
	"c_email": {
		"type": "report",
		"title": "Análise de e-mail",
		"mission": "m12",
		"intro": "E-mail suspeito aberto. Leia com 'cat email.eml' e aponte os indícios de fraude com 'report <indício>'. Digite 'report' sozinho para ver o que procurar.",
		"files": {
			"email.eml": "Return-Path: <suporte@empresaa-seguranca.com>\nReceived: from mail.empresaa-seguranca.com (mail.empresaa-seguranca.com [203.0.113.77])\n        by mx.provedor.example with ESMTP id 4f9c2b1a; Tue, 06 Oct 2026 03:12:44 -0300\nAuthentication-Results: mx.provedor.example;\n        spf=fail (domain of empresaa-seguranca.com does not designate 203.0.113.77 as permitted sender);\n        dkim=none;\n        dmarc=fail (p=none) header.from=empresaa-seguranca.com\nFrom: \"Suporte Banco Central\" <suporte@empresaa-seguranca.com>\nReply-To: recuperacao.conta@mail-seguro.example\nTo: vizinha@email.example\nSubject: URGENTE: sua conta sera bloqueada em 24 horas\nDate: Tue, 06 Oct 2026 03:12:40 -0300\nMessage-ID: <20261006031240.77A1@empresaa-seguranca.com>\nContent-Type: text/html; charset=utf-8\n\nPrezado cliente,\n\nDetectamos um acesso suspeito na sua conta. Para evitar o bloqueio,\nconfirme seus dados agora:\n\n   [ Acessar minha conta ]\n   texto exibido:  https://www.bancocentral.example/login\n   destino real:   http://seguranca-bc.example.net/entrar?id=88213\n\nVoce tem apenas 24 horas. Nao compartilhe este e-mail.",
		},
		"required": 3,
		"success_message": "Objetivo cumprido: e-mail identificado como fraude.",
		"targets": [
			{"hit": true, "label": "A autenticação do remetente: o servidor confirma quem enviou?", "keywords": ["spf", "dkim", "dmarc", "authentic", "autentic", "verificacao", "verificação", "assinatura"], "message": "Indício: a autenticação falhou (spf=fail, dkim=none, dmarc=fail). O servidor não consegue confirmar que o remetente é quem diz ser."},
			{"hit": true, "label": "Para onde vai a resposta de quem responder ao e-mail", "keywords": ["reply", "responder", "responde", "resposta"], "message": "Indício: o Reply-To manda a resposta para outro domínio (mail-seguro.example), diferente do remetente. Quem responde fala com o golpista."},
			{"hit": true, "label": "O domínio do remetente: ele é o que parece ser?", "keywords": ["empresaa", "dominio", "domínio", "remetente", "from", "return-path", "parecido", "falso", "imita"], "message": "Indício: o domínio 'empresaa-seguranca.com' imita um nome conhecido (note o 'a' a mais). Domínios parecidos são típicos de phishing."},
			{"hit": true, "label": "O link do corpo: o endereço mostrado é o mesmo do destino real?", "keywords": ["link", "href", "url", "destino", "endereco", "endereço", "clique"], "message": "Indício: o texto do link mostra um endereço, mas o destino real é outro (seguranca-bc.example.net). Sempre confira para onde o link realmente aponta."},
			{"hit": true, "label": "A pressão no texto: o que a mensagem quer que você faça rápido?", "keywords": ["urgen", "24 horas", "prazo", "pressa", "pressao", "pressão", "tempo", "bloque"], "message": "Indício: pressão de tempo ('apenas 24 horas'). É uma técnica clássica de engenharia social para o alvo agir sem pensar."},
			{"hit": false, "keywords": ["message-id", "message id", "date", "data", "to", "content-type"], "message": "Esse campo existe em qualquer e-mail, inclusive nos legítimos. Sozinho ele não prova fraude."},
		],
		"hints": [
			"O e-mail está no computador da Casa 2. Use 'files' e depois 'cat email.eml' para ler tudo, inclusive os cabeçalhos no topo.",
			"Analistas olham quem enviou de verdade, o resultado da autenticação (SPF, DKIM, DMARC), para onde vai a resposta e para onde o link realmente leva. Aponte cada achado com 'report <indício>'.",
			"Procure: o Authentication-Results com falha, o Reply-To em outro domínio, o domínio 'empresaa' parecido com o verdadeiro, o link cujo destino real é outro e o prazo de 24 horas.",
		],
		"explanation": "Um e-mail fraudulento costuma se denunciar nos cabeçalhos: SPF, DKIM e DMARC reprovados (o servidor não confirma o remetente), Reply-To em outro domínio, domínio parecido com o real, link cujo destino difere do texto e pressão de tempo. Antes de clicar, confira o remetente real, os cabeçalhos de autenticação e para onde o link realmente aponta.",
	},

	## Triagem de caixa de entrada: seis mensagens, três golpes. O jogador
	## reporta pelo número. Reportar uma mensagem legítima conta como erro.
	## Uma das fraudes passa na autenticação (SPF=pass, vem de um e-mail
	## pessoal) e uma legítima tem prazo: o conjunto é que decide.
	"c_triagem": {
		"type": "report",
		"title": "Phishing em massa",
		"mission": "m13",
		"intro": "Caixa de entrada com 6 mensagens. Leia 'cat inbox.txt', abra cada uma com 'cat msg1.eml' etc. e aponte os golpes com 'report <número>'. Digite 'report' sozinho para ver quantos faltam.",
		"files": {
			"inbox.txt": "CAIXA DE ENTRADA — morador@email.example\n\n 1  rastreio@correios-entrega.example      Sua encomenda foi retida\n 2  avisos@meubanco.example                Sua fatura fechou\n 3  roberto.mendes.diretor@gmail.example   Preciso de um favor urgente\n 4  ana.souza@techcorp.example             Reunião de equipe amanhã\n 5  ti-suporte@techcorp-sistemas.example   Sua senha expira hoje\n 6  newsletter@seguranca.example           Dicas da semana\n\n(abra cada mensagem com 'cat msg1.eml', 'cat msg2.eml'...)",
			"msg1.eml": "From: \"Correios\" <rastreio@correios-entrega.example>\nTo: morador@email.example\nSubject: Sua encomenda foi retida\nAuthentication-Results: spf=fail smtp.mailfrom=correios-entrega.example; dkim=none; dmarc=fail\nDate: Wed, 07 Oct 2026 08:02:11 -0300\n\nSua encomenda BR123456789 esta retida na alfandega.\nPague a taxa de R$ 12,40 hoje para liberar a entrega:\n\n   texto exibido:  https://www.correios.example/rastreio\n   destino real:   http://taxa-correios.example.net/pagar\n\nSe nao pagar em 24 horas ela sera devolvida ao remetente.",
			"msg2.eml": "From: \"Meu Banco\" <avisos@meubanco.example>\nTo: morador@email.example\nSubject: Sua fatura fechou\nAuthentication-Results: spf=pass smtp.mailfrom=meubanco.example; dkim=pass; dmarc=pass\nDate: Wed, 07 Oct 2026 07:30:00 -0300\n\nSua fatura de outubro fechou em R$ 842,10, com vencimento em 15/10.\nEla ja esta disponivel no aplicativo.\n\n   texto exibido:  https://meubanco.example/fatura\n   destino real:   https://meubanco.example/fatura\n\nEste aviso nunca pede senha, codigos ou dados do cartao.",
			"msg3.eml": "From: \"Roberto Mendes (Diretor)\" <roberto.mendes.diretor@gmail.example>\nTo: morador@email.example\nSubject: Preciso de um favor urgente\nAuthentication-Results: spf=pass smtp.mailfrom=gmail.example; dkim=pass; dmarc=pass\nDate: Wed, 07 Oct 2026 09:15:40 -0300\n\nEstou em reuniao e nao posso falar. Preciso que voce compre 5 cartoes-presente\nde R$ 200 agora e me envie os codigos por aqui. E confidencial, nao comente\ncom ninguem. Depois eu te reembolso.",
			"msg4.eml": "From: \"Ana Souza\" <ana.souza@techcorp.example>\nTo: morador@email.example\nSubject: Reuniao de equipe amanha\nAuthentication-Results: spf=pass smtp.mailfrom=techcorp.example; dkim=pass; dmarc=pass\nDate: Tue, 06 Oct 2026 17:40:02 -0300\n\nOi! Lembrando da reuniao de equipe amanha, 10h, na sala 2.\nPauta: revisao de acessos. Ate la!",
			"msg5.eml": "From: \"TI Suporte\" <ti-suporte@techcorp-sistemas.example>\nTo: morador@email.example\nSubject: Sua senha expira hoje\nAuthentication-Results: spf=fail smtp.mailfrom=techcorp-sistemas.example; dkim=none; dmarc=fail\nDate: Wed, 07 Oct 2026 10:01:55 -0300\n\nSua senha de rede expira hoje as 18h. Para manter o acesso, confirme sua\nsenha atual:\n\n   texto exibido:  https://intranet.techcorp.example/senha\n   destino real:   http://techcorp-login.example.net/confirmar\n\nNao responda a este e-mail.",
			"msg6.eml": "From: \"Boletim Seguranca\" <newsletter@seguranca.example>\nTo: morador@email.example\nSubject: Dicas da semana: verificacao em duas etapas\nAuthentication-Results: spf=pass smtp.mailfrom=seguranca.example; dkim=pass; dmarc=pass\nDate: Mon, 05 Oct 2026 08:00:00 -0300\n\nEsta semana: como ativar a verificacao em duas etapas nas suas contas.\n\n   Leia no site:   https://seguranca.example/dicas\n   Para sair da lista: https://seguranca.example/sair",
		},
		"report_help": "Aponte cada golpe pelo número da mensagem: report <número>. Reportar uma mensagem legítima conta como erro.",
		"success_message": "Objetivo cumprido: os três golpes foram identificados.",
		"targets": [
			{"hit": true, "label": "Um dos golpes (aponte pelo número da mensagem)", "found_label": "Golpe: mensagem 1", "keywords": ["1", "msg1", "mensagem 1", "mensagem1"], "message": "Golpe: a taxa de 'encomenda retida' vem de um domínio parecido com o dos Correios (spf=fail), o link leva a outro site e há prazo de 24 horas. Os Correios não cobram taxa por link de e-mail."},
			{"hit": false, "keywords": ["2", "msg2", "mensagem 2", "mensagem2"], "message": "Essa é legítima: autenticação aprovada (spf, dkim e dmarc passaram), o link leva ao domínio oficial e a mensagem não pede senha. Ter um vencimento não torna uma mensagem golpe."},
			{"hit": true, "label": "Um dos golpes (aponte pelo número da mensagem)", "found_label": "Golpe: mensagem 3", "keywords": ["3", "msg3", "mensagem 3", "mensagem3"], "message": "Golpe (fraude do 'chefe'): passou na autenticação, mas vem de um e-mail pessoal e pede cartões-presente com sigilo e urgência. SPF aprovado só prova que o e-mail veio do gmail, não que o diretor o enviou."},
			{"hit": false, "keywords": ["4", "msg4", "mensagem 4", "mensagem4"], "message": "Essa é legítima: remetente interno com autenticação aprovada, sem link e sem pedir nada fora do normal."},
			{"hit": true, "label": "Um dos golpes (aponte pelo número da mensagem)", "found_label": "Golpe: mensagem 5", "keywords": ["5", "msg5", "mensagem 5", "mensagem5"], "message": "Golpe: o domínio 'techcorp-sistemas' imita o da empresa (spf=fail), o link real é outro site e a mensagem pede a sua senha atual. O TI de verdade nunca pede senha por e-mail."},
			{"hit": false, "keywords": ["6", "msg6", "mensagem 6", "mensagem6"], "message": "Essa é legítima: boletim com autenticação aprovada e links para o próprio domínio."},
		],
		"hints": [
			"A caixa de entrada está no computador da Casa 3. Use 'cat inbox.txt' e abra cada mensagem com 'cat msg1.eml', 'cat msg2.eml'...",
			"Compare o remetente, o resultado da autenticação, para onde o link realmente leva e o que a mensagem pede (dinheiro, senha, urgência). Aponte o golpe com 'report <número>'.",
			"São três golpes: uma taxa de encomenda, um 'diretor' pedindo cartões-presente de um e-mail pessoal e um aviso de senha expirando num domínio parecido com o da empresa. Cuidado: nem toda mensagem com prazo é golpe.",
		],
		"explanation": "Golpes de phishing combinam um pretexto (encomenda, banco, chefe, TI), pressa e um link ou pedido fora do normal. Confira o domínio do remetente e do link, desconfie de pedidos de dinheiro, cartões ou senha e lembre que um e-mail pode passar na autenticação (SPF) e ainda ser golpe, como um 'diretor' escrevendo de um e-mail pessoal. Mensagens legítimas também têm prazos: o que decide é o conjunto de sinais.",
	},

	## Pós-vazamento (visão do defensor): um site vazou senhas, o morador usa
	## a mesma senha no e-mail e alguém entrou. O jogador filtra o log com
	## 'grep' e reporta o que achou (reuso, IP, regra de encaminhamento,
	## defesas). Tipo "report", 4 de 5 achados concluem.
	"c_vazamento": {
		"type": "report",
		"title": "Senha reutilizada",
		"mission": "m14",
		"intro": "Aviso de vazamento recebido. Veja os arquivos com 'ls', filtre o log com 'grep <termo> acessos_email.log' e aponte o que achar com 'report <achado>'. Digite 'report' sozinho para ver o que procurar.",
		"files": {
			"aviso_vazamento.txt": "De: seguranca@lojafacil.example\nAssunto: Incidente de seguranca na LojaFacil\n\nIdentificamos o acesso indevido a uma copia do nosso cadastro de clientes em\n03/10/2026. Foram expostos e-mails e senhas (armazenadas com hash MD5, sem sal).\nRecomendamos trocar a senha da LojaFacil e de qualquer outro servico em que\nvoce use a mesma senha.\n\nO arquivo vazamento_lojafacil.csv e a copia publicada pelo atacante.",
			"vazamento_lojafacil.csv": "email,hash_md5\ncarla@email.example,1953bef677244526d9339560a87cf3b9\njose@email.example,2a1aee4c85e9ad481947a90068242404\nmarcos@email.example,159e70e5dfbf44e74b2b20257657db3c\npaula@email.example,893969410d5dc7a880a225e68b0ed3b3",
			"acessos_email.log": "2026-10-04 19:02:11 LOGIN OK    user=marcos@email.example ip=198.51.100.23 (Brasil) agent=Firefox\n2026-10-05 07:45:30 LOGIN OK    user=marcos@email.example ip=198.51.100.23 (Brasil) agent=Firefox\n2026-10-06 03:12:50 LOGIN FAIL  user=carla@email.example ip=203.0.113.45 (Romenia) agent=python-requests\n2026-10-06 03:12:51 LOGIN FAIL  user=jose@email.example ip=203.0.113.45 (Romenia) agent=python-requests\n2026-10-06 03:12:52 LOGIN FAIL  user=paula@email.example ip=203.0.113.45 (Romenia) agent=python-requests\n2026-10-06 03:12:53 LOGIN OK    user=marcos@email.example ip=203.0.113.45 (Romenia) agent=python-requests\n2026-10-06 03:13:04 RULE        user=marcos@email.example action=forward_all to=coleta.dados@mail-seguro.example by_ip=203.0.113.45\n2026-10-06 03:13:20 LOGOUT      user=marcos@email.example ip=203.0.113.45\n2026-10-06 07:50:01 LOGIN OK    user=marcos@email.example ip=198.51.100.23 (Brasil) agent=Firefox",
			"conta.txt": "Conta: marcos@email.example\nVerificacao em duas etapas: DESATIVADA\nUltima troca de senha: 12/03/2024\nRegras de encaminhamento ativas: 1",
			"lembretes.txt": "Lembretes do Marcos\n\nMinha senha de tudo: marcos2020\n(e a mesma em todo lugar, assim eu nunca esqueco)",
		},
		"required": 4,
		"success_message": "Objetivo cumprido: o ataque foi entendido e as defesas apontadas.",
		"targets": [
			{"hit": true, "label": "O hábito de senha do morador que tornou o ataque possível", "keywords": ["reuso", "reutiliz", "mesma senha", "repetid", "repetir", "credential", "stuffing", "igual"], "message": "Achado: a senha vazada na LojaFácil era a mesma do e-mail. Reutilizar senhas é o que transforma um vazamento num site em invasão em outros (credential stuffing)."},
			{"hit": true, "label": "Quem atacou: o endereço de onde veio o acesso estranho", "keywords": ["203.0.113.45", "romenia", "romênia", "atacante", "invasor", "python", "outro pais", "outro país"], "message": "Achado: esse IP, de outro país e com um programa (python-requests), tentou várias contas em 3 segundos e entrou na do Marcos. Não é o IP habitual dele."},
			{"hit": true, "label": "O que o invasor deixou configurado para continuar recebendo os e-mails", "keywords": ["encaminh", "regra", "forward", "redirec", "persist", "coleta"], "message": "Achado: logo após entrar, o invasor criou uma regra que encaminha todos os e-mails para um endereço dele. Mesmo trocando a senha, ele continuaria recebendo tudo: a regra também precisa ser removida."},
			{"hit": true, "label": "A defesa que barraria o login mesmo com a senha certa", "keywords": ["2fa", "mfa", "fator", "etapa", "verificacao", "verificação", "token"], "message": "Defesa: com a verificação em duas etapas, a senha certa sozinha não bastaria para entrar. É a medida que mais reduz esse tipo de ataque."},
			{"hit": true, "label": "A prática de senhas que evitaria que um vazamento atingisse outros serviços", "keywords": ["gerenciador", "senha unica", "senha única", "senhas diferentes", "senha diferente", "cofre", "unica", "única"], "message": "Defesa: uma senha única por serviço (com a ajuda de um gerenciador de senhas) faz o vazamento de um site não afetar os outros."},
			{"hit": false, "keywords": ["198.51.100.23", "ip do marcos", "ip habitual"], "message": "Esse é o IP habitual do Marcos (Brasil, Firefox): são logins normais dele, não o ataque."},
		],
		"hints": [
			"Os arquivos estão no computador da Casa 4. Use 'ls' e leia o aviso de vazamento ('cat aviso_vazamento.txt') e depois o log de acessos do e-mail (acessos_email.log).",
			"Use 'grep <termo> acessos_email.log' para filtrar o log. Procure quem não é o Marcos: IP, país, programa usado e o que foi feito depois do login. Compare com o que ele anotou em lembretes.txt. Aponte cada achado com 'report <achado>'.",
			"Procure: um IP de outro país que tentou várias contas e entrou numa delas, uma regra criada logo depois do login e a mesma senha usada em vários serviços. Pense também no que impediria o login mesmo com a senha certa.",
		],
		"explanation": "Quando um site vaza senhas, os atacantes testam as mesmas combinações de e-mail e senha em outros serviços: é o credential stuffing, e só dá certo porque muita gente reutiliza a senha. Depois de entrar, costumam criar regras de encaminhamento para manter acesso mesmo se a senha for trocada. Use uma senha diferente em cada serviço (com um gerenciador de senhas), ative a verificação em duas etapas e revise as regras da conta depois de qualquer suspeita.",
	},

	## Teste de invasão autorizado em cadeia (visão do atacante). Tipo "hosts":
	## máquinas simuladas ("hosts") com portas, usuários, arquivos e páginas.
	## Não há etapas na tela: o que se descobre numa máquina libera a próxima.
	## "guidance" 1 por enquanto (a abertura cita as ferramentas): é o desafio
	## mais difícil e o jogo ainda não ensinou todas as peças antes dele. Quando
	## a rampa de missões estiver testada, pode subir para 2 ou 3.
	## "win_file": ler esse arquivo naquela máquina captura a flag;
	## "final_report": depois disso o jogador entrega o 'relatorio'.
	"c_cadeia": {
		"type": "hosts",
		"title": "Orion Logística",
		"mission": "m15",
		"guidance": 1,
		"intro": "Terminal de teste de invasão aberto. O escopo autorizado está em notas_pentest.txt. Ferramentas: 'scan' (mapear a rede), 'curl <endereço>' (ver páginas), 'ssh usuário@máquina' (entrar), 'ls -a' (listar inclusive arquivos ocultos) e 'relatorio' (entregar no fim).",
		"files": {
			"notas_pentest.txt": "TESTE DE INVASAO AUTORIZADO — Orion Logistica\n\nEscopo autorizado: 192.168.1.30 (web01) e 192.168.1.40 (db01)\nFORA DO ESCOPO: 192.168.1.1 (gateway) e qualquer outro sistema\n\nObjetivo: chegar a flag do servidor de banco de dados e documentar o caminho.\nRegra: somente leitura. Nao altere nem apague nada.",
		},
		"hosts": {
			"web01": {
				"ip": "192.168.1.30",
				"ports": "22/ssh  80/http",
				"scope": true,
				"users": {"deploy": "Orion@2023"},
				"web": {
					"/": "Orion Logistica - Portal de Rastreamento\n(site em construcao)",
					"/robots.txt": "User-agent: *\nDisallow: /backup/",
					"/backup/": "Index of /backup/\n  config.old    2.1K    2023-05-14",
					"/backup/config.old": "# configuracao antiga do deploy (nao apagar)\nssh_user=deploy\nssh_pass=Orion@2023",
				},
				"files": {
					"leiame.txt": "Servidor web da Orion. Deploy feito pelo usuario deploy.\nO acesso ao banco usa o usuario reports (mesma senha na maquina db01).",
					".pgpass": "192.168.1.40:5432:orion:reports:Rep0rt#db",
				},
			},
			"db01": {
				"ip": "192.168.1.40",
				"ports": "22/ssh  5432/postgres",
				"scope": true,
				"users": {"reports": "Rep0rt#db"},
				"files": {
					"clientes_export.csv": "id,cliente,cidade\n1,Mercado Aurora,Recife\n2,Farmacia Sol,Natal\n3,Casa Verde,Fortaleza",
					"flag.txt": "FLAG{orion-db01-a8f3}",
				},
			},
			"gateway": {
				"ip": "192.168.1.1",
				"ports": "53/dns  80/http",
				"scope": false,
				"users": {},
				"files": {},
			},
		},
		"win_file": {"host": "db01", "file": "flag.txt"},
		"final_report": true,
		"report_findings": [
			"O site expunha um diretório de backup (/backup/) citado no robots.txt, com a configuração antiga do deploy.",
			"Essa configuração tinha o usuário e a senha do SSH do web01 em texto puro.",
			"O web01 guardava a senha do banco no arquivo oculto .pgpass, e a mesma senha servia no db01 (reutilização).",
			"O banco de dados com os dados dos clientes ficou acessível a partir do servidor web (sem segmentação de rede).",
		],
		"report_recommendations": [
			"Remover o diretório /backup/ do site e não listar arquivos sensíveis no robots.txt.",
			"Nunca guardar credenciais em arquivos de configuração acessíveis; usar um cofre de segredos.",
			"Usar senhas diferentes por sistema e chaves SSH em vez de senha.",
			"Separar a rede do banco de dados da do servidor web e limitar quem pode acessá-lo.",
		],
		"success_message": "Objetivo cumprido: o teste de invasão foi concluído e documentado.",
		"hints": [
			"Comece lendo as notas do teste ('cat notas_pentest.txt') e mapeando a rede com 'scan'. Só ataque o que está no escopo autorizado.",
			"Sites costumam esconder arquivos esquecidos: use 'curl' nas páginas do site e olhe o robots.txt. Uma credencial achada num lugar costuma abrir outro (ssh). Dentro de uma máquina, 'ls -a' mostra também os arquivos ocultos.",
			"O caminho: o robots.txt do web01 aponta um diretório de backup com uma configuração antiga e uma senha; com ela você entra no web01; lá um arquivo oculto guarda a senha do banco, que também vale no db01. A flag está no db01. Depois entregue o 'relatorio'.",
		],
		"explanation": "Um teste de invasão segue o caminho de um atacante real, mas só dentro do escopo autorizado: reconhecimento, descoberta de um arquivo esquecido, uso de credenciais expostas, reutilização de senha entre sistemas (movimento lateral) e, no fim, um relatório com achados e recomendações. Os problemas foram um backup acessível pela web, credenciais em texto puro, senha reutilizada e falta de segmentação entre o servidor web e o banco.",
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
