import React, { useState, useEffect } from 'react';
import { StatusBar } from 'expo-status-bar';
import { Alert } from 'react-native';
import * as NavigationBar from 'expo-navigation-bar';
import { useFonts } from 'expo-font';
import TelaIntro from './src/screens/TelaIntro';
import TelaLogo from './src/screens/TelaLogo';
import TelaInicial from './src/screens/TelaInicial';
import TelaUmJogador from './src/screens/TelaUmJogador';
import TelaTutorial from './src/screens/TelaTutorial';
import TelaPerfil from './src/screens/TelaPerfil';
import TelaLobby from './src/screens/TelaLobby';
import TelaSala from './src/screens/TelaSala';
import ArenaCombate from './src/screens/ArenaCombate';
import ArenaMultiplayer from './src/screens/ArenaMultiplayer';
import { carregarPerfil, salvarPerfil } from './src/utils/perfilStorage';

export default function App() {
  const [telaAtual, setTelaAtual] = useState('intro');
  const [perfil, setPerfil] = useState(null);
  const [perfilCarregado, setPerfilCarregado] = useState(false);
  const [multiplayerConfig, setMultiplayerConfig] = useState(null);
  const [salaInfo, setSalaInfo] = useState(null);
  const [arenaQuantidade, setArenaQuantidade] = useState(2);

  const [fontesCarregadas] = useFonts({
    'VCR_OSD_MONO_1.001': require('./src/fonts/VCR_OSD_MONO_1.001.ttf'),
  });

  useEffect(() => {
    try {
      NavigationBar.setVisibilityAsync('hidden');
    } catch (e) {}
    carregarPerfilSalvo();
  }, []);

  const carregarPerfilSalvo = async () => {
    const perfilSalvo = await carregarPerfil();
    if (perfilSalvo) {
      setPerfil(perfilSalvo);
    }
    setPerfilCarregado(true);
  };

  const handleSalvarPerfil = async (novoPerfil) => {
    setPerfil(novoPerfil);
    await salvarPerfil(novoPerfil);
  };

  const iniciarJogo = () => {
    setTelaAtual('arena');
  };

  // Menu → tela de escolha do oponente (modo um jogador).
  const abrirUmJogador = () => {
    setMultiplayerConfig(null);
    setSalaInfo(null);
    setTelaAtual('umJogador');
  };

  const iniciarMultiplayer = (config) => {
    setMultiplayerConfig(config);
    setTelaAtual('arena');
  };

  const voltarParaInicial = () => {
    setMultiplayerConfig(null);
    setSalaInfo(null);
    setTelaAtual('inicial');
  };

  const iniciarArenaMultiplayer = (quantidade) => {
    setArenaQuantidade(quantidade);
    setTelaAtual('arenaMulti');
  };

  const handleCriarSala = (info) => {
    setSalaInfo({ ...info, isHost: true });
    setTelaAtual('sala');
  };

  const handleEntrarSala = (info) => {
    setSalaInfo({ ...info, isHost: false });
    setTelaAtual('sala');
  };

  const voltarParaLobby = () => {
    setSalaInfo(null);
    setTelaAtual('lobby');
  };

  const handleSair = () => {
    Alert.alert(
      'Sair do Jogo',
      'Tem certeza que deseja sair?',
      [
        { text: 'Cancelar', style: 'cancel' },
        { text: 'Sair', style: 'destructive' },
      ]
    );
  };

  if (!fontesCarregadas || !perfilCarregado) {
    return null;
  }

  return (
    <>
      <StatusBar hidden />
      {telaAtual === 'intro' && (
        <TelaIntro onAvancar={() => setTelaAtual('logo')} />
      )}
      {telaAtual === 'logo' && (
        <TelaLogo onAvancar={() => setTelaAtual('inicial')} />
      )}
      {telaAtual === 'inicial' && (
        <TelaInicial
          onIniciarJogo={abrirUmJogador}
          onMultiplayer={() => setTelaAtual('lobby')}
          onConfiguracoes={() => Alert.alert('Configurações', 'Em breve!')}
          onSobre={() => Alert.alert('Sobre', 'O Caro Deus Mercado v1.0')}
          onSair={handleSair}
          onPerfil={() => setTelaAtual('perfil')}
          perfil={perfil}
          onArena={iniciarArenaMultiplayer}
          onTutorial={() => setTelaAtual('tutorial')}
        />
      )}
      {telaAtual === 'tutorial' && (
        <TelaTutorial
          onVoltar={() => setTelaAtual('inicial')}
          onIniciarBatalha={() => {
            setMultiplayerConfig(null);
            setSalaInfo(null);
            setTelaAtual('arena');
          }}
          perfil={perfil}
          onSalvarPerfil={handleSalvarPerfil}
        />
      )}
      {telaAtual === 'umJogador' && (
        <TelaUmJogador
          onVoltar={() => setTelaAtual('inicial')}
          onIniciar={iniciarJogo}
        />
      )}
      {telaAtual === 'perfil' && (
        <TelaPerfil
          onVoltar={() => setTelaAtual('inicial')}
          onConfiguracoes={() => Alert.alert('Configurações', 'Em breve!')}
          onSobre={() => Alert.alert('Sobre', 'O Caro Deus Mercado v1.0')}
          onSair={handleSair}
          perfil={perfil}
          onSalvar={handleSalvarPerfil}
        />
      )}
      {telaAtual === 'lobby' && (
        <TelaLobby
          onVoltar={() => setTelaAtual('inicial')}
          onCriarSala={handleCriarSala}
          onEntrarSala={handleEntrarSala}
          perfil={perfil}
        />
      )}
      {telaAtual === 'sala' && (
        <TelaSala
          onVoltar={voltarParaLobby}
          onIniciarJogo={iniciarMultiplayer}
          perfil={perfil}
          salaInfo={salaInfo}
        />
      )}
      {telaAtual === 'arena' && multiplayerConfig && (
  <ArenaMultiplayer
    multiplayerConfig={multiplayerConfig}
    onVoltar={voltarParaInicial}
  />
)}
{telaAtual === 'arena' && !multiplayerConfig && (
  <ArenaCombate
    onVoltar={voltarParaInicial}
    multiplayerConfig={null}
    perfil={perfil}
  />
)}
      {telaAtual === 'arenaMulti' && (
        <ArenaMultiplayer
          quantidade={arenaQuantidade}
          onVoltar={voltarParaInicial}
        />
      )}
    </>
  );
}
