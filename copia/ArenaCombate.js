import React, { useState, useCallback, useEffect, useRef } from 'react';
import { View, Text, StyleSheet, Image, Animated, Dimensions, Pressable, Modal, TouchableOpacity } from 'react-native';
import { GameProvider, useGameState } from '../context/GameContext';
import { useIA } from '../hooks/useIA';
import { useMultiplayer } from '../multiplayer/useMultiplayer';
import MaoJogador from '../components/arena/MaoJogador';
import MaoOponente from '../components/arena/MaoOponente';
import TurnoIndicador from '../components/arena/TurnoIndicador';
import DecksArea from '../components/arena/DecksArea';
import PainelStatus from '../components/arena/PainelStatus';
import CartaZoomModal from '../components/arena/CartaZoomModal';
import AnimacaoInicioBatalha from '../components/arena/AnimacaoInicioBatalha';
import { soundManager } from '../utils/sound';

const bgImg = require('../assets/sprites/batalha/background.png');
const traseiraImg = require('../assets/cards/traseira_cartas.jpg');
const nossoImg = require('../assets/cards/nosso.png');
const toyotinhoImg = require('../assets/cards/toyotinho.png');
const pauseImg = require('../assets/sprites/menu/pause.jpg');

const cardImages = {
  0: nossoImg,
  1: toyotinhoImg,
};

const { width: SCREEN_WIDTH, height: SCREEN_HEIGHT } = Dimensions.get('window');

const CARD_W = 60;
const CARD_H = 84;

const DECK_W = 58;
const DECK_H = 81;
const DECK_GAP = 36;
const DECKS_Y = SCREEN_HEIGHT * 0.44 + DECK_H / 2;
const DECK_DRAW_X = SCREEN_WIDTH / 2 - DECK_W - DECK_GAP / 2;
const DECK_DESC_X = SCREEN_WIDTH / 2 + DECK_GAP / 2;

const POS_MAO_JOGADOR = { x: SCREEN_WIDTH - 140, y: SCREEN_HEIGHT - 110 };
const POS_MAO_OPONENTE = { x: SCREEN_WIDTH / 2 - 30, y: 30 };

const DECKS_POS = { drawX: DECK_DRAW_X, drawY: DECKS_Y, descX: DECK_DESC_X, descY: DECKS_Y };

function CartaVoadora({ imgSource, deX, deY, paraX, paraY, onCompleto, duracao = 400 }) {
  const posX = useRef(new Animated.Value(deX)).current;
  const posY = useRef(new Animated.Value(deY)).current;
  const escala = useRef(new Animated.Value(1)).current;
  const opacidade = useRef(new Animated.Value(1)).current;

  useEffect(() => {
    Animated.sequence([
      Animated.parallel([
        Animated.timing(posX, { toValue: paraX, duration: duracao, useNativeDriver: false }),
        Animated.timing(posY, { toValue: paraY, duration: duracao, useNativeDriver: false }),
        Animated.timing(escala, { toValue: 0.6, duration: duracao, useNativeDriver: false }),
      ]),
      Animated.timing(opacidade, { toValue: 0, duration: 150, useNativeDriver: false }),
    ]).start(() => {
      if (onCompleto) onCompleto();
    });
  }, []);

  return (
    <Animated.View style={[styles.cartaVoadora, { left: posX, top: posY, opacity: opacidade, transform: [{ scale: escala }] }]}>
      <Image source={imgSource} style={styles.cartaVoadoraImg} resizeMode="cover" />
    </Animated.View>
  );
}

