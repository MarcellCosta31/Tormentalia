export const TIPO_CARTA = {
  CORINGA: 'CORINGA',
  ACAO: 'ACAO',
  EFEITO: 'EFEITO',
  PROTECAO: 'PROTECAO',
};

const CARTAS_CORINGA = [
  { id: 1, titulo: 'Mão do Destino', tipo: TIPO_CARTA.CORINGA, alteracaoSaldoBase: 12, chanceSucesso: 0.7, alteracaoSaldoFalha: -8, precisaAlvo: false },
  { id: 2, titulo: 'Troca Justa', tipo: TIPO_CARTA.CORINGA, alteracaoSaldoBase: 8, chanceSucesso: 0.6, alteracaoSaldoFalha: -5, precisaAlvo: true },
  { id: 3, titulo: 'Caos Total', tipo: TIPO_CARTA.CORINGA, alteracaoSaldoBase: 15, chanceSucesso: 0.5, alteracaoSaldoFalha: -10, precisaAlvo: false },
  { id: 4, titulo: 'Deus Mercado', tipo: TIPO_CARTA.CORINGA, alteracaoSaldoBase: 20, chanceSucesso: 0.4, alteracaoSaldoFalha: -15, precisaAlvo: false },
  { id: 5, titulo: 'Dilema Moral', tipo: TIPO_CARTA.CORINGA, alteracaoSaldoBase: 10, chanceSucesso: 0.65, alteracaoSaldoFalha: -7, precisaAlvo: true },
  { id: 6, titulo: 'Aposta Arriscada', tipo: TIPO_CARTA.CORINGA, alteracaoSaldoBase: 18, chanceSucesso: 0.45, alteracaoSaldoFalha: -12, precisaAlvo: false },
  { id: 7, titulo: 'Golpe Esperto', tipo: TIPO_CARTA.CORINGA, alteracaoSaldoBase: 9, chanceSucesso: 0.75, alteracaoSaldoFalha: -6, precisaAlvo: true },
  { id: 8, titulo: 'Rei do Mercado', tipo: TIPO_CARTA.CORINGA, alteracaoSaldoBase: 14, chanceSucesso: 0.55, alteracaoSaldoFalha: -9, precisaAlvo: false },
  { id: 9, titulo: 'Comércio Negro', tipo: TIPO_CARTA.CORINGA, alteracaoSaldoBase: 11, chanceSucesso: 0.6, alteracaoSaldoFalha: -8, precisaAlvo: true },
  { id: 10, titulo: 'Milagre Financeiro', tipo: TIPO_CARTA.CORINGA, alteracaoSaldoBase: 16, chanceSucesso: 0.35, alteracaoSaldoFalha: -14, precisaAlvo: false },
  { id: 11, titulo: 'Fé Cega', tipo: TIPO_CARTA.CORINGA, alteracaoSaldoBase: 7, chanceSucesso: 0.8, alteracaoSaldoFalha: -4, precisaAlvo: false },
  { id: 12, titulo: 'Aposta Dupla', tipo: TIPO_CARTA.CORINGA, alteracaoSaldoBase: 13, chanceSucesso: 0.5, alteracaoSaldoFalha: -11, precisaAlvo: true },
  { id: 13, titulo: 'Sorte Grande', tipo: TIPO_CARTA.CORINGA, alteracaoSaldoBase: 17, chanceSucesso: 0.4, alteracaoSaldoFalha: -13, precisaAlvo: false },
  { id: 14, titulo: 'Carta Marcada', tipo: TIPO_CARTA.CORINGA, alteracaoSaldoBase: 10, chanceSucesso: 0.7, alteracaoSaldoFalha: -6, precisaAlvo: true },
  { id: 15, titulo: 'Negociação Suja', tipo: TIPO_CARTA.CORINGA, alteracaoSaldoBase: 12, chanceSucesso: 0.55, alteracaoSaldoFalha: -10, precisaAlvo: true },
  { id: 16, titulo: 'Deus do Caos', tipo: TIPO_CARTA.CORINGA, alteracaoSaldoBase: 25, chanceSucesso: 0.3, alteracaoSaldoFalha: -18, precisaAlvo: false },
];

