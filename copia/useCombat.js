import { gerarBaralhoCompleto, embaralharBaralho, comprarCarta as comprarCartaBaralho } from '../cards/baralhoCartas';
import { TIPO_CARTA } from '../cards/baralhoCartas';

const SALDO_INICIAL = 20;
const SALDO_EMERGENCIA = 5;
const MAX_TURNOS = 10;
const CARTAS_POR_MAO = 7;

function criarJogador(id, nome, isIA, avatar) {
  return {
    id,
    nome,
    isIA,
    avatar: avatar ?? null,   // <- novo
    saldo: SALDO_INICIAL,
    usouFundoEmergencia: false,
    mao: [],
    falido: false,
    protegido: false,
  };
}

function verificarFundoEmergencia(jogador) {
  if (jogador.saldo <= 0 && !jogador.usouFundoEmergencia) {
    return { ...jogador, saldo: SALDO_EMERGENCIA, usouFundoEmergencia: true };
  }
  return jogador;
}

function verificarFalencia(jogador) {
  if (jogador.saldo <= 0 && jogador.usouFundoEmergencia) {
    return { ...jogador, falido: true };
  }
  return jogador;
}

function aplicarEventoDeusMercado(jogadores) {
  const evento = Math.floor(Math.random() * 4);
  return jogadores.map((j) => {
    if (j.falido) return j;
    let novoSaldo = j.saldo;
    switch (evento) {
      case 0:
        novoSaldo += 2;
        break;
      case 1:
        novoSaldo -= 2;
        break;
      case 2:
        novoSaldo += 1;
        break;
      case 3:
        novoSaldo -= 3;
        break;
    }
    const atualizado = { ...j, saldo: novoSaldo };
    return verificarFalencia(verificarFundoEmergencia(atualizado));
  });
}

function verificarVitoria(jogadores, turnoAtual) {
  const j1 = jogadores[0];
  const j2 = jogadores[1];

  if (j1.falido && !j2.falido) return { vencedor: 2, motivo: 'Vitoria por Eliminacao!' };
  if (j2.falido && !j1.falido) return { vencedor: 1, motivo: 'Vitoria por Eliminacao!' };
  if (j1.falido && j2.falido) return { vencedor: 0, motivo: 'Empate: Ambos faliram!' };

  if (turnoAtual > MAX_TURNOS) {
    if (j1.saldo > j2.saldo) return { vencedor: 1, motivo: 'Vitoria por Tempo: Maior saldo!' };
    if (j2.saldo > j1.saldo) return { vencedor: 2, motivo: 'Vitoria por Tempo: Maior saldo!' };
    return { vencedor: 0, motivo: 'Empate: Saldo identico!' };
  }

  return null;
}

export function criarEstadoInicial() {
  const baralhoEmbaralhado = embaralharBaralho(gerarBaralhoCompleto());

  const jogadorLocal = criarJogador(1, 'JOGADOR_HUMANO', false);
  const oponenteIA = criarJogador(2, 'OPONENTE_IA', true);

  const resultadoCompra1 = comprarCartaBaralho(baralhoEmbaralhado, jogadorLocal.mao, CARTAS_POR_MAO);
  const resultadoCompra2 = comprarCartaBaralho(resultadoCompra1.baralho, oponenteIA.mao, CARTAS_POR_MAO);

  const primeiroJogador = Math.random() < 0.5 ? 0 : 1;

  return {
    turnoAtual: 1,
    maxTurnos: MAX_TURNOS,
    jogadorAtivoIndex: primeiroJogador,
    direcaoTurno: 1,
    baralho: resultadoCompra2.baralho,
    pilhaDescarte: [],
    jogadores: [
      { ...jogadorLocal, mao: resultadoCompra1.mao },
      { ...oponenteIA, mao: resultadoCompra2.mao },
    ],
    fimDeJogo: null,
    log: [],
    batalhaIniciada: false,
  };
}

