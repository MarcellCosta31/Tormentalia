export const formatarDinheiro = (valor) => {
  return `R$ ${Math.abs(valor).toLocaleString('pt-BR')}`;
};

export const getRandomInt = (min, max) => {
  return Math.floor(Math.random() * (max - min + 1)) + min;
};

export const shuffleArray = (array) => {
  const newArray = [...array];
  for (let i = newArray.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [newArray[i], newArray[j]] = [newArray[j], newArray[i]];
  }
  return newArray;
};

export const delay = (ms) => new Promise(resolve => setTimeout(resolve, ms));
