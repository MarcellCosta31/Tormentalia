import { useEffect, useRef } from 'react';
import { duracaoTurno } from '../cards/motorEfeitos';

// Reacao do Adam Smith: 6s para comecar a jogar. Se ele estiver sob o
// efeito de "Sem tempo" (turno dele reduzido a 2s), reage em 2s.
const REACAO_IA_MS = 6000;
const REACAO_IA_MIN_MS = 2000;

export function useIA(estado, dispatch, pausadoRef = null) {
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

    // Agenda uma etapa da sequencia. Se houver destaque de coringa em
    // andamento, reaguarda (300ms) ate o destaque terminar - o turno da IA
    // so continua depois dos segundos de destaque.
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

    function jogarProximaCarta() {
      const estadoAtual = estadoRef.current;
      const idxIA = estadoAtual.jogadorAtivoIndex;
      const ia = estadoAtual.jogadores[idxIA];

      if (ia && !ia.falido && ia.mao.length > 0 && cartasJogadas < MAX_CARTAS_IA) {
        cartasJogadas++;
        dispatch({ type: 'IA_JOGAR_CARTA' });

        agendar(() => {
          jogarProximaCarta();
        }, 800);
      } else {
        comprarEDescartar();
      }
    }

    function comprarEDescartar() {
      agendar(() => {
        dispatch({ type: 'IA_COMPRAR_CARTA' });

        agendar(() => {
          const estadoAtual = estadoRef.current;
          const idxIA = estadoAtual.jogadorAtivoIndex;
          const ia = estadoAtual.jogadores[idxIA];
          if (ia && !ia.falido && ia.mao.length > 0) {
            const idxDescarte = Math.floor(Math.random() * ia.mao.length);
            const cartaDescarte = ia.mao[idxDescarte];
            dispatch({ type: 'IA_DESCARTAR_CARTA', payload: { cartaUid: cartaDescarte.uid } });
          }

          agendar(() => {
            dispatch({ type: 'IA_FIM_TURNO' });
            executandoRef.current = false;
          }, 500);
        }, 500);
      }, 600);
    }

    const atrasoReacao = Math.max(
      REACAO_IA_MIN_MS,
      Math.min(REACAO_IA_MS, duracaoTurno(jogadorAtivo) * 1000)
    );

    agendar(() => {
      jogarProximaCarta();
    }, atrasoReacao);

    return () => {
      timeoutsRef.current.forEach((t) => clearTimeout(t));
      timeoutsRef.current = [];
    };
  }, [estado?.jogadorAtivoIndex, estado?.fimDeJogo, estado?.turnoAtual, estado?.batalhaIniciada]);

  return { iaExecutando: executandoRef.current };
}
