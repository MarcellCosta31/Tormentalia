import React, { useEffect, useRef, useState } from 'react';
import { View, Text, StyleSheet, Dimensions } from 'react-native';
import Animated, {
  useSharedValue,
  useAnimatedStyle,
  withTiming,
  withSequence,
  withDelay,
  withSpring,
  withRepeat,
  interpolate,
} from 'react-native-reanimated';
import { soundManager } from '../../utils/sound';

const { width: SCREEN_WIDTH, height: SCREEN_HEIGHT } = Dimensions.get('window');

const NUM_RAIOS = 12;
const NUM_CONFETES = 18;
const CORES_CONFETE = ['#FFD54F', '#4CAF50', '#42A5F5', '#EF5350', '#FFFFFF'];

const CONFETES_CONFIG = Array.from({ length: NUM_CONFETES }).map(() => ({
  x: (Math.random() - 0.5) * SCREEN_WIDTH * 0.9,
  atraso: Math.random() * 250,
  duracao: 900 + Math.random() * 500,
  rotacaoFinal: (Math.random() > 0.5 ? 1 : -1) * (360 + Math.random() * 360),
  cor: CORES_CONFETE[Math.floor(Math.random() * CORES_CONFETE.length)],
  tamanho: 6 + Math.random() * 5,
}));

function ConfetePeca({ config, index, startAnim }) {
  const progresso = useSharedValue(0);

  const style = useAnimatedStyle(() => {
    const translateY = interpolate(progresso.value, [0, 1], [-40, SCREEN_HEIGHT * 0.7]);
    const rotate = interpolate(progresso.value, [0, 1], [0, config.rotacaoFinal]);
    const opacity = interpolate(progresso.value, [0, 0.85, 1], [1, 1, 0]);

    return {
      position: 'absolute',
      top: 0,
      left: SCREEN_WIDTH / 2 + config.x,
      width: config.tamanho,
      height: config.tamanho * 1.6,
      backgroundColor: config.cor,
      borderRadius: 1,
      opacity,
      transform: [{ translateY }, { rotate: `${rotate}deg` }],
    };
  });

  useEffect(() => {
    if (startAnim) {
      progresso.value = withDelay(
        config.atraso,
        withTiming(1, { duration: config.duracao })
      );
    }
  }, [startAnim]);

  return <Animated.View style={style} />;
}

