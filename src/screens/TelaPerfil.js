import React, { useState } from 'react';
import {
  View,
  Text,
  TextInput,
  Image,
  TouchableOpacity,
  StyleSheet,
  Dimensions,
  ImageBackground,
} from 'react-native';
import { getAvatarById, getAvatarId, getAllAvatares } from '../utils/avatar';

const { width: SCREEN_WIDTH, height: SCREEN_HEIGHT } = Dimensions.get('window');

const avatares = getAllAvatares();

const BORDER_COLOR = '#c89b3c';
const BG_PAINEL = 'rgba(10, 10, 30, 0.92)';

const TelaPerfil = ({ onVoltar, onConfiguracoes, onSobre, onSair, perfil, onSalvar }) => {
  const [nickName, setNickName] = useState(perfil?.nickName || 'JOGADOR_1');
  const [avatarId, setAvatarId] = useState(perfil?.avatar || '1');
  const avatarSelecionado = getAvatarById(avatarId);

  const handleSalvarNome = () => {
    onSalvar({ nickName, avatar: avatarId });
  };

  const handleConfirmar = () => {
    onSalvar({ nickName, avatar: avatarId });
    onVoltar();
  };

  return (
    <ImageBackground
      style={styles.background}
      resizeMode="contain"
    >
      <View style={styles.layout}>
        <View style={styles.ladoEsquerdo}>
          <Text style={styles.tituloNeon}>PERFIL DO{'\n'}JOGADOR</Text>

          <View style={styles.menuLateral}>
            <TouchableOpacity style={styles.menuBtnVoltar} onPress={onVoltar} activeOpacity={0.7}>
              <Image source={require('../assets/sprites/menu/voltar.png')} style={styles.menuBtnIconeVoltar} resizeMode="contain" />
            </TouchableOpacity>
            <TouchableOpacity style={styles.menuBtn} onPress={onConfiguracoes} activeOpacity={0.7}>
              <Image source={require('../assets/sprites/menu/configura_btn.png')} style={styles.menuBtnIcone} resizeMode="contain" />
            </TouchableOpacity>
            <TouchableOpacity style={styles.menuBtn} onPress={onSobre} activeOpacity={0.7}>
              <Image source={require('../assets/sprites/menu/sobre_btn.png')} style={styles.menuBtnIcone} resizeMode="contain" />
            </TouchableOpacity>
            <TouchableOpacity style={styles.menuBtn} onPress={onSair} activeOpacity={0.7}>
              <Image source={require('../assets/sprites/menu/sair_btn.png')} style={styles.menuBtnIcone} resizeMode="contain" />
            </TouchableOpacity>
          </View>
        </View>

        <View style={styles.ladoDireito}>
          <View style={styles.painel}>
            <Text style={styles.painelTitulo}>EDIT PROFILE</Text>

            <View style={styles.painelCorpo}>
              <View style={styles.colunaAvatar}>
                <View style={styles.avatarSpotlight}>
                  <Image source={avatarSelecionado} style={styles.avatarGrande} resizeMode="contain" />
                </View>

                <View style={styles.inputRow}>
                  <TextInput
                    style={styles.input}
                    value={nickName}
                    onChangeText={setNickName}
                    maxLength={20}
                    placeholderTextColor="#888"
                  />
                  <TouchableOpacity style={styles.btnEditar} onPress={() => {}}>
                    <Text style={styles.btnEditarTexto}>✏️</Text>
                  </TouchableOpacity>
                </View>

                <TouchableOpacity style={styles.btnSalvarNome} onPress={handleSalvarNome} activeOpacity={0.7}>
                  <Text style={styles.btnCheck}>✓</Text>
                  <Text style={styles.btnSalvarNomeTexto}>SALVAR NOME</Text>
                </TouchableOpacity>
              </View>

              <View style={styles.colunaGrid}>
                <View style={styles.gridAvatares}>
                  {avatares.map((item) => (
                    <TouchableOpacity
                      key={item.id}
                      style={[
                        styles.avatarItem,
                        avatarId === item.id && styles.avatarSelecionado,
                      ]}
                      onPress={() => setAvatarId(item.id)}
                      activeOpacity={0.7}
                    >
                      <Image source={item.source} style={styles.avatarMini} resizeMode="contain" />
                    </TouchableOpacity>
                  ))}
                </View>

                <TouchableOpacity style={styles.btnConfirmar} onPress={handleConfirmar} activeOpacity={0.7}>
                  <Text style={styles.btnCheckVerde}>✓</Text>
                  <Text style={styles.btnConfirmarTexto}>CONFIRMAR{'\n'}MUDANÇAS</Text>
                </TouchableOpacity>
              </View>
            </View>
          </View>
        </View>
      </View>
    </ImageBackground>
  );
};

