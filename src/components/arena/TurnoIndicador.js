import React, { useEffect, useRef } from 'react';
import { View, Text, StyleSheet, Animated } from 'react-native';

const CANTO_SIZE = 8;

export default function TurnoIndicador({ nomeJogadorAtivo, turnoAtual, totalTurnos }) {
  const pulseAnim = useRef(new Animated.Value(1)).current;

  useEffect(() => {
    Animated.loop(
      Animated.sequence([
        Animated.timing(pulseAnim, { toValue: 1.05, duration: 800, useNativeDriver: true }),
        Animated.timing(pulseAnim, { toValue: 1, duration: 800, useNativeDriver: true }),
      ])
    ).start();
  }, [nomeJogadorAtivo]);

  const nomeFormatado = nomeJogadorAtivo === 'JOGADOR_HUMANO' ? 'SEU TURNO' : 'TURNO DO OPONENTE';

  return (
    <View style={styles.outerWrapper}>
      <View style={styles.correntesRow}>
        <View style={styles.corrente} />
        <View style={styles.corrente} />
      </View>

      <View style={styles.placaContainer}>
        <View style={[styles.vezBadge, { backgroundColor: nomeJogadorAtivo === 'JOGADOR_HUMANO' ? '#2E7D32' : '#C62828' }]}>
          <Text style={styles.vezBadgeTexto}>{nomeFormatado}</Text>
        </View>

        <View style={styles.turnoContainer}>
          <Text style={styles.turnoLabel}>TURNO</Text>
          <Animated.View style={[styles.turnoNumero, { transform: [{ scale: pulseAnim }] }]}>
            <Text style={styles.turnoNumeroTexto}>{turnoAtual}</Text>
          </Animated.View>
          <Text style={styles.turnoTotal}>/ {totalTurnos}</Text>
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
    height: 10,
  },
  corrente: {
    width: 3,
    height: 12,
    backgroundColor: '#9E9E9E',
    borderWidth: 1,
    borderColor: '#424242',
    borderRadius: 2,
  },
  placaContainer: {
    backgroundColor: '#3E2723',
    borderWidth: 2.5,
    borderColor: '#7C4A27',
    borderRadius: 8,
    paddingVertical: 8,
    paddingHorizontal: 12,
    minWidth: 140,
    alignItems: 'center',
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 3 },
    shadowOpacity: 0.5,
    shadowRadius: 4,
    elevation: 6,
  },
  vezBadge: {
    borderRadius: 4,
    paddingHorizontal: 8,
    paddingVertical: 3,
    marginBottom: 6,
  },
  vezBadgeTexto: {
    fontSize: 10,
    color: '#FFF',
    fontWeight: 'bold',
    letterSpacing: 1,
  },
  turnoContainer: {
    flexDirection: 'row',
    alignItems: 'center',
  },
  turnoLabel: {
    fontSize: 10,
    color: '#BCAAA4',
    fontWeight: 'bold',
    letterSpacing: 1,
    marginRight: 6,
  },
  turnoNumero: {
    backgroundColor: '#FFD54F',
    borderRadius: 4,
    paddingHorizontal: 6,
    paddingVertical: 2,
  },
  turnoNumeroTexto: {
    fontSize: 14,
    color: '#3E2723',
    fontWeight: 'bold',
  },
  turnoTotal: {
    fontSize: 11,
    color: '#BCAAA4',
    marginLeft: 4,
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