// IMPORTANTE: aceita `primeiroJogadorIndex` para que host e cliente
// concordem em quem começa. Sem isso, cada lado sorteava independente
// e o jogo dessincronizava na primeira jogada.
//  - 0 = host
//  - 1 = cliente
// Se não vier (ou vier inválido), cai no sorteio aleatório (fallback
// seguro para modos offline / testes).
export function criarEstadoMultiplayer(nomeJogador1, nomeJogador2, primeiroJogadorIndex, avatar1, avatar2) {
  const baralhoEmbaralhado = embaralharBaralho(gerarBaralhoCompleto());

  const jogador1 = criarJogador(1, nomeJogador1, false, avatar1);
  const jogador2 = criarJogador(2, nomeJogador2, false, avatar2);

  const resultadoCompra1 = comprarCartaBaralho(baralhoEmbaralhado, jogador1.mao, CARTAS_POR_MAO);
  const resultadoCompra2 = comprarCartaBaralho(resultadoCompra1.baralho, jogador2.mao, CARTAS_POR_MAO);

  const primeiroJogador =
    (primeiroJogadorIndex === 0 || primeiroJogadorIndex === 1)
      ? primeiroJogadorIndex
      : (Math.random() < 0.5 ? 0 : 1);

  return {
    turnoAtual: 1,
    maxTurnos: MAX_TURNOS,
    jogadorAtivoIndex: primeiroJogador,
    direcaoTurno: 1,
    baralho: resultadoCompra2.baralho,
    pilhaDescarte: [],
    jogadores: [
      { ...jogador1, mao: resultadoCompra1.mao },
      { ...jogador2, mao: resultadoCompra2.mao },
    ],
    fimDeJogo: null,
    log: [],
    batalhaIniciada: false,
    isMultiplayer: true,
  };
}

export function jogarCartaSemComprar(estado, jogadorId, cartaUid, jogadorAlvoId) {
  const novoEstado = { ...estado };
  const idxJogador = novoEstado.jogadores.findIndex((j) => j.id === jogadorId);
  if (idxJogador === -1) return novoEstado;

  const jogador = { ...novoEstado.jogadores[idxJogador] };
  const idxCarta = jogador.mao.findIndex((c) => c.uid === cartaUid);
  if (idxCarta === -1) return novoEstado;

  const carta = jogador.mao[idxCarta];
  const novaMao = [...jogador.mao];
  novaMao.splice(idxCarta, 1);
  jogador.mao = novaMao;

  const novaPilhaDescarte = [...novoEstado.pilhaDescarte, carta];
  const novosJogadores = [...novoEstado.jogadores];

  if (carta.tipo === TIPO_CARTA.PROTECAO) {
    jogador.protegido = true;
    novosJogadores[idxJogador] = jogador;
    return {
      ...novoEstado,
      jogadores: novosJogadores,
      pilhaDescarte: novaPilhaDescarte,
      log: [...novoEstado.log, `${jogador.nome} ativou protecao: ${carta.titulo}`],
    };
  }

  const sucesso = Math.random() < carta.chanceSucesso;
  let alteracao = 0;
  let logEntrada = '';

  const idxAlvo = jogadorAlvoId
    ? novosJogadores.findIndex((j) => j.id === jogadorAlvoId)
    : idxJogador === 0
    ? 1
    : 0;

  if (sucesso) {
    alteracao = carta.alteracaoSaldoBase;
    logEntrada = `${jogador.nome} jogou ${carta.titulo} com SUCESSO! (${carta.alteracaoSaldoBase > 0 ? '+' : ''}${carta.alteracaoSaldoBase})`;
  } else {
    alteracao = carta.alteracaoSaldoFalha;
    logEntrada = `${jogador.nome} jogou ${carta.titulo} e FALHOU! (${carta.alteracaoSaldoFalha > 0 ? '+' : ''}${carta.alteracaoSaldoFalha})`;
  }

  if (carta.precisaAlvo && idxAlvo !== idxJogador) {
    const alvo = { ...novosJogadores[idxAlvo] };
    if (alvo.protegido) {
      alvo.protegido = false;
      logEntrada += ` (Alvo protegido! Sem efeito)`;
      alteracao = 0;
    } else {
      alvo.saldo += alteracao;
      novosJogadores[idxAlvo] = verificarFalencia(verificarFundoEmergencia(alvo));
    }
  } else {
    if (jogador.protegido && alteracao < 0) {
      jogador.protegido = false;
      logEntrada += ` (Protegido! Sem perda)`;
      alteracao = 0;
    } else {
      jogador.saldo += alteracao;
    }
  }

  novosJogadores[idxJogador] = verificarFalencia(verificarFundoEmergencia(jogador));

  return {
    ...novoEstado,
    jogadores: novosJogadores,
    pilhaDescarte: novaPilhaDescarte,
    log: [...novoEstado.log, logEntrada],
  };
}

