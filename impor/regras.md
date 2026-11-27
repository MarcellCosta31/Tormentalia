# Regras V7 — Tormentalia Manual de Regras V7

> **Fora do escopo desta versão:** construção individual do baralho de 60 cartas,
> construção de deck por jogador e mecânicas de building. O baralho continua sendo
> o catálogo compartilhado e infinito de 49 cartas de `cartas.lua`. Todas as
> correções de divergências numéricas e mecânicas novas foram aplicadas no código
> Lua (raiz do projeto), mantendo a escolha do usuário de "Manter baralho infinito".

---

## 1. Visão geral

Duelo de cartas de gestão: cada jogador é uma empresa com um **saldo em reais**.
Jogando cartas de ação/efeito você ganha dinheiro, derruba o saldo dos oponentes
ou interfere nas mãos alheias. **Vence quem tiver o maior saldo ao final dos 10
turnos** (vitima por Tempo). Empates em saldo resultam em empate.

- **Jogadores:** 2 a 8 (duelo padrão: você x oponente; arena livre: 2..8).
- **Baralho:** catálogo compartilhado de **49 cartas** com pesos; cada compra
  cria uma cópia nova (baralho infinito). **Não** há deck building de 60 cartas.
- **Mão inicial:** **7 cartas** por jogador. O teto normal é 7; durante o
  evento do Deus Mercado o teto pode ser excedido (até 10 total).
- **Saldo inicial:** **R$ 2.000** por jogador.
- **Renda de rodada:** **R$ 1.000** base, mais **R$ 100** a mais a cada rodada
  que passa (multiplicativo: `valor * (1 + produtividade)`, piso em 0).
  A renda é creditada no fim da rodada no livro-caixa.
- **Turnos por partida:** **10** rodadas completas.
- **Vez inicial:** sorteada aleatoriamente.
- **Sem reembaralhar:** o descarte não volta ao baralho; o baralho é infinito.
- **Evento do Deus Mercado:** intervention a cada 2 rodadas (rodadas 2, 4, 6, 8),
  **nenhuma após a rodada 10**. Cada intervention tem 4 passos (em ordem):
  1. Leilão (produto único), 2. Lojinha, 3. Fusão (2–5 cartas → Super Carta),
     4. Fechar. O evento não roda após a rodada 10.

## 2. Turno

Cada jogador, na sua vez, pode:

1. Jogar até **2 cartas** (`CARTAS_POR_TURNO = 2`). O limite vale para qualquer
   tipo de carta. Cartas da Área Segura **não** consumem a quota.
2. **Passar a vez** quando quiser.
3. Guardar/usar a **Área Segura** (ver §6), sem gastar a quota.

**Tempo de turno:** base de **25 segundos** (`TURNO_BASE_SEGUNDOS`), afetado
por Sem tempo / Seiso. No modo um jogador local o tempo do humano não é
contado; a expiração real vale no modo em rede.

**Fim do turno** (automático ao gastar a quota ou ao passar):

1. Quem termina o turno completa a mão até 7 (o end-of-turn draw stops at 7).
2. Se era o **último jogador vivo da rodada**, acontece o **fim da rodada**:
   renda, verificação de combinações, e — se a rodada for par e ainda não
   passou da rodada 10 — o **Evento do Deus Mercado** (4 passos: leilão →
   lojinha → fusão → fechar).
3. A vez avança para o próximo jogador vivo (eliminados/desconectados são
   pulados; a virada do último para o primeiro conta o turno).
4. No início do turno de quem vai jogar, os efeitos com duração são
   processados, as defesas envelhecem e os contadores são decrementados.

**Descarte voluntário não existe:** o humano nunca descarta no fim do turno
(só via efeito Queima de Estoque).

## 3. Sucesso e falha

- Cada carta (exceto Proteções) tem uma **chance de sucesso** própria
  (55%..100%). `sucesso = random() < chance`.
- Em caso de **falha**, a carta não aplica efeito especial; o dinheiro de
  falha (`alteracaoSaldoFalha`), quando existe, é aplicado mesmo assim.
- A chance é calculada pelos modificadores ativos do invocador:
  `MOD_CHANCE` (soma), `MOD_FALHA` (reduz a chance de falha),
  `CHANCE_FIXA` (fixa, 1 uso), `MULT_CHANCE` (multiplica, 1 uso). Resultado
  preso em 0..1.
