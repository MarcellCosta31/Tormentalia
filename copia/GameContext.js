import React, { createContext, useContext, useReducer, useCallback } from 'react';
import { criarEstadoInicial, criarEstadoMultiplayer, jogarCarta as jogarCartaEngine, fimDeTurno as fimDeTurnoEngine, descartarCarta as descartarCartaEngine } from '../hooks/useCombat';
import { comprarCarta as comprarCartaBaralho } from '../cards/baralhoCartas';

const GameContext = createContext(null);

function gameReducer(state, action) {
  switch (action.type) {
    case 'INICIAR':
      return criarEstadoInicial();

    case 'INICIAR_MULTIPLAYER': {
      const { nomeJogador1, nomeJogador2 } = action.payload;
      return criarEstadoMultiplayer(nomeJogador1, nomeJogador2);
    }

    case 'SET_MULTIPLAYER_STATE': {
      return action.payload;
    }

    case 'JOGAR_CARTA': {
      const { jogadorId, cartaUid, jogadorAlvoId } = action.payload;
      return jogarCartaEngine(state, jogadorId, cartaUid, jogadorAlvoId);
    }

    case 'DESCARTAR': {
      const { jogadorId, cartaUid } = action.payload;
      return descartarCartaEngine(state, jogadorId, cartaUid);
    }

    case 'PASSAR_TURNO':
      return fimDeTurnoEngine(state);

    case 'IA_JOGAR_CARTA': {
      const ia = state.jogadores[1];
      if (!ia || ia.falido || ia.mao.length === 0) {
        return { ...state, iaAnimacao: { tipo: 'fim' } };
      }
      const carta = ia.mao[Math.floor(Math.random() * ia.mao.length)];
      const novoEstado = jogarCartaEngine(state, 2, carta.uid, carta.precisaAlvo ? 1 : null);
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

  const descartarCartaAction = useCallback((jogadorId, cartaUid) => {
    dispatch({ type: 'DESCARTAR', payload: { jogadorId, cartaUid } });
  }, []);

  const passarTurno = useCallback(() => {
    dispatch({ type: 'PASSAR_TURNO' });
  }, []);

  const resetarJogo = useCallback(() => {
    dispatch({ type: 'RESET' });
  }, []);

  const value = {
    estado,
    iniciarJogo,
    jogarCarta: jogarCartaAction,
    descartarCarta: descartarCartaAction,
    passarTurno,
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
