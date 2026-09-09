import React, { useState, useEffect, useRef } from 'react';
import {
  View,
  Text,
  TextInput,
  ScrollView,
  TouchableOpacity,
  StyleSheet,
  Dimensions,
  Alert,
} from 'react-native';
import * as Network from 'expo-network';
import { startListening, stopListening, cleanExpiredRooms } from '../multiplayer/discovery';

const { width: SCREEN_WIDTH, height: SCREEN_HEIGHT } = Dimensions.get('window');

const CYAN = '#00e5ff';
const GOLD = '#c89b3c';
const GOLD_LIGHT = '#d4a843';
const GREEN = '#4CAF50';
const PANEL_BG = '#1a1a2e';
const PANEL_BORDER = '#3a3a5c';

export default function TelaLobby({ onVoltar, onCriarSala, onEntrarSala, perfil }) {
  const [ipDigitado, setIpDigitado] = useState('');
  const [localIP, setLocalIP] = useState('');
  const [salasDescobertas, setSalasDescobertas] = useState([]);
  const cleanTimerRef = useRef(null);

  useEffect(() => {
    getLocalIP();
    startListening((rooms) => {
      setSalasDescobertas(rooms);
    }).catch(() => {});
    cleanTimerRef.current = setInterval(() => {
      cleanExpiredRooms();
    }, 3000);

    return () => {
      stopListening();
      if (cleanTimerRef.current) {
        clearInterval(cleanTimerRef.current);
      }
    };
  }, []);

  const getLocalIP = async () => {
    try {
      const ip = await Network.getIpAddressAsync();
      setLocalIP(ip);
    } catch (e) {
      setLocalIP('192.168.1.100');
    }
  };

  const handleCriarSala = () => {
    onCriarSala({ localIP });
  };

  const handleEntrarSala = () => {
    if (!ipDigitado.trim()) {
      Alert.alert('Erro', 'Digite o IP da sala');
      return;
    }
    onEntrarSala({ ip: ipDigitado.trim() });
  };

  const handleEntrarSalaDescoberta = (sala) => {
    onEntrarSala({ ip: sala.ip });
  };

  return (
    <View style={styles.background}>
      <TouchableOpacity style={styles.btnVoltarTopo} onPress={onVoltar} activeOpacity={0.7}>
        <Text style={styles.btnVoltarTopoTexto}>{'< VOLTAR'}</Text>
      </TouchableOpacity>

      <ScrollView
        style={styles.scroll}
        contentContainerStyle={styles.scrollContent}
        showsVerticalScrollIndicator={false}
      >
        <Text style={styles.titulo}>MULTIPLAYER</Text>
        <Text style={styles.subtitulo}>LOCAL</Text>

        <View style={styles.painel}>
          <TouchableOpacity style={styles.btnCriar} onPress={handleCriarSala} activeOpacity={0.7}>
            <Text style={styles.btnCriarTexto}>CRIAR NOVA SALA</Text>
            <Text style={styles.btnCriarIcone}>+</Text>
          </TouchableOpacity>

          <View style={styles.linhaDivisoria} />

          {salasDescobertas.length > 0 && (
            <View style={styles.salasContainer}>
              <Text style={styles.salasTitulo}>SALAS ENCONTRADAS</Text>
              {salasDescobertas.map((sala, index) => (
                <TouchableOpacity
                  key={`${sala.ip}-${index}`}
                  style={styles.salaCard}
                  onPress={() => handleEntrarSalaDescoberta(sala)}
                  activeOpacity={0.7}
                >
                  <View style={styles.salaInfo}>
                    <Text style={styles.salaNome}>{sala.hostName}</Text>
                    <Text style={styles.salaIp}>{sala.ip}</Text>
                  </View>
                  <View style={styles.salaJogadores}>
                    <Text style={styles.salaJogadoresTexto}>
                      {sala.playerCount}/{sala.maxPlayers}
                    </Text>
                  </View>
                  <View style={styles.btnEntrarSmall}>
                    <Text style={styles.btnEntrarSmallTexto}>CONECTAR</Text>
                  </View>
                </TouchableOpacity>
              ))}
            </View>
          )}

          {salasDescobertas.length === 0 && (
            <View style={styles.procurandoContainer}>
              <Text style={styles.procurandoTexto}>Procurando salas na rede...</Text>
            </View>
          )}

          <View style={styles.linhaDivisoria} />

          <View style={styles.inputRow}>
            <TextInput
              style={styles.input}
              placeholder="DIGITE O CODIGO"
              placeholderTextColor="#556"
              value={ipDigitado}
              onChangeText={setIpDigitado}
              keyboardType="default"
              maxLength={15}
            />
            <TouchableOpacity style={styles.btnConectar} onPress={handleEntrarSala} activeOpacity={0.7}>
              <Text style={styles.btnConectarIcone}>🤝</Text>
              <Text style={styles.btnConectarTexto}>CONECTAR</Text>
            </TouchableOpacity>
          </View>
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
    justifyContent: 'center',
    paddingHorizontal: 20,
    paddingVertical: 60,
    minHeight: SCREEN_HEIGHT,
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
    fontSize: 20,
    color: '#aaa',
    letterSpacing: 8,
    textAlign: 'center',
    marginBottom: 24,
    marginTop: 4,
  },
  painel: {
    width: SCREEN_WIDTH * 0.88,
    maxWidth: 400,
    backgroundColor: PANEL_BG,
    borderWidth: 3,
    borderColor: PANEL_BORDER,
    borderRadius: 16,
    paddingVertical: 24,
    paddingHorizontal: 20,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 4 },
    shadowOpacity: 0.6,
    shadowRadius: 10,
    elevation: 10,
  },
  btnCriar: {
    width: '100%',
    backgroundColor: '#3a3228',
    borderWidth: 3,
    borderColor: GOLD,
    borderRadius: 12,
    paddingVertical: 16,
    paddingHorizontal: 20,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    marginBottom: 16,
    shadowColor: GOLD,
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.4,
    shadowRadius: 4,
    elevation: 4,
  },
  btnCriarTexto: {
    color: '#fff',
    fontSize: 17,
    fontWeight: 'bold',
    letterSpacing: 2,
    flex: 1,
    textAlign: 'center',
  },
  btnCriarIcone: {
    color: '#fff',
    fontSize: 20,
    fontWeight: 'bold',
    position: 'absolute',
    right: 18,
  },
  linhaDivisoria: {
    width: '100%',
    height: 2,
    backgroundColor: '#333',
    marginVertical: 16,
  },
  salasContainer: {
    width: '100%',
    marginBottom: 8,
  },
  salasTitulo: {
    color: GOLD,
    fontSize: 10,
    fontWeight: 'bold',
    letterSpacing: 2,
    marginBottom: 10,
    textAlign: 'center',
  },
  salaCard: {
    width: '100%',
    backgroundColor: 'rgba(20, 20, 40, 0.8)',
    borderWidth: 1,
    borderColor: GREEN,
    borderRadius: 8,
    padding: 10,
    marginBottom: 8,
    flexDirection: 'row',
    alignItems: 'center',
  },
  salaInfo: {
    flex: 1,
  },
  salaNome: {
    color: '#fff',
    fontSize: 13,
    fontWeight: 'bold',
  },
  salaIp: {
    color: '#888',
    fontSize: 10,
    marginTop: 2,
  },
  salaJogadores: {
    backgroundColor: 'rgba(76, 175, 80, 0.2)',
    paddingHorizontal: 8,
    paddingVertical: 3,
    borderRadius: 4,
    marginRight: 8,
  },
  salaJogadoresTexto: {
    color: GREEN,
    fontSize: 10,
    fontWeight: 'bold',
  },
  btnEntrarSmall: {
    backgroundColor: '#1a3a2a',
    borderWidth: 1,
    borderColor: GREEN,
    borderRadius: 6,
    paddingHorizontal: 10,
    paddingVertical: 6,
  },
  btnEntrarSmallTexto: {
    color: GREEN,
    fontSize: 10,
    fontWeight: 'bold',
    letterSpacing: 1,
  },
  procurandoContainer: {
    width: '100%',
    paddingVertical: 12,
    alignItems: 'center',
  },
  procurandoTexto: {
    color: '#666',
    fontSize: 11,
    fontStyle: 'italic',
  },
  inputRow: {
    width: '100%',
    flexDirection: 'row',
    alignItems: 'center',
    gap: 8,
  },
  input: {
    flex: 1,
    height: 48,
    backgroundColor: '#111122',
    borderWidth: 2,
    borderColor: CYAN,
    borderRadius: 10,
    color: '#fff',
    fontSize: 13,
    fontWeight: 'bold',
    letterSpacing: 1,
    paddingHorizontal: 12,
    shadowColor: CYAN,
    shadowOffset: { width: 0, height: 0 },
    shadowOpacity: 0.3,
    shadowRadius: 6,
    elevation: 3,
  },
  btnConectar: {
    backgroundColor: '#1a3a4a',
    borderWidth: 2,
    borderColor: CYAN,
    borderRadius: 10,
    paddingVertical: 12,
    paddingHorizontal: 14,
    flexDirection: 'row',
    alignItems: 'center',
    gap: 6,
    shadowColor: CYAN,
    shadowOffset: { width: 0, height: 0 },
    shadowOpacity: 0.4,
    shadowRadius: 6,
    elevation: 4,
  },
  btnConectarIcone: {
    fontSize: 14,
  },
  btnConectarTexto: {
    color: CYAN,
    fontSize: 12,
    fontWeight: 'bold',
    letterSpacing: 1,
  },
});
