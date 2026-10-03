import { embaralharBaralho } from './baralhoCartas';
import { TIPO_CARTA } from './cartasTGA';

// ============================================================
// CONSTANTES DE ECONOMIA
// ============================================================

// Escala da planilha (valores como +400/-400, +500, dividas de 150-300).
export const SALDO_INICIAL = 1000;
export const SALDO_EMERGENCIA = 250;

// ============================================================
// TEMPO DE TURNO
// ============================================================

// Cada jogador tem este tempo (segundos) para jogar em um turno normal.
// Se o tempo esgotar, a vez passa automaticamente.
export const TURNO_BASE_SEGUNDOS = 20;

// Duracao efetiva do turno de um jogador, considerando TEMPO_TURNO ativos:
//  - modo 'definir' (Sem tempo): valor absoluto (2s), ignora bonus;
//  - modo 'bonus' (Seiso): soma ao base (+2s => 22s).
export function duracaoTurno(jogador) {
  const efeitos = (jogador && jogador.efeitos) || [];
  const definidos = efeitos.filter((e) => e.tipo === 'TEMPO_TURNO' && e.modo === 'definir');
  if (definidos.length > 0) {
    const segundos = definidos.map((e) => e.segundos || TURNO_BASE_SEGUNDOS);
    return Math.max(1, Math.min(...segundos));
  }
  const bonus = efeitos
    .filter((e) => e.tipo === 'TEMPO_TURNO' && e.modo === 'bonus')
    .reduce((soma, e) => soma + (e.segundos || 0), 0);
  return Math.max(1, TURNO_BASE_SEGUNDOS + bonus);
}

// ============================================================
// SALDO / FALENCIA
// ============================================================

export function verificarFundoEmergencia(jogador) {
  if (jogador.saldo <= 0 && !jogador.usouFundoEmergencia) {
    return { ...jogador, saldo: SALDO_EMERGENCIA, usouFundoEmergencia: true };
  }
  return jogador;
}

export function verificarFalencia(jogador) {
  if (jogador.saldo <= 0 && jogador.usouFundoEmergencia) {
    return { ...jogador, falido: true };
  }
  return jogador;
}

// ============================================================
// CHANCE
// ============================================================

const CARTAS_NEGATIVAS = [
  'DIVIDA',
  'DOACAO_PERCENTUAL',
  'ROUBA_CARTAS',
  'DESCARTA_E_PUXA',
  'DINHEIRO_ALVO',
  'MAO_ALEATORIA',
];

export function ehCartaNegativa(carta) {
  if (carta.alteracaoSaldoBase < 0) return true;
  const tipo = carta.efeito?.tipo;
  return CARTAS_NEGATIVAS.includes(tipo);
}

// Chance efetiva da carta, aplicando os efeitos ativos de quem jogou
// (MOD_CHANCE, MOD_FALHA, CHANCE_FIXA). Consome os usos dos efeitos.
// `jogador` precisa ter `efeitos` clonado (mutavel).
export function calcularChance(carta, jogador) {
  let chance = carta.chanceSucesso;
  const atuais = jogador.efeitos || [];
  const restantes = [];

  for (const e of atuais) {
    if (e.tipo === 'MOD_CHANCE') {
      chance += e.valor;
      restantes.push(e);
      continue;
    }
    if (e.tipo === 'MOD_FALHA') {
      // Reduz a chance de FALHA (ex.: fator 0.6 = falha 40% menor).
      chance = 1 - (1 - chance) * e.fator;
      restantes.push(e);
      continue;
    }
    if (e.tipo === 'CHANCE_FIXA') {
      if (!e.soNegativa || ehCartaNegativa(carta)) {
        chance = e.valor;
        const usos = (e.usos || 1) - 1;
        if (usos > 0) restantes.push({ ...e, usos });
        continue;
      }
      restantes.push(e);
      continue;
    }
    restantes.push(e);
  }

  jogador.efeitos = restantes;
  return Math.max(0, Math.min(1, chance));
}

// ============================================================
// DINHEIRO
// ============================================================

// Flutuacao do mercado: ganhos viram um valor aleatorio (0..valor).
function valorComFlutuacao(jogador, valor) {
  if (valor <= 0) return valor;
  const temFlutuacao = (jogador.efeitos || []).some((e) => e.tipo === 'RENDA_ALEATORIA');
  if (!temFlutuacao) return valor;
  return Math.floor(Math.random() * (valor + 1));
}

