local C = {}

-- Pesos do sorteio ponderado: tabela unica, separada do motor (pesos.lua).
local PESOS = require "pesos"

C.TIPO = {
  ACAO = "ACAO",
  EFEITO = "EFEITO",
  PROTECAO = "PROTECAO",
  CORINGA = "CORINGA",
}

-- Cartas oficiais: planilha "JOGO_TGA - 03-10-2026.xlsx" (23 cartas).
-- Textos em ASCII (a fonte VCR nao renderiza acento).
-- Espelhado de src/cards/cartasTGA.js:
--  - classe: classe da planilha (Efeito/Acao/Defesa/Curinga)
--  - tipo: tipo logico do motor (ACAO/EFEITO/PROTECAO/CORINGA)
--  - dinheiroEm: 'invocador' | 'alvo' | 'nenhum'
--  - efeito: efeito especial do motor (ou nil)
C.CARTAS = {
  {
    id = 1, nome = "Nosso",
    subtitulo = "E tudo nosso agora",
    descricao = "O jogador alvo tera que doar uma porcentagem de 0 a 100% do seu saldo para o jogador que invocou essa carta",
    efeitoTexto = "Doe uma porcentagem aleatoria da sua receita ao invocador",
    duracaoTexto = "Instantanea", alvoTexto = "Oponente",
    classe = "Efeito", tipo = "ACAO",
    chanceSucesso = 1, precisaAlvo = true,
    alteracaoSaldoBase = 0, alteracaoSaldoFalha = 0, dinheiroEm = "nenhum",
    efeito = { tipo = "DOACAO_PERCENTUAL", alvo = "alvo" },
  },
  {
    id = 2, nome = "Toyotinho",
    subtitulo = "Menos estoque, mais lucro, bebe!",
    descricao = "O mestre da eficiencia te inspira! Sua producao dispara... ou despenca! O importante e nunca ter estoque parado.",
    efeitoTexto = "Ganhe ou perca 400 reais",
    duracaoTexto = "Instantanea", alvoTexto = "Voce",
    classe = "Efeito", tipo = "ACAO",
    chanceSucesso = 0.7, precisaAlvo = false,
    alteracaoSaldoBase = 400, alteracaoSaldoFalha = -400, dinheiroEm = "invocador",
    efeito = nil,
  },
  {
    id = 3, nome = "Sem tempo",
    subtitulo = "Que a producao resete.",
    descricao = "Quando o jogador invoca essa carta o tempo do turno de cada jogador reduz para 2 segundos, exceto o invocador.",
    efeitoTexto = "Ganhe 50 reais",
    duracaoTexto = "3 turnos", alvoTexto = "Todos oponentes",
    classe = "Acao", tipo = "ACAO",
    chanceSucesso = 0.8, precisaAlvo = true,
    alteracaoSaldoBase = 50, alteracaoSaldoFalha = 0, dinheiroEm = "invocador",
    efeito = { tipo = "TEMPO_TURNO", modo = "definir", segundos = 2, turnos = 3, alvo = "oponentes" },
  },
  {
    id = 4, nome = "Roubo de Ideias",
    subtitulo = "Perdeu, playboy!",
    descricao = "Permite o invocador roubar cartas do jogador de sua escolha",
    efeitoTexto = "Pegue 2 cartas do jogador alvo",
    duracaoTexto = "Instantanea", alvoTexto = "Oponente",
    classe = "Efeito", tipo = "ACAO",
    chanceSucesso = 1, precisaAlvo = true,
    alteracaoSaldoBase = 0, alteracaoSaldoFalha = 0, dinheiroEm = "nenhum",
    efeito = { tipo = "ROUBA_CARTAS", quantidade = 2, alvo = "alvo" },
  },
  {
    id = 5, nome = "Presente do Noel",
    subtitulo = "Ho Ho Ho!",
    descricao = "Um sociologo Socialista foi enviado para a empresa alvo e convenceu todos a fazer uma revolta por direitos.",
    efeitoTexto = "Ganhe 200 reais. O alvo perdera 100 reais e tera 10% da chance de sucesso reduzida por 2 turnos",
    duracaoTexto = "Instantanea/2 turnos", alvoTexto = "Oponente",
    classe = "Acao", tipo = "ACAO",
    chanceSucesso = 0.55, precisaAlvo = true,
    alteracaoSaldoBase = 0, alteracaoSaldoFalha = 0, dinheiroEm = "nenhum",
    efeito = {
      tipo = "DINHEIRO_ALVO",
      alvo = "alvo",
      ganhoInvocador = 200,
      perdaAlvo = 100,
      debuff = { tipo = "MOD_CHANCE", valor = -0.1, turnos = 2 },
    },
  },
  {
    id = 6, nome = "O Monstro Inflacao",
    subtitulo = "",
    descricao = "Ele nao so devora o seu dinheiro, mas tambem as suas chances...",
    efeitoTexto = "Reduz em 40% a chance de as cartas jogadas falharem",
    duracaoTexto = "2 turnos", alvoTexto = "Todos",
    classe = "Curinga", tipo = "CORINGA",
    chanceSucesso = 1, precisaAlvo = true,
    alteracaoSaldoBase = 0, alteracaoSaldoFalha = 0, dinheiroEm = "nenhum",
    efeito = { tipo = "MOD_FALHA", fator = 0.6, turnos = 2, alvo = "todos" },
  },
  {
    id = 7, nome = "Cris e Greg Agiotas",
    subtitulo = "",
    descricao = "O jogador alvo tera que pagar uma divida de valor aleatorio de 150-300 reais",
    efeitoTexto = "Perde de 150-300 reais.",
    duracaoTexto = "Instantanea", alvoTexto = "Oponente",
    classe = "Efeito", tipo = "ACAO",
    chanceSucesso = 0.9, precisaAlvo = true,
    alteracaoSaldoBase = 0, alteracaoSaldoFalha = 0, dinheiroEm = "alvo",
    efeito = { tipo = "DIVIDA", min = 150, max = 300, alvo = "alvo" },
  },
  {
    id = 8, nome = "Tempos e Movimentos",
    subtitulo = "O tempo e a sombra do movimento",
    descricao = "Reajuste total para otimizar o tempo, pode funcionar, ou nao.",
    efeitoTexto = "Estabelece que a proxima acao tem chance exata de 50%",
    duracaoTexto = "Instantanea", alvoTexto = "Voce ou Oponente",
    -- Defesa de MITIGACAO: fica no Slot de Defesa e, quando um ataque
    -- chega ao dono, forca a chance da carta atacante a 50%. Nao cancela
    -- o ataque (isso e so das defesas de bloqueio). O CHANCE_FIXA abaixo
    -- e lido pelo jogo como a condicao/efeito da mitigacao.
    classe = "Defesa", tipo = "PROTECAO",
    chanceSucesso = 1, precisaAlvo = true,
    alteracaoSaldoBase = 0, alteracaoSaldoFalha = 0, dinheiroEm = "nenhum",
    efeito = { tipo = "CHANCE_FIXA", valor = 0.5, usos = 1, alvo = "alvo" },
    satisfacao = { valor = -15, alvo = "alvo" },
  },
  {
    id = 9, nome = "Queima de Estoque",
    subtitulo = "Toyota mandou vender tudo... tudo!",
    descricao = "Estoque parado nao esta no dicionario da toyota (Isso inclui cartas).",
    efeitoTexto = "Descarte 1 carta e puxe 1 nova",
    duracaoTexto = "Instantanea", alvoTexto = "Oponente",
    classe = "Efeito", tipo = "ACAO",
    chanceSucesso = 0.9, precisaAlvo = true,
    alteracaoSaldoBase = 0, alteracaoSaldoFalha = 0, dinheiroEm = "nenhum",
    efeito = { tipo = "DESCARTA_E_PUXA", quantidade = 1, alvo = "alvo" },
  },
  {
    id = 10, nome = "Psicologia Industrial",
    subtitulo = "O homem e o ambiente devem adequar-se um ao outro",
    descricao = "Os melhores funcionarios para as suas melhores posicoes, com os melhores resultados",
    efeitoTexto = "Anula a proxima carta de efeito do oponente sobre voce",
    duracaoTexto = "Instantanea", alvoTexto = "Voce ou Oponente",
    classe = "Defesa", tipo = "PROTECAO",
    chanceSucesso = 1, precisaAlvo = true,
    alteracaoSaldoBase = 0, alteracaoSaldoFalha = 0, dinheiroEm = "nenhum",
    protegeContra = "EFEITO",
    efeito = nil,
  },
  {
    id = 11, nome = "Emprestimo",
    subtitulo = "Com grandes emprestimos, vem grandes responsabilidades",
    descricao = "Voce faz um emprestimo do banco, mas deve pagar o valor dividido em 5 turnos",
    efeitoTexto = "Ganhe 500 reais",
    duracaoTexto = "5 turnos", alvoTexto = "Voce ou Oponente",
    classe = "Acao", tipo = "ACAO",
    chanceSucesso = 0.9, precisaAlvo = true,
    alteracaoSaldoBase = 500, alteracaoSaldoFalha = 0, dinheiroEm = "invocador",
    efeito = { tipo = "DIVIDA_PARCELADA", valor = 100, turnos = 5, alvo = "invocador" },
  },
  {
    id = 12, nome = "Mao Visivel",
    subtitulo = "Uma mao completamente visivel se estende a voce...",
    descricao = "A mao visivel defende voce contra cartas de acao",
    efeitoTexto = "Anula a proxima carta de acao do oponente sobre voce",
    duracaoTexto = "Instantanea", alvoTexto = "Voce ou Oponente",
    classe = "Defesa", tipo = "PROTECAO",
    chanceSucesso = 1, precisaAlvo = true,
    alteracaoSaldoBase = 0, alteracaoSaldoFalha = 0, dinheiroEm = "nenhum",
    protegeContra = "ACAO",
    efeito = nil,
  },
  {
    id = 13, nome = "Seiketsu",
    subtitulo = "Manter as condicoes de saude, higiene e padronizacao do ambiente",
    descricao = "Diminui o efeito da proxima carta que diminua chances ou dinheiro em 50%",
    efeitoTexto = "Abaixa para 50% as chances da proxima carta de efeito negativo do oponente funcionar",
    duracaoTexto = "Instantanea", alvoTexto = "Oponente",
    -- Defesa de MITIGACAO: so reage a cartas negativas (soNegativa) e
    -- derruba a chance delas para 50% antes do dado. Vai ao descarte ao
    -- ativar, como as outras defesas.
    classe = "Defesa", tipo = "PROTECAO",
    chanceSucesso = 1, precisaAlvo = true,
    alteracaoSaldoBase = 0, alteracaoSaldoFalha = 0, dinheiroEm = "nenhum",
    efeito = { tipo = "CHANCE_FIXA", valor = 0.5, usos = 1, soNegativa = true, alvo = "alvo" },
    satisfacao = { valor = 25, alvo = "invocador" },
  },
  {
    id = 14, nome = "Shitsuke",
    subtitulo = "Com disciplina, um ato mundano vira rotina",
    descricao = "A proxima carta de acao ira durar um turno a mais",
    efeitoTexto = "Faz a sua proxima carta de acao perdurar por 1 turno a mais",
    duracaoTexto = "Instantanea", alvoTexto = "Voce ou Oponente",
    classe = "Efeito", tipo = "ACAO",
    chanceSucesso = 0.9, precisaAlvo = true,
    alteracaoSaldoBase = 0, alteracaoSaldoFalha = 0, dinheiroEm = "nenhum",
    efeito = { tipo = "PROLONGA", turnosAdicionais = 1, usos = 1, alvo = "alvo" },
  },
  {
    id = 15, nome = "Seiton",
    subtitulo = "Eu ate ia enrolar pra pegar a ferramenta, mas tava logo ali",
    descricao = "Sua produtividade aumenta porque tudo estava ordenado, ganhe +500 reais no proximo turno",
    efeitoTexto = "Adiciona 500 ao seu saldo no proximo turno; +10% produtividade e +15 satisfacao",
    duracaoTexto = "Instantanea", alvoTexto = "Voce",
    classe = "Efeito", tipo = "ACAO",
    chanceSucesso = 0.95, precisaAlvo = false,
    alteracaoSaldoBase = 0, alteracaoSaldoFalha = 0, dinheiroEm = "nenhum",
    efeito = { tipo = "DINHEIRO_ADIADO", valor = 500, turnos = 1, alvo = "invocador" },
    satisfacao = { valor = 15, alvo = "invocador" },
    produtividade = { valor = 0.10, alvo = "invocador" },
  },
  {
    id = 16, nome = "Seiri",
    subtitulo = "Inutil, Inutil, Inutil!",
    descricao = "Restam somente aquilo que e util em sua empresa, suas ferramentas se renovam",
    efeitoTexto = "Devolva 3 cartas da sua mao; por 3 turnos voce puxa 3 e fica com 1; +15 satisfacao",
    duracaoTexto = "3 turnos", alvoTexto = "Voce",
    classe = "Acao", tipo = "ACAO",
    chanceSucesso = 0.9, precisaAlvo = false,
    alteracaoSaldoBase = 0, alteracaoSaldoFalha = 0, dinheiroEm = "nenhum",
    efeito = { tipo = "TROCA_MAO", quantidade = 3, turnos = 3, alvo = "invocador" },
    satisfacao = { valor = 15, alvo = "invocador" },
  },
  {
    id = 17, nome = "Seiso",
    subtitulo = "Tchau, preguica / Tchau, sujeira / Adeus, cheirinho de suor",
    descricao = "Seu ambiente de trabalho esta limpo e higienizado, seus trabalhadores gostam de ficar aqui, +2 segundos para o tempo dos seus 2 proximos turno",
    efeitoTexto = "Seus 2 proximos turnos +2 segundos; +20 satisfacao",
    duracaoTexto = "2 turnos", alvoTexto = "Voce",
    classe = "Acao", tipo = "ACAO",
    chanceSucesso = 0.9, precisaAlvo = false,
    alteracaoSaldoBase = 0, alteracaoSaldoFalha = 0, dinheiroEm = "nenhum",
    efeito = { tipo = "TEMPO_TURNO", modo = "bonus", segundos = 2, turnos = 2, alvo = "invocador" },
    satisfacao = { valor = 20, alvo = "invocador" },
  },
  {
    id = 18, nome = "Seletividade de Taylor",
    subtitulo = "Querem essa vaga? Me provem que sao aptos!",
    descricao = "O Taylor aplica sua seletividade nao so em funcionarios, mas em cartas!",
    efeitoTexto = "3 cartas aleatorias suas sao trocadas por turno",
    duracaoTexto = "2 turnos", alvoTexto = "Todos",
    classe = "Curinga", tipo = "CORINGA",
    chanceSucesso = 1, precisaAlvo = true,
    alteracaoSaldoBase = 0, alteracaoSaldoFalha = 0, dinheiroEm = "nenhum",
    efeito = { tipo = "MAO_ALEATORIA", quantidade = 3, turnos = 2, alvo = "todos" },
  },
  {
    id = 19, nome = "Flutuacao do Mercado",
    subtitulo = "Olhem esses graficos subindo e descendo, chega a ser lindo!",
    descricao = "Durante os proximos 2 turnos qualquer maneira de receber dinheiro tera um valor aleatorio",
    efeitoTexto = "Qualquer acao ou efeito que der dinheiro tera o valor substituido por um valor aleatorio",
    duracaoTexto = "2 turnos", alvoTexto = "Todos",
    classe = "Curinga", tipo = "CORINGA",
    chanceSucesso = 1, precisaAlvo = true,
    alteracaoSaldoBase = 0, alteracaoSaldoFalha = 0, dinheiroEm = "nenhum",
    efeito = { tipo = "RENDA_ALEATORIA", turnos = 2, alvo = "todos" },
  },
  {
    id = 20, nome = "Cada Um No Seu Quadrado",
    subtitulo = "A divisao do trabalho e a chave para a prosperidade economica",
    descricao = "Voce implanta a divisao de trabalho, elevando a producao dos seus trabalhadores.",
    efeitoTexto = "Ganhe 500 reais ou perca 100 reais",
    duracaoTexto = "Instantanea", alvoTexto = "Voce",
    classe = "Acao", tipo = "ACAO",
    chanceSucesso = 0.7, precisaAlvo = false,
    alteracaoSaldoBase = 500, alteracaoSaldoFalha = -100, dinheiroEm = "invocador",
    efeito = nil,
  },
  {
    id = 21, nome = "Pego no Flagra",
    subtitulo = "",
    descricao = "A Receita Federal descobriu uma fraude fiscal na empresa oponente",
    efeitoTexto = "Menos 20% de chance de sucesso",
    duracaoTexto = "2 turnos", alvoTexto = "Oponente",
    classe = "Acao", tipo = "ACAO",
    chanceSucesso = 0.6, precisaAlvo = true,
    alteracaoSaldoBase = 0, alteracaoSaldoFalha = 0, dinheiroEm = "nenhum",
    efeito = { tipo = "MOD_CHANCE", valor = -0.2, turnos = 2, alvo = "alvo" },
  },
  {
    id = 22, nome = "Previsao",
    subtitulo = "Nao contavam com minha astucia!",
    descricao = "Voce preve a jogada do oponente, elaborando uma contra medida e protegendo seus lucros.",
    efeitoTexto = "Reduz 50% a chance da carta do oponente acertar voce",
    duracaoTexto = "Instantanea", alvoTexto = "Oponente",
    -- Defesa de MITIGACAO multiplicativa: diferente das defesas que fixam a
    -- chance em 50% (Tempos/Seiketsu), a Previsao apenas corta pela metade a
    -- chance da proxima carta que chegar ao dono. O MULT_CHANCE abaixo e lido
    -- pelo jogo como a condicao/efeito da mitigacao.
    classe = "Defesa", tipo = "PROTECAO",
    chanceSucesso = 0.7, precisaAlvo = true,
    alteracaoSaldoBase = 0, alteracaoSaldoFalha = 0, dinheiroEm = "nenhum",
    efeito = { tipo = "MULT_CHANCE", fator = 0.5, usos = 1, alvo = "alvo" },
  },
  {
    id = 23, nome = "Overclock Produtivo",
    subtitulo = "MegaBrain, forca total!",
    descricao = "Sua producao dispara.",
    efeitoTexto = "Seu bonus no fim de turno aumenta em 10%, mas voce perde o ultimo bonus.",
    duracaoTexto = "5 turnos", alvoTexto = "Voce ou Oponente",
    classe = "Acao", tipo = "ACAO",
    chanceSucesso = 0.9, precisaAlvo = true,
    alteracaoSaldoBase = 0, alteracaoSaldoFalha = 0, dinheiroEm = "nenhum",
    efeito = { tipo = "MOD_BONUS_TURNO", fator = 1.1, turnos = 5, alvo = "alvo" },
  },

  -- ============================================================
  -- NOVAS CARTAS (IDs 24-50) - JOGO_TGA - 02-11-2026.xlsx
  -- ============================================================

  -- 24. Concepcao de Dewey (Efeito, peso 3)
  {
    id = 24, nome = "Concepcao de Dewey",
    subtitulo = "Aprender fazendo, errando e corrigindo",
    descricao = "A filosofia pratica ensina que a experiencia e o melhor mestre. Aprendizado melhora satisfacao e produtividade.",
    efeitoTexto = "Satisfacao +25 e produtividade +10% (voce)",
    duracaoTexto = "Instantanea", alvoTexto = "Voce",
    classe = "Efeito", tipo = "ACAO",
    chanceSucesso = 0.75, precisaAlvo = false,
    alteracaoSaldoBase = 0, alteracaoSaldoFalha = 0, dinheiroEm = "nenhum",
    efeito = nil,
    satisfacao = { valor = 25, alvo = "invocador" },
    produtividade = { valor = 0.10, alvo = "invocador" },
  },

  -- 25. Atestado Medico (Efeito, peso 3)
  {
    id = 25, nome = "Atestado Medico",
    subtitulo = "O medico recomendou descanso absoluto",
    descricao = "Voce se afasta do trabalho por questao de saude. Ninguem pode mexer com voce enquanto descansa.",
    efeitoTexto = "Produtividade -20% (voce)",
    duracaoTexto = "Instantanea", alvoTexto = "Voce",
    classe = "Efeito", tipo = "EFEITO",
    chanceSucesso = 1, precisaAlvo = false,
    alteracaoSaldoBase = 0, alteracaoSaldoFalha = 0, dinheiroEm = "nenhum",
    efeito = nil,
    produtividade = { valor = -0.20, alvo = "invocador" },
  },

  -- 26. Efeito Hawthorne (Curinga, peso 1)
  {
    id = 26, nome = "Efeito Hawthorne",
    subtitulo = "Sober observado ja muda o comportamento",
    descricao = "Quando todos estao sendo observados, a produtividade muda. Para melhor ou pior?",
    efeitoTexto = "Satisfacao -20 e produtividade +30% em todos por 4 turnos",
    duracaoTexto = "4 turnos", alvoTexto = "Todos",
    classe = "Curinga", tipo = "CORINGA",
    chanceSucesso = 0.8, precisaAlvo = false,
    alteracaoSaldoBase = 0, alteracaoSaldoFalha = 0, dinheiroEm = "nenhum",
    efeito = nil,
    satisfacao = { valor = -20, alvo = "todos" },
    produtividade = { valor = 0.30, alvo = "todos" },
  },

  -- 27. Inercia Psicologica (Efeito, peso 3)
  {
    id = 27, nome = "Inercia Psicologica",
    subtitulo = "O corpo quer ficar parado... a mente tambem",
    descricao = "A zona de conforto apesar de satisfatoria, nao e produtiva.",
    efeitoTexto = "Satisfacao +25 e produtividade -20% (voce ou alvo)",
    duracaoTexto = "Instantanea", alvoTexto = "Voce ou Oponente",
    classe = "Efeito", tipo = "ACAO",
    chanceSucesso = 0.85, precisaAlvo = false,
    alteracaoSaldoBase = 0, alteracaoSaldoFalha = 0, dinheiroEm = "nenhum",
    efeito = nil,
    satisfacao = { valor = 25, alvo = "invocador" },
    produtividade = { valor = -0.20, alvo = "invocador" },
  },

  -- 28. Sorte Merecida (Acao, peso 3)
  {
    id = 28, nome = "Sorte Merecida",
    subtitulo = "Quem trabalha duro tem a sorte ao seu lado",
    descricao = "Seu esforco e recompensado com um bonus substancial no proximo turno.",
    efeitoTexto = "Proximo bonus de turno dobrado",
    duracaoTexto = "1 turno", alvoTexto = "Voce",
    classe = "Acao", tipo = "EFEITO",
    chanceSucesso = 0.9, precisaAlvo = false,
    alteracaoSaldoBase = 0, alteracaoSaldoFalha = 0, dinheiroEm = "nenhum",
    efeito = { tipo = "MOD_BONUS_TURNO", fator = 2.0, turnos = 1, alvo = "invocador" },
  },

  -- 29. Reset Reconciliatorio (Efeito, peso 1)
  {
    id = 29, nome = "Reset Reconciliatorio",
    subtitulo = "Perdao dividas, recomece do zero",
    descricao = "Reseta o relacionamento entre a empresa e os funcionarios: satisfacao vira 50 e produtividade deixa de ser negativa.",
    efeitoTexto = "Satisfacao = 50; produtividade >= 0 (voce ou alvo)",
    duracaoTexto = "Instantanea", alvoTexto = "Voce ou Oponente",
    classe = "Efeito", tipo = "EFEITO",
    chanceSucesso = 0.8, precisaAlvo = false,
    alteracaoSaldoBase = 0, alteracaoSaldoFalha = 0, dinheiroEm = "nenhum",
    efeito = nil,
    satisfacao = { valor = 50, alvo = "invocador", setar = true },
    produtividade = { valor = 0.10, alvo = "invocador", setarPositivo = true },
  },

  -- 31. Hora Extra (Efeito, peso 1)
  {
    id = 31, nome = "Hora Extra",
    subtitulo = "Acaba pelo amor de Deus!",
    descricao = "Se tempo e dinheiro, trabalhe mais que ganharei mais",
    efeitoTexto = "Satisfacao -10 no alvo; voce ganha 500 reais",
    duracaoTexto = "Instantanea", alvoTexto = "Oponente",
    classe = "Efeito", tipo = "EFEITO",
    chanceSucesso = 0.85, precisaAlvo = true,
    alteracaoSaldoBase = 500, alteracaoSaldoFalha = 0, dinheiroEm = "invocador",
    efeito = nil,
    satisfacao = { valor = -10, alvo = "alvo" },
  },

  -- 32. Sabotagem empresarial (Efeito, peso 1)
  {
    id = 32, nome = "Sabotagem empresarial",
    subtitulo = "Um parafuso solto aqui, um fio cortado la...",
    descricao = "Sabotagem silenciosa na operacao do oponente. Ele perde dinheiro e eficiencia.",
    efeitoTexto = "Satisfacao -30 e produtividade -30% no alvo; rouba 500 reais",
    duracaoTexto = "Instantanea", alvoTexto = "Oponente",
    classe = "Efeito", tipo = "ACAO",
    chanceSucesso = 0.65, precisaAlvo = true,
    alteracaoSaldoBase = 0, alteracaoSaldoFalha = 0, dinheiroEm = "alvo",
    efeito = {
      tipo = "DINHEIRO_ALVO",
      alvo = "alvo",
      ganhoInvocador = 0,
      perdaAlvo = 500,
    },
    satisfacao = { valor = -30, alvo = "alvo" },
    produtividade = { valor = -0.30, alvo = "alvo" },
  },

  -- 33. Congelamento Empresarial (Efeito, peso 1)
  {
    id = 33, nome = "Congelamento Empresarial",
    subtitulo = "Tudo paralisado. Ninguem entra, ninguem sai.",
    descricao = "O negocio do alvo e congelado. Ele nao pode jogar cartas de acao por 2 turnos.",
    efeitoTexto = "Alvo nao pode usar cartas de acao por 2 turnos",
    duracaoTexto = "2 turnos", alvoTexto = "Oponente",
    classe = "Efeito", tipo = "EFEITO",
    chanceSucesso = 0.75, precisaAlvo = true,
    alteracaoSaldoBase = 0, alteracaoSaldoFalha = 0, dinheiroEm = "nenhum",
    efeito = { tipo = "BLOQUEIA_ACAO", turnos = 2, alvo = "alvo" },
  },

  -- 34. Sobrecarga termica (Efeito, peso 1)
  {
    id = 34, nome = "Sobrecarga termica",
    subtitulo = "Maquinas superaquecendo... perigo!",
    descricao = "O calor excessivo danifica a producao. O alvo perde dinheiro a cada turno.",
    efeitoTexto = "Alvo perde 150 reais por turno por 3 turnos; -25 satisfacao e -10% produtividade dele",
    duracaoTexto = "3 turnos", alvoTexto = "Oponente",
    classe = "Efeito", tipo = "EFEITO",
    chanceSucesso = 0.8, precisaAlvo = true,
    alteracaoSaldoBase = 0, alteracaoSaldoFalha = 0, dinheiroEm = "nenhum",
    efeito = { tipo = "DANO_PERIODICO", valor = 150, turnos = 3, alvo = "alvo" },
    satisfacao = { valor = -25, alvo = "alvo" },
    produtividade = { valor = -0.10, alvo = "alvo" },
  },

  -- 35. Climatizacao Premium (Efeito, peso 1)
  {
    id = 35, nome = "Climatizacao Premium",
    subtitulo = "Conforto termico = produtividade maxima",
    descricao = "Ambiente perfeitamente climatizado aumenta a eficiencia de todos os seus ganhos.",
    efeitoTexto = "Seus ganhos de dinheiro +25% por 3 turnos; +30 satisfacao e +15% produtividade",
    duracaoTexto = "3 turnos", alvoTexto = "Voce",
    classe = "Efeito", tipo = "EFEITO",
    chanceSucesso = 1, precisaAlvo = false,
    alteracaoSaldoBase = 0, alteracaoSaldoFalha = 0, dinheiroEm = "nenhum",
    efeito = { tipo = "MULT_DINHEIRO", fator = 1.25, turnos = 3, alvo = "invocador" },
    satisfacao = { valor = 30, alvo = "invocador" },
    produtividade = { valor = 0.15, alvo = "invocador" },
  },

  -- 36. Blackout (Efeito, peso 1)
  {
    id = 36, nome = "Blackout",
    subtitulo = "Escuridao total. Ninguem ve nada.",
    descricao = "Queda de energia geral. Todas as cartas de efeito falham automaticamente por 1 turno.",
    efeitoTexto = "Cartas de efeito tem chance 0% por 1 turno (todos)",
    duracaoTexto = "1 turno", alvoTexto = "Todos",
    classe = "Efeito", tipo = "EFEITO",
    chanceSucesso = 1, precisaAlvo = true,
    alteracaoSaldoBase = 0, alteracaoSaldoFalha = 0, dinheiroEm = "nenhum",
    efeito = { tipo = "CHANCE_FIXA", valor = 0, usos = -1, turnos = 1, alvo = "todos", soEfeito = true },
  },

  -- 37. Luzes Malucas (Efeito, peso 1)
  {
    id = 37, nome = "Luzes Malucas",
    subtitulo = "Piscam, mudam de cor, hipnotizam...",
    descricao = "Luzes instaveis confundem a todos. Chance de sucesso de TODAS as cartas vira 50%.",
    efeitoTexto = "Todas as cartas tem chance fixa de 50% por 2 turnos",
    duracaoTexto = "2 turnos", alvoTexto = "Todos",
    classe = "Efeito", tipo = "EFEITO",
    chanceSucesso = 1, precisaAlvo = true,
    alteracaoSaldoBase = 0, alteracaoSaldoFalha = 0, dinheiroEm = "nenhum",
    efeito = { tipo = "CHANCE_FIXA", valor = 0.5, usos = -1, turnos = 2, alvo = "todos" },
  },

  -- 38. Tarefas Iluminadas (Efeito, peso 1)
  {
    id = 38, nome = "Tarefas Iluminadas",
    subtitulo = "Clareza total no que precisa ser feito",
    descricao = "Com iluminacao perfeita, voce ve exatamente o que fazer. Suas acoes sao mais precisas.",
    efeitoTexto = "Suas cartas de acao tem +30% chance por 2 turnos",
    duracaoTexto = "2 turnos", alvoTexto = "Voce",
    classe = "Efeito", tipo = "EFEITO",
    chanceSucesso = 1, precisaAlvo = false,
    alteracaoSaldoBase = 0, alteracaoSaldoFalha = 0, dinheiroEm = "nenhum",
    efeito = { tipo = "MOD_CHANCE", valor = 0.3, turnos = 2, alvo = "invocador", soAcao = true },
  },

  -- 39. Mesas Rebaixadas (Efeito, peso 1)
  {
    id = 39, nome = "Mesas Rebaixadas",
    subtitulo = "Ergonomia nao e so para cadeiras",
    descricao = "Mesas na altura ideal reduzem esforco fisico. Pequeno bonus continuo.",
    efeitoTexto = "Ganha 50 reais por turno por 3 turnos",
    duracaoTexto = "3 turnos", alvoTexto = "Voce",
    classe = "Efeito", tipo = "EFEITO",
    chanceSucesso = 1, precisaAlvo = false,
    alteracaoSaldoBase = 0, alteracaoSaldoFalha = 0, dinheiroEm = "nenhum",
    efeito = { tipo = "RENDA_FIXA", valor = 50, turnos = 3, alvo = "invocador" },
  },

  -- 40. Ajuste Mobiliario (Efeito, peso 1)
  {
    id = 40, nome = "Ajuste Mobiliario",
    subtitulo = "Cada coisa no seu lugar, cada pessoa no seu posto",
    descricao = "Reorganizacao do espaco de trabalho. Troca sua mao por cartas novas.",
    efeitoTexto = "Devolva toda a mao ao deck e puxe 5 cartas novas",
    duracaoTexto = "Instantanea", alvoTexto = "Voce",
    classe = "Efeito", tipo = "ACAO",
    chanceSucesso = 0.9, precisaAlvo = false,
    alteracaoSaldoBase = 0, alteracaoSaldoFalha = 0, dinheiroEm = "nenhum",
    efeito = { tipo = "TROCA_MAO", quantidade = 5, turnos = 1, alvo = "invocador" },
  },

  -- 41. Poltrona dos Sonhos (Efeito, peso 1)
  {
    id = 41, nome = "Poltrona dos Sonhos",
    subtitulo = "Conforto supremo para decisões supremas",
    descricao = "A cadeira perfeita te da clareza mental. Voce ve a proxima carta do deck.",
    efeitoTexto = "Revele a proxima carta do deck; compre-a ou mande-a pro descarte; +25 satisfacao",
    duracaoTexto = "Instantanea", alvoTexto = "Voce",
    classe = "Efeito", tipo = "EFEITO",
    chanceSucesso = 1, precisaAlvo = false,
    alteracaoSaldoBase = 0, alteracaoSaldoFalha = 0, dinheiroEm = "nenhum",
    efeito = { tipo = "ESPIA_DECK", alvo = "invocador" },
    satisfacao = { valor = 25, alvo = "invocador" },
  },

  -- 42. Supremacia Ergonomica (Efeito, peso 1)
  {
    id = 42, nome = "Supremacia Ergonomica",
    subtitulo = "O posto de trabalho perfeito nao existe... ate agora",
    descricao = "Ergonomia total elimina fadiga. Voce ganha um turno extra imediato.",
    efeitoTexto = "Jogue novamente (turno extra)",
    duracaoTexto = "Instantanea", alvoTexto = "Voce",
    classe = "Efeito", tipo = "EFEITO",
    chanceSucesso = 0.7, precisaAlvo = false,
    alteracaoSaldoBase = 0, alteracaoSaldoFalha = 0, dinheiroEm = "nenhum",
    efeito = { tipo = "TURNO_EXTRA", alvo = "invocador" },
  },

  -- 43. Densconforto absoluto (Efeito, peso 1)
  {
    id = 43, nome = "Densconforto absoluto",
    subtitulo = "O oposto da ergonomia. Dor, cansaço, ineficiencia.",
    descricao = "Condicoes terriveis reduzem drasticamente a capacidade do oponente.",
    efeitoTexto = "Alvo: -40% chance e -200 reais por 2 turnos; -40 satisfacao e -15% produtividade",
    duracaoTexto = "2 turnos", alvoTexto = "Oponente",
    classe = "Efeito", tipo = "ACAO",
    chanceSucesso = 0.8, precisaAlvo = true,
    alteracaoSaldoBase = 0, alteracaoSaldoFalha = 0, dinheiroEm = "nenhum",
    efeito = {
      tipo = "DINHEIRO_ALVO",
      alvo = "alvo",
      ganhoInvocador = 0,
      perdaAlvo = 200,
      debuff = { tipo = "MOD_CHANCE", valor = -0.4, turnos = 2 },
    },
    satisfacao = { valor = -40, alvo = "alvo" },
    produtividade = { valor = -0.15, alvo = "alvo" },
  },

  -- 44. Esforco Zero (Efeito, peso 1)
  {
    id = 44, nome = "Esforco Zero",
    subtitulo = "Automatizacao total. A maquina faz por voce.",
    descricao = "Processos totalmente automatizados geram renda passiva sem esforco.",
    efeitoTexto = "Ganha 100 reais por turno por 4 turnos (passivo)",
    duracaoTexto = "4 turnos", alvoTexto = "Voce",
    classe = "Efeito", tipo = "EFEITO",
    chanceSucesso = 1, precisaAlvo = false,
    alteracaoSaldoBase = 0, alteracaoSaldoFalha = 0, dinheiroEm = "nenhum",
    efeito = { tipo = "RENDA_FIXA", valor = 100, turnos = 4, alvo = "invocador" },
  },

  -- 45. Reducao da Carga Horaria (Efeito, peso 1)
  {
    id = 45, nome = "Reducao da Carga Horaria",
    subtitulo = "Menos horas, mesma producao. Magica da eficiencia.",
    descricao = "Jornada reduzida mas produtividade mantida. Seu tempo de turno diminui mas bonus aumenta.",
    efeitoTexto = "Seu tempo de turno -3s e bonus de turno +20% por 3 turnos; +30 satisfacao e +10% produtividade",
    duracaoTexto = "3 turnos", alvoTexto = "Voce",
    classe = "Efeito", tipo = "EFEITO",
    chanceSucesso = 0.9, precisaAlvo = false,
    alteracaoSaldoBase = 0, alteracaoSaldoFalha = 0, dinheiroEm = "nenhum",
    efeito = {
      tipo = "EFEITO_COMPOSTO",
      tempoBonus = -3,
      bonusTurno = 1.2,
      turnos = 3,
      alvo = "invocador"
    },
    satisfacao = { valor = 30, alvo = "invocador" },
    produtividade = { valor = 0.10, alvo = "invocador" },
  },

  -- 46. Passos Dificeis (Efeito, peso 1)
  {
    id = 46, nome = "Passos Dificeis",
    subtitulo = "O caminho da excelencia e cheio de obstaculos",
    descricao = "Dificuldades impostas ao oponente. Cada passo dele fica mais pesado.",
    efeitoTexto = "Alvo: -2s no tempo de turno e -15% chance por 3 turnos",
    duracaoTexto = "3 turnos", alvoTexto = "Oponente",
    classe = "Efeito", tipo = "ACAO",
    chanceSucesso = 0.75, precisaAlvo = true,
    alteracaoSaldoBase = 0, alteracaoSaldoFalha = 0, dinheiroEm = "nenhum",
    efeito = {
      tipo = "EFEITO_COMPOSTO",
      tempoBonus = -2,
      modChance = -0.15,
      turnos = 3,
      alvo = "alvo"
    },
  },

  -- 47. Comandos descomplicados (Efeito, peso 1)
  {
    id = 47, nome = "Comandos descomplicados",
    subtitulo = "Simplicidade e a sofisticacao final",
    descricao = "Interface limpa, comandos simples. Suas cartas de efeito ficam mais faceis de usar.",
    efeitoTexto = "Suas cartas de efeito tem +25% chance e custam menos tempo por 2 turnos",
    duracaoTexto = "2 turnos", alvoTexto = "Voce",
    classe = "Efeito", tipo = "EFEITO",
    chanceSucesso = 1, precisaAlvo = false,
    alteracaoSaldoBase = 0, alteracaoSaldoFalha = 0, dinheiroEm = "nenhum",
    efeito = { tipo = "MOD_CHANCE", valor = 0.25, turnos = 2, alvo = "invocador", soEfeito = true },
  },

  -- 48. Complexidade Arco-Iris (Efeito, peso 1)
  {
    id = 48, nome = "Complexidade Arco-Iris",
    subtitulo = "Tantas cores, tantos caminhos... qual escolher?",
    descricao = "Complexidade excessiva confunde. O alvo recebe cartas aleatorias e perde foco.",
    efeitoTexto = "Alvo descarta mao e recebe 4 cartas aleatorias; -30% chance por 2 turnos",
    duracaoTexto = "Instantanea/2 turnos", alvoTexto = "Oponente",
    classe = "Efeito", tipo = "ACAO",
    chanceSucesso = 0.8, precisaAlvo = true,
    alteracaoSaldoBase = 0, alteracaoSaldoFalha = 0, dinheiroEm = "nenhum",
    efeito = {
      tipo = "MAO_ALEATORIA",
      quantidade = 4,
      turnos = 1,
      alvo = "alvo",
      debuff = { tipo = "MOD_CHANCE", valor = -0.3, turnos = 2 },
    },
  },

  -- 49. Rock Misterioso (Efeito, peso 1)
  {
    id = 49, nome = "Rock Misterioso",
    subtitulo = "Uma pedra estranha encontrada na fabrica...",
    descricao = "Ninguem sabe o que faz. Efeitos completamente aleatorios - pode ajudar ou atrapalhar.",
    efeitoTexto = "Efeito totalmente aleatorio (sorteio entre varios possiveis)",
    duracaoTexto = "Variavel", alvoTexto = "Aleatorio",
    classe = "Efeito", tipo = "EFEITO",
    chanceSucesso = 1, precisaAlvo = false,
    alteracaoSaldoBase = 0, alteracaoSaldoFalha = 0, dinheiroEm = "nenhum",
    efeito = { tipo = "EFEITO_ALEATORIO", alvo = "aleatorio" },
  },

  -- 50. Rotatividade de Mercado (Curinga, peso 2)
  {
    id = 50, nome = "Rotatividade de Mercado",
    subtitulo = '"O mundo da voltas, o mercado tambem"',
    descricao = "O Deus mercado troca as maos dos usuarios",
    efeitoTexto = "O Deus mercado troca as maos dos usuarios",
    duracaoTexto = "Instantanea", alvoTexto = "Todos",
    classe = "Curinga", tipo = "CORINGA",
    chanceSucesso = 1, precisaAlvo = true,
    alteracaoSaldoBase = 0, alteracaoSaldoFalha = 0, dinheiroEm = "nenhum",
    efeito = { tipo = "TROCA_MAOS", alvo = "todos" },
  },

  -- 51. Probabilidade Mortal (Curinga, peso 2)
  {
    id = 51, nome = "Probabilidade Mortal",
    subtitulo = '"Essa caveira significa perigo - PE RI GO"',
    descricao = "O Deus mercado escolhera um player aleatorio para ser morto",
    efeitoTexto = "O jogador alvo perde",
    duracaoTexto = "Instantanea", alvoTexto = "Todos",
    classe = "Curinga", tipo = "CORINGA",
    chanceSucesso = 1, precisaAlvo = true,
    alteracaoSaldoBase = 0, alteracaoSaldoFalha = 0, dinheiroEm = "nenhum",
    efeito = { tipo = "MORTE_ALEATORIA", alvo = "todos" },
  },
}

