import React from 'react';
import { View, Text, StyleSheet } from 'react-native';
import CartaArena from './CartaArena';

export default function RegiaoOponente({ jogador, maoOculta }) {
  if (!jogador) return null;

  return (
    <View style={styles.container}>
      <View style={styles.infoBar}>
        <View style={styles.avatarContainer}>
          <Text style={styles.avatarEmoji}>🤖</Text>
        </View>
        <View style={styles.infoText}>
          <Text style={styles.nome}>{jogador.nome}</Text>
          <Text style={[styles.saldo, jogador.saldo > 10 ? styles.saldoPositivo : jogador.saldo > 5 ? styles.saldoNeutro : styles.saldoNegativo]}>
            R$ {jogador.saldo}
          </Text>
        </View>
        {jogador.falido && (
          <View style={styles.badgeFalido}>
            <Text style={styles.badgeFalidoTexto}>FALIDO</Text>
          </View>
        )}
        {jogador.protegido && (
          <View style={styles.badgeProtegido}>
            <Text style={styles.badgeProtegidoTexto}>🛡</Text>
          </View>
        )}
      </View>

      <View style={styles.maoContainer}>
        <Text style={styles.maoLabel}>MAO ({jogador.mao.length})</Text>
        <View style={styles.mao}>
          {jogador.mao.map((carta, idx) => (
            <CartaArena key={carta.uid || idx} carta={carta} oculta={maoOculta} desabilitada />
          ))}
        </View>
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: 'rgba(30, 30, 50, 0.6)',
    borderBottomWidth: 1,
    borderBottomColor: '#333',
    paddingVertical: 4,
  },
  infoBar: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: 6,
    paddingVertical: 2,
  },
  avatarContainer: {
    width: 22,
    height: 22,
    borderRadius: 11,
    backgroundColor: '#444',
    alignItems: 'center',
    justifyContent: 'center',
    marginRight: 5,
  },
  avatarEmoji: {
    fontSize: 11,
  },
  infoText: {
    flex: 1,
  },
  nome: {
    fontSize: 8,
    color: '#CCC',
    fontWeight: 'bold',
  },
  saldo: {
    fontSize: 9,
    fontWeight: 'bold',
  },
  saldoPositivo: {
    color: '#66BB6A',
  },
  saldoNeutro: {
    color: '#FFA726',
  },
  saldoNegativo: {
    color: '#EF5350',
  },
  badgeFalido: {
    backgroundColor: '#C62828',
    borderRadius: 4,
    paddingHorizontal: 6,
    paddingVertical: 2,
  },
  badgeFalidoTexto: {
    fontSize: 9,
    color: '#FFF',
    fontWeight: 'bold',
  },
  badgeProtegido: {
    backgroundColor: '#2E7D32',
    borderRadius: 4,
    paddingHorizontal: 6,
    paddingVertical: 2,
    marginLeft: 4,
  },
  badgeProtegidoTexto: {
    fontSize: 8,
  },
  maoContainer: {
    paddingHorizontal: 8,
    paddingTop: 2,
  },
  maoLabel: {
    fontSize: 9,
    color: '#888',
    marginBottom: 2,
  },
  mao: {
    flexDirection: 'row',
    flexWrap: 'nowrap',
    justifyContent: 'center',
  },
});
