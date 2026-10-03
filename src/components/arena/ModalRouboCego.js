import React, { useEffect, useState } from 'react';
import { Modal, View, Pressable, StyleSheet, Image } from 'react-native';
import Text from '../Texto';

// Modal do roubo AS CEGAS (carta "Essa vai ser a minha maior vigarice"):
// mostra a mao do alvo com as cartas VIRADAS PARA BAIXO. O jogador escolhe
// quais quer levar e so descobre o conteudo quando elas caem na mao dele.
export default function ModalRouboCego({
  visivel,
  alvos = [],
  quantidade = 2,
  traseiraImg,
  onConfirmar,
  onCancelar,
}) {
  const [alvoSel, setAlvoSel] = useState(null);
  const [selecionadas, setSelecionadas] = useState([]);

  useEffect(() => {
    if (visivel && alvos.length > 0) {
      setAlvoSel(alvos[0].idx);
      setSelecionadas([]);
    }
  }, [visivel]);

  const alvoAtual = alvos.find((a) => a.idx === alvoSel) || alvos[0] || null;
  const maoAlvo = alvoAtual?.mao || [];
  const podeConfirmar = selecionadas.length > 0;

  const alternar = (uid) => {
    setSelecionadas((prev) => {
      if (prev.includes(uid)) return prev.filter((u) => u !== uid);
      if (prev.length >= quantidade) return prev;
      return [...prev, uid];
    });
  };

  const trocarAlvo = (idx) => {
    setAlvoSel(idx);
    setSelecionadas([]);
  };

  const confirmar = () => {
    if (!podeConfirmar || !alvoAtual) return;
    if (onConfirmar) onConfirmar(alvoAtual.idx, selecionadas);
  };

  return (
    <Modal
      visible={!!visivel}
      transparent
      animationType="fade"
      onRequestClose={onCancelar}
      statusBarTranslucent
    >
      <View style={styles.overlay}>
        <View style={styles.painel}>
          <Text style={styles.titulo}>VIGARICE!</Text>
          <Text style={styles.mensagem}>
            Escolha ate {quantidade} carta(s) da mao de {alvoAtual ? alvoAtual.nome : '...'} voce
            so vera as cartas depois que rouba-las.
          </Text>

          {alvos.length > 1 && (
            <View style={styles.chipsRow}>
              {alvos.map((a) => (
                <Pressable
                  key={a.idx}
                  onPress={() => trocarAlvo(a.idx)}
                  style={[styles.chip, alvoSel === a.idx && styles.chipAtivo]}
                >
                  <Text
                    style={[styles.chipTexto, alvoSel === a.idx && styles.chipTextoAtivo]}
                  >
                    {a.nome}
                  </Text>
                </Pressable>
              ))}
            </View>
          )}

          {maoAlvo.length === 0 ? (
            <Text style={styles.avisoVazio}>Mao vazia - nada para roubar.</Text>
          ) : (
            <View style={styles.grade}>
              {maoAlvo.map((carta, i) => {
                const ativa = selecionadas.includes(carta.uid);
                return (
                  <Pressable
                    key={`${carta.uid}_${i}`}
                    onPress={() => alternar(carta.uid)}
                    style={[styles.cartaContainer, ativa && styles.cartaAtiva]}
                  >
                    <Image source={traseiraImg} style={styles.carta} />
                    <View style={styles.cartaIndice}>
                      <Text style={styles.cartaIndiceTexto}>{i + 1}</Text>
                    </View>
                  </Pressable>
                );
              })}
            </View>
          )}

          <Text style={styles.contador}>
            {selecionadas.length} / {quantidade} selecionada(s)
          </Text>

          <View style={styles.botoesRow}>
            <Pressable style={[styles.botao, styles.botaoCancelar]} onPress={onCancelar}>
              <Text style={styles.botaoTexto}>CANCELAR</Text>
            </Pressable>
            <Pressable
              style={[
                styles.botao,
                styles.botaoConfirmar,
                !podeConfirmar && styles.botaoDesabilitado,
              ]}
              onPress={confirmar}
              disabled={!podeConfirmar}
            >
              <Text style={[styles.botaoTexto, styles.botaoConfirmarTexto]}>ROUBAR</Text>
            </Pressable>
          </View>
        </View>
      </View>
    </Modal>
  );
}

const styles = StyleSheet.create({
  overlay: {
    flex: 1,
    backgroundColor: 'rgba(0, 0, 0, 0.78)',
    alignItems: 'center',
    justifyContent: 'center',
    padding: 16,
  },
  painel: {
    width: '100%',
    maxWidth: 420,
    backgroundColor: '#3E2723',
    borderWidth: 2,
    borderColor: '#7C4A27',
    borderRadius: 8,
    padding: 16,
    alignItems: 'center',
    shadowColor: '#000',
    shadowOpacity: 0.5,
    shadowRadius: 8,
    elevation: 10,
  },
  titulo: {
    fontSize: 18,
    color: '#FFD54F',
    letterSpacing: 3,
    marginBottom: 6,
  },
  mensagem: {
    fontSize: 12,
    color: '#EFEBE9',
    textAlign: 'center',
    lineHeight: 17,
    marginBottom: 12,
  },
  chipsRow: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: 6,
    justifyContent: 'center',
    marginBottom: 10,
  },
  chip: {
    paddingHorizontal: 10,
    paddingVertical: 5,
    borderRadius: 4,
    borderWidth: 1,
    borderColor: '#7C4A27',
    backgroundColor: 'rgba(0, 0, 0, 0.3)',
  },
  chipAtivo: {
    backgroundColor: '#FFD54F',
    borderColor: '#FFD54F',
  },
  chipTexto: {
    fontSize: 11,
    color: '#BCAAA4',
  },
  chipTextoAtivo: {
    color: '#3E2723',
  },
  grade: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    justifyContent: 'center',
    gap: 8,
    maxWidth: 272,
  },
  cartaContainer: {
    borderRadius: 5,
  },
  carta: {
    width: 56,
    height: 80,
    borderRadius: 4,
  },
  cartaAtiva: {
    transform: [{ translateY: -5 }],
    borderWidth: 2,
    borderColor: '#FFD54F',
    borderRadius: 6,
  },
  cartaIndice: {
    position: 'absolute',
    bottom: 3,
    right: 3,
    backgroundColor: 'rgba(0, 0, 0, 0.65)',
    borderRadius: 3,
    paddingHorizontal: 4,
    paddingVertical: 1,
  },
  cartaIndiceTexto: {
    fontSize: 8,
    color: '#FFF',
  },
  avisoVazio: {
    fontSize: 12,
    color: '#EF9A9A',
    marginVertical: 16,
  },
  contador: {
    fontSize: 11,
    color: '#BCAAA4',
    marginTop: 12,
  },
  botoesRow: {
    flexDirection: 'row',
    gap: 10,
    marginTop: 12,
  },
  botao: {
    paddingVertical: 8,
    paddingHorizontal: 20,
    borderRadius: 5,
    borderWidth: 1,
  },
  botaoCancelar: {
    borderColor: '#7C4A27',
    backgroundColor: 'transparent',
  },
  botaoConfirmar: {
    borderColor: '#FFD54F',
    backgroundColor: '#FFD54F',
  },
  botaoDesabilitado: {
    opacity: 0.4,
  },
  botaoTexto: {
    fontSize: 12,
    letterSpacing: 1,
    color: '#EFEBE9',
  },
  botaoConfirmarTexto: {
    color: '#3E2723',
  },
});
