import React, { useState, useCallback, useEffect, useRef } from 'react';
import { View, Text, StyleSheet, Image, Dimensions, Pressable, Modal, TouchableOpacity, Alert } from 'react-native';
import Animated, { useSharedValue, useAnimatedStyle, withSequence, withTiming, withSpring, withDelay } from 'react-native-reanimated';
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
import ParticleBurst from '../components/arena/Particles';
import ScorePopup from '../components/arena/ScorePopup';
import { screenShake } from '../utils/screenShake';
import { soundManager } from '../utils/sound';

const bgImg = require('../assets/sprites/batalha/background.jpg');
const traseiraImg = require('../assets/cards/traseira_cartas.jpg');
const nossoImg = require('../assets/cards/nosso.png');
const toyotinhoImg = require('../assets/cards/toyotinho.png');
const pauseImg = require('../assets/sprites/menu/pause.jpg');

const cardImages = {
  ATAQUE:   nossoImg,
  DEFESA:   toyotinhoImg,
  PROTECAO: nossoImg,
  CORINGA:  nossoImg,
  ACAO:     toyotinhoImg,
  EFEITO:   nossoImg,
};

const imgPorCarta = (c) => (c && cardImages[c.tipo]) || traseiraImg;

const { width: SCREEN_WIDTH, height: SCREEN_HEIGHT } = Dimensions.get('window');

const CARD_W = 60;
const CARD_H = 84;

const DECK_W = 58;
const DECK_H = 81;
const DECK_GAP = 36;
const DECKS_Y = SCREEN_HEIGHT * 0.44 + DECK_H / 2;
const DECK_DRAW_X = SCREEN_WIDTH / 2 - DECK_W - DECK_GAP / 2;
const DECK_DESC_X = SCREEN_WIDTH / 2 + DECK_GAP / 2;

const POS_MAO_JOGADOR = { x: SCREEN_WIDTH / 2 - 30, y: SCREEN_HEIGHT - 120 };
const POS_MAO_OPONENTE = { x: SCREEN_WIDTH / 2 - 30, y: 30 };

const DECKS_POS = { drawX: DECK_DRAW_X, drawY: DECKS_Y, descX: DECK_DESC_X, descY: DECKS_Y };

// Durações das animações (constantes pra ajuste fino).
const LIFT_DURACAO = 200;
const VOO_DURACAO  = 400;
const FADE_DURACAO = 120;
const STAGGER_CARTAS = 220;

// Voo simples: compra (baralho → mão) e descarte do oponente.
function CartaVoadora({ imgSource, deX, deY, paraX, paraY, onCompleto, duracao = 400 }) {
  const posX = useSharedValue(deX);
  const posY = useSharedValue(deY);
  const escala = useSharedValue(1);
  const opacidade = useSharedValue(1);
  const rotacao = useSharedValue(0);

  const animatedStyle = useAnimatedStyle(() => ({
    left: posX.value,
    top: posY.value,
    opacity: opacidade.value,
    transform: [
      { scale: escala.value },
      { rotate: `${rotacao.value}deg` },
    ],
  }));

  useEffect(() => {
    const rotacaoAleatoria = (Math.random() - 0.5) * 8;

    posX.value = withSequence(
      withTiming(paraX, { duration: duracao }),
    );
    posY.value = withSequence(
      withTiming(Math.min(deY, paraY) - 30, { duration: duracao * 0.5 }),
      withSpring(paraY, { damping: 6, stiffness: 40 }),
    );
    escala.value = withTiming(0.6, { duration: duracao });
    rotacao.value = withSpring(rotacaoAleatoria, { damping: 5, stiffness: 50 });
    opacidade.value = withSequence(
      withDelay(duracao, withTiming(0, { duration: 150 })),
    );

    const timer = setTimeout(() => {
      if (onCompleto) onCompleto();
    }, duracao + 200);

    return () => clearTimeout(timer);
  }, []);

  return (
    <Animated.View style={[styles.cartaVoadora, animatedStyle]}>
      <Image source={imgSource} style={styles.cartaVoadoraImg} resizeMode="cover" />
    </Animated.View>
  );
}

