import { useEffect, useRef } from 'react';

export function useIA(estado, dispatch) {
  const timeoutsRef = useRef([]);
  const executandoRef = useRef(false);
  const estadoRef = useRef(estado);

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
    if (estado.isMultiplayer) return;

    const jogadorAtivo = estado.jogadores[estado.jogadorAtivoIndex];
    if (!jogadorAtivo || !jogadorAtivo.isIA) return;

    executandoRef.current = true;
    timeoutsRef.current.forEach((t) => clearTimeout(t));
    timeoutsRef.current = [];

    const MAX_CARTAS_IA = 2;
    let cartasJogadas = 0;

    function jogarProximaCarta() {
      const estadoAtual = estadoRef.current;
      const idxIA = estadoAtual.jogadorAtivoIndex;
      const ia = estadoAtual.jogadores[idxIA];

      if (ia && !ia.falido && ia.mao.length > 0 && cartasJogadas < MAX_CARTAS_IA) {
        cartasJogadas++;
        dispatch({ type: 'IA_JOGAR_CARTA' });

        const tProx = setTimeout(() => {
          jogarProximaCarta();
        }, 800);
        timeoutsRef.current.push(tProx);
      } else {
        comprarEDescartar();
      }
    }

    function comprarEDescartar() {
      const tComprar = setTimeout(() => {
        dispatch({ type: 'IA_COMPRAR_CARTA' });

        const tDescarte = setTimeout(() => {
          const estadoAtual = estadoRef.current;
          const idxIA = estadoAtual.jogadorAtivoIndex;
          const ia = estadoAtual.jogadores[idxIA];
          if (ia && !ia.falido && ia.mao.length > 0) {
            const idxDescarte = Math.floor(Math.random() * ia.mao.length);
            const cartaDescarte = ia.mao[idxDescarte];
            dispatch({ type: 'IA_DESCARTAR_CARTA', payload: { cartaUid: cartaDescarte.uid } });
          }

          const tFim = setTimeout(() => {
            dispatch({ type: 'IA_FIM_TURNO' });
            executandoRef.current = false;
          }, 500);

          timeoutsRef.current.push(tFim);
        }, 500);

        timeoutsRef.current.push(tDescarte);
      }, 600);

      timeoutsRef.current.push(tComprar);
    }

    const t1 = setTimeout(() => {
      jogarProximaCarta();
    }, 600);

    timeoutsRef.current.push(t1);

    return () => {
      timeoutsRef.current.forEach((t) => clearTimeout(t));
      timeoutsRef.current = [];
    };
  }, [estado?.jogadorAtivoIndex, estado?.fimDeJogo, estado?.turnoAtual, estado?.batalhaIniciada]);

  return { iaExecutando: executandoRef.current };
}
