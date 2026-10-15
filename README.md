# Cyber City — Protótipo Acadêmico (sistema de dicas)

Jogo educativo 2D de cibersegurança, desenvolvido em Godot 4.x / GDScript.

## Como abrir

1. Abra o **Godot Engine 4.3+** (ou versão 4.x compatível).
2. "Import" → selecione a pasta `CyberCity` (o arquivo `project.godot`).
3. Ao abrir pela primeira vez, o Godot vai importar automaticamente as
   texturas placeholder (`.png`) — isso é normal, aguarde a barra de
   progresso terminar.
4. Pressione **F5** (ou o botão de Play) para rodar a cena principal
   (`scenes/world/TestMap.tscn`).

## O que foi implementado na Fase 1

- Estrutura de pastas completa (`scenes/`, `scripts/`, `assets/`, `data/`),
  conforme a arquitetura planejada para o projeto inteiro.
- **Player** (`scenes/player/Player.tscn` + `scripts/player/Player.gd`):
  - `CharacterBody2D` com movimentação nas 4 direções via Input Map
    (`move_up`, `move_down`, `move_left`, `move_right` já mapeados para
    WASD **e** setas).
  - Velocidade configurável via `@export var speed`.
  - Colisão com paredes/obstáculos (via `CollisionShape2D` + `move_and_slide`).
  - Animação básica de placeholder (espelhamento horizontal do sprite
    conforme a direção — será substituída por spritesheet quando a arte
    final entrar no projeto).
  - `Camera2D` filha do jogador, com suavização de movimento
    (`position_smoothing_enabled`), sem mostrar áreas fora do mapa
    (câmera fixa dentro dos limites do quarto de teste).
- **Mapa de teste** (`scenes/world/TestMap.tscn`):
  - Piso simples (`Polygon2D`).
  - 4 paredes de borda com colisão (`StaticBody2D`).
  - 2 obstáculos internos (placeholders para futuros prédios).
  - Leve tint azulado (`CanvasModulate`) para reforçar a estética
    tecnológica sem poluir a tela.
  - Label de instrução na tela (`UI/HintLabel`).
- Ações de menu (`open_menu`, TAB/ESC) e interação (`interact`, tecla `E`)
  já registradas no Input Map do `project.godot`, prontas para serem
  usadas nas próximas fases (ainda sem função — serão implementadas na
  Fase 3: Interação).
- Sprites placeholder gerados proceduralmente (não são arte final):
  `assets/characters/player_placeholder.png`,
  `assets/environment/floor_tile.png`,
  `assets/environment/wall_tile.png`.

## Checklist de teste manual (Fase 1)

Ao rodar o projeto no seu Godot local, verifique:

- [ ] O personagem aparece no centro da sala de teste.
- [ ] Mover com W/A/S/D e com as setas funciona igual.
- [ ] O personagem **não atravessa** as paredes nem os dois obstáculos.
- [ ] O sprite espelha horizontalmente ao mudar de direção esquerda/direita.
- [ ] A câmera segue o personagem suavemente, sem mostrar área fora da sala.
- [ ] Nenhum erro aparece no console (painel "Output"/"Debugger" do Godot).

Se algo falhar ou aparecer erro no console, me envie a mensagem exata do
erro (arquivo + linha) que eu corrijo antes de seguirmos para a Fase 2.

## Nota importante

Este projeto foi escrito fora do editor Godot (sem acesso ao engine
neste ambiente), seguindo rigorosamente a sintaxe do formato `.tscn`
do Godot 4.x. Ele deve abrir e rodar normalmente, mas **a validação
final só é possível no seu Godot local** — por isso o checklist acima.
Qualquer erro reportado será corrigido imediatamente.

## O que foi implementado na Fase 2

- **Cidade** (`scenes/world/City.tscn` + `scripts/world/City.gd`):
  - Chão gerado **proceduralmente via `TileMapLayer`** (grama, rua e
    calçada), a partir de um `TileSet` simples
    (`scenes/world/CityTileSet.tres`) com 3 tiles visuais (sem colisão
    por tile — ver decisão de arquitetura abaixo).
  - Layout em cruz: uma rua horizontal e uma vertical com calçada ao
    redor, formando 4 quadrantes onde os prédios ficam.
  - **9 construções**, todas usando a mesma cena reutilizável
    `scenes/world/Building.tscn` (bloco colidível + nome + porta),
    só trocando cor/nome/destino por instância:
    Casa 1 a Casa 5, TechCorp Ltda., DataSoft Sistemas, Loja Eletrônica
    e Centro de Tecnologia.
  - **Um prédio bloqueado** (Centro de Tecnologia) para demonstrar o
    conceito de "área liberada só depois de uma missão" (a lógica de
    missões em si entra na Fase 5 — por enquanto é só um `locked = true`
    fixo na porta).
  - Árvores decorativas (`Decor`) espalhadas pela grama.
- **Portas e transição** (`Door.gd` / `ExitDoor.gd` / `SceneTransition.gd`):
  - Ao chegar perto de uma porta, aparece `[E] Entrar` (ou
    `🔒 Bloqueado`, se a porta estiver travada).
  - Pressionar `E` troca de cena para o interior correto
    (`get_tree().change_scene_to_file`), guardando em um **autoload**
    (`SceneTransition`) o ponto exato da cidade para onde o jogador deve
    voltar.
  - Dentro do interior, a porta de saída (`[E] Sair`) devolve para a
    cidade, na posição salva.
- **Interiores reutilizáveis**:
  - `scenes/interiors/HouseInterior.tscn` — sala pequena, tom quente,
    usada por todas as 5 casas.
  - `scenes/interiors/OfficeInterior.tscn` — mesma estrutura, tom
    azulado, duas "estações de computador" (ainda decorativas — ficam
    interativas na Fase 3), usada pelas empresas/loja/prédio de
    tecnologia.
  - Ambas têm uma parede inferior **partida em dois blocos**, deixando
    um vão real para a porta (o jogador realmente anda por uma
    "abertura", não apenas toca num sensor dentro da parede).
  - O título mostrado no topo (`"Casa 2"`, `"TechCorp Ltda."`...) é
    dinâmico, vindo do `SceneTransition`.
- **Minimapa** (`UI/MinimapPanel` dentro de `City.tscn`):
  implementado com uma técnica padrão do Godot: um `SubViewport` com
  `own_world_2d = false` (compartilha o mesmo mundo 2D da cena
  principal) e uma câmera extra, bem afastada, olhando a cidade
  inteira de cima. Isso significa que o minimapa é uma **visão real**
  do mapa (prédios e jogador aparecem automaticamente, sem precisar
  desenhar ícones à mão) — atualiza sozinho conforme o jogador anda.

### Decisões de arquitetura (Fase 2)

- **Chão sem colisão por tile / prédios com colisão própria**: em vez
  de configurar física dentro do `TileSet` (mais complexo e mais
  arriscado de dar erro), o chão é só visual e cada prédio tem seu
  próprio `StaticBody2D`. É a abordagem mais comum em jogos 2D
  top-down (o "terreno" nunca bloqueia, só os objetos).
- **Todos os prédios com o mesmo tamanho** (`96x64`): simplifica a cena
  reutilizável — a diferença entre eles é só cor, nome e para onde a
  porta leva.