const CARTAS_ACAO = [
  { id: 17, titulo: 'Venda Agressiva', tipo: TIPO_CARTA.ACAO, alteracaoSaldoBase: 5, chanceSucesso: 0.85, alteracaoSaldoFalha: -3, precisaAlvo: false },
  { id: 18, titulo: 'Compra Atacado', tipo: TIPO_CARTA.ACAO, alteracaoSaldoBase: 4, chanceSucesso: 0.9, alteracaoSaldoFalha: -2, precisaAlvo: false },
  { id: 19, titulo: 'Marketing Viral', tipo: TIPO_CARTA.ACAO, alteracaoSaldoBase: 6, chanceSucesso: 0.75, alteracaoSaldoFalha: -4, precisaAlvo: false },
  { id: 20, titulo: 'Preço de Guerra', tipo: TIPO_CARTA.ACAO, alteracaoSaldoBase: 3, chanceSucesso: 0.95, alteracaoSaldoFalha: -1, precisaAlvo: true },
  { id: 21, titulo: 'Monopólio', tipo: TIPO_CARTA.ACAO, alteracaoSaldoBase: 8, chanceSucesso: 0.6, alteracaoSaldoFalha: -6, precisaAlvo: true },
  { id: 22, titulo: 'Greve dos Fornecedores', tipo: TIPO_CARTA.ACAO, alteracaoSaldoBase: 0, chanceSucesso: 0.7, alteracaoSaldoFalha: 0, precisaAlvo: true },
  { id: 23, titulo: 'Inovação', tipo: TIPO_CARTA.ACAO, alteracaoSaldoBase: 7, chanceSucesso: 0.7, alteracaoSaldoFalha: -5, precisaAlvo: false },
  { id: 24, titulo: 'Expansão', tipo: TIPO_CARTA.ACAO, alteracaoSaldoBase: 6, chanceSucesso: 0.65, alteracaoSaldoFalha: -4, precisaAlvo: false },
  { id: 25, titulo: 'Fusão', tipo: TIPO_CARTA.ACAO, alteracaoSaldoBase: 9, chanceSucesso: 0.55, alteracaoSaldoFalha: -7, precisaAlvo: false },
  { id: 26, titulo: 'Aquisição', tipo: TIPO_CARTA.ACAO, alteracaoSaldoBase: 5, chanceSucesso: 0.8, alteracaoSaldoFalha: -3, precisaAlvo: true },
  { id: 27, titulo: 'Descarte Total', tipo: TIPO_CARTA.ACAO, alteracaoSaldoBase: 0, chanceSucesso: 0.75, alteracaoSaldoFalha: 0, precisaAlvo: true },
  { id: 28, titulo: 'Capital de Giro', tipo: TIPO_CARTA.ACAO, alteracaoSaldoBase: 4, chanceSucesso: 0.9, alteracaoSaldoFalha: -2, precisaAlvo: false },
  { id: 29, titulo: 'Queda Livre', tipo: TIPO_CARTA.ACAO, alteracaoSaldoBase: -3, chanceSucesso: 0.8, alteracaoSaldoFalha: 2, precisaAlvo: true },
  { id: 30, titulo: 'Boato', tipo: TIPO_CARTA.ACAO, alteracaoSaldoBase: -4, chanceSucesso: 0.7, alteracaoSaldoFalha: 3, precisaAlvo: true },
  { id: 31, titulo: 'Auditoria', tipo: TIPO_CARTA.ACAO, alteracaoSaldoBase: -5, chanceSucesso: 0.65, alteracaoSaldoFalha: 4, precisaAlvo: true },
  { id: 32, titulo: 'Crise', tipo: TIPO_CARTA.ACAO, alteracaoSaldoBase: -6, chanceSucesso: 0.6, alteracaoSaldoFalha: 5, precisaAlvo: true },
  { id: 33, titulo: 'Recessão', tipo: TIPO_CARTA.ACAO, alteracaoSaldoBase: -4, chanceSucesso: 0.75, alteracaoSaldoFalha: 3, precisaAlvo: false },
  { id: 34, titulo: 'Calote', tipo: TIPO_CARTA.ACAO, alteracaoSaldoBase: -3, chanceSucesso: 0.85, alteracaoSaldoFalha: 2, precisaAlvo: true },
  { id: 35, titulo: 'Roubo Corporativo', tipo: TIPO_CARTA.ACAO, alteracaoSaldoBase: -7, chanceSucesso: 0.55, alteracaoSaldoFalha: 6, precisaAlvo: true },
  { id: 36, titulo: 'Boicote', tipo: TIPO_CARTA.ACAO, alteracaoSaldoBase: -5, chanceSucesso: 0.7, alteracaoSaldoFalha: 4, precisaAlvo: true },
  { id: 37, titulo: 'Greve Geral', tipo: TIPO_CARTA.ACAO, alteracaoSaldoBase: -6, chanceSucesso: 0.6, alteracaoSaldoFalha: 5, precisaAlvo: false },
  { id: 38, titulo: 'Inflação', tipo: TIPO_CARTA.ACAO, alteracaoSaldoBase: -4, chanceSucesso: 0.8, alteracaoSaldoFalha: 3, precisaAlvo: false },
  { id: 39, titulo: 'Divida', tipo: TIPO_CARTA.ACAO, alteracaoSaldoBase: -8, chanceSucesso: 0.5, alteracaoSaldoFalha: 7, precisaAlvo: false },
  { id: 40, titulo: 'Bancarrota', tipo: TIPO_CARTA.ACAO, alteracaoSaldoBase: -9, chanceSucesso: 0.45, alteracaoSaldoFalha: 8, precisaAlvo: false },
];

