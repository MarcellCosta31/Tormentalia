import React, { useState, useCallback, useEffect, useRef } from 'react';
import { View, StyleSheet, Image, Dimensions, Pressable } from 'react-native';
import Text from '../Texto';
import Animated, {
  useSharedValue,
  useAnimatedStyle,
  withTiming,
  withSequence,
  withSpring,
  withDelay,
  interpolate,
} from 'react-native-reanimated';
import { GameProvider, useGameState } from '../../context/GameContext';
import { useIA } from '../../hooks/useIA';
import MaoJogador from './MaoJogador';
import MaoOponente from './MaoOponente';
import TurnoIndicador from './TurnoIndicador';
import DecksArea from './DecksArea';
import PainelStatus from './PainelStatus';
import CartaZoomModal from './CartaZoomModal';
import { soundManager } from '../../utils/sound';
import { artePorCarta } from '../../cards/arteCarta';

const bgImg = require('../../assets/sprites/batalha/background.jpg');
const traseiraImg = require('../../assets/cards/traseira_cartas.jpg');

const imgPorCarta = (c) => artePorCarta(c) || traseiraImg;

const { width: SCREEN_WIDTH, height: SCREEN_HEIGHT } = Dimensions.get('screen');

const CARD_W = 70;
const CARD_H = 98;
const DECK_W = 58;
const DECK_H = 81;
const DECK_GAP = 36;

const DECKS_WRAPPER_Y = SCREEN_HEIGHT * 0.44;
const DECKS_TOTAL_W = DECK_W * 2 + DECK_GAP;
const DECKS_START_X = (SCREEN_WIDTH - DECKS_TOTAL_W) / 2;

const DECKS_POS = {
  drawX: DECKS_START_X,
  drawY: DECKS_WRAPPER_Y,
  descX: DECKS_START_X + DECK_W + DECK_GAP,
  descY: DECKS_WRAPPER_Y,
};

const POS_MAO_JOGADOR = { x: SCREEN_WIDTH / 2 - 30, y: SCREEN_HEIGHT - 130 };

const LIFT_DURACAO = 200;
const VOO_DURACAO  = 400;
const FADE_DURACAO = 120;
const STAGGER_CARTAS = 220;

function CartaVoadora({ imgSource, deX, deY, paraX, paraY, onCompleto, duracao = 400 }) {
  const posX = useSharedValue(deX);
  const posY = useSharedValue(deY);
  const escala = useSharedValue(1);
  const opacidade = useSharedValue(1);

  const style = useAnimatedStyle(() => ({
    left: posX.value,
    top: posY.value,
    opacity: opacidade.value,
    transform: [{ scale: escala.value }],
  }));

  useEffect(() => {
    posX.value = withSequence(
      withTiming(paraX, { duration: duracao }),
    );
    posY.value = withSequence(
      withTiming(paraY, { duration: duracao }),
    );
    escala.value = withTiming(0.7, { duration: duracao });
    opacidade.value = withSequence(
      withDelay(duracao, withTiming(0, { duration: 150 })),
    );

    const timer = setTimeout(() => {
      if (onCompleto) onCompleto();
    }, duracao + 200);

    return () => clearTimeout(timer);
  }, []);

  return (
    <Animated.View style={[styles.cartaVoadora, style]}>
      <Image source={imgSource} style={styles.cartaVoadoraImg} resizeMode="cover" />
    </Animated.View>
  );
}

function CartaSaidaComLift({ imgSource, deX, deY, paraX, paraY, duracao = VOO_DURACAO, delay = 0, onCompleto }) {
  const posX     = useSharedValue(deX);
  const posY     = useSharedValue(deY);
  const escala   = useSharedValue(1);
  const rotacao  = useSharedValue(0);
  const opacidade = useSharedValue(1);

  const cbCompleto = onCompleto;

  const style = useAnimatedStyle(() => ({
    left: posX.value,
    top: posY.value,
    opacity: opacidade.value,
    transform: [
      { scale: escala.value },
      { rotate: `${interpolate(rotacao.value, [0, 1], [0, -8])}deg` },
    ],
  }));

  useEffect(() => {
    const somTimer = setTimeout(() => soundManager.playCardPlay(), delay);

    const executarAnimacao = () => {
      // FASE 1 — lift
      posY.value = withTiming(deY - 55, { duration: LIFT_DURACAO });
      escala.value = withTiming(1.22, { duration: LIFT_DURACAO });
      rotacao.value = withTiming(1, { duration: LIFT_DURACAO });

      // FASE 2 — voo
      setTimeout(() => {
        posX.value = withTiming(paraX, { duration: duracao });
        posY.value = withTiming(paraY, { duration: duracao });
        escala.value = withTiming(0.7, { duration: duracao });
        rotacao.value = withTiming(0, { duration: duracao });

        // FASE 3 — fade
        setTimeout(() => {
          opacidade.value = withTiming(0, { duration: FADE_DURACAO });
          setTimeout(() => { if (cbCompleto) cbCompleto(); }, FADE_DURACAO);
        }, duracao);
      }, LIFT_DURACAO);
    };

    const timer = setTimeout(executarAnimacao, delay);

    return () => {
      clearTimeout(somTimer);
      clearTimeout(timer);
    };
  }, []);

  return (
    <Animated.View style={[styles.cartaVoadora, style]}>
      <Image source={imgSource} style={styles.cartaVoadoraImg} resizeMode="cover" />
    </Animated.View>
  );
}

