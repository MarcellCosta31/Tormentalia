import React, { useEffect, useMemo, useRef } from 'react';
import { View, Image, StyleSheet, Animated } from 'react-native';
import Text from '../Texto';
import CARTAS_TGA, { TIPO_CARTA } from '../../cards/cartasTGA';
import { temArte, artePorCarta } from '../../cards/arteCarta';
import { CartaFaceCompleta } from '../arena/CartaFace';

const ROTULO_TIPO = {
  [TIPO_CARTA.ACAO]: 'CARTA DE ACAO',
  [TIPO_CARTA.EFEITO]: 'CARTA DE MEDIDA / EFEITO',
  [TIPO_CARTA.PROTECAO]: 'CARTA DE PROTECAO',
  [TIPO_CARTA.CORINGA]: 'CARTA CORINGA',
};

function exemploDe(tipo) {
  return CARTAS_TGA.find((c) => c.tipo === tipo) || null;
}

// Destaca uma carta REAL do jogo enquanto o Guia explica cada tipo (spec 22).
// tipo: null = nada em destaque.
export default function DestaqueTipos({ tipo }) {
  const entrada = useRef(new Animated.Value(1)).current;
  const carta = useMemo(() => (tipo ? exemploDe(tipo) : null), [tipo]);

  useEffect(() => {
    entrada.setValue(0.4);
    Animated.timing(entrada, { toValue: 1, duration: 250, useNativeDriver: true }).start();
    return () => entrada.stopAnimation();
  }, [tipo, entrada]);

  if (!carta) return null;

  return (
    <Animated.View style={[styles.wrap, { opacity: entrada }]} pointerEvents="none">
      <Text style={styles.rotulo}>{ROTULO_TIPO[tipo] || tipo}</Text>
      <View style={styles.cartaSlot}>
        {temArte(carta) ? (
          <View style={styles.arteWrap}>
            <Image source={artePorCarta(carta)} style={styles.arte} resizeMode="contain" />
            <Text style={styles.arteTitulo} numberOfLines={2}>
              {carta.titulo}
            </Text>
          </View>
        ) : (
          <CartaFaceCompleta carta={carta} style={styles.face} />
        )}
      </View>
    </Animated.View>
  );
}

const styles = StyleSheet.create({
  wrap: {
    alignItems: 'center',
    marginBottom: 8,
  },
  rotulo: {
    color: '#FFD54F',
    fontSize: 10,
    letterSpacing: 2,
    marginBottom: 5,
  },
  cartaSlot: {
    width: 132,
    height: 176,
    borderRadius: 6,
    borderWidth: 1,
    borderColor: '#FFD54F',
    backgroundColor: '#141A2E',
    overflow: 'hidden',
    shadowColor: '#FFD54F',
    shadowOffset: { width: 0, height: 0 },
    shadowOpacity: 0.55,
    shadowRadius: 10,
    elevation: 8,
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
    height: '80%',
  },
  arteTitulo: {
    color: '#FFF8E7',
    fontSize: 9,
    textAlign: 'center',
    marginTop: 2,
  },
});
