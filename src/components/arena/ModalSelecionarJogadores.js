import React, { useEffect } from 'react';
import {
  View,
  Text,
  StyleSheet,
  Modal,
  TouchableOpacity,
  Dimensions,
} from 'react-native';
import Animated, {
  useSharedValue,
  useAnimatedStyle,
  withTiming,
  withSequence,
} from 'react-native-reanimated';

const { width: W } = Dimensions.get('window');

const PLAYER_COLORS = [
  '#FFD54F',
  '#EF5350',
  '#42A5F5',
  '#66BB6A',
  '#AB47BC',
  '#FF7043',
  '#26C6DA',
  '#EC407A',
];

const PLAYER_EMOJIS = ['👑', '🤖', '🦊', '🐉', '🎭', '🦁', '🌙', '⚡'];

function BotaoQuantidade({ quantidade, onPress }) {
  const scaleAnim = useSharedValue(1);

  const animatedStyle = useAnimatedStyle(() => ({
    transform: [{ scale: scaleAnim.value }],
  }));

  const handlePress = () => {
    scaleAnim.value = withSequence(
      withTiming(0.92, { duration: 80 }),
      withTiming(1, { duration: 80 }),
      () => {
        'worklet';
        onPress(quantidade);
      },
    );
  };

  // Pequenos avatares para representar os jogadores
  const avatarSize = Math.min(18, Math.floor(52 / quantidade));

  return (
    <Animated.View style={animatedStyle}>
      <TouchableOpacity
        style={styles.botaoQuantidade}
        onPress={handlePress}
        activeOpacity={1}
      >
        {/* Linha de avatares */}
        <View style={styles.avatarRow}>
          {Array.from({ length: quantidade }).map((_, i) => (
            <View
              key={i}
              style={[
                styles.avatarMini,
                {
                  backgroundColor: PLAYER_COLORS[i] + '22',
                  borderColor: PLAYER_COLORS[i],
                  width: avatarSize + 4,
                  height: avatarSize + 4,
                  borderRadius: (avatarSize + 4) / 2,
                },
              ]}
            >
              <Text style={{ fontSize: avatarSize - 2 }}>{PLAYER_EMOJIS[i]}</Text>
            </View>
          ))}
        </View>

        {/* Número + label */}
        <View style={styles.botaoInfo}>
          <Text style={styles.botaoNumero}>{quantidade}</Text>
          <Text style={styles.botaoLabel}>
            {quantidade === 2 ? 'DUELO' : quantidade <= 4 ? 'BATALHA' : quantidade <= 6 ? 'GUERRA' : 'CAOS TOTAL'}
          </Text>
        </View>

        {/* Seta */}
        <Text style={styles.seta}>▶</Text>
      </TouchableOpacity>
    </Animated.View>
  );
}

export default function ModalSelecionarJogadores({ visivel, onFechar, onSelecionarQuantidade }) {
  const slideAnim = useSharedValue(300);
  const opacityAnim = useSharedValue(0);

  const containerStyle = useAnimatedStyle(() => ({
    opacity: opacityAnim.value,
    transform: [{ translateY: slideAnim.value }],
  }));

  useEffect(() => {
    if (visivel) {
      slideAnim.value = withTiming(0, { duration: 300 });
      opacityAnim.value = withTiming(1, { duration: 300 });
    } else {
      slideAnim.value = withTiming(300, { duration: 200 });
      opacityAnim.value = withTiming(0, { duration: 200 });
    }
  }, [visivel]);

  return (
    <Modal
      visible={visivel}
      transparent
      animationType="none"
      onRequestClose={onFechar}
    >
      <TouchableOpacity style={styles.overlay} onPress={onFechar} activeOpacity={1}>
        <Animated.View
          style={[styles.container, containerStyle]}
        >
          {/* Cantos decorativos */}
          <View style={[styles.canto, styles.cantoTL]} />
          <View style={[styles.canto, styles.cantoTR]} />
          <View style={[styles.canto, styles.cantoBL]} />
          <View style={[styles.canto, styles.cantoBR]} />

          {/* Header */}
          <View style={styles.header}>
            <Text style={styles.titulo}>⚔️ ARENA</Text>
            <Text style={styles.subtitulo}>Quantos jogadores?</Text>
          </View>

          <View style={styles.divisor} />

          {/* Lista de opções */}
          <View style={styles.lista}>
            {[2, 3, 4, 5, 6, 7, 8].map((q) => (
              <BotaoQuantidade
                key={q}
                quantidade={q}
                onPress={(n) => {
                  onFechar();
                  setTimeout(() => onSelecionarQuantidade(n), 150);
                }}
              />
            ))}
          </View>

          {/* Botão fechar */}
          <TouchableOpacity style={styles.botaoFechar} onPress={onFechar} activeOpacity={0.7}>
            <Text style={styles.botaoFecharTexto}>CANCELAR</Text>
          </TouchableOpacity>
        </Animated.View>
      </TouchableOpacity>
    </Modal>
  );
}

