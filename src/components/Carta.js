import React from 'react';
import { View, Text, TouchableOpacity, StyleSheet } from 'react-native';
import { TIPO_CARTA } from '../cards/cartas';

const Carta = ({ carta, onPress, selecionada = false, desabilitada = false }) => {
  const getCorTipo = () => {
    switch (carta.tipo) {
      case TIPO_CARTA.MEDIDA:
        return carta.efeito.valor >= 0 ? '#2E7D32' : '#C62828';
      case TIPO_CARTA.BONUS:
        return '#FFA000';
      case TIPO_CARTA.CORINGA:
        return '#6A1B9A';
      default:
        return '#424242';
    }
  };

  const getCorFundo = () => {
    if (desabilitada) return '#9E9E9E';
    if (selecionada) return '#1565C0';
    return getCorTipo();
  };

  const getEfeitoTexto = () => {
    if (carta.tipo === TIPO_CARTA.BONUS) {
      return carta.descricao;
    }
    
    const { tipo, valor } = carta.efeito;
    if (tipo === 'DINHEIRO') {
      return valor >= 0 ? `+R$ ${valor}` : `-R$ ${Math.abs(valor)}`;
    }
    if (tipo === 'TODOS') {
      return `Todos: ${valor >= 0 ? '+' : ''}${valor}`;
    }
    if (tipo === 'OPONENTE') {
      return `Oponente: ${valor >= 0 ? '+' : ''}${valor}`;
    }
    if (tipo === 'BUFF') {
      return `Buff: ${valor >= 0 ? '+' : ''}${valor} (${carta.efeito.duracao}T)`;
    }
    if (tipo === 'ALEATORIO') {
      return '???';
    }
    return '';
  };

  return (
    <TouchableOpacity
      style={[
        styles.carta,
        { backgroundColor: getCorFundo() },
        selecionada && styles.cartaSelecionada,
        desabilitada && styles.cartaDesabilitada
      ]}
      onPress={() => !desabilitada && onPress?.(carta)}
      activeOpacity={desabilitada ? 1 : 0.7}
    >
      <View style={styles.cabecalho}>
        <Text style={styles.pixelEmoji}>{carta.pixelEmoji}</Text>
        {carta.risco !== undefined && carta.risco > 0 && (
          <View style={[styles.badgeRisco, { backgroundColor: carta.risco > 50 ? '#FF5722' : '#FFC107' }]}>
            <Text style={styles.textoRisco}>{carta.risco}%</Text>
          </View>
        )}
      </View>

      <Text style={styles.nome} numberOfLines={2}>{carta.nome}</Text>
      
      <View style={styles.efeitoContainer}>
        <Text style={styles.efeito}>{getEfeitoTexto()}</Text>
      </View>

      <Text style={styles.descricao} numberOfLines={2}>{carta.descricao}</Text>

      {carta.tipo === TIPO_CARTA.BONUS && (
        <View style={styles.badgeBonus}>
          <Text style={styles.textoBonus}>BÔNUS</Text>
        </View>
      )}

      {carta.tipo === TIPO_CARTA.CORINGA && (
        <View style={styles.badgeCoringa}>
          <Text style={styles.textoCoringa}>CORINGA</Text>
        </View>
      )}
    </TouchableOpacity>
  );
};

const styles = StyleSheet.create({
  carta: {
    width: 100,
    height: 140,
    borderRadius: 8,
    padding: 8,
    marginHorizontal: 4,
    justifyContent: 'space-between',
    elevation: 4,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.25,
    shadowRadius: 3.84,
  },
  cartaSelecionada: {
    borderWidth: 3,
    borderColor: '#FFF',
    transform: [{ translateY: -10 }],
  },
  cartaDesabilitada: {
    opacity: 0.5,
  },
  cabecalho: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'flex-start',
  },
  pixelEmoji: {
    fontSize: 24,
  },
  badgeRisco: {
    paddingHorizontal: 4,
    paddingVertical: 2,
    borderRadius: 4,
  },
  textoRisco: {
    color: '#FFF',
    fontSize: 8,
    fontWeight: 'bold',
  },
  nome: {
    color: '#FFF',
    fontSize: 10,
    fontWeight: 'bold',
    textAlign: 'center',
    marginTop: 4,
  },
  efeitoContainer: {
    backgroundColor: 'rgba(0,0,0,0.3)',
    borderRadius: 4,
    padding: 4,
    marginVertical: 4,
  },
  efeito: {
    color: '#FFF',
    fontSize: 12,
    fontWeight: 'bold',
    textAlign: 'center',
  },
  descricao: {
    color: 'rgba(255,255,255,0.8)',
    fontSize: 8,
    textAlign: 'center',
  },
  badgeBonus: {
    position: 'absolute',
    top: -5,
    right: -5,
    backgroundColor: '#FFA000',
    paddingHorizontal: 6,
    paddingVertical: 2,
    borderRadius: 8,
  },
  textoBonus: {
    color: '#000',
    fontSize: 8,
    fontWeight: 'bold',
  },
  badgeCoringa: {
    position: 'absolute',
    top: -5,
    right: -5,
    backgroundColor: '#6A1B9A',
    paddingHorizontal: 6,
    paddingVertical: 2,
    borderRadius: 8,
  },
  textoCoringa: {
    color: '#FFF',
    fontSize: 8,
    fontWeight: 'bold',
  },
});

export default Carta;