export function comprarCartaJogador(estado, jogadorId) {
  const novoEstado = { ...estado };
  const idxJogador = novoEstado.jogadores.findIndex((j) => j.id === jogadorId);
  if (idxJogador === -1) return novoEstado;

  const jogador = { ...novoEstado.jogadores[idxJogador] };
  const resultado = comprarCartaBaralho(novoEstado.baralho, jogador.mao, 1);
  jogador.mao = resultado.mao;
  novoEstado.baralho = resultado.baralho;

  const novosJogadores = [...novoEstado.jogadores];
  novosJogadores[idxJogador] = jogador;

  return {
    ...novoEstado,
    jogadores: novosJogadores,
  };
}

export function jogarCarta(estado, jogadorId, cartaUid, jogadorAlvoId) {
  const novoEstado = { ...estado };
  const idxJogador = novoEstado.jogadores.findIndex((j) => j.id === jogadorId);
  if (idxJogador === -1) return novoEstado;

  const jogador = { ...novoEstado.jogadores[idxJogador] };
  const idxCarta = jogador.mao.findIndex((c) => c.uid === cartaUid);
  if (idxCarta === -1) return novoEstado;

  const carta = jogador.mao[idxCarta];
  const novaMao = [...jogador.mao];
  novaMao.splice(idxCarta, 1);
  jogador.mao = novaMao;

  const novaPilhaDescarte = [...novoEstado.pilhaDescarte, carta];
  const novosJogadores = [...novoEstado.jogadores];

  if (carta.tipo === TIPO_CARTA.PROTECAO) {
    jogador.protegido = true;
    novosJogadores[idxJogador] = jogador;
    const logEntrada = `${jogador.nome} ativou protecao: ${carta.titulo}`;

    const resultadoCompraProt = comprarCartaBaralho(novoEstado.baralho, jogador.mao, 1);
    jogador.mao = resultadoCompraProt.mao;
    novoEstado.baralho = resultadoCompraProt.baralho;

    return {
      ...novoEstado,
      jogadores: novosJogadores,
      pilhaDescarte: novaPilhaDescarte,
      log: [...novoEstado.log, logEntrada],
    };
  }

  const sucesso = Math.random() < carta.chanceSucesso;
  let alteracao = 0;
  let logEntrada = '';

  const idxAlvo = jogadorAlvoId
    ? novosJogadores.findIndex((j) => j.id === jogadorAlvoId)
    : idxJogador === 0
    ? 1
    : 0;

  if (sucesso) {
    alteracao = carta.alteracaoSaldoBase;
    logEntrada = `${jogador.nome} jogou ${carta.titulo} com SUCESSO! (${carta.alteracaoSaldoBase > 0 ? '+' : ''}${carta.alteracaoSaldoBase})`;
  } else {
    alteracao = carta.alteracaoSaldoFalha;
    logEntrada = `${jogador.nome} jogou ${carta.titulo} e FALHOU! (${carta.alteracaoSaldoFalha > 0 ? '+' : ''}${carta.alteracaoSaldoFalha})`;
  }

  if (carta.precisaAlvo && idxAlvo !== idxJogador) {
    const alvo = { ...novosJogadores[idxAlvo] };
    if (alvo.protegido) {
      alvo.protegido = false;
      logEntrada += ` (Alvo protegido! Sem efeito)`;
      alteracao = 0;
    } else {
      alvo.saldo += alteracao;
      novosJogadores[idxAlvo] = verificarFalencia(verificarFundoEmergencia(alvo));
    }
  } else {
    if (jogador.protegido && alteracao < 0) {
      jogador.protegido = false;
      logEntrada += ` (Protegido! Sem perda)`;
      alteracao = 0;
    } else {
      jogador.saldo += alteracao;
    }
  }

  novosJogadores[idxJogador] = verificarFalencia(verificarFundoEmergencia(jogador));

  const resultadoCompra = comprarCartaBaralho(novoEstado.baralho, jogador.mao, 1);
  jogador.mao = resultadoCompra.mao;
  novoEstado.baralho = resultadoCompra.baralho;

  return {
    ...novoEstado,
    jogadores: novosJogadores,
    pilhaDescarte: novaPilhaDescarte,
    log: [...novoEstado.log, logEntrada],
  };
}

