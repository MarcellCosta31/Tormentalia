import React from 'react';
import { View, ScrollView, StyleSheet, TouchableOpacity } from 'react-native';
import Text from '../Texto';
import CartaArena from './CartaArena';

export default function RegiaoJogador({ jogador, cartaSelecionada, onSelecionarCarta, onJogarCarta, onDescartar, modoDescarte, desabilitado }) {
  if (!jogador) return null;

  return (
    <View style={styles.container}>
      <View style={styles.maoContainer}>
        <Text style={styles.maoLabel}>SUA MAO ({jogador.mao.length})</Text>
        <ScrollView horizontal showsHorizontalScrollIndicator={false} style={styles.maoScroll}>
          <View style={styles.mao}>
            {jogador.mao.map((carta) => (
              <CartaArena
                key={carta.uid}
                carta={carta}
                onPress={() => onSelecionarCarta(carta)}
                selecionada={cartaSelecionada?.uid === carta.uid}
                desabilitada={desabilitado || jogador.falido}
              />
            ))}
          </View>
        </ScrollView>
      </View>

      <View style={styles.controles}>
        <TouchableOpacity
          style={[styles.botao, styles.botaoJogar, (!cartaSelecionada || desabilitado || jogador.falido) && styles.botaoDesabilitado]}
          onPress={onJogarCarta}
          disabled={!cartaSelecionada || desabilitado || jogador.falido}
        >
          <Text style={styles.botaoTexto}>
            {modoDescarte ? 'DESCARTAR' : 'JOGAR CARTA'}
          </Text>
        </TouchableOpacity>

        <TouchableOpacity
          style={[styles.botao, styles.botaoPassar, desabilitado || jogador.falido && styles.botaoDesabilitado]}
          onPress={onDescartar}
          disabled={desabilitado || jogador.falido}
        >
          <Text style={styles.botaoTexto}>PASSAR TURNO</Text>
        </TouchableOpacity>
      </View>

      <View style={styles.infoBar}>
        <View style={styles.avatarContainer}>
          <Text style={styles.avatarEmoji}>👤</Text>
        </View>
        <View style={styles.infoText}>
          <Text style={styles.nome}>{jogador.nome}</Text>
          <Text style={[styles.saldo, jogador.saldo > 10 ? styles.saldoPositivo : jogador.saldo > 5 ? styles.saldoNeutro : styles.saldoNegativo]}>
            R$ {jogador.saldo}
          </Text>
        </View>
        {jogador.usouFundoEmergencia && (
          <View style={styles.badgeEmergencia}>
            <Text style={styles.badgeEmergenciaTexto}>EMERGENCIA</Text>
          </View>
        )}
        {jogador.falido && (
          <View style={styles.badgeFalido}>
            <Text style={styles.badgeFalidoTexto}>FALIDO</Text>
          </View>
        )}
        {jogador.protegido && (
          <View style={styles.badgeProtegido}>
            <Text style={styles.badgeProtegidoTexto}>🛡 PROTEGIDO</Text>
          </View>
        )}
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: 'rgba(30, 30, 50, 0.6)',
    borderTopWidth: 1,
    borderTopColor: '#333',
    paddingVertical: 4,
  },
  maoContainer: {
    flex: 1,
    paddingHorizontal: 8,
  },
  maoLabel: {
    fontSize: 9,
    color: '#888',
    marginBottom: 2,
  },
  maoScroll: {
    flex: 1,
  },
  mao: {
    flexDirection: 'row',
    alignItems: 'flex-start',
    paddingVertical: 4,
  },
  controles: {
    flexDirection: 'row',
    justifyContent: 'center',
    gap: 8,
    paddingVertical: 4,
  },
  botao: {
    borderRadius: 6,
    paddingHorizontal: 16,
    paddingVertical: 8,
    alignItems: 'center',
    justifyContent: 'center',
    minWidth: 120,
  },
  botaoJogar: {
    backgroundColor: '#2E7D32',
  },
  botaoPassar: {
    backgroundColor: '#E65100',
  },
  botaoDesabilitado: {
    backgroundColor: '#444',
    opacity: 0.5,
  },
  botaoTexto: {
    fontSize: 11,
    color: '#FFF',
    fontWeight: 'bold',
  },
  infoBar: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: 6,
    paddingVertical: 2,
    borderTopWidth: 1,
    borderTopColor: '#333',
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
  badgeEmergencia: {
    backgroundColor: '#FF8F00',
    borderRadius: 4,
    paddingHorizontal: 6,
    paddingVertical: 2,
  },
  badgeEmergenciaTexto: {
    fontSize: 8,
    color: '#FFF',
    fontWeight: 'bold',
  },
  badgeFalido: {
    backgroundColor: '#C62828',
    borderRadius: 4,
    paddingHorizontal: 6,
    paddingVertical: 2,
    marginLeft: 4,
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
    fontSize: 9,
    color: '#FFF',
    fontWeight: 'bold',
  },
});
