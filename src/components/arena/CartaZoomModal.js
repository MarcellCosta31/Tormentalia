import React, { useEffect } from 'react';
import { View, StyleSheet, Pressable, Image } from 'react-native';
import Animated, {
  useSharedValue,
  useAnimatedStyle,
  withTiming,
  withSpring,
} from 'react-native-reanimated';
import { artePorCarta, temArte } from '../../cards/arteCarta';
import { CartaFaceCompleta } from './CartaFace';

const ZOOM_W = 200;
const ZOOM_H = 280;
const CANTO_SIZE = 8;

export default function CartaZoomModal({ carta, visivel, onFechar }) {
  const opacidade = useSharedValue(0);
  const escala = useSharedValue(0.5);
  const overlayOpacidade = useSharedValue(0);

  const overlayStyle = useAnimatedStyle(() => ({
    opacity: overlayOpacidade.value,
  }));

  const cardStyle = useAnimatedStyle(() => ({
    opacity: opacidade.value,
    transform: [
      { scale: escala.value },
    ],
  }));

  useEffect(() => {
    if (visivel) {
      overlayOpacidade.value = 0;
      opacidade.value = 0;
      escala.value = 0.5;

      overlayOpacidade.value = withTiming(1, { duration: 200 });
      opacidade.value = withTiming(1, { duration: 200 });
      escala.value = withSpring(1, { damping: 15, stiffness: 120 });
    } else {
      overlayOpacidade.value = withTiming(0, { duration: 200 });
      opacidade.value = withTiming(0, { duration: 200 });
      escala.value = withTiming(0.5, { duration: 150 });
    }
  }, [visivel]);

  if (!carta) return null;

  const imgSource = artePorCarta(carta);

  return (
    <Pressable style={styles.overlay} onPress={onFechar}>
      <Animated.View
        style={[styles.overlayBg, overlayStyle]}
        pointerEvents="none"
      />
      <Animated.View style={[styles.zoomCard, cardStyle]}>
        {temArte(carta) ? (
          <Image source={imgSource} style={styles.cartaImg} resizeMode="cover" />
        ) : (
          <CartaFaceCompleta carta={carta} style={styles.cartaImg} />
        )}

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
