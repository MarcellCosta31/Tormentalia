import React, { useEffect, useState } from 'react';
import { View, Image, StyleSheet, Dimensions } from 'react-native';
import Text from '../Texto';
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

export default function AnimacaoInicioBatalha({
  jogadorAtivoIndex,
  jogadores = [],
  nomeJogador,
  nomeOponente,
  avatarJogadorSource,
  avatarOponenteSource,
  onCompleto,
}) {
  const [fase, setFase] = useState('intro');
  const [completado, setCompletado] = useState(false);
  const [startConfetti, setStartConfetti] = useState(false);
  const [idxExibido, setIdxExibido] = useState(0);

  const overlayOpacity = useSharedValue(0);
  const perguntaOpacity = useSharedValue(0);
  const perguntaScale = useSharedValue(0.5);
  const quadroScale = useSharedValue(0);
  const quadroRotacao = useSharedValue(0);
  const revelacaoOpacity = useSharedValue(0);
  const flashOpacity = useSharedValue(0);
  const glowPulse = useSharedValue(0.3);
  const raiosRotation = useSharedValue(0);
  const shakeX = useSharedValue(0);

  // Lista de todos os jogadores da batalha (nome + avatar).
  const lista = jogadores.length > 0
    ? jogadores
    : [
        { nome: nomeJogador || 'JOGADOR', avatarSource: avatarJogadorSource, emoji: '👤' },
        { nome: nomeOponente || 'OPONENTE', avatarSource: avatarOponenteSource, emoji: '🤖' },
      ];

  const escolhidoIdxBruto = Number.isInteger(jogadorAtivoIndex) ? jogadorAtivoIndex : 0;
  const escolhidoIdx = Math.min(Math.max(escolhidoIdxBruto, 0), lista.length - 1);
  const escolhido = lista[escolhidoIdx];

  const atual = lista[idxExibido] || escolhido;

  const corTema = escolhido.cor || (escolhidoIdx === 0 ? '#4CAF50' : '#FFD54F');

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

  const quadroStyle = useAnimatedStyle(() => ({
    transform: [
      { scale: quadroScale.value },
      { rotate: `${quadroRotacao.value}deg` },
    ],
  }));

  const revelacaoStyle = useAnimatedStyle(() => ({ opacity: revelacaoOpacity.value }));

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
      setFase('rolling');
    }, 1100);

    return () => clearTimeout(timerFase);
  }, []);

  useEffect(() => {
    if (fase !== 'rolling') return;

    perguntaOpacity.value = withTiming(0, { duration: 200 });

    soundManager.playDiceRoll();
    quadroScale.value = withSpring(1, { damping: 8, stiffness: 90 });

    // Quadrado troca de avatar a cada "tranco": comeca rapidissimo e
    // vai desacelerando ate PARAR no jogador escolhido.
    const TOTAL_TRANCOS = 16;
    let trancoAtual = 0;
    let timeoutId;

    const proximoTranco = () => {
      trancoAtual++;
      const progresso = trancoAtual / TOTAL_TRANCOS;

      if (lista.length > 1) {
        setIdxExibido((prev) => {
          let novo = Math.floor(Math.random() * lista.length);
          if (novo === prev) novo = (novo + 1) % lista.length;
          return novo;
        });
      }

      // tranco visual: chacoalha o quadro e volta
      quadroRotacao.value = withSequence(
        withTiming((Math.random() - 0.5) * 14, { duration: 55 }),
        withSpring(0, { damping: 9, stiffness: 140 })
      );
      quadroScale.value = withSequence(
        withTiming(1.05, { duration: 55 }),
        withSpring(1, { damping: 10, stiffness: 130 })
      );

      if (trancoAtual < TOTAL_TRANCOS) {
        const atraso = 40 + progresso * progresso * 300; // 40ms -> ~340ms
        timeoutId = setTimeout(proximoTranco, atraso);
      } else {
        // PARA NO ESCOLHIDO
        setIdxExibido(escolhidoIdx);
        quadroScale.value = withSequence(
          withTiming(1.14, { duration: 90 }),
          withSpring(1, { damping: 7, stiffness: 90 })
        );
        timeoutId = setTimeout(() => setFase('resultado'), 480);
      }
    };

    timeoutId = setTimeout(proximoTranco, 150);

    return () => clearTimeout(timeoutId);
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

    revelacaoOpacity.value = withTiming(1, { duration: 300 });

    setStartConfetti(true);

    flashOpacity.value = withSequence(
      withTiming(0.85, { duration: 90 }),
      withTiming(0, { duration: 250 })
    );

    const timerFase = setTimeout(() => {
      overlayOpacity.value = withTiming(0, { duration: 500 });
      setTimeout(() => setCompletado(true), 500);
    }, 2200);

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

      {(fase === 'rolling' || fase === 'resultado') && (
        <View style={styles.quadroContainer}>
          <Animated.View style={[styles.glow, glowStyle]} />
          <Animated.View style={[styles.quadro, quadroStyle]}>
            <View style={styles.quadroBorda}>
              <View style={styles.quadroMiolo}>
                {atual?.avatarSource ? (
                  <Image
                    source={atual.avatarSource}
                    style={styles.quadroAvatar}
                    resizeMode="cover"
                  />
                ) : (
                  <Text style={styles.quadroEmoji}>{atual?.emoji || '👤'}</Text>
                )}
                <Text style={styles.quadroNome} numberOfLines={1}>
                  {atual?.nome || ''}
                </Text>
              </View>
            </View>
          </Animated.View>
        </View>
      )}

      {fase === 'resultado' && (
        <>
          <Animated.View
            style={[styles.revelacaoGlow, revelacaoStyle]}
            pointerEvents="none"
          />

          <View style={styles.confeteWrapper} pointerEvents="none">
            {CONFETES_CONFIG.map((conf, i) => (
              <ConfetePeca key={i} config={conf} index={i} startAnim={startConfetti} />
            ))}
          </View>
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
  quadroContainer: {
    width: 160,
    height: 180,
    alignItems: 'center',
    justifyContent: 'center',
  },
  glow: {
    position: 'absolute',
    left: -15,
    top: -5,
    width: 190,
    height: 190,
    borderRadius: 95,
  },
  quadro: {
    width: 140,
    height: 140,
    alignItems: 'center',
    justifyContent: 'center',
    backfaceVisibility: 'hidden',
  },
  quadroBorda: {
    width: '100%',
    height: '100%',
    borderRadius: 20,
    backgroundColor: '#E8B923',
    borderWidth: 4,
    borderColor: '#FFF3C4',
    padding: 6,
    shadowColor: '#FFD54F',
    shadowOffset: { width: 0, height: 0 },
    shadowOpacity: 0.9,
    shadowRadius: 14,
    elevation: 12,
  },
  quadroMiolo: {
    flex: 1,
    borderRadius: 14,
    borderWidth: 2,
    borderColor: '#FFF3C4',
    backgroundColor: '#1C2238',
    alignItems: 'center',
    justifyContent: 'center',
    overflow: 'hidden',
  },
  quadroAvatar: {
    width: '100%',
    height: '100%',
  },
  quadroEmoji: {
    fontSize: 56,
  },
  quadroNome: {
    position: 'absolute',
    bottom: 0,
    left: 0,
    right: 0,
    paddingVertical: 5,
    paddingHorizontal: 8,
    backgroundColor: 'rgba(0,0,0,0.62)',
    color: '#FFD54F',
    fontSize: 12,
    fontWeight: 'bold',
    textAlign: 'center',
    letterSpacing: 1,
  },
  revelacaoGlow: {
    position: 'absolute',
    left: '18%',
    right: '18%',
    top: '30%',
    height: 200,
    borderRadius: 100,
    backgroundColor: 'rgba(255, 213, 79, 0.10)',
  },

  confeteWrapper: {
    ...StyleSheet.absoluteFillObject,
  },
});
