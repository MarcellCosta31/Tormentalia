import React, { useState, useCallback, useEffect, useRef } from 'react';
import { View, Text, StyleSheet, Image, Animated, Dimensions, Pressable } from 'react-native';
import { GameProvider, useGameState } from '../../context/GameContext';
import { useIA } from '../../hooks/useIA';
import MaoJogador from './MaoJogador';
import MaoOponente from './MaoOponente';
import TurnoIndicador from './TurnoIndicador';
import DecksArea from './DecksArea';
import PainelStatus from './PainelStatus';
import CartaZoomModal from './CartaZoomModal';
import { soundManager } from '../../utils/sound';

const bgImg = require('../../assets/sprites/background.png');
const traseiraImg = require('../../assets/cards/traseira_cartas.jpg');
const nossoImg = require('../../assets/cards/nosso.png');
const toyotinhoImg = require('../../assets/cards/toyotinho.png');

const cardImages = {
  0: nossoImg,
  1: toyotinhoImg,
};

const { width: SCREEN_WIDTH, height: SCREEN_HEIGHT } = Dimensions.get('screen');

const CARD_W = 70;
const CARD_H = 98;

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
        Animated.timing(escala, { toValue: 0.7, duration: duracao, useNativeDriver: false }),
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

function ArenaInterna() {
  const { estado, jogarCarta, passarTurno, resetarJogo, dispatch } = useGameState();
  const [cartaSelecionada, setCartaSelecionada] = useState(null);
  const [voadora, setVoadora] = useState(null);
  const [decksPos, setDecksPos] = useState(null);
  const [panelPressed, setPanelPressed] = useState(false);
  const [cartaZoom, setCartaZoom] = useState(null);
  const longPressTimer = useRef(null);

  const { iaExecutando } = useIA(estado, dispatch);

  useEffect(() => {
    setCartaSelecionada(null);
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
    ? (jogadorLocal?.nome || 'JOGADOR_HUMANO')
    : (oponenteIA?.nome || 'OPONENTE_IA');

  const handleSelecionarCarta = useCallback((carta) => {
    if (!isMinhaVez) return;
    setCartaSelecionada(carta);
  }, [isMinhaVez]);

  const handleAnimacaoSaidaCompleta = useCallback((carta) => {
    const descX = decksPos ? decksPos.descX : SCREEN_WIDTH / 2 + 30;
    const descY = decksPos ? decksPos.descY : SCREEN_HEIGHT * 0.4;
    const cartaImg = cardImages[carta.uid % 2];

    setVoadora({
      key: 'descarte_' + Date.now(),
      imgSource: cartaImg,
      deX: SCREEN_WIDTH - 120,
      deY: SCREEN_HEIGHT - 120,
      paraX: descX,
      paraY: descY,
      onCompleto: () => {
        if (carta.precisaAlvo) {
          jogarCarta(jogadorLocal.id, carta.uid, oponenteIA.id);
        } else {
          jogarCarta(jogadorLocal.id, carta.uid, null);
        }
        setCartaSelecionada(null);

        setTimeout(() => {
          const drawX = decksPos ? decksPos.drawX : SCREEN_WIDTH / 2 - 65;
          const drawY = decksPos ? decksPos.drawY : SCREEN_HEIGHT * 0.4;
          setVoadora({
            key: 'comprar_' + Date.now(),
            imgSource: traseiraImg,
            deX: drawX,
            deY: drawY,
            paraX: SCREEN_WIDTH - 120,
            paraY: SCREEN_HEIGHT - 100,
            onCompleto: () => setVoadora(null),
          });
        }, 100);
      },
    });
  }, [jogadorLocal, oponenteIA, jogarCarta, decksPos]);

  const handlePassarTurno = useCallback(() => {
    if (!isMinhaVez) return;
    passarTurno();
    setCartaSelecionada(null);
  }, [isMinhaVez, passarTurno]);

  const handleDecksLayout = useCallback((drawX, drawY, descX, descY) => {
    setDecksPos({ drawX, drawY, descX, descY });
  }, []);

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

      {/* Luz de holofote sobre a mesa central */}
      <View style={styles.spotlight} pointerEvents="none" />

      {/* Top Left: Placa de madeira pendurada por correntes */}
      <View style={styles.topLeftWrapper}>
        <TurnoIndicador
          nomeJogadorAtivo={nomeJogadorAtivo}
          turnoAtual={estado.turnoAtual ?? 1}
          totalTurnos={estado.totalTurnos ?? 10}
        />
      </View>

      {/* Top Center: Painel do Oponente + Mão do Oponente (cartas viradas) */}
      <View style={styles.topCenterWrapper}>
        <MaoOponente jogador={oponenteIA} hideStatus={false} />
      </View>

      {/* Center Table: Baralho (esquerda) e Descarte (direita) */}
      <View style={styles.centerDecksWrapper}>
        <DecksArea
          baralho={estado.baralho}
          pilhaDescarte={estado.pilhaDescarte}
          onLayout={handleDecksLayout}
        />
      </View>

      {/* Bottom Center: Painel de Status do Jogador Humano */}
      <View style={styles.bottomCenterWrapper}>
        <Pressable
          onPressIn={handlePanelPressIn}
          onPressOut={handlePanelPressOut}
          style={styles.painelPressable}
        >
          <PainelStatus nome={jogadorLocal?.nome || 'JOGADOR_HUMANO'} saldo={jogadorLocal?.saldo ?? 20} corDestaque="#FFD54F" />
          {panelPressed && (
            <View style={styles.passarOverlay}>
              <Text style={styles.passarTexto}>SOLTAR PARA PASSAR</Text>
            </View>
          )}
        </Pressable>
      </View>

      {/* Bottom Right: Mão do Jogador Humano em Leque */}
      <View style={styles.bottomRightWrapper}>
        <MaoJogador
          jogador={jogadorLocal}
          cartaSelecionada={cartaSelecionada}
          onSelecionarCarta={handleSelecionarCarta}
          onAnimacaoSaidaCompleta={handleAnimacaoSaidaCompleta}
          onDescartar={handlePassarTurno}
          desabilitado={jogadoresDesabilitado}
          hideStatus={true}
          onZoomCarta={(carta) => {
            console.log('[ZOOM DEBUG] ArenaCombate: setCartaZoom chamado para:', carta?.titulo || carta?.nome);
            setCartaZoom(carta);
          }}
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
          onCompleto={voadora.onCompleto}
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
      {/* Zoom de Carta — renderizado no nível raiz para cobrir toda a tela */}
      {console.log('[ZOOM DEBUG] Renderizando CartaZoomModal, cartaZoom:', cartaZoom?.titulo || cartaZoom?.nome || 'null')}
      <CartaZoomModal
        carta={cartaZoom}
        visivel={!!cartaZoom}
        onFechar={() => {
          console.log('[ZOOM DEBUG] Fechando modal...');
          setCartaZoom(null);
        }}
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
});