- **Bônus de cópia:** a partir da **segunda carta com o mesmo `id` no mesmo
  turno** do jogador, a chance é multiplicada por **1,3** (+30%, Carta Dobrada),
  limitada a 100%. O contador zera no início do turno do dono.

## 4. Defense Slot, Curinga Global e Cartas Jogadas

### Defense Slot

- Cartas do tipo **PROTECAO** (ou com `tipo == "PROTECAO"`) vão para o
  **Defense Slot** em vez do descarte.
- O slot é **único**: uma nova defesa substitui a anterior; a antiga vai para
  o descarte.
- Duração padrão: **2 turnos do dono** (`DEFESA_TURNOS = 2`). O contador
  diminui no início do turno do dono e, ao zerar, a carta vai ao descarte.
- `J.ehDefesa(c)` = `classe == "Defesa" OR tipo == "PROTECAO"` (união).
  Assim, cartas que atacam o oponente mas têm `tipo == "PROTECAO"` também
  ocupam o slot (ex.: ids 8 e 13, cujas classes foram relabeladas de "Defesa"
  para "Acao" pois atacam o oponente).
- Se `protegeContra` existe, bloqueia apenas cartas daquele tipo (ACAO ou
  EFEITO); sem tipo, bloqueia qualquer perda/efeito direcionado.
- Ao bloquear uma carta, a defesa é consumida e vai ao descarte.
- `PROTECAO_TOTAL` (Atestado Médico) é uma imunidade temporária por efeito e
  não usa o slot.

### Curinga Global (Visor de Curingas)

- Antes do leilão, um **Curinga Global** é sorteado e aplicado a todos os
  jogadores. O novo substitui o anterior e entra no visor ativo.
- O visor de curingas guarda, no máximo, as **2 últimas substituições**
  anteriores (pilha com até 2 entradas). O global atual não entra no histórico.
- Candidatos suportados pelo motor: **O Monstro Inflação**, **Seletividade de
  Taylor** e **Flutuação do Mercado**.
- O Curinga Global ativo aparece no topo da mesa durante o leilão e na Pilha de
  Curinga (visor mostra global + até 2 anteriores).

### Played Cards Pile (Jogadas)

- Cartas de **ACAO/EFEITO** jogadas ficam espelhadas na **Pilha de Jogadas**
  do jogador, usada como histórico/visual.
- Elas também continuam indo para o descarte compartilhado.
- A UI mostra as três pilhas no canto inferior esquerdo: **DEFESA**, **JOGADAS**
  e **CURINGA** (visor), além de um resumo financeiro.

## 5. Dinheiro, livro-caixa e falência

- Qualquer delta de saldo passa pela **Flutuação do Mercado** se ativa
  (ganhos positivos viram um valor aleatório entre 0 e o original).
- **Não existe mais fundo de emergência.** Ao chegar a **zero**, o jogador vai
  imediatamente à **FALÊNCIA** (`falido = true`, `status = ELIMINADO`,
  `saldo = 0`). O saldo nunca fica negativo.
- **Livro-caixa (`extrato`):** cada jogador registra capital inicial,
  receitas, despesas e movimentos com categoria (`renda`, `evento`, `leilao`,
  `lojinha`, `combo`, `efeito`), rodada e saldo resultante.
- O resumo `jogo.resumoFinanceiro(j)` devolve inicial, receitas, despesas,
  saldo, lucro e movimentos. O **lucro é história/estatística**, **não** é
  critério de vitória. O overlay de pausa mostra o resumo e os últimos movimentos.

## 6. Área Segura

- Espaço para **1 carta** por jogador (`AREA_SEGURA_MAX = 1`), tirada da
  mão durante o próprio turno.
- So cabe uma carta guardada: um novo guarda substitui a anterior.
  Guardar não consome quota nem encerra o turno.
- Jogar a carta guardada **não** consome quota, **não** compra carta e **pode**
  ser usada até fora do próprio turno** (reação). Depois do efeito, vai ao
  descarte.
- A IA guarda no início do próprio turno com chance que cresce nos ciclos.
- **Manual V7 4.2:** fora do turno, `jogarAreaSegura` retorna nil (a carta
  continua guardada na área).

## 7. Combinações de Mercado

Verificadas no **fim da rodada**, depois da renda e antes do Evento do Deus
Mercado. Cada combinação paga uma vez por rodada e exige todas as cartas
listadas jogadas com sucesso naquela rodada:

