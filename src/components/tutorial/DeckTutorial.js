import React, { useEffect, useRef, useState } from 'react';
import {
  View,
  TouchableOpacity,
  StyleSheet,
  Image,
  ScrollView,
  Dimensions,
  Animated,
} from 'react-native';
import Text from '../Texto';
import CARTAS_TGA from '../../cards/cartasTGA';
import { temArte, artePorCarta, TRASEIRA } from '../../cards/arteCarta';
import { CartaFaceCompleta } from '../arena/CartaFace';
import { SpriteGuia } from './CenaLuz';
import CaixaLegenda from './CaixaLegenda';
import { FALANTE } from '../../tutorial/cenas';
import { soundManager } from '../../utils/sound';
import logLayout from '../../utils/logLayout';

const { width: SCREEN_WIDTH, height: SCREEN_HEIGHT } = Dimensions.get('window');

// Tamanho de projeto da CartaFaceCompleta (mesmo do zoom, 200x280): a face
// inteira e renderizada nesse tamanho e depois ESCALADA para caber no slot,
// assim nada e cortado (descricao, efeito, duracao...).
const FACE_W = 200;
const FACE_H = 280;

// Espaco vertical: tela - caixa(108) - sprite do Guia(88) - botao(~52) - margem(4).
const CARTA_H = Math.min(FACE_H, Math.max(150, SCREEN_HEIGHT - 252));
const CARTA_W = Math.min((CARTA_H * FACE_W) / FACE_H, SCREEN_WIDTH - 24);
const FACE_ESCALA = Math.min(CARTA_W / FACE_W, CARTA_H / FACE_H);

console.log('[TUT] deck dims', {
  tela: [SCREEN_WIDTH, SCREEN_HEIGHT],
  slot: [Math.round(CARTA_W), Math.round(CARTA_H)],
  escala: FACE_ESCALA,
});

// Particulas douradas que explodem a partir do deck no momento do estouro.
const NUM_PARTICULAS = 16;
const PARTICULAS_CONFIG = Array.from({ length: NUM_PARTICULAS }).map((_, i) => {
  const angulo = (i / NUM_PARTICULAS) * Math.PI * 2 + (Math.random() - 0.5) * 0.4;
  const distancia = 70 + Math.random() * 95;
  return {
    angulo,
    distancia,
    tamanho: 4 + Math.random() * 5,
    cor: Math.random() < 0.5 ? '#FFD54F' : '#FFF3C4',
    atraso: Math.random() * 70,
    duracao: 520 + Math.random() * 220,
  };
});

function Particula({ config, progresso }) {
  const dx = Math.cos(config.angulo) * config.distancia;
  const dy = Math.sin(config.angulo) * config.distancia;
  return (
    <Animated.View
      pointerEvents="none"
      style={{
        position: 'absolute',
        width: config.tamanho,
        height: config.tamanho,
        borderRadius: config.tamanho / 2,
        backgroundColor: config.cor,
        opacity: progresso.interpolate({
          inputRange: [0, 0.15, 1],
          outputRange: [0, 1, 0],
        }),
        transform: [
          { translateX: progresso.interpolate({ inputRange: [0, 1], outputRange: [0, dx] }) },
          { translateY: progresso.interpolate({ inputRange: [0, 1], outputRange: [0, dy] }) },
          { scale: progresso.interpolate({ inputRange: [0, 1], outputRange: [0.5, 1.3] }) },
        ],
      }}
    />
  );
}

