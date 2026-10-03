import React, { useEffect, useRef } from 'react';
import { View, Image, StyleSheet, Animated, Dimensions } from 'react-native';

const { width: SCREEN_WIDTH, height: SCREEN_HEIGHT } = Dimensions.get('window');
const GUIA_SPRITE = require('../../assets/avatares/guia.png');

// =============================================================================
// FUNDO CICLICO — fundo que muda sem parar entre tons de preto e cinza
// (preto -> cinza escuro -> cinza -> volta), em loop suave.
// =============================================================================
export function FundoCiclico() {
  const t = useRef(new Animated.Value(0)).current;

  useEffect(() => {
    // Ping-pong: preto <-> cinza, passando por tons intermediarios na ida.
    const anim = Animated.loop(
      Animated.sequence([
        Animated.timing(t, { toValue: 1, duration: 1800, useNativeDriver: false }),
        Animated.timing(t, { toValue: 0, duration: 1800, useNativeDriver: false }),
      ])
    );
    anim.start();
    return () => anim.stop();
  }, [t]);

  const cor = t.interpolate({
    inputRange: [0, 0.5, 1],
    outputRange: ['rgb(0,0,0)', 'rgb(45,45,45)', 'rgb(120,120,120)'],
  });

  return (
    <Animated.View
      pointerEvents="none"
      style={[styles.fundo, { backgroundColor: cor }]}
    />
  );
}

// =============================================================================
// SPRITE GUIA — sprite do Guia (src/assets/avatares/guia.png) com halo de luz
// atras. Respira sempre; TREMOR quando o GUIA fala (prop `falando`).
// =============================================================================
export function SpriteGuia({ falando = false, tamanho = null }) {
  const tremor = useRef(new Animated.Value(0)).current;
  const respir = useRef(new Animated.Value(0)).current;
  const base = Math.min(SCREEN_WIDTH, SCREEN_HEIGHT) * 0.24;
  const D = tamanho != null ? tamanho : base;
  // Caixa de layout do sprite: por padrao o halo folgado; com `tamanho`, compacta.
  const wrap = tamanho != null ? tamanho * 2.6 : base * 3.4;

  // Respiracao lenta permanente (vida parada).
  useEffect(() => {
    const anim = Animated.loop(
      Animated.sequence([
        Animated.timing(respir, { toValue: 1, duration: 1500, useNativeDriver: true }),
        Animated.timing(respir, { toValue: 0, duration: 1500, useNativeDriver: true }),
      ])
    );
    anim.start();
    return () => anim.stop();
  }, [respir]);

  // Tremor rapido ligado/desligado conforme quem esta falando.
  useEffect(() => {
    if (!falando) {
      tremor.stopAnimation();
      tremor.setValue(0);
      return undefined;
    }
    const anim = Animated.loop(
      Animated.sequence([
        Animated.timing(tremor, { toValue: 1, duration: 70, useNativeDriver: true }),
        Animated.timing(tremor, { toValue: -1, duration: 70, useNativeDriver: true }),
      ])
    );
    anim.start();
    return () => anim.stop();
  }, [falando, tremor]);

  const haloOp = respir.interpolate({
    inputRange: [0, 1],
    outputRange: falando ? [0.8, 1] : [0.55, 0.95],
  });
  const escalaRespir = respir.interpolate({ inputRange: [0, 1], outputRange: [1, 1.06] });
  const tremX = tremor.interpolate({ inputRange: [-1, 1], outputRange: [-3, 3] });
  const tremY = tremor.interpolate({ inputRange: [-1, 1], outputRange: [2.2, -2.2] });
  const tremEsc = tremor.interpolate({ inputRange: [-1, 0, 1], outputRange: [1.05, 1, 1.05] });

  return (
    <Animated.View
      pointerEvents="none"
      style={[
        styles.haloWrap,
        { width: wrap, height: wrap, opacity: haloOp, transform: [{ scale: escalaRespir }] },
      ]}
    >
      <View
        style={[
          styles.circulo,
          { width: D * 2.3, height: D * 2.3, borderRadius: D * 1.15, backgroundColor: 'rgba(255,255,255,0.16)' },
        ]}
      >
        <View
          style={[
            styles.circulo,
            { width: D * 1.5, height: D * 1.5, borderRadius: D * 0.75, backgroundColor: 'rgba(255,255,255,0.3)' },
          ]}
        >
          <Animated.View
            style={{ transform: [{ translateX: tremX }, { translateY: tremY }, { scale: tremEsc }] }}
          >
            <Image source={GUIA_SPRITE} style={{ width: D, height: D }} resizeMode="contain" />
          </Animated.View>
        </View>
      </View>
    </Animated.View>
  );
}

const styles = StyleSheet.create({
  fundo: {
    ...StyleSheet.absoluteFillObject,
    backgroundColor: '#000000',
    zIndex: 0,
  },
  haloWrap: {
    alignItems: 'center',
    justifyContent: 'center',
  },
  circulo: {
    alignItems: 'center',
    justifyContent: 'center',
  },
});