| Combinação | Cartas | Prêmio |
|---|---|---|
| **5S Completo** | Seiri, Seiton, Seiso, Seiketsu, Shitsuke | **+R$ 300** |
| **Tríade Financeira** | Empréstimo, Nosso, Cris e Greg Agiotas | **+R$ 250** |
| **Marketing e Produção** | Toyotinho, Presente do Noel, Queima de Estoque | **+R$ 200** |
| **Controle e Defesa** | Psicologia Industrial, Mão Visível, Tempos e Movimentos | **+R$ 150** |

Os nomes são os `nome` do catálogo; o conjunto é resetado ao fim de cada
rodada. A UI mostra um popup `COMBO ... +R$ ...` quando a combinação fecha.

## 8. As cartas

Tipos: `ACAO`, `EFEITO`, `PROTECAO`, `CORINGA`. A tabela abaixo lista o núcleo
clássico; o catálogo completo (49 cartas, com pesos) está em `cartas.lua`.

| # | Nome | Tipo | Chance | Efeito exato |
|---|------|------|--------|--------------|
| 1 | Nosso | ACAO | 100% | O alvo **doa uma porcentagem aleatória (0–100%)** do saldo ao invocador. |
| 2 | Toyotinho | ACAO | 70% | Invocador **+R$ 400** no sucesso; **−R$ 400** na falha. |
| 3 | Sem tempo | ACAO | 80% | Invocador **+R$ 50**; por **3 turnos**, o turno dos oponentes fica com **2 segundos**. |
| 4 | Essa Vai Ser a Minha Maior Vigarice | ACAO | 100% | Rouba **2 cartas** do alvo; escolha às cegas. Teto de mão: 9. |
| 5 | Presente do Noel | ACAO | 55% | Invocador **+R$ 200**; alvo **−R$ 100** e **−10% de chance** por **2 turnos**. |
| 6 | O Monstro Inflação | CORINGA | 100% | Por **2 turnos**, todos: a chance de falha cai 40% (fator 0.6). |
| 7 | Cris e Greg Agiotas | ACAO | 90% | Alvo **perde de R$ 150 a R$ 300**. |
| 8 | Tempos e Movimentos | EFEITO | 90% | 1 uso no alvo: a próxima carta dele tem chance exata de 50%. |
| 9 | Queima de Estoque | ACAO | 90% | O alvo descarta 1 carta aleatória e puxa 1. |
| 10 | Psicologia Industrial | PROTECAO | 100% | Defesa contra **EFEITO** no Defense Slot por 2 turnos. |
| 11 | Empréstimo | ACAO | 90% | Invocador **+R$ 500**; paga R$ 100 por turno durante 5 turnos. |
| 12 | Mão Visível | PROTECAO | 100% | Defesa contra **ACAO** no Defense Slot por 2 turnos. |
| 13 | Seiketsu | EFEITO | 100% | 1 uso no alvo: a próxima carta negativa tem chance fixa de 50%. |
| 14 | Shitsuke | ACAO | 90% | 1 uso no alvo: a próxima carta de ação dura +1 turno. |
| 15 | Seiton | ACAO | 95% | **+R$ 500** no próximo turno do invocador. |
| 16 | Seiri | ACAO | 90% | Devolve 3 cartas ao baralho; por 3 turnos puxa 3 e fica com 1. |
| 17 | Seiso | ACAO | 90% | +2 segundos no turno do invocador nos próximos 2 turnos. |
| 18 | Seletividade de Taylor | CORINGA | 100% | Por 2 turnos, todos trocam 3 cartas aleatórias no início do turno. |
| 19 | Flutuação do Mercado | CORINGA | 100% | Por 2 turnos, ganhos viram valor aleatório (0..original). |
| 20 | Cada Um No Seu Quadrado | ACAO | 70% | Invocador **+R$ 500**; **−R$ 100** na falha. |
| 21 | Pego no Flagra | ACAO | 60% | Alvo com **−20% de chance** por 2 turnos. |
| 22 | Que Atrevido | EFEITO | 70% | 1 uso no alvo: a próxima carta tem chance ×0.5. |
| 23 | Overclock Produtivo | ACAO | 90% | Por 5 turnos, o bônus positivo do Deus Mercado é ×1.1. Novo substitui o anterior. |

### Detalhes de efeitos

- **Dívida (Cris e Greg):** valor sorteado (150..300), perda direta do alvo.
- **Roubo (Vigarice):** no app em rede o invocador escolhe os códigos sem ver
  o conteúdo; a mão pode chegar a 9.
- **Efeitos de duração** são lidos no turno do portador; os demais decrementam
  no início do turno.
