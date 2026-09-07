import React from 'react';
import { View, Text, StyleSheet } from 'react-native';

export default function InfoJogador({ jogador, isTopo }) {
  if (!jogador) return null;

  const corSaldo = jogador.saldo > 10 ? '#66BB6A' : jogador.saldo > 5 ? '#FFA726' : '#EF5350';

  return (
    <View style={[styles.container, isTopo ? styles.containerTopo : styles.containerBaixo]}>
      <View style={styles.avatar}>
        <Text style={styles.avatarEmoji}>
          {jogador.isIA ? '🤖' : '👤'}
        </Text>
      </View>

      <View style={styles.info}>
        <Text style={styles.nome} numberOfLines={1}>
          {jogador.nome}
        </Text>
        <Text style={[styles.saldo, { color: corSaldo }]}>
          R$ {jogador.saldo}
        </Text>
        {jogador.usouFundoEmergencia && (
          <Text style={styles.emergencia}>Fundo ativo</Text>
        )}
        {jogador.falido && (
          <Text style={styles.falido}>FALIDO</Text>
        )}
        {jogador.protegido && (
          <Text style={styles.protegido}>PROTEGIDO</Text>
        )}
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: 8,
    paddingVertical: 4,
  },
  containerTopo: {
    borderTopLeftRadius: 8,
    borderTopRightRadius: 8,
  },
  containerBaixo: {
    borderBottomLeftRadius: 8,
    borderBottomRightRadius: 8,
  },
  avatar: {
    width: 32,
    height: 32,
    borderRadius: 16,
    backgroundColor: '#333',
    alignItems: 'center',
    justifyContent: 'center',
    marginRight: 8,
  },
  avatarEmoji: {
    fontSize: 16,
  },
  info: {
    flex: 1,
  },
  nome: {
    fontSize: 11,
    color: '#CCC',
    fontWeight: 'bold',
  },
  saldo: {
    fontSize: 13,
    fontWeight: 'bold',
  },
  emergencia: {
    fontSize: 8,
    color: '#FFA726',
    fontStyle: 'italic',
  },
  falido: {
    fontSize: 9,
    color: '#EF5350',
    fontWeight: 'bold',
  },
  protegido: {
    fontSize: 8,
    color: '#66BB6A',
    fontWeight: 'bold',
  },
});
