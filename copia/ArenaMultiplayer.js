import React, { useState, useRef, useEffect, useCallback } from 'react';
import {
  View,
  Text,
  StyleSheet,
  Image,
  Dimensions,
  TouchableOpacity,
  Modal,
  Animated,
  Pressable,
} from 'react-native';
import { GameProvider, useGameState } from '../context/GameContext';
import { useIAMulti } from '../hooks/useIAMulti';
import { useMultiplayer } from '../multiplayer/useMultiplayer';
import TurnoIndicador from '../components/arena/TurnoIndicador';
import CartaZoomModal from '../components/arena/CartaZoomModal';
import AnimacaoInicioBatalha from '../components/arena/AnimacaoInicioBatalha';
import MaoJogador from '../components/arena/MaoJogador';
import MaoOponente from '../components/arena/MaoOponente';
import DecksArea from '../components/arena/DecksArea';
import ParticleBurst from '../components/arena/Particles';
import ScorePopup from '../components/arena/ScorePopup';
import { screenShake } from '../utils/screenShake';
import { getAvatarById } from '../utils/avatar';
import { soundManager } from '../utils/sound';

const bgImg = require('../assets/sprites/batalha/background.jpg');
const traseiraImg = require('../assets/cards/traseira_cartas.jpg');
const nossoImg = require('../assets/cards/nosso.png');
const toyotinhoImg = require('../assets/cards/toyotinho.png');
const pauseImg = require('../assets/sprites/menu/pause.jpg');

const cardImages = { 0: nossoImg, 1: toyotinhoImg };
const imgPorCarta = (c) => (c && cardImages[c.uid % 2]) || traseiraImg;

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

// Posições para layout 1v1 (single-player style)
const POS_MAO_1V1_OPONENTE = { x: W / 2 - 30, y: 20 };
const POS_MAO_1V1_LOCAL = { x: W / 2 - 30, y: H - 120 };
const DECKS_POS_1V1 = { drawX: W / 2 - 58 - 18, drawY: H * 0.44 + 40, descX: W / 2 + 18, descY: H * 0.44 + 40 };

const PLAYER_COLORS = ['#FFD54F', '#EF5350', '#42A5F5', '#66BB6A', '#AB47BC', '#FF7043', '#26C6DA', '#EC407A'];

// Avatares padrão para os oponentes IA na simulação (2-8 jogadores).
// O jogador 0 (humano local) usa o avatar do perfil quando houver.
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
  const posX = useRef(new Animated.Value(deX)).current;
  const posY = useRef(new Animated.Value(deY)).current;
  const escala = useRef(new Animated.Value(1)).current;
  const opacidade = useRef(new Animated.Value(1)).current;
  const rotacao = useRef(new Animated.Value(0)).current;

  useEffect(() => {
    const rotacaoAleatoria = (Math.random() - 0.5) * 8;

    Animated.sequence([
      Animated.parallel([
        Animated.timing(posX, { toValue: paraX, duration: duracao, useNativeDriver: false }),
        Animated.sequence([
          Animated.timing(posY, { toValue: Math.min(deY, paraY) - 30, duration: duracao * 0.5, useNativeDriver: false }),
          Animated.spring(posY, { toValue: paraY, friction: 6, tension: 40, useNativeDriver: false }),
        ]),
        Animated.timing(escala, { toValue: 0.5, duration: duracao, useNativeDriver: false }),
        Animated.spring(rotacao, { toValue: rotacaoAleatoria, friction: 5, tension: 50, useNativeDriver: false }),
      ]),
      Animated.timing(opacidade, { toValue: 0, duration: 150, useNativeDriver: false }),
    ]).start(() => { if (onCompleto) onCompleto(); });
  }, []);

  const rotateStr = rotacao.interpolate({
    inputRange: [-10, 10],
    outputRange: ['-10deg', '10deg'],
  });

  return (
    <Animated.View style={[styles.cartaVoadora, { left: posX, top: posY, opacity: opacidade, transform: [{ scale: escala }, { rotate: rotateStr }] }]}>
      <Image source={imgSource} style={styles.cartaVoadoraImg} resizeMode="cover" />
    </Animated.View>
  );
}

