import React, { useCallback, useMemo, useRef, useState } from 'react';
import {
  View,
  TouchableOpacity,
  StyleSheet,
  ImageBackground,
  Image,
  Dimensions,
  Animated,
} from 'react-native';
import Text from '../components/Texto';

const { width: SCREEN_WIDTH, height: SCREEN_HEIGHT } = Dimensions.get('window');

const ADAM_RATIO = 169 / 262;
const LOCK_RATIO = 112 / 184;
const VOLTAR_RATIO = 44 / 47;

// Altura manda (mesma proporção da arte de referência), com teto de largura
// pra não estourar em telas estreitas.
const ADAM_H = Math.min(SCREEN_HEIGHT * 0.5, SCREEN_WIDTH * 0.5);
const ADAM_W = ADAM_H * ADAM_RATIO;
const LOCK_H = Math.min(SCREEN_HEIGHT * 0.34, SCREEN_WIDTH * 0.34);
const LOCK_W = LOCK_H * LOCK_RATIO;
const VOLTAR = SCREEN_HEIGHT * 0.1;

// Espaço reservado por card no carrossel (o card do centro ocupa a slot inteira).
const ESCALA_CENTRO = 1.18;
const ESCALA_LATERAL = 0.85;
const SLOT = ADAM_W * ESCALA_CENTRO + SCREEN_WIDTH * 0.03;
const PADDING_LATERAL = (SCREEN_WIDTH - SLOT) / 2;
const ALTURA_CAROUSEL = ADAM_H * ESCALA_CENTRO + SCREEN_HEIGHT * 0.03;
const ALTURA_BOTAO = SCREEN_HEIGHT * 0.065;
const QTD_BLOQUEADOS = 10;

const OPONENTES = [
  {
    id: 'adam',
    nome: 'ADAM SMITH',
    imagem: require('../assets/sprites/um_jogador/adam_smith.jpg'),
    bloqueado: false,
    largura: ADAM_W,
    altura: ADAM_H,
  },
  ...Array.from({ length: QTD_BLOQUEADOS }).map((_, i) => ({
    id: `bloqueado_${i}`,
    nome: 'BLOQUEADO',
    imagem: require('../assets/sprites/um_jogador/perso_bloqueado.png'),
    bloqueado: true,
    largura: LOCK_W,
    altura: LOCK_H,
  })),
];

const Carta = React.memo(function Carta({ oponente, index, scrollX, selecionada, onSelecionar }) {
  const escala = useMemo(
    () =>
      scrollX.interpolate({
        inputRange: [(index - 1) * SLOT, index * SLOT, (index + 1) * SLOT],
        outputRange: [ESCALA_LATERAL, ESCALA_CENTRO, ESCALA_LATERAL],
        extrapolate: 'clamp',
      }),
    [scrollX, index]
  );

  return (
    <TouchableOpacity
      style={[styles.item, { width: SLOT }, selecionada && styles.itemSelecionada]}
      onPress={() => onSelecionar(index)}
      disabled={oponente.bloqueado}
      activeOpacity={oponente.bloqueado ? 1 : 0.9}
      accessibilityLabel={`Oponente ${oponente.nome}`}
    >
      <Animated.View
        style={[
          styles.cartaWrap,
          { width: oponente.largura, height: oponente.altura },
          { transform: [{ scale: escala }] },
          selecionada && styles.cartaWrapSelecionada,
        ]}
      >
        <Image source={oponente.imagem} style={styles.cartaImg} resizeMode="contain" />
      </Animated.View>
    </TouchableOpacity>
  );
});

