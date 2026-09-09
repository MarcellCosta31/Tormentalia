import React, { useState, useRef, useEffect } from 'react';
import {
  View,
  Text,
  StyleSheet,
  Image,
  Dimensions,
  TouchableOpacity,
  Modal,
  Animated,
  ScrollView,
} from 'react-native';

const bgImg = require('../assets/sprites/batalha/background.png');
const traseiraImg = require('../assets/cards/traseira_cartas.jpg');
const pauseImg = require('../assets/sprites/menu/pause.jpg');

const { width: W, height: H } = Dimensions.get('window');

// Paleta de cores por jogador
const PLAYER_COLORS = [
  '#FFD54F', // ouro
  '#EF5350', // vermelho
  '#42A5F5', // azul
  '#66BB6A', // verde
  '#AB47BC', // roxo
  '#FF7043', // laranja
  '#26C6DA', // ciano
  '#EC407A', // rosa
];

const PLAYER_EMOJIS = ['👑', '🤖', '🦊', '🐉', '🎭', '🦁', '🌙', '⚡'];

// Gera jogadores fictícios para a tela de teste
function gerarJogadores(quantidade) {
  const nomes = ['VOCÊ', 'ROBÔ', 'RAPOSA', 'DRAGÃO', 'MÁSCARA', 'LEÃO', 'LUA', 'RAIO'];
  return Array.from({ length: quantidade }, (_, i) => ({
    id: i + 1,
    nome: nomes[i] || `JOGADOR ${i + 1}`,
    saldo: Math.floor(Math.random() * 30) + 10,
    cartas: Math.floor(Math.random() * 5) + 1,
    cor: PLAYER_COLORS[i],
    emoji: PLAYER_EMOJIS[i],
    ativo: i === 0,
    eliminado: false,
  }));
}

// Posições ao redor da mesa (círculo)
function calcularPosicoes(n) {
  const cx = W / 2;
  const cy = H / 2;
  // Raio elíptico ajustado para caber na tela
  const rx = W * 0.36;
  const ry = H * 0.36;

  return Array.from({ length: n }, (_, i) => {
    // Começa de baixo (jogador local) e vai no sentido horário
    const angulo = (Math.PI / 2) + (2 * Math.PI * i) / n;
    const x = cx + rx * Math.cos(angulo);
    const y = cy + ry * Math.sin(angulo);
    return { x, y };
  });
}

function MiniCarta({ cor, rotacao = 0 }) {
  return (
    <View
      style={[
        styles.miniCarta,
        {
          borderColor: cor,
          transform: [{ rotate: `${rotacao}deg` }],
        },
      ]}
    >
      <Image source={traseiraImg} style={styles.miniCartaImg} resizeMode="cover" />
    </View>
  );
}

