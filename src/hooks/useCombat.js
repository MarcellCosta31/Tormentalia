import {
  gerarBaralhoCompleto,
  embaralharBaralho,
  comprarCarta as comprarCartaBaralho,
} from '../cards/baralhoCartas';
import {
  executarCarta,
  processarInicioTurno,
  aplicarSaldo,
  SALDO_INICIAL,
} from '../cards/motorEfeitos';

const MAX_TURNOS = 10;
const CARTAS_POR_MAO = 7;

function criarJogador(id, nome, isIA, avatar) {
  return {
    id,
    nome,
    isIA,
    avatar: avatar ?? null,
    saldo: SALDO_INICIAL,
    usouFundoEmergencia: false,
    mao: [],
    areaSegura: [],
    falido: false,
    protegido: false,
    protegeContra: null,
    efeitos: [],
  };
}

// Eventos do Deus Mercado (escala 1000, equivalentes a +2/-2/+1/-3 no
// jogo original de saldo 20).
function aplicarEventoDeusMercado(jogadores) {
  const deltas = [20, -20, 10, -30];
  const delta = deltas[Math.floor(Math.random() * deltas.length)];
  return jogadores.map((j) => (j.falido ? j : aplicarSaldo(j, delta)));
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

// ============================================================
// NUCLEO DE JOGADA (compartilhado por todas as variantes)
// ============================================================

function removerCarta(estado, idxJogador, cartaUid, fonte) {
  const jogador = { ...estado.jogadores[idxJogador] };
  const lista = fonte === 'areaSegura' ? [...jogador.areaSegura] : [...jogador.mao];
  const idx = lista.findIndex((c) => c.uid === cartaUid);
  if (idx === -1) return null;

  const carta = lista[idx];
  lista.splice(idx, 1);

  const atualizado =
    fonte === 'areaSegura'
      ? { ...jogador, areaSegura: lista }
      : { ...jogador, mao: lista };

  const jogadores = [...estado.jogadores];
  jogadores[idxJogador] = atualizado;

  return {
    estado: { ...estado, jogadores, pilhaDescarte: [...estado.pilhaDescarte, carta] },
    carta,
  };
}

function comprarPara(estado, idxJogador, quantidade) {
  const jogador = { ...estado.jogadores[idxJogador] };
  const resultado = comprarCartaBaralho(estado.baralho, jogador.mao, quantidade);
  const jogadores = [...estado.jogadores];
  jogadores[idxJogador] = { ...jogador, mao: resultado.mao };
  return { ...estado, jogadores, baralho: resultado.baralho };
}

function jogarInterno(
  estado,
  { idxJogador, cartaUid, idxAlvo, fonte = 'mao', comprar = 0, origem = '', roubarUids = null }
) {
  if (idxJogador < 0 || idxJogador >= estado.jogadores.length) return estado;

  const preparado = removerCarta(estado, idxJogador, cartaUid, fonte);
  if (!preparado) return estado;

  const { estado: posRemocao, carta } = preparado;
  const { estado: posExecucao, logEntrada, resultado } = executarCarta(posRemocao, {
    idxJogador,
    idxAlvo,
    carta,
    origem,
    roubarUids,
  });

  let novo = { ...posExecucao, log: [...posExecucao.log, logEntrada] };
  // Registra o resultado (sucesso/falha) para a UI do zoom. Mantem so as
  // ultimas 12 entradas; o seq monotonic evita reexibir em re-sync do MP.
  if (resultado) {
    const anteriores = novo.ultimasJogadas || [];
    const ultimoSeq = anteriores.length ? anteriores[anteriores.length - 1].seq : 0;
    novo = {
      ...novo,
      ultimasJogadas: [...anteriores, { seq: ultimoSeq + 1, ...resultado }].slice(-12),
    };
  }
  if (comprar > 0) novo = comprarPara(novo, idxJogador, comprar);
  return novo;
}

function idxAlvoOposto(idxJogador) {
  return idxJogador === 0 ? 1 : 0;
}

function encontrarAlvoAleatorio(jogadores, idxJogador) {
  const vivos = jogadores
    .map((j, i) => ({ ...j, idx: i }))
    .filter((j) => !j.falido && j.idx !== idxJogador);
  if (vivos.length === 0) return idxJogador;
  return vivos[Math.floor(Math.random() * vivos.length)].idx;
}

function resolverAlvoN(jogadores, idxJogador, alvoIdx, precisaAlvo) {
  if (!precisaAlvo) return undefined;
  if (
    alvoIdx !== undefined &&
    alvoIdx !== null &&
    alvoIdx >= 0 &&
    !jogadores[alvoIdx]?.falido &&
    alvoIdx !== idxJogador
  ) {
    return alvoIdx;
  }
  return encontrarAlvoAleatorio(jogadores, idxJogador);
}

function resolverAlvo1v1(jogadores, idxJogador, jogadorAlvoId, precisaAlvo) {
  if (!precisaAlvo) return undefined;
  if (jogadorAlvoId) {
    const idx = jogadores.findIndex((j) => j.id === jogadorAlvoId);
    if (idx !== -1) return idx;
  }
  return idxAlvoOposto(idxJogador);
}

// ============================================================
// ESTADO INICIAL
// ============================================================

export function criarEstadoInicial(nomeJogadorHumano) {
  const baralhoEmbaralhado = embaralharBaralho(gerarBaralhoCompleto());

  const jogadorLocal = criarJogador(1, nomeJogadorHumano || 'JOGADOR_1', false);
  const oponenteIA = criarJogador(2, 'Adam Smith', true);

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
    ultimasJogadas: [],
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
    ultimasJogadas: [],
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

// ============================================================
// 1v1 (joga + compra 1 carta)
// ============================================================

export function jogarCarta(estado, jogadorId, cartaUid, jogadorAlvoId, roubarUids = null) {
  const idxJogador = estado.jogadores.findIndex((j) => j.id === jogadorId);
  if (idxJogador === -1) return estado;

  const carta = estado.jogadores[idxJogador].mao.find((c) => c.uid === cartaUid);
  if (!carta) return estado;

  const idxAlvo = resolverAlvo1v1(
    estado.jogadores,
    idxJogador,
    jogadorAlvoId,
    carta.precisaAlvo
  );

  return jogarInterno(estado, { idxJogador, cartaUid, idxAlvo, comprar: 1, roubarUids });
}

// 1v1 sem comprar (a compra acontece no fim do turno).
export function jogarCartaSemComprar(
  estado,
  jogadorId,
  cartaUid,
  jogadorAlvoId,
  roubarUids = null
) {
  const idxJogador = estado.jogadores.findIndex((j) => j.id === jogadorId);
  if (idxJogador === -1) return estado;

  const carta = estado.jogadores[idxJogador].mao.find((c) => c.uid === cartaUid);
  if (!carta) return estado;

  const idxAlvo = resolverAlvo1v1(
    estado.jogadores,
    idxJogador,
    jogadorAlvoId,
    carta.precisaAlvo
  );

  return jogarInterno(estado, { idxJogador, cartaUid, idxAlvo, comprar: 0, roubarUids });
}

export function comprarCartaJogador(estado, jogadorId) {
  const idxJogador = estado.jogadores.findIndex((j) => j.id === jogadorId);
  if (idxJogador === -1) return estado;
  return comprarPara(estado, idxJogador, 1);
}

export function fimDeTurno(estado) {
  let novoEstado = { ...estado };
  const numJogadores = novoEstado.jogadores.length;
  const idxJogador = novoEstado.jogadorAtivoIndex;

  novoEstado = comprarPara(novoEstado, idxJogador, 1);
  novoEstado.jogadores = aplicarEventoDeusMercado(novoEstado.jogadores);

  novoEstado.log = [...novoEstado.log, 'Deus Mercado envia um evento aleatorio...'];

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

  // Tick dos efeitos ativos no inicio do turno de `proximoIdx`.
  novoEstado = processarInicioTurno(novoEstado, proximoIdx);

  const vitoria = verificarVitoria(novoEstado.jogadores, novoEstado.turnoAtual);
  if (vitoria) {
    novoEstado.fimDeJogo = vitoria;
  }

  return novoEstado;
}

export function descartarCarta(estado, jogadorId, cartaUid) {
  const idxJogador = estado.jogadores.findIndex((j) => j.id === jogadorId);
  if (idxJogador === -1) return estado;

  const jogador = { ...estado.jogadores[idxJogador] };
  const idxCarta = jogador.mao.findIndex((c) => c.uid === cartaUid);
  if (idxCarta === -1) return estado;

  const carta = jogador.mao[idxCarta];
  const novaMao = [...jogador.mao];
  novaMao.splice(idxCarta, 1);
  jogador.mao = novaMao;

  const novosJogadores = [...estado.jogadores];
  novosJogadores[idxJogador] = jogador;

  return {
    ...estado,
    jogadores: novosJogadores,
    pilhaDescarte: [...estado.pilhaDescarte, carta],
    log: [...estado.log, `${jogador.nome} descartou ${carta.titulo}`],
  };
}

// ============================================================
// MULTIPLAYER N JOGADORES (2-8)
// ============================================================

const PLAYER_COLORS_N = ['#FFD54F', '#EF5350', '#42A5F5', '#66BB6A', '#AB47BC', '#FF7043', '#26C6DA', '#EC407A'];
const PLAYER_EMOJIS_N = ['👑', '🤖', '🦊', '🐉', '🎭', '🦁', '🌙', '⚡'];

function criarJogadorN(id, nome, isIA, avatar) {
  return {
    ...criarJogador(id, nome, isIA, avatar),
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
    ultimasJogadas: [],
    jogadores,
    fimDeJogo: null,
    log: [],
    batalhaIniciada: false,
    isMultiplayer: true,
    numJogadores,
  };
}

export function jogarCartaN(estado, jogadorIdx, cartaUid, alvoIdx, roubarUids = null) {
  if (jogadorIdx < 0 || jogadorIdx >= estado.jogadores.length) return estado;

  const carta = estado.jogadores[jogadorIdx].mao.find((c) => c.uid === cartaUid);
  if (!carta) return estado;

  const idxAlvo = resolverAlvoN(estado.jogadores, jogadorIdx, alvoIdx, carta.precisaAlvo);

  return jogarInterno(estado, { idxJogador: jogadorIdx, cartaUid, idxAlvo, comprar: 1, roubarUids });
}

// Versao N que NAO compra carta ao jogar (a compra e do fimDeTurnoN).
export function jogarCartaSemComprarN(
  estado,
  jogadorIdx,
  cartaUid,
  alvoIdx,
  roubarUids = null
) {
  if (jogadorIdx < 0 || jogadorIdx >= estado.jogadores.length) return estado;

  const carta = estado.jogadores[jogadorIdx].mao.find((c) => c.uid === cartaUid);
  if (!carta) return estado;

  const idxAlvo = resolverAlvoN(estado.jogadores, jogadorIdx, alvoIdx, carta.precisaAlvo);

  return jogarInterno(estado, {
    idxJogador: jogadorIdx,
    cartaUid,
    idxAlvo,
    comprar: 0,
    roubarUids,
  });
}

export function fimDeTurnoN(estado) {
  let novoEstado = { ...estado };
  const numJogadores = novoEstado.jogadores.length;
  const idxJogador = novoEstado.jogadorAtivoIndex;

  novoEstado = comprarPara(novoEstado, idxJogador, 1);
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

  novoEstado = processarInicioTurno(novoEstado, proximoIdx);

  const vitoria = verificarVitoriaN(novoEstado.jogadores, novoEstado.turnoAtual);
  if (vitoria) {
    novoEstado.fimDeJogo = vitoria;
  }

  return novoEstado;
}

export function descartarCartaN(estado, jogadorIdx, cartaUid) {
  if (jogadorIdx < 0 || jogadorIdx >= estado.jogadores.length) return estado;

  const jogador = { ...estado.jogadores[jogadorIdx] };
  const idxCarta = jogador.mao.findIndex((c) => c.uid === cartaUid);
  if (idxCarta === -1) return estado;

  const carta = jogador.mao[idxCarta];
  const novaMao = [...jogador.mao];
  novaMao.splice(idxCarta, 1);
  jogador.mao = novaMao;

  const novosJogadores = [...estado.jogadores];
  novosJogadores[jogadorIdx] = jogador;

  return {
    ...estado,
    jogadores: novosJogadores,
    pilhaDescarte: [...estado.pilhaDescarte, carta],
    log: [...estado.log, `${jogador.nome} descartou ${carta.titulo}`],
  };
}

// =============================================
// AREA SEGURA - Versao 1v1 (usa jogadorId)
// =============================================

export function colocarCartaAreaSegura1v1(estado, jogadorId, cartaUid) {
  const idxJogador = estado.jogadores.findIndex((j) => j.id === jogadorId);
  if (idxJogador === -1) return estado;

  const jogador = { ...estado.jogadores[idxJogador] };
  if (jogador.areaSegura.length >= 1) return estado;
  const idxCarta = jogador.mao.findIndex((c) => c.uid === cartaUid);
  if (idxCarta === -1) return estado;

  const carta = jogador.mao[idxCarta];
  const novaMao = [...jogador.mao];
  novaMao.splice(idxCarta, 1);
  jogador.mao = novaMao;
  jogador.areaSegura = [...jogador.areaSegura, carta];

  const novosJogadores = [...estado.jogadores];
  novosJogadores[idxJogador] = jogador;

  return {
    ...estado,
    jogadores: novosJogadores,
    log: [...estado.log, `${jogador.nome} colocou ${carta.titulo} na Area Segura`],
  };
}

export function jogarCartaAreaSegura1v1(estado, jogadorId, cartaUid) {
  const idxJogador = estado.jogadores.findIndex((j) => j.id === jogadorId);
  if (idxJogador === -1) return estado;

  const carta = estado.jogadores[idxJogador].areaSegura.find((c) => c.uid === cartaUid);
  if (!carta) return estado;

  const idxAlvo = carta.precisaAlvo ? idxAlvoOposto(idxJogador) : undefined;

  return jogarInterno(estado, {
    idxJogador,
    cartaUid,
    idxAlvo,
    fonte: 'areaSegura',
    comprar: 0,
    origem: ' da Area Segura',
  });
}

// =============================================
// AREA SEGURA - Versao N jogadores
// =============================================

export function colocarCartaAreaSegura(estado, jogadorIdx, cartaUid) {
  if (jogadorIdx < 0 || jogadorIdx >= estado.jogadores.length) return estado;

  const jogador = { ...estado.jogadores[jogadorIdx] };
  if (jogador.areaSegura.length >= 1) return estado;
  const idxCarta = jogador.mao.findIndex((c) => c.uid === cartaUid);
  if (idxCarta === -1) return estado;

  const carta = jogador.mao[idxCarta];
  const novaMao = [...jogador.mao];
  novaMao.splice(idxCarta, 1);
  jogador.mao = novaMao;
  jogador.areaSegura = [...jogador.areaSegura, carta];

  const novosJogadores = [...estado.jogadores];
  novosJogadores[jogadorIdx] = jogador;

  return {
    ...estado,
    jogadores: novosJogadores,
    log: [...estado.log, `${jogador.nome} colocou ${carta.titulo} na Area Segura`],
  };
}

export function jogarCartaAreaSegura(estado, jogadorIdx, cartaUid) {
  if (jogadorIdx < 0 || jogadorIdx >= estado.jogadores.length) return estado;

  const carta = estado.jogadores[jogadorIdx].areaSegura.find((c) => c.uid === cartaUid);
  if (!carta) return estado;

  const idxAlvo = carta.precisaAlvo
    ? encontrarAlvoAleatorio(estado.jogadores, jogadorIdx)
    : undefined;

  return jogarInterno(estado, {
    idxJogador: jogadorIdx,
    cartaUid,
    idxAlvo,
    fonte: 'areaSegura',
    comprar: 0,
    origem: ' da Area Segura',
  });
}
