# Copia de Seguranca - Modo Multiplayer

Copia de todos os arquivos relacionados ao modo multiplayer do jogo, feita antes de alteracoes no layout da ArenaMultiplayer.

---

## Arquivos de Rede (src/multiplayer/)

### Protocol.js
Define o protocolo de comunicacao TCP entre host e cliente.
- Porta: 4963
- Enum `MSG`: todos os tipos de mensagem possiveis (ROOM_CREATED, PLAYER_ACTION, STATE_UPDATE, GAME_OVER, etc.)
- `criarMensagem(tipo, payload)`: serializa uma mensagem JSON com timestamp, terminada em `\n`
- `criarParser()`: retorna uma funcao com buffer proprio que lidar com fragmentacao de mensagens TCP (uma mensagem pode chegar dividida em varios eventos `data`, ou varias mensagens chegar grudadas). Acumula chunks e so extrai linhas completas.

### TCPServer.js
Servidor TCP para o HOST da partida (classe `GameServer`).
- `iniciar(hostIP)`: cria um servidor TCP na porta 4963 e escuta conexoes
- Quando um cliente conecta, configura o parser de mensagens e comeca a receber dados
- `enviar(tipo, payload)`: envia mensagem para o cliente conectado
- `parar()`: fecha a conexao e o servidor
- Suporta apenas 1 cliente simultaneo (1v1)

### TCPClient.js
Cliente TCP para quem entra na partida (classe `GameClient`).
- `conectar(hostIP)`: conecta ao servidor TCP do host na porta 4963
- Cada conexao cria um novo parser (buffer limpo a cada tentativa)
- `enviar(tipo, payload)`: envia mensagem para o host
- `parar()`: fecha a conexao
- Callbacks: `onConectado`, `onMensagemRecebida`, `onDesconectado`

### discovery.js
Descoberta de salas na rede local via UDP broadcast (porta 4445).
- `startBroadcast(hostName, ip, playerCount)`: envia broadcasts UDP a cada 2s com dados da sala (nome do host, IP, jogadores)
- `startListening(callback)`: escuta broadcasts UDP e mantem lista de salas descobertas
- Salas expiram apos 6 segundos sem broadcast
- `getRooms()`: retorna salas ativas (limpa expiradas)
- Usado pela TelaLobby para encontrar partidas automaticamente na rede

---

## Telas (src/screens/)

### TelaLobby.js
Tela de lobby multiplayer - punto de entrada para criar ou entrar em partida.
- Mostra IP local do dispositivo
- Input para digitar IP do host manualmente
- Lista de salas descobertas automaticamente via UDP (discovery.js)
- Botoes: "Criar Sala" (vai para TelaSala como host) e "Entrar" (vai para TelaSala como cliente)
- Limpa salas expiradas periodicamente

### TelaSala.js
Tela de espera/lobby da sala antes de comecar o jogo.
- Cria `GameServer` (se host) ou `GameClient` (se cliente)
- Troca informacoes dos jogadores (nome, avatar) via PLAYER_INFO
- Gerencia estado de "pronto" (PLAYER_READY)
- Host inicia o broadcast UDP para ser encontrado
- Quando ambos prontos, host envia GAME_START e navega para ArenaMultiplayer
- Gerencia conexoes, erros e desconexao do oponente

### ArenaMultiplayer.js
Tela principal da batalha multiplayer (e tambem simulacao N-jogadores com IA).
- **Modo Multiplayer 1v1 (TCP)**: host e cliente jogam pela rede
  - Host cria estado inicial e envia para cliente
  - Sincronizacao: host envia estado completo apos cada acao
  - Cliente envia acoes via PLAYER_ACTION, host valida e aplica
  - Layout 1v1: MaoOponente (topo) + DecksArea (centro) + MaoJogador (baixo)
- **Modo Simulacao (2-8 jogadores)**: jogo local com IA
  - Jogador 0 = humano, resto = IA controlada por useIAMulti
  - Layout circular: posicoes calculadas por calcularPosicoes()
- Animacoes: CartaVoadora (voo simples), CartaSaidaComLift (salta da mesa antes de voar)
- Componentes internos: SlotOponente (painel de oponente no layout circular), MesaCentral (arena no centro)
- Gerencia: selecao de cartas, jogar/Passar turno, pause modal, game over overlay, particles, score popups

---

## Hooks (src/hooks/)

### useCombat.js
Hook principal do motor do jogo - contem toda a logica de estado.
- `criarEstadoMultiplayer()`: cria estado inicial para 1v1 (baralho embaralhado, maos distribuidas)
- `criarEstadoMultiN()`: cria estado para N-jogadores (simulacao)
- `jogarCartaSemComprarN()`: aplica efeito da carta e gera animacao de IA
- `passarTurnoN()`: avanca turno, compra carta, verifica fim de jogo
- `passarTurno()`: avanca turno sem compra extra (usado no multiplayer)
- Logica de efeitos: ATAQUE (cobra dinheiro), DEFESA (bloqueia), PROTECAO (escudo), CORINGA (copia), ACAO (efeito especial), EFEITO (variados)
- Verificacao de falencia, fundo de emergencia, protecao

### useIAMulti.js
Hook de IA para modo simulacao N-jogadores (2-8 jogadores).
- Cada IA joga uma carta aleatoria da mao, depois compra e passa o turno
- Timeouts escalonados (800ms-1500ms) para simular tempo de pensamento
- `encontrarAlvo()`: escolhe alvo aleatorio entre jogadores vivos (exceto a si mesmo)
- So executa quando e a vez do jogador IA (idx > 0)
- Desliga quando jogo termina ou estado e null

---

## Contexto (src/context/)

### GameContext.js
Provider e reducer que gerencia todo o estado do jogo.
- **Actions**:
  - `INICIAR_MULTIPLAYER`: cria estado para 1v1 multiplayer (host)
  - `INICIAR_MULTI_N`: cria estado para N-jogadores (simulacao)
  - `SET_MULTIPLAYER_STATE`: substitui estado inteiro (cliente recebe do host)
  - `JOGAR_CARTA_SEM_COMPRA`: aplica carta sem comprar
  - `JOGAR_CARTAS_SEM_COMPRA`: aplica multiplas cartas (batch)
  - `PASSAR_TURNO`: avanca turno
  - `PASSAR_TURNO_N`: avanca turno no modo N-jogadores
  - `BATALHA_INICIADA`: marca que animacao inicial terminou
  - `SET_FIM_DE_JOGO`: define resultado do jogo
  - `RESETAR_JOGO`: volta ao estado inicial
- `GameProvider`: wrapper que disponibiliza estado e dispatch via Context
- `useGameState()`: hook para acessar estado e acoes do jogo
