import React, { useState, useEffect } from 'react';
import { StatusBar } from 'expo-status-bar';
import * as NavigationBar from 'expo-navigation-bar';
import TelaInicial from './src/screens/TelaInicial';
import ArenaCombate from './src/screens/ArenaCombate';

export default function App() {
  const [telaAtual, setTelaAtual] = useState('arena');

  useEffect(() => {
    NavigationBar.setVisibilityAsync('hidden');
  }, []);

  const iniciarJogo = () => {
    setTelaAtual('arena');
  };

  const voltarParaInicial = () => {
    setTelaAtual('inicial');
  };

  return (
    <>
      <StatusBar hidden />
      {telaAtual === 'inicial' ? (
        <TelaInicial onIniciarJogo={iniciarJogo} />
      ) : (
        <ArenaCombate onVoltar={voltarParaInicial} />
      )}
    </>
  );
}
