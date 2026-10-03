const ARTE_PADRAO = require('../assets/cards/arte_faltando.png');
const TRASEIRA = require('../assets/cards/traseira_cartas.jpg');

const ARTE_POR_ID = {
  1: require('../assets/cards/nosso.png'),
  2: require('../assets/cards/toyotinho.png'),
  3: require('../assets/cards/sem_tempo.png'),
  5: require('../assets/cards/presente_noel.png'),
  20: require('../assets/cards/cada_um_no_seu_quadrado.png'),
};

// Resolve a imagem de uma carta pelo id canonic (cartasTGA).
// Cartas ainda sem arte usam o placeholder "arte faltando".
export function artePorCarta(carta) {
  if (!carta) return TRASEIRA;
  return ARTE_POR_ID[carta.id] || ARTE_PADRAO;
}

// true se a carta tem arte propria (senao a UI mostra face textual).
export function temArte(carta) {
  return !!(carta && ARTE_POR_ID[carta.id]);
}

export { TRASEIRA, ARTE_PADRAO, ARTE_POR_ID };
