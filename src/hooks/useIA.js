import { useEffect, useRef } from 'react';
import { TIPO_CARTA } from '../cards/baralhoCartas';

export function useIA(estado, dispatch) {
  const timeoutRef = useRef(null);
  const executandoRef = useRef(false);

  useEffect(() => {
    return () => {
      if (timeoutRef.current) clearTimeout(timeoutRef.current);
    };
  }, []);

  useEffect(() => {
    if (!estado || estado.fimDeJogo) {
      executandoRef.current = false;
      return;
    }
    if (executandoRef.current) return;

    const jogadorAtivo = estado.jogadores[estado.jogadorAtivoIndex];
    if (!jogadorAtivo || !jogadorAtivo.isIA) return;

    executandoRef.current = true;

    timeoutRef.current = setTimeout(() => {
      dispatch({ type: 'EXECUTAR_TURNO_IA' });
      executandoRef.current = false;
    }, 1200);

    return () => {
      if (timeoutRef.current) clearTimeout(timeoutRef.current);
    };
  }, [estado?.jogadorAtivoIndex, estado?.fimDeJogo, estado?.turnoAtual]);

  return { iaExecutando: executandoRef.current };
}
