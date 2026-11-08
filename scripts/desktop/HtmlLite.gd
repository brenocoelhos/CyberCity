extends RefCounted
## HtmlLite.gd
## Transforma o HTML simples das páginas dos desafios em BBCode para o
## RichTextLabel do navegador. Entende só o básico: títulos, parágrafos,
## listas, links e quebras de linha. Comentários (<!-- -->) e o <head> ficam
## fora da página mostrada (só aparecem em "Código-fonte").

const LINK_COLOR := "#0b5cd5"


## True se o texto parece uma página HTML (e não texto puro, como robots.txt).
static func looks_like_html(text: String) -> bool:
	var lower: String = text.strip_edges().to_lower()
	for start in ["<html", "<!doctype", "<body", "<h1", "<p>"]:
		if lower.begins_with(start):
			return true
	return false


## Texto do <title> ("" se a página não tem).
static func title_of(html: String) -> String:
	var rx := RegEx.new()
	rx.compile("(?is)<title[^>]*>(.*?)</title>")
	var found: RegExMatch = rx.search(html)
	return "" if found == null else found.get_string(1).strip_edges()


## Escapa colchetes para o texto não virar BBCode.
static func escape(text: String) -> String:
	return text.replace("[", "[lb]")


## HTML -> BBCode.
static func render(html: String) -> String:
	var s: String = html
	s = _sub(s, "(?s)<!--.*?-->", "")
	s = _sub(s, "(?is)<head[^>]*>.*?</head>", "")
	s = _sub(s, "(?is)<script[^>]*>.*?</script>", "")
	s = _sub(s, "(?is)<style[^>]*>.*?</style>", "")
	s = escape(s)
	s = _sub(s, "(?m)^[ \t]+", "")
	s = _sub(s, "(?is)<h1[^>]*>(.*?)</h1>", "\n[font_size=30][b]$1[/b][/font_size]\n")
	s = _sub(s, "(?is)<h2[^>]*>(.*?)</h2>", "\n[font_size=24][b]$1[/b][/font_size]\n")
	s = _sub(s, "(?is)<h3[^>]*>(.*?)</h3>", "\n[font_size=19][b]$1[/b][/font_size]\n")
	s = _sub(s, "(?is)<a\\s[^>]*href\\s*=\\s*[\"']([^\"']*)[\"'][^>]*>(.*?)</a>", "[url=$1][color=%s][u]$2[/u][/color][/url]" % LINK_COLOR)
	s = _sub(s, "(?is)<li[^>]*>", "  • ")
	s = _sub(s, "(?is)</li>", "\n")
	s = _sub(s, "(?is)<br\\s*/?>", "\n")
	s = _sub(s, "(?is)</(p|div|tr|ul|ol|table)>", "\n\n")
	s = _sub(s, "(?is)<[^>]+>", "")
	s = s.replace("&nbsp;", " ").replace("&lt;", "<").replace("&gt;", ">").replace("&quot;", "\"").replace("&amp;", "&")
	s = _sub(s, "\n{3,}", "\n\n")
	return s.strip_edges()


## Divide a página em blocos, na ordem em que aparecem: {"type": "text",
## "html": ...} para o que é texto e {"type": "form", "action", "method",
## "fields": [{name, kind ("text"|"password"|"textarea"|"hidden"), label,
## placeholder, value}], "submit": texto do botão} para cada <form>. Sem
## formulário, devolve um bloco só, com a página inteira.
static func blocks(html: String) -> Array:
	var out: Array = []
	var rx := RegEx.new()
	rx.compile("(?is)<form\\b([^>]*)>(.*?)</form>")
	var position := 0
	for found in rx.search_all(html):
		out.append({"type": "text", "html": html.substr(position, found.get_start() - position)})
		out.append(_parse_form(found.get_string(1), found.get_string(2)))
		position = found.get_end()
	out.append({"type": "text", "html": html.substr(position)})
	return out


static func _parse_form(form_attributes: String, inner: String) -> Dictionary:
	var form := {
		"type": "form",
		"action": _attribute(form_attributes, "action"),
		"method": _attribute(form_attributes, "method").to_lower(),
		"fields": [],
		"submit": "Enviar",
	}
	var rx := RegEx.new()
	rx.compile("(?is)<label\\b[^>]*>(.*?)</label>|<input\\b([^>]*)>|<textarea\\b([^>]*)>(.*?)</textarea>|<button\\b([^>]*)>(.*?)</button>")
	var pending_label := ""
	for found in rx.search_all(inner):
		if found.get_string(1) != "":
			pending_label = found.get_string(1).strip_edges()
		elif found.get_string(2) != "":
			var attributes: String = found.get_string(2)
			var input_type: String = _attribute(attributes, "type").to_lower()
			if input_type == "submit":
				form["submit"] = _attribute(attributes, "value") if _attribute(attributes, "value") != "" else "Enviar"
				continue
			form["fields"].append({
				"name": _attribute(attributes, "name"),
				"kind": input_type if input_type in ["password", "hidden"] else "text",
				"label": pending_label,
				"placeholder": _attribute(attributes, "placeholder"),
				"value": _attribute(attributes, "value"),
			})
			pending_label = ""
		elif found.get_string(3) != "":
			form["fields"].append({
				"name": _attribute(found.get_string(3), "name"),
				"kind": "textarea",
				"label": pending_label,
				"placeholder": _attribute(found.get_string(3), "placeholder"),
				"value": found.get_string(4).strip_edges(),
			})
			pending_label = ""
		elif found.get_string(6) != "":
			form["submit"] = found.get_string(6).strip_edges()
	return form


## Valor de um atributo (name="valor" ou name='valor') numa tag; "" se não tem.
static func _attribute(attributes: String, attribute_name: String) -> String:
	var rx := RegEx.new()
	rx.compile("(?is)\\b" + attribute_name + "\\s*=\\s*(?:\"([^\"]*)\"|'([^']*)')")
	var found: RegExMatch = rx.search(attributes)
	if found == null:
		return ""
	return found.get_string(1) if found.get_string(1) != "" else found.get_string(2)


static func _sub(text: String, pattern: String, replacement: String) -> String:
	var rx := RegEx.new()
	if rx.compile(pattern) != OK:
		push_warning("HtmlLite: expressão inválida: " + pattern)
		return text
	return rx.sub(text, replacement, true)
