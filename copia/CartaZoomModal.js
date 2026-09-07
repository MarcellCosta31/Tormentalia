import React, { useEffect, useRef } from 'react';
import { View, StyleSheet, Pressable, Image, Animated } from 'react-native';

const nossoImg = require('../../assets/cards/nosso.png');
const toyotinhoImg = require('../../assets/cards/toyotinho.png');

const cardImages = {
  0: nossoImg,
  1: toyotinhoImg,
};

const ZOOM_W = 200;
const ZOOM_H = 280;
const CANTO_SIZE = 8;

export default function CartaZoomModal({ carta, visivel, onFechar }) {
  const opacidade = useRef(new Animated.Value(0)).current;
  const escala = useRef(new Animated.Value(0.3)).current;
  const rotacao = useRef(new Animated.Value(0)).current;
  const overlayOpacidade = useRef(new Animated.Value(0)).current;

  useEffect(() => {
    if (visivel) {
      overlayOpacidade.setValue(0);
      opacidade.setValue(0);
      escala.setValue(0.3);
      rotacao.setValue(-5);

      Animated.parallel([
        Animated.spring(overlayOpacidade, { toValue: 1, useNativeDriver: false, friction: 8 }),
        Animated.spring(opacidade, { toValue: 1, useNativeDriver: false, friction: 6, tension: 40 }),
        Animated.spring(escala, { toValue: 1, useNativeDriver: false, friction: 6, tension: 40 }),
        Animated.spring(rotacao, { toValue: 0, useNativeDriver: false, friction: 8, tension: 30 }),
      ]).start();
    } else {
      Animated.parallel([
        Animated.timing(overlayOpacidade, { toValue: 0, duration: 200, useNativeDriver: false }),
        Animated.timing(opacidade, { toValue: 0, duration: 200, useNativeDriver: false }),
        Animated.timing(escala, { toValue: 0.5, duration: 200, useNativeDriver: false }),
        Animated.timing(rotacao, { toValue: 3, duration: 200, useNativeDriver: false }),
      ]).start();
    }
  }, [visivel]);

  if (!carta) return null;

  const imgSource = cardImages[carta.uid % 2];

  const rotateStr = rotacao.interpolate({
    inputRange: [-10, 10],
    outputRange: ['-10deg', '10deg'],
  });

  return (
    <Pressable style={styles.overlay} onPress={onFechar}>
      <Animated.View
        style={[
          styles.overlayBg,
          { opacity: overlayOpacidade },
        ]}
        pointerEvents="none"
      />
      <Animated.View
        style={[
          styles.zoomCard,
          {
            opacity: opacidade,
            transform: [
              { scale: escala },
              { rotate: rotateStr },
            ],
          },
        ]}
      >
        <Image source={imgSource} style={styles.cartaImg} resizeMode="cover" />

        <View style={[styles.canto, styles.cantoTL]} />
        <View style={[styles.canto, styles.cantoTR]} />
        <View style={[styles.canto, styles.cantoBL]} />
        <View style={[styles.canto, styles.cantoBR]} />
      </Animated.View>
    </Pressable>
  );
}

const styles = StyleSheet.create({
  overlay: {
    ...StyleSheet.absoluteFillObject,
    zIndex: 300,
    alignItems: 'center',
    justifyContent: 'center',
  },
  overlayBg: {
    ...StyleSheet.absoluteFillObject,
    backgroundColor: '#000',
  },
  zoomCard: {
    width: ZOOM_W,
    height: ZOOM_H,
    borderRadius: 8,
    borderWidth: 2.5,
    borderColor: '#FFD54F',
    overflow: 'hidden',
    shadowColor: '#000',
    shadowOffset: { width: 4, height: 4 },
    shadowOpacity: 0.8,
    shadowRadius: 8,
    elevation: 30,
  },
  cartaImg: {
    width: '100%',
    height: '100%',
  },
  canto: {
    position: 'absolute',
    width: CANTO_SIZE,
    height: CANTO_SIZE,
    borderColor: '#FFD54F',
  },
  cantoTL: { top: -2, left: -2, borderTopWidth: 2, borderLeftWidth: 2 },
  cantoTR: { top: -2, right: -2, borderTopWidth: 2, borderRightWidth: 2 },
  cantoBL: { bottom: -2, left: -2, borderBottomWidth: 2, borderLeftWidth: 2 },
  cantoBR: { bottom: -2, right: -2, borderBottomWidth: 2, borderRightWidth: 2 },
});
