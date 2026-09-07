export const TIPO_CARTA = {
  MEDIDA: 'MEDIDA',
  BONUS: 'BONUS',
  CORINGA: 'CORINGA'
};

export const CARTAS_MEDIAS = [
  // Cartas Positivas
  {
    id: 1,
    nome: 'Venda de Produtos',
    tipo: TIPO_CARTA.MEDIDA,
    efeito: { tipo: 'DINHEIRO', valor: 10 },
    risco: 20,
    descricao: 'Venda básica do estoque',
    pixelEmoji: '📦'
  },
  {
    id: 2,
    nome: 'Propaganda na TV',
    tipo: TIPO_CARTA.MEDIDA,
    efeito: { tipo: 'DINHEIRO', valor: 5 },
    risco: 10,
    descricao: 'Marketing simples',
    pixelEmoji: '📺'
  },
  {
    id: 3,
    nome: 'Nova Filial',
    tipo: TIPO_CARTA.MEDIDA,
    efeito: { tipo: 'DINHEIRO', valor: 15 },
    risco: 50,
    descricao: 'Expansão arriscada',
    pixelEmoji: '🏪'
  },
  {
    id: 4,
    nome: 'Parceria Estratégica',
    tipo: TIPO_CARTA.MEDIDA,
    efeito: { tipo: 'DINHEIRO', valor: 12 },
    risco: 30,
    descricao: 'Colaboração com outra empresa',
    pixelEmoji: '🤝'
  },
  {
    id: 5,
    nome: 'Produto Estrela',
    tipo: TIPO_CARTA.MEDIDA,
    efeito: { tipo: 'DINHEIRO', valor: 20 },
    risco: 70,
    descricao: 'Lançamento de produto inovador',
    pixelEmoji: '⭐'
  },
  {
    id: 6,
    nome: 'Investimento em Ações',
    tipo: TIPO_CARTA.MEDIDA,
    efeito: { tipo: 'DINHEIRO', valor: 8 },
    risco: 40,
    descricao: 'Aplicação no mercado financeiro',
    pixelEmoji: '📈'
  },
  {
    id: 7,
    nome: 'Contrato Governamental',
    tipo: TIPO_CARTA.MEDIDA,
    efeito: { tipo: 'DINHEIRO', valor: 18 },
    risco: 60,
    descricao: 'Licitação pública',
    pixelEmoji: '📋'
  },
  {
    id: 8,
    nome: 'Exportação',
    tipo: TIPO_CARTA.MEDIDA,
    efeito: { tipo: 'DINHEIRO', valor: 14 },
    risco: 45,
    descricao: 'Vendas para exterior',
    pixelEmoji: '✈️'
  },
  {
    id: 9,
    nome: 'Venda Online',
    tipo: TIPO_CARTA.MEDIDA,
    efeito: { tipo: 'DINHEIRO', valor: 7 },
    risco: 15,
    descricao: 'E-commerce básico',
    pixelEmoji: '💻'
  },
  {
    id: 10,
    nome: 'Serviço Premium',
    tipo: TIPO_CARTA.MEDIDA,
    efeito: { tipo: 'DINHEIRO', valor: 11 },
    risco: 35,
    descricao: 'Atendimento VIP',
    pixelEmoji: '👑'
  },

  // Cartas Negativas
  {
    id: 11,
    nome: 'Multa Trabalhista',
    tipo: TIPO_CARTA.MEDIDA,
    efeito: { tipo: 'DINHEIRO', valor: -8 },
    risco: 100,
    descricao: 'Problemas com funcionários',
    pixelEmoji: '⚖️'
  },
  {
    id: 12,
    nome: 'Crise Econômica',
    tipo: TIPO_CARTA.MEDIDA,
    efeito: { tipo: 'TODOS', valor: -5 },
    risco: 100,
    descricao: 'Afeta todos os jogadores',
    pixelEmoji: '📉'
  },
  {
    id: 13,
    nome: 'Concorrente Ataca',
    tipo: TIPO_CARTA.MEDIDA,
    efeito: { tipo: 'OPONENTE', valor: -5 },
    risco: 80,
    descricao: 'Prejudica um oponente',
    pixelEmoji: '🎯'
  },
  {
    id: 14,
    nome: 'Falha na Produção',
    tipo: TIPO_CARTA.MEDIDA,
    efeito: { tipo: 'DINHEIRO', valor: -7 },
    risco: 100,
    descricao: 'Problemas na fábrica',
    pixelEmoji: '🏭'
  },
  {
    id: 15,
    nome: 'Aumento de Impostos',
    tipo: TIPO_CARTA.MEDIDA,
    efeito: { tipo: 'DINHEIRO', valor: -6 },
    risco: 100,
    descricao: 'Muda a cada turno',
    pixelEmoji: '💸'
  },
  {
    id: 16,
    nome: 'Roubo/Crime',
    tipo: TIPO_CARTA.MEDIDA,
    efeito: { tipo: 'DINHEIRO', valor: -10 },
    risco: 60,
    descricao: 'Perda de ativos',
    pixelEmoji: '🚨'
  },
  {
    id: 17,
    nome: 'Processo Judicial',
    tipo: TIPO_CARTA.MEDIDA,
    efeito: { tipo: 'DINHEIRO', valor: -12 },
    risco: 70,
    descricao: 'Ação na justiça',
    pixelEmoji: '👨‍⚖️'
  },
  {
    id: 18,
    nome: 'Desastre Natural',
    tipo: TIPO_CARTA.MEDIDA,
    efeito: { tipo: 'DINHEIRO', valor: -9 },
    risco: 50,
    descricao: 'Evento imprevisto',
    pixelEmoji: '🌪️'
  },
  {
    id: 19,
    nome: 'Greve',
    tipo: TIPO_CARTA.MEDIDA,
    efeito: { tipo: 'BUFF', valor: -3, duracao: 2 },
    risco: 100,
    descricao: 'Funcionários parados',
    pixelEmoji: '✊'
  },
  {
    id: 20,
    nome: 'Boa Reputação',
    tipo: TIPO_CARTA.MEDIDA,
    efeito: { tipo: 'BUFF', valor: 2, duracao: 3 },
    risco: 20,
    descricao: 'Imagem positiva',
    pixelEmoji: '🌟'
  },
  {
    id: 21,
    nome: 'Má Reputação',
    tipo: TIPO_CARTA.MEDIDA,
    efeito: { tipo: 'BUFF', valor: -2, duracao: 2 },
    risco: 100,
    descricao: 'Imagem negativa',
    pixelEmoji: '😤'
  },
  {
    id: 22,
    nome: 'Monopólio',
    tipo: TIPO_CARTA.MEDIDA,
    efeito: { tipo: 'DINHEIRO', valor: 4 },
    risco: 40,
    descricao: 'Controle de mercado',
    pixelEmoji: '🏢'
  },
  {
    id: 23,
    nome: 'Venda Flash',
    tipo: TIPO_CARTA.MEDIDA,
    efeito: { tipo: 'DINHEIRO', valor: 6 },
    risco: 25,
    descricao: 'Promoção relâmpago',
    pixelEmoji: '⚡'
  },
  {
    id: 24,
    nome: 'Investidor Externo',
    tipo: TIPO_CARTA.MEDIDA,
    efeito: { tipo: 'DINHEIRO', valor: 16 },
    risco: 55,
    descricao: 'Capital estrangeiro',
    pixelEmoji: '🌍'
  },
  {
    id: 25,
    nome: 'Problema no Sistema',
    tipo: TIPO_CARTA.MEDIDA,
    efeito: { tipo: 'DINHEIRO', valor: -4 },
    risco: 100,
    descricao: 'Falha tecnológica',
    pixelEmoji: '💻'
  },
  {
    id: 26,
    nome: 'Auditoria',
    tipo: TIPO_CARTA.MEDIDA,
    efeito: { tipo: 'DINHEIRO', valor: -3 },
    risco: 100,
    descricao: 'Fiscalização',
    pixelEmoji: '🔍'
  },
  {
    id: 27,
    nome: 'Novo Produto',
    tipo: TIPO_CARTA.MEDIDA,
    efeito: { tipo: 'DINHEIRO', valor: 9 },
    risco: 35,
    descricao: 'Inovação no catálogo',
    pixelEmoji: '🆕'
  },
  {
    id: 28,
    nome: 'Parceria com Influencer',
    tipo: TIPO_CARTA.MEDIDA,
    efeito: { tipo: 'DINHEIRO', valor: 13 },
    risco: 40,
    descricao: 'Marketing digital',
    pixelEmoji: '📱'
  },
  {
    id: 29,
    nome: 'Divórcio Corporativo',
    tipo: TIPO_CARTA.MEDIDA,
    efeito: { tipo: 'DINHEIRO', valor: -11 },
    risco: 65,
    descricao: 'Separação de sócios',
    pixelEmoji: '💔'
  },
  {
    id: 30,
    nome: 'Franquia',
    tipo: TIPO_CARTA.MEDIDA,
    efeito: { tipo: 'DINHEIRO', valor: 17 },
    risco: 60,
    descricao: 'Expansão via franquia',
    pixelEmoji: '🏬'
  }
];

