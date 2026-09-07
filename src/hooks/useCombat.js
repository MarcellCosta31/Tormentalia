import { gerarBaralhoCompleto, embaralharBaralho, comprarCarta as comprarCartaBaralho } from '../cards/baralhoCartas';
import { TIPO_CARTA } from '../cards/baralhoCartas';

const SALDO_INICIAL = 20;
const SALDO_EMERGENCIA = 5;
const MAX_TURNOS = 10;
const CARTAS_POR_MAO = 7;

function criarJogador(id, nome, isIA) {
  return {
    id,
    nome,
    isIA,
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

  if (j1.falido && !j2.falido) return { vencedor: 2, motivo: 'Vitoria por Eliminacao: O Oponente venceu!' };
  if (j2.falido && !j1.falido) return { vencedor: 1, motivo: 'Vitoria por Eliminacao: Voce venceu!' };
  if (j1.falido && j2.falido) return { vencedor: 0, motivo: 'Empate: Ambos faliram!' };

  if (turnoAtual > MAX_TURNOS) {
    if (j1.saldo > j2.saldo) return { vencedor: 1, motivo: 'Vitoria por Tempo: Voce tem o maior saldo!' };
    if (j2.saldo > j1.saldo) return { vencedor: 2, motivo: 'Vitoria por Tempo: O Oponente tem o maior saldo!' };
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

  return {
    turnoAtual: 1,
    maxTurnos: MAX_TURNOS,
    jogadorAtivoIndex: 0,
    direcaoTurno: 1,
    baralho: resultadoCompra2.baralho,
    pilhaDescarte: [],
    jogadores: [
      { ...jogadorLocal, mao: resultadoCompra1.mao },
      { ...oponenteIA, mao: resultadoCompra2.mao },
    ],
    fimDeJogo: null,
    log: [],
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

  const proximoIdx = (idxJogador + 1) % 2;
  novoEstado.jogadorAtivoIndex = proximoIdx;

  if (proximoIdx === 0) {
    novoEstado.turnoAtual += 1;
    novoEstado.direcaoTurno *= -1;
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