// Overlay do "deck inicial" do tutorial (spec 19-20):
// 1) deck fechado -> jogador TOCA (nao avanca sozinho);
// 2) um pequeno "windup" (squash) prepara o golpe antes do estouro;
// 3) estouro: flash + onda de choque + particulas + tremor de tela;
// 4) revela as cartas REAIS do jogo, entrando em cascata com bounce;
// 5) botao CONTINUAR fecha o overlay e a cutscene segue.
// Layout: sprite do Guia ACIMA do deck, caixa de dialogo ABAIXO.
export default function DeckTutorial({ visivel, onConcluir, fala }) {
  const [revelado, setRevelado] = useState(false);
  const [abrindo, setAbrindo] = useState(false);
  const pulsacao = useRef(new Animated.Value(1)).current;
  const deckEsc = useRef(new Animated.Value(1)).current;
  const deckOp = useRef(new Animated.Value(1)).current;
  const flash = useRef(new Animated.Value(0)).current;
  const onda = useRef(new Animated.Value(0)).current;
  const shakeX = useRef(new Animated.Value(0)).current;
  const botaoAnim = useRef(new Animated.Value(0)).current;
  const cartasAnim = useRef(CARTAS_TGA.map(() => new Animated.Value(0))).current;
  const particulasAnim = useRef(PARTICULAS_CONFIG.map(() => new Animated.Value(0))).current;

  useEffect(() => {
    if (!visivel) {
      setRevelado(false);
      setAbrindo(false);
      deckEsc.setValue(1);
      deckOp.setValue(1);
      flash.setValue(0);
      onda.setValue(0);
      shakeX.setValue(0);
      botaoAnim.setValue(0);
      cartasAnim.forEach((v) => v.setValue(0));
      particulasAnim.forEach((v) => v.setValue(0));
    }
  }, [visivel, deckEsc, deckOp, flash, onda, shakeX, botaoAnim, cartasAnim, particulasAnim]);

  useEffect(() => {
    if (!visivel || revelado) return undefined;
    const loop = Animated.loop(
      Animated.sequence([
        Animated.timing(pulsacao, { toValue: 0.35, duration: 650, useNativeDriver: true }),
        Animated.timing(pulsacao, { toValue: 1, duration: 650, useNativeDriver: true }),
      ])
    );
    loop.start();
    return () => {
      loop.stop();
      pulsacao.stopAnimation();
    };
  }, [visivel, revelado, pulsacao]);

  // Toque no deck: pacote "estoura" (deck cresce e some + flash + onda de
  // choque + particulas + tremor de tela). A entrada em si (o windup) ja
  // roda no onPress, ANTES de setAbrindo(true) - ver handleAbrir abaixo.
  useEffect(() => {
    if (!abrindo) return undefined;

    soundManager.playVictory();

    const estouro = Animated.parallel([
      Animated.timing(deckEsc, { toValue: 1.32, duration: 200, useNativeDriver: true }),
      Animated.timing(deckOp, { toValue: 0, duration: 180, useNativeDriver: true }),
    ]);
    estouro.start(({ finished }) => {
      if (finished) {
        setRevelado(true);
        setAbrindo(false);
        soundManager.playCardDraw();
      }
    });

    // Flash solido (nucleo) + onda de choque (anel), com duracoes levemente
    // diferentes para dar sensacao de profundidade/camadas.
    Animated.timing(flash, { toValue: 1, duration: 420, useNativeDriver: true }).start();
    Animated.timing(onda, { toValue: 1, duration: 700, useNativeDriver: true }).start();

    // Tremor rapido de tela no instante do impacto.
    Animated.sequence([
      Animated.timing(shakeX, { toValue: 6, duration: 35, useNativeDriver: true }),
      Animated.timing(shakeX, { toValue: -6, duration: 35, useNativeDriver: true }),
      Animated.timing(shakeX, { toValue: 3, duration: 35, useNativeDriver: true }),
      Animated.timing(shakeX, { toValue: 0, duration: 35, useNativeDriver: true }),
    ]).start();

    // Particulas douradas explodindo a partir do deck.
    particulasAnim.forEach((v, i) => {
      v.setValue(0);
      Animated.timing(v, {
        toValue: 1,
        duration: PARTICULAS_CONFIG[i].duracao,
        delay: PARTICULAS_CONFIG[i].atraso,
        useNativeDriver: true,
      }).start();
    });

    return () => estouro.stop();
  }, [abrindo, deckEsc, deckOp, flash, onda, shakeX, particulasAnim]);

  // Cartas sao "distribuidas" em cascata (com leve overshoot/bounce) +
  // botao entra depois da ultima.
  useEffect(() => {
    if (!revelado) return undefined;
    const entrada = cartasAnim.map((v, i) =>
      Animated.spring(v, {
        toValue: 1,
        friction: 4.5,
        tension: 85,
        delay: i * 30,
        useNativeDriver: true,
      })
    );
    const botao = Animated.timing(botaoAnim, {
      toValue: 1,
      duration: 320,
      delay: cartasAnim.length * 30 + 120,
      useNativeDriver: true,
    });
    const tudo = Animated.parallel([...entrada, botao]);
    tudo.start();
    return () => tudo.stop();
  }, [revelado, cartasAnim, botaoAnim]);

  if (!visivel) return null;

  // Windup: um pequeno "squash" (encolhe e estica) antes do deck estourar
  // de verdade - prepara o golpe, igual abertura de pacote em jogo de
  // verdade, em vez do deck ir direto pro estouro.
  const handleAbrir = () => {
    if (abrindo) return;
    soundManager.playFlip();
    Animated.sequence([
      Animated.timing(deckEsc, { toValue: 0.9, duration: 90, useNativeDriver: true }),
      Animated.timing(deckEsc, { toValue: 1.1, duration: 110, useNativeDriver: true }),
    ]).start(() => {
      setAbrindo(true);
    });
  };

  const estiloCarta = (i) => {
    const v = cartasAnim[i];
    const giro = i % 2 === 0 ? '-14deg' : '14deg';
    return {
      opacity: v,
      transform: [
        { translateY: v.interpolate({ inputRange: [0, 1], outputRange: [64, 0] }) },
        { scale: v.interpolate({ inputRange: [0, 0.7, 1], outputRange: [0.4, 1.08, 1] }) },
        { rotate: v.interpolate({ inputRange: [0, 1], outputRange: [giro, '0deg'] }) },
      ],
    };
  };

  return (
    <Animated.View
      style={[styles.overlay, { transform: [{ translateX: shakeX }] }]}
      onLayout={logLayout('deck overlay')}
    >
      <SpriteGuia tamanho={34} falando={!!fala && fala.speaker === FALANTE.GUIA} />

      {!revelado ? (
        <Animated.View
          style={[
            styles.centroDeck,
            { opacity: deckOp, transform: [{ scale: deckEsc }] },
          ]}
        >
          <TouchableOpacity
            style={styles.deckBack}
            activeOpacity={0.85}
            disabled={abrindo}
            onPress={handleAbrir}
            accessibilityLabel="Abrir deck inicial"
          >
            <Image source={TRASEIRA} style={styles.deckBackImg} resizeMode="cover" />
          </TouchableOpacity>
          <Animated.View style={[styles.dicaDeckWrap, { opacity: pulsacao }]}>
            <Text style={styles.dicaDeck}>TOQUE NO DECK PARA ABRIR</Text>
          </Animated.View>

          {/* Particulas (ficam ancoradas no mesmo centro do deck) */}
          <View pointerEvents="none" style={styles.particulasWrap}>
            {PARTICULAS_CONFIG.map((config, i) => (
              <Particula key={i} config={config} progresso={particulasAnim[i]} />
            ))}
          </View>
        </Animated.View>
      ) : (
        <>
          <ScrollView
            horizontal
            showsHorizontalScrollIndicator={false}
            contentContainerStyle={styles.listaCartas}
            style={styles.listaScroll}
            onLayout={logLayout('deck lista')}
          >
            {CARTAS_TGA.map((carta, i) => (
              <Animated.View key={carta.id} style={[styles.cartaSlot, estiloCarta(i)]}>
                <View style={styles.faceZoom}>
                  {temArte(carta) ? (
                    <View style={styles.arteWrap}>
                      <Image
                        source={artePorCarta(carta)}
                        style={styles.arte}
                        resizeMode="contain"
                      />
                      <Text style={styles.arteTitulo} numberOfLines={2}>
                        {carta.titulo}
                      </Text>
                    </View>
                  ) : (
                    <CartaFaceCompleta carta={carta} style={styles.face} />
                  )}
                </View>
              </Animated.View>
            ))}
          </ScrollView>

          <Animated.View
            onLayout={logLayout('deck botao')}
            style={{
              opacity: botaoAnim,
              transform: [
                { translateY: botaoAnim.interpolate({ inputRange: [0, 1], outputRange: [24, 0] }) },
              ],
            }}
          >
            <TouchableOpacity style={styles.botaoContinuar} activeOpacity={0.8} onPress={onConcluir}>
              <Text style={styles.botaoContinuarTexto}>CONTINUAR ▶</Text>
            </TouchableOpacity>
          </Animated.View>
        </>
      )}

      {/* Onda de choque: anel que se expande e desvanece, mais lento e maior
          que o flash solido - da sensacao de camadas/profundidade no estouro. */}
      <Animated.View
        pointerEvents="none"
        style={[
          styles.ondaWrap,
          {
            opacity: onda.interpolate({
              inputRange: [0, 0.4, 1],
              outputRange: [0.9, 0.35, 0],
            }),
            transform: [
              { scale: onda.interpolate({ inputRange: [0, 1], outputRange: [0.3, 9] }) },
            ],
          },
        ]}
      >
        <View style={styles.ondaAnel} />
      </Animated.View>

      {/* Flash do estouro do pacote: luz branca dourada que expande e some. */}
      <Animated.View
        pointerEvents="none"
        style={[
          styles.flashWrap,
          {
            opacity: flash.interpolate({
              inputRange: [0, 0.45, 1],
              outputRange: [0, 1, 0],
            }),
            transform: [
              { scale: flash.interpolate({ inputRange: [0, 1], outputRange: [0.35, 7] }) },
            ],
          },
        ]}
      >
        <View style={styles.flashNucleo} />
      </Animated.View>

      {fala && (
        <CaixaLegenda
          speaker={fala.speaker}
          texto={fala.text}
          mostrarDica={false}
          onToque={() => {}}
        />
      )}
    </Animated.View>
  );
}

