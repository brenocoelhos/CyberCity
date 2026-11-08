extends RefCounted
## MailParser.gd
## Lê um e-mail guardado como texto (cabeçalhos, linha em branco, corpo) e
## separa o que o app de E-mail mostra: remetente, assunto, data, os cabeçalhos
## completos e o corpo. Entende cabeçalhos em inglês (From, Subject, Date, To) e
## em português (De, Assunto), e linhas de continuação (começam com espaço).


## {file, number, from, to, subject, date, headers, body}. "number" é o número
## que o jogador usa para apontar a mensagem: os dígitos do nome do arquivo
## (msg3.eml -> 3), ou "fallback" se o nome não tem número.
static func parse(file_name: String, text: String, fallback: int = 0) -> Dictionary:
	var parts: PackedStringArray = text.split("\n\n", true, 1)
	var head: String = parts[0]
	var body: String = parts[1].strip_edges() if parts.size() > 1 else ""

	var fields: Dictionary = {}
	var last := ""
	for line in head.split("\n"):
		if line.begins_with(" ") or line.begins_with("\t"):
			if last != "":
				fields[last] = String(fields[last]) + " " + line.strip_edges()
			continue
		var colon: int = line.find(":")
		if colon > 0:
			last = line.substr(0, colon).strip_edges().to_lower()
			fields[last] = line.substr(colon + 1).strip_edges()

	return {
		"file": file_name,
		"number": _number_of(file_name, fallback),
		"from": String(fields.get("from", fields.get("de", ""))),
		"to": String(fields.get("to", fields.get("para", ""))),
		"subject": String(fields.get("subject", fields.get("assunto", "(sem assunto)"))),
		"date": String(fields.get("date", fields.get("data", ""))),
		"headers": head,
		"body": body,
	}


## Só o nome do remetente ("Correios" em "\"Correios\" <rastreio@...>"); sem
## nome, o endereço inteiro.
static func sender_name(from_field: String) -> String:
	var text: String = from_field.strip_edges()
	var open: int = text.find("<")
	if open > 0:
		return text.substr(0, open).strip_edges().trim_prefix("\"").trim_suffix("\"")
	return text


static func _number_of(file_name: String, fallback: int) -> int:
	var digits := ""
	for character in file_name:
		if character >= "0" and character <= "9":
			digits += character
	return int(digits) if digits != "" else fallback
