import React from 'react';
import { View, StyleSheet } from 'react-native';
import Text from '../Texto';
import { TIPO_CARTA } from '../../cards/cartasTGA';

const COR_TIPO = {
  [TIPO_CARTA.ACAO]: '#C62828',
  [TIPO_CARTA.EFEITO]: '#1565C0',
  [TIPO_CARTA.PROTECAO]: '#2E7D32',
  [TIPO_CARTA.CORINGA]: '#6A1B9A',
};

const COR_PADRAO = '#FFD54F';

function corDoTipo(carta) {
  return COR_TIPO[carta?.tipo] || COR_PADRAO;
}

function rotuloChance(carta) {
  const chance = typeof carta?.chanceSucesso === 'number' ? carta.chanceSucesso : 1;
  return `${Math.round(chance * 100)}%`;
}

// Face textual para cartas que ainda nao tem arte: nome + descricao
// (usada na mao, 68x96, e no topo do descarte, 64x90).
export function CartaFaceMini({ carta, style }) {
  if (!carta) return null;
  const cor = corDoTipo(carta);

  return (
    <View style={[styles.mini, { borderColor: cor }, style]}>
      <View style={[styles.miniTopo, { backgroundColor: cor }]}>
        <Text style={styles.miniTitulo} numberOfLines={2}>
          {carta.titulo}
        </Text>
        <View style={styles.miniChanceBadge}>
          <Text style={styles.miniChanceTexto}>{rotuloChance(carta)}</Text>
        </View>
      </View>
      <Text style={styles.miniDescricao} numberOfLines={7}>
        {carta.descricao}
      </Text>
      <View style={styles.miniRodape}>
        <Text style={[styles.miniTipo, { color: cor }]} numberOfLines={1}>
          {carta.tipo}
        </Text>
      </View>
    </View>
  );
}

// Face textual completa para o zoom (200x280): tudo que a planilha traz.
export function CartaFaceCompleta({ carta, style }) {
  if (!carta) return null;
  const cor = corDoTipo(carta);

  return (
    <View style={[styles.completa, style]}>
      <View style={[styles.completaBarra, { backgroundColor: cor }]} />
      <Text style={styles.completaTitulo} numberOfLines={2}>
        {carta.titulo}
      </Text>
      {!!carta.subtitulo && (
        <Text style={styles.completaSubtitulo} numberOfLines={2}>
          {carta.subtitulo}
        </Text>
      )}

      <View style={styles.completaMetaLinha}>
        <View style={[styles.completaBadge, { backgroundColor: cor }]}>
          <Text style={styles.completaBadgeTexto}>{carta.tipo}</Text>
        </View>
        <Text style={styles.completaChance}>CHANCE {rotuloChance(carta)}</Text>
      </View>
      {!!carta.alvoTexto && (
        <Text style={styles.completaAlvo}>ALVO: {carta.alvoTexto}</Text>
      )}

      <View style={styles.completaDivisor} />

      <Text style={styles.completaLabel}>DESCRICAO</Text>
      <Text style={styles.completaDescricao} numberOfLines={7}>
        {carta.descricao}
      </Text>

      {!!carta.efeitoTexto && (
        <View style={styles.completaEfeitoBox}>
          <Text style={styles.completaLabel}>EFETO</Text>
          <Text style={styles.completaEfeito} numberOfLines={3}>
            {carta.efeitoTexto}
          </Text>
        </View>
      )}

      <View style={styles.completaRodape}>
        <Text style={styles.completaRodapeLabel}>DURACAO</Text>
        <Text style={styles.completaRodapeValor} numberOfLines={1}>
          {carta.duracionTexto || '-'}
        </Text>
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  // ---------- mini (mao / descarte) ----------
  mini: {
    flex: 1,
    backgroundColor: '#141A2E',
    borderWidth: 1,
    borderRadius: 4,
    paddingHorizontal: 3,
    paddingTop: 2,
    paddingBottom: 2,
    overflow: 'hidden',
  },
  miniTopo: {
    flexDirection: 'row',
    alignItems: 'flex-start',
    borderRadius: 2,
    paddingHorizontal: 2,
    paddingVertical: 1,
    gap: 2,
  },
  miniTitulo: {
    flex: 1,
    color: '#FFF8E7',
    fontSize: 7,
    lineHeight: 8,
  },
  miniChanceBadge: {
    backgroundColor: 'rgba(0, 0, 0, 0.35)',
    borderRadius: 2,
    paddingHorizontal: 2,
    paddingVertical: 1,
  },
  miniChanceTexto: {
    color: '#FFD54F',
    fontSize: 6,
  },
  miniDescricao: {
    flex: 1,
    color: '#CFD6E6',
    fontSize: 6,
    lineHeight: 7,
    marginTop: 2,
    overflow: 'hidden',
  },
  miniRodape: {
    alignItems: 'center',
  },
  miniTipo: {
    fontSize: 5.5,
    letterSpacing: 0.5,
  },

  // ---------- completa (zoom) ----------
  completa: {
    flex: 1,
    backgroundColor: '#141A2E',
    paddingHorizontal: 8,
    paddingTop: 6,
    paddingBottom: 8,
    overflow: 'hidden',
  },
  completaBarra: {
    height: 5,
    borderRadius: 2,
    marginBottom: 6,
  },
  completaTitulo: {
    color: '#FFD54F',
    fontSize: 13,
    lineHeight: 15,
  },
  completaSubtitulo: {
    color: '#9AA4C0',
    fontSize: 8,
    lineHeight: 10,
    fontStyle: 'italic',
    marginTop: 2,
  },
  completaMetaLinha: {
    flexDirection: 'row',
    alignItems: 'center',
    marginTop: 6,
    gap: 6,
  },
  completaBadge: {
    borderRadius: 3,
    paddingHorizontal: 5,
    paddingVertical: 2,
  },
  completaBadgeTexto: {
    color: '#FFF',
    fontSize: 7,
    letterSpacing: 1,
  },
  completaChance: {
    color: '#FFD54F',
    fontSize: 8,
  },
  completaAlvo: {
    color: '#AAB0D0',
    fontSize: 7,
    marginTop: 3,
  },
  completaDivisor: {
    height: 1,
    backgroundColor: '#FFD54F',
    opacity: 0.35,
    marginVertical: 5,
  },
  completaLabel: {
    color: '#7C8AAC',
    fontSize: 6.5,
    letterSpacing: 1.5,
    marginBottom: 2,
  },
  completaDescricao: {
    flex: 1,
    color: '#E4E9F5',
    fontSize: 8.5,
    lineHeight: 11,
    overflow: 'hidden',
  },
  completaEfeitoBox: {
    backgroundColor: 'rgba(255, 213, 79, 0.08)',
    borderRadius: 4,
    borderWidth: 1,
    borderColor: 'rgba(255, 213, 79, 0.35)',
    paddingHorizontal: 5,
    paddingVertical: 3,
    marginTop: 5,
  },
  completaEfeito: {
    color: '#FFE082',
    fontSize: 7.5,
    lineHeight: 9.5,
  },
  completaRodape: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    marginTop: 5,
    gap: 6,
  },
  completaRodapeLabel: {
    color: '#7C8AAC',
    fontSize: 6.5,
    letterSpacing: 1.5,
  },
  completaRodapeValor: {
    flex: 1,
    color: '#FFD54F',
    fontSize: 7.5,
    textAlign: 'right',
  },
});

export default CartaFaceMini;
