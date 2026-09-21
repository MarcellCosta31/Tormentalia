import React, { useEffect, useRef, useState } from 'react';
import { View, Text, StyleSheet } from 'react-native';
import Animated, {
  useSharedValue,
  useAnimatedStyle,
  withTiming,
  withSequence,
  withDelay,
  withSpring,
} from 'react-native-reanimated';
import { soundManager } from '../../utils/sound';

function PopupIndividual({ valor, x, y, delay = 0, onCompleto }) {
  const translateY = useSharedValue(0);
  const escala = useSharedValue(0);
  const opacidade = useSharedValue(0);
  const [visivel, setVisivel] = useState(false);

  const isPositivo = valor > 0;
  const cor = isPositivo ? '#66BB6A' : '#EF5350';
  const sinal = isPositivo ? '+' : '';
  const texto = `${sinal}R$ ${Math.abs(valor)}`;

  const animatedStyle = useAnimatedStyle(() => ({
    left: x,
    top: y,
    opacity: opacidade.value,
    transform: [{ translateY: translateY.value }, { scale: escala.value }],
  }));

  useEffect(() => {
    const timer = setTimeout(() => {
      setVisivel(true);
      if (isPositivo) {
        soundManager.playScoreGain();
      } else {
        soundManager.playScoreLose();
      }

      escala.value = withSequence(
        withSpring(1.2, { damping: 5, stiffness: 80 }),
        withSpring(1, { damping: 6, stiffness: 40 })
      );
      opacidade.value = withSequence(
        withTiming(1, { duration: 100 }),
        withDelay(800, withTiming(0, { duration: 400 }))
      );
      translateY.value = withTiming(-80, { duration: 1200 });
    }, delay);

    return () => clearTimeout(timer);
  }, []);

  if (!visivel) return null;

  return (
    <Animated.View style={[styles.popup, animatedStyle]}>
      <Text style={[styles.texto, { color: cor, textShadowColor: cor }]}>
        {texto}
      </Text>
    </Animated.View>
  );
}

export default function ScorePopup({ alteracoes = [], onCompleto }) {
  const [popups, setPopups] = useState([]);

  useEffect(() => {
    if (!alteracoes || alteracoes.length === 0) return;

    const novos = alteracoes.map((a, i) => ({
      id: `sp_${Date.now()}_${i}`,
      valor: a.valor,
      x: a.x || 0,
      y: a.y || 0,
      delay: i * 200,
    }));

    setPopups(novos);

    const timeout = setTimeout(() => {
      setPopups([]);
      if (onCompleto) onCompleto();
    }, 2500);

    return () => clearTimeout(timeout);
  }, [alteracoes]);

  if (popups.length === 0) return null;

  return (
    <View style={styles.container} pointerEvents="none">
      {popups.map((p) => (
        <PopupIndividual
          key={p.id}
          valor={p.valor}
          x={p.x}
          y={p.y}
          delay={p.delay}
        />
      ))}
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    ...StyleSheet.absoluteFillObject,
    zIndex: 250,
  },
  popup: {
    position: 'absolute',
    alignItems: 'center',
  },
  texto: {
    fontSize: 20,
    fontWeight: 'bold',
    fontFamily: 'monospace',
    textShadowOffset: { width: 0, height: 0 },
    textShadowRadius: 8,
  },
});