function CartaSaidaComLift({ imgSource, deX, deY, paraX, paraY, duracao = VOO_DURACAO, delay = 0, onCompleto }) {
  const posX = useRef(new Animated.Value(deX)).current;
  const posY = useRef(new Animated.Value(deY)).current;
  const escala = useRef(new Animated.Value(1)).current;
  const rotacao = useRef(new Animated.Value(0)).current;
  const opacidade = useRef(new Animated.Value(1)).current;

  useEffect(() => {
    const somTimer = setTimeout(() => soundManager.playCardPlay(), delay);
    const rotacaoAleatoria = (Math.random() - 0.5) * 10;

    Animated.sequence([
      Animated.delay(delay),
      Animated.parallel([
        Animated.spring(posY,    { toValue: deY - 55, friction: 5, tension: 80, useNativeDriver: false }),
        Animated.spring(escala,  { toValue: 1.22,     friction: 4, tension: 100, useNativeDriver: false }),
        Animated.spring(rotacao, { toValue: rotacaoAleatoria, friction: 5, tension: 60, useNativeDriver: false }),
      ]),
      Animated.parallel([
        Animated.timing(posX,    { toValue: paraX, duration: duracao, useNativeDriver: false }),
        Animated.sequence([
          Animated.timing(posY, { toValue: Math.min(deY, paraY) - 40, duration: duracao * 0.5, useNativeDriver: false }),
          Animated.spring(posY, { toValue: paraY, friction: 6, tension: 40, useNativeDriver: false }),
        ]),
        Animated.spring(escala,  { toValue: 0.7,   friction: 6, tension: 30, useNativeDriver: false }),
        Animated.spring(rotacao, { toValue: 0,      friction: 7, tension: 50, useNativeDriver: false }),
      ]),
      Animated.timing(opacidade, { toValue: 0, duration: FADE_DURACAO, useNativeDriver: false }),
    ]).start(() => {
      clearTimeout(somTimer);
      if (onCompleto) onCompleto();
    });
    return () => clearTimeout(somTimer);
  }, []);

  const rotateStr = rotacao.interpolate({
    inputRange: [-15, 15],
    outputRange: ['-15deg', '15deg'],
  });

  return (
    <Animated.View
      style={[
        styles.cartaVoadora,
        { left: posX, top: posY, opacity: opacidade, transform: [{ scale: escala }, { rotate: rotateStr }] },
      ]}
    >
      <Image source={imgSource} style={styles.cartaVoadoraImg} resizeMode="cover" />
    </Animated.View>
  );
}

// ============================ Slot de oponente ============================

