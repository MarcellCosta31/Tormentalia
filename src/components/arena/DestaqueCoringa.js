import React, { useEffect, useRef } from 'react';
import { View, StyleSheet, Modal, Image } from 'react-native';
import Animated, {
  useSharedValue,
  useAnimatedStyle,
  withTiming,
  withSequence,
  withDelay,
  withSpring,
} from 'react-native-reanimated';
import Text from '../Texto';
import { artePorCarta, temArte } from '../../cards/arteCarta';
import { CartaFaceCompleta } from './CartaFace';

// Quanto tempo a carta coringa fica em destaque. O turno so continua
// depois desse tempo (executarJogadaMao e a IA esperam essa duracao).
export const DURACAO_DESTAQUE_CORINGA = 3000;

export default function DestaqueCoringa({ carta, sucesso = null, onFim }) {
  const escala = useSharedValue(0.55);
  const tremor = useSharedValue(0);
  const brilho = useSharedValue(0);

  // Ultima carta mostrada: mantem o conteudo montado enquanto o Modal
  // faz o fade-out.
  const ultimaRef = useRef(null);
  if (carta) ultimaRef.current = carta;

  useEffect(() => {
    if (!carta) return;

    escala.value = 0.55;
    tremor.value = 0;
    brilho.value = 0;

    // Entra com um snap (estilo Balatro), nao balancando.
    escala.value = withSpring(1, { damping: 13, stiffness: 220, mass: 0.6 });

    // Clarao roxo unico que assenta (sem piscar em loop).
    brilho.value = withDelay(
      200,
      withSequence(
        withTiming(1, { duration: 250 }),
        withTiming(0.5, { duration: 450 })
      )
    );

    // Tremor unico do caos - acontece uma vez, nao repete.
    tremor.value = withDelay(
      320,
      withSequence(
        withTiming(1, { duration: 45 }),
        withTiming(-1, { duration: 55 }),
        withTiming(0.7, { duration: 50 }),
        withTiming(-0.45, { duration: 50 }),
        withTiming(0, { duration: 60 })
      )
    );

    const t = setTimeout(() => {
      if (onFim) onFim();
    }, DURACAO_DESTAQUE_CORINGA);

    return () => clearTimeout(t);
  }, [carta]);

  const cardStyle = useAnimatedStyle(() => ({
    transform: [{ translateX: tremor.value * 9 }, { scale: escala.value }],
  }));

  const glowStyle = useAnimatedStyle(() => ({
    opacity: brilho.value,
  }));

  const cartaAtual = carta || ultimaRef.current;

  return (
    <Modal
      visible={!!carta}
      transparent
      animationType="fade"
      statusBarTranslucent
      onRequestClose={() => {}}
    >
      <View style={styles.overlay}>
        {cartaAtual ? (
          <>
            <Text style={styles.banner}>CORINGA!</Text>
            <Text style={styles.subBanner}>O CAOS TOMOU CONTA DA MESA</Text>

            <View style={styles.cardArea}>
              <Animated.View style={[styles.glow, glowStyle]} />
              <Animated.View style={[styles.card, cardStyle]}>
                {temArte(cartaAtual) ? (
                  <Image
                    source={artePorCarta(cartaAtual)}
                    style={styles.cartaImg}
                    resizeMode="cover"
                  />
                ) : (
                  <CartaFaceCompleta carta={cartaAtual} style={styles.cartaImg} />
                )}
                {sucesso !== null && sucesso !== undefined && (
                  <View
                    style={[
                      styles.selo,
                      sucesso ? styles.seloSucesso : styles.seloFalha,
                    ]}
                  >
                    <Text style={[styles.seloTexto, { color: sucesso ? '#66BB6A' : '#EF5350' }]}>
                      {sucesso ? 'SUCESSO' : 'FALHA'}
                    </Text>
                  </View>
                )}
              </Animated.View>
            </View>

            <Text style={styles.titulo}>{cartaAtual.titulo}</Text>
            <Text style={styles.efeito}>{cartaAtual.efeitoTexto}</Text>
          </>
        ) : null}
      </View>
    </Modal>
  );
}

const styles = StyleSheet.create({
  overlay: {
    flex: 1,
    backgroundColor: 'rgba(8, 0, 18, 0.88)',
    alignItems: 'center',
    justifyContent: 'center',
    paddingHorizontal: 24,
  },
  banner: {
    fontSize: 42,
    letterSpacing: 6,
    color: '#CE93D8',
    textShadowColor: '#6A1B9A',
    textShadowOffset: { width: 0, height: 0 },
    textShadowRadius: 18,
    marginBottom: 4,
  },
  subBanner: {
    fontSize: 13,
    letterSpacing: 3,
    color: '#E1BEE7',
    marginBottom: 22,
  },
  cardArea: {
    alignItems: 'center',
    justifyContent: 'center',
  },
  glow: {
    position: 'absolute',
    width: 258,
    height: 342,
    borderRadius: 18,
    backgroundColor: 'rgba(157, 0, 255, 0.35)',
  },
  card: {
    width: 210,
    height: 294,
    borderRadius: 8,
    borderWidth: 3,
    borderColor: '#CE93D8',
    overflow: 'hidden',
    shadowColor: '#6A1B9A',
    shadowOffset: { width: 0, height: 0 },
    shadowOpacity: 0.9,
    shadowRadius: 30,
    elevation: 30,
    backgroundColor: '#120A1E',
  },
  cartaImg: {
    width: '100%',
    height: '100%',
  },
  selo: {
    position: 'absolute',
    bottom: 22,
    alignSelf: 'center',
    paddingHorizontal: 12,
    paddingVertical: 6,
    borderWidth: 3,
    borderRadius: 6,
    backgroundColor: 'rgba(0, 0, 0, 0.72)',
    transform: [{ rotate: '-8deg' }],
  },
  seloSucesso: {
    borderColor: '#66BB6A',
  },
  seloFalha: {
    borderColor: '#EF5350',
  },
  seloTexto: {
    fontSize: 24,
    letterSpacing: 3,
  },
  titulo: {
    fontSize: 20,
    letterSpacing: 2,
    color: '#FFD54F',
    textAlign: 'center',
    marginTop: 20,
  },
  efeito: {
    fontSize: 14,
    lineHeight: 20,
    color: '#F3E5F5',
    textAlign: 'center',
    marginTop: 8,
    paddingHorizontal: 16,
  },
});
