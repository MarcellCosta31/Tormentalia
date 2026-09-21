import React, { useRef, useEffect, useState } from 'react';
import { View, StyleSheet, Text, Dimensions, Pressable } from 'react-native';
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
import CartaArena from './CartaArena';
import PainelStatus from './PainelStatus';
import { soundManager } from '../../utils/sound';

const CARD_WIDTH = 68;
const CARD_HEIGHT = 95;
const OVERLAP = 30;
const LIFT_SELECIONADA = 22;
const LONG_PRESS_ZOOM_MS = 800;
const STAGGER_DELAY = 80;
const { width: SCREEN_WIDTH } = Dimensions.get('window');

const HIGHLIGHT_DURATION = 3000;

function CartaAnimada({ carta, index, numCartas, desabilitado, falido, selecionada, onToggleSelecionar, onZoom, prevPositions, isRecentDrawn }) {
  const animLeft = useSharedValue(index * OVERLAP);
  const animTop = useSharedValue(0);
  const animRotate = useSharedValue(0);
  const animScale = useSharedValue(1);
  const animOpacity = useSharedValue(0);
  const animGlow = useSharedValue(0);
  const animHighlight = useSharedValue(0);

  const maxAngle = 22;
  const angleStep = numCartas > 1 ? (maxAngle * 2) / (numCartas - 1) : 0;
  const offsetFromCenter = index - (numCartas - 1) / 2;
  const angle = numCartas > 1 ? offsetFromCenter * angleStep : 0;

  const curvature = numCartas > 3 ? 8 : 5;
  const normalizedOffset = numCartas > 1 ? offsetFromCenter / ((numCartas - 1) / 2) : 0;
  const translateYBase = Math.pow(Math.abs(normalizedOffset), 1.3) * curvature;
  const translateYAlvo = translateYBase - (selecionada ? LIFT_SELECIONADA : 0);

  const wrapperStyle = useAnimatedStyle(() => ({
    left: animLeft.value,
    top: animTop.value,
    transform: [
      { rotate: `${interpolate(animRotate.value, [-30, 30], [-30, 30])}deg` },
      { scale: animScale.value },
    ],
    opacity: animOpacity.value,
    zIndex: selecionada ? 50 + index : index,
  }));

  const glowStyle = useAnimatedStyle(() => ({
    opacity: animGlow.value,
  }));

  const highlightStyle = useAnimatedStyle(() => ({
    opacity: animHighlight.value,
    shadowOpacity: animHighlight.value,
  }));

  useEffect(() => {
    const prev = prevPositions.current[carta.uid];
    const newLeft = index * OVERLAP;

    if (prev !== undefined && prev !== newLeft) {
      animLeft.value = prev;
    }

    const entradaDelay = index * STAGGER_DELAY;

    setTimeout(() => {
      animLeft.value = withSpring(newLeft, { damping: 8, stiffness: 60 });
      animTop.value = withSpring(translateYAlvo, { damping: 7, stiffness: 50 });
      animRotate.value = withSpring(angle + (Math.random() - 0.5) * 3, { damping: 6, stiffness: 45 });
      animScale.value = withSpring(selecionada ? 1.1 : 1, {
        damping: selecionada ? 4 : 6,
        stiffness: selecionada ? 120 : 50,
      });
      animOpacity.value = withTiming(1, { duration: 200 });
    }, entradaDelay);
  }, [index, numCartas, selecionada, translateYAlvo]);

  useEffect(() => {
    if (isRecentDrawn) {
      soundManager.playCardHighlight();
      animHighlight.value = withSequence(
        withTiming(1, { duration: 200 }),
        withRepeat(
          withSequence(
            withTiming(0.5, { duration: 500 }),
            withTiming(1, { duration: 500 })
          ),
          -1,
          false
        )
      );

      const timer = setTimeout(() => {
        animHighlight.value = withTiming(0, { duration: 400 });
      }, HIGHLIGHT_DURATION);

      return () => clearTimeout(timer);
    } else {
      animHighlight.value = 0;
    }
  }, [isRecentDrawn]);

  useEffect(() => {
    if (selecionada) {
      soundManager.playSelect();
      animGlow.value = withSequence(
        withTiming(1, { duration: 150 }),
        withTiming(0.6, { duration: 100 })
      );
    } else {
      animGlow.value = 0;
    }
  }, [selecionada]);

  useEffect(() => {
    return () => {
      prevPositions.current[carta.uid] = index * OVERLAP;
    };
  }, [index]);

  const podeSelecionar = !desabilitado && !falido;

  const handlePress = () => {
    if (!podeSelecionar) return;
    soundManager.playCardDraw();
    if (onToggleSelecionar) onToggleSelecionar(carta);
  };

  const handleLongPress = () => {
    soundManager.playCardDraw();
    if (onZoom) onZoom(carta);
  };

  return (
    <Animated.View style={[styles.cartaWrapper, wrapperStyle]}>
      <Pressable
        onPress={handlePress}
        onLongPress={handleLongPress}
        delayLongPress={LONG_PRESS_ZOOM_MS}
      >
        <CartaArena
          carta={carta}
          onPress={() => {}}
          selecionada={selecionada}
          desabilitada={desabilitado || falido}
        />
        {selecionada && (
          <Animated.View style={[styles.selectionGlow, glowStyle]} />
        )}
        {isRecentDrawn && (
          <Animated.View style={[styles.drawnHighlight, highlightStyle]} />
        )}
      </Pressable>
    </Animated.View>
  );
}