- **Shitsuke/Seiketsu/Que Atrevido/Tempos** são "1 uso".
- **Proteções** vão para o Defense Slot (não para o descarte imediato).
- `J.ehDefesa(c)` = `classe == "Defesa" OR tipo == "PROTECAO"` (união).

## 8. Leilão e Lojinha (meta-eventos)

A cada **2 rodadas concluídas** (`LEILAO_INTERVALO = 2`), depois do evento do
Deus Mercado e antes do turno seguinte, a mesa pausa para os seguintes fases
(em ordem, se não tiver passado da rodada 10):

### 8.1 Curinga Global

Antes do leilão, um Curinga Global é sorteado e aplicado a todos os jogadores.
O anterior é removido e entra no visor (até 2 últimas substituições guardadas).

### 8.2 Leilão (V7 5.7)

- **Duração:** **15 segundos** (`LEILAO_SEGUNDOS`).
- **Oferta:** **um produto único** — 1 carta **ou** kit de 2 a 3 cartas
  (35% de chance de conter uma Super Carta). O produto é sorteado aleatoriamente.
- **Lances:** **um único lance por jogador**, em passos de **R$ 100**, de 0 a
  **R$ 500** (respectando o saldo do jogador). Os lances são números simples,
  não dicionário por uid.
- **Vencedor:** o maior lance vence **todo o produto** (todas as cartas do kit
  ou a única carta). Empate é sorteado aleatoriamente entre os empatados.
- **Pagamento:** o vencedor paga o único lance (uma única dedução de saldo).
- **Entrega:** o produto vai inteiro para a mão do vencedor (ou para a Área
  Segura se a mão estiver cheia, respeitando o teto total de 10).
- A IA define lances aleatórios com limite de saldo; o humano usa os botões
  `−100/+100` e confirma.
- Modo em rede: o host pula o meta-evento (`proximaFase` só abre meta quando
  `not redeModo`) para não travar a mesa.

### 8.3 Lojinha (V7)

- Abre **depois do leilão**, por **15 segundos** (`LOJINHA_SEGUNDOS`).
- **Oferta:** **até 3 cartas** (individualmente, 1 unidade de cada), escolhidas
  do catálogo. Podem incluir Super Cartas.
- **Preço:** **R$ 100 a R$ 400** por carta; Curingas custam **+R$ 100**.
- A IA pode comprar antes do humano; item vendido não pode ser comprado de novo.
- A carta comprada entra na mão (ou no descarte, se a mão estiver cheia,
  respeitando o teto total de 10).

## 9. Evento do Deus Mercado (4 passos, rodadas pares)

No fim de cada rodada par (2, 4, 6, 8), **até a rodada 10**, o mercado sorteia
um evento de 4 passos executados nesta ordem:

1. **Leilão** (ver §8.2) — produto único, 15s.
2. **Lojinha** (ver §8.3) — até 3 cartas, 15s.
3. **Fusão** (V7 5.5.3): 2 a 5 cartas da mão ou da Área Segura são escolhidas
   aleatoriamente. Se todos os UIDs forem válidos, as cartas vão para o
   `pilhaDescarte` e um **Super Carta** é concedido aleatoriamente ao jogador
   (fora do baralho infinito, usa ids 101–104). Se qualquer UID for inválido,
   a fusão inteira é anulada e nada é consumido.
4. **Fechar** — o meta-evento encerra, `eventoMeta` é limpo, o teto de 10
   cartas volta ao normal.

> **Nota:** O Evento do Deus Mercado **não ocorre após a rodada 10**. Após cada
  intervention, a rodada continua normal.

## 10. Fusão / Super Cartas (V7 5.5.3)

- O jogador pode fundir **2 a 5 cartas** (de sua mão ou da Área Segura).
- Todas as UIDs devem ser válidas; se qualquer UID for inválido, a fusão
  inteira é **anulada** e **nenhuma** carta é consumida.
- As cartas fundidas vão para o `pilhaDescarte`.
- Concede-se **1 Super Carta** aleatória entre as 4 possíveis (ids 101–104).
  **Não há escolha do jogador** — o tipo é sorteado ao acaso.
- Super Cartas ficam **fora do catálogo infinito** (ids 101–104, fora de
  `cartas.CARTAS`). Elas têm `classe = "Super"` e efeitos próprios.
- As Super Cartas são: 
  1. **101 Kaizen Supremo** — efeito de melhora contínua.
  2. **102 Jidoka Total** — automação total de processos.
  3. **103 Heijunka Total** — nivelamento de produção.
  4. **104 Andon Total** — sinal de alerta Andon.

