import React, { useEffect, useRef, useState } from 'react';
import { View, StyleSheet } from 'react-native';
import Text from '../Texto';
import Animated, {
  useSharedValue,
  useAnimatedStyle,
  withTiming,
  withSequence,
  withSpring,
} from 'react-native-reanimated';

const DIGIT_HEIGHT = 12;
const ROLL_DURATION = 300;

function DigitoRolante({ digito, corFinal }) {
  const [valorAtual, setValorAtual] = useState('0');

  useEffect(() => {
    const alvo = parseInt(digito, 10);
    if (isNaN(alvo)) {
      setValorAtual(digito);
      return;
    }

    let frame = 0;
    const totalFrames = 12 + alvo;
    const frameDur = ROLL_DURATION / totalFrames;

    const interval = setInterval(() => {
      frame++;
      if (frame <= totalFrames) {
        setValorAtual(String(frame % 10));
      }
      if (frame >= totalFrames) {
        setValorAtual(String(alvo));
        clearInterval(interval);
      }
    }, frameDur);

    return () => clearInterval(interval);
  }, [digito]);

  if (isNaN(parseInt(digito, 10))) {
    return <Text style={[styles.digit, { color: corFinal }]}>{digito}</Text>;
  }

  return (
    <View style={styles.digitContainer}>
      <Text style={[styles.digit, { color: corFinal }]}>{valorAtual}</Text>
    </View>
  );
}

export default function ScoreRoll({ valor, duracao = 400, estilo = {} }) {
  const escala = useSharedValue(1);
  const [valorExibido, setValorExibido] = useState(String(valor));
  const valorAnterior = useRef(valor);
  const [animando, setAnimando] = useState(false);

  const animatedStyle = useAnimatedStyle(() => ({
    transform: [{ scale: escala.value }],
  }));

  useEffect(() => {
    if (valor !== valorAnterior.current) {
      valorAnterior.current = valor;
      setAnimando(true);
      setValorExibido(`R$ ${Math.abs(valor)}`);

      escala.value = withSequence(
        withTiming(1.3, { duration: 120 }),
        withSpring(1, { damping: 5, stiffness: 80 })
      );

      const timer = setTimeout(() => setAnimando(false), 300);
      return () => clearTimeout(timer);
    }
  }, [valor]);

  const corSaldo = valor > 10 ? '#66BB6A' : valor > 5 ? '#FFD54F' : '#EF5350';
  const texto = `R$ ${valor}`;

  return (
    <Animated.View style={[styles.container, estilo, animatedStyle]}>
      <Text style={styles.label}>SALDO:</Text>
      <View style={styles.rollRow}>
        {animando ? (
          texto.split('').map((ch, i) => (
            <DigitoRolante
              key={`${i}-${ch}`}
              digito={ch}
              corFinal={corSaldo}
            />
          ))
        ) : (
          <Text style={[styles.valor, { color: corSaldo }]}>{texto}</Text>
        )}
      </View>
      <Text style={styles.moeda}>🪙</Text>
    </Animated.View>
  );
}

const styles = StyleSheet.create({
  container: {
    flexDirection: 'row',
    alignItems: 'center',
  },
  label: {
    fontSize: 7,
    color: '#AAB0D0',
    fontWeight: 'bold',
    marginRight: 3,
  },
  rollRow: {
    flexDirection: 'row',
    alignItems: 'center',
    overflow: 'hidden',
  },
  digitContainer: {
    height: DIGIT_HEIGHT,
    overflow: 'hidden',
    justifyContent: 'center',
  },
  digit: {
    fontSize: 9,
    fontWeight: 'bold',
  },
  valor: {
    fontSize: 9,
    fontWeight: 'bold',
  },
  moeda: {
    fontSize: 8,
    marginLeft: 2,
  },
});
