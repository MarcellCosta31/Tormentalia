import React from 'react';
import { View, StyleSheet } from 'react-native';
import Text from '../Texto';
import { TIPO_CARTA } from '../../cards/baralhoCartas';

const coresTipo = {
  [TIPO_CARTA.CORINGA]: '#6A1B9A',
  [TIPO_CARTA.ACAO]: '#C62828',
  [TIPO_CARTA.EFEITO]: '#1565C0',
  [TIPO_CARTA.PROTECAO]: '#2E7D32',
};

export default function MesaDuelo({ estado }) {
  if (!estado) return null;

  const { baralho, pilhaDescarte, turnoAtual, maxTurnos, jogadorAtivoIndex, direcaoTurno, jogadores } = estado;
  const ultimaCartaDescarte = pilhaDescarte.length > 0 ? pilhaDescarte[pilhaDescarte.length - 1] : null;

  return (
    <View style={styles.container}>
      <View style={styles.ladoEsquerdo}>
        <View style={styles.indicadorTurno}>
          <Text style={styles.turnoLabel}>TURNO</Text>
          <Text style={styles.turnoNumero}>{turnoAtual}/{maxTurnos}</Text>
        </View>

        <View style={[styles.indicadorVez, jogadorAtivoIndex === 0 ? styles.vezJogador : styles.vezOponente]}>
          <Text style={styles.vezTexto}>
            {jogadorAtivoIndex === 0 ? 'SUA VEZ' : 'VEZ DO OPONENTE'}
          </Text>
        </View>

        <View style={styles.indicadorDirecao}>
          <Text style={styles.direcaoLabel}>DIRECAO</Text>
          <Text style={styles.direcaoSimbolo}>
            {direcaoTurno === 1 ? '↻ Horario' : '↺ Anti-horario'}
          </Text>
        </View>
      </View>

      <View style={styles.ladoDireito}>
        <View style={styles.montes}>
          <View style={styles.monte}>
            <View style={[styles.pilha, styles.pilhaBaralho]}>
              <Text style={styles.pilhaTexto}>{baralho.length}</Text>
              <Text style={styles.pilhaLabel}>BARALHO</Text>
            </View>
          </View>

          <View style={styles.monte}>
            <View style={[styles.pilha, styles.pilhaDescarte]}>
              {ultimaCartaDescarte ? (
                <>
                  <Text style={[styles.descarteTipo, { color: coresTipo[ultimaCartaDescarte.tipo] }]}>
                    {ultimaCartaDescarte.tipo.charAt(0)}
                  </Text>
                  <Text style={styles.descarteTitulo} numberOfLines={1}>
                    {ultimaCartaDescarte.titulo}
                  </Text>
                </>
              ) : (
                <Text style={styles.pilhaVazia}>Vazio</Text>
              )}
              <Text style={styles.pilhaLabel}>DESCARTE ({pilhaDescarte.length})</Text>
            </View>
          </View>
        </View>

        {jogadores && (
          <View style={styles.saldosMini}>
            <View style={styles.saldoMini}>
              <Text style={styles.saldoMiniLabel}>Voce</Text>
              <Text style={[styles.saldoMiniValor, { color: jogadores[0].saldo > 10 ? '#66BB6A' : '#EF5350' }]}>
                R$ {jogadores[0].saldo}
              </Text>
            </View>
            <Text style={styles.saldoMiniVersus}>VS</Text>
            <View style={styles.saldoMini}>
              <Text style={styles.saldoMiniLabel}>Oponente</Text>
              <Text style={[styles.saldoMiniValor, { color: jogadores[1].saldo > 10 ? '#66BB6A' : '#EF5350' }]}>
                R$ {jogadores[1].saldo}
              </Text>
            </View>
          </View>
        )}
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 2,
    flexDirection: 'row',
    backgroundColor: 'rgba(20, 20, 35, 0.9)',
    borderTopWidth: 1,
    borderBottomWidth: 1,
    borderColor: '#444',
    paddingVertical: 4,
    paddingHorizontal: 6,
  },
  ladoEsquerdo: {
    width: '30%',
    justifyContent: 'center',
    alignItems: 'center',
    gap: 4,
  },
  indicadorTurno: {
    alignItems: 'center',
    backgroundColor: '#1E1E2E',
    borderRadius: 6,
    paddingHorizontal: 10,
    paddingVertical: 4,
    borderWidth: 1,
    borderColor: '#555',
  },
  turnoLabel: {
    fontSize: 8,
    color: '#888',
    fontWeight: 'bold',
  },
  turnoNumero: {
    fontSize: 18,
    color: '#FFD54F',
    fontWeight: 'bold',
  },
  indicadorVez: {
    borderRadius: 6,
    paddingHorizontal: 8,
    paddingVertical: 4,
    alignItems: 'center',
  },
  vezJogador: {
    backgroundColor: 'rgba(46, 125, 50, 0.3)',
    borderWidth: 1,
    borderColor: '#2E7D32',
  },
  vezOponente: {
    backgroundColor: 'rgba(198, 40, 40, 0.3)',
    borderWidth: 1,
    borderColor: '#C62828',
  },
  vezTexto: {
    fontSize: 10,
    color: '#FFF',
    fontWeight: 'bold',
  },
  indicadorDirecao: {
    alignItems: 'center',
  },
  direcaoLabel: {
    fontSize: 8,
    color: '#888',
    fontWeight: 'bold',
  },
  direcaoSimbolo: {
    fontSize: 9,
    color: '#4FC3F7',
  },
  ladoDireito: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
  },
  montes: {
    flexDirection: 'row',
    gap: 12,
    marginBottom: 6,
  },
  monte: {
    alignItems: 'center',
  },
  pilha: {
    width: 60,
    height: 75,
    borderRadius: 6,
    borderWidth: 2,
    alignItems: 'center',
    justifyContent: 'center',
    padding: 4,
  },
  pilhaBaralho: {
    backgroundColor: '#1A237E',
    borderColor: '#3F51B5',
  },
  pilhaDescarte: {
    backgroundColor: '#3E2723',
    borderColor: '#795548',
    width: 70,
  },
  pilhaTexto: {
    fontSize: 20,
    color: '#FFF',
    fontWeight: 'bold',
  },
  pilhaLabel: {
    fontSize: 7,
    color: '#AAA',
    marginTop: 2,
  },
  pilhaVazia: {
    fontSize: 10,
    color: '#666',
  },
  descarteTipo: {
    fontSize: 10,
    fontWeight: 'bold',
  },
  descarteTitulo: {
    fontSize: 8,
    color: '#DDD',
    textAlign: 'center',
  },
  saldosMini: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 8,
    backgroundColor: '#1E1E2E',
    borderRadius: 6,
    paddingHorizontal: 10,
    paddingVertical: 3,
    borderWidth: 1,
    borderColor: '#444',
  },
  saldoMini: {
    alignItems: 'center',
  },
  saldoMiniLabel: {
    fontSize: 8,
    color: '#888',
  },
  saldoMiniValor: {
    fontSize: 12,
    fontWeight: 'bold',
  },
  saldoMiniVersus: {
    fontSize: 10,
    color: '#FF5722',
    fontWeight: 'bold',
  },
});
