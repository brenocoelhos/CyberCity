# Cyber City

Jogo educativo 2D de cibersegurança, feito em **Godot 4.7** com **GDScript**
(protótipo acadêmico). O jogador é um hacker ético que ajuda os moradores e
as empresas da cidade resolvendo casos de phishing, senhas, hash,
criptografia, redes, firewall, logs, SQL Injection, XSS e testes de invasão.

O histórico de desenvolvimento, fase por fase, está em
[docs/HISTORICO_FASES.md](docs/HISTORICO_FASES.md).

## Como abrir e jogar

1. Abra o **Godot 4.7** (o projeto usa o renderizador *Compatibility*).
2. Na tela de projetos, clique em **Importar** e escolha o arquivo
   `project.godot` desta pasta.
3. Na primeira vez, o Godot importa todas as imagens e sons. Espere a barra de
   progresso terminar.
4. Aperte **F5** (ou o botão **Executar Projeto**). O jogo começa pelo menu
   principal (`scenes/ui/MainMenu.tscn`).

### Pelo JetBrains Rider

A configuração "Player" que o Rider cria sozinho é do tipo *.NET Executable* e
pede o .NET SDK, que este projeto não usa. Crie uma do tipo **Native
Executable**:

1. No menu das configurações (barra de cima), clique em
   **Edit Configurations...**
2. Clique em **+** e escolha **Native Executable** (ou copie a configuração
   **Editor** desse grupo com **Ctrl+D**).
3. Preencha:
   - **Name:** `Jogo`
   - **Executable:** o `.exe` do Godot 4.7
   - **Program arguments:** `--path "./"` (com `--editor` abre o editor)
   - **Working directory:** a pasta do projeto
4. Escolha **Jogo** e clique no **▶** (**Shift+F10**).

Para depurar com breakpoints no GDScript: abra o editor do Godot com o
projeto, escolha **Player (GDScript)** e clique no **🐞** (**Shift+F9**). A
porta do *Debug Adapter* no Godot (**Editor → Configurações do Editor → Rede**)
precisa ser **6006**.

## Controles

**No mundo**

| Tecla | Ação |
| --- | --- |
| W A S D ou setas | andar |
| E | interagir (portas, pessoas, computadores) |
| M | mapa grande (ou clique no minimapa) |
| TAB | celular (mensagens, pistas, missões, notas) |
| ESC | pausar (salvar, opções, menu principal) |

**Nos computadores**

- Terminal: `help` lista os comandos e `dica` ajuda no desafio.
- Desktop: arraste as janelas pela barra de título, redimensione pelo canto,
  duplo clique maximiza e ESC minimiza a janela da frente.

## Como o jogo avança

- **Campanha em capítulos.** As 17 missões estão divididas em 7 capítulos, do
  mais fácil (quizzes de conceitos) ao mais difícil (o teste de invasão
  completo). As missões de um capítulo só ficam disponíveis quando ele
  começa, e ele só começa quando o anterior termina
  (`scripts/missions/CampaignManager.gd`).
- **Capítulo final.** Depois do capítulo 7, a Casa 5 destranca e o jogador
  enfrenta o hacker num duelo no terminal (`scripts/boss/`). São 5 ataques
  (phishing, força bruta, firewall, SQL Injection e XSS); quem acerta tudo
  vence ao conter o 5º. Vencer encerra o jogo, mostra os créditos e grava o
  tempo no placar.
- **Selos dos capítulos.** Concluir um capítulo dá +50 XP e um selo no Perfil
  do celular. O app Missões mostra o capítulo atual e quantas missões faltam.
- **Missões práticas.** As missões usam o terminal, o desktop e as ferramentas
  de verdade do jogo: as de 02 a 05, por exemplo, são auditoria de senhas
  (`passcheck`), integridade com hash (`sha256sum`), cifra de César (`caesar`)
  e comparação de e-mails de phishing.
- **Quem pede ajuda.** Moradores com **!** entregam missões. Se a missão é de
  um capítulo que ainda não começou, eles avisam que o jogador ainda não está
  pronto, e o computador dela também não abre.
- **XP e nível.** Cada missão dá XP. Cada nível dá um título (de Estagiário
  a Hacker Ético), mostrado no Perfil e na pausa. Alguns níveis liberam
  ferramentas de apoio: app Ferramentas do celular (nível 3), mapa de rede no
  `scan` (nível 4) e histórico de comandos salvo (nível 5).
- **Mochila.** Cada missão concluída dá um item; o app **Mochila** do celular
  mostra os itens e os que faltam.
