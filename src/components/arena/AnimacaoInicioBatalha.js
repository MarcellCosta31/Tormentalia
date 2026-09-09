import React, { useEffect, useRef, useState } from 'react';
import { View, Text, StyleSheet, Animated, Dimensions } from 'react-native';
import { soundManager } from '../../utils/sound';

const { width: SCREEN_WIDTH, height: SCREEN_HEIGHT } = Dimensions.get('window');

const NUM_RAIOS = 12;
const NUM_CONFETES = 18;
const CORES_CONFETE = ['#FFD54F', '#4CAF50', '#42A5F5', '#EF5350', '#FFFFFF'];

// Gerado uma unica vez (fora do componente) pra nao mudar a cada render
const CONFETES_CONFIG = Array.from({ length: NUM_CONFETES }).map(() => ({
  x: (Math.random() - 0.5) * SCREEN_WIDTH * 0.9,
  atraso: Math.random() * 250,
  duracao: 900 + Math.random() * 500,
  rotacaoFinal: (Math.random() > 0.5 ? 1 : -1) * (360 + Math.random() * 360),
  cor: CORES_CONFETE[Math.floor(Math.random() * CORES_CONFETE.length)],
  tamanho: 6 + Math.random() * 5,
}));

export default function AnimacaoInicioBatalha({ jogadorAtivoIndex, nomeJogador, nomeOponente, onCompleto }) {
  const [fase, setFase] = useState('intro');
  const overlayOpacity = useRef(new Animated.Value(0)).current;
  const perguntaOpacity = useRef(new Animated.Value(0)).current;
  const perguntaScale = useRef(new Animated.Value(0.5)).current;
  const moedaScale = useRef(new Animated.Value(0)).current;
  const moedaRotation = useRef(new Animated.Value(0)).current;
  const resultadoOpacity = useRef(new Animated.Value(0)).current;
  const resultadoScale = useRef(new Animated.Value(0.3)).current;
  const flashOpacity = useRef(new Animated.Value(0)).current;
  const glowPulse = useRef(new Animated.Value(0.3)).current;
  const raiosRotation = useRef(new Animated.Value(0)).current;
  const shakeX = useRef(new Animated.Value(0)).current;
  const confeteAnims = useRef(CONFETES_CONFIG.map(() => new Animated.Value(0))).current;

  const isJogadorHumano = jogadorAtivoIndex === 0;
  const vencedor = isJogadorHumano ? nomeJogador : nomeOponente;
  const corTema = isJogadorHumano ? '#4CAF50' : '#FFD54F';

  useEffect(() => {
    soundManager.init();

    // Raios giram continuamente e devagar desde o inicio, dando profundidade
    Animated.loop(
      Animated.timing(raiosRotation, {
        toValue: 1,
        duration: 8000,
        useNativeDriver: true,
      })
    ).start();

    // Pulso de brilho continuo atras da moeda
    Animated.loop(
      Animated.sequence([
        Animated.timing(glowPulse, { toValue: 1, duration: 900, useNativeDriver: true }),
        Animated.timing(glowPulse, { toValue: 0.3, duration: 900, useNativeDriver: true }),
      ])
    ).start();

    const sequenciaAnimacao = () => {
      Animated.sequence([
        Animated.parallel([
          Animated.timing(overlayOpacity, {
            toValue: 1,
            duration: 400,
            useNativeDriver: true,
          }),
          Animated.timing(perguntaOpacity, {
            toValue: 1,
            duration: 500,
            useNativeDriver: true,
          }),
          Animated.spring(perguntaScale, {
            toValue: 1,
            friction: 6,
            tension: 40,
            useNativeDriver: true,
          }),
        ]),
        Animated.delay(600),
        Animated.timing(perguntaOpacity, {
          toValue: 0,
          duration: 200,
          useNativeDriver: true,
        }),
      ]).start(() => {
        setFase('flip');
        executarGiroMoeda();
      });
    };

    sequenciaAnimacao();
  }, []);

  const executarGiroMoeda = () => {
    soundManager.playFlip();

    Animated.parallel([
      Animated.spring(moedaScale, {
        toValue: 1,
        friction: 5,
        tension: 60,
        useNativeDriver: true,
      }),
      // Varias voltas completas antes de assentar - efeito "cara ou coroa"
      Animated.timing(moedaRotation, {
        toValue: 5,
        duration: 1100,
        useNativeDriver: true,
      }),
    ]).start(() => {
      setFase('resultado');
      mostrarResultado();
    });
  };

  const mostrarResultado = () => {
    setTimeout(() => {
      soundManager.playVictory();
    }, 100);

    // Tremor rapido de tela no exato momento do impacto
    Animated.sequence([
      Animated.timing(shakeX, { toValue: 8, duration: 40, useNativeDriver: true }),
      Animated.timing(shakeX, { toValue: -8, duration: 40, useNativeDriver: true }),
      Animated.timing(shakeX, { toValue: 5, duration: 40, useNativeDriver: true }),
      Animated.timing(shakeX, { toValue: 0, duration: 40, useNativeDriver: true }),
    ]).start();

    // Confete cai a partir do topo, com atraso escalonado por peca
    confeteAnims.forEach((anim, i) => {
      Animated.timing(anim, {
        toValue: 1,
        duration: CONFETES_CONFIG[i].duracao,
        delay: CONFETES_CONFIG[i].atraso,
        useNativeDriver: true,
      }).start();
    });

    Animated.sequence([
      Animated.parallel([
        Animated.timing(flashOpacity, {
          toValue: 0.85,
          duration: 90,
          useNativeDriver: true,
        }),
        Animated.spring(resultadoScale, {
          toValue: 1,
          friction: 5,
          tension: 50,
          useNativeDriver: true,
        }),
        Animated.timing(resultadoOpacity, {
          toValue: 1,
          duration: 300,
          useNativeDriver: true,
        }),
      ]),
      Animated.timing(flashOpacity, {
        toValue: 0,
        duration: 250,
        useNativeDriver: true,
      }),
      Animated.delay(1300),
      Animated.timing(overlayOpacity, {
        toValue: 0,
        duration: 500,
        useNativeDriver: true,
      }),
    ]).start(() => {
      if (onCompleto) onCompleto();
    });
  };

  const interpolateMoedaRotation = moedaRotation.interpolate({
    inputRange: [0, 1, 2, 3, 4, 5],
    outputRange: ['0deg', '360deg', '720deg', '1080deg', '1440deg', '1800deg'],
  });

  const interpolateGlow = glowPulse.interpolate({
    inputRange: [0, 1],
    outputRange: [0.25, 0.55],
  });

  const interpolateRaios = raiosRotation.interpolate({
    inputRange: [0, 1],
    outputRange: ['0deg', '360deg'],
  });

  return (
    <Animated.View
      style={[styles.overlay, { opacity: overlayOpacity, transform: [{ translateX: shakeX }] }]}
      pointerEvents="auto"
    >
      <Animated.View style={[styles.flash, { opacity: flashOpacity }]} />

      {/* Raios dourados girando lentamente ao fundo, dao profundidade e drama */}
      <Animated.View
        style={[styles.raiosContainer, { transform: [{ rotate: interpolateRaios }] }]}
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
        <Animated.View style={[styles.perguntaContainer, { opacity: perguntaOpacity, transform: [{ scale: perguntaScale }] }]}>
          <Text style={styles.perguntaTexto}>QUEM COMEÇA</Text>
          <Text style={styles.perguntaTextoDestaque}>A BATALHA?</Text>
        </Animated.View>
      )}

      {(fase === 'flip' || fase === 'resultado') && (
        <View style={styles.moedaContainer}>
          <Animated.View
            style={[
              styles.glow,
              {
                opacity: interpolateGlow,
                backgroundColor: fase === 'resultado' ? `${corTema}55` : 'rgba(255, 213, 79, 0.3)',
              },
            ]}
          />

          <Animated.View
            style={[
              styles.moeda,
              {
                transform: [
                  { scale: moedaScale },
                  { rotateY: interpolateMoedaRotation },
                ],
              },
            ]}
          >
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
          {/* Confete caindo a partir do topo da tela */}
          <View style={styles.confeteWrapper} pointerEvents="none">
            {CONFETES_CONFIG.map((conf, i) => {
              const translateY = confeteAnims[i].interpolate({
                inputRange: [0, 1],
                outputRange: [-40, SCREEN_HEIGHT * 0.7],
              });
              const rotate = confeteAnims[i].interpolate({
                inputRange: [0, 1],
                outputRange: ['0deg', `${conf.rotacaoFinal}deg`],
              });
              const opacity = confeteAnims[i].interpolate({
                inputRange: [0, 0.85, 1],
                outputRange: [1, 1, 0],
              });
              return (
                <Animated.View
                  key={i}
                  style={[
                    styles.confetePeca,
                    {
                      left: SCREEN_WIDTH / 2 + conf.x,
                      width: conf.tamanho,
                      height: conf.tamanho * 1.6,
                      backgroundColor: conf.cor,
                      opacity,
                      transform: [{ translateY }, { rotate }],
                    },
                  ]}
                />
              );
            })}
          </View>

          <Animated.View style={[styles.resultadoContainer, { opacity: resultadoOpacity, transform: [{ scale: resultadoScale }] }]}>
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
  confetePeca: {
    position: 'absolute',
    top: 0,
    borderRadius: 1,
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