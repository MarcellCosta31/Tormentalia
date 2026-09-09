import { useEffect, useRef } from 'react';

export function useIA(estado, dispatch) {
  const timeoutsRef = useRef([]);
  const executandoRef = useRef(false);

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

    const t1 = setTimeout(() => {
      dispatch({ type: 'IA_JOGAR_CARTA' });

      const t2 = setTimeout(() => {
        dispatch({ type: 'IA_COMPRAR_CARTA' });

        const t3 = setTimeout(() => {
          const ia = estado.jogadores[1];
          if (ia && !ia.falido && ia.mao.length > 0) {
            const idxDescarte = Math.floor(Math.random() * ia.mao.length);
            const cartaDescarte = ia.mao[idxDescarte];
            dispatch({ type: 'IA_DESCARTAR_CARTA', payload: { cartaUid: cartaDescarte.uid } });
          }

          const t4 = setTimeout(() => {
            dispatch({ type: 'IA_FIM_TURNO' });
            executandoRef.current = false;
          }, 500);

          timeoutsRef.current.push(t4);
        }, 500);

        timeoutsRef.current.push(t3);
      }, 800);

      timeoutsRef.current.push(t2);
    }, 600);

    timeoutsRef.current.push(t1);

    return () => {
      timeoutsRef.current.forEach((t) => clearTimeout(t));
      timeoutsRef.current = [];
    };
  }, [estado?.jogadorAtivoIndex, estado?.fimDeJogo, estado?.turnoAtual, estado?.batalhaIniciada]);

  return { iaExecutando: executandoRef.current };
}
