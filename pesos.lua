-- ============================================================
-- BARALHO PADRAO (sorteio ponderado)
-- ============================================================
-- Regra: peso > 0 = carta presente no baralho; carta fora desta tabela
-- (ou com peso 0) nunca sai no sorteio. O valor e o numero de "copias"
-- relativas da carta dentro do baralho infinito.
--
-- Selecao definida para o jogo padrao (regras/baralho atual.txt):
--   - Acao:   4 cartas;
--   - Efeito: 17 cartas (5 comuns peso 3 + 12 raras peso 1);
--   - Defesa: 5 cartas (as 5 Defesas da planilha);
--   - Curinga: 6 Curingas, cada um com peso 2 = 12 cartas especiais.
--
-- Cartas nao listadas aqui ficam de fora do baralho padrao, mas continuam
-- existindo no catalogo (podem aparecer em leilao/lojinha/fusao).
return {
  -- ---------------- Acao (4 cartas) ----------------
  ["Overclock Produtivo"] = 3,
  ["Cada Um No Seu Quadrado"] = 3,
  ["Presente do Noel"] = 3,
  ["Emprestimo"] = 3,

  -- ---------------- Efeito (17 cartas) ----------------
  -- comuns (peso 3)
  ["Queima de Estoque"] = 3,
  ["Toyotinho"] = 3,
  ["Concepcao de Dewey"] = 3,
  ["Atestado Medico"] = 3,
  ["Inercia Psicologica"] = 3,
  -- raras (peso 1)
  ["Reset Reconciliatorio"] = 1,
  ["Hora Extra"] = 1,
  ["Sabotagem empresarial"] = 1,
  ["Rock Misterioso"] = 1,
  ["Roubo de Ideias"] = 1,
  ["Poltrona dos Sonhos"] = 1,
  ["Mesas Rebaixadas"] = 1,
  ["Ajuste Mobiliario"] = 1,
  ["Supremacia Ergonomica"] = 1,
  ["Reducao da Carga Horaria"] = 1,
  ["Esforco Zero"] = 1,
  ["Climatizacao Premium"] = 1,

  -- ---------------- Defesa (5 cartas da planilha) ----------------
  ["Tempos e Movimentos"] = 3,
  ["Psicologia Industrial"] = 3,
  ["Mao Visivel"] = 3,
  ["Seiketsu"] = 3,
  ["Previsao"] = 3,

  -- ---------------- Curinga (6 x 2 = 12 especiais) ----------------
  ["O Monstro Inflacao"] = 2,
  ["Seletividade de Taylor"] = 2,
  ["Flutuacao do Mercado"] = 2,
  ["Efeito Hawthorne"] = 2,
  ["Rotatividade de Mercado"] = 2,
  ["Probabilidade Mortal"] = 2,
}