export function aplicarSaldo(jogador, delta) {
  if (!delta) return jogador;
  const valor = delta > 0 ? valorComFlutuacao(jogador, delta) : delta;
  const atualizado = { ...jogador, saldo: jogador.saldo + valor };
  return verificarFalencia(verificarFundoEmergencia(atualizado));
}

// ============================================================
// EFEITOS ATIVOS
// ============================================================

// Efeitos cuja duracao e LIDA durante o turno (o motor/UI consultam a
// lista depois do tick do inicio do turno). Como o decremento acontece
// antes da leitura, guardamos 1 turno a mais para valer `turnos` turnos.
const EFEITOS_LIDOS_NO_TURNO = ['TEMPO_TURNO', 'MOD_CHANCE', 'MOD_FALHA', 'RENDA_ALEATORIA'];

export function adicionarEfeito(jogador, efeito, bonusTurnos = 0) {
  const e = { ...efeito };
  if (typeof e.turnos === 'number') {
    e.turnos += bonusTurnos;
    if (EFEITOS_LIDOS_NO_TURNO.includes(e.tipo)) e.turnos += 1;
  }
  jogador.efeitos = [...(jogador.efeitos || []), e];
}

// Shitsuke: consome 1 uso e devolve os turnos extras para somar aos
// efeitos de duracao da proxima carta de acao jogada.
export function consumirProlonga(jogador) {
  const efeitos = jogador.efeitos || [];
  const idx = efeitos.findIndex((e) => e.tipo === 'PROLONGA');
  if (idx === -1) return 0;
  const e = efeitos[idx];
  const usos = (e.usos || 1) - 1;
  const proximos = [...efeitos];
  if (usos > 0) proximos[idx] = { ...e, usos };
  else proximos.splice(idx, 1);
  jogador.efeitos = proximos;
  return e.turnosAdicionais || 0;
}

function bloqueadoPorProtecao(alvo, carta) {
  if (!alvo.protegido) return false;
  if (!alvo.protegeContra) return true;
  return alvo.protegeContra === carta.tipo;
}

function consumirProtecao(alvo) {
  return { ...alvo, protegido: false, protegeContra: null };
}

// ============================================================
// EXECUCAO DE UMA CARTA
// ============================================================

function clonarJogadores(jogadores) {
  return jogadores.map((j) => ({
    ...j,
    mao: [...j.mao],
    areaSegura: [...j.areaSegura],
    efeitos: [...(j.efeitos || [])],
  }));
}

function roubarCartas(jogadores, idxAlvo, idxJogador, quantidade, uidsEscolhidas) {
  const alvo = jogadores[idxAlvo];
  const maoAlvo = [...alvo.mao];
  const maoInvocador = [...jogadores[idxJogador].mao];
  let roubadas = 0;

  // Roubo respeita um teto um pouco acima do limite de compra (7): a mao
  // pode estourar em ate 2 cartas, mas nunca passar de 9.
  const escolhidas = (Array.isArray(uidsEscolhidas) ? uidsEscolhidas : []).filter(
    (uid, i, arr) => arr.indexOf(uid) === i
  );

  if (escolhidas.length > 0) {
    // Roubo as cegas: o jogador escolheu os uids sem ver as cartas.
    // So leva as que ainda estao na mao do alvo (validacao do host);
    // uid invalido nao consome a cota de `quantidade`.
    for (const uid of escolhidas) {
      if (roubadas >= quantidade) break;
      if (maoInvocador.length >= 9) break;
      const idx = maoAlvo.findIndex((c) => c.uid === uid);
      if (idx === -1) continue;
      maoInvocador.push(maoAlvo.splice(idx, 1)[0]);
      roubadas++;
    }
  } else {
    for (let i = 0; i < quantidade; i++) {
      if (maoAlvo.length === 0) break;
      if (maoInvocador.length >= 9) break;
      const de = Math.floor(Math.random() * maoAlvo.length);
      maoInvocador.push(maoAlvo.splice(de, 1)[0]);
      roubadas++;
    }
  }

  jogadores[idxAlvo] = { ...alvo, mao: maoAlvo };
  jogadores[idxJogador] = { ...jogadores[idxJogador], mao: maoInvocador };
  return roubadas;
}

