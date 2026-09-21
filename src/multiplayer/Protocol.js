export const PORT = 4963;

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

// Mantido por compatibilidade, mas NAO deve ser usado diretamente em cima de
// eventos 'data' de socket TCP, pois um envio pode chegar fragmentado em
// varios eventos. Use criarParser() para manter buffer entre chamadas.
export function parseMensagem(data) {
  try {
    const linhas = data.split('\n').filter(Boolean);
    return linhas.map((linha) => JSON.parse(linha));
  } catch (e) {
    return [];
  }
}

/**
 * Cria um parser com buffer proprio, para ser usado por conexao TCP
 * (uma instancia por socket). TCP e um stream de bytes: uma unica
 * mensagem (terminada em '\n') pode chegar dividida em varios eventos
 * 'data', ou varias mensagens podem chegar grudadas num unico evento.
 *
 * Este parser acumula os chunks recebidos, so extrai e faz JSON.parse
 * das linhas que ja estao completas (ou seja, que ja tem um '\n' depois
 * delas), e guarda o restante incompleto no buffer para a proxima chamada.
 *
 * Uso:
 *   const parse = criarParser();
 *   socket.on('data', (chunk) => {
 *     const mensagens = parse(chunk.toString());
 *     mensagens.forEach((msg) => ...);
 *   });
 */
export function criarParser() {
  let buffer = '';

  return function parse(dataChunk) {
    buffer += dataChunk;

    const partes = buffer.split('\n');
    // A ultima parte pode estar incompleta (sem '\n' no final ainda).
    // Guardamos ela de volta no buffer para a proxima chamada.
    buffer = partes.pop();

    const mensagens = [];
    for (const linha of partes) {
      if (!linha) continue;
      try {
        mensagens.push(JSON.parse(linha));
      } catch (e) {
        console.warn('[Protocol] Linha invalida ignorada:', e.message);
      }
    }
    return mensagens;
  };
}