-- ============================================================
-- SUPER CARTAS (manual V7) - produto da FUSAO de 2..5 cartas
-- ============================================================
-- Ficam FORA do baralho infinito: so chegam a mesa pela fusao ou como
-- produto do leilao. Ids a partir de 100 (nao colidem com as 49).
C.SUPER_CARTAS = {
  -- 101. Kaizen Supremo
  {
    id = 101, nome = "Kaizen Supremo",
    subtitulo = "Melhoria continua levada ao extremo",
    descricao = "A fabrica inteira se transforma: capital, moral e producao disparam juntos.",
    efeitoTexto = "Ganhe 900 reais e seus ganhos +50% por 3 turnos; +40 satisfacao e +25% produtividade",
    duracaoTexto = "3 turnos", alvoTexto = "Voce",
    classe = "Super", tipo = "ACAO",
    chanceSucesso = 1, precisaAlvo = false,
    alteracaoSaldoBase = 900, alteracaoSaldoFalha = 0, dinheiroEm = "invocador",
    efeito = { tipo = "MULT_DINHEIRO", fator = 1.5, turnos = 3, alvo = "invocador" },
    satisfacao = { valor = 40, alvo = "invocador" },
    produtividade = { valor = 0.25, alvo = "invocador" },
    super = true,
  },

  -- 102. Jidoka Total
  {
    id = 102, nome = "Jidoka Total",
    subtitulo = "A linha para sozinha quando encontra defeito",
    descricao = "Autonomia radical: a parada repentina castiga a producao do oponente.",
    efeitoTexto = "Alvo perde 600 reais e -40% de chance por 3 turnos; -40 satisfacao e -20% produtividade",
    duracaoTexto = "3 turnos", alvoTexto = "Oponente",
    classe = "Super", tipo = "ACAO",
    chanceSucesso = 0.9, precisaAlvo = true,
    alteracaoSaldoBase = 0, alteracaoSaldoFalha = 0, dinheiroEm = "nenhum",
    efeito = {
      tipo = "DINHEIRO_ALVO",
      alvo = "alvo",
      ganhoInvocador = 0,
      perdaAlvo = 600,
      debuff = { tipo = "MOD_CHANCE", valor = -0.4, turnos = 3 },
    },
    satisfacao = { valor = -40, alvo = "alvo" },
    produtividade = { valor = -0.20, alvo = "alvo" },
    super = true,
  },

  -- 103. Heijunka Total
  {
    id = 103, nome = "Heijunka Total",
    subtitulo = "Nivelar o fluxo e nao deixar ninguem parado",
    descricao = "Voce organiza a producao e leva tudo o que o oponente tem na mao.",
    efeitoTexto = "Roube 3 cartas do alvo; +30 satisfacao",
    duracaoTexto = "Instantanea", alvoTexto = "Oponente",
    classe = "Super", tipo = "ACAO",
    chanceSucesso = 0.9, precisaAlvo = true,
    alteracaoSaldoBase = 0, alteracaoSaldoFalha = 0, dinheiroEm = "nenhum",
    efeito = { tipo = "ROUBA_CARTAS", quantidade = 3, alvo = "alvo" },
    satisfacao = { valor = 30, alvo = "invocador" },
    super = true,
  },

  -- 104. Andon Total
  {
    id = 104, nome = "Andon Total",
    subtitulo = "Sinal de parada: ninguem passa do defeito",
    descricao = "Protecao absoluta da sua linha de producao por 3 turnos.",
    efeitoTexto = "Protecao total contra qualquer ataque por 3 turnos; +40 satisfacao",
    duracaoTexto = "3 turnos", alvoTexto = "Voce",
    classe = "Super", tipo = "EFEITO",
    chanceSucesso = 1, precisaAlvo = false,
    alteracaoSaldoBase = 0, alteracaoSaldoFalha = 0, dinheiroEm = "nenhum",
    efeito = { tipo = "PROTECAO_TOTAL", turnos = 3, alvo = "invocador" },
    satisfacao = { valor = 40, alvo = "invocador" },
    super = true,
  },
}

