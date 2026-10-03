import React, { useState } from 'react';
import {
  View,
  TextInput,
  Image,
  TouchableOpacity,
  StyleSheet,
  Dimensions,
  ImageBackground,
} from 'react-native';
import Text, { FONTE } from '../components/Texto';
import { getAvatarById, getAllAvatares } from '../utils/avatar';

const { width: SCREEN_WIDTH, height: SCREEN_HEIGHT } = Dimensions.get('window');

const avatares = getAllAvatares();

const GOLD = '#c8963c';
const GOLD_LIGHT = '#f0b429';
const BG_PAINEL = 'rgba(10, 18, 34, 0.96)';
const BG_FUNDO = '#0A0714';
const VERDE = '#3df064';
const VERDE_ESCURO = '#0e5a26';
const CANTO_SIZE = 12;

const FUNDO_PERFIL = require('../assets/sprites/perfil/background.png');

// Largura do painel — altere aqui para aumentar/diminuir tudo proporcionalmente.
const PAINEL_WIDTH = SCREEN_WIDTH * 0.55;

function CantosDecorativos({ cor = GOLD_LIGHT }) {
  return (
    <>
      <View style={[estilosCanto.base, estilosCanto.tl, { borderColor: cor }]} />
      <View style={[estilosCanto.base, estilosCanto.tr, { borderColor: cor }]} />
      <View style={[estilosCanto.base, estilosCanto.bl, { borderColor: cor }]} />
      <View style={[estilosCanto.base, estilosCanto.br, { borderColor: cor }]} />
    </>
  );
}

function Ornamento({ lado }) {
  const isEsq = lado === 'esq';
  return (
    <View style={estilosOrnamento.container}>
      {isEsq ? (
        <>
          <View style={estilosOrnamento.linha} />
          <View style={estilosOrnamento.diamante} />
          <View style={[estilosOrnamento.seta, estilosOrnamento.setaDir]} />
        </>
      ) : (
        <>
          <View style={[estilosOrnamento.seta, estilosOrnamento.setaEsq]} />
          <View style={estilosOrnamento.diamante} />
          <View style={estilosOrnamento.linha} />
        </>
      )}
    </View>
  );
}

const TelaPerfil = ({ onVoltar, perfil, onSalvar }) => {
  const [nickName, setNickName] = useState(perfil?.nickName || 'JOGADOR_1');
  const [avatarId, setAvatarId] = useState(perfil?.avatar || '1');
  const avatarSelecionado = getAvatarById(avatarId);

  const handleConfirmar = () => {
    onSalvar({ nickName, avatar: avatarId });
    onVoltar();
  };

  return (
    <ImageBackground
      source={FUNDO_PERFIL}
      style={styles.background}
      resizeMode="cover"
    >
      <View style={styles.overlay} pointerEvents="none" />

      <TouchableOpacity style={styles.btnVoltar} onPress={onVoltar} activeOpacity={0.7}>
        <Image
          source={require('../assets/sprites/um_jogador/voltar_btn.png')}
          style={styles.btnVoltarIcone}
          resizeMode="contain"
        />
      </TouchableOpacity>

      <View style={styles.conteudo}>
        <View style={styles.painel}>
          <CantosDecorativos />

          <View style={styles.painelTituloRow}>
            <Ornamento lado="esq" />
            <Text style={styles.painelTitulo}>EDITAR AVATAR</Text>
            <Ornamento lado="dir" />
          </View>
          <View style={styles.painelDivisor} />

          <View style={styles.painelCorpo}>
            {/* Coluna esquerda: preview + input */}
            <View style={styles.colunaAvatar}>
              <View style={styles.avatarSpotlight}>
                <CantosDecorativos cor={GOLD} />
                <Image
                  source={avatarSelecionado}
                  style={styles.avatarGrande}
                  resizeMode="contain"
                />
              </View>

              <TextInput
                style={styles.input}
                value={nickName}
                onChangeText={setNickName}
                maxLength={20}
                placeholderTextColor="#888"
                autoCapitalize="characters"
              />
            </View>

            {/* Coluna direita: grid 4x2 de avatares */}
            <View style={styles.colunaGrid}>
              <View style={styles.gridAvatares}>
                {avatares.map((item) => (
                  <TouchableOpacity
                    key={item.id}
                    style={[
                      styles.avatarItem,
                      avatarId === item.id && styles.avatarItemSelecionado,
                    ]}
                    onPress={() => setAvatarId(item.id)}
                    activeOpacity={0.7}
                  >
                    <Image
                      source={item.source}
                      style={styles.avatarMini}
                      resizeMode="cover"
                    />
                  </TouchableOpacity>
                ))}
              </View>
            </View>
          </View>

          <View style={styles.rodape}>
            <TouchableOpacity
              style={styles.btnConfirmar}
              onPress={handleConfirmar}
              activeOpacity={0.8}
            >
              <Text style={styles.btnConfirmarCheck}>✓</Text>
              <Text style={styles.btnConfirmarTexto}>
                CONFIRMAR{'\n'}MUDANÇAS
              </Text>
            </TouchableOpacity>
          </View>
        </View>
      </View>
    </ImageBackground>
  );
};