export function fimDeTurno(estado) {
  let novoEstado = { ...estado };
  const numJogadores = novoEstado.jogadores.length;
  const idxJogador = novoEstado.jogadorAtivoIndex;
  const jogador = { ...novoEstado.jogadores[idxJogador] };

  const resultadoCompra = comprarCartaBaralho(novoEstado.baralho, jogador.mao, 1);
  jogador.mao = resultadoCompra.mao;
  novoEstado.baralho = resultadoCompra.baralho;

  const novosJogadores = [...novoEstado.jogadores];
  novosJogadores[idxJogador] = jogador;
  novoEstado.jogadores = novosJogadores;

  novoEstado.jogadores = aplicarEventoDeusMercado(novoEstado.jogadores);

  const logEvento = 'Deus Mercado envia um evento aleatorio...';
  novoEstado.log = [...novoEstado.log, logEvento];

  // Avanca para o proximo jogador nao-falido (funciona para 2..N jogadores).
  let proximoIdx;
  let tentativas = 0;
  do {
    if (novoEstado.direcaoTurno === 1) {
      proximoIdx = (idxJogador + 1) % numJogadores;
    } else {
      proximoIdx = (idxJogador - 1 + numJogadores) % numJogadores;
    }
    tentativas++;
  } while (novoEstado.jogadores[proximoIdx].falido && tentativas < numJogadores);

  novoEstado.jogadorAtivoIndex = proximoIdx;

  // Conta um "turno completo" sempre que voltamos ao indice 0.
  if (proximoIdx === 0) {
    novoEstado.turnoAtual += 1;
  }

  const vitoria = verificarVitoria(novoEstado.jogadores, novoEstado.turnoAtual);
  if (vitoria) {
    novoEstado.fimDeJogo = vitoria;
  }

  return novoEstado;
}

export function descartarCarta(estado, jogadorId, cartaUid) {
  const novoEstado = { ...estado };
  const idxJogador = novoEstado.jogadores.findIndex((j) => j.id === jogadorId);
  if (idxJogador === -1) return novoEstado;

  const jogador = { ...novoEstado.jogadores[idxJogador] };
  const idxCarta = jogador.mao.findIndex((c) => c.uid === cartaUid);
  if (idxCarta === -1) return novoEstado;

  const carta = jogador.mao[idxCarta];
  const novaMao = [...jogador.mao];
  novaMao.splice(idxCarta, 1);
  jogador.mao = novaMao;

  const novosJogadores = [...novoEstado.jogadores];
  novosJogadores[idxJogador] = jogador;

  return {
    ...novoEstado,
    jogadores: novosJogadores,
    pilhaDescarte: [...novoEstado.pilhaDescarte, carta],
    log: [...novoEstado.log, `${jogador.nome} descartou ${carta.titulo}`],
  };
}

// ============================================================
// FUNCOES MULTIPLAYER N JOGADORES (2-8)
// ============================================================

const PLAYER_COLORS_N = ['#FFD54F', '#EF5350', '#42A5F5', '#66BB6A', '#AB47BC', '#FF7043', '#26C6DA', '#EC407A'];
const PLAYER_EMOJIS_N = ['👑', '🤖', '🦊', '🐉', '🎭', '🦁', '🌙', '⚡'];

function criarJogadorN(id, nome, isIA, avatar) {
  return {
    id,
    nome,
    isIA,
    avatar: avatar ?? null,   // <- novo
    saldo: SALDO_INICIAL,
    usouFundoEmergencia: false,
    mao: [],
    falido: false,
    protegido: false,
    cor: PLAYER_COLORS_N[id - 1] || '#FFF',
    emoji: PLAYER_EMOJIS_N[id - 1] || '❓',
  };
}

