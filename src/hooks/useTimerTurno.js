import { useEffect, useRef, useState } from 'react';

// Contagem regressiva de turno. Roda em intervalos de 100ms enquanto
// `ativo` for true; ao chegar em 0 chama `aoEsgotar` UMA vez.
//  - `chave` muda a cada turno => reseta a contagem;
//  - quando fica inativo (fim de jogo / animacao de inicio) reseta tambem,
//    para um novo jogo nao comecar com o tempo zerado;
//  - `pausado` congela a contagem sem zerar.
export function useTimerTurno({ chave, duracao, ativo, pausado, aoEsgotar }) {
  const duracaoSeg = typeof duracao === 'number' && duracao > 0 ? duracao : 20;
  const [restante, setRestante] = useState(duracaoSeg);
  const expiradoRef = useRef(false);
  const cbRef = useRef(aoEsgotar);
  cbRef.current = aoEsgotar;

  // Troca de turno (ou de duracao, ex.: Sem tempo ativo) => reinicia.
  useEffect(() => {
    expiradoRef.current = false;
    setRestante(duracaoSeg);
  }, [chave, duracaoSeg]);

  // Ficou inativo => deixa tudo pronto para o proximo ciclo.
  useEffect(() => {
    if (!ativo) {
      expiradoRef.current = false;
      setRestante(duracaoSeg);
    }
  }, [ativo, duracaoSeg]);

  // Tique de 100ms.
  useEffect(() => {
    if (!ativo || pausado || expiradoRef.current) return;
    const id = setInterval(() => {
      setRestante((r) => Math.max(0, Math.round((r - 0.1) * 10) / 10));
    }, 100);
    return () => clearInterval(id);
  }, [ativo, pausado, chave]);

  // Esgotou => notifica uma unica vez.
  useEffect(() => {
    if (ativo && !pausado && restante <= 0 && !expiradoRef.current) {
      expiradoRef.current = true;
      if (cbRef.current) cbRef.current();
    }
  }, [restante, ativo, pausado]);

  return restante;
}

export default useTimerTurno;