- **Troca de cena real** para os interiores (como você escolheu),
  centralizada num autoload (`SceneTransition`) — assim cada casa/
  empresa não precisa saber nada sobre a cidade, só chama
  `SceneTransition.enter_building(...)`.

## Checklist de teste manual (Fase 2)

- [ ] O projeto abre sem erros no console.
- [ ] A cidade aparece com rua, calçada, grama e os 9 prédios visíveis.
- [ ] O minimapa no canto superior direito mostra a cidade de cima e o
      jogador se movendo nele em tempo real.
- [ ] Chegando perto de uma porta destravada, aparece `[E] Entrar`.
- [ ] Pressionar `E` leva para dentro (casa ou empresa), com o nome
      certo no topo da tela.
- [ ] Dentro do interior, é possível voltar para a cidade `[E] Sair`
      exatamente perto da porta de onde você entrou (não em outro
      lugar do mapa).
- [ ] O "Centro de Tecnologia" mostra `🔒 Bloqueado` e não deixa entrar.
- [ ] Não há erros no console ao entrar/sair repetidamente de vários
      prédios.

Se algo falhar, me manda a mensagem exata do erro (arquivo + linha)
que eu corrijo antes de seguirmos.

## Correção aplicada (relatada por você)

O jogador conseguia sair da área desenhada, tanto na cidade quanto
dentro das casas/empresas. Corrigido:

- **Cidade**: adicionadas 4 paredes de borda invisíveis
  (`City.tscn > MapBounds`) ao redor de todo o mapa (960×640), então
  agora só dá para andar dentro da área com grama/rua/calçada.
- **Interiores**: a parede de baixo, que antes tinha um vão "aberto"
  para simular uma porta, virou uma parede sólida única — a porta
  passou a ser só uma área de interação (`[E] Sair`) encostada nela
  por dentro, sem abertura física nenhuma. Mais simples e sem brecha
  para vazar pro vazio.

## O que foi implementado na Fase 3

- **Sistema genérico de interação** (`scripts/systems/Interactable.gd`):
  uma base reutilizável (`Area2D`) que qualquer objeto interativo pode
  estender. Ela sozinha cuida de: detectar o jogador por perto, mostrar
  `[E] ...]`, e chamar `_on_interact()` quando `E` é pressionado — cada
  tipo de objeto só sobrescreve esse método.
  - `NPC.gd` estende `Interactable.gd` → abre diálogo.
  - `Computer.gd` estende `Interactable.gd` → (por enquanto) avisa que
    o terminal de verdade vem na Fase 4.
  - `Door.gd`/`ExitDoor.gd` continuam com sua própria lógica (já
    prontos desde a Fase 2), mas agora também respeitam o diálogo
    aberto (ver abaixo).
- **Sistema de diálogo** (`DialogueManager`, autoload com UI própria em
  `scenes/ui/DialogueBox.tscn`): uma caixa no rodapé da tela mostra as
  falas uma de cada vez; `E` avança e, na última fala, fecha. Funciona
  em qualquer cena porque é autoload.
  - Enquanto o diálogo está aberto, o jogador **para de se mover** e
    nenhuma outra porta/NPC/computador reage a `E` (evita reabrir o
    mesmo diálogo ou entrar sem querer num prédio no meio da conversa).
- **NPCs**: 3 no total, todos usando a mesma cena `scenes/npc/NPC.tscn`
  (corpo sólido que bloqueia passagem + área de interação com fala):
  - **Vizinho**, na cidade — mensagem de boas-vindas/tutorial.
  - **Morador**, dentro de `HouseInterior.tscn` (aparece em todas as
    casas) — a fala de exemplo do e-mail suspeito, do seu prompt
    original, plantando o gancho para uma futura missão de phishing.
  - **Funcionário**, dentro de `OfficeInterior.tscn` — reclama de
    computadores lentos, plantando o gancho para uma futura missão de
    rede/firewall.
- **Computadores interativos** (`scenes/computers/Computer.tscn`):
  substituíram os sprites decorativos das Fases 1-2. Já reagem a `E` e
  abrem uma mensagem via `DialogueManager` avisando que o terminal
  chega na Fase 4 — a "porta de entrada" para o terminal já está
  pronta, só falta a tela do terminal em si.

### Decisões de arquitetura (Fase 3)

- **Herança de script para reuso**: em vez de copiar a lógica de
  prompt/detecção em cada tipo de objeto, `NPC.gd` e `Computer.gd`
  **estendem** `Interactable.gd` (`extends "res://scripts/.../Interactable.gd"`).
  Isso é literalmente o "sistema genérico de interação" pedido no
  escopo do projeto.
- **Diálogo como autoload com cena própria**: o `DialogueManager` é
  registrado no `project.godot` apontando para uma `.tscn` (não só um
  `.gd`), o que permite ele já vir com sua própria UI (`CanvasLayer` +
  `Panel` + `Label`s) presente em todas as cenas automaticamente, sem
  precisar duplicar a caixa de diálogo em cada interior.
- **NPCs "sólidos" com padrão Corpo + Área**: mesmo modelo já usado nos
  prédios (Fase 2) — um `StaticBody2D` bloqueia a passagem, e uma
  `Area2D` separada cuida só da interação. Reaproveitar o padrão deixa
  o projeto mais previsível de entender/manter.

## Checklist de teste manual (Fase 3)

- [ ] Não é mais possível sair da área do mapa, nem na cidade nem
      dentro das casas/empresas.
- [ ] Falar com o **Vizinho** na cidade abre o diálogo de boas-vindas.
- [ ] Falar com o **Morador** dentro de qualquer casa mostra as 4 falas
      na ordem certa, avançando com `E` e fechando na última.
- [ ] Falar com o **Funcionário** dentro de qualquer empresa/loja
      funciona igual.
- [ ] Interagir com um computador (`[E] Acessar`) mostra o aviso de que
      o terminal vem na Fase 4.
- [ ] Enquanto o diálogo está na tela, o jogador não se move e nenhuma
      porta abre sem querer.
- [ ] Depois de fechar o diálogo, tudo volta ao normal (movimento,
      portas, etc.).
- [ ] Nenhum erro no console, incluindo depois de entrar/sair de vários
      prédios e conversar com todo mundo repetidas vezes.

Se algo falhar, me manda a mensagem exata do erro (arquivo + linha)
que eu corrijo antes de seguirmos.

## O que foi implementado na Fase 4

- **Terminal fictício** (`TerminalManager`, autoload com UI própria em
  `scenes/terminal/Terminal.tscn`): computadores agora abrem uma janela
  de verdade, no estilo `CYBER-OS TERMINAL v1.0` do seu roteiro
  original, com:
  - **saída rolável** (`RichTextLabel`) mostrando o histórico de tudo
    que já foi digitado e respondido;
  - **campo de entrada de texto** (`LineEdit`), com o prompt
    `user@cybercity:~$`;
  - **histórico de comandos**: setas `↑`/`↓` repetem comandos já
    digitados (como um terminal de verdade);
  - `ESC` fecha o terminal a qualquer momento.
- **4 comandos fictícios implementados** (todos interpretados pelo
  próprio jogo — nada disso roda comando real do sistema operacional):
  - `help` — lista os comandos disponíveis;
  - `clear` — limpa a tela;
  - `files` — lista os arquivos do "sistema" simulado;
  - `read <arquivo>` — mostra o conteúdo de um arquivo simulado.
  - Bônus: `exit`/`sair` fecha o terminal (não estava na lista original,
    mas é natural ter um jeito de sair digitando também, além do ESC).
