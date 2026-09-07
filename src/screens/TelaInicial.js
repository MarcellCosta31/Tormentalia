import React from 'react';
import { View, Text, TouchableOpacity, StyleSheet, SafeAreaView } from 'react-native';

const TelaInicial = ({ onIniciarJogo }) => {
  return (
    <SafeAreaView style={styles.container}>
      <View style={styles.conteudo}>
        {/* Logo/Título */}
        <View style={styles.logoContainer}>
          <Text style={styles.emojiLogo}>👤</Text>
          <Text style={styles.titulo}>O Caro</Text>
          <Text style={styles.subtitulo}>Deus Mercado</Text>
        </View>

        {/* Descrição */}
        <View style={styles.descricaoContainer}>
          <Text style={styles.descricao}>
            Gerencie sua empresa, compre cartas, acumule capital e elimine a concorrência!
          </Text>
        </View>

        {/* Regras rápidas */}
        <View style={styles.regrasContainer}>
          <Text style={styles.tituloRegras}>📋 Regras Rápidas:</Text>
          <Text style={styles.regra}>• Comece com R$ 20 e 7 cartas</Text>
          <Text style={styles.regra}>• Use cartas para ganhar dinheiro</Text>
          <Text style={styles.regra}>• Cuidado com o risco das cartas!</Text>
          <Text style={styles.regra}>• Saldo zerado = Saldo de emergência</Text>
          <Text style={styles.regra}>• Mais dinheiro ao final = Vence!</Text>
        </View>

        {/* Botões */}
        <View style={styles.botoesContainer}>
          <TouchableOpacity style={styles.botaoJogar} onPress={onIniciarJogo}>
            <Text style={styles.textoBotaoJogar}>🎮 JOGAR</Text>
          </TouchableOpacity>

          <TouchableOpacity style={styles.botaoModo}>
            <Text style={styles.textoBotaoModo}>🤖 Single Player</Text>
          </TouchableOpacity>

          <TouchableOpacity style={[styles.botaoModo, styles.botaoDesabilitado]}>
            <Text style={styles.textoBotaoModo}>🌐 Multiplayer (Em breve)</Text>
          </TouchableOpacity>
        </View>

        {/* Rodapé */}
        <View style={styles.rodape}>
          <Text style={styles.rodapeTexto}>
            Trabalho de Teoria Geral de Administração
          </Text>
          <Text style={styles.versao}>v1.0 - Pixel Art</Text>
        </View>
      </View>
    </SafeAreaView>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#1a1a2e',
  },
  conteudo: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    padding: 20,
  },
  logoContainer: {
    alignItems: 'center',
    marginBottom: 30,
  },
  emojiLogo: {
    fontSize: 80,
    marginBottom: 10,
  },
  titulo: {
    fontSize: 40,
    fontWeight: 'bold',
    color: '#4fc3f7',
    textShadowColor: '#000',
    textShadowOffset: { width: 2, height: 2 },
    textShadowRadius: 3,
  },
  subtitulo: {
    fontSize: 24,
    color: '#ff9800',
    fontWeight: 'bold',
    marginTop: 5,
  },
  descricaoContainer: {
    backgroundColor: '#16213e',
    padding: 15,
    borderRadius: 10,
    marginBottom: 20,
    maxWidth: '90%',
  },
  descricao: {
    color: '#FFF',
    fontSize: 14,
    textAlign: 'center',
    lineHeight: 20,
  },
  regrasContainer: {
    backgroundColor: '#0f3460',
    padding: 15,
    borderRadius: 10,
    marginBottom: 30,
    width: '90%',
  },
  tituloRegras: {
    color: '#4fc3f7',
    fontSize: 16,
    fontWeight: 'bold',
    marginBottom: 10,
  },
  regra: {
    color: '#CCC',
    fontSize: 12,
    marginBottom: 5,
  },
  botoesContainer: {
    width: '100%',
    alignItems: 'center',
    gap: 15,
  },
  botaoJogar: {
    backgroundColor: '#4caf50',
    paddingHorizontal: 50,
    paddingVertical: 20,
    borderRadius: 15,
    elevation: 5,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 3 },
    shadowOpacity: 0.3,
    shadowRadius: 4,
  },
  textoBotaoJogar: {
    color: '#FFF',
    fontSize: 24,
    fontWeight: 'bold',
  },
  botaoModo: {
    backgroundColor: '#16213e',
    paddingHorizontal: 30,
    paddingVertical: 15,
    borderRadius: 10,
    borderWidth: 2,
    borderColor: '#4fc3f7',
    width: '80%',
    alignItems: 'center',
  },
  botaoDesabilitado: {
    opacity: 0.5,
    borderColor: '#666',
  },
  textoBotaoModo: {
    color: '#FFF',
    fontSize: 16,
  },
  rodape: {
    position: 'absolute',
    bottom: 20,
    alignItems: 'center',
  },
  rodapeTexto: {
    color: '#666',
    fontSize: 10,
  },
  versao: {
    color: '#444',
    fontSize: 10,
    marginTop: 5,
  },
});

export default TelaInicial;