export default function AnimacaoInicioBatalha({ jogadorAtivoIndex, nomeJogador, nomeOponente, onCompleto }) {
  const [fase, setFase] = useState('intro');
  const [completado, setCompletado] = useState(false);
  const [startConfetti, setStartConfetti] = useState(false);

  const overlayOpacity = useSharedValue(0);
  const perguntaOpacity = useSharedValue(0);
  const perguntaScale = useSharedValue(0.5);
  const moedaScale = useSharedValue(0);
  const moedaRotation = useSharedValue(0);
  const resultadoOpacity = useSharedValue(0);
  const resultadoScale = useSharedValue(0.3);
  const flashOpacity = useSharedValue(0);
  const glowPulse = useSharedValue(0.3);
  const raiosRotation = useSharedValue(0);
  const shakeX = useSharedValue(0);

  const isJogadorHumano = jogadorAtivoIndex === 0;
  const vencedor = isJogadorHumano ? nomeJogador : nomeOponente;
  const corTema = isJogadorHumano ? '#4CAF50' : '#FFD54F';

  const overlayStyle = useAnimatedStyle(() => ({
    opacity: overlayOpacity.value,
    transform: [{ translateX: shakeX.value }],
  }));

  const flashStyle = useAnimatedStyle(() => ({
    opacity: flashOpacity.value,
  }));

  const raiosStyle = useAnimatedStyle(() => ({
    transform: [{ rotate: `${interpolate(raiosRotation.value, [0, 1], [0, 360])}deg` }],
  }));

  const perguntaStyle = useAnimatedStyle(() => ({
    opacity: perguntaOpacity.value,
    transform: [{ scale: perguntaScale.value }],
  }));

  const glowStyle = useAnimatedStyle(() => ({
    opacity: interpolate(glowPulse.value, [0, 1], [0.25, 0.55]),
    backgroundColor: fase === 'resultado' ? `${corTema}55` : 'rgba(255, 213, 79, 0.3)',
  }));

  const moedaStyle = useAnimatedStyle(() => ({
    transform: [
      { scale: moedaScale.value },
      { rotateY: `${interpolate(moedaRotation.value, [0, 1, 2, 3, 4, 5], [0, 360, 720, 1080, 1440, 1800])}deg` },
    ],
  }));

  const resultadoStyle = useAnimatedStyle(() => ({
    opacity: resultadoOpacity.value,
    transform: [{ scale: resultadoScale.value }],
  }));

  useEffect(() => {
    soundManager.init();

    raiosRotation.value = withRepeat(
      withTiming(1, { duration: 8000 }),
      -1,
      false
    );

    glowPulse.value = withRepeat(
      withSequence(
        withTiming(1, { duration: 900 }),
        withTiming(0.3, { duration: 900 })
      ),
      -1,
      false
    );

    overlayOpacity.value = withTiming(1, { duration: 400 });
    perguntaOpacity.value = withTiming(1, { duration: 500 });
    perguntaScale.value = withSpring(1, { damping: 6, stiffness: 40 });

    const timerFase = setTimeout(() => {
      setFase('flip');
    }, 1100);

    return () => clearTimeout(timerFase);
  }, []);

  useEffect(() => {
    if (fase !== 'flip') return;

    perguntaOpacity.value = withTiming(0, { duration: 200 });

    soundManager.playFlip();
    moedaScale.value = withSpring(1, { damping: 5, stiffness: 60 });
    moedaRotation.value = withTiming(5, { duration: 1100 });

    const timerFase = setTimeout(() => {
      setFase('resultado');
    }, 1300);

    return () => clearTimeout(timerFase);
  }, [fase]);

  useEffect(() => {
    if (fase !== 'resultado') return;

    setTimeout(() => {
      soundManager.playVictory();
    }, 100);

    shakeX.value = withSequence(
      withTiming(8, { duration: 40 }),
      withTiming(-8, { duration: 40 }),
      withTiming(5, { duration: 40 }),
      withTiming(0, { duration: 40 })
    );

    setStartConfetti(true);

    flashOpacity.value = withSequence(
      withTiming(0.85, { duration: 90 }),
      withTiming(0, { duration: 250 })
    );
    resultadoScale.value = withSpring(1, { damping: 5, stiffness: 50 });
    resultadoOpacity.value = withTiming(1, { duration: 300 });

    const timerFase = setTimeout(() => {
      overlayOpacity.value = withTiming(0, { duration: 500 });
      setTimeout(() => setCompletado(true), 500);
    }, 1800);

    return () => clearTimeout(timerFase);
  }, [fase]);

  useEffect(() => {
    if (completado && onCompleto) {
      onCompleto();
    }
  }, [completado]);

  return (
    <Animated.View
      style={[styles.overlay, overlayStyle]}
      pointerEvents="auto"
    >
      <Animated.View style={[styles.flash, flashStyle]} />

      <Animated.View
        style={[styles.raiosContainer, raiosStyle]}
        pointerEvents="none"
      >
        {Array.from({ length: NUM_RAIOS }).map((_, i) => (
          <View
            key={i}
            style={[
              styles.raio,
              { transform: [{ rotate: `${(360 / NUM_RAIOS) * i}deg` }] },
            ]}
          />
        ))}
      </Animated.View>

      {fase === 'intro' && (
        <Animated.View style={[styles.perguntaContainer, perguntaStyle]}>
          <Text style={styles.perguntaTexto}>QUEM COMEÇA</Text>
          <Text style={styles.perguntaTextoDestaque}>A BATALHA?</Text>
        </Animated.View>
      )}

      {(fase === 'flip' || fase === 'resultado') && (
        <View style={styles.moedaContainer}>
          <Animated.View style={[styles.glow, glowStyle]} />
          <Animated.View style={[styles.moeda, moedaStyle]}>
            <View style={styles.moedaBorda}>
              <View style={styles.moedaMiolo}>
                <Text style={styles.moedaSimbolo}>
                  {fase === 'resultado' ? (isJogadorHumano ? '👤' : '🤖') : '$'}
                </Text>
              </View>
            </View>
          </Animated.View>
        </View>
      )}

      {fase === 'resultado' && (
        <>
          <View style={styles.confeteWrapper} pointerEvents="none">
            {CONFETES_CONFIG.map((conf, i) => (
              <ConfetePeca key={i} config={conf} index={i} startAnim={startConfetti} />
            ))}
          </View>

          <Animated.View style={[styles.resultadoContainer, resultadoStyle]}>
            <View style={[styles.faixaResultado, { borderColor: corTema }]}>
              <Text style={styles.resultadoLabel}>
                {isJogadorHumano ? '🎉 COMEÇA' : 'COMEÇA'}
              </Text>
              <Text style={[styles.resultadoNome, { color: corTema, textShadowColor: corTema }]}>
                {vencedor}
              </Text>
              <View style={[styles.divisor, { backgroundColor: corTema }]} />
              <Text style={styles.resultadoSubtitulo}>BOA SORTE!</Text>
            </View>
          </Animated.View>
        </>
      )}
    </Animated.View>
  );
}

