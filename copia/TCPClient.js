let TcpSocket = null;
try {
  const tcpModule = require('react-native-tcp-socket');
  TcpSocket = tcpModule.default || tcpModule;
  console.log('[TCPClient] TCP module loaded:', typeof TcpSocket);
} catch (e) {
  console.error('[TCPClient] Failed to load TCP module:', e.message);
}
import { criarMensagem, criarParser, MSG, PORT } from './Protocol';

export class GameClient {
  constructor() {
    this.socket = null;
    this.onConectado = null;
    this.onMensagemRecebida = null;
    this.onDesconectado = null;

    // Cada conexao tem seu proprio buffer de parsing, para lidar
    // corretamente com mensagens TCP fragmentadas entre eventos 'data'.
    this.parse = criarParser();
  }

  conectar(hostIP) {
    return new Promise((resolve, reject) => {
      if (!TcpSocket) {
        reject(new Error('TCP module not available'));
        return;
      }

      let settled = false;

      // Novo buffer a cada tentativa de conexao, para nao arrastar lixo
      // de uma conexao anterior (ex.: reconexao apos queda).
      this.parse = criarParser();

      this.socket = TcpSocket.createConnection(
        { port: PORT, host: hostIP },
        () => {
          if (settled) return;
          settled = true;
          resolve();
          if (this.onConectado) this.onConectado();
        }
      );

      this.socket.on('data', (data) => {
        const mensagens = this.parse(data.toString());
        mensagens.forEach((msg) => {
          if (this.onMensagemRecebida) this.onMensagemRecebida(msg);
        });
      });

      this.socket.on('close', () => {
        if (this.onDesconectado) this.onDesconectado();
      });

      this.socket.on('error', (err) => {
        console.error('[TCPClient] Connection error:', err.message || err);
        if (settled) return;
        settled = true;
        reject(err);
      });
    });
  }

  enviar(tipo, payload = {}) {
    if (this.socket) {
      this.socket.write(criarMensagem(tipo, payload));
    }
  }

  parar() {
    if (this.socket) {
      this.socket.destroy();
      this.socket = null;
    }
  }
}