const CARTAS_EFEITO = [
  { id: 41, titulo: 'Imposto Surprise', tipo: TIPO_CARTA.EFEITO, alteracaoSaldoBase: -3, chanceSucesso: 0.8, alteracaoSaldoFalha: 2, precisaAlvo: true },
  { id: 42, titulo: 'Cashback', tipo: TIPO_CARTA.EFEITO, alteracaoSaldoBase: 3, chanceSucesso: 0.85, alteracaoSaldoFalha: -2, precisaAlvo: false },
  { id: 43, titulo: 'Desconto Espontâneo', tipo: TIPO_CARTA.EFEITO, alteracaoSaldoBase: -2, chanceSucesso: 0.9, alteracaoSaldoFalha: 1, precisaAlvo: true },
  { id: 44, titulo: 'Frete Grátis', tipo: TIPO_CARTA.EFEITO, alteracaoSaldoBase: 2, chanceSucesso: 0.9, alteracaoSaldoFalha: -1, precisaAlvo: false },
  { id: 45, titulo: 'Troca Fracionada', tipo: TIPO_CARTA.EFEITO, alteracaoSaldoBase: -1, chanceSucesso: 0.95, alteracaoSaldoFalha: 1, precisaAlvo: true },
  { id: 46, titulo: 'Promo Relâmpago', tipo: TIPO_CARTA.EFEITO, alteracaoSaldoBase: 4, chanceSucesso: 0.7, alteracaoSaldoFalha: -3, precisaAlvo: false },
  { id: 47, titulo: 'Estorno', tipo: TIPO_CARTA.EFEITO, alteracaoSaldoBase: -2, chanceSucesso: 0.85, alteracaoSaldoFalha: 1, precisaAlvo: true },
  { id: 48, titulo: 'Bônus de Fidelidade', tipo: TIPO_CARTA.EFEITO, alteracaoSaldoBase: 3, chanceSucesso: 0.8, alteracaoSaldoFalha: -2, precisaAlvo: false },
  { id: 49, titulo: 'Juros Abusivos', tipo: TIPO_CARTA.EFEITO, alteracaoSaldoBase: -4, chanceSucesso: 0.75, alteracaoSaldoFalha: 3, precisaAlvo: true },
  { id: 50, titulo: 'Reembolso', tipo: TIPO_CARTA.EFEITO, alteracaoSaldoBase: 2, chanceSucesso: 0.85, alteracaoSaldoFalha: -1, precisaAlvo: false },
  { id: 51, titulo: 'Correção Monetária', tipo: TIPO_CARTA.EFEITO, alteracaoSaldoBase: -1, chanceSucesso: 0.9, alteracaoSaldoFalha: 1, precisaAlvo: false },
  { id: 52, titulo: 'Dividendo', tipo: TIPO_CARTA.EFEITO, alteracaoSaldoBase: 4, chanceSucesso: 0.7, alteracaoSaldoFalha: -3, precisaAlvo: false },
  { id: 53, titulo: 'Multas', tipo: TIPO_CARTA.EFEITO, alteracaoSaldoBase: -3, chanceSucesso: 0.8, alteracaoSaldoFalha: 2, precisaAlvo: true },
  { id: 54, titulo: 'Aporte Forçado', tipo: TIPO_CARTA.EFEITO, alteracaoSaldoBase: -2, chanceSucesso: 0.85, alteracaoSaldoFalha: 2, precisaAlvo: true },
  { id: 55, titulo: 'Vale-Refeição', tipo: TIPO_CARTA.EFEITO, alteracaoSaldoBase: 2, chanceSucesso: 0.9, alteracaoSaldoFalha: -1, precisaAlvo: false },
  { id: 56, titulo: 'Taxa Oculta', tipo: TIPO_CARTA.EFEITO, alteracaoSaldoBase: -3, chanceSucesso: 0.8, alteracaoSaldoFalha: 2, precisaAlvo: true },
  { id: 57, titulo: 'Superbanana', tipo: TIPO_CARTA.EFEITO, alteracaoSaldoBase: 3, chanceSucesso: 0.75, alteracaoSaldoFalha: -2, precisaAlvo: false },
  { id: 58, titulo: 'Cupom Vencido', tipo: TIPO_CARTA.EFEITO, alteracaoSaldoBase: -1, chanceSucesso: 0.9, alteracaoSaldoFalha: 1, precisaAlvo: true },
  { id: 59, titulo: 'Lucro Inesperado', tipo: TIPO_CARTA.EFEITO, alteracaoSaldoBase: 5, chanceSucesso: 0.6, alteracaoSaldoFalha: -4, precisaAlvo: false },
  { id: 60, titulo: 'Desvio de Verba', tipo: TIPO_CARTA.EFEITO, alteracaoSaldoBase: -2, chanceSucesso: 0.85, alteracaoSaldoFalha: 2, precisaAlvo: true },
];

