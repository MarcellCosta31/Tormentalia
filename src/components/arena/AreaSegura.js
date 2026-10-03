import React, { useState } from 'react';
import { View, StyleSheet, Pressable, Image, Dimensions } from 'react-native';
import Text from '../Texto';
import CartaArena from './CartaArena';

const { width: SCREEN_WIDTH, height: SCREEN_HEIGHT } = Dimensions.get('window');
const AREA_CARD_W = 56;
const AREA_CARD_H = 78;
const LONG_PRESS_ZOOM_MS = 600;

export default function AreaSegura({ jogador, isMinhaVez, proprio, onJogarCartaArea, cartasSelecionadasArea, topo, onZoomCarta }) {
  const areaCards = jogador?.areaSegura || [];
  const [selecionadaUid, setSelecionadaUid] = useState(null);

  // Área própria = posso ver/selecionar/usar a carta, mesmo fora do meu turno.
  const isOwner = proprio ?? isMinhaVez;
  const cartaSelecionada = areaCards.find((c) => c.uid === selecionadaUid) || null;

  const handleLongPress = (carta) => {
    if (onZoomCarta) onZoomCarta(carta);
  };

  const handlePress = (carta) => {
    if (!isOwner) return;
    setSelecionadaUid((prev) => (prev === carta.uid ? null : carta.uid));
  };

  const handleUsar = () => {
    if (!cartaSelecionada || !onJogarCartaArea) return;
    const carta = cartaSelecionada;
    setSelecionadaUid(null);
    onJogarCartaArea(jogador.id, carta.uid);
  };

  return (
    <View style={[styles.container, topo && styles.containerTopo]}>
      <View style={styles.areaCardsRow}>
        {areaCards.length === 0 ? (
          <View style={[styles.slotVazio, { width: AREA_CARD_W, height: AREA_CARD_H }]}>
            <Text style={styles.slotVazioTexto}>VAZIA</Text>
          </View>
        ) : (
          areaCards.map((carta) => {
            const isSelected =
              selecionadaUid === carta.uid ||
              !!cartasSelecionadasArea?.some((c) => c.uid === carta.uid);
            return (
              <Pressable
                key={carta.uid}
                onPress={() => handlePress(carta)}
                onLongPress={() => handleLongPress(carta)}
                delayLongPress={LONG_PRESS_ZOOM_MS}
              >
                <View style={[
                  styles.cartaSlot,
                  { width: AREA_CARD_W, height: AREA_CARD_H },
                  isSelected && styles.cartaSlotSelecionada,
                  !isOwner && styles.cartaSlotOponente,
                ]}>
                  {isOwner ? (
                    <CartaArena
                      carta={carta}
                      onPress={() => {}}
                      desabilitada={!isOwner}
                      largura={AREA_CARD_W}
                      altura={AREA_CARD_H}
                    />
                  ) : (
                    <View style={styles.cartaTraseira}>
                      <Image
                        source={require('../../assets/cards/traseira_cartas.jpg')}
                        style={styles.cartaTraseiraImg}
                        resizeMode="cover"
                      />
                    </View>
                  )}
                </View>
              </Pressable>
            );
          })
        )}
      </View>

      {isOwner && cartaSelecionada && (
        <Pressable style={styles.botaoUsar} onPress={handleUsar} hitSlop={8}>
          <Text style={styles.botaoUsarTexto}>USAR</Text>
        </Pressable>
      )}
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    position: 'absolute',
    right: '25%',
    bottom: 12,
    zIndex: 26,
    alignItems: 'center',
  },
  containerTopo: {
    position: 'absolute',
    right: '25%',
    top: 20,
    zIndex: 26,
    alignItems: 'center',
  },
  labelRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 4,
    marginBottom: 4,
  },
  botaoUsar: {
    marginTop: 4,
    paddingHorizontal: 8,
    paddingVertical: 2,
    borderRadius: 4,
    backgroundColor: '#1565C0',
    borderWidth: 1,
    borderColor: '#42A5F5',
    alignItems: 'center',
    justifyContent: 'center',
    elevation: 4,
    zIndex: 27,
  },
  botaoUsarTexto: {
    color: '#FFF',
    fontSize: 8,
    fontWeight: 'bold',
    letterSpacing: 1,
  },
  label: {
    color: '#FFD54F',
    fontSize: 8,
    fontWeight: 'bold',
    letterSpacing: 1.5,
  },
  count: {
    color: '#FFD54F',
    fontSize: 8,
    fontWeight: 'bold',
    backgroundColor: 'rgba(255,213,79,0.2)',
    borderRadius: 6,
    paddingHorizontal: 4,
    overflow: 'hidden',
  },
  areaCardsRow: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    justifyContent: 'center',
    gap: 4,
  },
  slotVazio: {
    borderWidth: 1.5,
    borderColor: 'rgba(255,213,79,0.3)',
    borderStyle: 'dashed',
    borderRadius: 6,
    backgroundColor: 'rgba(128,128,128,0.15)',
    alignItems: 'center',
    justifyContent: 'center',
  },
  slotVazioTexto: {
    color: 'rgba(255,213,79,0.4)',
    fontSize: 7,
    fontWeight: 'bold',
  },
  cartaSlot: {
    borderRadius: 6,
    overflow: 'hidden',
    justifyContent: 'center',
    alignItems: 'center',
  },
  cartaSlotSelecionada: {
    borderWidth: 3,
    borderColor: '#FFD54F',
    shadowColor: '#FFD54F',
    shadowOffset: { width: 0, height: 0 },
    shadowOpacity: 0.8,
    shadowRadius: 8,
    elevation: 15,
  },
  cartaSlotOponente: {
    borderWidth: 1,
    borderColor: 'rgba(255,255,255,0.2)',
    opacity: 0.7,
  },
  cartaTraseira: {
    width: '100%',
    height: '100%',
    borderRadius: 6,
    overflow: 'hidden',
  },
  cartaTraseiraImg: {
    width: '100%',
    height: '100%',
  },
});