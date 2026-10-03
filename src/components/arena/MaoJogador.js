import React, { useRef, useEffect, useState, useMemo } from 'react';
import { View, StyleSheet, Dimensions, Pressable, PanResponder } from 'react-native';
import Text from '../Texto';
import Animated, {
  Easing,
  useSharedValue,
  useAnimatedStyle,
  withTiming,
  withSequence,
  withSpring,
} from 'react-native-reanimated';
import CartaArena from './CartaArena';
import PainelStatus from './PainelStatus';
import { soundManager } from '../../utils/sound';

const CARD_WIDTH = 68;
const CARD_HEIGHT = 95;
const OVERLAP = 30;
const LIFT_SELECIONADA = 16;
const LONG_PRESS_ZOOM_MS = 800;
const STAGGER_DELAY = 50;
const { width: SCREEN_WIDTH } = Dimensions.get('window');

const HIGHLIGHT_DURATION = 3000;

// Movimento seco e sem balanco (estilo Balatro): timing curto com easing
// de saida. A mola da selecao e quase amortecida - sobe e para.
const MOVE_MS = 140;
const MOVE_EASING = Easing.out(Easing.cubic);
const SELECT_SPRING = { damping: 20, stiffness: 420, mass: 0.4 };

function CartaAnimada({ carta, index, numCartas, overlap, desabilitado, falido, selecionada, onToggleSelecionar, onZoom, prevPositions, isRecentDrawn, arrastando, onArrastoInicio, onArrastoFim }) {
  const animLeft = useSharedValue(index * overlap);
  const animTop = useSharedValue(0);
  const animRotate = useSharedValue(0);
  const animScale = useSharedValue(1);
  const animOpacity = useSharedValue(0);
  const animGlow = useSharedValue(0);
  const animHighlight = useSharedValue(0);
  const montadaRef = useRef(false);
  // Posicao-alvo aplicada na mao durante o arrasto (evita pular no drop).
  const manualLeftRef = useRef(null);
  const dragRef = useRef(null);

  // Referencia estavel para o PanResponder ler nos callbacks (evita
  // recriar o responder a cada render).
  const handlersRef = useRef({});
  handlersRef.current = { carta, onArrastoInicio, onArrastoFim, podeArrastar: !falido };

  const panResponderRef = useRef(null);
  if (!panResponderRef.current) {
    const limparTransform = () => {
      if (dragRef.current) dragRef.current.setNativeProps({ transform: [] });
    };
    panResponderRef.current = PanResponder.create({
      onStartShouldSetPanResponder: () => false,
      // So captura depois de um movimento claro (tap e long-press
      // continuam pertencendo ao Pressable).
      onMoveShouldSetPanResponder: (_, g) =>
        handlersRef.current.podeArrastar &&
        (Math.abs(g.dx) > 8 || Math.abs(g.dy) > 8),
      onPanResponderGrant: () => {
        if (handlersRef.current.onArrastoInicio) {
          handlersRef.current.onArrastoInicio(handlersRef.current.carta.uid);
        }
        if (dragRef.current) {
          dragRef.current.setNativeProps({
            transform: [{ translateX: 0 }, { translateY: -8 }, { scale: 1.06 }],
          });
        }
      },
      onPanResponderMove: (_, g) => {
        if (dragRef.current) {
          dragRef.current.setNativeProps({
            transform: [{ translateX: g.dx }, { translateY: g.dy - 8 }, { scale: 1.06 }],
          });
        }
      },
      onPanResponderRelease: (_, g) => {
        const h = handlersRef.current;
        const finalLeft = h.onArrastoFim ? h.onArrastoFim(h.carta.uid, g.dx) : null;
        if (finalLeft != null) {
          // Drop em outra posicao: aplica a posicao final na hora (o
          // transform some junto, sem salto visual) e deixa o efeito de
          // entrada cuidar das demais cartas.
          manualLeftRef.current = finalLeft;
          animLeft.value = finalLeft;
        }
        limparTransform();
      },
      onPanResponderTerminate: () => {
        limparTransform();
        const h = handlersRef.current;
        if (h.onArrastoFim) h.onArrastoFim(h.carta.uid, 0);
      },
    });
  }

  const maxAngle = 10;
  const angleStep = numCartas > 1 ? (maxAngle * 2) / (numCartas - 1) : 0;
  const offsetFromCenter = index - (numCartas - 1) / 2;
  const angle = numCartas > 1 ? offsetFromCenter * angleStep : 0;

  const curvature = numCartas > 3 ? 5 : 3;
  const normalizedOffset = numCartas > 1 ? offsetFromCenter / ((numCartas - 1) / 2) : 0;
  const translateYBase = Math.pow(Math.abs(normalizedOffset), 1.3) * curvature;
  const translateYAlvo = translateYBase - (selecionada ? LIFT_SELECIONADA : 0);

  const wrapperStyle = useAnimatedStyle(() => ({
    left: animLeft.value,
    top: animTop.value,
    transform: [
      { rotate: `${animRotate.value}deg` },
      { scale: animScale.value },
    ],
    opacity: animOpacity.value,
    zIndex: selecionada || arrastando ? 50 + index : index,
  }));

  const glowStyle = useAnimatedStyle(() => ({
    opacity: animGlow.value,
  }));

  const highlightStyle = useAnimatedStyle(() => ({
    opacity: animHighlight.value,
    shadowOpacity: animHighlight.value,
  }));

  // Efeito de ENTRADA/REFLOW: distribui a mao (posicao horizontal, leque,
  // fade-in) com o atraso escalonado por carta. Roda so quando o numero de
  // cartas ou a posicao na mao muda - NAO quando so a selecao muda, pra nao
  // reacionar o atraso toda vez que o jogador toca numa carta.
  useEffect(() => {
    const prev = prevPositions.current[carta.uid];
    const newLeft = index * overlap;

    if (prev !== undefined && prev !== newLeft) {
      animLeft.value = prev;
    }

    const entradaDelay = index * STAGGER_DELAY;

    setTimeout(() => {
      // Timing seco, sem overshoot: as cartas escorregam pro lugar e
      // param (Balatro). A rotacao vai para o angulo fixo do leque -
      // nada de aleatorio, que era o que fazia a mao "balancar".
      animLeft.value = withTiming(newLeft, { duration: MOVE_MS, easing: MOVE_EASING });
      animRotate.value = withTiming(angle, { duration: MOVE_MS, easing: MOVE_EASING });
      animOpacity.value = withTiming(1, { duration: 160 });
      if (!montadaRef.current) {
        animTop.value = withTiming(translateYAlvo, { duration: 160, easing: MOVE_EASING });
        animScale.value = withTiming(1, { duration: 160 });
        montadaRef.current = true;
      }
    }, entradaDelay);
  }, [index, numCartas, overlap]);

  // Efeito de SELECIONAR/DESSELECIONAR: sem atraso nenhum, mola bem mais
  // rigida (alta stiffness, massa baixa) para um "snap" quase instantaneo,
  // igual a resposta de selecionar carta no Balatro.
  useEffect(() => {
    if (!montadaRef.current) return; // a entrada acima ja cobre a 1a vez
    animTop.value = withSpring(translateYAlvo, SELECT_SPRING);
    animScale.value = withSpring(selecionada ? 1.05 : 1, SELECT_SPRING);
  }, [selecionada, translateYAlvo]);

  useEffect(() => {
    if (isRecentDrawn) {
      soundManager.playCardHighlight();
      // Destaque da carta recem-comprada: um unico clarao que assenta
      // (sem piscar em loop - era balanco desnecessario).
      animHighlight.value = withSequence(
        withTiming(0.9, { duration: 250 }),
        withTiming(0.6, { duration: 350 })
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
      // Posicao aplicada manualmente no drop do arrasto tem prioridade
      // sobre a posicao anterior por indice.
      prevPositions.current[carta.uid] = manualLeftRef.current ?? index * overlap;
      manualLeftRef.current = null;
    };
  }, [index, overlap]);

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
      <View ref={dragRef} collapsable={false} {...panResponderRef.current.panHandlers}>
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
      </View>
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
  // Ordem exibida da mao (organizacao manual por arrasto). Guarda uids;
  // a ordem do engine nao e alterada.
  const [ordemUids, setOrdemUids] = useState([]);
  const [uidArrastando, setUidArrastando] = useState(null);

  const mao = jogador?.mao || [];
  const cartasExibidas = useMemo(() => {
    const porUid = new Map(mao.map((c) => [c.uid, c]));
    const lista = [];
    for (const uid of ordemUids) {
      const carta = porUid.get(uid);
      if (carta) {
        lista.push(carta);
        porUid.delete(uid);
      }
    }
    // Cartas ainda nao listadas (compra, roubo): entram no fim.
    for (const carta of mao) {
      if (porUid.has(carta.uid)) lista.push(carta);
    }
    return lista;
  }, [mao, ordemUids]);

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

  const numCartas = cartasExibidas.length;
  // Espacamento dinamico: quando a mao acumula (ex.: roubo), encolhe o
  // passo entre as cartas para a mao inteira caber na tela.
  const larguraMax = SCREEN_WIDTH - 24;
  const overlap =
    numCartas > 1
      ? Math.max(12, Math.min(OVERLAP, (larguraMax - CARD_WIDTH) / (numCartas - 1)))
      : OVERLAP;
  const totalWidth = CARD_WIDTH + Math.max(numCartas - 1, 0) * overlap;

  const handleArrastoInicio = (uid) => setUidArrastando(uid);

  // Finaliza o arrasto: calcula o destino e devolve o left final para a
  // carta aplicar sem salto visual. null = nao mudou de posicao.
  const handleArrastoFim = (uid, dx) => {
    setUidArrastando(null);
    const from = cartasExibidas.findIndex((c) => c.uid === uid);
    if (from === -1) return null;
    const alvo = Math.round((from * overlap + dx) / overlap);
    const to = Math.max(0, Math.min(cartasExibidas.length - 1, alvo));
    if (to === from) return null;
    const nova = [...cartasExibidas];
    const [c] = nova.splice(from, 1);
    nova.splice(to, 0, c);
    setOrdemUids(nova.map((x) => x.uid));
    soundManager.playSelect();
    return to * overlap;
  };

  return (
    <View style={styles.container}>
      <Text style={styles.sparkleAccent}>✨</Text>

      <View style={styles.maoContainer}>
        <View style={[styles.mao, { width: totalWidth, height: CARD_HEIGHT + 30 + LIFT_SELECIONADA }]}>
          {cartasExibidas.map((carta, index) => {
            const selecionada = cartasSelecionadas.some((c) => c.uid === carta.uid);
            return (
              <CartaAnimada
                key={carta.uid}
                carta={carta}
                index={index}
                numCartas={numCartas}
                overlap={overlap}
                desabilitado={desabilitado}
                falido={jogador.falido}
                selecionada={selecionada}
                onToggleSelecionar={onSelecionarCarta}
                onZoom={onZoomCarta}
                prevPositions={prevPositions}
                isRecentDrawn={carta.uid === cartaRecemCompradaUid}
                arrastando={uidArrastando === carta.uid}
                onArrastoInicio={handleArrastoInicio}
                onArrastoFim={handleArrastoFim}
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