- **Sistema de arquivos simulado** (`VIRTUAL_FILES` dentro de
  `TerminalManager.gd`): por enquanto os mesmos 2 arquivos aparecem em
  qualquer computador — `readme.txt` e `email_suspeito.eml` (o
  "e-mail" que o Morador mencionou no diálogo da Fase 3 já pode ser
  lido de verdade dentro do terminal, fechando esse gancho narrativo).
- Jogador travado (sem se mover) e outras interações bloqueadas
  enquanto o terminal está aberto — mesmo cuidado que já existia com
  o diálogo, para W/A/S/D digitados dentro do terminal não moverem o
  personagem por trás da janela.

### Decisões de arquitetura (Fase 4)

- **Terminal como autoload com cena própria**, no mesmo padrão do
  `DialogueManager` (Fase 3): fica disponível em qualquer cena sem
  precisar duplicar a interface.
- **Comandos como `match` dentro de `_run_command()`**: simples de ler
  e fácil de estender — adicionar um novo comando fictício nas
  próximas fases (`scan`, `logs`, `hash`, `decrypt`...) é só somar mais
  um `case` no `match` e uma função `_cmd_*()` nova.
- **Arquivos simulados como um `Dictionary` fixo**: hoje é global (todo
  computador vê os mesmos arquivos); dá pra evoluir depois para um
  dicionário por computador/missão sem mudar a estrutura do terminal
  em si — só o que `open()` recebe como parâmetro.

## Checklist de teste manual (Fase 4)

- [ ] Interagir com qualquer computador abre o terminal (`CYBER-OS
      TERMINAL v1.0`) em vez do aviso da Fase 3.
- [ ] `help` lista os comandos.
- [ ] `files` lista `readme.txt` e `email_suspeito.eml`.
- [ ] `read readme.txt` e `read email_suspeito.eml` mostram o conteúdo.
- [ ] `read arquivo_que_nao_existe.txt` avisa que o arquivo não foi
      encontrado (sem travar nada).
- [ ] `clear` limpa a tela.
- [ ] Um comando desconhecido (ex.: `oi`) mostra a mensagem de "comando
      não reconhecido" e não trava o jogo.
- [ ] Setas `↑`/`↓` navegam pelo histórico de comandos já digitados.
- [ ] `ESC` (ou `exit`) fecha o terminal e devolve o controle ao
      jogador normalmente.
- [ ] Enquanto o terminal está aberto, W/A/S/D digitados **não** movem
      o personagem por trás da janela.
- [ ] Nenhum erro no console após abrir/fechar o terminal várias vezes
      em computadores diferentes.

Se algo falhar, me manda a mensagem exata do erro (arquivo + linha)
que eu corrijo antes de seguirmos.

## Correção aplicada (relatada por você)

Depois de enviar um comando, o campo de texto do terminal perdia o
foco e era preciso clicar nele de novo para continuar digitando.
Corrigido em `TerminalManager.gd`:

- o foco é devolvido ao campo de forma **deferida**
  (`call_deferred("grab_focus")`) após cada comando — o `LineEdit`
  perde o foco no mesmo frame em que o texto é enviado, então
  reatribuir na hora não funcionava;
- a área de saída (`RichTextLabel`) teve `focus_mode = 0` para nunca
  roubar o foco do campo;
- rede de segurança: se o foco se perder por qualquer outro motivo,
  qualquer tecla digitada com o terminal aberto já devolve o foco.

## O que foi implementado na Fase 5

- **`GameManager`** (autoload): progresso global do jogador — XP, nível
  e conhecimentos. XP para subir de nível segue uma fórmula simples e
  previsível (nível × 100), e um ganho grande pode subir mais de um
  nível de uma vez.
- **`MissionManager`** (autoload): sistema de missões com todos os
  campos pedidos no escopo (id, título, descrição, objetivo, local,
  estado, XP, dificuldade) e os 5 estados
  (`LOCKED` / `AVAILABLE` / `ACTIVE` / `COMPLETED` / `FAILED`).
  Ao concluir uma missão, ele entrega o XP e registra o conceito
  aprendido no `GameManager` automaticamente.
- **Primeira missão completa, de ponta a ponta** — *Missão 01 — O
  e-mail suspeito*, ligando tudo que já existia:
  1. conversar com o **Morador** dentro de uma casa **aceita a missão**
     (estado vai de `AVAILABLE` para `ACTIVE`);
  2. o objetivo aparece no HUD;
  3. o jogador usa o **terminal** do computador da casa (`files`, depois
     `read email_suspeito.eml`);
  4. ler o e-mail **conclui a missão**: +100 XP, conceito "Phishing"
     registrado, e a tela de explicação aparece.
- **HUD permanente** (`scenes/ui/HUD.tscn`): nível, barra de XP e
  objetivo atual sempre visíveis no rodapé.
- **Tela de missão concluída**: o painel `DESAFIO CONCLUÍDO` com a
  explicação do *porquê*, o conceito aprendido e o XP ganho — a parte
  educativa que o escopo destaca como importante para o trabalho
  acadêmico.
- **Menu do jogador / CYBER PHONE** (`TAB` ou `ESC`): lista as missões
  com seus estados, os conhecimentos adquiridos (com barrinhas) e o
  perfil (nível/XP).
- **Desbloqueio de área**: o *Centro de Tecnologia*, que estava
  travado desde a Fase 2, agora **destrava sozinho** quando a Missão 01
  é concluída (`unlock_after_mission` na porta) — demonstrando o
  conceito de progressão desbloqueando novas áreas.

### Decisões de arquitetura (Fase 5)

- **Missões como dicionários, não Resources customizados**: mais fácil
  de ler, editar e explicar num trabalho acadêmico; adicionar a Missão
  02 é só somar uma entrada no dicionário `missions`.
- **Comunicação por sinais**: `GameManager` e `MissionManager` emitem
  sinais (`xp_changed`, `mission_started`, `mission_completed`) e o HUD
  apenas escuta. Assim a interface não fica misturada com a lógica de
  progressão — se um dia a UI mudar, os sistemas continuam iguais.
- **Uma única checagem de "UI bloqueando"**: o jogador e todos os
  objetos interativos consultam a mesma condição (diálogo, terminal,
  menu ou popup abertos). Isso evita a classe de bug que você já
  encontrou antes — teclas funcionando "por trás" de uma janela aberta.

## Checklist de teste manual (Fase 5)

- [ ] No terminal, dá para digitar vários comandos seguidos **sem
      precisar clicar no campo de novo** entre um e outro.
- [ ] O HUD mostra `NÍVEL 1`, a barra de XP em 0/100 e `Objetivo: —`
      no começo do jogo.
- [ ] Conversar com o Morador dentro de uma casa faz o objetivo da
      Missão 01 aparecer no HUD.
- [ ] `TAB` (ou `ESC`) abre o CYBER PHONE e a Missão 01 aparece como
      `EM ANDAMENTO`.
- [ ] No computador da casa: `files` e depois `read email_suspeito.eml`
      conclui a missão — o terminal fecha e a tela `DESAFIO CONCLUÍDO`
      aparece com a explicação, o conceito e `+100 XP`.
