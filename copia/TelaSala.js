import React, { useState, useEffect, useRef } from 'react';
import {
  View,
  Text,
  ScrollView,
  TouchableOpacity,
  StyleSheet,
  Dimensions,
  Image,
  Alert,
} from 'react-native';
import { GameServer } from '../multiplayer/TCPServer';
import { GameClient } from '../multiplayer/TCPClient';
import { MSG } from '../multiplayer/Protocol';
import { getAvatarById } from '../utils/avatar';

const { width: SCREEN_WIDTH, height: SCREEN_HEIGHT } = Dimensions.get('window');

const CYAN = '#00e5ff';
const GOLD = '#c89b3c';
const GOLD_LIGHT = '#d4a843';
const GREEN = '#4CAF50';
const PANEL_BG = '#1a1a2e';
const PANEL_BORDER = '#3a3a5c';

export default function TelaSala({ onVoltar, onIniciarJogo, perfil, salaInfo }) {
  const [status, setStatus] = useState('Preparando sala...');
  const [conectado, setConectado] = useState(false);
  const [oponentePronto, setOponentePronto] = useState(false);
  const [jogadores, setJogadores] = useState([]);

  const serverRef = useRef(null);
  const clientRef = useRef(null);
  const isHost = salaInfo?.isHost;
  const localIP = salaInfo?.localIP || '0.0.0.0';
  const ipDigitado = salaInfo?.ip || '';

  useEffect(() => {
    if (isHost) {
      criarSala();
    } else {
      entrarSala();
    }
    return () => {
      if (serverRef.current) serverRef.current.parar();
      if (clientRef.current) clientRef.current.parar();
    };
  }, []);

  const adicionarJogador = (jogador) => {
    setJogadores((prev) => {
      const jogadorComAvatar = {
        ...jogador,
        avatarSource: jogador.avatar ? getAvatarById(jogador.avatar) : null,
      };
      const existe = prev.find((j) => j.id === jogador.id);
      if (existe) {
        return prev.map((j) => (j.id === jogador.id ? jogadorComAvatar : j));
      }
      return [...prev, jogadorComAvatar];
    });
  };

  const criarSala = async () => {
    const avatarId = perfil?.avatar || '1';
    const hostInfo = {
      id: 'host',
      nome: perfil?.nickName || 'JOGADOR_1',
      avatar: avatarId,
      avatarSource: getAvatarById(avatarId),
      isHost: true,
    };
    setJogadores([hostInfo]);

    const server = new GameServer();
    serverRef.current = server;

    server.onClienteConectado = () => {
      setConectado(true);
      setStatus('Jogador conectado!');
      server.enviar(MSG.ROOM_JOINED, {
        hostName: perfil?.nickName || 'JOGADOR_1',
        hostAvatar: avatarId,
      });
    };

    server.onMensagemRecebida = (msg) => {
      if (msg.tipo === MSG.PLAYER_INFO) {
        const clientInfo = {
          id: 'client',
          nome: msg.payload.nome,
          avatar: msg.payload.avatar,
          isHost: false,
        };
        adicionarJogador(clientInfo);
      }
      if (msg.tipo === MSG.PLAYER_READY) {
        setOponentePronto(true);
        setStatus('Jogador pronto!');
        server.enviar(MSG.PLAYER_READY, {
          hostName: perfil?.nickName || 'JOGADOR_1',
        });
      }
    };

    server.onClienteDesconectado = () => {
      setConectado(false);
      setOponentePronto(false);
      setJogadores((prev) => prev.filter((j) => j.id !== 'client'));
      setStatus('Jogador desconectado. Aguardando...');
    };

    try {
      await server.iniciar(localIP);
      setStatus('Aguardando jogador conectar...');
    } catch (e) {
      console.error('[TelaSala] Erro ao criar sala:', e.message || e);
      Alert.alert('Erro', `Nao foi possivel criar a sala: ${e.message || e}`);
      onVoltar();
    }
  };

  const entrarSala = async () => {
    setStatus('Conectando...');

    const client = new GameClient();
    clientRef.current = client;

    client.onConectado = () => {
      setConectado(true);
      setStatus('Conectado! Enviando dados...');
      client.enviar(MSG.PLAYER_INFO, {
        nome: perfil?.nickName || 'JOGADOR_2',
        avatar: perfil?.avatar || '1',
      });
      client.enviar(MSG.PLAYER_READY, {
        clientName: perfil?.nickName || 'JOGADOR_2',
      });
    };

    client.onMensagemRecebida = (msg) => {
      if (msg.tipo === MSG.ROOM_JOINED) {
        const hostInfo = {
          id: 'host',
          nome: msg.payload.hostName,
          avatar: msg.payload.hostAvatar,
          isHost: true,
        };
        adicionarJogador(hostInfo);
        setStatus('Conectado a sala de ' + msg.payload.hostName + '!');
      }
      if (msg.tipo === MSG.PLAYER_READY) {
        setOponentePronto(true);
        setStatus('Pronto! Aguardando host iniciar...');
      }
      if (msg.tipo === MSG.GAME_START) {
        onIniciarJogo({
          modo: 'multiplayer',
          isHost: false,
          server: null,
          client: clientRef.current,
          perfil,
        });
      }
    };

    client.onDesconectado = () => {
      setConectado(false);
      setOponentePronto(false);
      setJogadores([]);
      setStatus('Desconectado do servidor');
    };

    try {
      console.log('[TelaSala] Tentando conectar em:', ipDigitado, 'porta:', 4444);
      await client.conectar(ipDigitado);
    } catch (e) {
      console.error('[TelaSala] Erro ao conectar sala:', e.message || e);
      Alert.alert('Erro', `Nao foi possivel conectar a sala: ${e.message || e}`);
      onVoltar();
    }
  };

  const iniciarBatalha = () => {
    const oponenteInfo = jogadores.find((j) => (isHost ? j.id === 'client' : j.id === 'host'));

    if (serverRef.current) {
      serverRef.current.enviar(MSG.GAME_START, {
        perfilHost: perfil,
        modo: 'multiplayer',
      });
    }
    if (clientRef.current) {
      clientRef.current.enviar(MSG.GAME_START, {
        perfilCliente: perfil,
        modo: 'multiplayer',
      });
    }
    onIniciarJogo({
      modo: 'multiplayer',
      isHost,
      server: serverRef.current,
      client: clientRef.current,
      perfil,
      oponente: oponenteInfo ? { nome: oponenteInfo.nome, avatar: oponenteInfo.avatar } : null,
    });
  };

  const voltar = () => {
    if (serverRef.current) serverRef.current.parar();
    if (clientRef.current) clientRef.current.parar();
    onVoltar();
  };

  const renderJogador = (jogador, index) => (
    <View key={jogador.id} style={styles.jogadorCard}>
      <View style={styles.jogadorAvatar}>
        {jogador.avatarSource ? (
          <Image source={jogador.avatarSource} style={styles.jogadorAvatarImg} resizeMode="contain" />
        ) : (
          <Text style={styles.jogadorAvatarPlaceholder}>{index + 1}</Text>
        )}
      </View>
      <View style={styles.jogadorInfo}>
        <Text style={styles.jogadorNome}>{jogador.nome}</Text>
        <Text style={styles.jogadorRole}>{jogador.isHost ? 'HOST' : 'JOGADOR'}</Text>
      </View>
      <View style={[styles.jogadorStatus, conectado && styles.jogadorStatusOnline]}>
        <Text style={styles.jogadorStatusTexto}>{conectado ? 'ONLINE' : 'OFFLINE'}</Text>
      </View>
    </View>
  );

  return (
    <View style={styles.background}>
      <TouchableOpacity style={styles.btnVoltarTopo} onPress={voltar} activeOpacity={0.7}>
        <Text style={styles.btnVoltarTopoTexto}>{'< VOLTAR'}</Text>
      </TouchableOpacity>

      <ScrollView
        style={styles.scroll}
        contentContainerStyle={styles.scrollContent}
        showsVerticalScrollIndicator={false}
      >
        <Text style={styles.titulo}>SALA</Text>
        <Text style={styles.subtitulo}>{isHost ? 'CRIADA' : 'CONECTADA'}</Text>

        <View style={styles.painel}>
          {isHost && (
            <View style={styles.ipBox}>
              <Text style={styles.ipLabel}>COMPARTE O CODIGO</Text>
              <Text style={styles.ipValor}>{localIP}</Text>
              <Text style={styles.ipHint}>O outro jogador deve digitar este IP</Text>
            </View>
          )}

          {!isHost && (
            <View style={styles.ipBox}>
              <Text style={styles.ipLabel}>CONECTADO AO IP</Text>
              <Text style={styles.ipValor}>{ipDigitado}</Text>
            </View>
          )}

          <View style={styles.statusBox}>
            <View style={[styles.statusDot, conectado && styles.statusDotOnline]} />
            <Text style={styles.statusTexto}>{status}</Text>
          </View>

          <View style={styles.jogadoresContainer}>
            <Text style={styles.jogadoresTitulo}>JOGADORES NA SALA</Text>
            {jogadores.map((j, idx) => renderJogador(j, idx))}
          </View>

          {conectado && oponentePronto && isHost && (
            <TouchableOpacity style={styles.btnIniciar} onPress={iniciarBatalha} activeOpacity={0.7}>
              <Text style={styles.btnIniciarTexto}>INICIAR BATALHA</Text>
            </TouchableOpacity>
          )}

          {conectado && oponentePronto && !isHost && (
            <View style={styles.aguardandoBox}>
              <Text style={styles.aguardandoTexto}>Aguardando host iniciar...</Text>
            </View>
          )}

          {!conectado && (
            <View style={styles.aguardandoBox}>
              <Text style={styles.aguardandoTexto}>Aguardando jogador conectar...</Text>
            </View>
          )}
        </View>
      </ScrollView>
    </View>
  );
}

