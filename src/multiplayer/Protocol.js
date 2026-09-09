export const PORT = 4444;

export const MSG = {
  ROOM_CREATED: 'ROOM_CREATED',
  ROOM_JOINED: 'ROOM_JOINED',
  PLAYER_READY: 'PLAYER_READY',
  PLAYER_INFO: 'PLAYER_INFO',
  GAME_START: 'GAME_START',
  PLAYER_ACTION: 'PLAYER_ACTION',
  HOST_ACTION: 'HOST_ACTION',
  STATE_UPDATE: 'STATE_UPDATE',
  GAME_OVER: 'GAME_OVER',
  CHAT: 'CHAT',
  PING: 'PING',
  PONG: 'PONG',
};

export function criarMensagem(tipo, payload = {}) {
  return JSON.stringify({ tipo, payload, timestamp: Date.now() }) + '\n';
}

export function parseMensagem(data) {
  try {
    const linhas = data.split('\n').filter(Boolean);
    return linhas.map((linha) => JSON.parse(linha));
  } catch (e) {
    return [];
  }
}
