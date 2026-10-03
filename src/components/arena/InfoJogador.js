import React from 'react';
import { View, StyleSheet } from 'react-native';
import Text from '../Texto';

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
    paddingHorizontal: 5,
    paddingVertical: 2,
  },
  containerTopo: {
    borderTopLeftRadius: 6,
    borderTopRightRadius: 6,
  },
  containerBaixo: {
    borderBottomLeftRadius: 6,
    borderBottomRightRadius: 6,
  },
  avatar: {
    width: 24,
    height: 24,
    borderRadius: 12,
    backgroundColor: '#333',
    alignItems: 'center',
    justifyContent: 'center',
    marginRight: 5,
  },
  avatarEmoji: {
    fontSize: 12,
  },
  info: {
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
  emergencia: {
    fontSize: 6,
    color: '#FFA726',
    fontStyle: 'italic',
  },
  falido: {
    fontSize: 7,
    color: '#EF5350',
    fontWeight: 'bold',
  },
  protegido: {
    fontSize: 6,
    color: '#66BB6A',
    fontWeight: 'bold',
  },
});
