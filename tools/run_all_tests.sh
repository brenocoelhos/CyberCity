#!/usr/bin/env bash
# Roda todos os testes tools/verify_*.gd do Cyber City, um por vez, sem abrir
# janela (Godot em modo headless), e mostra um resumo.
#
# Uso (no Git Bash, na pasta do projeto):
#   tools/run_all_tests.sh                    # todos
#   tools/run_all_tests.sh desktop mail       # só os que têm esses nomes
#   GODOT="/caminho/do/Godot.exe" tools/run_all_tests.sh
#
# O Godot é procurado em: variável GODOT, comando "godot" no PATH e na Área de
# Trabalho (Godot_v4.*-stable_win64.exe). Cada teste tem TEMPO_MAX segundos
# (padrão 300). Sai com código 0 se tudo passou e 1 se algo falhou.
#
# Os testes usam arquivos temporários e nunca mexem no save nem no placar do
# jogador.

cd "$(dirname "$0")/.." || exit 2
TEMPO_MAX="${TEMPO_MAX:-300}"

achar_godot() {
	if [ -n "$GODOT" ] && [ -x "$GODOT" ]; then echo "$GODOT"; return; fi
	if command -v godot >/dev/null 2>&1; then command -v godot; return; fi
	local candidato
	for candidato in "$HOME"/Desktop/Godot_v4*-stable_win64.exe "$HOME"/Desktop/Godot*.exe; do
		if [ -x "$candidato" ]; then echo "$candidato"; return; fi
	done
}

GODOT_BIN="$(achar_godot)"
if [ -z "$GODOT_BIN" ]; then
	echo "Godot nao encontrado. Defina GODOT=/caminho/do/Godot.exe e rode de novo."
	exit 2
fi

# Filtro opcional: só os testes cujo nome contém algum dos argumentos.
testes=()
for arquivo in tools/verify_*.gd; do
	nome="$(basename "$arquivo" .gd)"
	if [ "$#" -eq 0 ]; then
		testes+=("$nome")
		continue
	fi
	for filtro in "$@"; do
		case "$nome" in *"$filtro"*) testes+=("$nome"); break ;; esac
	done
done

if [ "${#testes[@]}" -eq 0 ]; then
	echo "Nenhum teste encontrado para: $*"
	exit 2
fi

echo "Godot: $GODOT_BIN"
echo "Rodando ${#testes[@]} teste(s)..."
echo

falhas=()
inicio_geral=$SECONDS
for nome in "${testes[@]}"; do
	inicio=$SECONDS
	saida="$(timeout "$TEMPO_MAX" "$GODOT_BIN" --headless --path . --script "res://tools/$nome.gd" 2>&1)"
	codigo=$?
	duracao=$((SECONDS - inicio))

	motivo=""
	if [ "$codigo" -eq 124 ]; then
		motivo="passou de ${TEMPO_MAX}s (travou?)"
	elif echo "$saida" | grep -qE "SCRIPT ERROR|Parse Error"; then
		motivo="erro de script"
	elif echo "$saida" | grep -qE "^  (FALHA|FAIL)|RESULTADO: FALHOU|^FALHOU"; then
		motivo="verificacao falhou"
	elif [ "$codigo" -ne 0 ]; then
		motivo="codigo de saida $codigo"
	fi

	if [ -z "$motivo" ]; then
		printf "  ok     %-28s %3ss\n" "$nome" "$duracao"
	else
		printf "  FALHA  %-28s %3ss  (%s)\n" "$nome" "$duracao" "$motivo"
		echo "$saida" | grep -E "^  (FALHA|FAIL)|SCRIPT ERROR|Parse Error|RESULTADO|^FALHOU" | head -8 | sed 's/^/           /'
		falhas+=("$nome")
	fi
done

echo
echo "Tempo total: $((SECONDS - inicio_geral))s"
if [ "${#falhas[@]}" -eq 0 ]; then
	echo "TUDO OK: ${#testes[@]} teste(s) passaram."
	exit 0
fi
echo "FALHOU: ${#falhas[@]} de ${#testes[@]}: ${falhas[*]}"
exit 1
