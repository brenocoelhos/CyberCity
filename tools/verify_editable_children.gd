extends SceneTree
## Verifica que nenhuma cena muda nós DENTRO de uma instância sem marcar a
## instância como "Filhos Editáveis" (linha [editable path="..."] no .tscn).
##
## Por quê: no editor (e nos outros testes) essas mudanças funcionam, mas a
## exportação para .exe as descarta. Foi o que travou a campanha no .exe: o
## morador da Casa 1 saía sem falas e sem a m01, e funcionários, o Guia da
## Praça e os nomes/visual dos computadores voltavam ao padrão.
##
## Como corrigir uma falha deste teste: no Godot, abra a cena, clique com o
## botão direito no nó citado e marque "Filhos Editáveis"; depois salve.
## Rodar: Godot --headless --path . --script res://tools/verify_editable_children.gd
## Sai com código 0 se tudo passar e 1 se algo falhar.

const SCENES_DIR := "res://scenes"


func _initialize() -> void:
	var ok := true
	var scenes := _find_scenes(SCENES_DIR)
	ok = _check("encontrou as cenas do jogo (%d)" % scenes.size(), scenes.size() > 10) and ok
	var checked := 0
	for path in scenes:
		var missing := _missing_editable(FileAccess.get_file_as_string(path))
		if not missing.is_empty():
			ok = _check("%s: marcar como Filhos Editáveis: %s" % [path.get_file(), ", ".join(missing)], false) and ok
		checked += 1
	ok = _check("toda mudança dentro de instância tem [editable] (%d cenas)" % checked, ok) and ok
	# O próprio verificador acusa o caso que quebrou o .exe (e aceita o certo).
	var broken := "[gd_scene format=3]\n[node name=\"Casa\" type=\"Node2D\"]\n[node name=\"Morador\" parent=\".\" instance=ExtResource(\"1\")]\n[node name=\"Interaction\" parent=\"Morador\"]\nmission_to_start = \"m01\"\n"
	ok = _check("verificador acusa a cena sem [editable]", _missing_editable(broken) == PackedStringArray(["Morador"])) and ok
	ok = _check("verificador aceita a cena com [editable]", _missing_editable(broken + "\n[editable path=\"Morador\"]\n").is_empty()) and ok
	print("RESULTADO: ", "TUDO OK" if ok else "FALHOU")
	quit(0 if ok else 1)


## Instâncias que têm nós de dentro alterados sem a linha [editable].
func _missing_editable(text: String) -> PackedStringArray:
	var instances: Array[String] = []
	var needed: Array[String] = []
	var editable: Array[String] = []
	for line in text.split("\n"):
		line = line.strip_edges()
		if line.begins_with("[editable "):
			editable.append(_attr(line, "path"))
			continue
		if not line.begins_with("[node "):
			continue
		var name := _attr(line, "name")
		var parent := _attr(line, "parent")
		if parent == "":
			continue  # raiz da cena
		var node_path := name if parent == "." else parent + "/" + name
		if line.contains(" instance="):
			instances.append(node_path)
		elif not line.contains(" type="):
			# Sem tipo e sem instância: altera um nó que já existe dentro de
			# uma instância. A instância é a mais funda que contém o "parent".
			var owner_instance := ""
			for inst in instances:
				if (parent == inst or parent.begins_with(inst + "/")) and inst.length() > owner_instance.length():
					owner_instance = inst
			if owner_instance != "" and not needed.has(owner_instance):
				needed.append(owner_instance)
	var missing := PackedStringArray()
	for inst in needed:
		if not editable.has(inst):
			missing.append(inst)
	return missing


func _attr(line: String, key: String) -> String:
	var start := line.find(key + "=\"")
	if start == -1:
		return ""
	start += key.length() + 2
	return line.substr(start, line.find("\"", start) - start)


func _find_scenes(dir_path: String) -> Array[String]:
	var found: Array[String] = []
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return found
	for file in dir.get_files():
		if file.ends_with(".tscn"):
			found.append(dir_path.path_join(file))
	for sub in dir.get_directories():
		found.append_array(_find_scenes(dir_path.path_join(sub)))
	return found


func _check(label: String, cond: bool) -> bool:
	print(("  ok   " if cond else "  FAIL ") + label)
	return cond