export default function MaoJogador({
  jogador,
  cartasSelecionadas = [],
  onSelecionarCarta,
  onDescartar,
  desabilitado,
  hideStatus = false,
  onZoomCarta,
  cartaRecemCompradaUid = null,
}) {
  const prevPositions = useRef({});
  const longPressTimer = useRef(null);
  const [panelPressed, setPanelPressed] = useState(false);

  const handlePanelPressIn = () => {
    setPanelPressed(true);
    longPressTimer.current = setTimeout(() => {
      soundManager.playPassTurn();
      if (onDescartar) onDescartar();
    }, 800);
  };

  const handlePanelPressOut = () => {
    setPanelPressed(false);
    if (longPressTimer.current) {
      clearTimeout(longPressTimer.current);
      longPressTimer.current = null;
    }
  };

  useEffect(() => {
    return () => {
      if (longPressTimer.current) clearTimeout(longPressTimer.current);
    };
  }, []);

  if (!jogador) return null;

  const numCartas = jogador.mao.length;
  const totalWidth = CARD_WIDTH + Math.max(numCartas - 1, 0) * OVERLAP;

  return (
    <View style={styles.container}>
      <Text style={styles.sparkleAccent}>✨</Text>

      <View style={styles.maoContainer}>
        <View style={[styles.mao, { width: totalWidth, height: CARD_HEIGHT + 30 + LIFT_SELECIONADA }]}>
          {jogador.mao.map((carta, index) => {
            const selecionada = cartasSelecionadas.some((c) => c.uid === carta.uid);
            return (
              <CartaAnimada
                key={carta.uid}
                carta={carta}
                index={index}
                numCartas={numCartas}
                desabilitado={desabilitado}
                falido={jogador.falido}
                selecionada={selecionada}
                onToggleSelecionar={onSelecionarCarta}
                onZoom={onZoomCarta}
                prevPositions={prevPositions}
                isRecentDrawn={carta.uid === cartaRecemCompradaUid}
              />
            );
          })}
        </View>
      </View>

      {!hideStatus && (
        <Pressable
          onPressIn={handlePanelPressIn}
          onPressOut={handlePanelPressOut}
          style={styles.painelContainer}
        >
          <PainelStatus nome={jogador.nome} saldo={jogador.saldo} corDestaque="#FFD54F" />

          {panelPressed && (
            <View style={styles.passarOverlay}>
              <Text style={styles.passarTexto}>SOLTAR PARA PASSAR</Text>
            </View>
          )}
        </Pressable>
      )}
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    alignItems: 'center',
    backgroundColor: 'transparent',
    position: 'relative',
    width: '100%',
  },
  sparkleAccent: {
    position: 'absolute',
    top: -16,
    right: 10,
    fontSize: 18,
    color: '#FFF8E7',
    zIndex: 1,
    opacity: 0.85,
  },
  maoContainer: {
    alignItems: 'center',
    marginBottom: 5,
    zIndex: 1,
  },
  mao: {
    position: 'relative',
    alignSelf: 'center',
    alignItems: 'flex-start',
  },
  cartaWrapper: {
    position: 'absolute',
    top: 0,
  },
  selectionGlow: {
    position: 'absolute',
    top: -4,
    left: -4,
    right: -4,
    bottom: -4,
    borderRadius: 10,
    borderWidth: 2,
    borderColor: '#FFD54F',
    backgroundColor: 'rgba(255, 213, 79, 0.15)',
    shadowColor: '#FFD54F',
    shadowOffset: { width: 0, height: 0 },
    shadowOpacity: 0.8,
    shadowRadius: 12,
    elevation: 15,
  },
  drawnHighlight: {
    position: 'absolute',
    top: -5,
    left: -5,
    right: -5,
    bottom: -5,
    borderRadius: 11,
    borderWidth: 3,
    borderColor: '#4FC3F7',
    backgroundColor: 'rgba(79, 195, 247, 0.12)',
    shadowColor: '#4FC3F7',
    shadowOffset: { width: 0, height: 0 },
    shadowRadius: 16,
    elevation: 20,
  },
  painelContainer: {
    width: SCREEN_WIDTH * 0.8,
    maxWidth: 320,
    position: 'relative',
    alignItems: 'center',
    justifyContent: 'center',
    zIndex: 2,
  },
  passarOverlay: {
    ...StyleSheet.absoluteFillObject,
    backgroundColor: 'rgba(230, 81, 0, 0.85)',
    borderRadius: 8,
    alignItems: 'center',
    justifyContent: 'center',
  },
  passarTexto: {
    color: '#FFF',
    fontWeight: 'bold',
    fontSize: 12,
    letterSpacing: 2,
  },
});
