import React, { useCallback } from 'react';
import { View, StyleSheet, Image } from 'react-native';

const traseiraImg = require('../../assets/cards/traseira_cartas.jpg');
const nossoImg = require('../../assets/cards/nosso.png');
const toyotinhoImg = require('../../assets/cards/toyotinho.png');

const cardImages = {
  0: nossoImg,
  1: toyotinhoImg,
};

const DECK_WIDTH = 58;
const DECK_HEIGHT = 81;

export default function DecksArea({ baralho, pilhaDescarte, onLayout }) {
  const qtdBaralho = baralho?.length || 0;
  const qtdDescarte = pilhaDescarte?.length || 0;

  const handleDrawLayout = useCallback((e) => {
    const { x, y } = e.nativeEvent.layout;
    if (onLayout) onLayout(x, y, 0, 0);
  }, [onLayout]);

  const handleDescarteLayout = useCallback((e) => {
    const { x, y } = e.nativeEvent.layout;
    if (onLayout) onLayout(0, 0, x, y);
  }, [onLayout]);

  return (
    <View style={styles.container}>
      {/* Baralho de compra (Left Deck) */}
      <View style={styles.deckGroup} onLayout={handleDrawLayout}>
        <View style={styles.deckPile}>
          {qtdBaralho > 2 && <Image source={traseiraImg} style={[styles.cardStack, styles.stack3]} resizeMode="cover" />}
          {qtdBaralho > 1 && <Image source={traseiraImg} style={[styles.cardStack, styles.stack2]} resizeMode="cover" />}
          {qtdBaralho > 0 && <Image source={traseiraImg} style={[styles.cardStack, styles.stack1]} resizeMode="cover" />}
          {qtdBaralho === 0 && <View style={[styles.cardStack, styles.stack1, styles.deckVazio]} />}
        </View>
      </View>

      {/* Pilha de Descarte (Right Deck) */}
      <View style={styles.deckGroup} onLayout={handleDescarteLayout}>
        <View style={styles.deckPile}>
          {qtdDescarte > 0 ? (
            <>
              {qtdDescarte > 2 && <Image source={traseiraImg} style={[styles.cardStack, styles.stack3]} resizeMode="cover" />}
              {qtdDescarte > 1 && <Image source={traseiraImg} style={[styles.cardStack, styles.stack2]} resizeMode="cover" />}
              <Image
                source={cardImages[pilhaDescarte[pilhaDescarte.length - 1].uid % 2]}
                style={[styles.cardStack, styles.stack1]}
                resizeMode="cover"
              />
            </>
          ) : (
            <View style={[styles.cardStack, styles.stack1, styles.deckVazio]} />
          )}
        </View>
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flexDirection: 'row',
    justifyContent: 'center',
    alignItems: 'center',
    gap: 36,
    paddingVertical: 6,
  },
  deckGroup: {
    alignItems: 'center',
  },
  deckPile: {
    width: DECK_WIDTH,
    height: DECK_HEIGHT,
    position: 'relative',
    justifyContent: 'center',
  },
  cardStack: {
    width: DECK_WIDTH,
    height: DECK_HEIGHT,
    borderRadius: 6,
    position: 'absolute',
    borderWidth: 1.5,
    borderColor: '#FAD02C',
  },
  stack1: {
    top: 0,
    left: 0,
  },
  stack2: {
    top: -3,
    left: 2,
  },
  stack3: {
    top: -6,
    left: 4,
  },
  deckVazio: {
    borderWidth: 2,
    borderColor: '#777',
    borderStyle: 'dashed',
    backgroundColor: 'rgba(30, 30, 50, 0.4)',
  },
});