function verificarVitoriaN(jogadores, turnoAtual) {
  const vivos = jogadores.filter((j) => !j.falido);

  if (vivos.length === 0) {
    return { vencedor: 0, motivo: 'Empate: Todos faliram!' };
  }
  if (vivos.length === 1) {
    return { vencedor: vivos[0].id, motivo: 'Vitoria por Eliminacao!' };
  }

  if (turnoAtual > MAX_TURNOS) {
    const ordenados = [...vivos].sort((a, b) => b.saldo - a.saldo);
    if (ordenados.length >= 2 && ordenados[0].saldo === ordenados[1].saldo) {
      const empatados = ordenados.filter((j) => j.saldo === ordenados[0].saldo);
      if (empatados.length > 1) {
        return { vencedor: 0, motivo: `Empate: ${empatados.length} jogadores com mesmo saldo!` };
      }
    }
    return { vencedor: ordenados[0].id, motivo: 'Vitoria por Tempo: Maior saldo!' };
  }

  return null;
}

function encontrarAlvoAleatorio(jogadores, idxJogador) {
  const vivos = jogadores
    .map((j, i) => ({ ...j, idx: i }))
    .filter((j) => !j.falido && j.idx !== idxJogador);
  if (vivos.length === 0) return idxJogador;
  const alvo = vivos[Math.floor(Math.random() * vivos.length)];
  return alvo.idx;
}

export function criarEstadoMultiplayerN(nomesJogadores, avatarsJogadores = []) {
  const numJogadores = nomesJogadores.length;
  const baralhoEmbaralhado = embaralharBaralho(gerarBaralhoCompleto());

  let baralhoAtual = baralhoEmbaralhado;
  const jogadores = nomesJogadores.map((nome, i) => {
    const avatar = avatarsJogadores?.[i] ?? null;
    const j = criarJogadorN(i + 1, nome, i > 0, avatar);
    const resultado = comprarCartaBaralho(baralhoAtual, j.mao, CARTAS_POR_MAO);
    baralhoAtual = resultado.baralho;
    return { ...j, mao: resultado.mao };
  });

  const primeiroJogador = Math.floor(Math.random() * numJogadores);
  const direcaoTurno = numJogadores >= 3 ? (Math.random() < 0.5 ? 1 : -1) : 1;

  return {
    turnoAtual: 1,
    maxTurnos: MAX_TURNOS,
    jogadorAtivoIndex: primeiroJogador,
    direcaoTurno,
    baralho: baralhoAtual,
    pilhaDescarte: [],
    jogadores,
    fimDeJogo: null,
    log: [],
    batalhaIniciada: false,
    isMultiplayer: true,
    numJogadores,
  };
}