export const CARTAS_BONUS = [
  {
    id: 101,
    nome: 'Investidor Anjo',
    tipo: TIPO_CARTA.BONUS,
    efeito: { tipo: 'REMOVE_RISCO', valor: 100 },
    descricao: 'Remove todo o risco da carta medida',
    pixelEmoji: '👼'
  },
  {
    id: 102,
    nome: 'Consultor Financeiro',
    tipo: TIPO_CARTA.BONUS,
    efeito: { tipo: 'MULTIPLICA_EFEITO', valor: 1.5 },
    descricao: '+50% do efeito da carta medida',
    pixelEmoji: '💼'
  },
  {
    id: 103,
    nome: 'Seguro Empresarial',
    tipo: TIPO_CARTA.BONUS,
    efeito: { tipo: 'PROTEGE_FALHA', valor: 100 },
    descricao: 'Se falhar, não perde nada',
    pixelEmoji: '🛡️'
  },
  {
    id: 104,
    nome: 'Lobby Político',
    tipo: TIPO_CARTA.BONUS,
    efeito: { tipo: 'REDUZ_RISCO', valor: 50 },
    descricao: 'Reduz risco pela metade',
    pixelEmoji: '🏛️'
  },
  {
    id: 105,
    nome: 'Oportunidade Única',
    tipo: TIPO_CARTA.BONUS,
    efeito: { tipo: 'CRITICO', valor: 30 },
    descricao: '30% chance de efeito x3',
    pixelEmoji: '🎯'
  },
  {
    id: 106,
    nome: 'Amigo no Governo',
    tipo: TIPO_CARTA.BONUS,
    efeito: { tipo: 'REMOVE_RISCO_ESPECIFICO', valor: 100, tipoCarta: 'Contrato Governamental' },
    descricao: 'Remove risco em contratos governamentais',
    pixelEmoji: '🏛️'
  },
  {
    id: 107,
    nome: 'Marketing Viral',
    tipo: TIPO_CARTA.BONUS,
    efeito: { tipo: 'MULTIPLICA_EFEITO', valor: 2, tipoCarta: 'Propaganda' },
    descricao: '+100% em cartas de propaganda',
    pixelEmoji: '📣'
  },
  {
    id: 108,
    nome: 'Advogado Caro',
    tipo: TIPO_CARTA.BONUS,
    efeito: { tipo: 'REDUZ_PERDA', valor: 50, tipoCarta: 'Processo Judicial' },
    descricao: 'Reduz processos pela metade',
    pixelEmoji: '👨‍⚖️'
  },
  {
    id: 109,
    nome: 'Sorte Grande',
    tipo: TIPO_CARTA.BONUS,
    efeito: { tipo: 'REMOVE_RISCO', valor: 100 },
    descricao: 'Risco zero para qualquer carta',
    pixelEmoji: '🍀'
  },
  {
    id: 110,
    nome: 'Pechinche',
    tipo: TIPO_CARTA.BONUS,
    efeito: { tipo: 'DINHEIRO_EXTRA', valor: 5 },
    descricao: 'Ganha R$ 5 extra com qualquer carta',
    pixelEmoji: '🤑'
  },
  {
    id: 111,
    nome: 'Correção Monetária',
    tipo: TIPO_CARTA.BONUS,
    efeito: { tipo: 'RECUPERA_PERDA', valor: 50 },
    descricao: 'Recupera 50% de perdas',
    pixelEmoji: '💹'
  },
  {
    id: 112,
    nome: 'Filial Fantasma',
    tipo: TIPO_CARTA.BONUS,
    efeito: { tipo: 'DINHEIRO_EXTRA', valor: 8 },
    descricao: '+R$ 8 garantidos sem risco',
    pixelEmoji: '👻'
  },
  {
    id: 113,
    nome: 'Segredo Industrial',
    tipo: TIPO_CARTA.BONUS,
    efeito: { tipo: 'PROXIMA_CARTA_SEM_RISCO', valor: 1 },
    descricao: 'Próxima carta jogada sem risco',
    pixelEmoji: '🤫'
  },
  {
    id: 114,
    nome: 'Parceiro Estratégico',
    tipo: TIPO_CARTA.BONUS,
    efeito: { tipo: 'MULTIPLICA_EFEITO', valor: 1.3, tipoCarta: 'Parceria' },
    descricao: '+30% em cartas de parceria',
    pixelEmoji: '🤝'
  },
  {
    id: 115,
    nome: 'Reserva do BCE',
    tipo: TIPO_CARTA.BONUS,
    efeito: { tipo: 'DINHEIRO_EXTRA_CONDICIONAL', valor: 10, condicao: 'SALDO_MENOR_10' },
    descricao: '+R$ 10 se saldo < R$ 10',
    pixelEmoji: '🏦'
  }
];