const styles = StyleSheet.create({
  overlay: {
    ...StyleSheet.absoluteFillObject,
    backgroundColor: 'rgba(3, 3, 8, 0.96)',
    alignItems: 'center',
    justifyContent: 'center',
    paddingHorizontal: 12,
    // Reserva o espaco da caixa de legenda (absoluta, embaixo).
    paddingBottom: 108,
    zIndex: 50,
  },
  centroDeck: {
    alignItems: 'center',
    justifyContent: 'center',
    marginTop: 4,
  },
  deckBack: {
    width: CARTA_W,
    height: CARTA_H,
    borderRadius: 8,
    borderWidth: 2,
    borderColor: '#FFD54F',
    overflow: 'hidden',
    shadowColor: '#FFD54F',
    shadowOffset: { width: 0, height: 0 },
    shadowOpacity: 0.6,
    shadowRadius: 14,
    elevation: 10,
  },
  deckBackImg: {
    width: '100%',
    height: '100%',
  },
  dicaDeckWrap: {
    marginTop: 10,
  },
  dicaDeck: {
    color: '#FFD54F',
    fontSize: 11,
    letterSpacing: 2,
    textAlign: 'center',
  },
  particulasWrap: {
    position: 'absolute',
    top: '50%',
    left: '50%',
    width: 0,
    height: 0,
    alignItems: 'center',
    justifyContent: 'center',
  },
  ondaWrap: {
    ...StyleSheet.absoluteFillObject,
    alignItems: 'center',
    justifyContent: 'center',
    zIndex: 54,
  },
  ondaAnel: {
    width: 110,
    height: 110,
    borderRadius: 55,
    borderWidth: 3,
    borderColor: '#FFD54F',
    backgroundColor: 'transparent',
  },
  flashWrap: {
    ...StyleSheet.absoluteFillObject,
    alignItems: 'center',
    justifyContent: 'center',
    zIndex: 55,
  },
  flashNucleo: {
    width: 96,
    height: 96,
    borderRadius: 48,
    backgroundColor: '#FFFFFF',
    shadowColor: '#FFD54F',
    shadowOffset: { width: 0, height: 0 },
    shadowOpacity: 1,
    shadowRadius: 30,
    elevation: 20,
  },
  listaScroll: {
    // Trava a fileira: o ScrollView do RN tem flexShrink:1 por padrao e
    // encolhia as cartas quando a coluna transbordava.
    height: CARTA_H,
    flexGrow: 0,
    flexShrink: 0,
    width: '100%',
  },
  listaCartas: {
    paddingHorizontal: 8,
    gap: 10,
    alignItems: 'center',
  },
  cartaSlot: {
    width: CARTA_W,
    height: CARTA_H,
    borderRadius: 6,
    borderWidth: 1,
    borderColor: '#3A3A52',
    backgroundColor: '#141A2E',
    overflow: 'hidden',
    alignItems: 'center',
    justifyContent: 'center',
  },
  // Renderiza a face no tamanho de projeto (200x280) e escala para o slot.
  faceZoom: {
    width: FACE_W,
    height: FACE_H,
    transform: [{ scale: FACE_ESCALA }],
  },
  face: {
    flex: 1,
    borderRadius: 5,
  },
  arteWrap: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
    padding: 4,
  },
  arte: {
    width: '100%',
    height: '78%',
  },
  arteTitulo: {
    color: '#FFF8E7',
    fontSize: 9,
    textAlign: 'center',
    marginTop: 2,
  },
  botaoContinuar: {
    marginTop: 10,
    paddingHorizontal: 26,
    paddingVertical: 11,
    backgroundColor: 'rgba(10,10,26,0.9)',
    borderWidth: 2,
    borderColor: '#FFD54F',
    borderRadius: 10,
  },
  botaoContinuarTexto: {
    color: '#FFD54F',
    fontSize: 12,
    letterSpacing: 2,
  },
});