export function jogarCartaN(estado, jogadorIdx, cartaUid, alvoIdx) {
  const novoEstado = { ...estado };
  if (jogadorIdx < 0 || jogadorIdx >= novoEstado.jogadores.length) return novoEstado;

  const jogador = { ...novoEstado.jogadores[jogadorIdx] };
  const idxCarta = jogador.mao.findIndex((c) => c.uid === cartaUid);
  if (idxCarta === -1) return novoEstado;

  const carta = jogador.mao[idxCarta];
  const novaMao = [...jogador.mao];
  novaMao.splice(idxCarta, 1);
  jogador.mao = novaMao;

  const novaPilhaDescarte = [...novoEstado.pilhaDescarte, carta];
  const novosJogadores = [...novoEstado.jogadores];

  if (carta.tipo === TIPO_CARTA.PROTECAO) {
    jogador.protegido = true;
    novosJogadores[jogadorIdx] = jogador;
    const logEntrada = `${jogador.nome} ativou protecao: ${carta.titulo}`;

    const resultadoCompraProt = comprarCartaBaralho(novoEstado.baralho, jogador.mao, 1);
    jogador.mao = resultadoCompraProt.mao;
    novoEstado.baralho = resultadoCompraProt.baralho;
    novosJogadores[jogadorIdx] = jogador;

    return {
      ...novoEstado,
      jogadores: novosJogadores,
      pilhaDescarte: novaPilhaDescarte,
      log: [...novoEstado.log, logEntrada],
    };
  }

  const sucesso = Math.random() < carta.chanceSucesso;
  let alteracao = 0;
  let logEntrada = '';

  let idxAlvo;
  if (carta.precisaAlvo) {
    if (alvoIdx !== undefined && alvoIdx !== null && alvoIdx >= 0 && !novosJogadores[alvoIdx]?.falido && alvoIdx !== jogadorIdx) {
      idxAlvo = alvoIdx;
    } else {
      idxAlvo = encontrarAlvoAleatorio(novosJogadores, jogadorIdx);
    }
  }

  if (sucesso) {
    alteracao = carta.alteracaoSaldoBase;
    logEntrada = `${jogador.nome} jogou ${carta.titulo} com SUCESSO! (${carta.alteracaoSaldoBase > 0 ? '+' : ''}${carta.alteracaoSaldoBase})`;
  } else {
    alteracao = carta.alteracaoSaldoFalha;
    logEntrada = `${jogador.nome} jogou ${carta.titulo} e FALHOU! (${carta.alteracaoSaldoFalha > 0 ? '+' : ''}${carta.alteracaoSaldoFalha})`;
  }

  if (carta.precisaAlvo && idxAlvo !== undefined && idxAlvo !== jogadorIdx) {
    const alvo = { ...novosJogadores[idxAlvo] };
    if (alvo.protegido) {
      alvo.protegido = false;
      logEntrada += ` (${alvo.nome} protegido! Sem efeito)`;
      alteracao = 0;
    } else {
      alvo.saldo += alteracao;
      novosJogadores[idxAlvo] = verificarFalencia(verificarFundoEmergencia(alvo));
      logEntrada += ` (Alvo: ${alvo.nome})`;
    }
  } else {
    if (jogador.protegido && alteracao < 0) {
      jogador.protegido = false;
      logEntrada += ` (Protegido! Sem perda)`;
      alteracao = 0;
    } else {
      jogador.saldo += alteracao;
    }
  }

  novosJogadores[jogadorIdx] = verificarFalencia(verificarFundoEmergencia(jogador));

  const resultadoCompra = comprarCartaBaralho(novoEstado.baralho, jogador.mao, 1);
  novosJogadores[jogadorIdx].mao = resultadoCompra.mao;
  novoEstado.baralho = resultadoCompra.baralho;

  return {
    ...novoEstado,
    jogadores: novosJogadores,
    pilhaDescarte: novaPilhaDescarte,
    log: [...novoEstado.log, logEntrada],
  };
}

export function fimDeTurnoN(estado) {
  let novoEstado = { ...estado };
  const numJogadores = novoEstado.jogadores.length;
  const idxJogador = novoEstado.jogadorAtivoIndex;

  const jogador = { ...novoEstado.jogadores[idxJogador] };
  const resultadoCompra = comprarCartaBaralho(novoEstado.baralho, jogador.mao, 1);
  jogador.mao = resultadoCompra.mao;
  novoEstado.baralho = resultadoCompra.baralho;

  const novosJogadores = [...novoEstado.jogadores];
  novosJogadores[idxJogador] = jogador;
  novoEstado.jogadores = novosJogadores;

  novoEstado.jogadores = aplicarEventoDeusMercado(novoEstado.jogadores);

  let proximoIdx;
  let tentativas = 0;
  do {
    if (novoEstado.direcaoTurno === 1) {
      proximoIdx = (idxJogador + 1) % numJogadores;
    } else {
      proximoIdx = (idxJogador - 1 + numJogadores) % numJogadores;
    }
    tentativas++;
  } while (novoEstado.jogadores[proximoIdx].falido && tentativas < numJogadores);

  novoEstado.jogadorAtivoIndex = proximoIdx;

  if (proximoIdx === 0) {
    novoEstado.turnoAtual += 1;
  }

  const vitoria = verificarVitoriaN(novoEstado.jogadores, novoEstado.turnoAtual);
  if (vitoria) {
    novoEstado.fimDeJogo = vitoria;
  }

  return novoEstado;
}

