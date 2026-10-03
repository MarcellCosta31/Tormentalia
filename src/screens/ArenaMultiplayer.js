import React, { useState, useRef, useEffect, useCallback } from 'react';
import {
  View,
  StyleSheet,
  Image,
  Dimensions,
  TouchableOpacity,
  Modal,
  Pressable,
} from 'react-native';
import Text from '../components/Texto';
import Animated, {
  useSharedValue,
  useAnimatedStyle,
  withTiming,
  withSequence,
  withSpring,
  withDelay,
  withRepeat,
  interpolate,
} from 'react-native-reanimated';
import { GameProvider, useGameState } from '../context/GameContext';
import { useIAMulti } from '../hooks/useIAMulti';
import { useMultiplayer } from '../multiplayer/useMultiplayer';
import TurnoIndicador from '../components/arena/TurnoIndicador';
import CartaZoomModal from '../components/arena/CartaZoomModal';
import DestaqueCoringa, { DURACAO_DESTAQUE_CORINGA } from '../components/arena/DestaqueCoringa';
import ResultadoJogada, { DURACAO_ZOOM_RESULTADO } from '../components/arena/ResultadoJogada';
import ModalRouboCego from '../components/arena/ModalRouboCego';
import AnimacaoInicioBatalha from '../components/arena/AnimacaoInicioBatalha';
import MaoJogador from '../components/arena/MaoJogador';
import MaoOponente from '../components/arena/MaoOponente';
import DecksArea from '../components/arena/DecksArea';
import ParticleBurst from '../components/arena/Particles';
import ScorePopup from '../components/arena/ScorePopup';
import { screenShake } from '../utils/screenShake';
import { getAvatarById } from '../utils/avatar';
import { soundManager } from '../utils/sound';
import AreaSegura from '../components/arena/AreaSegura';
import FundoMadeira from '../components/arena/FundoMadeira';
import { artePorCarta } from '../cards/arteCarta';
import { TIPO_CARTA } from '../cards/cartasTGA';
import { duracaoTurno, TURNO_BASE_SEGUNDOS } from '../cards/motorEfeitos';

const traseiraImg = require('../assets/cards/traseira_cartas.jpg');
const pauseImg = require('../assets/sprites/menu/pause.jpg');

const imgPorCarta = (c) => artePorCarta(c) || traseiraImg;

const { width: W, height: H } = Dimensions.get('window');

const CARD_W = 60;
const CARD_H = 84;
const MINI_CARD_W = 28;
const MINI_CARD_H = 40;

const MAX_CARTAS_POR_TURNO = 2;

const LIFT_DURACAO = 200;
const VOO_DURACAO = 400;
const FADE_DURACAO = 120;
const STAGGER_CARTAS = 220;

const POS_OPONENTE_2P = { x: W / 2, y: H * 0.22 };

const POS_MAO_1V1_OPONENTE = { x: W / 2 - 30, y: 20 };
const POS_MAO_1V1_LOCAL = { x: W / 2 - 30, y: H - 120 };
// DecksArea (1v1): mesma geometria de DecksArea.js — pilha de compra 50x70,
// descarte 64x90, gap 36, linha em `top: H * 0.44` + paddingVertical 6.
const DECKS_GAP = 36;
const DECK_DRAW_W = 50;
const DECK_DRAW_H = 70;
const DECK_DESC_W = 64;
const DECK_DESC_H = 90;
const DECKS_ROW_TOP = H * 0.44 + 6;
const DECKS_ROW_H = Math.max(DECK_DRAW_H, DECK_DESC_H);
const DECKS_ROW_X = (W - (DECK_DRAW_W + DECKS_GAP + DECK_DESC_W)) / 2;
const DECKS_POS_1V1 = {
  drawX: DECKS_ROW_X + (DECK_DRAW_W - CARD_W) / 2,
  drawY: DECKS_ROW_TOP + (DECKS_ROW_H - DECK_DRAW_H) / 2 + (DECK_DRAW_H - CARD_H) / 2,
  descX: DECKS_ROW_X + DECK_DRAW_W + DECKS_GAP + (DECK_DESC_W - CARD_W) / 2,
  descY: DECKS_ROW_TOP + (DECKS_ROW_H - DECK_DESC_H) / 2 + (DECK_DESC_H - CARD_H) / 2,
};

const PLAYER_COLORS = ['#FFD54F', '#EF5350', '#42A5F5', '#66BB6A', '#AB47BC', '#FF7043', '#26C6DA', '#EC407A'];

const AVATARES_IA_PADRAO = ['3', '4', '5', '6', '7', '2', '1'];

function calcularPosicoes(n) {
  if (n === 2) {
    return [
      { x: W / 2, y: H * 0.85 },
      { x: POS_OPONENTE_2P.x, y: POS_OPONENTE_2P.y },
    ];
  }
  const cx = W / 2;
  const cy = H * 0.42;
  const rx = W * 0.38;
  const ry = H * 0.32;
  return Array.from({ length: n }, (_, i) => {
    const angulo = Math.PI / 2 + (2 * Math.PI * i) / n;
    return {
      x: cx + rx * Math.cos(angulo),
      y: cy + ry * Math.sin(angulo),
    };
  });
}

// ============================ Animações ============================

function CartaVoadora({ imgSource, deX, deY, paraX, paraY, onCompleto, duracao = 400 }) {
  const posX = useSharedValue(deX);
  const posY = useSharedValue(deY);
  const escala = useSharedValue(1);
  const opacidade = useSharedValue(1);
  const rotacao = useSharedValue(0);

  const cbCompleto = onCompleto;

  const animatedStyle = useAnimatedStyle(() => ({
    transform: [
      { scale: escala.value },
      { rotate: `${interpolate(rotacao.value, [-10, 10], [-10, 10])}deg` },
    ],
  }));

  useEffect(() => {
    const rotacaoAleatoria = (Math.random() - 0.5) * 3;

    posX.value = withTiming(paraX, { duration: duracao });
    escala.value = withTiming(0.65, { duration: duracao });
    rotacao.value = withSpring(rotacaoAleatoria, { damping: 12, stiffness: 60 });
    posY.value = withSequence(
      withTiming(Math.min(deY, paraY) - 18, { duration: duracao * 0.5 }),
      withSpring(paraY, { damping: 12, stiffness: 55 }),
    );

    opacidade.value = withDelay(
      duracao,
      withTiming(0, { duration: 150 })
    );
    setTimeout(() => { if (cbCompleto) cbCompleto(); }, duracao + 150);
  }, []);

  return (
    <Animated.View style={[styles.cartaVoadora, { left: posX, top: posY, opacity: opacidade }, animatedStyle]}>
      <Image source={imgSource} style={styles.cartaVoadoraImg} resizeMode="cover" />
    </Animated.View>
  );
}

