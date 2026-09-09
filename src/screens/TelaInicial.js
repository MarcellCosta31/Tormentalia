import React, { useState } from 'react';
import { View, Text, TouchableOpacity, StyleSheet, ImageBackground, Image, Dimensions } from 'react-native';
import { getAvatarById } from '../utils/avatar';
import ModalSelecionarJogadores from '../components/arena/ModalSelecionarJogadores';

const { width: SCREEN_WIDTH, height: SCREEN_HEIGHT } = Dimensions.get('window');

const MenuButton = ({ source, onPress, style }) => (
  <TouchableOpacity style={[styles.botao, style]} onPress={onPress} activeOpacity={0.7}>
    <Image source={source} style={styles.botaoImagem} resizeMode="contain" />
  </TouchableOpacity>
);

const TelaInicial = ({ onIniciarJogo, onMultiplayer, onConfiguracoes, onSobre, onSair, onPerfil, perfil, onArena }) => {
  const [modalArenaVisivel, setModalArenaVisivel] = useState(false);

  const handleSelecionarQuantidade = (quantidade) => {
    if (onArena) {
      onArena(quantidade);
    }
  };

  return (
    <ImageBackground
      source={require('../assets/sprites/menu/menu_back.png')}
      style={styles.background}
      resizeMode="contain"
    >
      <TouchableOpacity style={styles.perfilContainer} onPress={onPerfil} activeOpacity={0.7}>
        <View style={styles.avatarBorda}>
          <Image
            source={getAvatarById(perfil?.avatar || '7')}
            style={styles.avatarPerfil}
            resizeMode="contain"
          />
        </View>
        <Text style={styles.nomeJogador}>{perfil?.nickName || 'JOGADOR_1'}</Text>
      </TouchableOpacity>

      <View style={styles.container}>
        <View style={styles.menuContainer}>
          <MenuButton
            source={require('../assets/sprites/menu/um_jogador_btn.png')}
            onPress={onIniciarJogo}
            style={{ width: SCREEN_WIDTH * 0.35, height: SCREEN_HEIGHT * 0.16 }}
          />
          <MenuButton
            source={require('../assets/sprites/menu/multi_jogadores_btn.png')}
            onPress={onMultiplayer}
          />
          <MenuButton
            source={require('../assets/sprites/menu/configura_btn.png')}
            onPress={onConfiguracoes}
          />
          <MenuButton
            source={require('../assets/sprites/menu/sobre_btn.png')}
            onPress={onSobre}
          />
          <MenuButton
            source={require('../assets/sprites/menu/sair_btn.png')}
            onPress={onSair}
          />
        </View>
      </View>

      {/* Botão de Arena flutuante */}
      <TouchableOpacity
        style={styles.botaoArena}
        onPress={() => setModalArenaVisivel(true)}
        activeOpacity={0.8}
      >
        <Text style={styles.botaoArenaEmoji}>⚔️</Text>
        <Text style={styles.botaoArenaTexto}>ARENA</Text>
      </TouchableOpacity>

      {/* Modal seleção de jogadores */}
      <ModalSelecionarJogadores
        visivel={modalArenaVisivel}
        onFechar={() => setModalArenaVisivel(false)}
        onSelecionarQuantidade={handleSelecionarQuantidade}
      />
    </ImageBackground>
  );
};

const styles = StyleSheet.create({
  background: {
    flex: 1,
    width: '100%',
    height: '100%',
    backgroundColor: '#07060bff'
  },
  perfilContainer: {
    position: 'absolute',
    top: SCREEN_HEIGHT * 0.04,
    right: SCREEN_WIDTH * 0.04,
    alignItems: 'center',
    zIndex: 10,
  },
  avatarBorda: {
    width: SCREEN_WIDTH * 0.08,
    height: SCREEN_WIDTH * 0.08,
    borderRadius: SCREEN_WIDTH * 0.04,
    borderWidth: 2,
    borderColor: '#FFD700',
    overflow: 'hidden',
  },
  avatarPerfil: {
    width: '100%',
    height: '100%',
  },
  nomeJogador: {
    color: '#FFD700',
    fontSize: 10,
    fontWeight: 'bold',
    marginTop: 4,
    textShadowColor: '#000',
    textShadowOffset: { width: 1, height: 1 },
    textShadowRadius: 2,
  },
  container: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'flex-start',
    paddingLeft: SCREEN_WIDTH * 0.05,
  },
  menuContainer: {
    alignItems: 'flex-start',
    gap: 1,
    height: '80%',
    left: 60,
    top: '15%',
  },
  botao: {
    width: SCREEN_WIDTH * 0.35,
    height: SCREEN_HEIGHT * 0.14,
  },
  botaoImagem: {
    width: '100%',
    height: '100%',
  },
  // Botão arena flutuante (canto inferior direito)
  botaoArena: {
    position: 'absolute',
    bottom: SCREEN_HEIGHT * 0.04,
    right: SCREEN_WIDTH * 0.04,
    backgroundColor: 'rgba(10,10,26,0.9)',
    borderWidth: 2,
    borderColor: '#FFD54F',
    borderRadius: 12,
    paddingHorizontal: 14,
    paddingVertical: 10,
    alignItems: 'center',
    zIndex: 20,
    shadowColor: '#FFD54F',
    shadowOffset: { width: 0, height: 0 },
    shadowOpacity: 0.5,
    shadowRadius: 8,
    elevation: 8,
  },
  botaoArenaEmoji: {
    fontSize: 22,
  },
  botaoArenaTexto: {
    color: '#FFD54F',
    fontSize: 10,
    fontWeight: 'bold',
    letterSpacing: 2,
    marginTop: 2,
  },
});

export default TelaInicial;