function descartarEPuxar(jogadores, idx, baralho, pilhaDescarte, quantidade) {
  const jogador = jogadores[idx];
  const mao = [...jogador.mao];
  const novoBaralho = [...baralho];
  const novoDescarte = [...pilhaDescarte];
  let descartadas = 0;
  let puxadas = 0;

  for (let i = 0; i < quantidade; i++) {
    if (mao.length > 0) {
      const de = Math.floor(Math.random() * mao.length);
      novoDescarte.push(mao.splice(de, 1)[0]);
      descartadas++;
    }
    if (novoBaralho.length > 0 && mao.length < 7) {
      mao.push(novoBaralho.shift());
      puxadas++;
    }
  }

  jogadores[idx] = { ...jogador, mao };
  return { baralho: novoBaralho, pilhaDescarte: novoDescarte, descartadas, puxadas };
}

function devolverCartasParaBaralho(jogador, baralho, quantidade) {
  const mao = [...jogador.mao];
  const devolvidas = [];
  for (let i = 0; i < quantidade && mao.length > 0; i++) {
    devolvidas.push(mao.splice(Math.floor(Math.random() * mao.length), 1)[0]);
  }
  return {
    jogador: { ...jogador, mao },
    baralho: embaralharBaralho([...baralho, ...devolvidas]),
    devolvidas: devolvidas.length,
  };
}