function ArenaInterna({ onVoltar, multiplayerConfig }) {
  const { estado, jogarCarta, passarTurno, resetarJogo, dispatch } = useGameState();
  const [cartaSelecionada, setCartaSelecionada] = useState(null);
  const [voadora, setVoadora] = useState(null);
  const [voadora2, setVoadora2] = useState(null);
  const [panelPressed, setPanelPressed] = useState(false);
  const [cartaZoom, setCartaZoom] = useState(null);
  const [modalPausa, setModalPausa] = useState(false);
  const longPressTimer = useRef(null);
  const iaAnimacaoProcessada = useRef(null);
  const estadoRef = useRef(estado);

  const isMultiplayer = !!multiplayerConfig;
  const isHost = multiplayerConfig?.isHost;

  useEffect(() => {
    estadoRef.current = estado;
  }, [estado]);

  const enviarEstadoRef = useRef(null);

  const { enviarAcaoHost, enviarAcaoCliente, enviarEstado } = useMultiplayer(
    estado,
    dispatch,
    multiplayerConfig,
    enviarEstadoRef
  );

  enviarEstadoRef.current = enviarEstado;

  useEffect(() => {
    if (isMultiplayer && isHost && !estado?.isMultiplayer && !estado?.batalhaIniciada) {
      dispatch({
        type: 'INICIAR_MULTIPLAYER',
        payload: {
          nomeJogador1: multiplayerConfig?.perfil?.nickName || 'JOGADOR_1',
          nomeJogador2: multiplayerConfig?.oponente?.nome || 'OPONENTE',
        },
      });
    }
  }, [isMultiplayer, isHost, estado?.isMultiplayer, estado?.batalhaIniciada]);

  const iaHook = useIA(estado, dispatch);
  const iaExecutando = !isMultiplayer ? iaHook.iaExecutando : false;

  const handleAnimacaoInicioCompleta = useCallback(() => {
    dispatch({ type: 'BATALHA_INICIADA' });
    soundManager.playBattleStart();
    if (isMultiplayer && isHost) {
      setTimeout(() => {
        enviarEstado({ ...estadoRef.current, batalhaIniciada: true });
      }, 50);
    }
  }, [dispatch, isMultiplayer, isHost, enviarEstado]);

  useEffect(() => {
    setCartaSelecionada(null);
    iaAnimacaoProcessada.current = null;
  }, [estado?.jogadorAtivoIndex, estado?.turnoAtual]);

  useEffect(() => {
    if (estado?.fimDeJogo) {
      if (estado.fimDeJogo.vencedor === meuIndice + 1) {
        soundManager.playVictory();
      } else if (estado.fimDeJogo.vencedor !== 0) {
        soundManager.playDefeat();
      }
    }
  }, [estado?.fimDeJogo]);

  const jogadorLocal = isMultiplayer && !isHost ? estado?.jogadores[1] : estado?.jogadores[0];
  const oponenteIA = isMultiplayer && !isHost ? estado?.jogadores[0] : estado?.jogadores[1];

  const meuIndice = isMultiplayer && !isHost ? 1 : 0;
  const isMinhaVez = estado?.jogadorAtivoIndex === meuIndice && !estado?.fimDeJogo;
  const jogadoresDesabilitado = !isMinhaVez;

  const nomeJogadorAtivo = isMinhaVez
    ? (jogadorLocal?.nome || 'JOGADOR')
    : (oponenteIA?.nome || 'OPONENTE');

  useEffect(() => {
    const anim = estado?.iaAnimacao;
    if (!anim) return;
    if (iaAnimacaoProcessada.current === anim) return;
    iaAnimacaoProcessada.current = anim;

    if (anim.tipo === 'jogar') {
      setVoadora({
        key: 'ia_jogar_' + Date.now(),
        imgSource: traseiraImg,
        deX: POS_MAO_OPONENTE.x,
        deY: POS_MAO_OPONENTE.y,
        paraX: DECKS_POS.descX,
        paraY: DECKS_POS.descY,
        duracao: 500,
        onCompleto: () => {
          soundManager.playCardPlay();
          setVoadora(null);
        },
      });
    } else if (anim.tipo === 'comprar') {
      setVoadora2({
        key: 'ia_comprar_' + Date.now(),
        imgSource: traseiraImg,
        deX: DECKS_POS.drawX,
        deY: DECKS_POS.drawY,
        paraX: POS_MAO_OPONENTE.x,
        paraY: POS_MAO_OPONENTE.y,
        duracao: 400,
        onCompleto: () => {
          soundManager.playCardDraw();
          setVoadora2(null);
        },
      });
    }
  }, [estado?.iaAnimacao]);

  const handleSelecionarCarta = useCallback((carta) => {
    if (!isMinhaVez) return;
    setCartaSelecionada(carta);
  }, [isMinhaVez]);

  const handleAnimacaoSaidaCompleta = useCallback((carta) => {
    const cartaImg = cardImages[carta.uid % 2];

    setVoadora({
      key: 'descarte_' + Date.now(),
      imgSource: cartaImg,
      deX: POS_MAO_JOGADOR.x,
      deY: POS_MAO_JOGADOR.y,
      paraX: DECKS_POS.descX,
      paraY: DECKS_POS.descY,
      duracao: 400,
      onCompleto: () => {
        const action = {
          type: 'JOGAR_CARTA',
          payload: {
            jogadorId: jogadorLocal.id,
            cartaUid: carta.uid,
            jogadorAlvoId: carta.precisaAlvo ? oponenteIA.id : null,
          },
        };

        if (isMultiplayer && isHost) {
          jogarCarta(jogadorLocal.id, carta.uid, carta.precisaAlvo ? oponenteIA.id : null);
          setTimeout(() => enviarEstado(estadoRef.current), 50);
        } else if (isMultiplayer && !isHost) {
          enviarAcaoCliente(action);
        } else {
          jogarCarta(jogadorLocal.id, carta.uid, carta.precisaAlvo ? oponenteIA.id : null);
        }

        setCartaSelecionada(null);

        setTimeout(() => {
          setVoadora2({
            key: 'comprar_' + Date.now(),
            imgSource: traseiraImg,
            deX: DECKS_POS.drawX,
            deY: DECKS_POS.drawY,
            paraX: POS_MAO_JOGADOR.x,
            paraY: POS_MAO_JOGADOR.y,
            duracao: 400,
            onCompleto: () => {
              setVoadora2(null);
              if (!isMultiplayer) {
                passarTurno();
              }
            },
          });
        }, 200);
      },
    });
  }, [jogadorLocal, oponenteIA, jogarCarta, passarTurno, isMultiplayer, isHost, enviarAcaoCliente, enviarEstado]);

  const handlePassarTurno = useCallback(() => {
    if (!isMinhaVez) return;
    setCartaSelecionada(null);
    if (isMultiplayer && isHost) {
      passarTurno();
      setTimeout(() => enviarEstado(estadoRef.current), 50);
    } else if (isMultiplayer && !isHost) {
      enviarAcaoCliente({ type: 'PASSAR_TURNO' });
    } else {
      passarTurno();
    }
  }, [isMinhaVez, passarTurno, isMultiplayer, isHost, enviarEstado, enviarAcaoCliente]);

  const handleResetarJogo = useCallback(() => {
    resetarJogo();
  }, [resetarJogo]);

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

      <TouchableOpacity
        style={styles.botaoPausa}
        onPress={() => setModalPausa(true)}
        activeOpacity={0.7}
      >
        <Image source={pauseImg} style={styles.pauseIcon} resizeMode="contain" />
      </TouchableOpacity>

      <Modal
        visible={modalPausa}
        transparent={true}
        animationType="fade"
        onRequestClose={() => setModalPausa(false)}
      >
        <View style={styles.modalOverlay}>
          <View style={styles.modalContainer}>
            <Text style={styles.modalTitulo}>PAUSA</Text>
            <View style={styles.modalDivisor} />
            <TouchableOpacity
              style={[styles.modalBotao, styles.modalBotaoContinuar]}
              onPress={() => setModalPausa(false)}
              activeOpacity={0.7}
            >
              <Text style={styles.modalBotaoTexto}>CONTINUAR</Text>
            </TouchableOpacity>
            <TouchableOpacity
              style={[styles.modalBotao, styles.modalBotaoSair]}
              onPress={onVoltar}
              activeOpacity={0.7}
            >
              <Text style={styles.modalBotaoTexto}>SAIR</Text>
            </TouchableOpacity>
          </View>
        </View>
      </Modal>

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
          <PainelStatus nome={jogadorLocal?.nome || 'JOGADOR'} saldo={jogadorLocal?.saldo ?? 20} corDestaque="#FFD54F" />
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
          cartaSelecionada={cartaSelecionada}
          onSelecionarCarta={handleSelecionarCarta}
          onAnimacaoSaidaCompleta={handleAnimacaoSaidaCompleta}
          onDescartar={handlePassarTurno}
          desabilitado={jogadoresDesabilitado}
          hideStatus={true}
          onZoomCarta={(carta) => setCartaZoom(carta)}
        />
      </View>

      {voadora && (
        <CartaVoadora
          key={voadora.key}
          imgSource={voadora.imgSource}
          deX={voadora.deX}
          deY={voadora.deY}
          paraX={voadora.paraX}
          paraY={voadora.paraY}
          duracao={voadora.duracao}
          onCompleto={voadora.onCompleto}
        />
      )}

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
              {estado.fimDeJogo.vencedor === meuIndice + 1 ? 'VOCE VENCEU!' : estado.fimDeJogo.vencedor === (meuIndice === 0 ? 2 : 1) ? 'OPONENTE VENCEU!' : 'EMPATE!'}
            </Text>
            <Text style={styles.overlayMotivo}>{estado.fimDeJogo.motivo}</Text>
            <Text style={styles.overlayPlacar}>
              {jogadorLocal?.nome || 'Voce'}: R$ {jogadorLocal?.saldo ?? 0} | {oponenteIA?.nome || 'Oponente'}: R$ {oponenteIA?.saldo ?? 0}
            </Text>
            <Text style={styles.botaoReiniciar} onPress={handleResetarJogo}>
              JOGAR NOVAMENTE
            </Text>
          </View>
        </View>
      )}

      {!estado.batalhaIniciada && (
        <AnimacaoInicioBatalha
          jogadorAtivoIndex={estado.jogadorAtivoIndex}
          nomeJogador={jogadorLocal?.nome || 'JOGADOR'}
          nomeOponente={oponenteIA?.nome || 'OPONENTE'}
          onCompleto={handleAnimacaoInicioCompleta}
        />
      )}

      <CartaZoomModal
        carta={cartaZoom}
        visivel={!!cartaZoom}
        onFechar={() => setCartaZoom(null)}
      />
    </View>
  );
}