export default function TelaUmJogador({ onVoltar, onIniciar }) {
  const scrollRef = useRef(null);
  const scrollX = useRef(new Animated.Value(0)).current;
  const [indice, setIndice] = useState(0);

  const aoRolar = useMemo(
    () =>
      Animated.event(
        [{ nativeEvent: { contentOffset: { x: scrollX } } }],
        {
          useNativeDriver: true,
          listener: (e) => {
            const i = Math.round(e.nativeEvent.contentOffset.x / SLOT);
            const limitado = Math.max(0, Math.min(OPONENTES.length - 1, i));
            setIndice((prev) => (prev === limitado ? prev : limitado));
          },
        }
      ),
    [scrollX]
  );

  const irPara = useCallback((i) => {
    const limitado = Math.max(0, Math.min(OPONENTES.length - 1, i));
    scrollRef.current?.scrollTo({ x: limitado * SLOT, animated: true });
    setIndice(limitado);
  }, []);

  const oponenteAtual = OPONENTES[indice];

  return (
    <ImageBackground
      source={require('../assets/sprites/um_jogador/background.jpg')}
      style={styles.background}
      resizeMode="cover"
    >
      <View style={styles.topBar}>
        <TouchableOpacity
          style={[styles.botaoVoltar, { width: VOLTAR, height: VOLTAR * VOLTAR_RATIO }]}
          onPress={onVoltar}
          activeOpacity={0.7}
        >
          <Image
            source={require('../assets/sprites/um_jogador/voltar_btn.png')}
            style={styles.botaoVoltarImg}
            resizeMode="cover"
          />
        </TouchableOpacity>
        <Text style={styles.titulo}>MODO UM JOGADOR</Text>

        <View style={styles.linhaContainer}>
          <View style={styles.diamante} />
          <View style={styles.linha} />
        </View>
      </View>

      <View style={styles.areaCards}>
        <Animated.ScrollView
          ref={scrollRef}
          horizontal
          showsHorizontalScrollIndicator={false}
          snapToInterval={SLOT}
          decelerationRate="fast"
          disableIntervalMomentum
          scrollEventThrottle={16}
          onScroll={aoRolar}
          contentContainerStyle={styles.scrollContent}
          style={{ height: ALTURA_CAROUSEL }}
        >
          {OPONENTES.map((oponente, i) => (
            <Carta
              key={oponente.id}
              oponente={oponente}
              index={i}
              scrollX={scrollX}
              selecionada={i === indice}
              onSelecionar={irPara}
            />
          ))}
        </Animated.ScrollView>
      </View>

      <View style={styles.areaBotao}>
        {oponenteAtual.bloqueado ? (
          <View style={[styles.botaoDesafiar, styles.botaoDesafiarBloqueado]}>
            <Text style={[styles.botaoDesafiarTexto, styles.botaoDesafiarTextoBloqueado]}>
              BLOQUEADO
            </Text>
          </View>
        ) : (
          <TouchableOpacity
            style={styles.botaoDesafiar}
            onPress={onIniciar}
            activeOpacity={0.8}
            accessibilityLabel={`Desafiar ${oponenteAtual.nome}`}
          >
            <Text style={styles.botaoDesafiarTexto}>DESAFIAR</Text>
          </TouchableOpacity>
        )}
      </View>
    </ImageBackground>
  );
}

const styles = StyleSheet.create({
  background: {
    flex: 1,
    width: '100%',
    height: '100%',
    backgroundColor: '#0A0705',
  },
  topBar: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingTop: SCREEN_HEIGHT * 0.045,
    paddingHorizontal: SCREEN_WIDTH * 0.03,
  },
  botaoVoltar: {
    justifyContent: 'center',
    alignItems: 'center',
  },
  botaoVoltarImg: {
    width: '100%',
    height: '100%',
  },
  titulo: {
    color: '#F7D488',
    fontSize: SCREEN_HEIGHT * 0.05,
    fontWeight: '800',
    letterSpacing: 4,
    marginHorizontal: SCREEN_WIDTH * 0.018,
    textShadowColor: '#000',
    textShadowOffset: { width: 2, height: 2 },
    textShadowRadius: 4,
  },
  linhaContainer: {
    flex: 1,
    flexDirection: 'row',
    alignItems: 'center',
    marginRight: SCREEN_WIDTH * 0.02,
  },
  diamante: {
    width: 7,
    height: 7,
    backgroundColor: '#F7D488',
    borderRadius: 1,
    transform: [{ rotate: '45deg' }],
  },
  linha: {
    flex: 1,
    height: 1.5,
    marginHorizontal: 8,
    borderRadius: 1,
    backgroundColor: 'rgba(247, 212, 136, 0.55)',
  },
  areaCards: {
    flex: 1,
    justifyContent: 'center',
    paddingBottom: SCREEN_HEIGHT * 0.02,
  },
  scrollContent: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: PADDING_LATERAL,
  },
  item: {
    height: '100%',
    justifyContent: 'center',
    alignItems: 'center',
  },
  itemSelecionada: {
    zIndex: 2,
  },
  cartaWrap: {
    justifyContent: 'center',
    alignItems: 'center',
    borderRadius: 12,
  },
  cartaWrapSelecionada: {
    shadowColor: '#FFD54F',
    shadowOffset: { width: 0, height: 0 },
    shadowOpacity: 0.75,
    shadowRadius: 18,
    elevation: 12,
  },
  cartaImg: {
    width: '100%',
    height: '100%',
  },
  areaBotao: {
    height: ALTURA_BOTAO,
    marginVertical: SCREEN_HEIGHT * 0.02,
    marginHorizontal: SCREEN_WIDTH * 0.2,
    justifyContent: 'center',
    alignItems: 'center',
  },
  botaoDesafiar: {
    width: '100%',
    height: '100%',
    backgroundColor: 'rgba(10,10,26,0.9)',
    borderWidth: 2,
    borderColor: '#FFD54F',
    borderRadius: 12,
    justifyContent: 'center',
    alignItems: 'center',
    shadowColor: '#FFD54F',
    shadowOffset: { width: 0, height: 0 },
    shadowOpacity: 0.5,
    shadowRadius: 8,
    elevation: 8,
  },
  botaoDesafiarTexto: {
    color: '#FFD54F',
    fontSize: 13,
    fontWeight: '800',
    letterSpacing: 3,
  },
  botaoDesafiarBloqueado: {
    borderColor: '#6B6B6B',
    shadowColor: '#000',
    opacity: 0.85,
  },
  botaoDesafiarTextoBloqueado: {
    color: '#9B9B9B',
  },
});