const estilosCanto = StyleSheet.create({
  base: {
    position: 'absolute',
    width: CANTO_SIZE,
    height: CANTO_SIZE,
  },
  tl: { top: -3, left: -3, borderTopWidth: 3, borderLeftWidth: 3 },
  tr: { top: -3, right: -3, borderTopWidth: 3, borderRightWidth: 3 },
  bl: { bottom: -3, left: -3, borderBottomWidth: 3, borderLeftWidth: 3 },
  br: { bottom: -3, right: -3, borderBottomWidth: 3, borderRightWidth: 3 },
});

const estilosOrnamento = StyleSheet.create({
  container: {
    flex: 1,
    flexDirection: 'row',
    alignItems: 'center',
    gap: 5,
  },
  seta: {
    width: 0,
    height: 0,
    borderTopWidth: 4,
    borderBottomWidth: 4,
    borderTopColor: 'transparent',
    borderBottomColor: 'transparent',
  },
  setaDir: {
    borderLeftWidth: 6,
    borderLeftColor: GOLD_LIGHT,
  },
  setaEsq: {
    borderRightWidth: 6,
    borderRightColor: GOLD_LIGHT,
  },
  diamante: {
    width: 7,
    height: 7,
    backgroundColor: GOLD_LIGHT,
    transform: [{ rotate: '45deg' }],
  },
  linha: {
    flex: 1,
    height: 2,
    backgroundColor: GOLD_LIGHT,
  },
});