// Executa a carta ja removida da mao/area segura e descartada pelo chamador.
// Retorna { estado, logEntrada }.
export function executarCarta(estado, { idxJogador, idxAlvo, carta, origem = '', roubarUids = null }) {
  const jogadores = clonarJogadores(estado.jogadores);
  const baralho = [...estado.baralho];
  const pilhaDescarte = [...estado.pilhaDescarte];
  const jogador = jogadores[idxJogador];
  const logExtras = [];

  if (carta.tipo === TIPO_CARTA.PROTECAO) {
    jogadores[idxJogador] = {
      ...jogador,
      protegido: true,
      protegeContra: carta.protegeContra || null,
    };
    return {
      estado: { ...estado, jogadores, baralho, pilhaDescarte },
      logEntrada: `${jogador.nome} ativou protecao${origem}: ${carta.titulo}`,
      resultado: {
        carta,
        sucesso: true,
        chance: typeof carta.chanceSucesso === 'number' ? carta.chanceSucesso : 1,
      },
    };
  }

  const temAlvo = carta.precisaAlvo && typeof idxAlvo === 'number' && idxAlvo !== idxJogador;

  const chance = calcularChance(carta, jogador);
  const sucesso = Math.random() < chance;
  jogadores[idxJogador] = jogador;

  // --- dinheiro base (sucesso/falha, ou valor aleatorio da divida) ---
  let delta = sucesso ? carta.alteracaoSaldoBase : carta.alteracaoSaldoFalha;
  if (carta.efeito?.tipo === 'DIVIDA' && sucesso) {
    const { min, max } = carta.efeito;
    delta = -(min + Math.floor(Math.random() * (max - min + 1)));
  }

  const dinheiroEm = carta.dinheiroEm || (carta.precisaAlvo ? 'alvo' : 'invocador');
  let bloqueado = false;

  if (dinheiroEm !== 'nenhum' && delta !== 0) {
    if (dinheiroEm === 'alvo' && temAlvo) {
      const alvo = jogadores[idxAlvo];
      if (bloqueadoPorProtecao(alvo, carta)) {
        bloqueado = true;
        logExtras.push(`(${alvo.nome} protegido! Sem efeito)`);
        jogadores[idxAlvo] = consumirProtecao(alvo);
      } else {
        jogadores[idxAlvo] = aplicarSaldo(alvo, delta);
        logExtras.push(`(${alvo.nome}: ${delta > 0 ? '+' : ''}${delta})`);
      }
    } else {
      const self = jogadores[idxJogador];
      if (self.protegido && delta < 0) {
        bloqueado = true;
        logExtras.push('(Protegido! Sem perda)');
        jogadores[idxJogador] = consumirProtecao(self);
      } else {
        jogadores[idxJogador] = aplicarSaldo(self, delta);
      }
    }
  }

  // --- efeito especial (somente em caso de sucesso) ---
  const efeito = carta.efeito;
  if (sucesso && efeito && !bloqueado) {
    let protegido = false;
    if (efeito.alvo === 'alvo' && temAlvo) {
      const alvoAtual = jogadores[idxAlvo];
      if (bloqueadoPorProtecao(alvoAtual, carta)) {
        protegido = true;
        logExtras.push(`(${alvoAtual.nome} protegido! Sem efeito)`);
        jogadores[idxAlvo] = consumirProtecao(alvoAtual);
      }
    }

    if (!protegido) {
      const bonusTurnos =
        carta.tipo === TIPO_CARTA.ACAO ? consumirProlonga(jogadores[idxJogador]) : 0;

      const alvosDoEfeito = () => {
        switch (efeito.alvo) {
          case 'invocador':
            return [idxJogador];
          case 'alvo':
            return temAlvo ? [idxAlvo] : [];
          case 'oponentes':
            return jogadores.map((_, i) => i).filter((i) => i !== idxJogador);
          case 'todos':
          default:
            return jogadores.map((_, i) => i);
        }
      };

      switch (efeito.tipo) {
        case 'DOACAO_PERCENTUAL': {
          const victima = jogadores[idxAlvo];
          const pct = Math.floor(Math.random() * 101);
          const doado = Math.round(Math.max(0, victima.saldo) * (pct / 100));
          jogadores[idxAlvo] = aplicarSaldo(victima, -doado);
          jogadores[idxJogador] = aplicarSaldo(jogadores[idxJogador], doado);
          logExtras.push(`doou ${pct}% (${doado})`);
          break;
        }
        case 'DINHEIRO_ALVO': {
          jogadores[idxJogador] = aplicarSaldo(
            jogadores[idxJogador],
            efeito.ganhoInvocador || 0
          );
          if (temAlvo) {
            jogadores[idxAlvo] = aplicarSaldo(jogadores[idxAlvo], -(efeito.perdaAlvo || 0));
            if (efeito.debuff) adicionarEfeito(jogadores[idxAlvo], efeito.debuff, bonusTurnos);
          }
          logExtras.push(`(+${efeito.ganhoInvocador || 0} / alvo -${efeito.perdaAlvo || 0})`);
          break;
        }
        case 'ROUBA_CARTAS': {
          const roubadas = roubarCartas(
            jogadores,
            idxAlvo,
            idxJogador,
            efeito.quantidade || 1,
            roubarUids
          );
          logExtras.push(
            Array.isArray(roubarUids) && roubadas > 0
              ? `roubou ${roubadas} carta(s) (as cegas)`
              : `roubou ${roubadas} carta(s)`
          );
          break;
        }
        case 'DESCARTA_E_PUXA': {
          const r = descartarEPuxar(
            jogadores,
            idxAlvo,
            baralho,
            pilhaDescarte,
            efeito.quantidade || 1
          );
          baralho.length = 0;
          baralho.push(...r.baralho);
          pilhaDescarte.length = 0;
          pilhaDescarte.push(...r.pilhaDescarte);
          logExtras.push(`descartou ${r.descartadas} e puxou ${r.puxadas}`);
          break;
        }
        case 'TROCA_MAO': {
          const r = devolverCartasParaBaralho(
            jogadores[idxJogador],
            baralho,
            efeito.quantidade || 3
          );
          jogadores[idxJogador] = r.jogador;
          baralho.length = 0;
          baralho.push(...r.baralho);
          adicionarEfeito(jogadores[idxJogador], { ...efeito, alvo: 'invocador' }, bonusTurnos);
          logExtras.push(`devolveu ${r.devolvidas} carta(s) ao baralho`);
          break;
        }
        case 'DIVIDA':
          // O dinheiro ja foi aplicado pelo caminho base.
          break;
        default: {
          alvosDoEfeito().forEach((i) => {
            adicionarEfeito(jogadores[i], efeito, bonusTurnos);
          });
          break;
        }
      }
    }
  }

  const situacao = sucesso ? 'com SUCESSO!' : 'e FALHOU!';
  const valor = dinheiroEm !== 'nenhum' && delta !== 0 ? ` (${delta > 0 ? '+' : ''}${delta})` : '';
  const extras = logExtras.length ? ` ${logExtras.join(' ')}` : '';
  const logEntrada = `${jogador.nome} jogou ${carta.titulo}${origem} ${situacao}${valor}${extras}`;

  return {
    estado: { ...estado, jogadores, baralho, pilhaDescarte },
    logEntrada,
    // Resultado estruturado para a UI mostrar SUCESSO/FALHA em zoom
    // (gravado em estado.ultimasJogadas por jogarInterno).
    resultado: { carta, sucesso, chance },
  };
}