- [ ] `E` fecha a tela de conclusão; o HUD agora mostra 100/100 → ou
      seja, `NÍVEL 2` com a barra zerada.
- [ ] No CYBER PHONE, a Missão 01 aparece como `CONCLUÍDA` e
      "Phishing" aparece na lista de conhecimentos.
- [ ] O *Centro de Tecnologia* na cidade, que antes mostrava
      `🔒 Bloqueado`, agora deixa entrar.
- [ ] Ler o e-mail de novo **não** dá XP repetido.
- [ ] O jogador não se move enquanto qualquer janela (diálogo,
      terminal, menu, tela de conclusão) está aberta.
- [ ] Nenhum erro no console.

Se algo falhar, me manda a mensagem exata do erro (arquivo + linha)
que eu corrijo antes de seguirmos.

## O que foi implementado na Fase 6

Os **quatro primeiros desafios educativos** do escopo, cada um ligado a
uma missão própria, com XP e explicação do conceito ao final:

| Desafio | Missão | Onde | XP |
|---|---|---|---|
| Senhas | Missão 02 | Empresa — Estação 1 | 100 |
| Hash | Missão 03 | Empresa — Estação 2 | 150 |
| Criptografia | Missão 04 | Centro de Tecnologia — Estação 1 | 150 |
| Phishing | Missão 05 | Centro de Tecnologia — Estação 2 | 200 |

- **Tela de desafio** (`scenes/ui/ChallengeScreen.tscn`): enunciado com
  o cenário + alternativas clicáveis. **Errar não penaliza**: mostra
  uma dica explicando o raciocínio e deixa tentar de novo — a proposta
  é ensinar, não punir. `ESC` sai do desafio e a missão continua em
  andamento, dá para voltar depois.
- **Desafios acessados pelo terminal**: cada computador pode ter um
  desafio associado (`challenge_id`). Ao abrir o terminal, ele avisa
  que há um desafio disponível, e o novo comando **`desafio`** inicia a
  tela. Isso reaproveita o terminal da Fase 4 em vez de criar um
  caminho paralelo de interação.
- **Conteúdo dos desafios**:
  - *Senhas* — comparar 4 opções e identificar a mais segura;
  - *Hash* — entender que hash não é senha invertida nem criptografia
    reversível;
  - *Criptografia* — decifrar `VHJXUR` com Cifra de César, chave 3;
  - *Phishing* — comparar dois e-mails e achar os sinais de fraude
    (domínio imitado + urgência pedindo senha).
- **Novo interior**: `TechCenterInterior.tscn` para o Centro de
  Tecnologia — o prédio que destrava ao concluir a Missão 01 agora tem
  conteúdo próprio (paleta roxa, uma Pesquisadora e as duas estações
  com os desafios avançados).
- Progressão real: completando as 5 missões o jogador acumula **700 XP**,
  chegando ao **nível 3**, com 5 conceitos registrados em
  "Conhecimentos" no CYBER PHONE (Phishing aparece reforçado 2×, já que
  dois desafios diferentes tratam do tema).

### Decisões de arquitetura (Fase 6)

- **Dados separados da lógica**: `ChallengeData.gd` guarda só o conteúdo
  dos desafios (enunciados, alternativas, dicas) e `ChallengeManager.gd`
  cuida só de apresentar e validar. Adicionar os desafios restantes
  (redes, firewall, logs, SQL Injection, XSS) é só acrescentar entradas
  em `ChallengeData` + as missões correspondentes — sem tocar na
  interface.
- **Reuso da tela de conclusão**: acertar o desafio conclui a missão,
  e quem mostra a explicação é o mesmo painel `DESAFIO CONCLUÍDO` do
  HUD já feito na Fase 5. Um caminho só para toda recompensa educativa.
- **Formato único de desafio (múltipla escolha)**: mantém o escopo
  controlado e a interface reutilizável para todos os temas, em vez de
  uma tela sob medida por assunto.

## Checklist de teste manual (Fase 6)

- [ ] Entrar numa empresa (TechCorp / DataSoft / Loja) e usar a
      **Estação 1**: o terminal avisa que há um desafio disponível.
- [ ] Digitar `desafio` abre a tela do desafio de **senhas**.
- [ ] Escolher uma alternativa errada mostra a dica e **deixa tentar de
      novo** (sem travar nem fechar).
- [ ] Acertar (`J7#vq!Lm92$tR`) fecha o desafio e abre a tela
      `DESAFIO CONCLUÍDO` com a explicação e `+100 XP`.
- [ ] A **Estação 2** da mesma empresa oferece o desafio de **hash**.
- [ ] Concluir a Missão 01 (ler o e-mail na casa) destrava o **Centro
      de Tecnologia**, e dentro dele as duas estações oferecem os
      desafios de **criptografia** e **phishing**.
- [ ] `ESC` durante um desafio sai sem concluir, e voltando ao mesmo
      computador dá para retomar.
- [ ] No CYBER PHONE (`TAB`), as missões mudam de `DISPONÍVEL` para
      `EM ANDAMENTO` e depois `CONCLUÍDA`, e os conceitos vão
      aparecendo em "Conhecimentos".
- [ ] Refazer um desafio já concluído **não** dá XP repetido.
- [ ] Completando tudo: **nível 3** e 700 XP acumulados.
- [ ] Nenhum erro no console.

Se algo falhar, me manda a mensagem exata do erro (arquivo + linha)
que eu corrijo antes de seguirmos.

## Pedido: desafios mais "mãos na massa" (não só marcar opção)

Os quatro primeiros desafios (senhas/hash/criptografia/phishing) são
naturalmente do tipo pergunta-e-resposta, então continuam como
múltipla escolha. Mas os dois novos abaixo são resolvidos **inteiramente
digitando comandos no terminal**, no estilo de uma investigação de
red team (só que 100% simulado dentro do jogo — nada aqui roda
comando real de rede ou de sistema).

### Missão 06 — Dispositivo desconhecido (comandos `scan` / `connect`)

No computador **Servidor** (empresas), o terminal avisa que há uma
rede local pra mapear:

```
user@cybercity:~$ scan
Escaneando rede local...

192.168.1.1     ROUTER
192.168.1.10    OFFICE-PC
192.168.1.20    SERVER
192.168.1.50    UNKNOWN

Dispositivo suspeito detectado. Use 'connect <ip>' para investigar.

user@cybercity:~$ connect 192.168.1.50
Conectando a 192.168.1.50 (UNKNOWN)...
Dispositivo não cadastrado no inventário. Está enviando pacotes para
um endereço externo desconhecido, fora do horário comercial.

>> Objetivo cumprido: dispositivo suspeito identificado.
```

Dá pra tentar `connect` em qualquer um dos outros IPs também — cada
um responde com informação real sobre aquele dispositivo (nenhum é
"resposta errada" travada, é uma investigação de verdade).

### Missão 07 — Configurar o firewall (comando `firewall`)

No computador **Firewall** (Centro de Tecnologia), o jogador vê uma
lista de conexões pendentes e decide, uma por uma, se libera ou
bloqueia:

```
user@cybercity:~$ firewall status
Conexões pendentes de análise:

  porta 80    -  HTTP (site da empresa)                         [???]
  porta 443   -  HTTPS (site da empresa, com criptografia)       [???]
  porta 23    -  TELNET (login remoto sem criptografia)          [???]
  porta 4444  -  porta não documentada, tráfego constante        [???]

user@cybercity:~$ firewall allow 80
user@cybercity:~$ firewall allow 443
user@cybercity:~$ firewall block 23
user@cybercity:~$ firewall block 4444
>> Objetivo cumprido: firewall configurado corretamente.
```

A missão só é concluída quando **todas** as portas recebem a decisão
certa — dá pra checar o progresso a qualquer momento com
`firewall status`.

### Como isso foi construído

- Os desafios ganharam um campo **`type`** em `ChallengeData.gd`:
  `"quiz"` (os quatro antigos, via `ChallengeManager`/botões),
  `"network"` e `"firewall"` (novos, resolvidos só com comandos).
- O `TerminalManager` agora consulta esse tipo para decidir quais
  comandos aceitar e qual dica mostrar ao abrir (`scan` num sistema de
  rede, `firewall status` num sistema de firewall) — o comando
  `desafio` (tela de botões) continua existindo só para os quiz.
- Isso significa que dar suporte aos próximos desafios do escopo
  (`logs`, `hash`/`decrypt` mais avançados, `SQL Injection`, `XSS`) é
  seguir o mesmo padrão: um novo `type` em `ChallengeData` + os
  comandos correspondentes no terminal — sem mexer no resto do jogo.
- Cada empresa/Centro de Tecnologia ganhou um **terceiro computador**
  (Servidor / Firewall) reaproveitando a mesma cena `Computer.tscn` de
  sempre, só com um `challenge_id` diferente.

## Checklist de teste manual (desafios de rede/firewall)

- [ ] No computador **Servidor** de qualquer empresa: `scan` lista os
      4 dispositivos e avisa que um é suspeito.
- [ ] `connect 192.168.1.50` conclui a Missão 06 com `+200 XP` e o
      conceito "Redes".
- [ ] `connect` num IP normal (ex.: `192.168.1.1`) mostra a info dele
      sem concluir a missão (não é o suspeito).
- [ ] `connect 10.0.0.1` (IP que não existe) mostra "Host inacessível".
- [ ] No computador **Firewall** do Centro de Tecnologia:
      `firewall status` mostra as 4 conexões, todas com `[???]`.
- [ ] `firewall allow 80`, `firewall allow 443`, `firewall block 23`,
      `firewall block 4444` (em qualquer ordem) conclui a Missão 07
      com `+250 XP` e o conceito "Firewall".
- [ ] Configurar uma porta errada (ex.: `firewall allow 23`) não
      conclui a missão — `firewall status` mostra o estado atualizado
      pra corrigir.
- [ ] Depois de concluídas as duas, o CYBER PHONE mostra as Missões 06
      e 07 como `CONCLUÍDA`, com "Redes" e "Firewall" em Conhecimentos.
- [ ] Nenhum erro no console usando os comandos em qualquer ordem,
      inclusive digitando porta/IP inválido.

Se algo falhar, me manda a mensagem exata do erro (arquivo + linha)
que eu corrijo antes de seguirmos.

## Ajuste visual: terminal e desafios agora em tela cheia

Antes, o terminal e a tela de desafio abriam como um painel pequeno
flutuando sobre a cidade — dava pra ver o minimapa e o HUD por trás.
Agora, ao interagir com qualquer computador, a tela muda para uma
visão grande e imersiva:

- um **fundo escuro cobrindo a tela inteira** (esconde cidade, HUD e
  minimap por completo enquanto a atividade estiver aberta);
- um **"PC de mesa"** — um monitor grande centralizado — com o
  terminal (ou a tela de desafio) por dentro dele, como se você
  estivesse mesmo sentado na frente do computador.

Tecnicamente: `TerminalManager` e `ChallengeManager` passaram a
esconder/mostrar a própria `CanvasLayer` inteira (`visible = true/false`)
em vez de só o painel interno, e foram promovidos para uma camada de
desenho bem acima de tudo (`layer = 10`) — garantindo que nada do jogo
por trás apareça enquanto a atividade estiver na tela.

## O que foi implementado na Fase 7

### Os 3 desafios que faltavam do escopo original

Todos na **Loja Eletrônica**, que ganhou seu próprio interior
(`scenes/interiors/AppInterior.tscn`) com 3 computadores — encaixando
com o Capítulo 5 do seu roteiro ("A Aplicação"):

**Missão 08 — Logs** (`🖥️ Registro de Acessos`):
```
user@cybercity:~$ logs
Registro de acessos:

[1] 10:31  Login successful (user: admin)
[2] 10:32  Login failed (user: admin)
[3] 10:32  Login failed (user: admin)
[4] 10:33  Login failed (user: admin)
[5] 10:33  Login successful (user: admin)
[6] 10:34  File accessed (contract.pdf)

user@cybercity:~$ report 5
>> Objetivo cumprido: comportamento suspeito identificado.
```

**Missão 09 — SQL Injection** (`🖥️ Sistema de Login`) — laboratório
100% fictício, é uma checagem de texto dentro do jogo, não um banco de
dados de verdade:
```
user@cybercity:~$ login ' OR '1'='1
Tentando autenticar com: "' OR '1'='1"
Login aceito. O sistema autenticou sem validar a senha real!

>> Objetivo cumprido: vulnerabilidade de SQL Injection explorada.
```
Aceita as variações clássicas de "sempre verdadeiro" (`' OR 1=1`,
`' OR '1'='1`, etc. — a checagem é por padrão, não por texto exato).

**Missão 10 — XSS** (`🖥️ Sistema de Comentários`) — mesma ideia,
simulação de texto, nada de HTML/JS sendo executado de verdade:
```
user@cybercity:~$ postar <script>roubarSessao()</script>
Comentário publicado sem nenhum tratamento:
  <script>roubarSessao()</script>

Como o site não trata o que o usuário digita, esse <script> rodaria
de verdade no navegador de quem lesse o comentário.

>> Objetivo cumprido: vulnerabilidade de XSS demonstrada.
```

Com isso, **todos os 10 desafios do escopo original estão
implementados** — os 4 primeiros como quiz (múltipla escolha) e os 6
seguintes como investigação por comando no terminal.

### Tela de Perfil melhorada

O CYBER PHONE (`TAB`/`ESC`) agora abre direto no Perfil, com uma barra
de XP em ASCII (`████████░░░░░░░░░░░░ 350/500`) e os conhecimentos
listados com barrinha de reforço por tema — bem próximo do exemplo do
seu roteiro original:

```
=== PERFIL ===

  HACKER
  Nível: 4
  XP: ███████████░░░░░░░░░ 350/500

=== CONHECIMENTOS ===

  Phishing         ██░░░
  Senhas           █░░░░
  Hash             █░░░░
  Criptografia     █░░░░
  Redes            █░░░░
  Firewall         █░░░░
  Logs             █░░░░
  SQL Injection    █░░░░
  XSS              █░░░░
```

### Progressão completa do jogo

Completando as 10 missões: **1850 XP** acumulados, o que dá **nível 8**
(cada nível pede nível×100 XP) — e os 9 conceitos de cibersegurança do
escopo original todos registrados.

### Decisões de arquitetura (Fase 7)

