const avatares = [
  { id: '1', source: require('../assets/sprites/perfil/azul_marinho.png') },
  { id: '2', source: require('../assets/sprites/perfil/vermelho.png') },
  { id: '3', source: require('../assets/sprites/perfil/verde.png') },
  { id: '4', source: require('../assets/sprites/perfil/roxo.png') },
  { id: '5', source: require('../assets/sprites/perfil/marrom.png') },
  { id: '6', source: require('../assets/sprites/perfil/amarelo.png') },
  { id: '7', source: require('../assets/sprites/perfil/cinza.png') },
  { id: '8', source: require('../assets/sprites/perfil/ciano.png') },
];

export const getAvatarById = (id) => {
  const avatar = avatares.find((a) => a.id === id);
  return avatar ? avatar.source : avatares[0].source;
};

export const getAvatarId = (source) => {
  const avatar = avatares.find((a) => a.source === source);
  return avatar ? avatar.id : '1';
};

export const getAllAvatares = () => avatares;
