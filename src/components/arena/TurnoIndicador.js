import React from 'react';
import { View, Text, StyleSheet } from 'react-native';

const CANTO_SIZE = 8;

export default function TurnoIndicador({ nomeJogadorAtivo, turnoAtual, totalTurnos }) {
  return (
    <View style={styles.outerWrapper}>
      {/* Correntes de sustentação topo */}
      <View style={styles.correntesRow}>
        <View style={styles.corrente} />
        <View style={styles.corrente} />
      </View>

      {/* Placa de Madeira */}
      <View style={styles.placaContainer}>
        <Text style={styles.labelVez}>A VEZ: {nomeJogadorAtivo?.toUpperCase() || 'JOGADOR'}</Text>

        <View style={styles.setasRow}>
          <View style={styles.setaBox}>
            <Text style={styles.seta}>↪</Text>
          </View>
          <View style={styles.setaBox}>
            <Text style={styles.seta}>↩</Text>
          </View>
        </View>

        <Text style={styles.turnoTexto}>TURNO: {turnoAtual}/{totalTurnos}</Text>

        {/* Moldura de cantos dourados */}
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
    backgroundColor: '#4A2E1B',
    borderWidth: 2.5,
    borderColor: '#7C4A27',
    borderRadius: 6,
    paddingVertical: 5,
    paddingHorizontal: 10,
    minWidth: 135,
    alignItems: 'center',
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 3 },
    shadowOpacity: 0.5,
    shadowRadius: 4,
    elevation: 6,
  },
  labelVez: {
    fontSize: 11,
    color: '#FFF8E7',
    fontWeight: 'bold',
    letterSpacing: 1,
    marginBottom: 4,
    textShadowColor: '#000',
    textShadowOffset: { width: 1, height: 1 },
    textShadowRadius: 2,
  },
  setasRow: {
    flexDirection: 'row',
    alignItems: 'center',
    marginVertical: 4,
  },
  setaBox: {
    width: 28,
    height: 24,
    borderRadius: 5,
    backgroundColor: '#2E1A0F',
    borderWidth: 1,
    borderColor: '#D4AF6A',
    alignItems: 'center',
    justifyContent: 'center',
    marginHorizontal: 4,
  },
  seta: {
    fontSize: 14,
    color: '#FFD54F',
    fontWeight: 'bold',
  },
  turnoTexto: {
    fontSize: 12,
    color: '#FFECB3',
    fontWeight: 'bold',
    letterSpacing: 1,
    marginTop: 2,
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

