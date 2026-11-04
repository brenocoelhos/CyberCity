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


static func _sub(text: String, pattern: String, replacement: String) -> String:
	var rx := RegEx.new()
	if rx.compile(pattern) != OK:
		push_warning("HtmlLite: expressão inválida: " + pattern)
		return text
	return rx.sub(text, replacement, true)