function ArenaInterna() {
  const { estado, passarTurno, resetarJogo, dispatch } = useGameState();
  const [cartasSelecionadas, setCartasSelecionadas] = useState([]);
  const [cartasDescarte, setCartasDescarte] = useState([]);
  const [voadora2, setVoadora2] = useState(null);
  const [panelPressed, setPanelPressed] = useState(false);
  const [cartaZoom, setCartaZoom] = useState(null);
  const longPressTimer = useRef(null);

  const { iaExecutando } = useIA(estado, dispatch);

  const MAX_CARTAS_POR_TURNO = 2;

  useEffect(() => {
    setCartasSelecionadas([]);
  }, [estado?.jogadorAtivoIndex, estado?.turnoAtual]);

  useEffect(() => {
    if (estado?.fimDeJogo) {
      if (estado.fimDeJogo.vencedor === 1) {
        soundManager.playVictory();
      } else if (estado.fimDeJogo.vencedor === 2) {
        soundManager.playDefeat();
      }
    }
  }, [estado?.fimDeJogo]);

  const jogadorLocal = estado?.jogadores[0];
  const oponenteIA = estado?.jogadores[1];
  const isMinhaVez = estado?.jogadorAtivoIndex === 0 && !estado?.fimDeJogo;
  const jogadoresDesabilitado = !isMinhaVez;

  const nomeJogadorAtivo = isMinhaVez
    ? (jogadorLocal?.nome || 'JOGADOR_1')
    : (oponenteIA?.nome || 'Adam Smith');

  const handleToggleSelectCarta = useCallback((carta) => {
    if (!isMinhaVez) return;
    setCartasSelecionadas((prev) => {
      const jaSelecionada = prev.some((c) => c.uid === carta.uid);
      if (jaSelecionada) {
        return prev.filter((c) => c.uid !== carta.uid);
      }
      if (prev.length >= MAX_CARTAS_POR_TURNO) return prev;
      return [...prev, carta];
    });
  }, [isMinhaVez]);

  const handleJogarMao = useCallback(() => {
    if (!isMinhaVez || cartasSelecionadas.length === 0) return;

    const cartasParaJogar = [...cartasSelecionadas];
    setCartasSelecionadas([]);

    dispatch({
      type: 'JOGAR_CARTAS_SEM_COMPRA',
      payload: { jogadorId: jogadorLocal.id, cartas: cartasParaJogar },
    });

    const novasVoadoras = cartasParaJogar.map((carta, i) => {
      const key = `saida_${i}_${Date.now()}_${Math.random().toString(36).slice(2, 8)}`;
      return {
        key,
        imgSource: imgPorCarta(carta),
        deX: POS_MAO_JOGADOR.x + i * 16,
        deY: POS_MAO_JOGADOR.y - i * 6,
        paraX: DECKS_POS.descX,
        paraY: DECKS_POS.descY,
        duracao: VOO_DURACAO,
        delay: i * STAGGER_CARTAS,
        onCompleto: () => setCartasDescarte((prev) => prev.filter((v) => v.key !== key)),
      };
    });
    setCartasDescarte((prev) => [...prev, ...novasVoadoras]);

    const tempoUltimaSaida = (cartasParaJogar.length - 1) * STAGGER_CARTAS
                           + LIFT_DURACAO + VOO_DURACAO + FADE_DURACAO;
    const atrasoCompra = tempoUltimaSaida + 100;

    setTimeout(() => {
      setVoadora2({
        key: `comprar_${Date.now()}`,
        imgSource: traseiraImg,
        deX: DECKS_POS.drawX,
        deY: DECKS_POS.drawY,
        paraX: POS_MAO_JOGADOR.x,
        paraY: POS_MAO_JOGADOR.y,
        duracao: 400,
        onCompleto: () => {
          setVoadora2(null);
          soundManager.playCardDraw();
          passarTurno();
        },
      });
    }, atrasoCompra);
  }, [isMinhaVez, cartasSelecionadas, jogadorLocal, passarTurno, dispatch]);

  const handlePassarTurno = useCallback(() => {
    if (!isMinhaVez) return;
    setCartasSelecionadas([]);
    passarTurno();
  }, [isMinhaVez, passarTurno]);

  const handlePanelPressIn = () => {
    if (!isMinhaVez) return;
    setPanelPressed(true);
    longPressTimer.current = setTimeout(() => {
      soundManager.playPassTurn();
      handlePassarTurno();
    }, 800);
  };

  const handlePanelPressOut = () => {
    setPanelPressed(false);
    if (longPressTimer.current) {
      clearTimeout(longPressTimer.current);
      longPressTimer.current = null;
    }
  };

  if (!estado) return null;

  return (
    <View style={styles.container}>
      <Image source={bgImg} style={styles.bg} resizeMode="cover" />

      <View style={styles.spotlight} pointerEvents="none" />

      <View style={styles.topLeftWrapper}>
        <TurnoIndicador
          nomeJogadorAtivo={nomeJogadorAtivo}
          turnoAtual={estado.turnoAtual ?? 1}
          totalTurnos={estado.totalTurnos ?? 10}
        />
      </View>

      <View style={styles.topCenterWrapper}>
        <MaoOponente jogador={oponenteIA} hideStatus={false} />
      </View>

      <View style={styles.centerDecksWrapper}>
        <DecksArea
          baralho={estado.baralho}
          pilhaDescarte={estado.pilhaDescarte}
        />
      </View>

      <View style={styles.bottomCenterWrapper}>
        <Pressable
          onPressIn={handlePanelPressIn}
          onPressOut={handlePanelPressOut}
          style={styles.painelPressable}
        >
          <PainelStatus nome={jogadorLocal?.nome || 'JOGADOR_1'} saldo={jogadorLocal?.saldo ?? 20} corDestaque="#FFD54F" />
          {panelPressed && (
            <View style={styles.passarOverlay}>
              <Text style={styles.passarTexto}>SOLTAR PARA PASSAR</Text>
            </View>
          )}
        </Pressable>
      </View>

      <View style={styles.bottomRightWrapper}>
        <MaoJogador
          jogador={jogadorLocal}
          cartasSelecionadas={cartasSelecionadas}
          onSelecionarCarta={handleToggleSelectCarta}
          onDescartar={handlePassarTurno}
          desabilitado={jogadoresDesabilitado}
          hideStatus={true}
          onZoomCarta={(carta) => setCartaZoom(carta)}
        />
      </View>

      {isMinhaVez && cartasSelecionadas.length > 0 && (
        <Pressable
          style={styles.botaoJogar}
          onPress={handleJogarMao}
        >
          <Text style={styles.botaoJogarTexto}>JOGAR</Text>
          <Text style={styles.botaoJogarContador}>{cartasSelecionadas.length}/{MAX_CARTAS_POR_TURNO}</Text>
        </Pressable>
      )}

      {cartasDescarte.map((v) => (
        <CartaSaidaComLift
          key={v.key}
          imgSource={v.imgSource}
          deX={v.deX}
          deY={v.deY}
          paraX={v.paraX}
          paraY={v.paraY}
          duracao={v.duracao}
          delay={v.delay}
          onCompleto={v.onCompleto}
        />
      ))}

      {voadora2 && (
        <CartaVoadora
          key={voadora2.key}
          imgSource={voadora2.imgSource}
          deX={voadora2.deX}
          deY={voadora2.deY}
          paraX={voadora2.paraX}
          paraY={voadora2.paraY}
          duracao={voadora2.duracao}
          onCompleto={voadora2.onCompleto}
        />
      )}

      {estado.fimDeJogo && (
        <View style={styles.overlayFim}>
          <View style={styles.overlayCard}>
            <Text style={styles.overlayTitulo}>
              {estado.fimDeJogo.vencedor === 1 ? 'VOCE VENCEU!' : estado.fimDeJogo.vencedor === 2 ? 'OPONENTE VENCEU!' : 'EMPATE!'}
            </Text>
            <Text style={styles.overlayMotivo}>{estado.fimDeJogo.motivo}</Text>
            <Text style={styles.overlayPlacar}>
              Voce: R$ {jogadorLocal.saldo} | Oponente: R$ {oponenteIA.saldo}
            </Text>
            <Text style={styles.botaoReiniciar} onPress={resetarJogo}>
              JOGAR NOVAMENTE
            </Text>
          </View>
        </View>
      )}

      <CartaZoomModal
        carta={cartaZoom}
        visivel={!!cartaZoom}
        onFechar={() => setCartaZoom(null)}
      />
    </View>
  );
}