const styles = StyleSheet.create({
  background: {
    flex: 1,
    backgroundColor: '#1a0a2e',
  },
  scroll: {
    flex: 1,
  },
  scrollContent: {
    flexGrow: 1,
    alignItems: 'center',
    paddingHorizontal: 20,
    paddingTop: 100,
    paddingBottom: 40,
  },
  btnVoltarTopo: {
    position: 'absolute',
    top: 50,
    left: 20,
    backgroundColor: 'rgba(30, 30, 50, 0.9)',
    borderWidth: 2,
    borderColor: '#555',
    borderRadius: 8,
    paddingVertical: 8,
    paddingHorizontal: 14,
    zIndex: 10,
  },
  btnVoltarTopoTexto: {
    color: '#ccc',
    fontSize: 13,
    fontWeight: 'bold',
    letterSpacing: 1,
  },
  titulo: {
    fontSize: 36,
    color: '#fff',
    fontWeight: 'bold',
    letterSpacing: 6,
    textAlign: 'center',
    textShadowColor: '#000',
    textShadowOffset: { width: 2, height: 2 },
    textShadowRadius: 6,
  },
  subtitulo: {
    fontSize: 18,
    color: '#aaa',
    letterSpacing: 8,
    textAlign: 'center',
    marginBottom: 20,
    marginTop: 4,
  },
  painel: {
    width: SCREEN_WIDTH * 0.88,
    maxWidth: 400,
    backgroundColor: PANEL_BG,
    borderWidth: 3,
    borderColor: PANEL_BORDER,
    borderRadius: 16,
    paddingVertical: 20,
    paddingHorizontal: 18,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 4 },
    shadowOpacity: 0.6,
    shadowRadius: 10,
    elevation: 10,
  },
  ipBox: {
    width: '100%',
    backgroundColor: 'rgba(0, 0, 0, 0.4)',
    borderWidth: 2,
    borderColor: GOLD,
    borderRadius: 12,
    padding: 16,
    alignItems: 'center',
    marginBottom: 14,
  },
  ipLabel: {
    color: '#888',
    fontSize: 10,
    letterSpacing: 3,
  },
  ipValor: {
    color: GOLD_LIGHT,
    fontSize: 28,
    fontWeight: 'bold',
    marginVertical: 8,
    letterSpacing: 4,
  },
  ipHint: {
    color: '#666',
    fontSize: 9,
    textAlign: 'center',
  },
  statusBox: {
    width: '100%',
    backgroundColor: 'rgba(0, 0, 0, 0.3)',
    borderWidth: 1,
    borderColor: '#444',
    borderRadius: 10,
    padding: 12,
    alignItems: 'center',
    marginBottom: 14,
    flexDirection: 'row',
    justifyContent: 'center',
    gap: 8,
  },
  statusDot: {
    width: 8,
    height: 8,
    borderRadius: 4,
    backgroundColor: '#666',
  },
  statusDotOnline: {
    backgroundColor: GREEN,
  },
  statusTexto: {
    color: '#ccc',
    fontSize: 12,
    textAlign: 'center',
  },
  jogadoresContainer: {
    width: '100%',
    backgroundColor: 'rgba(0, 0, 0, 0.3)',
    borderWidth: 1,
    borderColor: GOLD,
    borderRadius: 10,
    padding: 10,
    marginBottom: 14,
  },
  jogadoresTitulo: {
    color: GOLD,
    fontSize: 10,
    fontWeight: 'bold',
    letterSpacing: 2,
    marginBottom: 10,
    textAlign: 'center',
  },
  jogadorCard: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: 'rgba(20, 20, 40, 0.8)',
    borderWidth: 1,
    borderColor: '#444',
    borderRadius: 8,
    padding: 10,
    marginBottom: 8,
  },
  jogadorAvatar: {
    width: 36,
    height: 36,
    borderRadius: 18,
    borderWidth: 2,
    borderColor: GOLD,
    backgroundColor: 'rgba(15, 15, 30, 0.9)',
    justifyContent: 'center',
    alignItems: 'center',
    overflow: 'hidden',
  },
  jogadorAvatarImg: {
    width: '100%',
    height: '100%',
  },
  jogadorAvatarPlaceholder: {
    color: GOLD,
    fontSize: 14,
    fontWeight: 'bold',
  },
  jogadorInfo: {
    marginLeft: 10,
    flex: 1,
  },
  jogadorNome: {
    color: '#fff',
    fontSize: 13,
    fontWeight: 'bold',
  },
  jogadorRole: {
    color: '#777',
    fontSize: 9,
    letterSpacing: 1,
    marginTop: 2,
  },
  jogadorStatus: {
    backgroundColor: 'rgba(100, 100, 100, 0.3)',
    paddingHorizontal: 8,
    paddingVertical: 3,
    borderRadius: 4,
  },
  jogadorStatusOnline: {
    backgroundColor: 'rgba(76, 175, 80, 0.3)',
  },
  jogadorStatusTexto: {
    color: '#888',
    fontSize: 8,
    fontWeight: 'bold',
    letterSpacing: 1,
  },
  aguardandoBox: {
    width: '100%',
    paddingVertical: 12,
    paddingHorizontal: 16,
    backgroundColor: 'rgba(200, 155, 60, 0.1)',
    borderRadius: 8,
    borderWidth: 1,
    borderColor: GOLD,
  },
  aguardandoTexto: {
    color: GOLD,
    fontSize: 12,
    fontStyle: 'italic',
    textAlign: 'center',
  },
  btnIniciar: {
    width: '100%',
    backgroundColor: '#1a3a2a',
    borderWidth: 2,
    borderColor: GREEN,
    borderRadius: 12,
    paddingVertical: 14,
    alignItems: 'center',
  },
  btnIniciarTexto: {
    color: '#fff',
    fontSize: 16,
    fontWeight: 'bold',
    letterSpacing: 2,
  },
});