- **Mesmo padrão dos desafios de rede/firewall (Fase 6)**: cada novo
  desafio só precisou de um `type` novo em `ChallengeData.gd` + os
  comandos correspondentes no `TerminalManager` — nenhum sistema
  existente (missões, XP, HUD, menu) precisou mudar.
- **Comandos com texto livre**: `login` e `postar` recebem qualquer
  texto depois do nome do comando (incluindo aspas e espaços), em vez
  de quebrar em várias palavras — necessário pra payloads de
  SQL Injection como `' OR '1'='1`.
- **Checagem por padrão, não por texto exato**: tanto no SQLi quanto
  no XSS, a validação procura características (aspas + "or" + condição
  sempre-verdadeira; presença de `<script`) em vez de exigir uma frase
  decorada — mais parecido com uma investigação de verdade.
- **Novo interior dedicado só pra Loja** (em vez de continuar
  compartilhando o `OfficeInterior`): mostra que trocar o
  `interior_scene_path` de uma porta já basta pra dar identidade
  própria a um prédio, sem mexer em mais nada.

## Checklist de teste manual (Fase 7)

- [ ] Na Loja Eletrônica, a Desenvolvedora dá o contexto dos 3 sistemas.
- [ ] `🖥️ Registro de Acessos`: `logs` mostra as 6 linhas; `report 5`
      conclui a Missão 08. `report 2` (linha errada) dá a dica e não
      conclui.
- [ ] `🖥️ Sistema de Login`: `login 123456` nega o acesso;
      `login ' OR '1'='1` conclui a Missão 09.
- [ ] `🖥️ Sistema de Comentários`: `postar oi tudo bem` só publica;
      `postar <script>alert(1)</script>` conclui a Missão 10.
- [ ] `TAB` abre o CYBER PHONE já na tela de Perfil, com a barra de XP
      em ASCII.
- [ ] Depois de completar as 10 missões: **nível 8**, 1850 XP, e os 9
      conceitos aparecem em Conhecimentos (Phishing com barra maior,
      já que 2 missões diferentes reforçam esse conceito).
- [ ] Nenhum erro no console testando os comandos em qualquer ordem,
      inclusive com entradas "erradas" de propósito.

Se algo falhar, me manda a mensagem exata do erro (arquivo + linha)
que eu corrijo antes de seguirmos.

## O que foi implementado na Fase 8

Uma camada narrativa fina por cima de tudo que já existia — **nenhum
sistema novo**, só um `CampaignManager` que reage às missões sendo
concluídas e reaproveita o `DialogueManager` (Fase 3) pra mostrar
intro/outro de cada capítulo.

### Os capítulos (mapeados nos locais onde as missões já acontecem)

| Capítulo | Missões | Onde |
|---|---|---|
| 1 — Primeiro Trabalho | m01 (phishing) | Casa |
| 2 — A Empresa | m02 (senhas), m03 (hash) | Empresa |
| 3 — Rede e Perímetro | m06 (redes), m07 (firewall) | Empresa + Centro de Tecnologia |
| 4 — Criptografia e Fraude | m04 (cripto), m05 (phishing) | Centro de Tecnologia |
| 5 — A Aplicação | m08 (logs), m09 (SQLi), m10 (XSS) | Loja Eletrônica |
| Final — O Incidente | (todas as anteriores) | — |

Isso mudou os nomes/agrupamento em relação ao roteiro original (que
tinha "O E-mail" e "O Servidor" como capítulos próprios), porque
preferi mapear os capítulos em cima de onde cada desafio **já mora**
no jogo, em vez de mover missões de lugar só pra bater o nome exato —
o efeito final (uma progressão com começo, meio e fim) é o mesmo.

### Como funciona

- Ao entrar na cidade pela primeira vez, toca a introdução do
  Capítulo 1 (uma mensagem recebida, convidando pro primeiro trabalho).
- Terminar a última missão pendente de um capítulo dispara a mensagem
  de fechamento dele e, na sequência (só depois que o jogador fecha a
  caixa de diálogo), a introdução do capítulo seguinte.
- Terminar o Capítulo 5 dispara o **Capítulo Final — O Incidente**: uma
  mensagem de encerramento citando todos os 9 conceitos aprendidos,
  junto com nível final e XP total conquistado.
- O CYBER PHONE (Perfil) ganha um selo **🏆 CASO ENCERRADO** depois do
  final.

### Decisões de arquitetura (Fase 8)

- **Zero UI nova**: capítulos usam a mesma caixa de diálogo dos NPCs
  (`DialogueManager.start_dialogue`), só com o título do capítulo como
  "quem fala". Menos código, e visualmente já é familiar pro jogador.
- **Encadeamento via sinal, não temporizador**: pra não sobrepor a
  mensagem de fechamento de um capítulo com a introdução do próximo,
  o `CampaignManager` escuta `DialogueManager.closed` (sinal novo,
  disparado quando a caixa fecha) uma única vez
  (`CONNECT_ONE_SHOT`) e só então mostra a próxima.
- **Nada de posições fixas de progresso salvas em disco**: como o
  projeto ainda não tem save/load (isso é escopo de uma fase futura),
  os capítulos são recalculados a partir do estado das missões
  (`MissionManager`) — se um dia o save chegar, a campanha já funciona
  sem mudanças.

## Checklist de teste manual (Fase 8)

- [ ] Ao entrar na cidade pela primeira vez (jogo do zero), aparece a
      introdução do Capítulo 1 antes de qualquer outra coisa.
- [ ] Voltar de dentro de uma casa/empresa **não** repete a introdução.
- [ ] Completar a Missão 01 mostra a mensagem de fechamento do
      Capítulo 1 e, ao fechar, a introdução do Capítulo 2.
- [ ] Completar m02 sozinha não fecha o Capítulo 2 (falta m03); só ao
      completar as duas o capítulo fecha.
- [ ] Completando as 10 missões, no final aparece a mensagem do
      "CAPÍTULO FINAL — O INCIDENTE" com nível e XP total corretos.
- [ ] Depois do final, o CYBER PHONE mostra "🏆 CASO ENCERRADO" no Perfil.
- [ ] Durante qualquer mensagem de capítulo, o jogador não se move
      (mesma trava que já existia pro diálogo dos NPCs).
- [ ] Nenhum erro no console jogando a campanha inteira do início ao fim.

Se algo falhar, me manda a mensagem exata do erro (arquivo + linha)
que eu corrijo antes de seguirmos.

## O que foi implementado na Fase 9

### Sons (placeholders sintetizados por código)

Como o sandbox não tem acesso a bancos de assets de áudio, os 6 sons
foram **gerados por código** (`assets/audio/*.wav`, ondas simples
sintetizadas em Python) — dá pra trocar por sons de verdade depois só
substituindo os arquivos, sem mexer em nenhum script:

| Som | Quando toca |
|---|---|
| `footstep` | A cada passo, enquanto o jogador anda (com um pequeno intervalo, não é contínuo) |
| `interact` | Ao abrir uma porta, falar com um NPC ou acessar um computador |
| `blip` | Avançar uma fala de diálogo, abrir/fechar o CYBER PHONE |
| `keypress` | Enviar um comando no terminal |
| `success` | Missão concluída (dispara de um lugar só — `HUD.gd` — não importa se veio de um quiz, do terminal ou da leitura de um e-mail) |
| `error` | Resposta errada no quiz, linha errada em `report`, `login` negado |