function SlotJogador({ jogador, posicao, isLocal, turnoAtual }) {
  const pulseAnim = useRef(new Animated.Value(1)).current;

  useEffect(() => {
    if (jogador.ativo) {
      Animated.loop(
        Animated.sequence([
          Animated.timing(pulseAnim, { toValue: 1.12, duration: 600, useNativeDriver: true }),
          Animated.timing(pulseAnim, { toValue: 1, duration: 600, useNativeDriver: true }),
        ])
      ).start();
    } else {
      pulseAnim.setValue(1);
    }
  }, [jogador.ativo]);

  const SLOT_W = isLocal ? 110 : 90;
  const SLOT_H = isLocal ? 80 : 65;

  return (
    <Animated.View
      style={[
        styles.slotJogador,
        {
          left: posicao.x - SLOT_W / 2,
          top: posicao.y - SLOT_H / 2,
          width: SLOT_W,
          height: SLOT_H,
          borderColor: jogador.cor,
          transform: [{ scale: pulseAnim }],
          opacity: jogador.eliminado ? 0.4 : 1,
        },
      ]}
    >
      {/* Badge turno ativo */}
      {jogador.ativo && (
        <View style={[styles.badgeAtivo, { backgroundColor: jogador.cor }]}>
          <Text style={styles.badgeAtivoTexto}>VEZ</Text>
        </View>
      )}

      {/* Avatar + Nome */}
      <View style={styles.slotTop}>
        <View style={[styles.avatarCirculo, { borderColor: jogador.cor }]}>
          <Text style={styles.avatarEmoji}>{jogador.emoji}</Text>
        </View>
        <Text style={[styles.nomeJogador, { color: jogador.cor }]} numberOfLines={1}>
          {jogador.nome}
        </Text>
      </View>

      {/* Saldo */}
      <View style={styles.slotSaldo}>
        <Text style={styles.saldoLabel}>R$</Text>
        <Text style={[styles.saldoValor, { color: jogador.saldo > 10 ? '#66BB6A' : jogador.saldo > 5 ? '#FFD54F' : '#EF5350' }]}>
          {jogador.saldo}
        </Text>
        <Text style={styles.saldoMoeda}>🪙</Text>
      </View>

      {/* Cartas na mão (mini) */}
      <View style={styles.miniCartasRow}>
        {Array.from({ length: Math.min(jogador.cartas, 5) }).map((_, ci) => (
          <MiniCarta key={ci} cor={jogador.cor} rotacao={(ci - 2) * 8} />
        ))}
      </View>

      {/* Eliminado overlay */}
      {jogador.eliminado && (
        <View style={styles.eliminadoOverlay}>
          <Text style={styles.eliminadoTexto}>💀 FALIU</Text>
        </View>
      )}
    </Animated.View>
  );
}

function MesaCentral({ jogadores }) {
  const rotAnim = useRef(new Animated.Value(0)).current;

  useEffect(() => {
    Animated.loop(
      Animated.timing(rotAnim, { toValue: 1, duration: 30000, useNativeDriver: true })
    ).start();
  }, []);

  const rot = rotAnim.interpolate({ inputRange: [0, 1], outputRange: ['0deg', '360deg'] });

  return (
    <View style={styles.mesaCentral}>
      {/* Círculo externo girando */}
      <Animated.View style={[styles.mesaCirculoExt, { transform: [{ rotate: rot }] }]} />
      <View style={styles.mesaCirculoInt}>
        <Text style={styles.mesaEmoji}>⚔️</Text>
        <Text style={styles.mesaTitulo}>ARENA</Text>
        <Text style={styles.mesaSubtitulo}>{jogadores.length}v{jogadores.length}</Text>

        {/* Pilha descarte */}
        <View style={styles.pilhaDescarte}>
          <Image source={traseiraImg} style={styles.pilhaCartaImg} resizeMode="cover" />
          <Image source={traseiraImg} style={[styles.pilhaCartaImg, styles.pilhaCarta2]} resizeMode="cover" />
          <Image source={traseiraImg} style={[styles.pilhaCartaImg, styles.pilhaCarta3]} resizeMode="cover" />
        </View>
      </View>
    </View>
  );
}

