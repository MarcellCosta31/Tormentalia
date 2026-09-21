import React, { createContext, useContext, useReducer, useCallback } from 'react';
import {
  criarEstadoInicial,
  criarEstadoMultiplayer,
  jogarCarta as jogarCartaEngine,
  jogarCartaSemComprar,
  comprarCartaJogador,
  fimDeTurno as fimDeTurnoEngine,
  descartarCarta as descartarCartaEngine,
  criarEstadoMultiplayerN,
  jogarCartaN,
  jogarCartaSemComprarN,
  fimDeTurnoN,
  descartarCartaN,
} from '../hooks/useCombat';
import { comprarCarta as comprarCartaBaralho } from '../cards/baralhoCartas';

const GameContext = createContext(null);

function gameReducer(state, action) {
  switch (action.type) {
    case 'INICIAR':
      return criarEstadoInicial();

   case 'INICIAR_MULTIPLAYER': {
  const { nomeJogador1, nomeJogador2, primeiroJogadorIndex, avatar1, avatar2 } = action.payload;
  return criarEstadoMultiplayer(nomeJogador1, nomeJogador2, primeiroJogadorIndex, avatar1, avatar2);
}

    case 'INICIAR_MULTI_N': {
  const { nomesJogadores, avatarsJogadores } = action.payload;
  return criarEstadoMultiplayerN(nomesJogadores, avatarsJogadores);
}

    case 'SET_MULTIPLAYER_STATE': {
      return action.payload;
    }

    case 'JOGAR_CARTA': {
      const { jogadorId, cartaUid, jogadorAlvoId } = action.payload;
      return jogarCartaEngine(state, jogadorId, cartaUid, jogadorAlvoId);
    }

    case 'JOGAR_CARTA_SEM_COMPRA': {
      const { jogadorId, cartaUid, jogadorAlvoId } = action.payload;
      return jogarCartaSemComprar(state, jogadorId, cartaUid, jogadorAlvoId);
    }

    case 'JOGAR_CARTAS_SEM_COMPRA': {
      const { jogadorId, cartas } = action.payload;
      let estadoAtual = state;
      for (const carta of cartas) {
        estadoAtual = jogarCartaSemComprar(estadoAtual, jogadorId, carta.uid, carta.precisaAlvo ? null : null);
      }
      return estadoAtual;
    }

    // Ação atômica: joga múltiplas cartas E passa o turno numa única
    // transição de estado. Evita race conditions no multiplayer onde
    // JOGAR_CARTAS_SEM_COMPRA e PASSAR_TURNO chegam como mensagens
    // TCP separadas e podem ser processadas fora de ordem.
    case 'JOGAR_CARTAS_E_PASSAR': {
      const { jogadorId, cartas } = action.payload;
      let estadoAtual = state;
      for (const carta of cartas) {
        estadoAtual = jogarCartaSemComprar(estadoAtual, jogadorId, carta.uid, null);
      }
      return fimDeTurnoEngine(estadoAtual);
    }

    case 'COMPRAR_CARTA_JOGADOR': {
      const { jogadorId } = action.payload;
      return comprarCartaJogador(state, jogadorId);
    }

    // Ação atômica (1 carta): joga + passa turno.
    case 'JOGAR_CARTA_E_PASSAR': {
      const { jogadorId, cartaUid, jogadorAlvoId } = action.payload;
      const aposJogar = jogarCartaEngine(state, jogadorId, cartaUid, jogadorAlvoId);
      return fimDeTurnoEngine(aposJogar);
    }

    case 'DESCARTAR': {
      const { jogadorId, cartaUid } = action.payload;
      return descartarCartaEngine(state, jogadorId, cartaUid);
    }

    case 'PASSAR_TURNO':
      return fimDeTurnoEngine(state);

    case 'JOGAR_CARTA_N': {
      const { jogadorIdx, cartaUid, alvoIdx } = action.payload;
      return jogarCartaN(state, jogadorIdx, cartaUid, alvoIdx);
    }

    case 'JOGAR_CARTA_E_PASSAR_N': {
      const { jogadorIdx: jIdx, cartaUid: cUid, alvoIdx: aIdx } = action.payload;
      const estadoAposJogar = jogarCartaN(state, jIdx, cUid, aIdx);
      return fimDeTurnoN(estadoAposJogar);
    }

    // NOVO — joga UMA carta N-player SEM comprar (usada pelo botão JOGAR
    // da ArenaMultiplayer para aplicar cada carta da seleção).
    case 'JOGAR_CARTA_SEM_COMPRA_N': {
      const { jogadorIdx, cartaUid, alvoIdx } = action.payload;
      return jogarCartaSemComprarN(state, jogadorIdx, cartaUid, alvoIdx);
    }

    // Ação atômica N-player: joga múltiplas cartas SEM comprar e passa o
    // turno (fimDeTurnoN faz a compra de 1 carta no final). Mantida para
    // quem quiser o fluxo atômico de uma vez só.
    case 'JOGAR_CARTAS_E_PASSAR_N': {
      const { jogadorIdx, cartas } = action.payload;
      let estadoAtual = state;
      for (const carta of cartas) {
        estadoAtual = jogarCartaSemComprarN(
          estadoAtual,
          jogadorIdx,
          carta.uid,
          carta.alvoIdx ?? null
        );
      }
      return fimDeTurnoN(estadoAtual);
    }

    case 'DESCARTAR_N': {
      const { jogadorIdx, cartaUid } = action.payload;
      return descartarCartaN(state, jogadorIdx, cartaUid);
    }

    case 'PASSAR_TURNO_N':
      return fimDeTurnoN(state);

    case 'IA_N_JOGAR_CARTA': {
      const { jogadorIdx: iaIdx, cartaUid: iaCartaUid, alvoIdx: iaAlvoIdx } = action.payload;
      const iaJogador = state.jogadores[iaIdx];
      if (!iaJogador || iaJogador.falido || iaJogador.mao.length === 0) {
        return { ...state, iaAnimacao: { tipo: 'fim' } };
      }
      const novoEstado = jogarCartaN(state, iaIdx, iaCartaUid, iaAlvoIdx);
      return { ...novoEstado, iaAnimacao: { tipo: 'jogar', jogadorIdx: iaIdx, cartaUid: iaCartaUid } };
    }

    case 'IA_N_COMPRAR_CARTA': {
      const { jogadorIdx: compIdx } = action.payload;
      const novoEstado = { ...state };
      const iaComp = { ...novoEstado.jogadores[compIdx] };
      const resultado = comprarCartaBaralho(novoEstado.baralho, iaComp.mao, 1);
      iaComp.mao = resultado.mao;
      novoEstado.baralho = resultado.baralho;
      const novosJogadores = [...novoEstado.jogadores];
      novosJogadores[compIdx] = iaComp;
      return { ...novoEstado, jogadores: novosJogadores, iaAnimacao: { tipo: 'comprar', jogadorIdx: compIdx } };
    }

    case 'IA_N_DESCARTAR_CARTA': {
      const { jogadorIdx: descIdx, cartaUid: descCartaUid } = action.payload;
      return descartarCartaN(state, descIdx, descCartaUid);
    }

    case 'IA_N_FIM_TURNO':
      return { ...fimDeTurnoN(state), iaAnimacao: null };

    case 'IA_N_LIMPAR_ANIMACAO':
      return { ...state, iaAnimacao: null };

    case 'IA_JOGAR_CARTA': {
      const ia = state.jogadores[1];
      if (!ia || ia.falido || ia.mao.length === 0) {
        return { ...state, iaAnimacao: { tipo: 'fim' } };
      }
      const carta = ia.mao[Math.floor(Math.random() * ia.mao.length)];
      const novoEstado = jogarCartaSemComprar(state, 2, carta.uid, carta.precisaAlvo ? 1 : null);
      return { ...novoEstado, iaAnimacao: { tipo: 'jogar', cartaUid: carta.uid } };
    }

    case 'IA_COMPRAR_CARTA': {
      const novoEstado = { ...state };
      const ia = { ...novoEstado.jogadores[1] };
      const resultado = comprarCartaBaralho(novoEstado.baralho, ia.mao, 1);
      ia.mao = resultado.mao;
      novoEstado.baralho = resultado.baralho;
      const novosJogadores = [...novoEstado.jogadores];
      novosJogadores[1] = ia;
      return { ...novoEstado, jogadores: novosJogadores, iaAnimacao: { tipo: 'comprar' } };
    }

    case 'IA_DESCARTAR_CARTA': {
      const { cartaUid } = action.payload;
      return descartarCartaEngine(state, 2, cartaUid);
    }

    case 'IA_FIM_TURNO':
      return { ...fimDeTurnoEngine(state), iaAnimacao: null };

    case 'IA_LIMPAR_ANIMACAO':
      return { ...state, iaAnimacao: null };

    case 'BATALHA_INICIADA':
      return { ...state, batalhaIniciada: true };

    case 'SET_FIM_DE_JOGO':
      return { ...state, fimDeJogo: action.payload };

    case 'RESET':
      return criarEstadoInicial();

    default:
      return state;
  }
}