-- PESO de cada carta (baralho infinito): vem de pesos.lua. Carta sem entrada
-- na tabela fica com peso 0, ou seja, nunca sai no sorteio.
for _, c in ipairs(C.CARTAS) do
  c.peso = math.max(0, math.floor(tonumber(PESOS[c.nome]) or 0))
end

-- Cartas cujo efeito principal prejudica o invocador quando comparadas
-- (mesma lista de CARTAS_NEGATIVAS do motor React: ehCartaNegativa).
local CARTAS_NEGATIVAS = {
  DIVIDA = true,
  DOACAO_PERCENTUAL = true,
  ROUBA_CARTAS = true,
  DESCARTA_E_PUXA = true,
  DINHEIRO_ALVO = true,
  MAO_ALEATORIA = true,
}

function C.ehCartaNegativa(c)
  if (c.alteracaoSaldoBase or 0) < 0 then return true end
  local t = c.efeito and c.efeito.tipo
  return t ~= nil and CARTAS_NEGATIVAS[t] == true
end

-- Probabilidade de SUCESSO da carta (0..1).
function C.chanceDa(c)
  return c.chanceSucesso or 1
end

-- Cor do texto de efeito na face (ui.faceMini):
--  positiva = dinheiro para o invocador / apoio; negativa = ataque / risco.
local ATAQUES = {
  DIVIDA = true,
  ROUBA_CARTAS = true,
  DESCARTA_E_PUXA = true,
  MAO_ALEATORIA = true,
  MULT_CHANCE = true,
  PULA_JOGADA = true,
  BLOQUEIA_ACAO = true,
  DANO_PERIODICO = true,
  DINHEIRO_ALVO = true,
  DOACAO_PERCENTUAL = true,
  EFEITO_COMPOSTO = true,
  MAO_ALEATORIA = true,
  EFEITO_ALEATORIO = true,
  TROCA_ESTADO_TOTAL = true,
  TROCA_MAOS = true,
  MORTE_ALEATORIA = true,
}
local APOIOS = {
  DOACAO_PERCENTUAL = true,
  DINHEIRO_ALVO = true,
  DINHEIRO_ADIADO = true,
  DIVIDA_PARCELADA = true,
  TROCA_MAO = true,
  PROLONGA = true,
  MOD_BONUS_TURNO = true,
  PROTECAO_TOTAL = true,
  LIMPA_DIVIDAS = true,
  RENDA_FIXA = true,
  RENDA_ALEATORIA = true,
  MULT_DINHEIRO = true,
  ESPIA_DECK = true,
  TURNO_EXTRA = true,
  TEMPO_TURNO = true,
}