- **`SoundManager`** (autoload): toca os sons por nome, com um **pool
  de 6 `AudioStreamPlayer`** — assim um som novo não corta o anterior
  (importante pros passos, que tocam em sequência rápida).

### Transição em fade entre cenas

Trocar de cena (cidade ↔ interior) era um corte seco. Agora tem um
**fade pra preto** antes de trocar e um fade de volta depois — a
mudança inteira ficou em `SceneTransition.gd`, que já era o único
lugar que trocava de cena, então nenhuma porta precisou saber que isso
mudou.

### Pequenas animações de entrada

O terminal e a tela de desafio agora aparecem com um **fade suave**
(0.15s) em vez de aparecerem instantaneamente — evita o "pisca" seco
de uma tela cheia surgindo do nada.

### Decisões de arquitetura (Fase 9)

- **Som de sucesso centralizado**: em vez de espalhar
  `SoundManager.play("success")` em cada lugar que pode concluir uma
  missão (terminal, quiz, leitura de e-mail...), o som toca de um
  único ponto — `HUD._on_mission_completed()`, que já escuta o sinal
  `MissionManager.mission_completed`. Um lugar só pra manter, funciona
  não importa por onde a missão foi concluída.
- **`await` para orquestrar o fade**: `SceneTransition.gd` usa
  `await Fade.fade_out()` / `await Fade.fade_in()` — GDScript trata
  isso como uma coroutine automaticamente, então nenhuma porta
  (`Door.gd`/`ExitDoor.gd`) precisou virar `async` pra chamar.
- **Áudio como placeholder, igual a arte**: os sons deixam claro no
  comentário do arquivo que são temporários — trocar por sons de
  verdade (ou pelos do pacote do Kenney, quando você mandar) é só
  substituir o `.wav`, sem tocar em nenhum script.

## Checklist de teste manual (Fase 9)

- [ ] Andar pela cidade toca passos num ritmo razoável (não muito
      rápido, não contínuo/travado).
- [ ] Abrir uma porta, falar com NPC e acessar um computador tocam o
      som de interação.
- [ ] Avançar uma fala de diálogo e abrir/fechar o CYBER PHONE tocam o
      blip.
- [ ] Enviar qualquer comando no terminal toca o som de tecla.
- [ ] Completar uma missão (por qualquer caminho: e-mail, quiz,
      scan/connect, firewall, logs, login, postar) toca o jingle de
      sucesso.
- [ ] Errar uma opção do quiz, ou usar `report`/`login` errado no
      terminal, toca o som de erro.
- [ ] Entrar/sair de um prédio faz um fade pra preto e volta, em vez de
      cortar seco.
- [ ] Abrir o terminal ou um desafio tem uma pequena animação de
      entrada, não aparece instantâneo.
- [ ] Nenhum som "engasga" tocando vários rápido (ex.: andar rápido +
      abrir porta ao mesmo tempo).
- [ ] Nenhum erro no console.

Se algo falhar, me manda a mensagem exata do erro (arquivo + linha)
que eu corrijo antes de seguirmos.

## Sistema de dicas (pedido a qualquer momento, não só depois de errar)

Antes, só existia dica reativa: errar uma opção do quiz mostrava uma
explicação. Agora dá pra pedir ajuda **antes** de tentar, de três
jeitos:

- **No terminal**: qualquer computador com desafio ligado a ele aceita
  o comando `dica` (funciona pros 10 desafios — quiz, rede, firewall,
  logs, SQLi e XSS). A mensagem de abertura do terminal já avisa
  `"Travou? Digite 'dica'."` quando isso está disponível.
- **Na tela de quiz**: um botão **💡 Pedir dica** no canto, do lado do
  título — mostra a mesma dica sem contar como erro nem atrapalhar a
  tentativa.
- **No CYBER PHONE**: a missão que está **em andamento** agora mostra
  a dica dela direto na lista de missões — dá pra consultar de
  qualquer lugar da cidade, sem precisar estar no computador certo.

Todas as três fontes usam o **mesmo texto**, guardado uma vez só em
`ChallengeData.gd` (campo `hint`, que antes só existia pros 4 quiz
como `wrong_hint` — generalizei pros outros 6 desafios também).
Escrevi as dicas pra apontar o caminho sem entregar a resposta pronta.

## Ajustes a partir do seu projeto com a arte do Kenney já integrada

Você mandou o projeto de volta com os assets já trocados (aliás, muito
bem feito — usar `texture_repeat` + `region_rect` pra ladrilhar as
texturas de 16×16 em vez de esticá-las foi uma escolha melhor que a
minha original). A partir desse projeto, fiz três ajustes:

### 1. Cenas maiores (cidade e as 4 casas/interiores)

- **Cidade**: de 30×20 tiles (960×640) para **42×28 tiles (1344×896)**
  — quase 2,2× mais área. Recalculei a posição dos 9 prédios com bem
  mais espaço entre eles, as bordas do mapa, e a câmera do minimapa.
- **Interiores** (`HouseInterior`, `OfficeInterior`, `TechCenterInterior`,
  `AppInterior`): de 192×128 para **384×256** (dobro em cada direção,
  4× mais área) — computadores e NPC bem mais espaçados, sem parecer
  amontoado.
- Como isso mexeu em muita coisa nos 4 interiores ao mesmo tempo, apliquei
  as mudanças por um script que troca só as posições/tamanhos,
  preservando as texturas e os desafios que você já tinha ligado a
  cada computador — nada de recriar os arquivos do zero.

### 2. Visual mais "hacker" na cidade

- **Prédios com textura por tipo**, em vez de um tijolo só tingido de
  cor: casas usam `brick_orange_tile`, TechCorp/DataSoft usam
  `brick_red_tile` (já eram assim), e o Centro de Tecnologia + a Loja
  agora usam `concrete_gray_tile` — o mesmo material "tech" que você já
  tinha colocado nos interiores deles, então por fora e por dentro
  ficou consistente.
- **Tom geral mais escuro e azulado** (`CanvasModulate`), pra dar clima
  de cidade à noite.
- **Decoração nova, gerada do zero** (mesmo grid 16×16 dos seus
  assets): `neon_sign.png` (letreiro brilhante ciano/magenta) e
  `server_rack.png` (rack de servidor com luzinhas verdes/cianas),
  espalhados perto dos prédios de tecnologia e da rua principal.

### 3. Personagem "andando" de verdade

Sem um spritesheet de caminhada (o `player_kenney.png` é um quadro
único), adicionei uma **animação de balanço procedural** em
`Player.gd`: o sprite sobe e desce e estica/esmaga levemente em
sincronia com os passos enquanto o jogador anda, e volta suavemente ao
normal quando para. Não substitui uma animação de verdade, mas já
tira a sensação de "personagem deslizando parado".

## Dicas do que dá pra melhorar (e novidades pra explorar)

**Visual**
- Se algum pacote do Kenney tiver variações de personagem por direção
  (cima/baixo/lado), dá pra montar um `AnimatedSprite2D` com 4 estados
  e ter uma "caminhada" de verdade em vez do balanço procedural.
- TileSet da cidade com mais variedade (calçada com bueiro, poças
  refletindo neon, grade de metrô) — hoje são só 3 tiles lisos.
- Uma leve luz/vinheta ao redor do jogador (`Light2D` com modo aditivo)
  reforça bastante o clima "cidade escura, você é o ponto de luz".