const CARTAS_PROTECAO = [
  { id: 61, titulo: 'Escudo Fiscal', tipo: TIPO_CARTA.PROTECAO, alteracaoSaldoBase: 0, chanceSucesso: 1.0, alteracaoSaldoFalha: 0, precisaAlvo: false },
  { id: 62, titulo: 'Advogado', tipo: TIPO_CARTA.PROTECAO, alteracaoSaldoBase: 0, chanceSucesso: 1.0, alteracaoSaldoFalha: 0, precisaAlvo: false },
  { id: 63, titulo: 'Seguro Empresarial', tipo: TIPO_CARTA.PROTECAO, alteracaoSaldoBase: 0, chanceSucesso: 1.0, alteracaoSaldoFalha: 0, precisaAlvo: false },
  { id: 64, titulo: 'Blindagem', tipo: TIPO_CARTA.PROTECAO, alteracaoSaldoBase: 0, chanceSucesso: 1.0, alteracaoSaldoFalha: 0, precisaAlvo: false },
  { id: 65, titulo: 'Auditoria Interna', tipo: TIPO_CARTA.PROTECAO, alteracaoSaldoBase: 0, chanceSucesso: 1.0, alteracaoSaldoFalha: 0, precisaAlvo: false },
  { id: 66, titulo: 'Cofre', tipo: TIPO_CARTA.PROTECAO, alteracaoSaldoBase: 0, chanceSucesso: 1.0, alteracaoSaldoFalha: 0, precisaAlvo: false },
  { id: 67, titulo: 'Contrato', tipo: TIPO_CARTA.PROTECAO, alteracaoSaldoBase: 0, chanceSucesso: 1.0, alteracaoSaldoFalha: 0, precisaAlvo: false },
  { id: 68, titulo: 'Alvará', tipo: TIPO_CARTA.PROTECAO, alteracaoSaldoBase: 0, chanceSucesso: 1.0, alteracaoSaldoFalha: 0, precisaAlvo: false },
  { id: 69, titulo: 'Patente', tipo: TIPO_CARTA.PROTECAO, alteracaoSaldoBase: 0, chanceSucesso: 1.0, alteracaoSaldoFalha: 0, precisaAlvo: false },
  { id: 70, titulo: 'Sigilo', tipo: TIPO_CARTA.PROTECAO, alteracaoSaldoBase: 0, chanceSucesso: 1.0, alteracaoSaldoFalha: 0, precisaAlvo: false },
];

export function gerarBaralhoCompleto() {
  const baralho = [];
  let uid = 0;

  const adicionarCartas = (cartas) => {
    cartas.forEach((carta) => {
      baralho.push({ ...carta, uid: uid++ });
    });
  };

  adicionarCartas(CARTAS_CORINGA);
  adicionarCartas(CARTAS_ACAO);
  adicionarCartas(CARTAS_EFEITO);
  adicionarCartas(CARTAS_PROTECAO);

  return baralho;
}

export function embaralharBaralho(array) {
  const arr = [...array];
  for (let i = arr.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [arr[i], arr[j]] = [arr[j], arr[i]];
  }
  return arr;
}

export function comprarCarta(baralho, mao, quantidade = 1) {
  const baralhoLocal = [...baralho];
  const maoLocal = [...mao];
  const maxCompra = Math.min(quantidade, 7 - maoLocal.length);

  for (let i = 0; i < maxCompra; i++) {
    if (baralhoLocal.length === 0) break;
    const carta = baralhoLocal.shift();
    maoLocal.push(carta);
  }

  return { baralho: baralhoLocal, mao: maoLocal };
}