// Carta que "salta" da mão antes de voar pro descarte.
// Fases: lift → voo → fade. Respeita `delay` para escalonar múltiplas cartas.
function CartaSaidaComLift({ imgSource, deX, deY, paraX, paraY, duracao = VOO_DURACAO, delay = 0, onCompleto }) {
  const posX     = useSharedValue(deX);
  const posY     = useSharedValue(deY);
  const escala   = useSharedValue(1);
  const rotacao  = useSharedValue(0);
  const opacidade = useSharedValue(1);

  const cbCompleto = onCompleto;

  const animatedStyle = useAnimatedStyle(() => ({
    left: posX.value,
    top: posY.value,
    opacity: opacidade.value,
    transform: [
      { scale: escala.value },
      { rotate: `${rotacao.value}deg` },
    ],
  }));

  useEffect(() => {
    const rotacaoAleatoria = (Math.random() - 0.5) * 10;

    const executarAnimacao = () => {
      soundManager.playCardPlay();

      // FASE 1 — desprende da mão com bounce spring
      posY.value = withSpring(deY - 55, { damping: 5, stiffness: 80 });
      escala.value = withSpring(1.22, { damping: 4, stiffness: 100 });
      rotacao.value = withSpring(rotacaoAleatoria, { damping: 5, stiffness: 60 });

      // FASE 2 — voa pro descarte com curva parabólica (após lift)
      const liftDuracao = 200;
      setTimeout(() => {
        posX.value = withTiming(paraX, { duration: duracao });
        posY.value = withSequence(
          withTiming(Math.min(deY, paraY) - 40, { duration: duracao * 0.5 }),
          withSpring(paraY, { damping: 6, stiffness: 40 }),
        );
        escala.value = withSpring(0.7, { damping: 6, stiffness: 30 });
        rotacao.value = withSpring(0, { damping: 7, stiffness: 50 });

        // FASE 3 — fade out ao encostar no descarte
        setTimeout(() => {
          opacidade.value = withTiming(0, { duration: 120 });
          setTimeout(() => { if (cbCompleto) cbCompleto(); }, 120);
        }, duracao);
      }, liftDuracao);
    };

    const timer = setTimeout(executarAnimacao, delay);

    return () => clearTimeout(timer);
  }, []);

  return (
    <Animated.View style={[styles.cartaVoadora, animatedStyle]}>
      <Image source={imgSource} style={styles.cartaVoadoraImg} resizeMode="cover" />
    </Animated.View>
  );
}

