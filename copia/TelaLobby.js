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
import { GameServer } from '../multiplayer/TCPServer';
import { GameClient } from '../multiplayer/TCPClient';
import { MSG } from '../multiplayer/Protocol';
import { getAvatarById } from '../utils/avatar';

const { width: SCREEN_WIDTH, height: SCREEN_HEIGHT } = Dimensions.get('window');

const CYAN = '#00e5ff';
const GOLD = '#c89b3c';
const GOLD_LIGHT = '#d4a843';
const PANEL_BG = '#1a1a2e';
const PANEL_BORDER = '#3a3a5c';

export default function TelaLobby({ onVoltar, onCriarSala, onEntrarSala, perfil }) {
  const [ipDigitado, setIpDigitado] = useState('');
  const [localIP, setLocalIP] = useState('');

  useEffect(() => {
    getLocalIP();
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
    marginBottom: 16,
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
