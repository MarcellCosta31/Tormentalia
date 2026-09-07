import React, { useRef, useEffect, useState, useCallback } from 'react';
import { View, StyleSheet, Text, Animated, PanResponder, Dimensions, Pressable } from 'react-native';
import CartaArena from './CartaArena';
import PainelStatus from './PainelStatus';
import { soundManager } from '../../utils/sound';

const CARD_WIDTH = 68;
const CARD_HEIGHT = 95;
const OVERLAP = 30;
const DRAG_THRESHOLD = -80;
const { width: SCREEN_WIDTH } = Dimensions.get('window');

function CartaAnimada({ carta, index, numCartas, desabilitado, falido, onPress, onJogar, prevPositions }) {
  const animLeft = useRef(new Animated.Value(index * OVERLAP)).current;
  const animTop = useRef(new Animated.Value(0)).current;
  const animRotate = useRef(new Animated.Value(0)).current;
  const animScale = useRef(new Animated.Value(1)).current;
  const animOpacity = useRef(new Animated.Value(1)).current;
  const dragY = useRef(new Animated.Value(0)).current;

  const desabilitadoRef = useRef(desabilitado);
  const falidoRef = useRef(falido);
  const cartaRef = useRef(carta);
  const didMoveRef = useRef(false);

  desabilitadoRef.current = desabilitado;
  falidoRef.current = falido;
  cartaRef.current = carta;

  const maxAngle = 18;
  const angleStep = numCartas > 1 ? (maxAngle * 2) / (numCartas - 1) : 0;
  const offsetFromCenter = index - (numCartas - 1) / 2;
  const angle = numCartas > 1 ? offsetFromCenter * angleStep : 0;
  const translateY = Math.abs(offsetFromCenter) * 6;

  const panResponder = useRef(
    PanResponder.create({
      // Captura TODOS os toques desde o inicio para nao conflitar com Pressable
      onStartShouldSetPanResponder: () => true,
      onStartShouldSetPanResponderCapture: () => false,
      onMoveShouldSetPanResponder: () => true,
      onPanResponderGrant: () => {
        didMoveRef.current = false;
        Animated.spring(animScale, { toValue: 1.1, useNativeDriver: false, friction: 5 }).start();
      },
      onPanResponderMove: (_, gestureState) => {
        // Marca como movimento real se passou do limiar
        if (Math.abs(gestureState.dy) > 8 || Math.abs(gestureState.dx) > 8) {
          didMoveRef.current = true;
        }
        if (gestureState.dy < 0) {
          dragY.setValue(gestureState.dy);
        }
      },
      onPanResponderRelease: (_, gestureState) => {
        const desab = desabilitadoRef.current;
        const faliu = falidoRef.current;
        const podeJogar = !desab && !faliu;

        if (podeJogar && gestureState.dy < DRAG_THRESHOLD) {
          // Arraste para cima suficiente = jogar carta (so permitido no seu turno)
          soundManager.playCardPlay();
          Animated.parallel([
            Animated.timing(animTop, { toValue: -250, duration: 300, useNativeDriver: false }),
            Animated.timing(animOpacity, { toValue: 0, duration: 300, useNativeDriver: false }),
            Animated.timing(animScale, { toValue: 0.5, duration: 300, useNativeDriver: false }),
          ]).start(() => {
            dragY.setValue(0);
            if (onJogar) onJogar(cartaRef.current);
          });
        } else if (!didMoveRef.current) {
          // Toque simples (sem movimento) = ampliar/inspecionar a carta.
          Animated.spring(animScale, { toValue: 1, useNativeDriver: false, friction: 8 }).start();
          Animated.spring(dragY, { toValue: 0, useNativeDriver: false, friction: 8 }).start();
          soundManager.playCardDraw();
          if (onPress) onPress(cartaRef.current);
        } else {
          // Arraste incompleto (ou tentativa de jogar fora do turno) = voltar pro lugar
          Animated.parallel([
            Animated.spring(dragY, { toValue: 0, useNativeDriver: false, friction: 8 }),
            Animated.spring(animScale, { toValue: 1, useNativeDriver: false, friction: 8 }),
          ]).start();
        }
      },
      onPanResponderTerminate: () => {
        Animated.parallel([
          Animated.spring(dragY, { toValue: 0, useNativeDriver: false, friction: 8 }),
          Animated.spring(animScale, { toValue: 1, useNativeDriver: false, friction: 8 }),
        ]).start();
      },
    })
  ).current;

  useEffect(() => {
    const prev = prevPositions.current[carta.uid];
    const newLeft = index * OVERLAP;

    if (prev !== undefined && prev !== newLeft) {
      animLeft.setValue(prev);
    }

    Animated.parallel([
      Animated.spring(animLeft, { toValue: newLeft, useNativeDriver: false, friction: 8, tension: 60 }),
      Animated.spring(animTop, { toValue: translateY, useNativeDriver: false, friction: 8, tension: 60 }),
      Animated.spring(animRotate, { toValue: angle, useNativeDriver: false, friction: 8, tension: 60 }),
      Animated.spring(animScale, { toValue: 1, useNativeDriver: false, friction: 8, tension: 60 }),
    ]).start();
  }, [index, numCartas]);

  useEffect(() => {
    return () => {
      prevPositions.current[carta.uid] = index * OVERLAP;
    };
  }, [index]);

  const rotateStr = animRotate.interpolate({
    inputRange: [-30, 30],
    outputRange: ['-30deg', '30deg'],
  });

  return (
    <Animated.View
      {...panResponder.panHandlers}
      style={[
        styles.cartaWrapper,
        {
          left: animLeft,
          top: Animated.add(animTop, dragY),
          opacity: animOpacity,
          transform: [
            { rotate: rotateStr },
            { scale: animScale },
          ],
          zIndex: index,
        },
      ]}
    >
      <CartaArena
        carta={carta}
        onPress={() => {}}
        selecionada={false}
        desabilitada={desabilitado || falido}
      />
    </Animated.View>
  );
}