## 10. Satisfação (V7 5.3)

- A barra de Satisfação vai de **0 a 200** (começa em 100).
- Em **0**, o jogador entra em **GREVE** e perde o próximo turno. A barra volta
  a 100 ao sair da Greve.
- Em **200**, as **próximas 2 cartas** jogadas pelo jogador têm os efeitos
  **dobrados** (multiplicador `mult=2` no delta de sucesso). O bonus é
  consumido 1 unidade por carta; quando o bonus termina, a barra de Satisfação
  **volta a 100**.
- O bonus de Satisfação MAX é consumido no **entrada de `executarCarta`**,
  independentemente de sucesso ou falha.
- **Falha nao é dobrada:** só a parte de sucesso do delta é dobrada; a penalidade
  de falha (`alteracaoSaldoFalha`) continua normal.
- A barra também sobe/baixa com `alterarSatisfacao` (0..200).
- Greve: satisfação 0 coloca em GREVE; sair da GREVE limpa a barra e redefine
  para 100.

## 11. Produtividade (V7 5.4)

- A produtividade é **acumulativa across rodadas** (cumulativa, sem teto superior).
- **Piso em -100%** (renda vira 0); não há teto superior.
- Aplicada na **aplicarRendaRodada** como `valor * (1 + prod)`, resultando em
  valor floored em 0.
- Cada jogador tem sua própria produtividade (individual, não compartilhada).
- Cartas podem aplicar produtividade declarada na própria carta (`produtividade =
  { valor = 0.20, alvo = "invocador" }`).

## 12. Vitoria e Derrota

A partida termina quando:

1. **Resta 1 (ou 0) jogador de pé** → vitória por **Eliminação**; se restar 0,
   **empate** (“ambos faliram”).
2. **Acabam os 10 turnos** → o vivo com **maior saldo** vence por **Tempo**.
   Saldos iguais no topo → **empate**.

O lucro do livro-caixa **não** define o vencedor.

## 13. Modos de jogo

- **Um jogador (campanha):** progresso salvo em disco; duelo clássico contra oponentes
  com ciclos e arenas próprios; o tempo do humano não corre.
- **Arena:** 2 a 8 jogadores (bots) numa mesa; mesmas regras do motor.
- **Multiplayer (rede):** um host roda o motor; os outros espelham snapshots.
  Quem desconecta sai da rotação. O tempo de turno expira de verdade.
  **Leilão/lojinha são locais telas de AI; o host pula o meta-evento** (`proximaFase`
  só abre meta quando `not redeModo`) para não travar a mesa.
- **Tutorial:** fluxo guiado das mecânicas básicas.

## 14. Camada de moedas (meta-jogo, fora da partida)

- **Moedas** são a moeda permanente do perfil (arquivo próprio, separado do
  saldo das partidas): **+10 moedas por vitória** do jogador 1; pagas uma vez
  por partida.
- **Loja:** avatares **Frederick Taylor**, **Karl Marx** e **Elton Mayo** por
  **100 moedas** cada; o botão **MOEDAS +100** repõe o saldo.
- **Perfil:** apelido (até 20 caracteres) + avatar entre os 8 básicos e os
  comprados.
- **Habilidades dos avatares comprados:**
  - **Frederick Taylor:** cartas de ACAO/EFEITO que você joga recebem +10% de chance.
  - **Karl Marx:** no início de cada seu turno, o jogador de maior saldo doa
    R$ 100 ao de menor saldo (somente vivos; não acontece se você for o mais
    rico). Em multiplayer, cada Marx dispara no próprio turno.
  - **Elton Mayo:** uma vez por rodada, quando um adversário joga uma carta
    negativa contra você, 30% de chance de neutralizar o efeito negativo. A
    tentativa consome a vez da rodada. Cartas de alvo `todos`/`oponentes` não
    disparam.
- Em modo de teste, moedas e inventário valem só em memória.

## 15. Constantes principais (jogo.lua)

