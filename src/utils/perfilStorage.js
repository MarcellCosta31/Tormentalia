import AsyncStorage from '@react-native-async-storage/async-storage';

const PERFIL_KEY = '@perfil_jogador';

export async function salvarPerfil(perfil) {
  try {
    const dados = JSON.stringify(perfil);
    await AsyncStorage.setItem(PERFIL_KEY, dados);
    return true;
  } catch (e) {
    console.error('Erro ao salvar perfil:', e);
    return false;
  }
}

export async function carregarPerfil() {
  try {
    const dados = await AsyncStorage.getItem(PERFIL_KEY);
    if (dados) {
      return JSON.parse(dados);
    }
    return null;
  } catch (e) {
    console.error('Erro ao carregar perfil:', e);
    return null;
  }
}