const styles = StyleSheet.create({
  overlay: {
    ...StyleSheet.absoluteFillObject,
    backgroundColor: 'rgba(5, 5, 20, 0.95)',
    alignItems: 'center',
    justifyContent: 'center',
    zIndex: 1000,
  },
  flash: {
    ...StyleSheet.absoluteFillObject,
    backgroundColor: '#FFD54F',
  },
  raiosContainer: {
    position: 'absolute',
    width: 4,
    height: 4,
    alignItems: 'center',
    justifyContent: 'center',
  },
  raio: {
    position: 'absolute',
    width: 3,
    height: SCREEN_HEIGHT * 0.9,
    backgroundColor: 'rgba(255, 213, 79, 0.06)',
  },
  perguntaContainer: {
    alignItems: 'center',
  },
  perguntaTexto: {
    fontSize: 28,
    color: '#AAA',
    fontWeight: 'bold',
    letterSpacing: 4,
    textShadowColor: '#000',
    textShadowOffset: { width: 2, height: 2 },
    textShadowRadius: 4,
  },
  perguntaTextoDestaque: {
    fontSize: 36,
    color: '#FFD54F',
    fontWeight: 'bold',
    letterSpacing: 6,
    marginTop: 8,
    textShadowColor: '#000',
    textShadowOffset: { width: 2, height: 2 },
    textShadowRadius: 4,
  },
  moedaContainer: {
    width: 160,
    height: 220,
    alignItems: 'center',
    justifyContent: 'center',
    marginBottom: 60,
  },
  glow: {
    position: 'absolute',
    width: 190,
    height: 190,
    borderRadius: 95,
  },
  moeda: {
    width: 130,
    height: 130,
    alignItems: 'center',
    justifyContent: 'center',
    backfaceVisibility: 'hidden',
  },
  moedaBorda: {
    width: '100%',
    height: '100%',
    borderRadius: 65,
    backgroundColor: '#E8B923',
    borderWidth: 4,
    borderColor: '#FFF3C4',
    alignItems: 'center',
    justifyContent: 'center',
    shadowColor: '#FFD54F',
    shadowOffset: { width: 0, height: 0 },
    shadowOpacity: 0.9,
    shadowRadius: 14,
    elevation: 12,
  },
  moedaMiolo: {
    width: '78%',
    height: '78%',
    borderRadius: 55,
    borderWidth: 2,
    borderColor: '#FFF3C4',
    backgroundColor: '#F4C430',
    alignItems: 'center',
    justifyContent: 'center',
  },
  moedaSimbolo: {
    fontSize: 46,
    fontWeight: 'bold',
    color: '#7A5B00',
  },
  confeteWrapper: {
    ...StyleSheet.absoluteFillObject,
  },
  resultadoContainer: {
    position: 'absolute',
    bottom: SCREEN_HEIGHT * 0.16,
    alignItems: 'center',
    width: '100%',
  },
  faixaResultado: {
    alignItems: 'center',
    paddingVertical: 16,
    paddingHorizontal: 28,
    borderRadius: 14,
    borderWidth: 2,
    backgroundColor: 'rgba(10, 10, 25, 0.55)',
  },
  resultadoLabel: {
    fontSize: 18,
    color: '#AAA',
    fontWeight: 'bold',
    letterSpacing: 3,
  },
  resultadoNome: {
    fontSize: 32,
    fontWeight: 'bold',
    marginTop: 6,
    letterSpacing: 2,
    textShadowOffset: { width: 0, height: 0 },
    textShadowRadius: 14,
  },
  divisor: {
    width: 100,
    height: 2,
    marginVertical: 12,
    opacity: 0.6,
  },
  resultadoSubtitulo: {
    fontSize: 14,
    color: '#888',
    letterSpacing: 4,
    fontWeight: 'bold',
  },
});
