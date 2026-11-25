#!/bin/sh
# Copia os MP3 das vozes (baixados do ElevenLabs) da pasta Downloads para
# assets/audio/voices/<personagem>/, com o mesmo nome que o jogo espera.
# Uso (na pasta do projeto):  sh tools/importar_vozes.sh [pasta_de_origem]
ORIGEM="${1:-$HOME/Downloads}"
total=0
for arq in "$ORIGEM"/*.mp3; do
  [ -e "$arq" ] || continue
  nome=$(basename "$arq")
  case "$nome" in
    campanha_*) pasta=narrador_campanha ;;
    npc_nao_pronto_*) pasta=npc_comum ;;
    guia_praca_*|casa_0?_*|techcorp_funcionario_*|centro_pesquisadora_*|loja_desenvolvedora_*|sistema_boss_*|boss_hacker_*)
      pasta=$(echo "$nome" | sed 's/_[0-9]*\.mp3$//') ;;
    central_*) pasta=central ;;
    *) continue ;;
  esac
  [ -d "assets/audio/voices/$pasta" ] || continue
  cp -f "$arq" "assets/audio/voices/$pasta/$nome" && total=$((total+1))
done
echo "$total arquivos copiados. Abra o projeto no Godot para ele importar os audios novos."