export default function ArenaCombate({ onVoltar }) {
  return (
    <GameProvider>
      <View style={styles.container}>
        <ArenaInterna />
      </View>
    </GameProvider>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#0A0A1A',
  },
  bg: {
    position: 'absolute',
    width: SCREEN_WIDTH,
    height: SCREEN_HEIGHT,
  },
  spotlight: {
    position: 'absolute',
    top: '25%',
    left: '20%',
    width: '60%',
    height: '45%',
    borderRadius: 150,
    backgroundColor: 'rgba(255, 235, 175, 0.08)',
    zIndex: 1,
  },
  topLeftWrapper: {
    position: 'absolute',
    top: 6,
    left: 6,
    zIndex: 30,
  },
  topCenterWrapper: {
    position: 'absolute',
    top: 10,
    width: '100%',
    alignItems: 'center',
    zIndex: 15,
  },
  centerDecksWrapper: {
    position: 'absolute',
    top: SCREEN_HEIGHT * 0.44,
    width: '100%',
    alignItems: 'center',
    zIndex: 10,
  },
  bottomCenterWrapper: {
    position: 'absolute',
    bottom: 12,
    alignSelf: 'center',
    zIndex: 20,
  },
  painelPressable: {
    position: 'relative',
  },
  passarOverlay: {
    ...StyleSheet.absoluteFillObject,
    backgroundColor: 'rgba(230, 81, 0, 0.88)',
    borderRadius: 6,
    alignItems: 'center',
    justifyContent: 'center',
  },
  passarTexto: {
    color: '#FFF',
    fontWeight: 'bold',
    fontSize: 11,
    letterSpacing: 1.5,
  },
  bottomRightWrapper: {
    position: 'absolute',
    bottom: 0,
    left: 0,
    right: 0,
    alignItems: 'center',
    zIndex: 25,
  },
  cartaVoadora: {
    position: 'absolute',
    width: CARD_W,
    height: CARD_H,
    zIndex: 100,
  },
  cartaVoadoraImg: {
    width: '100%',
    height: '100%',
    borderRadius: 6,
  },
  overlayFim: {
    ...StyleSheet.absoluteFillObject,
    backgroundColor: 'rgba(0, 0, 0, 0.85)',
    alignItems: 'center',
    justifyContent: 'center',
    zIndex: 50,
  },
  overlayCard: {
    backgroundColor: '#1E1E2E',
    borderRadius: 12,
    borderWidth: 2,
    borderColor: '#FFD54F',
    padding: 24,
    alignItems: 'center',
    maxWidth: '80%',
  },
  overlayTitulo: {
    fontSize: 24,
    color: '#FFD54F',
    fontWeight: 'bold',
    marginBottom: 8,
  },
  overlayMotivo: {
    fontSize: 14,
    color: '#CCC',
    textAlign: 'center',
    marginBottom: 12,
  },
  overlayPlacar: {
    fontSize: 16,
    color: '#FFF',
    fontWeight: 'bold',
    marginBottom: 20,
  },
  botaoReiniciar: {
    backgroundColor: '#2E7D32',
    borderRadius: 8,
    paddingHorizontal: 24,
    paddingVertical: 12,
    color: '#FFF',
    fontWeight: 'bold',
    fontSize: 16,
    overflow: 'hidden',
  },
  botaoJogar: {
    position: 'absolute',
    bottom: 20,
    left: 12,
    backgroundColor: '#2E7D32',
    borderRadius: 10,
    paddingHorizontal: 16,
    paddingVertical: 10,
    alignItems: 'center',
    justifyContent: 'center',
    zIndex: 30,
    elevation: 6,
    borderWidth: 2,
    borderColor: '#66BB6A',
  },
  botaoJogarTexto: {
    color: '#FFF',
    fontWeight: 'bold',
    fontSize: 16,
    letterSpacing: 1,
  },
  botaoJogarContador: {
    color: '#C8E6C9',
    fontSize: 11,
    marginTop: 2,
  },
});