- **Minha Casa.** A casa do jogador, na Vila Residencial, tem quarto,
  banheiro, sala e cozinha. No quarto ficam a cama que salva o jogo e o
  **Meu PC**, um desktop livre com e-mails, arquivos, wiki dos conceitos
  aprendidos e o placar do agente.
- **Rank.** Cada desafio recebe rank S, A ou B pelo número de dicas e erros,
  com bônus de XP para S e A.
- **Salvamento.** Automático a cada 5 minutos, ao concluir missão, ao subir
  de nível e ao fechar o jogo; também pelo menu de pausa, pelo Terminal de
  Salvamento da Praça Central e dormindo na cama da Minha Casa. Durante o
  duelo final não se salva.
- **Música e sons.** Trilhas de fundo e efeitos sonoros ficam em
  `scripts/systems/MusicManager.gd` e `scripts/systems/SoundManager.gd`. O arquivo fica em `user://savegame.json` (no Godot: **Projeto →
  Abrir Pasta de Dados do Usuário**).

## Estrutura de pastas

| Pasta | O que tem |
| --- | --- |
| `scenes/` | cenas: cidade, interiores, jogador, NPCs, computadores e telas |
| `scripts/` | código, separado por sistema (missões, terminal, desktop, chefe, interface...) |
| `assets/` | imagens, sons, temas e shaders |
| `tools/` | testes automáticos (`verify_*.gd`) e scripts que geram arte e textos dos desafios |
| `docs/` | documentação da arte, do tileset, dos NPCs e o histórico |

Convenções do projeto (tamanho dos tiles, pixel art, assets de origem) estão
em [AGENTS.md](AGENTS.md).

## Testes automáticos

No Git Bash, na pasta do projeto:

```bash
tools/run_all_tests.sh
```

Roda todos os `tools/verify_*.gd` sem abrir janela e mostra um resumo. Para
rodar só alguns, passe parte do nome (ex.: `tools/run_all_tests.sh campaign
mail`). O Godot é procurado na variável `GODOT`, no `PATH` e na Área de
Trabalho. Os testes usam arquivos temporários e nunca mexem no save nem no
placar do jogador.

## Exportar para Windows

Menu **Projeto → Exportar...**, preset **Windows Desktop**. Ele gera um único
`build/CyberCity.exe` (sem as pastas `tools/`, `docs/` e `assets/source/`).
É preciso ter os *Export Templates* do Godot 4.7 instalados.

## Tela cheia e objetos da rua em alta resolução

- O jogo abre em **tela cheia sem bordas** e ocupa a tela toda em qualquer
  proporção (16:9, 16:10, ultrawide 21:9...): `window/stretch/aspect="expand"`.
  **F11** ou **Alt+Enter** alternam tela cheia/janela; a escolha fica salva
  (Opções → "Tela cheia (F11)"). HUD, minimapa, diálogo, celular, terminal e
  tela de desafio ficam presos às bordas ou ao centro da tela.
- **Centro de Tecnologia e objetos da rua nítidos**: `tools/upscale_city_props.py`
  amplia os recortes da arte original com super-resolução (EDSR/OpenCV) e gera
  versões 3x (`assets/environment/cyber/tech_center.png` e `cyber/hd/*.png`).
  `City._use_hd_props` troca poste, árvore, banco, floreira, ponto de ônibus,
  quiosque, lixeira e flores por essas versões, sem mudar o tamanho na tela.

## HUD discreto e Praça Central nova

- **HUD** (`scenes/ui/HUD.tscn`, `scripts/ui/GlassPanel.gd`): painéis de vidro
  escuro semitransparente, quase sem bordas e com pouco neon. Local + relógio
  num painel compacto (topo esquerdo), missão num cartão pequeno, nível/XP numa
  barra fina (base esquerda), celular como botão pequeno com TAB (base direita)
  e minimapa menor (topo direito).
- **Praça Central** (`scripts/world/PlazaDesign.gd`, `PlazaBed.gd`,
  `PlazaMonument.gd`): layout simétrico, piso de pedra com variação de tom,
  círculo em volta do monumento, caminho de entrada com bordas de neon, canteiros
  elevados com árvores, flores e faixa de luz, painéis holográficos, bancos com
  luz, halos nos postes e nos terminais e um monumento holográfico animado
  (anéis que pulsam, feixe de luz e cristal flutuante). Terminais, Guia e
  interações continuam os mesmos; os caminhos até eles ficam livres.