**Áudio**
- Música ambiente baixinha em loop (o roteiro original já previa isso
  pra depois) — dá pra sintetizar um pad simples do mesmo jeito que os
  efeitos, ou usar uma faixa CC0.
- Som diferente por tipo de chão (grama vs. rua vs. calçada) deixa os
  passos mais reais.

**Jogabilidade**
- Indicador visual de objetivo atual no minimapa (um ponto piscando na
  direção da próxima missão).
- Um segundo NPC "narrador" que comenta o progresso da campanha, além
  das mensagens de capítulo.
- Os 2 desafios que faltam do escopo original das Fases 6/7 (o roteiro
  cita `connect`, `decrypt` mais avançados) — dá pra estender o mesmo
  padrão de comandos do terminal.

**Técnico**
- Save/load (mencionei isso no teste final também) — com os autoloads
  já organizados do jeito que estão, salvar em JSON é bem direto.
- Tela de opções (volume dos efeitos, tamanho da janela).

Nenhuma dessas é obrigatória — são só direções caso você queira
continuar depois de fechar o escopo principal.

## Correção: foco do terminal (de novo)

Você reportou que, depois de reestruturar o terminal como "tela
grande" (Fase 7), o campo de texto voltou a perder o foco depois de
`Enter`. A correção anterior (devolver o foco de forma deferida após
cada comando) continuava lá no código, mas reforcei com uma **rede de
segurança rodando a cada frame**: enquanto o terminal está aberto, se
por qualquer motivo o campo perder o foco, ele é recuperado
imediatamente — não depende mais só do momento exato do envio do
comando.

## O que foi feito na Fase 10 (revisão geral)

Sem o editor do Godot à disposição, a "execução" desta fase foi uma
bateria de checagens automáticas no projeto inteiro, cobrindo os
pontos que o escopo original pede:

- **Referências `$Caminho/DoNo` nos scripts × árvore real das cenas**
  — script por script, cena por cena. Nenhum problema real (dois
  alertas do checador eram falso-positivo do próprio script de
  checagem, não do jogo — documentei o porquê).
- **Todo `ext_resource` aponta pra um arquivo que existe** — nenhuma
  textura, script ou cena "fantasma".
- **Toda missão referenciada em portas (`unlock_after_mission`) e NPCs
  (`mission_to_start`) existe no `MissionManager`** — `m01` é a única
  usada fora do fluxo do terminal/quiz, e existe.
- **Esquema de colisão consistente em todo o projeto**: layer 1 =
  mundo estático (prédios, paredes, NPCs), layer 2 = jogador, layer 0
  + mask 2 = qualquer área de interação (portas, NPCs, computadores).
  Nenhuma inconsistência encontrada.
- **TileSet da cidade × geração procedural**: os 3 tiles registrados
  no `.tres` batem exatamente com as constantes usadas em `City.gd`.
- **Todos os scripts começam com `extends` válido**, sem arquivo
  corrompido ou cortado no meio (conferi principalmente os 4
  interiores, que foram gerados por transformação de texto em cadeia
  ao longo de várias fases).
- **Limpeza**: removi `TestMap.tscn`, a cena de teste da Fase 1 que já
  não era mais referenciada em lugar nenhum desde que `City.tscn`
  virou a cena principal — só sobrava como arquivo morto.

### O que ainda não existe (por escopo, não por esquecimento)

- **Save/load**: o roteiro original trata isso como um item à parte
  ("Salvamento"), não como parte do "teste final". Hoje o progresso
  vive só na memória durante a sessão (os autoloads persistem entre
  cidade/interiores, mas reiniciar o jogo zera tudo). Posso implementar
  isso como próximo passo se você quiser.
- **Arte definitiva do Kenney**: ainda não recebi o zip — quando
  mandar, entra sem precisar repetir esta revisão.

## Checklist de teste manual (Fase 10)

- [ ] No terminal, digitar vários comandos em sequência **nunca**
      exige clicar no campo de novo, nem depois de vários comandos
      seguidos.
- [ ] Percorrer a campanha inteira do zero até o "CASO ENCERRADO" sem
      nenhum erro aparecer no console.
- [ ] Entrar e sair de cada um dos 9 prédios pelo menos uma vez.
- [ ] Testar os 10 desafios (4 quiz + scan/connect + firewall + logs +
      SQLi + XSS).
- [ ] Conferir que o Centro de Tecnologia começa bloqueado e destrava
      certo depois da Missão 01.
- [ ] Colidir de propósito com cada tipo de obstáculo (paredes da
      cidade, prédios, paredes dos interiores, NPCs) — não deve ser
      possível atravessar nenhum.
- [ ] Abrir o CYBER PHONE em qualquer momento do jogo e conferir que
      Missões/Conhecimentos/Perfil sempre mostram o estado certo.

Se algo falhar, me manda a mensagem exata do erro (arquivo + linha)
que eu corrijo.

## E agora?

O projeto cobre as 10 fases da metodologia original. Os próximos
passos ficam a seu critério — pode ser:

- mandar o **zip do Kenney** pra eu trocar a arte placeholder;
- pedir o **save/load** (não estava no escopo do "teste final", mas é
  citado no roteiro original como item futuro);
- ajustar qualquer coisa que aparecer nos testes;
- ou considerar o protótipo pronto pra entrega, do jeito que está.

## Menu principal e menu de pausa

- A cena principal agora é `scenes/ui/MainMenu.tscn` (em **Projeto →
  Configurações do Projeto → Aplicação → Executar → Cena Principal**).
  Botões: **Continuar** (só aparece com um jogo em andamento), **Novo jogo**,
  **Opções**, **Controles** e **Sair**.
- O **celular (Cyber Phone)** abre com TAB/ESC ou clicando em
  **CELULAR** no canto do HUD. Ele também pausa o jogo. Apps:
  - **Mensagens**: recados que chegam sozinhos quando um capítulo começa,
    quando uma missão é aceita e quando ela é concluída. O HUD mostra
    quantas não foram lidas, e o ícone "vibra" com uma notificação.
  - **Pistas**: para cada missão em andamento, a 1ª pista vem junto com a
    missão; as próximas são liberadas no botão **Revelar próxima pista**.
    A última é a dica do desafio (`ChallengeData`).
  - **Missões**, **Perfil** (nível, XP, conhecimentos) e **Ajustes**
    (volume/tela, menu principal, sair).
  - Textos das pistas e remetentes ficam em
    `scripts/systems/PhoneManager.gd` (constantes `CLUES` e `CONTACTS`).
- **Opções** (`scenes/ui/OptionsPanel.tscn`): volume geral e tela cheia,
  salvos em `user://settings.cfg` pelo autoload `Settings`.
- Funciona com mouse ou teclado (setas + Enter; ESC volta).

## Cidade em quarteirões

A cidade (`scenes/world/City.tscn`) tem 6 quarteirões separados por ruas, cada
um preparado para um grupo de desafios: Bairro Residencial e Vila Residencial
(Missão 01), Praça Central (início, com o Guia), Distrito Empresarial (02, 03,
06), Centro de Tecnologia (04, 05, 07) e Comércio (08, 09, 10). Um "!" amarelo
marca os prédios com missões do capítulo atual, e o minimapa mostra a cidade.
Detalhes e como acrescentar prédios/ruas: `docs/TILESET_32.md`.