export const CARTA_CORINGA = {
  id: 200,
  nome: 'O Grande Deus Mercado',
  tipo: TIPO_CARTA.CORINGA,
  efeito: { tipo: 'ALEATORIO', opcoes: [
    { tipo: 'DINHEIRO', valor: 30, chance: 25 },
    { tipo: 'DINHEIRO', valor: -20, chance: 25 },
    { tipo: 'ROUBA_CARTA', valor: 1, chance: 25 },
    { tipo: 'TODOS_PERDEM', valor: 10, chance: 25 }
  ]},
  descricao: 'Efeito completamente aleatório!',
  pixelEmoji: '🎲'
};

export const criarBaralho = () => {
  const baralho = [];
  
  // Adiciona cartas medidas (2 de cada)
  CARTAS_MEDIAS.forEach(carta => {
    baralho.push({ ...carta, uid: `${carta.id}-1` });
    baralho.push({ ...carta, uid: `${carta.id}-2` });
  });
  
  // Adiciona cartas bônus (1 de cada)
  CARTAS_BONUS.forEach(carta => {
    baralho.push({ ...carta, uid: `${carta.id}-1` });
  });
  
  // Adiciona carta coringa
  baralho.push({ ...CARTA_CORINGA, uid: 'coringa-1' });
  
  return baralho;
};

export const embaralhar = (baralho) => {
  const baralhoEmbaralhado = [...baralho];
  for (let i = baralhoEmbaralhado.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [baralhoEmbaralhado[i], baralhoEmbaralhado[j]] = [baralhoEmbaralhado[j], baralhoEmbaralhado[i]];
  }
  return baralhoEmbaralhado;
};
