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
            dispatchRef.current(msg.payload.action);
            setTimeout(() => {
              if (enviarEstadoRef?.current) {
                enviarEstadoRef.current(estadoRef.current);
              }
            }, 200);
          }
          break;
        }
        case MSG.STATE_UPDATE: {
          if (!isHost) {
            dispatchRef.current({
              type: 'SET_MULTIPLAYER_STATE',
              payload: msg.payload.estado,
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

  const enviarEstado = useCallback(
    (estadoParaEnviar) => {
      if (connection && isHost) {
        const jogadores = estadoParaEnviar.jogadores.map((j, idx) => {
          if (idx === 1) return { ...j };
          return { ...j, mao: j.mao.map(() => ({ uid: -1, oculta: true })) };
        });
        connection.enviar(MSG.STATE_UPDATE, {
          estado: { ...estadoParaEnviar, jogadores },
        });
      }
    },
    [connection, isHost]
  );

  return {
    enviarAcaoHost,
    enviarAcaoCliente,
    enviarEstado,
    isHost,
    isMultiplayer: !!multiplayerConfig,
  };
}