export default function MaoJogador({ jogador, cartaSelecionada, onSelecionarCarta, onAnimacaoSaidaCompleta, onDescartar, desabilitado, hideStatus = false, onZoomCarta }) {
  const prevPositions = useRef({});
  const longPressTimer = useRef(null);
  const [panelPressed, setPanelPressed] = useState(false);

  const handleJogarCarta = (carta) => {
    if (onAnimacaoSaidaCompleta) onAnimacaoSaidaCompleta(carta);
  };

  const handlePressCarta = (carta) => {
    soundManager.playCardDraw();
    if (onZoomCarta) onZoomCarta(carta);
  };

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
      {/* Brilho decorativo no topo direito da mão de cartas */}
      <Text style={styles.sparkleAccent}>✨</Text>

      <View style={[styles.maoContainer, { width: totalWidth }]}>
        <View style={[styles.mao, { width: totalWidth, height: CARD_HEIGHT + 30 }]}>
          {jogador.mao.map((carta, index) => (
            <CartaAnimada
              key={carta.uid}
              carta={carta}
              index={index}
              numCartas={numCartas}
              desabilitado={desabilitado}
              falido={jogador.falido}
              onPress={handlePressCarta}
              onJogar={handleJogarCarta}
              prevPositions={prevPositions}
            />
          ))}
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
  },
  sparkleAccent: {
    position: 'absolute',
    top: -16,
    right: 10,
    fontSize: 18,
    color: '#FFF8E7',
    zIndex: 10,
    opacity: 0.85,
  },
  maoContainer: {
    alignItems: 'center',
    marginBottom: 5,
    zIndex: 1,
  },
  mao: {
    position: 'relative',
    alignItems: 'flex-start',
  },
  cartaWrapper: {
    position: 'absolute',
    top: 0,
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