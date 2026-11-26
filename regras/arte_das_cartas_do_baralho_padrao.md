# Arte das cartas do baralho padrão

**Data:** 23/11/2026

Este documento levanta, para o **baralho padrão atual**, quais cartas têm arte
própria e quais ainda usam o placeholder.

## Critério usado

- **Baralho atual:** a lista de `regras/baralho atual.txt`, com os pesos de
  `pesos.lua`.
- **Carta com arte:** carta cujo `id` possui entrada `carta_<id>` em `arte.lua`
  apontando para um arquivo existente em `arte/cards/`.
- **Carta sem arte:** qualquer outra. O jogo cai na face textual (o
  `arte/cards/arte_faltando.png` também não existe mais no projeto).

## Resumo

| Situação | Quantidade |
|---|---:|
| Cartas no baralho padrão | 32 |
| Com arte própria | 32 |
| Sem arte (placeholder textual) | 0 |

Não incluídas: cartas com peso 0 (fora do baralho padrão) e as 4 Super cartas.

## Cartas com arte

| ID | Carta | Classe (`cartas.lua`) | Peso | Arquivo |
|---:|---|---|---:|---|
| 2 | Toyotinho | Efeito | 3 | `arte/cards/cartas de efeito/2-removebg-preview.png` |
| 4 | Roubo de Ideias | Efeito | 1 | `arte/cards/cartas de efeito/11-removebg-preview.png` |
| 5 | Presente do Noel | Acao | 3 | `arte/cards/cartas de acao/presente_noel.png` |
| 6 | O Monstro Inflacao | Curinga | 2 | `arte/cards/curinga/3-removebg-preview.png` |
| 8 | Tempos e Movimentos | Defesa | 3 | `arte/cards/cartas de defesa/1-removebg-preview.png` |
| 9 | Queima de Estoque | Efeito | 3 | `arte/cards/cartas de efeito/1-removebg-preview.png` |
| 10 | Psicologia Industrial | Defesa | 3 | `arte/cards/cartas de defesa/2-removebg-preview.png` |
| 11 | Emprestimo | Acao | 3 | `arte/cards/cartas de acao/emprestimo.png` |
| 12 | Mao Visivel | Defesa | 3 | `arte/cards/cartas de defesa/3-removebg-preview.png` |
| 13 | Seiketsu | Defesa | 3 | `arte/cards/cartas de defesa/4-removebg-preview.png` |
| 18 | Seletividade de Taylor | Curinga | 2 | `arte/cards/curinga/1-removebg-preview.png` |
| 19 | Flutuacao do Mercado | Curinga | 2 | `arte/cards/curinga/2-removebg-preview.png` |
| 20 | Cada Um No Seu Quadrado | Acao | 3 | `arte/cards/cartas de acao/cada_um_no_seu_quadrado.png` |
| 22 | Previsao | Defesa | 3 | `arte/cards/cartas de defesa/5.png` |
| 23 | Overclock Produtivo | Acao | 3 | `arte/cards/cartas de acao/overclock_produtivo.png` |
| 24 | Concepcao de Dewey | Efeito | 3 | `arte/cards/cartas de efeito/4-removebg-preview.png` |
| 25 | Atestado Medico | Efeito | 3 | `arte/cards/cartas de efeito/9-removebg-preview.png` |
| 26 | Efeito Hawthorne | Curinga | 2 | `arte/cards/curinga/4-removebg-preview.png` |
| 27 | Inercia Psicologica | Efeito | 3 | `arte/cards/cartas de efeito/10-removebg-preview.png` |
| 29 | Reset Reconciliatorio | Efeito | 1 | `arte/cards/cartas de efeito/5-removebg-preview.png` |
| 31 | Hora Extra | Efeito | 1 | `arte/cards/cartas de efeito/6-removebg-preview.png` |
| 32 | Sabotagem empresarial | Efeito | 1 | `arte/cards/cartas de efeito/7-removebg-preview.png` |
| 35 | Climatizacao Premium | Efeito | 1 | `arte/cards/cartas de efeito/18-removebg-preview.png` |
| 39 | Mesas Rebaixadas | Efeito | 1 | `arte/cards/cartas de efeito/13-removebg-preview.png` |
| 40 | Ajuste Mobiliario | Efeito | 1 | `arte/cards/cartas de efeito/14-removebg-preview.png` |
| 41 | Poltrona dos Sonhos | Efeito | 1 | `arte/cards/cartas de efeito/12-removebg-preview.png` |
| 42 | Supremacia Ergonomica | Efeito | 1 | `arte/cards/cartas de efeito/15-removebg-preview.png` |
| 44 | Esforco Zero | Efeito | 1 | `arte/cards/cartas de efeito/17-removebg-preview.png` |
| 45 | Reducao da Carga Horaria | Efeito | 1 | `arte/cards/cartas de efeito/16-removebg-preview.png` |
| 49 | Rock Misterioso | Efeito | 1 | `arte/cards/cartas de efeito/8-removebg-preview.png` |
| 50 | Rotatividade de Mercado | Curinga | 2 | `arte/cards/curinga/6-removebg-preview.png` |
| 51 | Probabilidade Mortal | Curinga | 2 | `arte/cards/curinga/5-removebg-preview.png` |

Todos os arquivos acima existem em disco e são carregados pelo LOVE.

## Defesas (5)

As 5 cartas da classe Defesa ocupam o Slot de Defesa. Três são de **bloqueio**
(cancelam a próxima carta do tipo indicado) e duas são de **mitigação** (não
cancelam: baixam a chance):

| Carta | Tipo | Efeito |
|---|---|---|
| Tempos e Movimentos | mitigação | Fixa a chance da próxima ação em 50% |
| Psicologia Industrial | bloqueio | Anula a próxima carta de efeito |
| Mão Visível | bloqueio | Anula a próxima carta de ação |
| Seiketsu | mitigação | Fixa em 50% a chance da próxima carta negativa |
| Previsão | mitigação | Corta pela metade (×0,5) a chance da próxima carta |

## Fora do baralho

As cartas com peso 0 (por exemplo, Seiri, Seiso, Pego no Flagra, Sorte
Merecida, Sem tempo, Nosso, as cartas fora da lista do baralho e as 4 Super
cartas) não têm arte própria e aparecem na face textual quando surgem em
leilão/lojinha/fusão.

Para ativar uma arte nova:

1. salvar o PNG dentro de `arte/cards/` (de preferência na subpasta da classe);
2. adicionar a entrada `carta_<id> = "<caminho>"` em `arte.lua`;
3. nenhuma mudança é necessária em `cartas.lua` ou no motor — a associação é
   feita pelo `id`.

## Observações

- A classe exibida nas tabelas é a de `cartas.lua`. Algumas cartas têm
  `classe = "Efeito"` mas `tipo = "ACAO"` (ataque com alvo), como Roubo de
  Ideias e Queima de Estoque: o `tipo` é o que o motor usa para regras e para
  o selo colorido do zoom; a `classe` é a da planilha.
- `Previsao` (id 22) foi renomeada de "Que Atrevido" e virou Defesa de
  mitigação multiplicativa (×0,5), conforme a arte de `cartas de defesa/5.png`.
- Os testes verificam que **toda carta com peso > 0 tem arte carregada**.