export default function ArenaCombate({ onVoltar, multiplayerConfig }) {
  return (
    <GameProvider>
      <View style={styles.container}>
        <ArenaInterna onVoltar={onVoltar} multiplayerConfig={multiplayerConfig} />
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
    width: '100%',
    height: '100%',
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
    right: 8,
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
  botaoPausa: {
    position: 'absolute',
    top: 10,
    right: 10,
    width: 36,
    height: 36,
    borderRadius: 18,
    backgroundColor: 'rgba(0, 0, 0, 0.6)',
    borderWidth: 1,
    borderColor: '#FFD54F',
    alignItems: 'center',
    justifyContent: 'center',
    zIndex: 100,
  },
  pauseIcon: {
    width: 20,
    height: 20,
  },
  modalOverlay: {
    flex: 1,
    backgroundColor: 'rgba(0, 0, 0, 0.85)',
    alignItems: 'center',
    justifyContent: 'center',
  },
  modalContainer: {
    backgroundColor: '#1E1E2E',
    borderRadius: 12,
    borderWidth: 2,
    borderColor: '#FFD54F',
    padding: 24,
    alignItems: 'center',
    width: 220,
  },
  modalTitulo: {
    fontSize: 24,
    color: '#FFD54F',
    fontWeight: 'bold',
    letterSpacing: 3,
    marginBottom: 8,
  },
  modalDivisor: {
    width: '80%',
    height: 1,
    backgroundColor: '#FFD54F',
    opacity: 0.4,
    marginBottom: 20,
  },
  modalBotao: {
    width: '100%',
    paddingVertical: 14,
    borderRadius: 8,
    alignItems: 'center',
    marginBottom: 12,
  },
  modalBotaoContinuar: {
    backgroundColor: '#2E7D32',
  },
  modalBotaoSair: {
    backgroundColor: '#C62828',
  },
  modalBotaoTexto: {
    color: '#FFF',
    fontWeight: 'bold',
    fontSize: 16,
    letterSpacing: 1,
  },
});