function C.polaridadeDe(c)
  local base = c.alteracaoSaldoBase or 0
  if base > 0 then return "positiva" end
  if base < 0 or (c.alteracaoSaldoFalha or 0) < 0 then return "negativa" end
  if c.tipo == "PROTECAO" then return "positiva" end
  local e = c.efeito
  local t = e and e.tipo
  if not t then return nil end
  if t == "MOD_CHANCE" then
    return (e.valor or 0) < 0 and "negativa" or "positiva"
  end
  if t == "TEMPO_TURNO" then
    return e.modo == "bonus" and "positiva" or nil
  end
  if t == "EFEITO_COMPOSTO" then
    -- Negativo se tem modChance negativo ou tempoBonus negativo no alvo
    if e.alvo == "alvo" and ((e.modChance or 0) < 0 or (e.tempoBonus or 0) < 0) then
      return "negativa"
    end
    if e.alvo == "invocador" and (e.bonusTurno or 1) > 1 then return "positiva" end
    return nil
  end
  if ATAQUES[t] then return "negativa" end
  if APOIOS[t] then return "positiva" end
  return nil
end

-- ============================================================
-- BARALHO INFINITO (sorteio ponderado por peso)
-- ============================================================

-- Copia nova de uma carta para a mao. O `uid` fica NULO de proposito: quem
-- compra (jogo.comprar / jogo.comprarCartas) carimba um uid unico da partida,
-- porque o baralho infinito pode entregar a mesma carta varias vezes.
function C.copia(carta)
  local c = {}
  for k, v in pairs(carta) do c[k] = v end
  c.uid = nil
  c.uidNum = carta.id
  c.chance = C.chanceDa(carta)
  c.polaridade = C.polaridadeDe(carta)
  return c
