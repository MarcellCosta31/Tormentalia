import React from 'react';
import { View, StyleSheet, Image } from 'react-native';
import { artePorCarta, TRASEIRA, temArte } from '../../cards/arteCarta';
import { CartaFaceMini } from './CartaFace';

const BORDER_COLORS = ['#2196F3', '#E53935', '#FFB300', '#4CAF50', '#00ACC1', '#9C27B0'];

export default function CartaArena({ carta, onPress, selecionada, desabilitada, oculta, largura, altura }) {
  if (oculta || !carta) {
    return (
      <View style={[styles.carta, styles.cartaOculta, largura && { width: largura }, altura && { height: altura }]}>
        <Image source={TRASEIRA} style={styles.cartaImgOculta} resizeMode="cover" />
      </View>
    );
  }

  const imgSource = artePorCarta(carta);
  const colorIndex = Math.abs(carta.uid || 0) % BORDER_COLORS.length;
  const borderColor = BORDER_COLORS[colorIndex];

  return (
    <View
      style={[
        styles.carta,
        { borderColor },
        selecionada && styles.cartaSelecionada,
        desabilitada && styles.cartaDesabilitada,
        largura && { width: largura },
        altura && { height: altura },
        largura && { marginHorizontal: 0 },
        altura && { marginVertical: 0 },
      ]}
      onTouchEnd={() => {
        if (!desabilitada && onPress) onPress(carta);
      }}
    >
      <View style={styles.innerBorder}>
        {temArte(carta) ? (
          <Image source={imgSource} style={styles.cartaImg} resizeMode="cover" />
        ) : (
          <CartaFaceMini carta={carta} style={styles.cartaImg} />
        )}
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  carta: {
    width: 68,
    height: 96,
    borderRadius: 6,
    backgroundColor: '#1E1E2E',
    borderWidth: 3,
    marginHorizontal: 2,
    overflow: 'hidden',
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 3 },
    shadowOpacity: 0.5,
    shadowRadius: 4,
    elevation: 6,
  },
  innerBorder: {
    flex: 1,
    borderWidth: 1.5,
    borderColor: '#FFF',
    borderRadius: 4,
    overflow: 'hidden',
    position: 'relative',
  },
  cartaImg: {
    width: '100%',
    height: '100%',
  },
  cartaSelecionada: {
    borderColor: '#FFF',
    borderWidth: 4,
  },
  cartaDesabilitada: {
    opacity: 0.4,
  },
  cartaOculta: {
    backgroundColor: '#1B2035',
    borderColor: '#FAD02C',
    borderWidth: 2,
  },
  cartaImgOculta: {
    width: '100%',
    height: '100%',
  },
});


