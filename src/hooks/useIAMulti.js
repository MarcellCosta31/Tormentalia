import { useEffect, useRef } from 'react';

function encontrarAlvo(jogadores, idxJogador) {
  const vivos = jogadores
    .map((j, i) => ({ ...j, idx: i }))
    .filter((j) => !j.falido && j.idx !== idxJogador);
  if (vivos.length === 0) return idxJogador;
  const alvo = vivos[Math.floor(Math.random() * vivos.length)];
  return alvo.idx;
}

export function useIAMulti(estado, dispatch, pausadoRef = null) {
  const timeoutsRef = useRef([]);
  const executandoRef = useRef(false);
  const ultimoTurnoRef = useRef(null);
  const estadoRef = useRef(estado);
  const idxRef = useRef(0);

  useEffect(() => { estadoRef.current = estado; }, [estado]);

  useEffect(() => {
    return () => {
      timeoutsRef.current.forEach((t) => clearTimeout(t));
      timeoutsRef.current = [];
    };
  }, []);

  useEffect(() => {
    if (!estado || estado.fimDeJogo) {
      executandoRef.current = false;
      return;
    }
    if (executandoRef.current) return;
    if (!estado.batalhaIniciada) return;

    const idx = estado.jogadorAtivoIndex;
    idxRef.current = idx;
    const jogadorAtivo = estado.jogadores[idx];
    if (!jogadorAtivo || !jogadorAtivo.isIA) return;

    const chaveTurno = `${estado.turnoAtual}_${idx}`;
    if (ultimoTurnoRef.current === chaveTurno) return;
    ultimoTurnoRef.current = chaveTurno;

    executandoRef.current = true;
    timeoutsRef.current.forEach((t) => clearTimeout(t));
    timeoutsRef.current = [];

    // Agenda uma etapa da sequencia. Se houver destaque de coringa em
    // andamento, reaguarda (300ms) ate o destaque terminar.
    const agendar = (fn, ms) => {
      const t = setTimeout(function tentar() {
        if (pausadoRef && pausadoRef.current) {
          const tp = setTimeout(tentar, 300);
          timeoutsRef.current.push(tp);
        } else {
          fn();
        }
      }, ms);
      timeoutsRef.current.push(t);
    };

    agendar(() => {
      const estadoAtual = estadoRef.current;
      const idxAtual = idxRef.current;
      const jogadorAtivo = estadoAtual.jogadores[idxAtual];
      if (jogadorAtivo && jogadorAtivo.mao.length > 0 && !jogadorAtivo.falido) {
        const carta = jogadorAtivo.mao[Math.floor(Math.random() * jogadorAtivo.mao.length)];
        const alvoIdx = carta.precisaAlvo ? encontrarAlvo(estadoAtual.jogadores, idxAtual) : null;
        dispatch({ type: 'IA_N_JOGAR_CARTA', payload: { jogadorIdx: idxAtual, cartaUid: carta.uid, alvoIdx } });
      }

      agendar(() => {
        dispatch({ type: 'IA_N_COMPRAR_CARTA', payload: { jogadorIdx: idxAtual } });

        agendar(() => {
          const estadoAtual2 = estadoRef.current;
          const idxAtual2 = idxRef.current;
          const jogadorAtual = estadoAtual2.jogadores[idxAtual2];
          if (jogadorAtual && !jogadorAtual.falido && jogadorAtual.mao.length > 0) {
            const idxDescarte = Math.floor(Math.random() * jogadorAtual.mao.length);
            const cartaDescarte = jogadorAtual.mao[idxDescarte];
            dispatch({ type: 'IA_N_DESCARTAR_CARTA', payload: { jogadorIdx: idxAtual2, cartaUid: cartaDescarte.uid } });
          }

          agendar(() => {
            dispatch({ type: 'IA_N_FIM_TURNO' });
            executandoRef.current = false;
          }, 500);
        }, 600);
      }, 800);
    }, 700);

    return () => {
      timeoutsRef.current.forEach((t) => clearTimeout(t));
      timeoutsRef.current = [];
    };
  }, [estado?.jogadorAtivoIndex, estado?.fimDeJogo, estado?.turnoAtual, estado?.batalhaIniciada]);

  return { iaExecutando: executandoRef.current };
}
