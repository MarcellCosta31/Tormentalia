import React, { useEffect, useRef } from 'react';
import { View, StyleSheet, Modal, Image } from 'react-native';
import Animated, {
  useSharedValue,
  useAnimatedStyle,
  withSpring,
  withDelay,
} from 'react-native-reanimated';
import Text from '../Texto';
import { artePorCarta, temArte } from '../../cards/arteCarta';
import { CartaFaceCompleta } from './CartaFace';

// Zoom das cartas jogadas com selo de SUCESSO/FALHA. Fica 2s na tela;
// so depois comeca a animacao das cartas saindo da mao pro descarte.
export const DURACAO_ZOOM_RESULTADO = 2000;

const CARD_W = 150;
const CARD_H = 210;

function CartaResultado({ entrada, carimbo }) {
  const cardStyle = useAnimatedStyle(() => ({
    transform: [{ scale: 0.7 + carimbo.value * 0.3 }],
    opacity: carimbo.value,
  }));
  const seloStyle = useAnimatedStyle(() => ({
    transform: [{ scale: carimbo.value }, { rotate: '-8deg' }],
    opacity: carimbo.value,
  }));

  const sucesso = !!entrada.sucesso;
  const chancePct = Math.round((entrada.chance ?? 1) * 100);

  return (
    <View style={styles.item}>
      <Animated.View style={[styles.card, cardStyle]}>
        {temArte(entrada.carta) ? (
          <Image source={artePorCarta(entrada.carta)} style={styles.cartaImg} resizeMode="cover" />
        ) : (
          <CartaFaceCompleta carta={entrada.carta} style={styles.cartaImg} />
        )}
        <Animated.View style={[styles.selo, sucesso ? styles.seloSucesso : styles.seloFalha, seloStyle]}>
          <Text style={[styles.seloTexto, { color: sucesso ? '#66BB6A' : '#EF5350' }]}>
            {sucesso ? 'SUCESSO' : 'FALHA'}
          </Text>
        </Animated.View>
      </Animated.View>
      <Text style={styles.titulo} numberOfLines={2}>
        {entrada.carta.titulo}
      </Text>
      <Text style={styles.chance}>chance: {chancePct}%</Text>
    </View>
  );
}

export default function ResultadoJogada({ entradas, onFim }) {
  const carimbo = useSharedValue(0);
  const fechouRef = useRef(false);

  useEffect(() => {
    if (!entradas || entradas.length === 0) return;
    fechouRef.current = false;
    carimbo.value = 0;
    carimbo.value = withDelay(260, withSpring(1, { damping: 11, stiffness: 300, mass: 0.5 }));

    const t = setTimeout(() => {
      if (!fechouRef.current) {
        fechouRef.current = true;
        if (onFim) onFim();
      }
    }, DURACAO_ZOOM_RESULTADO);
    return () => clearTimeout(t);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [entradas]);

  const visivel = !!(entradas && entradas.length > 0);

  return (
    <Modal visible={visivel} transparent animationType="fade" statusBarTranslucent onRequestClose={() => {}}>
      <View style={styles.overlay}>
        <Text style={styles.banner}>RESULTADO DA JOGADA</Text>
        <View style={styles.linha}>
          {(entradas || []).map((e) => (
            <CartaResultado key={e.seq} entrada={e} carimbo={carimbo} />
          ))}
        </View>
      </View>
    </Modal>
  );
}

const styles = StyleSheet.create({
  overlay: {
    flex: 1,
    backgroundColor: 'rgba(4, 4, 10, 0.92)',
    alignItems: 'center',
    justifyContent: 'center',
    paddingHorizontal: 16,
  },
  banner: {
    fontSize: 20,
    letterSpacing: 5,
    color: '#FFF8E7',
    marginBottom: 26,
    opacity: 0.9,
  },
  linha: {
    flexDirection: 'row',
    alignItems: 'flex-start',
    justifyContent: 'center',
    gap: 22,
  },
  item: {
    alignItems: 'center',
    width: CARD_W,
  },
  card: {
    width: CARD_W,
    height: CARD_H,
    borderRadius: 8,
    borderWidth: 2,
    borderColor: '#FFF8E7',
    overflow: 'hidden',
    shadowColor: '#000',
    shadowOffset: { width: 3, height: 4 },
    shadowOpacity: 0.7,
    shadowRadius: 10,
    elevation: 20,
    backgroundColor: '#120A1E',
  },
  cartaImg: {
    width: '100%',
    height: '100%',
  },
  selo: {
    position: 'absolute',
    bottom: 26,
    alignSelf: 'center',
    paddingHorizontal: 12,
    paddingVertical: 6,
    borderWidth: 3,
    borderRadius: 6,
    backgroundColor: 'rgba(0, 0, 0, 0.72)',
  },
  seloSucesso: {
    borderColor: '#66BB6A',
  },
  seloFalha: {
    borderColor: '#EF5350',
  },
  seloTexto: {
    fontSize: 22,
    letterSpacing: 3,
  },
  titulo: {
    fontSize: 13,
    letterSpacing: 1,
    color: '#FFF8E7',
    textAlign: 'center',
    marginTop: 12,
  },
  chance: {
    fontSize: 12,
    color: '#B0BEC5',
    marginTop: 4,
  },
});
