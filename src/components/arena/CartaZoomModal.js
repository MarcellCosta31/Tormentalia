import React, { useEffect } from 'react';
import { View, StyleSheet, Pressable, Image } from 'react-native';
import Animated, {
  useSharedValue,
  useAnimatedStyle,
  withTiming,
  withSpring,
} from 'react-native-reanimated';

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
  const opacidade = useSharedValue(0);
  const escala = useSharedValue(0.3);
  const rotacao = useSharedValue(0);
  const overlayOpacidade = useSharedValue(0);

  const overlayStyle = useAnimatedStyle(() => ({
    opacity: overlayOpacidade.value,
  }));

  const cardStyle = useAnimatedStyle(() => ({
    opacity: opacidade.value,
    transform: [
      { scale: escala.value },
      { rotate: `${rotacao.value}deg` },
    ],
  }));

  useEffect(() => {
    if (visivel) {
      overlayOpacidade.value = 0;
      opacidade.value = 0;
      escala.value = 0.3;
      rotacao.value = -5;

      overlayOpacidade.value = withSpring(1, { damping: 8 });
      opacidade.value = withSpring(1, { damping: 6, stiffness: 40 });
      escala.value = withSpring(1, { damping: 6, stiffness: 40 });
      rotacao.value = withSpring(0, { damping: 8, stiffness: 30 });
    } else {
      overlayOpacidade.value = withTiming(0, { duration: 200 });
      opacidade.value = withTiming(0, { duration: 200 });
      escala.value = withTiming(0.5, { duration: 200 });
      rotacao.value = withTiming(3, { duration: 200 });
    }
  }, [visivel]);

  if (!carta) return null;

  const imgSource = cardImages[carta.uid % 2];

  return (
    <Pressable style={styles.overlay} onPress={onFechar}>
      <Animated.View
        style={[styles.overlayBg, overlayStyle]}
        pointerEvents="none"
      />
      <Animated.View style={[styles.zoomCard, cardStyle]}>
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
