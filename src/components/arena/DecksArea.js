import React, { useCallback } from 'react';
import { View, StyleSheet, Image } from 'react-native';
import { artePorCarta, TRASEIRA, temArte } from '../../cards/arteCarta';
import { CartaFaceMini } from './CartaFace';

const DRAW_W = 50;
const DRAW_H = 70;
const DESC_W = 64;
const DESC_H = 90;

export default function DecksArea({ baralho, pilhaDescarte, onLayout }) {
  const qtdBaralho = baralho?.length || 0;
  const qtdDescarte = pilhaDescarte?.length || 0;
  const drawPosRef = React.useRef(null);
  const descPosRef = React.useRef(null);

  const handleDrawLayout = useCallback((e) => {
    const { x, y } = e.nativeEvent.layout;
    drawPosRef.current = { x, y };
    if (drawPosRef.current && descPosRef.current && onLayout) {
      onLayout(drawPosRef.current.x, drawPosRef.current.y, descPosRef.current.x, descPosRef.current.y);
    }
  }, [onLayout]);

  const handleDescarteLayout = useCallback((e) => {
    const { x, y } = e.nativeEvent.layout;
    descPosRef.current = { x, y };
    if (drawPosRef.current && descPosRef.current && onLayout) {
      onLayout(drawPosRef.current.x, drawPosRef.current.y, descPosRef.current.x, descPosRef.current.y);
    }
  }, [onLayout]);

  const cartaTopoDescarte = qtdDescarte > 0 ? pilhaDescarte[qtdDescarte - 1] : null;

  return (
    <View style={styles.container}>
      {/* Baralho de compra (Left Deck) */}
      <View style={styles.deckGroup} onLayout={handleDrawLayout}>
        <View style={[styles.deckPile, styles.drawPile]}>
          {qtdBaralho > 2 && <Image source={TRASEIRA} style={[styles.cardStack, styles.drawStack, styles.stack3]} resizeMode="cover" />}
          {qtdBaralho > 1 && <Image source={TRASEIRA} style={[styles.cardStack, styles.drawStack, styles.stack2]} resizeMode="cover" />}
          {qtdBaralho > 0 && <Image source={TRASEIRA} style={[styles.cardStack, styles.drawStack, styles.stack1]} resizeMode="cover" />}
          {qtdBaralho === 0 && <View style={[styles.cardStack, styles.drawStack, styles.stack1, styles.deckVazio]} />}
        </View>
      </View>

      {/* Pilha de Descarte (Right Deck) */}
      <View style={styles.deckGroup} onLayout={handleDescarteLayout}>
        <View style={[styles.deckPile, styles.descPile]}>
          {cartaTopoDescarte ? (
            <>
              {qtdDescarte > 2 && <Image source={TRASEIRA} style={[styles.cardStack, styles.descStack, styles.stack3]} resizeMode="cover" />}
              {qtdDescarte > 1 && <Image source={TRASEIRA} style={[styles.cardStack, styles.descStack, styles.stack2]} resizeMode="cover" />}
              {temArte(cartaTopoDescarte) ? (
                <Image
                  source={artePorCarta(cartaTopoDescarte)}
                  style={[styles.cardStack, styles.descStack, styles.stack1]}
                  resizeMode="cover"
                />
              ) : (
                <CartaFaceMini
                  carta={cartaTopoDescarte}
                  style={[styles.cardStack, styles.descStack, styles.stack1]}
                />
              )}
            </>
          ) : (
            <View style={[styles.cardStack, styles.descStack, styles.stack1, styles.deckVazio]} />
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
    position: 'relative',
    justifyContent: 'center',
  },
  drawPile: {
    width: DRAW_W,
    height: DRAW_H,
  },
  descPile: {
    width: DESC_W,
    height: DESC_H,
  },
  cardStack: {
    position: 'absolute',
    borderRadius: 6,
    borderWidth: 1.5,
    borderColor: '#FAD02C',
  },
  drawStack: {
    width: DRAW_W,
    height: DRAW_H,
  },
  descStack: {
    width: DESC_W,
    height: DESC_H,
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


