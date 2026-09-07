import React from 'react';
import { View, StyleSheet, Image } from 'react-native';
import PainelStatus from './PainelStatus';

const traseiraImg = require('../../assets/cards/traseira_cartas.jpg');

const CARD_W = 48;
const CARD_H = 68;
const OVERLAP = 22;

export default function MaoOponente({ jogador, hideStatus = false }) {
  if (!jogador) return null;
  const numCartas = jogador.mao?.length || 0;

  return (
    <View style={styles.container}>
      {!hideStatus && <PainelStatus nome={jogador.nome} saldo={jogador.saldo} corDestaque="#FFD54F" />}

      <View style={[styles.fanContainer, { width: CARD_W + Math.max(numCartas - 1, 0) * OVERLAP }]}>
        {Array.from({ length: numCartas }).map((_, index) => {
          const offsetFromCenter = index - (numCartas - 1) / 2;
          const angle = offsetFromCenter * 6;
          return (
            <View
              key={index}
              style={[
                styles.cartaWrapper,
                {
                  left: index * OVERLAP,
                  transform: [{ rotate: `${angle}deg` }],
                  zIndex: index,
                },
              ]}
            >
              <Image
                source={traseiraImg}
                resizeMode="cover"
                style={styles.carta}
              />
            </View>
          );
        })}
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    alignItems: 'center',
  },
  fanContainer: {
    height: CARD_H + 14,
    marginTop: 4,
    position: 'relative',
    alignSelf: 'center',
  },
  cartaWrapper: {
    position: 'absolute',
    top: 0,
    width: CARD_W,
    height: CARD_H,
    borderRadius: 5,
    borderWidth: 1.5,
    borderColor: '#FFD54F',
    overflow: 'hidden',
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 3 },
    shadowOpacity: 0.5,
    shadowRadius: 3,
    elevation: 4,
  },
  carta: {
    width: '100%',
    height: '100%',
  },
});