const styles = StyleSheet.create({
  background: {
    flex: 1,
    width: '100%',
    height: '100%',
    backgroundColor: BG_FUNDO,
  },
  overlay: {
    ...StyleSheet.absoluteFillObject,
    backgroundColor: 'rgba(0, 0, 0, 0.35)',
  },
  btnVoltar: {
    position: 'absolute',
    top: SCREEN_HEIGHT * 0.04,
    left: SCREEN_WIDTH * 0.025,
    width: SCREEN_WIDTH * 0.11,
    height: SCREEN_WIDTH * 0.11,
    justifyContent: 'center',
    alignItems: 'center',
    zIndex: 10,
  },
  btnVoltarIcone: {
    width: '50%',
    height: '50%',
  },
  conteudo: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    paddingHorizontal: SCREEN_WIDTH * 0.03,
    paddingVertical: SCREEN_HEIGHT * 0.03,
  },
  painel: {
    width: PAINEL_WIDTH,
    backgroundColor: BG_PAINEL,
    borderWidth: 3,
    borderColor: GOLD,
    borderRadius: 6,
    paddingHorizontal: PAINEL_WIDTH * 0.05,
    paddingTop: PAINEL_WIDTH * 0.03,
    paddingBottom: PAINEL_WIDTH * 0.03,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 8 },
    shadowOpacity: 0.7,
    shadowRadius: 14,
    elevation: 12,
  },
  painelTituloRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 10,
  },
  painelTitulo: {
    color: '#FFFFFF',
    fontSize: PAINEL_WIDTH * 0.058,
    fontWeight: '800',
    letterSpacing: 3,
    textShadowColor: '#000',
    textShadowOffset: { width: 2, height: 2 },
    textShadowRadius: 0,
    textAlign: 'center',
  },
  painelDivisor: {
    height: 2,
    backgroundColor: GOLD,
    marginTop: PAINEL_WIDTH * 0.022,
    marginBottom: PAINEL_WIDTH * 0.028,
  },
  painelCorpo: {
    flexDirection: 'row',
    gap: PAINEL_WIDTH * 0.028,
    alignItems: 'flex-start',
  },
  colunaAvatar: {
    width: '32%',
    alignItems: 'center',
    justifyContent: 'flex-start',
  },
  avatarSpotlight: {
    width: '100%',
    aspectRatio: 0.95,
    borderRadius: 4,
    borderWidth: 3,
    borderColor: GOLD,
    backgroundColor: '#182740',
    justifyContent: 'center',
    alignItems: 'center',
    marginBottom: PAINEL_WIDTH * 0.028,
    shadowColor: GOLD_LIGHT,
    shadowOffset: { width: 0, height: 0 },
    shadowOpacity: 0.4,
    shadowRadius: 10,
    elevation: 8,
  },
  avatarGrande: {
    width: '94%',
    height: '94%',
  },
  input: {
    width: '100%',
    height: PAINEL_WIDTH * 0.085,
    backgroundColor: '#0c1424',
    borderWidth: 2,
    borderColor: GOLD,
    borderRadius: 4,
    color: '#fff',
    fontSize: PAINEL_WIDTH * 0.036,
    fontFamily: FONTE,
    paddingHorizontal: 10,
    letterSpacing: 1,
    paddingVertical: 0,
  },
  colunaGrid: {
    flex: 1,
    justifyContent: 'flex-start',
  },
  gridAvatares: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    justifyContent: 'space-between',
    alignContent: 'flex-start',
    rowGap: PAINEL_WIDTH * 0.02,
  },
  avatarItem: {
    width: '23.5%',
    aspectRatio: 1,
    borderRadius: 4,
    borderWidth: 2,
    borderColor: '#3d5a8c',
    backgroundColor: '#131e36',
    justifyContent: 'center',
    alignItems: 'center',
    overflow: 'hidden',
  },
  avatarItemSelecionado: {
    borderColor: VERDE,
    borderWidth: 3,
    backgroundColor: 'rgba(61, 240, 100, 0.12)',
    shadowColor: VERDE,
    shadowOffset: { width: 0, height: 0 },
    shadowOpacity: 0.9,
    shadowRadius: 8,
    elevation: 8,
  },
  avatarMini: {
    width: '100%',
    height: '100%',
  },
  rodape: {
    marginTop: PAINEL_WIDTH * 0.03,
    alignItems: 'flex-end',
  },
  btnConfirmar: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 10,
    backgroundColor: VERDE_ESCURO,
    borderWidth: 3,
    borderColor: VERDE,
    borderRadius: 6,
    paddingHorizontal: PAINEL_WIDTH * 0.045,
    paddingVertical: PAINEL_WIDTH * 0.022,
    shadowColor: VERDE,
    shadowOffset: { width: 0, height: 0 },
    shadowOpacity: 0.55,
    shadowRadius: 10,
    elevation: 8,
  },
  btnConfirmarCheck: {
    color: VERDE,
    fontSize: PAINEL_WIDTH * 0.075,
    fontWeight: '900',
    lineHeight: PAINEL_WIDTH * 0.08,
    textShadowColor: '#000',
    textShadowOffset: { width: 1, height: 1 },
    textShadowRadius: 0,
  },
  btnConfirmarTexto: {
    color: '#FFFFFF',
    fontSize: PAINEL_WIDTH * 0.036,
    fontWeight: '800',
    letterSpacing: 1.2,
    lineHeight: PAINEL_WIDTH * 0.044,
    textAlign: 'center',
    textShadowColor: '#000',
    textShadowOffset: { width: 1, height: 1 },
    textShadowRadius: 0,
  },
});

export default TelaPerfil;