const styles = StyleSheet.create({
  background: {
    flex: 1,
    width: '100%',
    height: '100%',
    backgroundColor: '#07060bff',
  },
  layout: {
    flex: 1,
    flexDirection: 'row',
    paddingTop: SCREEN_HEIGHT * 0.05,
    paddingHorizontal: SCREEN_WIDTH * 0.03,
  },
  ladoEsquerdo: {
    width: '30%',
    justifyContent: 'flex-start',
    alignItems: 'flex-start',
    paddingTop: SCREEN_HEIGHT * 0.02,
  },
  tituloNeon: {
    fontSize: 24,
    fontWeight: 'bold',
    color: '#ff3cac',
    textShadowColor: '#ff3cac',
    textShadowOffset: { width: 0, height: 0 },
    textShadowRadius: 15,
    marginBottom: SCREEN_HEIGHT * 0.06,
    lineHeight: 30,
  },
  menuLateral: {
    gap: 14,
    width: '100%',
  },
  menuBtnVoltar: {
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: 'transparent',
    borderRadius: 8,
  },
  menuBtnIconeVoltar: {
    width: SCREEN_WIDTH * 0.20,
    height: SCREEN_HEIGHT * 0.10,
  },
  menuBtn: {
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: 'transparent',
    borderRadius: 8,
  },
  menuBtnIcone: {
    width: SCREEN_WIDTH * 0.24,
    height: SCREEN_HEIGHT * 0.13,
  },
  ladoDireito: {
    width: '70%',
    justifyContent: 'flex-start',
    alignItems: 'stretch',
  },
  painel: {
    flex: 1,
    backgroundColor: BG_PAINEL,
    borderWidth: 2,
    borderColor: BORDER_COLOR,
    borderRadius: 12,
    paddingHorizontal: SCREEN_WIDTH * 0.015,
    paddingTop: 12,
    paddingBottom: 14,
  },
  painelTitulo: {
    color: '#fff',
    fontSize: 18,
    fontWeight: 'bold',
    textAlign: 'center',
    letterSpacing: 2,
    paddingBottom: 10,
    borderBottomWidth: 1,
    borderBottomColor: BORDER_COLOR,
    marginBottom: 10,
  },
  painelCorpo: {
    flex: 1,
    flexDirection: 'row',
    gap: 12,
  },
  colunaAvatar: {
    width: '38%',
    alignItems: 'center',
    justifyContent: 'flex-start',
  },
  avatarSpotlight: {
    width: SCREEN_WIDTH * 0.16,
    height: SCREEN_WIDTH * 0.20,
    borderRadius: 10,
    borderWidth: 2,
    borderColor: BORDER_COLOR,
    backgroundColor: 'rgba(30, 30, 60, 0.8)',
    justifyContent: 'center',
    alignItems: 'center',
    overflow: 'hidden',
    marginBottom: 10,
  },
  avatarGrande: {
    width: '90%',
    height: '90%',
  },
  inputRow: {
    flexDirection: 'row',
    alignItems: 'center',
    width: '100%',
    marginBottom: 8,
  },
  input: {
    flex: 1,
    height: 38,
    backgroundColor: '#0d0d1a',
    borderWidth: 2,
    borderColor: BORDER_COLOR,
    borderRadius: 6,
    color: '#fff',
    fontSize: 14,
    fontWeight: 'bold',
    paddingHorizontal: 10,
    letterSpacing: 1,
  },
  btnEditar: {
    width: 38,
    height: 38,
    backgroundColor: BORDER_COLOR,
    borderRadius: 6,
    justifyContent: 'center',
    alignItems: 'center',
    marginLeft: 6,
  },
  btnEditarTexto: {
    fontSize: 16,
  },
  btnSalvarNome: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: 'rgba(40, 40, 70, 0.9)',
    borderWidth: 2,
    borderColor: BORDER_COLOR,
    borderRadius: 6,
    paddingVertical: 10,
    paddingHorizontal: 12,
    gap: 8,
    width: '100%',
    justifyContent: 'center',
  },
  btnCheck: {
    color: '#fff',
    fontSize: 16,
    fontWeight: 'bold',
  },
  btnSalvarNomeTexto: {
    color: '#fff',
    fontSize: 12,
    fontWeight: 'bold',
    letterSpacing: 1,
  },
  colunaGrid: {
    flex: 1,
    justifyContent: 'space-between',
  },
  gridAvatares: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    justifyContent: 'center',
    gap: 8,
  },
  avatarItem: {
    width: SCREEN_WIDTH * 0.085,
    height: SCREEN_WIDTH * 0.085,
    borderRadius: 8,
    borderWidth: 2,
    borderColor: '#444',
    backgroundColor: 'rgba(20, 20, 40, 0.8)',
    justifyContent: 'center',
    alignItems: 'center',
    overflow: 'hidden',
  },
  avatarSelecionado: {
    borderColor: '#4CAF50',
    borderWidth: 3,
    backgroundColor: 'rgba(76, 175, 80, 0.2)',
  },
  avatarMini: {
    width: '85%',
    height: '85%',
  },
  btnConfirmar: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: 'rgba(30, 60, 30, 0.9)',
    borderWidth: 2,
    borderColor: '#4CAF50',
    borderRadius: 8,
    paddingVertical: 10,
    paddingHorizontal: 14,
    gap: 8,
    alignSelf: 'flex-end',
    marginTop: 8,
  },
  btnCheckVerde: {
    color: '#4CAF50',
    fontSize: 18,
    fontWeight: 'bold',
  },
  btnConfirmarTexto: {
    color: '#fff',
    fontSize: 11,
    fontWeight: 'bold',
    letterSpacing: 1,
    lineHeight: 16,
  },
});

export default TelaPerfil;