| Constante | Valor | Onde |
|---|---|---|
| `TURNO_BASE_SEGUNDOS` | 25 | `jogo.lua` |
| `RENDA_BASE` | 1000 | `jogo.lua` |
| `RENDA_INCREMENTO` | 100 | `jogo.lua` |
| `BONUS_COPIA` | 0.3 (×1.3) | `jogo.lua` |
| `CARTAS_MAX_TOTAL` | 10 | `jogo.lua` |
| `CARTAS_POR_MAO` | 7 | `jogo.lua` |
| `CARTAS_POR_TURNO` | 2 | `jogo.lua` |
| `SATISFACAO_INICIAL` | 100 | `jogo.lua` |
| `SATISFACAO_MIN` | 0 | `jogo.lua` |
| `SATISFACAO_MAX` | 200 | `jogo.lua` |
| `SATISFACAO_BONUS_CARTAS` | 2 | `jogo.lua` |
| `PRODUTIVIDADE_MIN` | -1 | `jogo.lua` |
| `FUSAO_MIN` | 2 | `jogo.lua` |
| `FUSAO_MAX` | 5 | `jogo.lua` |
| `LEILAO_INTERVALO` | 2 rodadas | `jogo.lua` |
| `LEILAO_SEGUNDOS` | 15 | `jogo.lua` |
| `LOJINHA_SEGUNDOS` | 15 | `jogo.lua` |
| `AREA_SEGURA_MAX` | 1 carta | `jogo.lua` |
| `MAX_TURNOS` | 10 | `jogo.lua` |

## 15. Regras explicitamente fora do protótipo atual ou alteradas de V2 para V7

- **Baralho infinito de 49 cartas:** mantido como decidiu o usuário; não há
  deck building de 60 cartas por jogador.
- **Renda base R$ 1.000** (não R$ 500) + R$ 100 por rodada (não somatória
  simples). A renda usa multiplicador produtividade: `valor * (1 + prod)`.
- **Turno de 25 segundos** (não 15s).
- **Carta Dobrada +30%** (não +50%): `BONUS_COPIA = 0.3`.
- **Teto total de 10 cartas** (7 na mão + 3 no banco), excedível apenas durante
  o evento do Deus Mercado (`eventoMeta` ativo). Fora do evento, a mão limita
  em 7 no end-of-turn draw.
- **Defense Slot:** `J.ehDefesa(c)` = `classe == "Defesa" OR tipo == "PROTECAO"`
  (união). **ids 8 (Tempos e Movimentos) e 13 (Seiketsu)** foram relabelados
  de `classe = "Defesa"` para `"Acao"` (atacam o oponente, então não são
  proteções).
- **Satisfação 0–200** (não 0–100). Greve em 0; MAX dobra próximas 2 cartas.
- **Satisfação MAX:** consome `bonusSatisfacao` em `executarCarta` entrada (`mult=2`);
  dobra o delta de sucesso **apenas na parte de sucesso**; `dobrarEfeito` swap;
  aplica `carta.satisfacao`/`carta.produtividade`; barra volta a 100 quando o
  bonus acaba.
- **Produtividade acumula across rodadas** (piso −100%, sem teto), aplicada em
  `aplicarRendaRodada` como `valor * (1 + prod)` floored em 0.
- **Leilão V7 5.7:** produto **único** (1 carta ou kit 2–3, 35% Super Carta),
  **um lance por jogador**, maior lance vence **todo o produto**, pagamento único.
- **Super Cartas:** ids 101–104, `classe = "Super"`, fora do baralho infinito,
  concedidas aleatoriamente ao final da Fusão (nenhuma escolha do jogador).
- **Fusão 2–5 cartas:** UIDs inválidos anulam a fusão inteira; cartas vão para
  `pilhaDescarte`; Super Carta aleatória concedida.
- **Visor de Curingas:** global + até 2 últimas substituições anteriores.
- **§5.6 "Escolha do Curinga Global":** vazio no documento manual; a seleção
  segue o sorteio aleatório entre os curingas suportados pelo motor (Monstro
  Inflação, Seletividade de Taylor, Flutuação do Mercado), flagando a ausência
  de definição no manual.
- **Balance hiding:** saldos ocultos na UI no turno imediatamente anterior ao
  evento do Deus Mercado (`ocultarSaldos` true no último assento, rodada par,
  `turno < MAX_TURNOS`, não estando em evento).
- **Fusão consome Área Segura:** cartas da Área Segura podem ser usadas na
  fusão (se uid for válido).
- **Ruin a zero:** saldo zero = falência imediata.
- **Vitoria por maior saldo aos 10 turnos** (não por lucro acumulado).
- **Leilão/lojinha são telas locais/AI:** modo rede pula o meta-evento.
- **Sem reembaralhamento** do descarte (já estava em V2, mantido).
- **Sem vitória por lucro** do livro-caixa (já estava em V2, mantido).