// ============================================================
// INICIO DE TURNO (tick dos efeitos ativos)
// ============================================================

export function processarInicioTurno(estado, idx) {
  if (typeof idx !== 'number' || !estado.jogadores[idx]) return estado;

  const jogadores = clonarJogadores(estado.jogadores);
  const baralho = [...estado.baralho];
  const log = [];
  let jogador = jogadores[idx];
  const originais = jogador.efeitos;
  const restantes = [];

  for (const e of originais) {
    const atual = { ...e };

    if (e.tipo === 'DINHEIRO_ADIADO') {
      const antes = jogador.saldo;
      jogador = aplicarSaldo(jogador, e.valor || 0);
      log.push(`${jogador.nome} recebeu +${jogador.saldo - antes} (efeito adiado)`);
    } else if (e.tipo === 'DIVIDA_PARCELADA') {
      jogador = aplicarSaldo(jogador, -(e.valor || 0));
      log.push(`${jogador.nome} pagou ${e.valor} de emprestimo`);
    } else if (e.tipo === 'MAO_ALEATORIA') {
      const mao = [...jogador.mao];
      const trocadas = [];
      const qtd = e.quantidade || 3;
      for (let i = 0; i < qtd && mao.length > 0 && baralho.length > 0; i++) {
        const pos = Math.floor(Math.random() * mao.length);
        trocadas.push(mao[pos]);
        mao[pos] = baralho.shift();
      }
      baralho.push(...trocadas);
      for (let i = baralho.length - 1; i > 0; i--) {
        const j = Math.floor(Math.random() * (i + 1));
        [baralho[i], baralho[j]] = [baralho[j], baralho[i]];
      }
      jogador = { ...jogador, mao };
      log.push(`${jogador.nome} teve ${trocadas.length} carta(s) substituida(s) (Taylor)`);
    } else if (e.tipo === 'TROCA_MAO') {
      // Simplificacao: puxa `quantidade` cartas e fica com 1 aleatoria
      // (a versao original deixa o jogador escolher qual fica).
      const puxadas = [];
      const qtd = e.quantidade || 3;
      for (let i = 0; i < qtd && baralho.length > 0; i++) {
        puxadas.push(baralho.shift());
      }
      if (puxadas.length > 0) {
        const fica = puxadas.splice(Math.floor(Math.random() * puxadas.length), 1)[0];
        jogador = { ...jogador, mao: [...jogador.mao, fica].slice(0, 7) };
        baralho.push(...puxadas);
        for (let i = baralho.length - 1; i > 0; i--) {
          const j = Math.floor(Math.random() * (i + 1));
          [baralho[i], baralho[j]] = [baralho[j], baralho[i]];
        }
        log.push(`${jogador.nome} renovou a mao com Seiri (${puxadas.length + 1} cartas)`);
      }
    } else if (e.tipo === 'TEMPO_TURNO') {
      // Nao tem aplicacao aqui: a duracao do turno e lida pela UI via
      // duracaoTurno(jogador) quando o turno do jogador comeca.
    }

    if (typeof atual.turnos === 'number') {
      atual.turnos -= 1;
      if (atual.turnos > 0) restantes.push(atual);
    } else {
      restantes.push(atual);
    }
  }

  jogadores[idx] = { ...jogador, efeitos: restantes };

  const mudou =
    jogador.saldo !== estado.jogadores[idx].saldo ||
    jogador.mao.length !== estado.jogadores[idx].mao.length ||
    JSON.stringify(restantes) !== JSON.stringify(originais);

  if (!mudou) return estado;

  return {
    ...estado,
    jogadores,
    baralho,
    log: log.length ? [...estado.log, ...log] : estado.log,
  };
}