const CANTO = 10;

const styles = StyleSheet.create({
  overlay: {
    flex: 1,
    backgroundColor: 'rgba(0,0,0,0.82)',
    alignItems: 'center',
    justifyContent: 'center',
  },
  container: {
    backgroundColor: '#0F1322',
    borderRadius: 14,
    borderWidth: 2,
    borderColor: '#7A5C29',
    padding: 20,
    width: Math.min(W * 0.88, 360),
    position: 'relative',
  },
  // Cantos decorativos pixel-art
  canto: {
    position: 'absolute',
    width: CANTO,
    height: CANTO,
    borderColor: '#FFD54F',
  },
  cantoTL: { top: -2, left: -2, borderTopWidth: 2, borderLeftWidth: 2 },
  cantoTR: { top: -2, right: -2, borderTopWidth: 2, borderRightWidth: 2 },
  cantoBL: { bottom: -2, left: -2, borderBottomWidth: 2, borderLeftWidth: 2 },
  cantoBR: { bottom: -2, right: -2, borderBottomWidth: 2, borderRightWidth: 2 },
  header: {
    alignItems: 'center',
    marginBottom: 6,
  },
  titulo: {
    color: '#FFD54F',
    fontSize: 22,
    fontWeight: 'bold',
    letterSpacing: 3,
  },
  subtitulo: {
    color: '#AAB0D0',
    fontSize: 12,
    letterSpacing: 1,
    marginTop: 2,
  },
  divisor: {
    height: 1,
    backgroundColor: '#FFD54F',
    opacity: 0.25,
    marginVertical: 14,
  },
  lista: {
    gap: 8,
  },
  botaoQuantidade: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: 'rgba(255,255,255,0.05)',
    borderRadius: 10,
    borderWidth: 1,
    borderColor: '#3A3A5C',
    paddingVertical: 9,
    paddingHorizontal: 12,
    gap: 10,
  },
  avatarRow: {
    flexDirection: 'row',
    gap: 3,
    width: 100,
    flexWrap: 'nowrap',
    overflow: 'hidden',
  },
  avatarMini: {
    borderWidth: 1.5,
    alignItems: 'center',
    justifyContent: 'center',
  },
  botaoInfo: {
    flex: 1,
  },
  botaoNumero: {
    color: '#FFD54F',
    fontSize: 16,
    fontWeight: 'bold',
    letterSpacing: 1,
  },
  botaoLabel: {
    color: '#AAB0D0',
    fontSize: 9,
    letterSpacing: 1.5,
    marginTop: 1,
  },
  seta: {
    color: '#FFD54F',
    fontSize: 12,
    opacity: 0.6,
  },
  botaoFechar: {
    marginTop: 16,
    backgroundColor: 'rgba(198,40,40,0.2)',
    borderWidth: 1,
    borderColor: '#C62828',
    borderRadius: 8,
    paddingVertical: 11,
    alignItems: 'center',
  },
  botaoFecharTexto: {
    color: '#EF5350',
    fontWeight: 'bold',
    fontSize: 13,
    letterSpacing: 1.5,
  },
});