export default function ArenaMultiplayer({ quantidade = 4, onVoltar }) {
  const [jogadores, setJogadores] = useState(() => gerarJogadores(quantidade));
  const [turnoAtual, setTurnoAtual] = useState(1);
  const [jogadorAtivoIdx, setJogadorAtivoIdx] = useState(0);
  const [modalPausa, setModalPausa] = useState(false);

  const posicoes = calcularPosicoes(quantidade);

  const passarTurno = () => {
    const novoIdx = (jogadorAtivoIdx + 1) % quantidade;
    setJogadorAtivoIdx(novoIdx);
    setTurnoAtual(t => (novoIdx === 0 ? t + 1 : t));
    setJogadores(prev =>
      prev.map((j, i) => ({ ...j, ativo: i === novoIdx }))
    );
  };

  return (
    <View style={styles.container}>
      <Image source={bgImg} style={styles.bg} resizeMode="cover" />

      {/* Overlay escuro gradiente */}
      <View style={styles.overlay} />

      {/* Header */}
      <View style={styles.header}>
        <View style={styles.headerInfo}>
          <Text style={styles.headerTitulo}>⚔️ ARENA {quantidade}v{quantidade}</Text>
          <Text style={styles.headerTurno}>TURNO {turnoAtual}</Text>
        </View>
        <TouchableOpacity style={styles.botaoPausa} onPress={() => setModalPausa(true)} activeOpacity={0.7}>
          <Image source={pauseImg} style={styles.pauseIcon} resizeMode="contain" />
        </TouchableOpacity>
      </View>

      {/* Mesa central */}
      <MesaCentral jogadores={jogadores} />

      {/* Slots dos jogadores ao redor */}
      {jogadores.map((jogador, i) => (
        <SlotJogador
          key={jogador.id}
          jogador={jogador}
          posicao={posicoes[i]}
          isLocal={i === 0}
          turnoAtual={turnoAtual}
        />
      ))}

      {/* Botões de ação (apenas para jogador local quando é sua vez) */}
      {jogadores[0].ativo && (
        <View style={styles.acoesContainer}>
          <TouchableOpacity style={[styles.botaoAcao, styles.botaoJogar]} activeOpacity={0.8}>
            <Text style={styles.botaoAcaoTexto}>🃏 JOGAR</Text>
          </TouchableOpacity>
          <TouchableOpacity style={[styles.botaoAcao, styles.botaoPassar]} onPress={passarTurno} activeOpacity={0.8}>
            <Text style={styles.botaoAcaoTexto}>⏭️ PASSAR</Text>
          </TouchableOpacity>
        </View>
      )}

      {/* Legenda: quantidade de jogadores */}
      <View style={styles.legendaContainer}>
        <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={styles.legendaScroll}>
          {jogadores.map((j) => (
            <View key={j.id} style={[styles.legendaItem, j.ativo && { borderColor: j.cor, borderWidth: 1.5 }]}>
              <Text style={styles.legendaEmoji}>{j.emoji}</Text>
              <Text style={[styles.legendaNome, { color: j.cor }]}>{j.nome}</Text>
              <Text style={styles.legendaSaldo}>R${j.saldo}</Text>
            </View>
          ))}
        </ScrollView>
      </View>

      {/* Modal Pausa */}
      <Modal visible={modalPausa} transparent animationType="fade" onRequestClose={() => setModalPausa(false)}>
        <View style={styles.modalOverlay}>
          <View style={styles.modalContainer}>
            <Text style={styles.modalTitulo}>PAUSA</Text>
            <View style={styles.modalDivisor} />
            <TouchableOpacity style={[styles.modalBotao, styles.modalContinuar]} onPress={() => setModalPausa(false)} activeOpacity={0.7}>
              <Text style={styles.modalBotaoTexto}>CONTINUAR</Text>
            </TouchableOpacity>
            <TouchableOpacity style={[styles.modalBotao, styles.modalSair]} onPress={onVoltar} activeOpacity={0.7}>
              <Text style={styles.modalBotaoTexto}>SAIR</Text>
            </TouchableOpacity>
          </View>
        </View>
      </Modal>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#0A0A1A',
  },
  bg: {
    position: 'absolute',
    width: '100%',
    height: '100%',
  },
  overlay: {
    position: 'absolute',
    width: '100%',
    height: '100%',
    backgroundColor: 'rgba(0,0,0,0.45)',
  },
  header: {
    position: 'absolute',
    top: 0,
    left: 0,
    right: 0,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingHorizontal: 14,
    paddingTop: 12,
    paddingBottom: 8,
    backgroundColor: 'rgba(10,10,26,0.75)',
    borderBottomWidth: 1,
    borderBottomColor: '#FFD54F44',
    zIndex: 50,
  },
  headerInfo: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 12,
  },
  headerTitulo: {
    color: '#FFD54F',
    fontSize: 16,
    fontWeight: 'bold',
    letterSpacing: 1.5,
  },
  headerTurno: {
    color: '#AAB0D0',
    fontSize: 13,
    fontWeight: 'bold',
    letterSpacing: 1,
    backgroundColor: 'rgba(255,255,255,0.08)',
    paddingHorizontal: 10,
    paddingVertical: 3,
    borderRadius: 20,
  },
  botaoPausa: {
    width: 36,
    height: 36,
    borderRadius: 18,
    backgroundColor: 'rgba(0,0,0,0.6)',
    borderWidth: 1,
    borderColor: '#FFD54F',
    alignItems: 'center',
    justifyContent: 'center',
  },
  pauseIcon: {
    width: 20,
    height: 20,
  },
  // Mesa central
  mesaCentral: {
    position: 'absolute',
    left: W / 2 - 70,
    top: H / 2 - 70,
    width: 140,
    height: 140,
    alignItems: 'center',
    justifyContent: 'center',
    zIndex: 5,
  },
  mesaCirculoExt: {
    position: 'absolute',
    width: 140,
    height: 140,
    borderRadius: 70,
    borderWidth: 2,
    borderColor: '#FFD54F',
    borderStyle: 'dashed',
  },
  mesaCirculoInt: {
    width: 120,
    height: 120,
    borderRadius: 60,
    backgroundColor: 'rgba(15,19,34,0.92)',
    borderWidth: 2,
    borderColor: '#7A5C29',
    alignItems: 'center',
    justifyContent: 'center',
  },
  mesaEmoji: {
    fontSize: 22,
  },
  mesaTitulo: {
    color: '#FFD54F',
    fontSize: 13,
    fontWeight: 'bold',
    letterSpacing: 2,
  },
  mesaSubtitulo: {
    color: '#AAB0D0',
    fontSize: 10,
    letterSpacing: 1,
    marginTop: 2,
  },
  pilhaDescarte: {
    marginTop: 6,
    position: 'relative',
    width: 32,
    height: 44,
  },
  pilhaCartaImg: {
    position: 'absolute',
    width: 28,
    height: 40,
    borderRadius: 3,
    borderWidth: 1,
    borderColor: '#FFD54F',
    top: 0,
    left: 0,
  },
  pilhaCarta2: {
    top: -2,
    left: 2,
    transform: [{ rotate: '5deg' }],
  },
  pilhaCarta3: {
    top: -4,
    left: 4,
    transform: [{ rotate: '10deg' }],
  },
  // Slot jogador
  slotJogador: {
    position: 'absolute',
    backgroundColor: 'rgba(10,10,26,0.88)',
    borderWidth: 2,
    borderRadius: 10,
    padding: 6,
    alignItems: 'center',
    zIndex: 20,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 4 },
    shadowOpacity: 0.7,
    shadowRadius: 6,
    elevation: 8,
  },
  badgeAtivo: {
    position: 'absolute',
    top: -10,
    alignSelf: 'center',
    paddingHorizontal: 8,
    paddingVertical: 2,
    borderRadius: 8,
    zIndex: 30,
  },
  badgeAtivoTexto: {
    color: '#000',
    fontSize: 9,
    fontWeight: 'bold',
    letterSpacing: 1,
  },
  slotTop: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 5,
    marginBottom: 3,
  },
  avatarCirculo: {
    width: 24,
    height: 24,
    borderRadius: 12,
    borderWidth: 1.5,
    backgroundColor: '#1C2238',
    alignItems: 'center',
    justifyContent: 'center',
  },
  avatarEmoji: {
    fontSize: 13,
  },
  nomeJogador: {
    fontSize: 10,
    fontWeight: 'bold',
    letterSpacing: 0.5,
    maxWidth: 55,
  },
  slotSaldo: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 2,
    marginBottom: 4,
  },
  saldoLabel: {
    color: '#AAB0D0',
    fontSize: 9,
    fontWeight: 'bold',
  },
  saldoValor: {
    fontSize: 12,
    fontWeight: 'bold',
  },
  saldoMoeda: {
    fontSize: 9,
  },
  miniCartasRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 2,
  },
  miniCarta: {
    width: 14,
    height: 20,
    borderRadius: 2,
    borderWidth: 1,
    overflow: 'hidden',
  },
  miniCartaImg: {
    width: '100%',
    height: '100%',
  },
  eliminadoOverlay: {
    ...StyleSheet.absoluteFillObject,
    backgroundColor: 'rgba(0,0,0,0.7)',
    borderRadius: 10,
    alignItems: 'center',
    justifyContent: 'center',
  },
  eliminadoTexto: {
    color: '#EF5350',
    fontSize: 10,
    fontWeight: 'bold',
    letterSpacing: 0.5,
  },
  // Ações locais
  acoesContainer: {
    position: 'absolute',
    bottom: 68,
    alignSelf: 'center',
    flexDirection: 'row',
    gap: 12,
    zIndex: 40,
  },
  botaoAcao: {
    paddingHorizontal: 22,
    paddingVertical: 11,
    borderRadius: 24,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 3 },
    shadowOpacity: 0.5,
    shadowRadius: 5,
    elevation: 6,
  },
  botaoJogar: {
    backgroundColor: '#2E7D32',
    borderWidth: 1.5,
    borderColor: '#66BB6A',
  },
  botaoPassar: {
    backgroundColor: '#B45309',
    borderWidth: 1.5,
    borderColor: '#FFD54F',
  },
  botaoAcaoTexto: {
    color: '#FFF',
    fontSize: 13,
    fontWeight: 'bold',
    letterSpacing: 1,
  },
  // Legenda inferior
  legendaContainer: {
    position: 'absolute',
    bottom: 0,
    left: 0,
    right: 0,
    backgroundColor: 'rgba(10,10,26,0.9)',
    borderTopWidth: 1,
    borderTopColor: '#FFD54F33',
    paddingVertical: 6,
    zIndex: 30,
  },
  legendaScroll: {
    paddingHorizontal: 10,
    gap: 8,
  },
  legendaItem: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: 'rgba(255,255,255,0.06)',
    borderRadius: 20,
    paddingHorizontal: 10,
    paddingVertical: 4,
    gap: 5,
    borderWidth: 1,
    borderColor: 'transparent',
  },
  legendaEmoji: {
    fontSize: 13,
  },
  legendaNome: {
    fontSize: 10,
    fontWeight: 'bold',
    letterSpacing: 0.5,
  },
  legendaSaldo: {
    color: '#AAB0D0',
    fontSize: 10,
  },
  // Modal pausa
  modalOverlay: {
    flex: 1,
    backgroundColor: 'rgba(0,0,0,0.85)',
    alignItems: 'center',
    justifyContent: 'center',
  },
  modalContainer: {
    backgroundColor: '#1E1E2E',
    borderRadius: 12,
    borderWidth: 2,
    borderColor: '#FFD54F',
    padding: 24,
    alignItems: 'center',
    width: 220,
  },
  modalTitulo: {
    fontSize: 24,
    color: '#FFD54F',
    fontWeight: 'bold',
    letterSpacing: 3,
    marginBottom: 8,
  },
  modalDivisor: {
    width: '80%',
    height: 1,
    backgroundColor: '#FFD54F',
    opacity: 0.4,
    marginBottom: 20,
  },
  modalBotao: {
    width: '100%',
    paddingVertical: 14,
    borderRadius: 8,
    alignItems: 'center',
    marginBottom: 12,
  },
  modalContinuar: {
    backgroundColor: '#2E7D32',
  },
  modalSair: {
    backgroundColor: '#C62828',
  },
  modalBotaoTexto: {
    color: '#FFF',
    fontWeight: 'bold',
    fontSize: 16,
    letterSpacing: 1,
  },
});