function CartaSaidaComLift({ imgSource, deX, deY, paraX, paraY, duracao = VOO_DURACAO, delay = 0, onCompleto }) {
  const posX = useSharedValue(deX);
  const posY = useSharedValue(deY);
  const escala = useSharedValue(1);
  const rotacao = useSharedValue(0);
  const opacidade = useSharedValue(1);

  const cbCompleto = onCompleto;

  const animatedStyle = useAnimatedStyle(() => ({
    transform: [
      { scale: escala.value },
      { rotate: `${interpolate(rotacao.value, [-15, 15], [-15, 15])}deg` },
    ],
  }));

  useEffect(() => {
    const somTimer = setTimeout(() => soundManager.playCardPlay(), delay);
    const rotacaoAleatoria = (Math.random() - 0.5) * 4;

    posY.value = withDelay(delay, withSequence(
      withSpring(deY - 35, { damping: 11, stiffness: 100 }),
      withTiming(Math.min(deY, paraY) - 25, { duration: duracao * 0.5 }),
      withSpring(paraY, { damping: 11, stiffness: 55 }),
    ));
    escala.value = withDelay(delay, withSequence(
      withSpring(1.1, { damping: 10, stiffness: 110 }),
      withSpring(0.75, { damping: 11, stiffness: 60 }),
    ));
    rotacao.value = withDelay(delay, withSequence(
      withSpring(rotacaoAleatoria, { damping: 11, stiffness: 80 }),
      withSpring(0, { damping: 13, stiffness: 70 }),
    ));

    posX.value = withDelay(delay + LIFT_DURACAO, withTiming(paraX, { duration: duracao }));

    opacidade.value = withDelay(
      delay + LIFT_DURACAO + duracao,
      withTiming(0, { duration: FADE_DURACAO })
    );
    setTimeout(() => {
      clearTimeout(somTimer);
      if (cbCompleto) cbCompleto();
    }, delay + LIFT_DURACAO + duracao + FADE_DURACAO);

    return () => clearTimeout(somTimer);
  }, []);

  return (
    <Animated.View
      style={[styles.cartaVoadora, { left: posX, top: posY, opacity: opacidade }, animatedStyle]}
    >
      <Image source={imgSource} style={styles.cartaVoadoraImg} resizeMode="cover" />
    </Animated.View>
  );
}

// ============================ Slot de oponente ============================

function SlotOponente({ jogador, posicao, isAtivo, index, avatarSource }) {
  const pulseAnim = useSharedValue(1);

  useEffect(() => {
    if (isAtivo) {
      pulseAnim.value = withRepeat(
        withSequence(
          withTiming(1.05, { duration: 600 }),
          withTiming(1, { duration: 600 }),
        ),
        -1,
        false,
      );
    } else {
      pulseAnim.value = 1;
    }
  }, [isAtivo]);

  const numCartas = jogador.mao?.length || 0;
  const cor = jogador.cor || PLAYER_COLORS[index % PLAYER_COLORS.length];

  return (
    <Animated.View
      style={[
        styles.slotOponente,
        {
          left: posicao.x - 52,
          top: posicao.y - 58,
          borderColor: cor,
          transform: [{ scale: pulseAnim }],
          opacity: jogador.falido ? 0.4 : 1,
        },
      ]}
    >
      {isAtivo && (
        <View style={[styles.badgeAtivo, { backgroundColor: cor }]}>
          <Text style={styles.badgeAtivoTexto}>VEZ</Text>
        </View>
      )}

      <View style={styles.slotTopRow}>
        <View style={[styles.avatarCirculo, { borderColor: cor }]}>
          {avatarSource ? (
            <Image source={avatarSource} style={styles.avatarImg} resizeMode="contain" />
          ) : (
            <Text style={[styles.avatarPlaceholder, { color: cor }]}>{index + 1}</Text>
          )}
        </View>
        {jogador.protegido && <Text style={styles.badgeProtegido}>🛡️</Text>}
      </View>

      <Text style={[styles.nomeOponente, { color: cor }]} numberOfLines={1}>
        {jogador.nome}
      </Text>

      <View style={styles.saldoRow}>
        <Text style={styles.saldoLabel}>R$</Text>
        <Text style={[
          styles.saldoValor,
          { color: jogador.saldo > 10 ? '#66BB6A' : jogador.saldo > 5 ? '#FFD54F' : '#EF5350' },
        ]}>
          {jogador.saldo}
        </Text>
      </View>

      <View style={styles.miniCartasRow}>
        {Array.from({ length: Math.min(numCartas, 6) }).map((_, ci) => (
          <Image
            key={ci}
            source={traseiraImg}
            style={[
              styles.miniCartaTraseira,
              {
                transform: [{ rotate: `${(ci - Math.min(numCartas, 6) / 2) * 5}deg` }],
                borderColor: cor,
              },
            ]}
            resizeMode="cover"
          />
        ))}
      </View>

      {jogador.falido && (
        <View style={styles.falidoOverlay}>
          <Text style={styles.falidoTexto}>💀 FALIU</Text>
        </View>
      )}
    </Animated.View>
  );
}

// ============================ Mesa central ============================

function MesaCentral({ numJogadores, baralho, pilhaDescarte }) {
  const rotAnim = useSharedValue(0);

  const rotStyle = useAnimatedStyle(() => ({
    transform: [{ rotate: `${interpolate(rotAnim.value, [0, 1], [0, 360])}deg` }],
  }));

  useEffect(() => {
    rotAnim.value = withRepeat(withTiming(1, { duration: 30000 }), -1, false);
  }, []);

  return (
    <View style={styles.mesaCentral}>
      <Animated.View style={[styles.mesaCirculoExt, rotStyle]} />
      <View style={styles.mesaCirculoInt}>
        <Text style={styles.mesaEmoji}>⚔️</Text>
        <Text style={styles.mesaTitulo}>ARENA</Text>
        <Text style={styles.mesaSubtitulo}>{numJogadores}v{numJogadores}</Text>

        <View style={styles.deckInfo}>
          <View style={styles.deckInfoItem}>
            <Image source={traseiraImg} style={styles.deckMini} resizeMode="cover" />
            <Text style={styles.deckCount}>{baralho?.length || 0}</Text>
          </View>
          <View style={styles.deckInfoItem}>
            <View style={styles.descarteMini}>
              {pilhaDescarte && pilhaDescarte.length > 0 ? (
                <Image
                  source={artePorCarta(pilhaDescarte[pilhaDescarte.length - 1])}
                  style={styles.deckMini}
                  resizeMode="cover"
                />
              ) : (
                <View style={[styles.deckMini, { backgroundColor: 'rgba(255,255,255,0.1)' }]} />
              )}
            </View>
            <Text style={styles.deckCount}>{pilhaDescarte?.length || 0}</Text>
          </View>
        </View>
      </View>
    </View>
  );
}

// ============================ Tela principal ============================