function SlotOponente({ jogador, posicao, isAtivo, index, avatarSource }) {
  const pulseAnim = useRef(new Animated.Value(1)).current;

  useEffect(() => {
    if (isAtivo) {
      Animated.loop(
        Animated.sequence([
          Animated.timing(pulseAnim, { toValue: 1.05, duration: 600, useNativeDriver: true }),
          Animated.timing(pulseAnim, { toValue: 1, duration: 600, useNativeDriver: true }),
        ])
      ).start();
    } else {
      pulseAnim.setValue(1);
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

      {/* Linha 1: avatar + status de proteção */}
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

      {/* Linha 2: nome */}
      <Text style={[styles.nomeOponente, { color: cor }]} numberOfLines={1}>
        {jogador.nome}
      </Text>

      {/* Linha 3: saldo */}
      <View style={styles.saldoRow}>
        <Text style={styles.saldoLabel}>R$</Text>
        <Text style={[
          styles.saldoValor,
          { color: jogador.saldo > 10 ? '#66BB6A' : jogador.saldo > 5 ? '#FFD54F' : '#EF5350' },
        ]}>
          {jogador.saldo}
        </Text>
      </View>

      {/* Linha 4: mini cartas viradas */}
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
  const rotAnim = useRef(new Animated.Value(0)).current;

  useEffect(() => {
    Animated.loop(
      Animated.timing(rotAnim, { toValue: 1, duration: 30000, useNativeDriver: true })
    ).start();
  }, []);

  const rot = rotAnim.interpolate({ inputRange: [0, 1], outputRange: ['0deg', '360deg'] });

  return (
    <View style={styles.mesaCentral}>
      <Animated.View style={[styles.mesaCirculoExt, { transform: [{ rotate: rot }] }]} />
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
                  source={cardImages[(pilhaDescarte[pilhaDescarte.length - 1]?.uid || 0) % 2]}
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
  const [particlesData, setParticlesData] = useState({ visivel: false, x: 0, y: 0, cores: null });
  const [scorePopups, setScorePopups] = useState([]);
  const [cartaRecemCompradaUid, setCartaRecemCompradaUid] = useState(null);

  const iaAnimacaoProcessada = useRef(null);
  const estadoRef = useRef(estado);
  const estadoEnviadoRef = useRef(null);
  const shakeX = useRef(new Animated.Value(0)).current;
  const shakeY = useRef(new Animated.Value(0)).current;
  const prevSaldoRef = useRef({});

  const isMultiplayer = !!multiplayerConfig;
  const isHost = multiplayerConfig?.isHost;
  const meuIdx = isMultiplayer && !isHost ? 1 : 0;

  useEffect(() => { estadoRef.current = estado; }, [estado]);

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

    // Simulação
    if (estado && estado.jogadores?.length !== quantidade) {
      const nomes = ['VOCE', 'ROBO', 'RAPOSA', 'DRAGAO', 'MASCARA', 'LEAO', 'LUA', 'RAIO'];
      const nomesJogadores = Array.from({ length: quantidade }, (_, i) => nomes[i] || `JOGADOR ${i + 1}`);
      // Avatar do jogador 0 = do perfil (se houver) ou '7' como fallback.
      // Os demais recebem avatares IA padrão (variedade visual).
      const avatarsJogadores = nomesJogadores.map((_, i) => {
        if (i === 0) return perfilAvatarPadrao();
        return AVATARES_IA_PADRAO[(i - 1) % AVATARES_IA_PADRAO.length];
      });
      dispatch({ type: 'INICIAR_MULTI_N', payload: { nomesJogadores, avatarsJogadores } });
    }
  }, [isMultiplayer, isHost, estado?.isMultiplayer, estado?.jogadores?.length, quantidade, multiplayerConfig, dispatch]);

  // ------------------ IA local (só simulação) ------------------
  useIAMulti(isMultiplayer ? null : estado, dispatch);

  // ------------------ Limpa seleção ao trocar turno ------------------
  useEffect(() => {
    setCartasSelecionadas([]);
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

  const posicoes = calcularPosicoes(quantidade);
  const posMaoLocal = { x: W / 2 - 30, y: H - 110 };
  const DECKS_POS = DECKS_POS_1V1;

  // ------------------ Avatar de cada jogador ------------------
  // Usa o `avatar` guardado no próprio jogador (que já foi setado no estado).
  // Fallback: pega do multiplayerConfig se o jogador não tiver avatar.
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
    if (isMultiplayer && !isHost) return;
    setBatalhaIniciada(true);
    dispatch({ type: 'BATALHA_INICIADA' });
    soundManager.playBattleStart();
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

  const aplicarJogadaRemota = (carta) => {
    if (isMultiplayer) {
      if (isHost) {
        dispatch({
          type: 'JOGAR_CARTA_SEM_COMPRA',
          payload: { jogadorId: jogadorLocal.id, cartaUid: carta.uid, jogadorAlvoId: null },
        });
      } else {
        enviarAcaoCliente({
          type: 'JOGAR_CARTA_SEM_COMPRA',
          payload: { jogadorId: jogadorLocal.id, cartaUid: carta.uid, jogadorAlvoId: null },
        });
      }
    } else {
      let alvoIdx = null;
      if (carta.precisaAlvo) {
        const vivos = estadoRef.current.jogadores
          .map((j, idx) => ({ ...j, idx }))
          .filter((j) => !j.falido && j.idx !== 0);
        if (vivos.length > 0) {
          alvoIdx = vivos[Math.floor(Math.random() * vivos.length)].idx;
        }
      }
      jogarCartaSemComprarN(0, carta.uid, alvoIdx);
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

  const handleJogarMao = useCallback(() => {
    if (!isMinhaVez || cartasSelecionadas.length === 0) return;

    const cartasParaJogar = [...cartasSelecionadas];
    setCartasSelecionadas([]);

    cartasParaJogar.forEach(aplicarJogadaRemota);

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
          passarVez();
        },
      });
    }, atrasoCompra);
  }, [isMinhaVez, cartasSelecionadas, estado, isMultiplayer, isHost, jogadorLocal, enviarAcaoCliente, dispatch]);

  const handlePassarTurno = useCallback(() => {
    if (!isMinhaVez) return;
    setCartasSelecionadas([]);
    passarVez();
  }, [isMinhaVez]);

  const handleResetar = useCallback(() => {
    setBatalhaIniciada(false);
    setCartasSelecionadas([]);
    setCartasDescarte([]);
    setVoadora2(null);
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
<Image source={bgImg} style={styles.bg} resizeMode="cover" />
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
    <Animated.View style={[styles.container, { transform: [{ translateX: shakeX }, { translateY: shakeY }] }]}>
      <Image source={bgImg} style={styles.bg} resizeMode="cover" />
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
      />

      {isMultiplayer ? (
        <>
          <View style={styles_1v1.topCenterWrapper}>
            <MaoOponente jogador={outrosJogadores[0]} hideStatus={false} />
          </View>
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
        <Pressable style={styles.botaoJogar} onPress={handleJogarMao}>
          <Text style={styles.botaoJogarTexto}>JOGAR</Text>
          <Text style={styles.botaoJogarContador}>
            {cartasSelecionadas.length}/{MAX_CARTAS_POR_TURNO}
          </Text>
        </Pressable>
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
          nomeJogador={jogadorLocal?.nome || 'VOCE'}
          nomeOponente={jogadores[meuIdx === 0 ? 1 : 0]?.nome || 'OPONENTE'}
          onCompleto={handleAnimacaoInicioCompleta}
        />
      )}

      <CartaZoomModal carta={cartaZoom} visivel={!!cartaZoom} onFechar={() => setCartaZoom(null)} />

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

// Fallback de avatar para o jogador local na simulação (quando não há perfil).
// Mantém compatível com `getAvatarById`, que espera string de ID.
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
  bg: { position: 'absolute', width: '100%', height: '100%' },
  overlay: { position: 'absolute', width: '100%', height: '100%', backgroundColor: 'rgba(0,0,0,0.45)' },

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

  // -------- Slot de oponente (organizado em coluna) --------
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

  // -------- Painel do jogador local --------
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

  botaoJogar: {
    position: 'absolute',
    bottom: 8,
    left: 8,
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
  botaoJogarTexto: { color: '#FFF', fontWeight: 'bold', fontSize: 16, letterSpacing: 1 },
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