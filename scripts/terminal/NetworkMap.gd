extends RefCounted
## NetworkMap.gd
## Desenha em texto o mapa de uma rede, para o 'scan' mostrar (ferramenta
## liberada no nível 4): a máquina de onde se escaneia em cima, ligada a cada
## máquina encontrada.
##
##            ┌────────────┐
##            │ praca-cent │
##            └─────┬──────┘
##                  │
##      ┌───────────┼───────────┐
##   ┌──┴───┐   ┌───┴──┐   ┌────┴───┐
##   │ web01│   │ db01 │   │gateway │
##   └──────┘   └──────┘   └────────┘
##   192.168.1.30 ...
##
## Só texto (caracteres de desenho de caixa, os mesmos do prompt do terminal).

const GAP := 3


## "source" é o nome da máquina de origem; "nodes" é uma lista de
## {"name": String, "sub": Array de linhas escritas embaixo da caixa}.
static func render(source: String, nodes: Array) -> PackedStringArray:
	var lines := PackedStringArray()
	if nodes.is_empty():
		return lines

	# Posições (coluna da esquerda e do centro) de cada caixa de máquina.
	var lefts: Array[int] = []
	var widths: Array[int] = []  # largura interna (entre as bordas)
	var centers: Array[int] = []
	var x := 0
	for node in nodes:
		var inner: int = String(node["name"]).length()
		for sub_line in node.get("sub", []):
			inner = maxi(inner, String(sub_line).length())
		inner += 2
		lefts.append(x)
		widths.append(inner)
		centers.append(x + (inner + 2) / 2)
		x += inner + 2 + GAP
	var total: int = x - GAP

	# Caixa da máquina de origem, centrada sobre as outras.
	var bus_center: int = (centers[0] + centers[centers.size() - 1]) / 2
	var source_inner: int = source.length() + 2
	var source_total: int = source_inner + 2
	var shift: int = maxi(0, source_total / 2 - bus_center)
	var source_left: int = bus_center + shift - source_total / 2
	total = maxi(total + shift, source_left + source_total)

	var rows: Array = []
	var top: Array = _blank(total)
	var middle: Array = _blank(total)
	var bottom: Array = _blank(total)
	_put(top, source_left, "┌" + "─".repeat(source_inner) + "┐")
	_put(middle, source_left, "│ " + source + " │")
	_put(bottom, source_left, "└" + "─".repeat(source_inner) + "┘")
	bottom[bus_center + shift] = "┬"
	rows.append(top)
	rows.append(middle)
	rows.append(bottom)

	var stem: Array = _blank(total)
	stem[bus_center + shift] = "│"
	rows.append(stem)

	# Barra horizontal que liga a origem às máquinas.
	if nodes.size() > 1:
		var bus: Array = _blank(total)
		for column in range(centers[0] + shift, centers[centers.size() - 1] + shift + 1):
			bus[column] = "─"
		for center in centers:
			bus[center + shift] = "┬"
		bus[centers[0] + shift] = "┌"
		bus[centers[centers.size() - 1] + shift] = "┐"
		var junction: int = bus_center + shift
		bus[junction] = "┼" if bus[junction] == "┬" else "┴"
		rows.append(bus)

	var tops: Array = _blank(total)
	var names: Array = _blank(total)
	var bottoms: Array = _blank(total)
	var most_sub_lines := 0
	for i in range(nodes.size()):
		var left: int = lefts[i] + shift
		var inner: int = widths[i]
		var top_text: String = "┌" + "─".repeat(inner) + "┐"
		# Onde a barra encosta na caixa, a borda ganha o encaixe.
		var center_in_box: int = centers[i] - lefts[i]
		top_text = top_text.substr(0, center_in_box) + "┴" + top_text.substr(center_in_box + 1)
		_put(tops, left, top_text)
		var name_text: String = String(nodes[i]["name"])
		var padding: int = inner - name_text.length()
		_put(names, left, "│" + " ".repeat(padding / 2) + name_text + " ".repeat(padding - padding / 2) + "│")
		_put(bottoms, left, "└" + "─".repeat(inner) + "┘")
		most_sub_lines = maxi(most_sub_lines, Array(nodes[i].get("sub", [])).size())
	rows.append(tops)
	rows.append(names)
	rows.append(bottoms)

	for line_index in range(most_sub_lines):
		var sub_row: Array = _blank(total)
		for i in range(nodes.size()):
			var sub_lines: Array = Array(nodes[i].get("sub", []))
			if line_index < sub_lines.size():
				var text: String = String(sub_lines[line_index])
				var box_width: int = widths[i] + 2
				_put(sub_row, lefts[i] + shift + (box_width - text.length()) / 2, text)
		rows.append(sub_row)

	for row in rows:
		lines.append("".join(row).rstrip(" "))
	return lines


static func _blank(width: int) -> Array:
	var cells: Array = []
	cells.resize(width)
	cells.fill(" ")
	return cells


## Escreve "text" na linha a partir da coluna "start" (ignora o que passar do fim).
static func _put(row: Array, start: int, text: String) -> void:
	for i in range(text.length()):
		var column: int = start + i
		if column >= 0 and column < row.size():
			row[column] = text[i]