export function GameProvider({ children }) {
  const [estado, dispatch] = useReducer(gameReducer, null, criarEstadoInicial);

  const iniciarJogo = useCallback(() => {
    dispatch({ type: 'INICIAR' });
  }, []);

  const jogarCartaAction = useCallback((jogadorId, cartaUid, jogadorAlvoId) => {
    dispatch({ type: 'JOGAR_CARTA', payload: { jogadorId, cartaUid, jogadorAlvoId } });
  }, []);

  const jogarCartaEPassarAction = useCallback((jogadorId, cartaUid, jogadorAlvoId) => {
    dispatch({ type: 'JOGAR_CARTA_E_PASSAR', payload: { jogadorId, cartaUid, jogadorAlvoId } });
  }, []);

  const jogarCartasEPassarAction = useCallback((jogadorId, cartas) => {
    dispatch({ type: 'JOGAR_CARTAS_E_PASSAR', payload: { jogadorId, cartas } });
  }, []);

  const descartarCartaAction = useCallback((jogadorId, cartaUid) => {
    dispatch({ type: 'DESCARTAR', payload: { jogadorId, cartaUid } });
  }, []);

  const passarTurno = useCallback(() => {
    dispatch({ type: 'PASSAR_TURNO' });
  }, []);

  const iniciarMultiN = useCallback((nomesJogadores, avatarsJogadores) => {
    dispatch({ type: 'INICIAR_MULTI_N', payload: { nomesJogadores, avatarsJogadores } });
  }, []);

  const jogarCartaNAction = useCallback((jogadorIdx, cartaUid, alvoIdx) => {
    dispatch({ type: 'JOGAR_CARTA_N', payload: { jogadorIdx, cartaUid, alvoIdx } });
  }, []);

  // NOVO — joga UMA carta N-player sem comprar (usada no fluxo por carta
  // do botão JOGAR, espelhando o ArenaCombate 1v1).
  const jogarCartaSemComprarNAction = useCallback((jogadorIdx, cartaUid, alvoIdx) => {
    dispatch({ type: 'JOGAR_CARTA_SEM_COMPRA_N', payload: { jogadorIdx, cartaUid, alvoIdx } });
  }, []);

  // Ação atômica N-player (joga tudo + passa turno de uma vez).
  const jogarCartasEPassarNAction = useCallback((jogadorIdx, cartas) => {
    dispatch({ type: 'JOGAR_CARTAS_E_PASSAR_N', payload: { jogadorIdx, cartas } });
  }, []);

  const descartarCartaNAction = useCallback((jogadorIdx, cartaUid) => {
    dispatch({ type: 'DESCARTAR_N', payload: { jogadorIdx, cartaUid } });
  }, []);

  const passarTurnoN = useCallback(() => {
    dispatch({ type: 'PASSAR_TURNO_N' });
  }, []);

  const resetarJogo = useCallback(() => {
    dispatch({ type: 'RESET' });
  }, []);

  const jogarCartaSemComprarAction = useCallback((jogadorId, cartaUid, jogadorAlvoId) => {
    dispatch({ type: 'JOGAR_CARTA_SEM_COMPRA', payload: { jogadorId, cartaUid, jogadorAlvoId } });
  }, []);

  const comprarCartaJogadorAction = useCallback((jogadorId) => {
    dispatch({ type: 'COMPRAR_CARTA_JOGADOR', payload: { jogadorId } });
  }, []);

  const value = {
    estado,
    iniciarJogo,
    jogarCarta: jogarCartaAction,
    jogarCartaSemComprar: jogarCartaSemComprarAction,
    comprarCartaJogador: comprarCartaJogadorAction,
    jogarCartaEPassar: jogarCartaEPassarAction,
    jogarCartasEPassar: jogarCartasEPassarAction,
    descartarCarta: descartarCartaAction,
    passarTurno,
    iniciarMultiN,
    jogarCartaN: jogarCartaNAction,
    jogarCartaSemComprarN: jogarCartaSemComprarNAction,
    jogarCartasEPassarN: jogarCartasEPassarNAction,
    descartarCartaN: descartarCartaNAction,
    passarTurnoN,
    resetarJogo,
    dispatch,
  };

  return <GameContext.Provider value={value}>{children}</GameContext.Provider>;
}

export function useGameState() {
  const context = useContext(GameContext);
  if (!context) {
    throw new Error('useGameState deve ser usado dentro de um GameProvider');
  }
  return context;
}