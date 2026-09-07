import React, { createContext, useContext, useReducer, useCallback } from 'react';
import { criarEstadoInicial, jogarCarta as jogarCartaEngine, fimDeTurno as fimDeTurnoEngine, descartarCarta as descartarCartaEngine } from '../hooks/useCombat';
import { TIPO_CARTA } from '../cards/baralhoCartas';

const GameContext = createContext(null);

function executarTurnoIA(state) {
  const jogadorIA = state.jogadores[1];
  if (!jogadorIA || jogadorIA.falido) {
    return fimDeTurnoEngine(state);
  }

  let estadoAtual = { ...state };
  const ia = { ...estadoAtual.jogadores[1] };

  const cartasJogaveis = ia.mao.filter(
    (c) => c.tipo === TIPO_CARTA.ACAO || c.tipo === TIPO_CARTA.CORINGA || c.tipo === TIPO_CARTA.EFEITO || c.tipo === TIPO_CARTA.PROTECAO
  );

  if (cartasJogaveis.length > 0) {
    const carta = cartasJogaveis[Math.floor(Math.random() * cartasJogaveis.length)];

    estadoAtual = jogarCartaEngine(estadoAtual, ia.id, carta.uid, carta.precisaAlvo ? 1 : null);
  }

  const iaAtualizado = { ...estadoAtual.jogadores[1] };
  if (iaAtualizado.mao.length > 0) {
    const idxDescarte = Math.floor(Math.random() * iaAtualizado.mao.length);
    const cartaDescarte = iaAtualizado.mao[idxDescarte];
    estadoAtual = descartarCartaEngine(estadoAtual, iaAtualizado.id, cartaDescarte.uid);
  }

  return fimDeTurnoEngine(estadoAtual);
}

function gameReducer(state, action) {
  switch (action.type) {
    case 'INICIAR':
      return criarEstadoInicial();

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

    case 'EXECUTAR_TURNO_IA':
      return executarTurnoIA(state);

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
