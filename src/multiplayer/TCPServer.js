let TcpSocket = null;
try {
  const tcpModule = require('react-native-tcp-socket');
  TcpSocket = tcpModule.default || tcpModule;
  console.log('[TCPServer] TCP module loaded:', typeof TcpSocket);
} catch (e) {
  console.error('[TCPServer] Failed to load TCP module:', e.message);
}
import { criarMensagem, parseMensagem, MSG, PORT } from './Protocol';

export class GameServer {
  constructor() {
    this.server = null;
    this.client = null;
    this.onClienteConectado = null;
    this.onMensagemRecebida = null;
    this.onClienteDesconectado = null;
  }

  iniciar(hostIP) {
    return new Promise((resolve, reject) => {
      if (!TcpSocket) {
        reject(new Error('TCP module not available'));
        return;
      }

      let settled = false;

      console.log('[TCPServer] Starting on IP:', hostIP, 'Port:', PORT);

      this.server = TcpSocket.createServer({}, (socket) => {
        this.client = socket;
        console.log('[TCPServer] Client connected');
        if (this.onClienteConectado) this.onClienteConectado();

        socket.on('data', (data) => {
          const mensagens = parseMensagem(data.toString());
          mensagens.forEach((msg) => {
            if (this.onMensagemRecebida) this.onMensagemRecebida(msg);
          });
        });

        socket.on('close', () => {
          console.log('[TCPServer] Client disconnected');
          this.client = null;
          if (this.onClienteDesconectado) this.onClienteDesconectado();
        });

        socket.on('error', (err) => {
          console.error('[TCPServer] Socket error:', err.message || err);
        });
      });

      this.server.listen(PORT, hostIP, () => {
        if (settled) return;
        settled = true;
        console.log('[TCPServer] Listening on', hostIP + ':' + PORT);
        resolve(hostIP);
      });

      this.server.on('error', (err) => {
        console.error('[TCPServer] Server error:', err.message || err);
        if (settled) return;
        settled = true;
        reject(err);
      });
    });
  }

  enviar(tipo, payload = {}) {
    if (this.client) {
      this.client.write(criarMensagem(tipo, payload));
    }
  }

  parar() {
    if (this.client) {
      this.client.destroy();
      this.client = null;
    }
    if (this.server) {
      this.server.close();
      this.server = null;
    }
  }
}
