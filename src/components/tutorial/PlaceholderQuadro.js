import React from 'react';
import { View, Image, StyleSheet, Dimensions } from 'react-native';
import Text from '../Texto';
import logLayout from '../../utils/logLayout';

const { width: SCREEN_WIDTH } = Dimensions.get('window');

// Area da imagem: 16:9 (mesma proporcao da arte definitiva).
export const LARGURA_QUADRO = SCREEN_WIDTH * 0.94;
export const ALTURA_QUADRO = (LARGURA_QUADRO * 9) / 16;

// Quadro da cutscene. Se quadro.image existir, mostra a arte; caso contrario
// mostra o placeholder temporario com id estavel + descricao do que deve
// entrar ali. Trocar a arte futuramente nao mexe em logica nenhuma.
export default function PlaceholderQuadro({ quadro }) {
  if (quadro.image) {
    return (
      <View style={styles.area} onLayout={logLayout('arte')}>
        <Image source={quadro.image} style={styles.arte} resizeMode="cover" />
      </View>
    );
  }

  return (
    <View style={styles.area} onLayout={logLayout('arte')}>
      <View style={styles.placeholder}>
        <Text style={styles.id}>{quadro.id}</Text>
        <Text style={styles.numero} numberOfLines={1} adjustsFontSizeToFit minimumFontScale={0.6}>
          QUADRO {String(quadro.numero).padStart(2, '0')}
        </Text>
        <Text style={styles.titulo} numberOfLines={2} adjustsFontSizeToFit minimumFontScale={0.6}>
          {quadro.titulo}
        </Text>
        <View style={styles.linha} />
        <Text style={styles.descricao} numberOfLines={7} adjustsFontSizeToFit minimumFontScale={0.5}>
          {quadro.descricao}
        </Text>
        <Text style={styles.aviso}>PLACEHOLDER — IMAGEM 16:9 A SER INSERIDA</Text>
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  area: {
    width: LARGURA_QUADRO,
    height: ALTURA_QUADRO,
    alignSelf: 'center',
  },
  arte: {
    width: '100%',
    height: '100%',
    borderRadius: 6,
  },
  placeholder: {
    flex: 1,
    backgroundColor: '#101018',
    borderWidth: 1,
    borderColor: '#3A3A52',
    borderStyle: 'dashed',
    borderRadius: 6,
    alignItems: 'center',
    justifyContent: 'center',
    paddingHorizontal: 14,
    paddingVertical: 8,
    overflow: 'hidden',
  },
  id: {
    position: 'absolute',
    top: 6,
    left: 8,
    color: '#5A5A78',
    fontSize: 9,
  },
  numero: {
    color: '#FFD54F',
    fontSize: 26,
    letterSpacing: 4,
    marginBottom: 4,
  },
  titulo: {
    color: '#E8E8F2',
    fontSize: 13,
    letterSpacing: 1,
    textAlign: 'center',
    marginBottom: 6,
  },
  linha: {
    width: '55%',
    height: 1,
    backgroundColor: '#3A3A52',
    marginBottom: 6,
  },
  descricao: {
    color: '#9B9BB4',
    fontSize: 10,
    lineHeight: 14,
    textAlign: 'center',
    flexShrink: 1,
  },
  aviso: {
    position: 'absolute',
    bottom: 6,
    right: 8,
    color: '#5A5A78',
    fontSize: 8,
    letterSpacing: 1,
  },
});
