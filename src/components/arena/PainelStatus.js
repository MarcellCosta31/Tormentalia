import React from 'react';
import { View, Text, StyleSheet } from 'react-native';

const CANTO_SIZE = 8;

export default function PainelStatus({ nome, saldo, corDestaque = '#D4AF6A' }) {
  const corSaldo = saldo > 10 ? '#66BB6A' : saldo > 5 ? '#FFD54F' : '#EF5350';

  return (
    <View style={styles.container}>
      <View style={[styles.avatarBox, { borderColor: corDestaque }]}>
        <Text style={styles.avatarEmoji}>👨‍💼</Text>
      </View>

      <View style={styles.infoColuna}>
        <Text style={styles.nome} numberOfLines={1}>{nome?.toUpperCase() || 'JOGADOR'}</Text>
        <View style={styles.saldoRow}>
          <Text style={styles.saldoLabel}>SALDO:</Text>
          <Text style={[styles.saldoValor, { color: corSaldo }]}>R$ {saldo}</Text>
          <Text style={styles.moeda}>🪙</Text>
        </View>
      </View>

      {/* cantos decorativos pixel art */}
      <View style={[styles.canto, styles.cantoTL]} />
      <View style={[styles.canto, styles.cantoTR]} />
      <View style={[styles.canto, styles.cantoBL]} />
      <View style={[styles.canto, styles.cantoBR]} />
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: '#0F1322',
    borderWidth: 2,
    borderColor: '#7A5C29',
    borderRadius: 6,
    paddingVertical: 5,
    paddingHorizontal: 8,
    minWidth: 180,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 3 },
    shadowOpacity: 0.6,
    shadowRadius: 4,
    elevation: 5,
  },
  avatarBox: {
    width: 38,
    height: 38,
    borderRadius: 4,
    borderWidth: 2,
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: '#1C2238',
    marginRight: 8,
  },
  avatarEmoji: {
    fontSize: 20,
  },
  infoColuna: {
    flex: 1,
    justifyContent: 'center',
  },
  nome: {
    fontSize: 11,
    color: '#F0F3FF',
    fontWeight: 'bold',
    letterSpacing: 0.5,
    marginBottom: 2,
  },
  saldoRow: {
    flexDirection: 'row',
    alignItems: 'center',
  },
  saldoLabel: {
    fontSize: 10,
    color: '#AAB0D0',
    fontWeight: 'bold',
    marginRight: 4,
  },
  saldoValor: {
    fontSize: 12,
    fontWeight: 'bold',
    marginRight: 3,
  },
  moeda: {
    fontSize: 10,
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