end

-- Roleta acumulada: cada carta ocupa a faixa [acumulado anterior, + peso).
-- Os pesos sao dados estaticos, entao a roleta e montada uma vez so.
local roleta = nil
function C.roleta()
  if roleta then return roleta end
  local itens, total = {}, 0
  for _, carta in ipairs(C.CARTAS) do
    local peso = carta.peso or 0
    if peso > 0 then
      total = total + peso
      itens[#itens + 1] = { carta = carta, ate = total, peso = peso }
    end
  end
  roleta = { itens = itens, total = total }
  return roleta
end

-- Soma dos pesos por classe (a meta do balanceamento e 50/32/13/5).
function C.pesosPorClasse()
  local t = {}
  for _, carta in ipairs(C.CARTAS) do
    t[carta.classe] = (t[carta.classe] or 0) + (carta.peso or 0)
  end
  return t
end

-- COMPRA: sorteia uma carta com probabilidade = peso / soma dos pesos
-- (roleta acumulada). A carta NAO sai do deck: cada compra e independente e
-- o baralho nunca acaba. Devolve uma copia (uid nulo) ou nil se nao ha pesos.
function C.comprarCarta()
  local r = C.roleta()
  if r.total <= 0 or #r.itens == 0 then return nil end
  local sorte = love.math.random() * r.total
  for _, it in ipairs(r.itens) do
    if sorte < it.ate then return C.copia(it.carta) end
  end
  return C.copia(r.itens[#r.itens].carta)
end

function C.porId(id)
  for _, carta in ipairs(C.CARTAS) do
    if carta.id == id then return carta end
  end
  return nil
end

return C
