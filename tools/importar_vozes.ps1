# Copia os MP3 das vozes (baixados do ElevenLabs) da pasta Downloads para
# assets/audio/voices/<personagem>/, com o mesmo nome que o jogo espera.
# Uso (PowerShell, na pasta do projeto):  .\tools\importar_vozes.ps1
# Opcional: .\tools\importar_vozes.ps1 -Origem "D:\minhas_vozes"
param([string]$Origem = "$HOME\Downloads")
$pastas = @{
  "guia_praca_" = "guia_praca"; "casa_01_morador_" = "casa_01_morador"; "casa_02_vizinha_" = "casa_02_vizinha";
  "casa_03_morador_" = "casa_03_morador"; "casa_04_vizinho_" = "casa_04_vizinho"; "casa_06_moradora_" = "casa_06_moradora";
  "techcorp_funcionario_" = "techcorp_funcionario"; "centro_pesquisadora_" = "centro_pesquisadora";
  "loja_desenvolvedora_" = "loja_desenvolvedora"; "central_" = "central"; "sistema_boss_" = "sistema_boss";
  "boss_hacker_" = "boss_hacker"; "campanha_" = "narrador_campanha"
}
$total = 0
foreach ($arq in Get-ChildItem -Path $Origem -Filter "*.mp3") {
  foreach ($prefixo in $pastas.Keys) {
    if ($arq.Name.StartsWith($prefixo)) {
      $destino = Join-Path "assets\audio\voices" $pastas[$prefixo]
      Copy-Item $arq.FullName (Join-Path $destino $arq.Name) -Force
      $total++
      break
    }
  }
}
Write-Host "$total arquivos copiados. Abra o projeto no Godot para ele importar os audios novos."