export function descartarCartaN(estado, jogadorIdx, cartaUid) {
  const novoEstado = { ...estado };
  if (jogadorIdx < 0 || jogadorIdx >= novoEstado.jogadores.length) return novoEstado;

  const jogador = { ...novoEstado.jogadores[jogadorIdx] };
  const idxCarta = jogador.mao.findIndex((c) => c.uid === cartaUid);
  if (idxCarta === -1) return novoEstado;

  const carta = jogador.mao[idxCarta];
  const novaMao = [...jogador.mao];
  novaMao.splice(idxCarta, 1);
  jogador.mao = novaMao;

  const novosJogadores = [...novoEstado.jogadores];
  novosJogadores[jogadorIdx] = jogador;

  return {
    ...novoEstado,
    jogadores: novosJogadores,
    pilhaDescarte: [...novoEstado.pilhaDescarte, carta],
    log: [...novoEstado.log, `${jogador.nome} descartou ${carta.titulo}`],
  };
}

// Versão N-jogadores de jogarCartaN que NÃO compra uma carta ao jogar.
// Usada pelo fluxo "jogar N cartas + passar turno", onde a compra é
// responsabilidade do fimDeTurnoN (1 carta por turno, no final).
export function jogarCartaSemComprarN(estado, jogadorIdx, cartaUid, alvoIdx) {
  const novoEstado = { ...estado };
  if (jogadorIdx < 0 || jogadorIdx >= novoEstado.jogadores.length) return novoEstado;

  const jogador = { ...novoEstado.jogadores[jogadorIdx] };
  const idxCarta = jogador.mao.findIndex((c) => c.uid === cartaUid);
  if (idxCarta === -1) return novoEstado;

  const carta = jogador.mao[idxCarta];
  const novaMao = [...jogador.mao];
  novaMao.splice(idxCarta, 1);
  jogador.mao = novaMao;

  const novaPilhaDescarte = [...novoEstado.pilhaDescarte, carta];
  const novosJogadores = [...novoEstado.jogadores];

  if (carta.tipo === TIPO_CARTA.PROTECAO) {
    jogador.protegido = true;
    novosJogadores[jogadorIdx] = jogador;
    return {
      ...novoEstado,
      jogadores: novosJogadores,
      pilhaDescarte: novaPilhaDescarte,
      log: [...novoEstado.log, `${jogador.nome} ativou protecao: ${carta.titulo}`],
    };
  }

  const sucesso = Math.random() < carta.chanceSucesso;
  let alteracao = 0;
  let logEntrada = '';

  let idxAlvo;
  if (carta.precisaAlvo) {
    if (alvoIdx !== undefined && alvoIdx !== null && alvoIdx >= 0 && !novosJogadores[alvoIdx]?.falido && alvoIdx !== jogadorIdx) {
      idxAlvo = alvoIdx;
    } else {
      idxAlvo = encontrarAlvoAleatorio(novosJogadores, jogadorIdx);
    }
  }

  if (sucesso) {
    alteracao = carta.alteracaoSaldoBase;
    logEntrada = `${jogador.nome} jogou ${carta.titulo} com SUCESSO! (${carta.alteracaoSaldoBase > 0 ? '+' : ''}${carta.alteracaoSaldoBase})`;
  } else {
    alteracao = carta.alteracaoSaldoFalha;
    logEntrada = `${jogador.nome} jogou ${carta.titulo} e FALHOU! (${carta.alteracaoSaldoFalha > 0 ? '+' : ''}${carta.alteracaoSaldoFalha})`;
  }

  if (carta.precisaAlvo && idxAlvo !== undefined && idxAlvo !== jogadorIdx) {
    const alvo = { ...novosJogadores[idxAlvo] };
    if (alvo.protegido) {
      alvo.protegido = false;
      logEntrada += ` (${alvo.nome} protegido! Sem efeito)`;
      alteracao = 0;
    } else {
      alvo.saldo += alteracao;
      novosJogadores[idxAlvo] = verificarFalencia(verificarFundoEmergencia(alvo));
      logEntrada += ` (Alvo: ${alvo.nome})`;
    }
  } else {
    if (jogador.protegido && alteracao < 0) {
      jogador.protegido = false;
      logEntrada += ` (Protegido! Sem perda)`;
      alteracao = 0;
    } else {
      jogador.saldo += alteracao;
    }
  }

  novosJogadores[jogadorIdx] = verificarFalencia(verificarFundoEmergencia(jogador));

  return {
    ...novoEstado,
    jogadores: novosJogadores,
    pilhaDescarte: novaPilhaDescarte,
    log: [...novoEstado.log, logEntrada],
  };
}