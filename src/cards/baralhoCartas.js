import CARTAS_TGA, { TIPO_CARTA } from './cartasTGA';

export { TIPO_CARTA };

export const COPIAS_POR_CARTA = 3;
export const TOTAL_CARTAS = CARTAS_TGA.length * COPIAS_POR_CARTA;

export function gerarBaralhoCompleto() {
  const baralho = [];
  let uid = 0;

  for (let copia = 0; copia < COPIAS_POR_CARTA; copia++) {
    CARTAS_TGA.forEach((carta) => {
      baralho.push({ ...carta, uid: uid++ });
    });
  }

  return baralho;
}

export function embaralharBaralho(array) {
  const arr = [...array];
  for (let i = arr.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [arr[i], arr[j]] = [arr[j], arr[i]];
  }
  return arr;
}

export function comprarCarta(baralho, mao, quantidade = 1) {
  const baralhoLocal = [...baralho];
  const maoLocal = [...mao];
  const maxCompra = Math.min(quantidade, 7 - maoLocal.length);

  for (let i = 0; i < maxCompra; i++) {
    if (baralhoLocal.length === 0) break;
    const carta = baralhoLocal.shift();
    maoLocal.push(carta);
  }

  return { baralho: baralhoLocal, mao: maoLocal };
}
