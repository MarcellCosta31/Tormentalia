import React, { useEffect, useRef, useState } from 'react';
import { View, StyleSheet } from 'react-native';
import Animated, {
  useSharedValue,
  useAnimatedStyle,
  withTiming,
  withSequence,
  withDelay,
  withSpring,
} from 'react-native-reanimated';
import { soundManager } from '../../utils/sound';

const DEFAULT_CORES = ['#FFD54F', '#4CAF50', '#42A5F5', '#EF5350', '#FF9800', '#AB47BC'];
const NUM_PARTICLES = 10;

function Particula({ x, y, config, onComplete }) {
  const animX = useSharedValue(0);
  const animY = useSharedValue(0);
  const animOpacidade = useSharedValue(1);
  const animEscala = useSharedValue(1);

  const style = useAnimatedStyle(() => ({
    left: x,
    top: y,
    width: config.tamanho,
    height: config.tamanho,
    borderRadius: config.tamanho / 2,
    backgroundColor: config.cor,
    opacity: animOpacidade.value,
    transform: [
      { translateX: animX.value },
      { translateY: animY.value },
      { scale: animEscala.value },
    ],
  }));

  useEffect(() => {
    const angulo = config.angulo + (Math.random() - 0.5) * 0.5;
    const distancia = config.distancia * (0.6 + Math.random() * 0.8);
    const destinoX = Math.cos(angulo) * distancia;
    const destinoY = Math.sin(angulo) * distancia - config.gravidade;

    animX.value = withTiming(destinoX, { duration: config.duracao });
    animY.value = withTiming(destinoY, { duration: config.duracao });
    animOpacidade.value = withSequence(
      withDelay(config.duracao * 0.6, withTiming(0, { duration: config.duracao * 0.4 }))
    );
    animEscala.value = withSequence(
      withTiming(1.5, { duration: config.duracao * 0.3 }),
      withTiming(0, { duration: config.duracao * 0.7 })
    );

    const timer = setTimeout(() => {
      if (onComplete) onComplete();
    }, config.duracao);

    return () => clearTimeout(timer);
  }, []);

  return <Animated.View style={[styles.particula, style]} />;
}

export default function ParticleBurst({ x, y, cores, numParticulas = NUM_PARTICLES, visivel = false, onCompleto }) {
  const [particulas, setParticulas] = useState([]);
  const contador = useRef(0);

  useEffect(() => {
    if (!visivel) return;

    soundManager.playParticleBurst();

    const coresUsadas = cores || DEFAULT_CORES;
    const novasParticulas = Array.from({ length: numParticulas }).map((_, i) => ({
      id: `p_${Date.now()}_${i}`,
      config: {
        angulo: (Math.PI * 2 * i) / numParticulas + (Math.random() - 0.5) * 0.3,
        distancia: 40 + Math.random() * 60,
        duracao: 500 + Math.random() * 400,
        cor: coresUsadas[Math.floor(Math.random() * coresUsadas.length)],
        tamanho: 4 + Math.random() * 6,
        gravidade: 20 + Math.random() * 30,
      },
    }));

    setParticulas(novasParticulas);
    contador.current = 0;

    const timeout = setTimeout(() => {
      setParticulas([]);
      if (onCompleto) onCompleto();
    }, 1200);

    return () => clearTimeout(timeout);
  }, [visivel, x, y]);

  if (!visivel || particulas.length === 0) return null;

  return (
    <View style={styles.container} pointerEvents="none">
      {particulas.map((p) => (
        <Particula
          key={p.id}
          x={x}
          y={y}
          config={p.config}
          onComplete={() => {
            contador.current++;
          }}
        />
      ))}
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    ...StyleSheet.absoluteFillObject,
    zIndex: 200,
  },
  particula: {
    position: 'absolute',
  },
});
