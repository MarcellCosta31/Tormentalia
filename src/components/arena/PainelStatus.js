import React, { useEffect, useRef } from 'react';
import { View, Text, StyleSheet } from 'react-native';
import Animated, {
  useSharedValue,
  useAnimatedStyle,
  withTiming,
  withSequence,
  withSpring,
  withRepeat,
} from 'react-native-reanimated';
import ScoreRoll from './ScoreRoll';

const CANTO_SIZE = 6;

export default function PainelStatus({ nome, saldo, corDestaque = '#D4AF6A' }) {
  const scaleAnim = useSharedValue(1);
  const shakeX = useSharedValue(0);
  const prevSaldo = useRef(saldo);

  const animatedStyle = useAnimatedStyle(() => ({
    transform: [{ scale: scaleAnim.value }, { translateX: shakeX.value }],
  }));

  useEffect(() => {
    if (saldo !== prevSaldo.current) {
      const diff = saldo - prevSaldo.current;

      scaleAnim.value = withSequence(
        withTiming(1.08, { duration: 100 }),
        withSpring(1, { damping: 5, stiffness: 80 })
      );

      if (diff < 0) {
        shakeX.value = withSequence(
          withTiming(4, { duration: 30 }),
          withTiming(-4, { duration: 30 }),
          withTiming(2, { duration: 30 }),
          withTiming(0, { duration: 30 })
        );
      }

      prevSaldo.current = saldo;
    }
  }, [saldo]);

  return (
    <Animated.View style={[styles.container, animatedStyle]}>
      <View style={[styles.avatarBox, { borderColor: corDestaque }]}>
        <Text style={styles.avatarEmoji}>👨‍💼</Text>
      </View>

      <View style={styles.infoColuna}>
        <Text style={styles.nome} numberOfLines={1}>{nome?.toUpperCase() || 'JOGADOR'}</Text>
        <ScoreRoll valor={saldo} />
      </View>

      <View style={[styles.canto, styles.cantoTL]} />
      <View style={[styles.canto, styles.cantoTR]} />
      <View style={[styles.canto, styles.cantoBL]} />
      <View style={[styles.canto, styles.cantoBR]} />
    </Animated.View>
  );
}

const styles = StyleSheet.create({
  container: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: '#0F1322',
    borderWidth: 1.5,
    borderColor: '#7A5C29',
    borderRadius: 5,
    paddingVertical: 3,
    paddingHorizontal: 6,
    minWidth: 130,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.6,
    shadowRadius: 3,
    elevation: 5,
  },
  avatarBox: {
    width: 28,
    height: 28,
    borderRadius: 3,
    borderWidth: 1.5,
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: '#1C2238',
    marginRight: 6,
  },
  avatarEmoji: {
    fontSize: 14,
  },
  infoColuna: {
    flex: 1,
    justifyContent: 'center',
  },
  nome: {
    fontSize: 8,
    color: '#F0F3FF',
    fontWeight: 'bold',
    letterSpacing: 0.5,
    marginBottom: 1,
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
