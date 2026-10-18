extends RefCounted
## StudyTools.gd
## Funções de apoio de estudo, as mesmas que um analista usa no dia a dia:
## decifrar/cifrar César, calcular hash e checar a força de uma senha. Usadas
## pelo app "Ferramentas" do celular e pelo terminal. Só lógica, sem tela.

const DEFAULT_MIN_LENGTH := 10
const OBVIOUS_WORDS := ["admin", "senha", "1234"]


## Cifra de César: desloca cada letra "shift" posições (negativo = volta).
## Mantém maiúsculas/minúsculas e deixa o resto (números, símbolos) como está.
static func caesar(text: String, shift: int) -> String:
	var result := ""
	for character in text:
		var code: int = character.unicode_at(0)
		if code >= 65 and code <= 90:
			result += char(65 + posmod(code - 65 + shift, 26))
		elif code >= 97 and code <= 122:
			result += char(97 + posmod(code - 97 + shift, 26))
		else:
			result += character
	return result


static func md5(text: String) -> String:
	return text.md5_text()


static func sha256(text: String) -> String:
	return text.sha256_text()


## O que falta para a senha ser forte (lista vazia = forte): tamanho, letras,
## número, símbolo e palavras óbvias. "obvious" são palavras extras a evitar
## (ex.: a senha de fábrica de um equipamento).
static func password_problems(password: String, min_length: int = DEFAULT_MIN_LENGTH, obvious: Array = []) -> PackedStringArray:
	var problems := PackedStringArray()
	if password.length() < min_length:
		problems.append("precisa ter pelo menos %d caracteres" % min_length)

	var has_letter := false
	var has_digit := false
	var has_symbol := false
	for character in password:
		if character.to_upper() != character.to_lower():
			has_letter = true
		elif "0123456789".contains(character):
			has_digit = true
		elif character != " ":
			has_symbol = true
	if not has_letter:
		problems.append("precisa de letras")
	if not has_digit:
		problems.append("precisa de pelo menos um número")
	if not has_symbol:
		problems.append("precisa de pelo menos um símbolo (como ! # $ %)")

	var lowered: String = password.to_lower()
	var words: Array = obvious.duplicate()
	words.append_array(OBVIOUS_WORDS)
	for word in words:
		if String(word) != "" and lowered.contains(String(word).to_lower()):
			problems.append("não use palavras óbvias como '%s'" % String(word))
			break
	return problems


## "forte" (nada a corrigir), "média" (1 problema) ou "fraca".
static func password_strength(password: String) -> String:
	if password == "":
		return ""
	var count: int = password_problems(password).size()
	if count == 0:
		return "forte"
	return "média" if count == 1 else "fraca"