function ArenaInterna({ onVoltar, multiplayerConfig }) {
  const { estado, passarTurno, resetarJogo, dispatch } = useGameState();
  const [cartasSelecionadas, setCartasSelecionadas] = useState([]);
  const [cartasDescarte, setCartasDescarte] = useState([]); // array de voadoras indo pro descarte
  const [voadora2, setVoadora2] = useState(null);           // compra (baralho → mão)
  const [panelPressed, setPanelPressed] = useState(false);
  const [cartaZoom, setCartaZoom] = useState(null);
  const [modalPausa, setModalPausa] = useState(false);
  const [particlesData, setParticlesData] = useState({ visivel: false, x: 0, y: 0, cores: null });
  const [scorePopups, setScorePopups] = useState([]);
  const [cartaRecemCompradaUid, setCartaRecemCompradaUid] = useState(null);
  const longPressTimer = useRef(null);
  const iaAnimacaoProcessada = useRef(null);
  const estadoRef = useRef(estado);
  const estadoEnviadoRef = useRef(null);
  const shakeX = useSharedValue(0);
  const shakeY = useSharedValue(0);
  const prevSaldoRef = useRef({});

  const isMultiplayer = !!multiplayerConfig;
  const isHost = multiplayerConfig?.isHost;

  useEffect(() => {
    estadoRef.current = estado;
  }, [estado]);

  const enviarEstadoRef = useRef(null);

  const { enviarAcaoCliente, enviarEstado, enviarGameOver } = useMultiplayer(
    estado,
    dispatch,
    multiplayerConfig,
    enviarEstadoRef
  );

  enviarEstadoRef.current = enviarEstado;

  // ------------------------------------------------------------------
  // Sincronização host → cliente.
  // Envia sempre que o estado multiplayer mudar (não só após batalhaIniciada),
  // pra cliente receber imediatamente a mão real e o jogadorAtivoIndex correto.
  // ------------------------------------------------------------------
  useEffect(() => {
    if (!isMultiplayer || !isHost) return;
    if (!estado) return;
    if (!estado.isMultiplayer) return; // aguarda INICIAR_MULTIPLAYER aplicar
    if (estadoEnviadoRef.current === estado) return;
    estadoEnviadoRef.current = estado;
    enviarEstado(estado);
  }, [estado, isMultiplayer, isHost, enviarEstado]);

  // ------------------------------------------------------------------
  // INICIAR_MULTIPLAYER — só o HOST cria estado. O cliente espera receber
  // via STATE_UPDATE (com baralho idêntico e jogadorAtivoIndex já sorteado
  // pelo host).
  // ------------------------------------------------------------------
  useEffect(() => {
    if (!isMultiplayer) return;
    if (estado?.isMultiplayer) return;

    if (isHost) {
      dispatch({
        type: 'INICIAR_MULTIPLAYER',
        payload: {
          nomeJogador1: multiplayerConfig?.perfil?.nickName || 'JOGADOR_1',
          nomeJogador2: multiplayerConfig?.oponente?.nome || 'OPONENTE',
          primeiroJogadorIndex: multiplayerConfig?.primeiroJogadorIndex,
        },
      });
    }
    // Cliente NÃO gera estado — recebe tudo do host.
  }, [isMultiplayer, isHost, estado?.isMultiplayer, multiplayerConfig, dispatch]);

  const iaHook = useIA(estado, dispatch);
  const iaExecutando = !isMultiplayer ? iaHook.iaExecutando : false;

  const MAX_CARTAS_POR_TURNO = 2;

  const handleAnimacaoInicioCompleta = useCallback(() => {
    if (isMultiplayer && !isHost) {
      // Cliente não comanda o início — espera o host mandar batalhaIniciada:true.
      return;
    }
    dispatch({ type: 'BATALHA_INICIADA' });
    soundManager.playBattleStart();
  }, [dispatch, isMultiplayer, isHost]);

  useEffect(() => {
    setCartasSelecionadas([]);
    iaAnimacaoProcessada.current = null;
  }, [estado?.jogadorAtivoIndex, estado?.turnoAtual]);

  const jogadorLocal = isMultiplayer && !isHost ? estado?.jogadores[1] : estado?.jogadores[0];
  const oponenteIA = isMultiplayer && !isHost ? estado?.jogadores[0] : estado?.jogadores[1];

  const meuIndice = isMultiplayer && !isHost ? 1 : 0;
  const isMinhaVez = estado?.jogadorAtivoIndex === meuIndice && !estado?.fimDeJogo;
  const jogadoresDesabilitado = !isMinhaVez;

  const nomeJogadorAtivo = isMinhaVez
    ? (jogadorLocal?.nome || 'JOGADOR')
    : (oponenteIA?.nome || 'OPONENTE');

  useEffect(() => {
    if (estado?.fimDeJogo) {
      if (estado.fimDeJogo.vencedor === meuIndice + 1) {
        soundManager.playVictory();
      } else if (estado.fimDeJogo.vencedor !== 0) {
        soundManager.playDefeat();
      }
      screenShake(shakeX, shakeY, 12);
    }
  }, [estado?.fimDeJogo]);

  useEffect(() => {
    if (!estado?.jogadores) return;
    estado.jogadores.forEach((j, i) => {
      const prevSaldo = prevSaldoRef.current[i];
      if (prevSaldo !== undefined && j.saldo !== prevSaldo) {
        const diff = j.saldo - prevSaldo;
        const jIndex = i;
        const x = jIndex === 0 ? SCREEN_WIDTH / 2 - 40 : SCREEN_WIDTH / 2 - 40;
        const y = jIndex === 0 ? SCREEN_HEIGHT - 80 : 80;
        setScorePopups([{ valor: diff, x, y }]);

        if (diff < 0) {
          screenShake(shakeX, shakeY, 6);
        }

        setParticlesData({
          visivel: true,
          x: SCREEN_WIDTH / 2,
          y: jIndex === 0 ? SCREEN_HEIGHT * 0.55 : SCREEN_HEIGHT * 0.45,
          cores: diff > 0 ? ['#66BB6A', '#FFD54F', '#4CAF50'] : ['#EF5350', '#FF5722', '#F44336'],
        });
      }
      prevSaldoRef.current[i] = j.saldo;
    });
  }, [estado?.jogadores]);

  const prevMaoSizeRef = useRef(null);
  useEffect(() => {
    if (!jogadorLocal?.mao) return;
    const maoAtual = jogadorLocal.mao;
    const maoSizeAnterior = prevMaoSizeRef.current;

    if (maoSizeAnterior !== null && maoAtual.length > maoSizeAnterior) {
      const ultimaCarta = maoAtual[maoAtual.length - 1];
      setCartaRecemCompradaUid(ultimaCarta.uid);
      setTimeout(() => setCartaRecemCompradaUid(null), 3000);
    }

    prevMaoSizeRef.current = maoAtual.length;
  }, [jogadorLocal?.mao]);

  // Animação da IA (single-player apenas).
  useEffect(() => {
    if (isMultiplayer) return;
    const anim = estado?.iaAnimacao;
    if (!anim) return;
    if (iaAnimacaoProcessada.current === anim) return;
    iaAnimacaoProcessada.current = anim;

    if (anim.tipo === 'jogar') {
      const key = `ia_jogar_${Date.now()}`;
      const voadoraIA = {
        key,
        tipo: 'voadora',
        imgSource: traseiraImg,
        deX: POS_MAO_OPONENTE.x,
        deY: POS_MAO_OPONENTE.y,
        paraX: DECKS_POS.descX,
        paraY: DECKS_POS.descY,
        duracao: 500,
        delay: 0,
        onCompleto: () => setCartasDescarte((prev) => prev.filter((v) => v.key !== key)),
      };
      setCartasDescarte((prev) => [...prev, voadoraIA]);
    } else if (anim.tipo === 'comprar') {
      setVoadora2({
        key: `ia_comprar_${Date.now()}`,
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
  }, [estado?.iaAnimacao, isMultiplayer]);

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

    // 1) Aplica jogada IMEDIATAMENTE (cartas saem da mão, entram no descarte).
    if (isMultiplayer && !isHost) {
      cartasParaJogar.forEach((c) => {
        enviarAcaoCliente({
          type: 'JOGAR_CARTA_SEM_COMPRA',
          payload: { jogadorId: jogadorLocal.id, cartaUid: c.uid, jogadorAlvoId: null },
        });
      });
    } else {
      dispatch({
        type: 'JOGAR_CARTAS_SEM_COMPRA',
        payload: { jogadorId: jogadorLocal.id, cartas: cartasParaJogar },
      });
    }

    // 2) Anima cada carta saindo da mão (lift + voo + fade), com stagger.
    const novasVoadoras = cartasParaJogar.map((carta, i) => {
      const key = `saida_${i}_${Date.now()}_${Math.random().toString(36).slice(2, 8)}`;
      return {
        key,
        tipo: 'lift',
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

    // 3) Agenda compra para depois da última carta chegar ao descarte.
    const tempoUltimaSaida =
      (cartasParaJogar.length - 1) * STAGGER_CARTAS + LIFT_DURACAO + VOO_DURACAO + FADE_DURACAO;
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

          // 4) SÓ AGORA passa o turno (fimDeTurno compra 1 pro jogador ativo).
          if (isMultiplayer && !isHost) {
            enviarAcaoCliente({ type: 'PASSAR_TURNO' });
          } else {
            passarTurno();
          }
        },
      });
    }, atrasoCompra);
  }, [
    isMinhaVez,
    cartasSelecionadas,
    jogadorLocal,
    passarTurno,
    isMultiplayer,
    isHost,
    enviarAcaoCliente,
    dispatch,
  ]);

  const handlePassarTurno = useCallback(() => {
    if (!isMinhaVez) return;
    setCartasSelecionadas([]);

    if (isMultiplayer && isHost) {
      passarTurno();
    } else if (isMultiplayer && !isHost) {
      enviarAcaoCliente({ type: 'PASSAR_TURNO' });
    } else {
      passarTurno();
    }
  }, [isMinhaVez, passarTurno, isMultiplayer, isHost, enviarAcaoCliente]);

  const handleResetarJogo = useCallback(() => {
    resetarJogo();
  }, [resetarJogo]);

  const handleDesistir = useCallback(() => {
    Alert.alert(
      'Desistir',
      'Tem certeza que deseja sair? O oponente sera declarado vencedor.',
      [
        { text: 'Cancelar', style: 'cancel' },
        {
          text: 'Sim, desistir',
          style: 'destructive',
          onPress: () => {
            const oponenteIdx = isHost ? 1 : 0;
            const oponenteNome = estado?.jogadores?.[oponenteIdx]?.nome || 'OPONENTE';

            const fimDeJogo = {
              vencedor: oponenteIdx + 1,
              motivo: `${oponenteNome} venceu por desistencia`,
            };

            if (isMultiplayer) {
              enviarGameOver(fimDeJogo);
            }

            onVoltar();
          },
        },
      ]
    );
  }, [isMultiplayer, isHost, estado, enviarGameOver, onVoltar]);

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

  const shakeStyle = useAnimatedStyle(() => ({
    transform: [{ translateX: shakeX.value }, { translateY: shakeY.value }],
  }));

  if (!estado) return null;

  return (
    <Animated.View style={[styles.container, shakeStyle]}>
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
              onPress={isMultiplayer ? handleDesistir : onVoltar}
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
          fluxoDirecao={estado?.direcaoTurno || 1}
          isHumano={isMinhaVez}
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
          cartasSelecionadas={cartasSelecionadas}
          onSelecionarCarta={handleToggleSelectCarta}
          onDescartar={handlePassarTurno}
          desabilitado={jogadoresDesabilitado}
          hideStatus={true}
          onZoomCarta={(carta) => setCartaZoom(carta)}
          cartaRecemCompradaUid={cartaRecemCompradaUid}
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

      {/* Cartas voando pro descarte (jogador humano ou IA) */}
      {cartasDescarte.map((v) => (
        v.tipo === 'lift' ? (
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
        ) : (
          <CartaVoadora
            key={v.key}
            imgSource={v.imgSource}
            deX={v.deX}
            deY={v.deY}
            paraX={v.paraX}
            paraY={v.paraY}
            duracao={v.duracao}
            onCompleto={v.onCompleto}
          />
        )
      ))}

      {/* Compra (baralho → mão) */}
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
            <Text style={styles.botaoVoltarMenu} onPress={onVoltar}>
              VOLTAR AO MENU
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

      <ParticleBurst
        x={particlesData.x}
        y={particlesData.y}
        cores={particlesData.cores}
        visivel={particlesData.visivel}
        onCompleto={() => setParticlesData((prev) => ({ ...prev, visivel: false }))}
      />

      <ScorePopup
        alteracoes={scorePopups}
        onCompleto={() => setScorePopups([])}
      />
    </Animated.View>
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
    marginBottom: 10,
  },
  botaoVoltarMenu: {
    backgroundColor: '#C62828',
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