import React, { useEffect } from 'react';
import { View, Text, StyleSheet } from 'react-native';
import Animated, {
  useSharedValue,
  useAnimatedStyle,
  withTiming,
  withRepeat,
  withSequence,
} from 'react-native-reanimated';

const CANTO_SIZE = 6;

export default function TurnoIndicador({ nomeJogadorAtivo, turnoAtual, totalTurnos, fluxoDirecao, isHumano }) {
  const pulseAnim = useSharedValue(1);

  const pulseStyle = useAnimatedStyle(() => ({
    transform: [{ scale: pulseAnim.value }],
  }));

  useEffect(() => {
    pulseAnim.value = withRepeat(
      withSequence(
        withTiming(1.05, { duration: 800 }),
        withTiming(1, { duration: 800 })
      ),
      -1,
      false
    );
  }, [nomeJogadorAtivo]);

  const fluxoLabel = fluxoDirecao === 1 ? '→ DIREITA' : '← ESQUERDA';
  const nomeFormatado = `TURNO DE ${nomeJogadorAtivo}`;

  return (
    <View style={styles.outerWrapper}>
      <View style={styles.correntesRow}>
        <View style={styles.corrente} />
        <View style={styles.corrente} />
      </View>

      <View style={styles.placaContainer}>
        <View style={[styles.vezBadge, { backgroundColor: isHumano ? '#2E7D32' : '#C62828' }]}>
          <Text style={styles.vezBadgeTexto}>{nomeFormatado}</Text>
        </View>

        <View style={styles.turnoContainer}>
          <Text style={styles.turnoLabel}>TURNO</Text>
          <Animated.View style={[styles.turnoNumero, pulseStyle]}>
            <Text style={styles.turnoNumeroTexto}>{turnoAtual}</Text>
          </Animated.View>
          <Text style={styles.turnoTotal}> / {totalTurnos}</Text>
        </View>

        <View style={styles.fluxoContainer}>
          <Text style={styles.fluxoTexto}>{fluxoLabel}</Text>
        </View>

        <View style={[styles.canto, styles.cantoTL]} />
        <View style={[styles.canto, styles.cantoTR]} />
        <View style={[styles.canto, styles.cantoBL]} />
        <View style={[styles.canto, styles.cantoBR]} />
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  outerWrapper: {
    alignItems: 'flex-start',
  },
  correntesRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    width: '70%',
    marginLeft: '15%',
    height: 6,
  },
  corrente: {
    width: 2,
    height: 8,
    backgroundColor: '#9E9E9E',
    borderWidth: 1,
    borderColor: '#424242',
    borderRadius: 2,
  },
  placaContainer: {
    backgroundColor: '#3E2723',
    borderWidth: 2,
    borderColor: '#7C4A27',
    borderRadius: 6,
    paddingVertical: 4,
    paddingHorizontal: 8,
    minWidth: 100,
    alignItems: 'center',
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.5,
    shadowRadius: 3,
    elevation: 6,
  },
  vezBadge: {
    borderRadius: 3,
    paddingHorizontal: 5,
    paddingVertical: 2,
    marginBottom: 3,
  },
  vezBadgeTexto: {
    fontSize: 7,
    color: '#FFF',
    fontWeight: 'bold',
    letterSpacing: 0.5,
  },
  turnoContainer: {
    flexDirection: 'row',
    alignItems: 'center',
  },
  turnoLabel: {
    fontSize: 7,
    color: '#BCAAA4',
    fontWeight: 'bold',
    letterSpacing: 0.5,
    marginRight: 4,
  },
  turnoNumero: {
    backgroundColor: '#FFD54F',
    borderRadius: 3,
    paddingHorizontal: 4,
    paddingVertical: 1,
  },
  turnoNumeroTexto: {
    fontSize: 10,
    color: '#3E2723',
    fontWeight: 'bold',
  },
  turnoTotal: {
    fontSize: 8,
    color: '#BCAAA4',
    marginLeft: 3,
  },
  fluxoContainer: {
    marginTop: 3,
    paddingVertical: 1,
    paddingHorizontal: 5,
    backgroundColor: 'rgba(255, 213, 79, 0.15)',
    borderRadius: 3,
    borderWidth: 1,
    borderColor: '#FFD54F',
  },
  fluxoTexto: {
    fontSize: 7,
    color: '#FFD54F',
    fontWeight: 'bold',
    letterSpacing: 0.5,
  },
  canto: {
    position: 'absolute',
    width: CANTO_SIZE,
    height: CANTO_SIZE,
    borderColor: '#FFD54F',
  },
  cantoTL: { top: -2, left: -2, borderTopWidth: 2, borderLeftWidth: 2 },
  cantoTR: { top: -2, right: -2, borderTopWidth: 2, borderRightWidth: 2 },
  cantoBL: { bottom: -2, left: -2, borderBottomWidth: 2, borderLeftWidth: 2 },
  cantoBR: { bottom: -2, right: -2, borderBottomWidth: 2, borderRightWidth: 2 },
});
