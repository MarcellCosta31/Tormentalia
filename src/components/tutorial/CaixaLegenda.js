import React, { useEffect, useRef } from 'react';
import { View, StyleSheet, TouchableOpacity, Animated } from 'react-native';
import Text from '../Texto';
import logLayout from '../../utils/logLayout';

// Caixa de legenda inferior (spec 6): fundo escuro translucido, borda discreta,
// texto branco, nome do personagem opcional. Sem balao de fala.
// O TOQUE NELA e o unico que passa dialogo/cena (onToque do controller).
export default function CaixaLegenda({ speaker, texto, mostrarDica, onToque }) {
  const piscada = useRef(new Animated.Value(1)).current;

  useEffect(() => {
    if (!mostrarDica) {
      piscada.setValue(1);
      return undefined;
    }
    const loop = Animated.loop(
      Animated.sequence([
        Animated.timing(piscada, { toValue: 0.3, duration: 700, useNativeDriver: true }),
        Animated.timing(piscada, { toValue: 1, duration: 700, useNativeDriver: true }),
      ])
    );
    loop.start();
    return () => {
      loop.stop();
      piscada.stopAnimation();
    };
  }, [mostrarDica, piscada]);

  return (
    <View style={styles.container} onLayout={logLayout('legenda')}>
      <TouchableOpacity
        activeOpacity={0.85}
        onPress={onToque}
        accessibilityRole="button"
        accessibilityLabel="Continuar dialogo"
      >
        <View style={styles.caixa}>
          {!!speaker && <Text style={styles.speaker}>{speaker}</Text>}
          <Text style={styles.texto}>{texto}</Text>
          {mostrarDica && (
            <Animated.View style={[styles.dicaWrap, { opacity: piscada }]}>
              <Text style={styles.dica}>▼ TOQUE PARA CONTINUAR</Text>
            </Animated.View>
          )}
        </View>
      </TouchableOpacity>
    </View>
  );
}

// Indicador isolado, usado quando o quadro comeca sem nenhuma fala em tela
// (falaIdx === -1): so avisa que um toque comeca a legenda.
export function DicaAvulsa({ onToque }) {
  const piscada = useRef(new Animated.Value(1)).current;

  useEffect(() => {
    const loop = Animated.loop(
      Animated.sequence([
        Animated.timing(piscada, { toValue: 0.3, duration: 700, useNativeDriver: true }),
        Animated.timing(piscada, { toValue: 1, duration: 700, useNativeDriver: true }),
      ])
    );
    loop.start();
    return () => {
      loop.stop();
      piscada.stopAnimation();
    };
  }, [piscada]);

  return (
    <View style={styles.container} onLayout={logLayout('dica')}>
      <TouchableOpacity
        activeOpacity={0.85}
        onPress={onToque}
        accessibilityRole="button"
        accessibilityLabel="Continuar"
      >
        <Animated.View style={[styles.caixa, styles.caixaVazia, { opacity: piscada }]}>
          <Text style={styles.dica}>TOQUE PARA CONTINUAR</Text>
        </Animated.View>
      </TouchableOpacity>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    position: 'absolute',
    left: 0,
    right: 0,
    bottom: 0,
    paddingHorizontal: 12,
    paddingBottom: 18,
  },
  caixa: {
    backgroundColor: 'rgba(4, 4, 10, 0.82)',
    borderWidth: 1,
    borderColor: 'rgba(255, 255, 255, 0.16)',
    borderRadius: 8,
    paddingHorizontal: 14,
    paddingTop: 10,
    paddingBottom: 8,
  },
  caixaVazia: {
    alignItems: 'center',
    paddingVertical: 12,
  },
  speaker: {
    color: '#FFD54F',
    fontSize: 11,
    letterSpacing: 2,
    marginBottom: 5,
  },
  texto: {
    color: '#FFFFFF',
    fontSize: 15,
    lineHeight: 21,
  },
  dicaWrap: {
    alignItems: 'flex-end',
    marginTop: 6,
  },
  dica: {
    color: '#B9B9CF',
    fontSize: 9,
    letterSpacing: 2,
  },
});