function ArenaMultiInterna({ quantidade, onVoltar, multiplayerConfig }) {
  const {
    estado,
    jogarCartaSemComprarN,
    passarTurnoN,
    passarTurno,
    resetarJogo,
    dispatch,
  } = useGameState();

const [cartaZoom, setCartaZoom] = useState(null);
   const [modalPausa, setModalPausa] = useState(false);
   const [cartasDescarte, setCartasDescarte] = useState([]);
   const [voadora2, setVoadora2] = useState(null);
   const [batalhaIniciada, setBatalhaIniciada] = useState(false);
   const [cartasSelecionadas, setCartasSelecionadas] = useState([]);
   const [areaSeguraSelecionadas, setAreaSeguraSelecionadas] = useState([]);
   const [areaSeguraVisivel, setAreaSeguraVisivel] = useState(true);
   const [particlesData, setParticlesData] = useState({ visivel: false, x: 0, y: 0, cores: null });
  const [scorePopups, setScorePopups] = useState([]);
   const [cartaRecemCompradaUid, setCartaRecemCompradaUid] = useState(null);
   // true enquanto as cartas jogadas voam pro descarte (pausa o timer).
   const [jogandoEmAndamento, setJogandoEmAndamento] = useState(false);
   // Evita passar o turno 2x no mesmo turno (timer x clique manual).
   const passouNesteTurnoRef = useRef(null);
   // Pendencia do roubo as cegas (carta Vigarice): { cartas, uidCarta,
   // quantidade, alvos: [{ idx, nome, mao }] }.
   const [modalRoubo, setModalRoubo] = useState(null);
   // Destaque da carta coringa jogada (pausa o turno por alguns segundos).
   const [destaqueCoringa, setDestaqueCoringa] = useState(null);
   const destaqueRef = useRef(false);
   // Zoom de SUCESSO/FALHA das cartas jogadas (2s antes da animacao).
   const [zoomResultado, setZoomResultado] = useState(null);
   const resultadoRef = useRef(false);
   const resultadoVistoSeqRef = useRef(0);
   // Coringas da mesma leva que esperam o zoom fechar para abrir o
   // destaque deles.
   const pendenciaCoringaRef = useRef([]);

  const iaAnimacaoProcessada = useRef(null);
  const estadoRef = useRef(estado);
  const estadoEnviadoRef = useRef(null);
  const shakeX = useSharedValue(0);
  const shakeY = useSharedValue(0);
  const prevSaldoRef = useRef({});

  const isMultiplayer = !!multiplayerConfig;
  const isHost = multiplayerConfig?.isHost;
  const meuIdx = isMultiplayer && !isHost ? 1 : 0;

  const shakeStyle = useAnimatedStyle(() => ({
    transform: [
      { translateX: shakeX.value },
      { translateY: shakeY.value },
    ],
  }));

  useEffect(() => { estadoRef.current = estado; }, [estado]);

  // ------------------------------------------------------------------
  // RESULTADO DAS JOGADAS (zoom SUCESSO/FALHA) + DESTAQUE DE CORINGA.
  // Quem quer que jogue (local, IA ou remoto): o motor grava cada
  // jogada em estado.ultimasJogadas (sync leva o resultado pra todos).
  // O zoom fica 2s; coringas abrem o destaque DEPOIS do zoom fechar.
  // ------------------------------------------------------------------
  const fecharDestaque = useCallback(() => {
    destaqueRef.current = false;
    setDestaqueCoringa(null);
  }, []);

  const abrirDestaqueCoringa = (entrada) => {
    destaqueRef.current = true;
    setDestaqueCoringa({ carta: entrada.carta, sucesso: entrada.sucesso });
    screenShake(shakeX, shakeY, 10);
    soundManager.playCardPlay();
  };

  const fecharZoomResultado = () => {
    resultadoRef.current = false;
    setZoomResultado(null);
    const pend = pendenciaCoringaRef.current;
    pendenciaCoringaRef.current = [];
    if (pend.length > 0) abrirDestaqueCoringa(pend[0]);
  };

  useEffect(() => {
    const lista = estado?.ultimasJogadas;
    if (!lista) return;
    if (lista.length === 0) {
      // Partida nova/reiniciada: zera o cursor de seq.
      resultadoVistoSeqRef.current = 0;
      return;
    }
    const novas = lista.filter((r) => r.seq > resultadoVistoSeqRef.current);
    const ultimoSeq = lista[lista.length - 1].seq;
    resultadoVistoSeqRef.current = Math.max(resultadoVistoSeqRef.current, ultimoSeq);
    if (novas.length === 0) return;

    const coringas = novas.filter((r) => r.carta && r.carta.tipo === TIPO_CARTA.CORINGA);
    const normais = novas.filter((r) => !r.carta || r.carta.tipo !== TIPO_CARTA.CORINGA);

    if (normais.length > 0) {
      pendenciaCoringaRef.current = coringas;
      resultadoRef.current = true;
      setZoomResultado(normais);
      normais.forEach((r) => {
        if (r.sucesso) soundManager.playScoreGain();
        else soundManager.playScoreLose();
      });
    } else if (coringas.length > 0) {
      abrirDestaqueCoringa(coringas[0]);
    }
  }, [estado?.ultimasJogadas]);

  // Pausa a IA local enquanto qualquer destaque/zoom estiver em tela.
  const iaPausadaRef = {
    get current() {
      return destaqueRef.current || resultadoRef.current;
    },
  };

  const enviarEstadoRef = useRef(null);
  const { enviarAcaoCliente, enviarEstado, enviarGameOver } = useMultiplayer(
    estado,
    dispatch,
    multiplayerConfig,
    enviarEstadoRef
  );
  enviarEstadoRef.current = enviarEstado;

  // ------------------ Sync host → cliente ------------------
  useEffect(() => {
    if (!isMultiplayer || !isHost) return;
    if (!estado?.isMultiplayer) return;
    if (estadoEnviadoRef.current === estado) return;
    estadoEnviadoRef.current = estado;
    enviarEstado(estado);
  }, [estado, isMultiplayer, isHost, enviarEstado]);

  // ------------------ Init ------------------
  useEffect(() => {
    if (isMultiplayer) {
      if (estado?.isMultiplayer) return;
      if (isHost) {
        dispatch({
          type: 'INICIAR_MULTIPLAYER',
          payload: {
            nomeJogador1: multiplayerConfig?.perfil?.nickName || 'JOGADOR_1',
            nomeJogador2: multiplayerConfig?.oponente?.nome || 'OPONENTE',
            primeiroJogadorIndex: multiplayerConfig?.primeiroJogadorIndex,
            avatar1: multiplayerConfig?.perfil?.avatar || '1',
            avatar2: multiplayerConfig?.oponente?.avatar || '2',
          },
        });
      }
      return;
    }

    if (estado && estado.jogadores?.length !== quantidade) {
      const nomes = ['VOCE', 'ROBO', 'RAPOSA', 'DRAGAO', 'MASCARA', 'LEAO', 'LUA', 'RAIO'];
      const nomesJogadores = Array.from({ length: quantidade }, (_, i) => nomes[i] || `JOGADOR ${i + 1}`);
      const avatarsJogadores = nomesJogadores.map((_, i) => {
        if (i === 0) return perfilAvatarPadrao();
        return AVATARES_IA_PADRAO[(i - 1) % AVATARES_IA_PADRAO.length];
      });
      dispatch({ type: 'INICIAR_MULTI_N', payload: { nomesJogadores, avatarsJogadores } });
    }
  }, [isMultiplayer, isHost, estado?.isMultiplayer, estado?.jogadores?.length, quantidade, multiplayerConfig, dispatch]);

  // ------------------ IA local (só simulação) ------------------
  useIAMulti(isMultiplayer ? null : estado, dispatch, iaPausadaRef);

  // ------------------ Limpa seleção ao trocar turno ------------------
  useEffect(() => {
    setCartasSelecionadas([]);
    setAreaSeguraSelecionadas([]);
    setJogandoEmAndamento(false);
    iaAnimacaoProcessada.current = null;
  }, [estado?.jogadorAtivoIndex, estado?.turnoAtual]);

  // ------------------ Derivados ------------------
  const jogadores = estado?.jogadores || [];
  const jogadorLocal = jogadores[meuIdx];
  const jogadorAtivo = jogadores[estado?.jogadorAtivoIndex ?? 0];

  const isMinhaVez =
    estado?.jogadorAtivoIndex === meuIdx &&
    !estado?.fimDeJogo &&
    batalhaIniciada;

  const outrosJogadores = jogadores
    .map((j, i) => ({ ...j, idx: i }))
    .filter((j) => j.idx !== meuIdx);

  const fluxoDirecao = estado?.direcaoTurno || 1;
  const nomeJogadorAtivo = isMinhaVez
    ? (jogadorLocal?.nome || 'VOCE')
    : (jogadorAtivo?.nome || 'OPONENTE');

  // ------------------ Timer de turno (20s + efeitos TEMPO_TURNO) --
  const jogadorAtivoTimer = jogadores[estado?.jogadorAtivoIndex ?? 0];
  const duracaoTimer = jogadorAtivoTimer
    ? duracaoTurno(jogadorAtivoTimer)
    : TURNO_BASE_SEGUNDOS;
  const chaveTimer = `${estado?.jogadorAtivoIndex ?? 0}_${estado?.turnoAtual ?? 1}`;
  // Local (vs IA): contagem so no turno humano. MP: todos veem, so o
  // host manda passar a vez quando o tempo esgota.
  const tempoAtivo =
    !!estado?.batalhaIniciada && !estado?.fimDeJogo && (isMultiplayer || isMinhaVez);

  const posicoes = calcularPosicoes(quantidade);
  const posMaoLocal = { x: W / 2 - 30, y: H - 110 };
  const DECKS_POS = DECKS_POS_1V1;

  // ------------------ Avatar de cada jogador ------------------
  const getAvatarSourceDoJogador = (jogador, index) => {
    const avatarId =
      jogador?.avatar ||
      (index === meuIdx
        ? (multiplayerConfig?.perfil?.avatar || '7')
        : (AVATARES_IA_PADRAO[index % AVATARES_IA_PADRAO.length] || '3'));
    return getAvatarById(avatarId);
  };

  // ------------------ Animação da IA (só simulação) ------------------
  useEffect(() => {
    if (isMultiplayer) return;
    const anim = estado?.iaAnimacao;
    if (!anim) return;
    if (iaAnimacaoProcessada.current === anim) return;
    iaAnimacaoProcessada.current = anim;

    const idxAnimado = anim.jogadorIdx;
    const posAlvo = posicoes[idxAnimado] || { x: W / 2, y: H / 2 };

    if (anim.tipo === 'jogar') {
      const key = `ia_jogar_${Date.now()}`;
      setCartasDescarte((prev) => [...prev, {
        key,
        tipo: 'voadora',
        imgSource: traseiraImg,
        deX: posAlvo.x - MINI_CARD_W / 2,
        deY: posAlvo.y - MINI_CARD_H / 2,
        paraX: DECKS_POS.descX,
        paraY: DECKS_POS.descY,
        duracao: 400,
        delay: 0,
        onCompleto: () => setCartasDescarte((prev) => prev.filter((v) => v.key !== key)),
      }]);
    } else if (anim.tipo === 'comprar') {
      setVoadora2({
        key: `ia_comprar_${Date.now()}`,
        imgSource: traseiraImg,
        deX: DECKS_POS.drawX,
        deY: DECKS_POS.drawY,
        paraX: posAlvo.x - MINI_CARD_W / 2,
        paraY: posAlvo.y - MINI_CARD_H / 2,
        duracao: 350,
        onCompleto: () => { soundManager.playCardDraw(); setVoadora2(null); },
      });
    }
  }, [estado?.iaAnimacao, isMultiplayer, posicoes]);

  useEffect(() => {
    if (estado?.fimDeJogo) {
      screenShake(shakeX, shakeY, 12);
    }
  }, [estado?.fimDeJogo]);

  useEffect(() => {
    if (!estado?.jogadores) return;
    estado.jogadores.forEach((j, i) => {
      const prevSaldo = prevSaldoRef.current[i];
      if (prevSaldo !== undefined && j.saldo !== prevSaldo) {
        const diff = j.saldo - prevSaldo;
        const pos = posicoes[i] || { x: W / 2, y: H / 2 };
        setScorePopups([{ valor: diff, x: pos.x - 40, y: pos.y - 30 }]);

        if (diff < 0) {
          screenShake(shakeX, shakeY, 6);
        }

        setParticlesData({
          visivel: true,
          x: pos.x,
          y: pos.y,
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

  // ------------------ Handlers ------------------

  const handleAnimacaoInicioCompleta = useCallback(() => {
    setBatalhaIniciada(true);
    soundManager.playBattleStart();
    if (!isMultiplayer || isHost) {
      dispatch({ type: 'BATALHA_INICIADA' });
    }
  }, [dispatch, isMultiplayer, isHost]);

  const handleToggleSelectCarta = useCallback((carta) => {
    if (!isMinhaVez) return;
    setCartasSelecionadas((prev) => {
      const jaSelecionada = prev.some((c) => c.uid === carta.uid);
      if (jaSelecionada) return prev.filter((c) => c.uid !== carta.uid);
      if (prev.length >= MAX_CARTAS_POR_TURNO) return prev;
      return [...prev, carta];
    });
  }, [isMinhaVez]);

  const handleColocarAreaSegura = useCallback(() => {
    if (!isMinhaVez || cartasSelecionadas.length === 0) return;
    const carta = cartasSelecionadas[0];
    setCartasSelecionadas([]);
    if (isMultiplayer) {
      if (isHost) {
        dispatch({
          type: 'COLOCAR_AREA_SEGURA_N',
          payload: { jogadorIdx: meuIdx, cartaUid: carta.uid },
        });
      } else {
        enviarAcaoCliente({
          type: 'COLOCAR_AREA_SEGURA_N',
          payload: { jogadorIdx: meuIdx, cartaUid: carta.uid },
        });
      }
    } else {
      dispatch({ type: 'COLOCAR_AREA_SEGURA_N', payload: { jogadorIdx: meuIdx, cartaUid: carta.uid } });
    }
  }, [isMinhaVez, cartasSelecionadas, isMultiplayer, isHost, enviarAcaoCliente, dispatch, meuIdx]);

  // Usar carta da Area Segura: funciona até fora do turno (vai direto
  // pro descarte). Não checa isMinhaVez de propósito.
  const handleJogarAreaSegura = useCallback((jogadorId, cartaUid) => {
    const idx = estado.jogadores.findIndex(j => j.id === jogadorId);
    if (isMultiplayer) {
      if (isHost) {
        dispatch({
          type: 'JOGAR_AREA_SEGURA_N',
          payload: { jogadorIdx: idx, cartaUid },
        });
      } else {
        enviarAcaoCliente({
          type: 'JOGAR_AREA_SEGURA_N',
          payload: { jogadorIdx: idx, cartaUid },
        });
      }
    } else {
      dispatch({
        type: 'JOGAR_AREA_SEGURA_N',
        payload: { jogadorIdx: idx, cartaUid },
      });
    }
  }, [isMultiplayer, isHost, enviarAcaoCliente, dispatch, estado]);

  // ctx opcional: { mapaRoubo, alvoIdx, alvoId } — usado pelo roubo às
  // cegas para direcionar o alvo e levar os uids escolhidos.
  const aplicarJogadaRemota = (carta, ctx = {}) => {
    const mapaRoubo = ctx && ctx.mapaRoubo;
    const roubarUids = mapaRoubo ? mapaRoubo[carta.uid] || null : null;
    if (isMultiplayer) {
      const payload = {
        jogadorId: jogadorLocal.id,
        cartaUid: carta.uid,
        jogadorAlvoId: ctx && ctx.alvoId != null ? ctx.alvoId : null,
        roubarUids,
      };
      if (isHost) {
        dispatch({ type: 'JOGAR_CARTA_SEM_COMPRA', payload });
      } else {
        enviarAcaoCliente({ type: 'JOGAR_CARTA_SEM_COMPRA', payload });
      }
    } else {
      let alvoIdx = ctx && ctx.alvoIdx != null ? ctx.alvoIdx : null;
      if (alvoIdx == null && carta.precisaAlvo) {
        const vivos = estadoRef.current.jogadores
          .map((j, idx) => ({ ...j, idx }))
          .filter((j) => !j.falido && j.idx !== 0);
        if (vivos.length > 0) {
          alvoIdx = vivos[Math.floor(Math.random() * vivos.length)].idx;
        }
      }
      jogarCartaSemComprarN(0, carta.uid, alvoIdx, roubarUids);
    }
  };

  const passarVez = () => {
    if (isMultiplayer) {
      if (isHost) passarTurno();
      else enviarAcaoCliente({ type: 'PASSAR_TURNO' });
    } else {
      passarTurnoN();
    }
  };

  // Passa a vez com guarda por chave de turno (evita pass duplicado no
  // mesmo turno: timer x clique manual x fim da animacao de jogada).
  const executarPassar = () => {
    if (passouNesteTurnoRef.current === chaveTimer) return;
    passouNesteTurnoRef.current = chaveTimer;
    setCartasSelecionadas([]);
    setAreaSeguraSelecionadas([]);
    passarVez();
  };

  // Timer esgotou: em MP so o host e autoritativo (o cliente aguarda o
  // sync do estado); no modo local so roda no turno humano.
  const handleTempoEsgotado = () => {
    if (isMultiplayer && !isHost) return;
    if (destaqueRef.current || resultadoRef.current) return;
    soundManager.playPassTurn();
    executarPassar();
  };

  // Executa a jogada da mão (aplica + anima + passa no fim).
  // ctx: { mapaRoubo, alvoIdx, alvoId } (roubo às cegas).
  const executarJogadaMao = (cartasParaJogar, ctx) => {
    setCartasSelecionadas([]);
    setJogandoEmAndamento(true);

    cartasParaJogar.forEach((c) => aplicarJogadaRemota(c, ctx));

    // Primeiro os destaques em tela: zoom de SUCESSO/FALHA (2s) e,
    // se a leva tem coringa, o destaque dele (3s) em seguida. SO
    // DEPOIS as cartas saem da mão pro descarte.
    const temCoringa = cartasParaJogar.some((c) => c.tipo === TIPO_CARTA.CORINGA);
    const temNormal = cartasParaJogar.some((c) => c.tipo !== TIPO_CARTA.CORINGA);
    const esperaZoom = temNormal ? DURACAO_ZOOM_RESULTADO : 0;
    const esperaCoringa = temCoringa ? DURACAO_DESTAQUE_CORINGA : 0;

    const iniciarSaida = () => {
      const novasVoadoras = cartasParaJogar.map((carta, i) => {
        const key = `saida_${i}_${Date.now()}_${Math.random().toString(36).slice(2, 8)}`;
        return {
          key,
          tipo: 'lift',
          imgSource: imgPorCarta(carta),
          deX: posMaoLocal.x + i * 16,
          deY: posMaoLocal.y - i * 6,
          paraX: DECKS_POS.descX,
          paraY: DECKS_POS.descY,
          duracao: VOO_DURACAO,
          delay: i * STAGGER_CARTAS,
          onCompleto: () => setCartasDescarte((prev) => prev.filter((v) => v.key !== key)),
        };
      });
      setCartasDescarte((prev) => [...prev, ...novasVoadoras]);

      const tempoUltimaSaida =
        (cartasParaJogar.length - 1) * STAGGER_CARTAS + LIFT_DURACAO + VOO_DURACAO + FADE_DURACAO;
      const atrasoCompra = tempoUltimaSaida + 100;

      setTimeout(() => {
        setVoadora2({
          key: `comprar_${Date.now()}`,
          imgSource: traseiraImg,
          deX: DECKS_POS.drawX,
          deY: DECKS_POS.drawY,
          paraX: posMaoLocal.x,
          paraY: posMaoLocal.y,
          duracao: 400,
          onCompleto: () => {
            setVoadora2(null);
            soundManager.playCardDraw();
            executarPassar();
            setJogandoEmAndamento(false);
          },
        });
      }, atrasoCompra);
    };

    const atrasoSaida = esperaZoom + esperaCoringa;
    if (atrasoSaida > 0) setTimeout(iniciarSaida, atrasoSaida);
    else iniciarSaida();
  };

  const handleJogarMao = () => {
    if (!isMinhaVez || cartasSelecionadas.length === 0) return;

    const cartasParaJogar = [...cartasSelecionadas];

    // Vigarice na seleção? Interrompe e abre o roubo às cegas primeiro.
    const vigarice = cartasParaJogar.find((c) => c.efeito?.tipo === 'ROUBA_CARTAS');
    if (vigarice) {
      const vivos = (estado?.jogadores || [])
        .map((j, idx) => ({ j, idx }))
        .filter(({ j, idx }) => !j.falido && idx !== meuIdx);
      const alvos = vivos
        .filter(({ j }) => (j.mao || []).length > 0)
        .map(({ j, idx }) => ({ idx, nome: j.nome, mao: j.mao }));
      if (alvos.length > 0) {
        setModalRoubo({
          cartas: cartasParaJogar,
          uidCarta: vigarice.uid,
          quantidade: vigarice.efeito.quantidade || 2,
          alvos,
        });
        return;
      }
    }
    executarJogadaMao(cartasParaJogar, null);
  };

  const confirmarRouboCego = (alvoIdx, uids) => {
    const pend = modalRoubo;
    setModalRoubo(null);
    if (!pend) return;
    const jogadorAlvo = (estadoRef.current.jogadores || [])[alvoIdx];
    executarJogadaMao(pend.cartas, {
      mapaRoubo: { [pend.uidCarta]: uids },
      alvoIdx,
      alvoId: jogadorAlvo ? jogadorAlvo.id : null,
    });
  };

  // Cancela o modal: as cartas continuam selecionadas (nada jogado).
  const cancelarRouboCego = () => setModalRoubo(null);

  const handlePassarTurno = () => {
    if (!isMinhaVez) return;
    // Durante o zoom de resultado ou destaque de coringa o turno nao
    // pode continuar.
    if (destaqueRef.current || resultadoRef.current) return;
    executarPassar();
  };

  const handleResetar = useCallback(() => {
    setBatalhaIniciada(false);
    setCartasSelecionadas([]);
    setCartasDescarte([]);
    setVoadora2(null);
    setJogandoEmAndamento(false);
    setModalRoubo(null);
    destaqueRef.current = false;
    setDestaqueCoringa(null);
    resultadoRef.current = false;
    setZoomResultado(null);
    resultadoVistoSeqRef.current = 0;
    pendenciaCoringaRef.current = [];
    passouNesteTurnoRef.current = null;
    iaAnimacaoProcessada.current = null;
    resetarJogo();

    if (isMultiplayer) {
      onVoltar();
      return;
    }

    const nomes = ['VOCE', 'ROBO', 'RAPOSA', 'DRAGAO', 'MASCARA', 'LEAO', 'LUA', 'RAIO'];
    const nomesJogadores = Array.from({ length: quantidade }, (_, i) => nomes[i] || `JOGADOR ${i + 1}`);
    const avatarsJogadores = nomesJogadores.map((_, i) => {
      if (i === 0) return perfilAvatarPadrao();
      return AVATARES_IA_PADRAO[(i - 1) % AVATARES_IA_PADRAO.length];
    });
    dispatch({ type: 'INICIAR_MULTI_N', payload: { nomesJogadores, avatarsJogadores } });
  }, [resetarJogo, dispatch, quantidade, isMultiplayer, onVoltar]);

  const handleSair = useCallback(() => {
    if (isMultiplayer) {
      const oponenteIdx = isHost ? 1 : 0;
      const oponenteNome = estado?.jogadores?.[oponenteIdx]?.nome || 'OPONENTE';
      const fimDeJogo = {
        vencedor: oponenteIdx + 1,
        motivo: `${oponenteNome} venceu por desistencia`,
      };
      enviarGameOver(fimDeJogo);
    }
    onVoltar();
  }, [isMultiplayer, isHost, estado, enviarGameOver, onVoltar]);

  if (isMultiplayer && !estado?.isMultiplayer) {
    return (
      <View style={styles.container}>
      <FundoMadeira />
        <View style={styles.overlay} />
        <View style={styles.loadingWrap}>
          <Text style={styles.loadingTexto}>SINCRONIZANDO...</Text>
        </View>
      </View>
    );
  }

  if (!estado || !estado.jogadores) return null;

  const avatarLocalSource = jogadorLocal ? getAvatarSourceDoJogador(jogadorLocal, meuIdx) : null;

  return (
    <Animated.View style={[styles.container, shakeStyle]}>
      <FundoMadeira />
      <View style={styles.overlay} />

      <TouchableOpacity style={styles.botaoPausa} onPress={() => setModalPausa(true)} activeOpacity={0.7}>
        <Image source={pauseImg} style={styles.pauseIcon} resizeMode="contain" />
      </TouchableOpacity>

      <TurnoIndicador
        nomeJogadorAtivo={nomeJogadorAtivo}
        turnoAtual={estado.turnoAtual ?? 1}
        totalTurnos={estado.totalTurnos ?? 10}
        fluxoDirecao={fluxoDirecao}
        isHumano={isMinhaVez}
        duracaoTempo={duracaoTimer}
        chaveTempo={chaveTimer}
        tempoAtivo={tempoAtivo}
          tempoPausado={
            modalPausa ||
            jogandoEmAndamento ||
            !!modalRoubo ||
            !!destaqueCoringa ||
            !!zoomResultado
          }
        onTempoEsgotar={handleTempoEsgotado}
      />

      {isMultiplayer ? (
        <>
          <View style={styles_1v1.topCenterWrapper}>
            <MaoOponente jogador={outrosJogadores[0]} hideStatus={false} />
          </View>
          <AreaSegura
            jogador={outrosJogadores[0]}
            isMinhaVez={false}
            onJogarCartaArea={() => {}}
            cartasSelecionadasArea={[]}
            topo
          />
          <View style={styles_1v1.centerDecksWrapper}>
            <DecksArea
              baralho={estado.baralho}
              pilhaDescarte={estado.pilhaDescarte}
            />
          </View>
        </>
      ) : (
        <>
          <MesaCentral
            numJogadores={quantidade}
            baralho={estado.baralho}
            pilhaDescarte={estado.pilhaDescarte}
          />
          {outrosJogadores.map((jogador) => (
            <SlotOponente
              key={jogador.id}
              jogador={jogador}
              posicao={posicoes[jogador.idx] || POS_OPONENTE_2P}
              isAtivo={estado.jogadorAtivoIndex === jogador.idx}
              index={jogador.idx}
              avatarSource={getAvatarSourceDoJogador(jogador, jogador.idx)}
            />
          ))}
        </>
      )}

      {isMultiplayer ? (
        <View style={styles_1v1.bottomWrapper}>
          <MaoJogador
            jogador={jogadorLocal}
            cartasSelecionadas={cartasSelecionadas}
            onSelecionarCarta={handleToggleSelectCarta}
            onDescartar={handlePassarTurno}
            desabilitado={!isMinhaVez}
            hideStatus={false}
            onZoomCarta={setCartaZoom}
            cartaRecemCompradaUid={cartaRecemCompradaUid}
          />
        </View>
      ) : (
        <>
          <View style={styles.painelLocalPos}>
            <Pressable onPress={handlePassarTurno} style={styles.painelLocal}>
              <View style={[styles.painelLocalInner, { borderColor: jogadorLocal?.cor || '#FFD54F' }]}>
                <View style={[styles.painelLocalAvatar, { borderColor: jogadorLocal?.cor || '#FFD54F' }]}>
                  {avatarLocalSource ? (
                    <Image source={avatarLocalSource} style={styles.painelLocalAvatarImg} resizeMode="contain" />
                  ) : (
                    <Text style={[styles.avatarPlaceholder, { color: jogadorLocal?.cor || '#FFD54F' }]}>
                      {meuIdx + 1}
                    </Text>
                  )}
                </View>
                <Text style={[styles.painelLocalNome, { color: jogadorLocal?.cor || '#FFD54F' }]}>
                  {jogadorLocal?.nome || 'VOCE'}
                </Text>
                <View style={styles.painelLocalSaldo}>
                  <Text style={styles.painelLocalSaldoLabel}>R$</Text>
                  <Text style={[
                    styles.painelLocalSaldoValor,
                    {
                      color: (jogadorLocal?.saldo ?? 20) > 10
                        ? '#66BB6A'
                        : (jogadorLocal?.saldo ?? 20) > 5
                          ? '#FFD54F'
                          : '#EF5350',
                    },
                  ]}>
                    {jogadorLocal?.saldo ?? 20}
                  </Text>
                </View>
                {jogadorLocal?.protegido && <Text style={styles.painelLocalProtegido}>🛡️</Text>}
              </View>
            </Pressable>
          </View>

          <View style={styles.maoLocalWrapper}>
            <MaoJogador
              jogador={jogadorLocal}
              cartasSelecionadas={cartasSelecionadas}
              onSelecionarCarta={handleToggleSelectCarta}
              onDescartar={handlePassarTurno}
              desabilitado={!isMinhaVez}
              hideStatus={true}
              onZoomCarta={setCartaZoom}
              cartaRecemCompradaUid={cartaRecemCompradaUid}
            />
          </View>
        </>
      )}

      {isMinhaVez && cartasSelecionadas.length > 0 && (
        <View style={styles.botoesJogarContainer}>
          <Pressable style={styles.botaoJogar} onPress={handleJogarMao}>
            <Text style={styles.botaoJogarTexto}>JOGAR</Text>
            <Text style={styles.botaoJogarContador}>
              {cartasSelecionadas.length}/{MAX_CARTAS_POR_TURNO}
            </Text>
          </Pressable>
          <Pressable style={styles.botaoGuardar} onPress={handleColocarAreaSegura}>
            <Text style={styles.botaoJogarTexto}>GUARDAR</Text>
          </Pressable>
        </View>
      )}

      {areaSeguraVisivel && (
        <AreaSegura
          jogador={jogadorLocal}
          isMinhaVez={isMinhaVez}
          proprio
          onJogarCartaArea={handleJogarAreaSegura}
          cartasSelecionadasArea={areaSeguraSelecionadas}
          onZoomCarta={(carta) => setCartaZoom(carta)}
        />
      )}

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
              {estado.fimDeJogo.vencedor === meuIdx + 1 ? 'VOCE VENCEU!' :
               estado.fimDeJogo.vencedor === 0 ? 'EMPATE!' :
               `${jogadores.find(j => j.id === estado.fimDeJogo.vencedor)?.nome || 'ALGUEM'} VENCEU!`}
            </Text>
            <Text style={styles.overlayMotivo}>{estado.fimDeJogo.motivo}</Text>
            <View style={styles.overlayPlacar}>
              {jogadores.map(j => (
                <Text key={j.id} style={[styles.overlayPlacarLinha, { color: j.falido ? '#EF5350' : (j.cor || '#FFD54F') }]}>
                  {j.nome}: R$ {j.saldo} {j.falido ? '💀' : ''}
                </Text>
              ))}
            </View>
            {!isMultiplayer && (
              <TouchableOpacity style={styles.botaoReiniciar} onPress={handleResetar} activeOpacity={0.7}>
                <Text style={styles.botaoReiniciarTexto}>JOGAR NOVAMENTE</Text>
              </TouchableOpacity>
            )}
            <TouchableOpacity style={styles.botaoSairFim} onPress={onVoltar} activeOpacity={0.7}>
              <Text style={styles.botaoSairFimTexto}>SAIR</Text>
            </TouchableOpacity>
          </View>
        </View>
      )}

      {!estado.batalhaIniciada && (
        <AnimacaoInicioBatalha
          jogadorAtivoIndex={estado.jogadorAtivoIndex}
          jogadores={jogadores.map((j, i) => ({
            nome: j.nome || `JOGADOR ${i + 1}`,
            avatarSource: getAvatarSourceDoJogador(j, j.idx ?? i),
            emoji: '👤',
            cor: j.cor,
          }))}
          nomeJogador={jogadorLocal?.nome || 'VOCE'}
          nomeOponente={jogadores[meuIdx === 0 ? 1 : 0]?.nome || 'OPONENTE'}
          onCompleto={handleAnimacaoInicioCompleta}
        />
      )}

      <CartaZoomModal carta={cartaZoom} visivel={!!cartaZoom} onFechar={() => setCartaZoom(null)} />

      <DestaqueCoringa
        carta={destaqueCoringa?.carta || null}
        sucesso={destaqueCoringa ? destaqueCoringa.sucesso : null}
        onFim={fecharDestaque}
      />

      <ResultadoJogada entradas={zoomResultado} onFim={fecharZoomResultado} />

      <ModalRouboCego
        visivel={!!modalRoubo}
        alvos={modalRoubo?.alvos || []}
        quantidade={modalRoubo?.quantidade || 2}
        traseiraImg={traseiraImg}
        onConfirmar={confirmarRouboCego}
        onCancelar={cancelarRouboCego}
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

      <Modal visible={modalPausa} transparent animationType="fade" onRequestClose={() => setModalPausa(false)}>
        <View style={styles.modalOverlay}>
          <View style={styles.modalContainer}>
            <Text style={styles.modalTitulo}>PAUSA</Text>
            <View style={styles.modalDivisor} />
            <TouchableOpacity style={[styles.modalBotao, styles.modalContinuar]} onPress={() => setModalPausa(false)} activeOpacity={0.7}>
              <Text style={styles.modalBotaoTexto}>CONTINUAR</Text>
            </TouchableOpacity>
            <TouchableOpacity
              style={[styles.modalBotao, styles.modalSair]}
              onPress={isMultiplayer ? () => { setModalPausa(false); handleSair(); } : onVoltar}
              activeOpacity={0.7}
            >
              <Text style={styles.modalBotaoTexto}>SAIR</Text>
            </TouchableOpacity>
          </View>
        </View>
      </Modal>
    </Animated.View>
  );
}

let _perfilCacheSimulacao = null;
export function setPerfilParaSimulacao(perfil) {
  _perfilCacheSimulacao = perfil;
}
function perfilAvatarPadrao() {
  return _perfilCacheSimulacao?.avatar || '7';
}

export default function ArenaMultiplayer({ quantidade, onVoltar, multiplayerConfig }) {
  const qtd = multiplayerConfig ? 2 : (quantidade || 2);
  return (
    <GameProvider>
      <ArenaMultiInterna quantidade={qtd} onVoltar={onVoltar} multiplayerConfig={multiplayerConfig} />
    </GameProvider>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: '#0A0A1A' },
  overlay: { position: 'absolute', width: '100%', height: '100%', backgroundColor: 'rgba(0,0,0,0.2)' },

  loadingWrap: { flex: 1, alignItems: 'center', justifyContent: 'center' },
  loadingTexto: { color: '#FFD54F', fontSize: 16, fontWeight: 'bold', letterSpacing: 3 },

  botaoPausa: {
    position: 'absolute', top: 10, right: 10, width: 36, height: 36, borderRadius: 18,
    backgroundColor: 'rgba(0,0,0,0.6)', borderWidth: 1, borderColor: '#FFD54F',
    alignItems: 'center', justifyContent: 'center', zIndex: 100,
  },
  pauseIcon: { width: 20, height: 20 },

  mesaCentral: {
    position: 'absolute', left: W / 2 - 70, top: H * 0.42 - 70,
    width: 140, height: 140, alignItems: 'center', justifyContent: 'center', zIndex: 5,
  },
  mesaCirculoExt: {
    position: 'absolute', width: 140, height: 140, borderRadius: 70,
    borderWidth: 2, borderColor: '#FFD54F', borderStyle: 'dashed',
  },
  mesaCirculoInt: {
    width: 120, height: 120, borderRadius: 60,
    backgroundColor: 'rgba(15,19,34,0.92)', borderWidth: 2, borderColor: '#7A5C29',
    alignItems: 'center', justifyContent: 'center',
  },
  mesaEmoji: { fontSize: 20 },
  mesaTitulo: { color: '#FFD54F', fontSize: 12, fontWeight: 'bold', letterSpacing: 2 },
  mesaSubtitulo: { color: '#AAB0D0', fontSize: 10, letterSpacing: 1, marginTop: 2 },

  deckInfo: { flexDirection: 'row', gap: 12, marginTop: 6 },
  deckInfoItem: { alignItems: 'center', gap: 2 },
  deckMini: { width: 22, height: 30, borderRadius: 3, borderWidth: 1, borderColor: '#FFD54F88' },
  descarteMini: { width: 22, height: 30, borderRadius: 3 },
  deckCount: { color: '#AAB0D0', fontSize: 8, fontWeight: 'bold' },

  slotOponente: {
    position: 'absolute',
    width: 104,
    paddingVertical: 8,
    paddingHorizontal: 6,
    backgroundColor: 'rgba(10,10,26,0.9)',
    borderWidth: 2,
    borderRadius: 12,
    alignItems: 'center',
    zIndex: 20,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 4 },
    shadowOpacity: 0.7,
    shadowRadius: 6,
    elevation: 8,
  },
  badgeAtivo: {
    position: 'absolute',
    top: -10,
    alignSelf: 'center',
    paddingHorizontal: 8,
    paddingVertical: 2,
    borderRadius: 8,
    zIndex: 30,
  },
  badgeAtivoTexto: { color: '#000', fontSize: 9, fontWeight: 'bold', letterSpacing: 1 },

  slotTopRow: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    marginBottom: 4,
  },
  avatarCirculo: {
    width: 40,
    height: 40,
    borderRadius: 20,
    borderWidth: 2,
    backgroundColor: '#1C2238',
    alignItems: 'center',
    justifyContent: 'center',
    overflow: 'hidden',
  },
  avatarImg: { width: '100%', height: '100%' },
  avatarPlaceholder: {
    fontSize: 16,
    fontWeight: 'bold',
  },

  nomeOponente: {
    fontSize: 10,
    fontWeight: 'bold',
    letterSpacing: 0.5,
    maxWidth: 92,
    textAlign: 'center',
  },

  saldoRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 2,
    marginTop: 2,
  },
  saldoLabel: { color: '#AAB0D0', fontSize: 9, fontWeight: 'bold' },
  saldoValor: { fontSize: 12, fontWeight: 'bold' },

  miniCartasRow: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    gap: 1,
    marginTop: 4,
    height: 18,
  },
  miniCartaTraseira: {
    width: 11,
    height: 16,
    borderRadius: 2,
    borderWidth: 1,
  },
  badgeProtegido: {
    fontSize: 14,
    marginLeft: 4,
  },
  falidoOverlay: {
    ...StyleSheet.absoluteFillObject,
    backgroundColor: 'rgba(0,0,0,0.7)',
    borderRadius: 12,
    alignItems: 'center',
    justifyContent: 'center',
  },
  falidoTexto: { color: '#EF5350', fontSize: 10, fontWeight: 'bold', letterSpacing: 0.5 },

  painelLocalPos: {
    position: 'absolute',
    bottom: 10,
    left: 0,
    right: 0,
    alignItems: 'center',
    zIndex: 18,
  },
  painelLocal: { alignItems: 'center' },
  painelLocalInner: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 8,
    backgroundColor: 'rgba(10,10,26,0.9)',
    borderWidth: 1.5,
    borderRadius: 24,
    paddingLeft: 4,
    paddingRight: 14,
    paddingVertical: 4,
  },
  painelLocalAvatar: {
    width: 32,
    height: 32,
    borderRadius: 16,
    borderWidth: 2,
    backgroundColor: '#1C2238',
    alignItems: 'center',
    justifyContent: 'center',
    overflow: 'hidden',
  },
  painelLocalAvatarImg: { width: '100%', height: '100%' },
  painelLocalNome: { fontSize: 12, fontWeight: 'bold', letterSpacing: 0.5 },
  painelLocalSaldo: { flexDirection: 'row', alignItems: 'center', gap: 2 },
  painelLocalSaldoLabel: { color: '#AAB0D0', fontSize: 10, fontWeight: 'bold' },
  painelLocalSaldoValor: { fontSize: 13, fontWeight: 'bold' },
  painelLocalProtegido: { fontSize: 14 },

  maoLocalWrapper: {
    position: 'absolute',
    bottom: 0,
    left: 0,
    right: 0,
    alignItems: 'center',
    zIndex: 22,
  },

  botoesJogarContainer: {
    position: 'absolute',
    bottom: 8,
    left: 8,
    flexDirection: 'row',
    gap: 8,
    zIndex: 30,
    elevation: 6,
  },
   botaoJogar: {
     backgroundColor: '#2E7D32',
     borderRadius: 8,
     paddingHorizontal: 10,
     paddingVertical: 6,
     alignItems: 'center',
     justifyContent: 'center',
     borderWidth: 2,
     borderColor: '#66BB6A',
   },
   botaoGuardar: {
     backgroundColor: '#1565C0',
     borderRadius: 8,
     paddingHorizontal: 10,
     paddingVertical: 6,
     alignItems: 'center',
     justifyContent: 'center',
     borderWidth: 2,
     borderColor: '#42A5F5',
   },
   botaoJogarTexto: { color: '#FFF', fontWeight: 'bold', fontSize: 12, letterSpacing: 1 },
  botaoJogarContador: { color: '#C8E6C9', fontSize: 11, marginTop: 2 },

  cartaVoadora: {
    position: 'absolute',
    width: CARD_W,
    height: CARD_H,
    zIndex: 100,
  },
  cartaVoadoraImg: { width: '100%', height: '100%', borderRadius: 6 },

  overlayFim: {
    ...StyleSheet.absoluteFillObject,
    backgroundColor: 'rgba(0,0,0,0.88)',
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
    maxWidth: '85%',
  },
  overlayTitulo: { fontSize: 22, color: '#FFD54F', fontWeight: 'bold', marginBottom: 8 },
  overlayMotivo: { fontSize: 13, color: '#CCC', textAlign: 'center', marginBottom: 12 },
  overlayPlacar: { width: '100%', marginBottom: 16 },
  overlayPlacarLinha: { fontSize: 13, fontWeight: 'bold', marginBottom: 4, textAlign: 'center' },
  botaoReiniciar: {
    backgroundColor: '#2E7D32',
    borderRadius: 8,
    paddingHorizontal: 20,
    paddingVertical: 10,
    marginBottom: 8,
  },
  botaoReiniciarTexto: { color: '#FFF', fontWeight: 'bold', fontSize: 14, letterSpacing: 1 },
  botaoSairFim: {
    backgroundColor: '#C62828',
    borderRadius: 8,
    paddingHorizontal: 20,
    paddingVertical: 10,
  },
  botaoSairFimTexto: { color: '#FFF', fontWeight: 'bold', fontSize: 14, letterSpacing: 1 },

  modalOverlay: {
    flex: 1,
    backgroundColor: 'rgba(0,0,0,0.85)',
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
  modalTitulo: { fontSize: 24, color: '#FFD54F', fontWeight: 'bold', letterSpacing: 3, marginBottom: 8 },
  modalDivisor: { width: '80%', height: 1, backgroundColor: '#FFD54F', opacity: 0.4, marginBottom: 20 },
  modalBotao: {
    width: '100%',
    paddingVertical: 14,
    borderRadius: 8,
    alignItems: 'center',
    marginBottom: 12,
  },
  modalContinuar: { backgroundColor: '#2E7D32' },
  modalSair: { backgroundColor: '#C62828' },
  modalBotaoTexto: { color: '#FFF', fontWeight: 'bold', fontSize: 16, letterSpacing: 1 },
});

const styles_1v1 = StyleSheet.create({
  topCenterWrapper: {
    position: 'absolute',
    top: 10,
    width: '100%',
    alignItems: 'center',
    zIndex: 15,
  },
  centerDecksWrapper: {
    position: 'absolute',
    top: H * 0.44,
    width: '100%',
    alignItems: 'center',
    zIndex: 10,
  },
  bottomWrapper: {
    position: 'absolute',
    bottom: 0,
    left: 0,
    right: 0,
    alignItems: 'center',
    zIndex: 25,
  },
});
