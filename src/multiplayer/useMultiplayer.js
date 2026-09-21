import { useEffect, useRef, useCallback } from 'react';
import { MSG } from './Protocol';

export function useMultiplayer(estado, dispatch, multiplayerConfig, enviarEstadoRef) {
  const configRef = useRef(multiplayerConfig);
  const dispatchRef = useRef(dispatch);
  const estadoRef = useRef(estado);
  const isHost = multiplayerConfig?.isHost;
  const connection = isHost
    ? multiplayerConfig?.server
    : multiplayerConfig?.client;

  useEffect(() => {
    configRef.current = multiplayerConfig;
    dispatchRef.current = dispatch;
    estadoRef.current = estado;
  }, [multiplayerConfig, dispatch, estado]);

  useEffect(() => {
    if (!connection || !multiplayerConfig) return;

    const handleMessage = (msg) => {
      switch (msg.tipo) {
        case MSG.PLAYER_ACTION: {
          if (isHost) {
            const estadoAtual = estadoRef.current;
            const action = msg.payload.action;

            // Validacao: cliente so pode agir se for a vez dele (indice 1)
            const acoesDeTurno = ['JOGAR_CARTA', 'PASSAR_TURNO', 'JOGAR_CARTA_E_PASSAR', 'DESCARTAR', 'JOGAR_CARTA_SEM_COMPRA'];
            const ehAcaoDeTurno = acoesDeTurno.includes(action.type);

            if (ehAcaoDeTurno && estadoAtual?.jogadorAtivoIndex !== 1) {
              console.warn('[MP] Cliente tentou agir fora da vez. Ignorando.', action.type);
              break;
            }

            dispatchRef.current(action);
            // NAO enviar estado aqui. O useEffect que observa `estado` no
            // ArenaCombate vai enviar quando o reducer realmente aplicar.
          }
          break;
        }
        case MSG.STATE_UPDATE: {
          if (!isHost) {
            const estadoRecebido = msg.payload.estado;
            // NAO preserva mais "mão local": o host manda a mão REAL do
            // cliente (índice 1). O estado anterior do cliente (1v1 vs IA)
            // é descartado por completo.
            dispatchRef.current({
              type: 'SET_MULTIPLAYER_STATE',
              payload: estadoRecebido,
            });
          }
          break;
        }
        case MSG.HOST_ACTION: {
          if (!isHost) {
            dispatchRef.current(msg.payload.action);
          }
          break;
        }
        case MSG.GAME_OVER: {
          dispatchRef.current({
            type: 'SET_FIM_DE_JOGO',
            payload: msg.payload.fimDeJogo,
          });
          break;
        }
        default:
          break;
      }
    };

    const prevHandler = connection.onMensagemRecebida;
    connection.onMensagemRecebida = (msg) => {
      if (prevHandler) prevHandler(msg);
      handleMessage(msg);
    };

    return () => {
      if (connection) {
        connection.onMensagemRecebida = prevHandler;
      }
    };
  }, [connection, multiplayerConfig, isHost, enviarEstadoRef]);

  const enviarAcaoHost = useCallback(
    (action) => {
      if (!connection || !isHost) return;
      connection.enviar(MSG.HOST_ACTION, { action });
    },
    [connection, isHost]
  );

  const enviarAcaoCliente = useCallback(
    (action) => {
      if (!connection || isHost) return;
      connection.enviar(MSG.PLAYER_ACTION, { action });
    },
    [connection, isHost]
  );

  // Host → cliente. Oculta SÓ a mão do host (índice 0). A mão do cliente
  // (índice 1) vai completa, senão o cliente nunca vê as próprias cartas.
  const enviarEstado = useCallback(
    (estadoParaEnviar) => {
      if (connection && isHost) {
        const jogadores = estadoParaEnviar.jogadores.map((j, idx) => {
          if (idx === 0) {
            return {
              ...j,
              mao: j.mao.map((c) => ({ uid: c.uid, oculta: true })),
            };
          }
          return j; // cliente recebe a mão inteira
        });
        connection.enviar(MSG.STATE_UPDATE, {
          estado: { ...estadoParaEnviar, jogadores },
        });
      }
    },
    [connection, isHost]
  );

  const enviarGameOver = useCallback(
    (fimDeJogo) => {
      if (connection) {
        connection.enviar(MSG.GAME_OVER, { fimDeJogo });
      }
    },
    [connection]
  );

  return {
    enviarAcaoHost,
    enviarAcaoCliente,
    enviarEstado,
    enviarGameOver,
    isHost,
    isMultiplayer: !!multiplayerConfig,
  };
}