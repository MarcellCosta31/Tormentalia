import React, { useState, useEffect, useCallback } from 'react';
import {
  View,
  Text,
  ScrollView,
  TouchableOpacity,
  StyleSheet,
  Alert,
  SafeAreaView
} from 'react-native';
import Carta from '../components/Carta';
import {
  criarEstadoJogo,
  aplicarEfeitoCarta,
  aplicarEfeitoDeusMercado,
  verificarSaldoEmergencia,
  verificarEliminacao,
  passarTurno,
  comprarCarta,
  descartarCarta,
  STATUS_JOGADOR
} from '../game/logicaJogo';
import { TIPO_CARTA } from '../cards/cartas';

const TelaJogo = ({ onVoltar }) => {
  const [estadoJogo, setEstadoJogo] = useState(null);
  const [cartaSelecionada, setCartaSelecionada] = useState(null);
  const [cartaBonusSelecionada, setCartaBonusSelecionada] = useState(null);
  const [modoDescarte, setModoDescarte] = useState(false);
  const [mensagemTurno, setMensagemTurno] = useState('');
  const [mostrarLog, setMostrarLog] = useState(false);

  useEffect(() => {
    iniciarNovoJogo();
  }, []);

  const iniciarNovoJogo = () => {
    const novoEstado = criarEstadoJogo(['Você', 'Robô CEO', 'Máquina Corp', 'Android S.A.']);
    setEstadoJogo(novoEstado);
    setCartaSelecionada(null);
    setCartaBonusSelecionada(null);
    setModoDescarte(false);
    setMensagemTurno('🎮 Jogo começar! Sua vez!');
  };

  const jogadorAtual = estadoJogo?.jogadores[estadoJogo.jogadorAtualIndex];
  const isVezDoJogador = jogadorAtual && !jogadorAtual.isIA;

  const handleJogarCarta = useCallback(() => {
    if (!cartaSelecionada || !estadoJogo) return;

    // Verifica se é carta bônus (não pode jogar sozinha)
    if (cartaSelecionada.tipo === TIPO_CARTA.BONUS) {
      Alert.alert('Aviso', 'Cartas bônus não podem ser jogadas sozinhas!');
      return;
    }

    // Verifica se tem carta coringa
    if (cartaSelecionada.tipo === TIPO_CARTA.CORINGA) {
      const resultado = aplicarEfeitoCarta(cartaSelecionada, jogadorAtual, estadoJogo.jogadores);
      if (resultado.sucesso) {
        // Remove carta da mão
        const index = jogadorAtual.mao.findIndex(c => c.uid === cartaSelecionada.uid);
        if (index !== -1) {
          jogadorAtual.mao.splice(index, 1);
        }
        setMensagemTurno(resultado.mensagem);
        setCartaSelecionada(null);
        setCartaBonusSelecionada(null);
        
        // Compra nova carta
        comprarCarta(jogadorAtual, estadoJogo.baralho);
        
        // Verifica saldo emergência
        verificarSaldoEmergencia(jogadorAtual);
        verificarEliminacao(jogadorAtual);
        
        setEstadoJogo({ ...estadoJogo });
      }
      return;
    }

    const resultado = aplicarEfeitoCarta(
      cartaSelecionada,
      jogadorAtual,
      estadoJogo.jogadores,
      cartaBonusSelecionada
    );

    setMensagemTurno(resultado.mensagem);

    // Remove cartas usadas
    const indexMedida = jogadorAtual.mao.findIndex(c => c.uid === cartaSelecionada.uid);
    if (indexMedida !== -1) {
      jogadorAtual.mao.splice(indexMedida, 1);
    }

    if (cartaBonusSelecionada) {
      const indexBonus = jogadorAtual.mao.findIndex(c => c.uid === cartaBonusSelecionada.uid);
      if (indexBonus !== -1) {
        jogadorAtual.mao.splice(indexBonus, 1);
      }
    }

    // Compra nova carta
    comprarCarta(jogadorAtual, estadoJogo.baralho);

    // Verifica saldo emergência
    verificarSaldoEmergencia(jogadorAtual);
    verificarEliminacao(jogadorAtual);

    setCartaSelecionada(null);
    setCartaBonusSelecionada(null);
    setEstadoJogo({ ...estadoJogo });
  }, [cartaSelecionada, cartaBonusSelecionada, estadoJogo, jogadorAtual]);

  const handleDescartar = useCallback((carta) => {
    if (!estadoJogo || !modoDescarte) return;

    descartarCarta(jogadorAtual, carta.uid);
    comprarCarta(jogadorAtual, estadoJogo.baralho);

    setModoDescarte(false);
    setMensagemTurno(`🗑️ Descartou ${carta.nome} e comprou nova carta!`);
    
    // Passa turno
    const novoEstado = passarTurno(estadoJogo);
    setEstadoJogo(novoEstado);
    
    // Turno da IA
    if (!novoEstado.jogoAcabou) {
      setTimeout(() => executarTurnoIA(novoEstado), 1000);
    }
  }, [estadoJogo, jogadorAtual, modoDescarte]);

  const handlePassarTurno = useCallback(() => {
    if (!estadoJogo || modoDescarte) return;

    setModoDescarte(true);
    setMensagemTurno('🗑️ Escolha uma carta para descartar!');
  }, [estadoJogo, modoDescarte]);

  const executarTurnoIA = (estado) => {
    const jogadorIA = estado.jogadores[estado.jogadorAtualIndex];
    if (!jogadorIA || !jogadorIA.isIA) return;

    // IA simples: joga a primeira carta medida que tiver
    const cartaMedida = jogadorIA.mao.find(c => c.tipo === TIPO_CARTA.MEDIDA);
    const cartaBonus = jogadorIA.mao.find(c => c.tipo === TIPO_CARTA.BONUS);

    if (cartaMedida) {
      const resultado = aplicarEfeitoCarta(cartaMedida, jogadorIA, estado.jogadores, cartaBonus);
      
      // Remove cartas
      const indexMedida = jogadorIA.mao.findIndex(c => c.uid === cartaMedida.uid);
      if (indexMedida !== -1) jogadorIA.mao.splice(indexMedida, 1);

      if (cartaBonus) {
        const indexBonus = jogadorIA.mao.findIndex(c => c.uid === cartaBonus.uid);
        if (indexBonus !== -1) jogadorIA.mao.splice(indexBonus, 1);
      }

      comprarCarta(jogadorIA, estado.baralho);
      verificarSaldoEmergencia(jogadorIA);
      verificarEliminacao(jogadorIA);

      setMensagemTurno(`🤖 ${jogadorIA.nome}: ${resultado.mensagem}`);
    }

    // Descarta uma carta aleatória
    if (jogadorIA.mao.length > 0) {
      const cartaDescarte = jogadorIA.mao[Math.floor(Math.random() * jogadorIA.mao.length)];
      descartarCarta(jogadorIA, cartaDescarte.uid);
      comprarCarta(jogadorIA, estado.baralho);
    }

    // Aplica efeito Deus Mercado no final do turno
    if (estado.jogadorAtualIndex === estado.jogadores.length - 1) {
      const resultadoDeus = aplicarEfeitoDeusMercado(estado.jogadores, estado.baralho);
      if (resultadoDeus) {
        setMensagemTurno(`👁️ Deus Mercado: ${resultadoDeus.carta.nome}!`);
      }
    }

    // Próximo turno
    const novoEstado = passarTurno(estado);
    setEstadoJogo(novoEstado);

    // Se próximo for humano, mostra mensagem
    if (!novoEstado.jogoAcabou && !novoEstado.jogadores[novoEstado.jogadorAtualIndex].isIA) {
      setTimeout(() => {
        setMensagemTurno(`🎮 Sua vez! Turno ${novoEstado.turnoAtual}`);
      }, 1500);
    } else if (!novoEstado.jogoAcabou) {
      setTimeout(() => executarTurnoIA(novoEstado), 2000);
    }
  };

  const handleSelecionarCarta = (carta) => {
    if (modoDescarte) {
      handleDescartar(carta);
      return;
    }

    if (carta.tipo === TIPO_CARTA.BONUS) {
      if (cartaSelecionada) {
        setCartaBonusSelecionada(carta);
      } else {
        Alert.alert('Aviso', 'Selecione uma carta medida primeiro!');
      }
    } else {
      setCartaSelecionada(carta);
      setCartaBonusSelecionada(null);
    }
  };

  if (!estadoJogo) {
    return (
      <View style={styles.container}>
        <Text style={styles.carregando}>Carregando...</Text>
      </View>
    );
  }

  return (
    <SafeAreaView style={styles.container}>
      {/* Header */}
      <View style={styles.header}>
        <TouchableOpacity style={styles.botaoVoltar} onPress={onVoltar}>
          <Text style={styles.textoBotaoVoltar}>← Voltar</Text>
        </TouchableOpacity>
        <View style={styles.infoTurno}>
          <Text style={styles.turnoTexto}>Turno {estadoJogo.turnoAtual}/10</Text>
        </View>
        <TouchableOpacity style={styles.botaoNovoJogo} onPress={iniciarNovoJogo}>
          <Text style={styles.textoBotaoNovo}>Novo Jogo</Text>
        </TouchableOpacity>
      </View>

      {/* Barra de mensagem */}
      <View style={styles.barraMensagem}>
        <Text style={styles.textoMensagem}>{mensagemTurno}</Text>
      </View>

      {/* Status dos jogadores */}
      <ScrollView style={styles.listaJogadores} horizontal showsHorizontalScrollIndicator={false}>
        {estadoJogo.jogadores.map((jogador, index) => (
          <View
            key={jogador.id}
            style={[
              styles.cardJogador,
              index === estadoJogo.jogadorAtualIndex && styles.cardJogadorAtivo,
              jogador.status === STATUS_JOGADOR.ELIMINADO && styles.cardJogadorEliminado,
              jogador.status === STATUS_JOGADOR.EMERGENCIA && styles.cardJogadorEmergencia
            ]}
          >
            <Text style={styles.nomeJogador}>{jogador.nome}</Text>
            <Text style={styles.saldoJogador}>R$ {jogador.saldo}</Text>
            {jogador.status === STATUS_JOGADOR.EMERGENCIA && (
              <Text style={styles.emergencia}>🚨 EMERGÊNCIA</Text>
            )}
            {jogador.status === STATUS_JOGADOR.ELIMINADO && (
              <Text style={styles.eliminado}>💀 FALIU</Text>
            )}
            {jogador.isIA && <Text style={styles.badgeIA}>🤖</Text>}
          </View>
        ))}
      </ScrollView>

      {/* Área principal */}
      <View style={styles.areaPrincipal}>
        {/* Log do jogo */}
        <TouchableOpacity 
          style={styles.botaoLog}
          onPress={() => setMostrarLog(!mostrarLog)}
        >
          <Text style={styles.textoLog}>
            {mostrarLog ? '▼ Ocultar Log' : '▶ Ver Log'}
          </Text>
        </TouchableOpacity>

        {mostrarLog && (
          <ScrollView style={styles.logContainer}>
            {estadoJogo.log.map((mensagem, index) => (
              <Text key={index} style={styles.logTexto}>{mensagem}</Text>
            ))}
          </ScrollView>
        )}

        {/* Informações da carta selecionada */}
        {cartaSelecionada && (
          <View style={styles.infoCartaSelecionada}>
            <Text style={styles.tituloInfo}>Carta Selecionada:</Text>
            <Text style={styles.nomeInfo}>{cartaSelecionada.nome}</Text>
            <Text style={styles.descricaoInfo}>{cartaSelecionada.descricao}</Text>
            {cartaSelecionada.risco > 0 && (
              <Text style={styles.riscoInfo}>Risco: {cartaSelecionada.risco}%</Text>
            )}
            {cartaBonusSelecionada && (
              <Text style={styles.bonusInfo}>
                + Bônus: {cartaBonusSelecionada.nome}
              </Text>
            )}
          </View>
        )}
      </View>

      {/* Área de ações */}
      {isVezDoJogador && !estadoJogo.jogoAcabou && (
        <View style={styles.areaAcoes}>
          {!modoDescarte ? (
            <>
              <TouchableOpacity
                style={[
                  styles.botaoAcao,
                  styles.botaoJogar,
                  !cartaSelecionada && styles.botaoDesabilitado
                ]}
                onPress={handleJogarCarta}
                disabled={!cartaSelecionada}
              >
                <Text style={styles.textoBotaoAcao}>🃏 Jogar Carta</Text>
              </TouchableOpacity>

              <TouchableOpacity
                style={[styles.botaoAcao, styles.botaoPassar]}
                onPress={handlePassarTurno}
              >
                <Text style={styles.textoBotaoAcao}>⏭️ Passar Turno</Text>
              </TouchableOpacity>
            </>
          ) : (
            <View style={styles.modoDescarte}>
              <Text style={styles.textoModoDescarte}>
                🗑️ Toque em uma carta para descartar
              </Text>
            </View>
          )}
        </View>
      )}

      {/* Mão do jogador */}
      <View style={styles.maoContainer}>
        <Text style={styles.tituloMao}>
          Sua Mão ({jogadorAtual?.mao?.length || 0} cartas)
        </Text>
        <ScrollView horizontal showsHorizontalScrollIndicator={false} style={styles.maoScroll}>
          {jogadorAtual?.mao?.map((carta) => (
            <Carta
              key={carta.uid}
              carta={carta}
              onPress={handleSelecionarCarta}
              selecionada={carta.uid === cartaSelecionada?.uid || carta.uid === cartaBonusSelecionada?.uid}
              desabilitada={
                estadoJogo.jogoAcabou ||
                (!isVezDoJogador) ||
                (modoDescarte && carta.tipo === TIPO_CARTA.CORINGA)
              }
            />
          ))}
        </ScrollView>
      </View>

      {/* Tela de fim de jogo */}
      {estadoJogo.jogoAcabou && (
        <View style={styles.telaFim}>
          <View style={styles.cardFim}>
            <Text style={styles.tituloFim}>🏁 FIM DE JOGO!</Text>
            {estadoJogo.vencedor?.empate ? (
              <Text style={styles.textoFim}>EMPATE!</Text>
            ) : (
              <>
                <Text style={styles.vencedorFim}>
                  🏆 {estadoJogo.vencedor?.nome} VENCEU!
                </Text>
                <Text style={styles.saldoFim}>
                  Saldo: R$ {estadoJogo.vencedor?.saldo}
                </Text>
              </>
            )}
            <TouchableOpacity style={styles.botaoJogarNovamente} onPress={iniciarNovoJogo}>
              <Text style={styles.textoBotaoJogar}>Jogar Novamente</Text>
            </TouchableOpacity>
          </View>
        </View>
      )}
    </SafeAreaView>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#1a1a2e',
  },
  header: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    padding: 10,
    backgroundColor: '#16213e',
  },
  botaoVoltar: {
    padding: 8,
  },
  textoBotaoVoltar: {
    color: '#4fc3f7',
    fontSize: 14,
  },
  infoTurno: {
    backgroundColor: '#0f3460',
    paddingHorizontal: 15,
    paddingVertical: 8,
    borderRadius: 15,
  },
  turnoTexto: {
    color: '#FFF',
    fontSize: 16,
    fontWeight: 'bold',
  },
  botaoNovoJogo: {
    padding: 8,
  },
  textoBotaoNovo: {
    color: '#4fc3f7',
    fontSize: 14,
  },
  barraMensagem: {
    backgroundColor: '#0f3460',
    padding: 12,
    marginHorizontal: 10,
    marginVertical: 5,
    borderRadius: 8,
  },
  textoMensagem: {
    color: '#FFF',
    fontSize: 14,
    textAlign: 'center',
  },
  listaJogadores: {
    maxHeight: 100,
    paddingHorizontal: 10,
  },
  cardJogador: {
    backgroundColor: '#16213e',
    padding: 10,
    marginHorizontal: 5,
    borderRadius: 8,
    minWidth: 120,
    borderWidth: 2,
    borderColor: 'transparent',
  },
  cardJogadorAtivo: {
    borderColor: '#4fc3f7',
  },
  cardJogadorEmergencia: {
    borderColor: '#ff9800',
  },
  cardJogadorEliminado: {
    borderColor: '#f44336',
    opacity: 0.6,
  },
  nomeJogador: {
    color: '#FFF',
    fontSize: 12,
    fontWeight: 'bold',
  },
  saldoJogador: {
    color: '#4caf50',
    fontSize: 18,
    fontWeight: 'bold',
    marginTop: 4,
  },
  emergencia: {
    color: '#ff9800',
    fontSize: 10,
    marginTop: 4,
  },
  eliminado: {
    color: '#f44336',
    fontSize: 10,
    marginTop: 4,
  },
  badgeIA: {
    position: 'absolute',
    top: 5,
    right: 5,
    fontSize: 12,
  },
  areaPrincipal: {
    flex: 1,
    padding: 10,
  },
  botaoLog: {
    padding: 8,
    backgroundColor: '#0f3460',
    borderRadius: 5,
    marginBottom: 10,
  },
  textoLog: {
    color: '#4fc3f7',
    fontSize: 12,
  },
  logContainer: {
    maxHeight: 100,
    backgroundColor: '#0a0a1a',
    padding: 8,
    borderRadius: 5,
    marginBottom: 10,
  },
  logTexto: {
    color: '#888',
    fontSize: 10,
    marginBottom: 2,
  },
  infoCartaSelecionada: {
    backgroundColor: '#0f3460',
    padding: 10,
    borderRadius: 8,
  },
  tituloInfo: {
    color: '#4fc3f7',
    fontSize: 12,
    marginBottom: 4,
  },
  nomeInfo: {
    color: '#FFF',
    fontSize: 16,
    fontWeight: 'bold',
  },
  descricaoInfo: {
    color: '#AAA',
    fontSize: 12,
    marginTop: 4,
  },
  riscoInfo: {
    color: '#ff9800',
    fontSize: 12,
    marginTop: 4,
  },
  bonusInfo: {
    color: '#4caf50',
    fontSize: 12,
    marginTop: 4,
  },
  areaAcoes: {
    flexDirection: 'row',
    justifyContent: 'center',
    padding: 10,
    gap: 10,
  },
  botaoAcao: {
    paddingHorizontal: 20,
    paddingVertical: 12,
    borderRadius: 8,
    minWidth: 140,
    alignItems: 'center',
  },
  botaoJogar: {
    backgroundColor: '#4caf50',
  },
  botaoPassar: {
    backgroundColor: '#ff9800',
  },
  botaoDesabilitado: {
    backgroundColor: '#666',
    opacity: 0.5,
  },
  textoBotaoAcao: {
    color: '#FFF',
    fontSize: 14,
    fontWeight: 'bold',
  },
  modoDescarte: {
    backgroundColor: '#f44336',
    paddingHorizontal: 20,
    paddingVertical: 12,
    borderRadius: 8,
  },
  textoModoDescarte: {
    color: '#FFF',
    fontSize: 14,
    fontWeight: 'bold',
  },
  maoContainer: {
    backgroundColor: '#0a0a1a',
    padding: 10,
    borderTopWidth: 1,
    borderTopColor: '#333',
  },
  tituloMao: {
    color: '#4fc3f7',
    fontSize: 12,
    marginBottom: 8,
  },
  maoScroll: {
    flexDirection: 'row',
  },
  telaFim: {
    ...StyleSheet.absoluteFillObject,
    backgroundColor: 'rgba(0,0,0,0.9)',
    justifyContent: 'center',
    alignItems: 'center',
  },
  cardFim: {
    backgroundColor: '#16213e',
    padding: 30,
    borderRadius: 15,
    alignItems: 'center',
    borderWidth: 3,
    borderColor: '#4fc3f7',
  },
  tituloFim: {
    color: '#FFF',
    fontSize: 24,
    fontWeight: 'bold',
    marginBottom: 20,
  },
  vencedorFim: {
    color: '#4caf50',
    fontSize: 20,
    fontWeight: 'bold',
    marginBottom: 10,
  },
  saldoFim: {
    color: '#FFF',
    fontSize: 16,
    marginBottom: 20,
  },
  textoFim: {
    color: '#ff9800',
    fontSize: 20,
    fontWeight: 'bold',
    marginBottom: 20,
  },
  botaoJogarNovamente: {
    backgroundColor: '#4fc3f7',
    paddingHorizontal: 30,
    paddingVertical: 15,
    borderRadius: 10,
  },
  textoBotaoJogar: {
    color: '#000',
    fontSize: 16,
    fontWeight: 'bold',
  },
  carregando: {
    color: '#FFF',
    fontSize: 18,
    textAlign: 'center',
    marginTop: 50,
  },
});

export default TelaJogo;
