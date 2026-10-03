import React, { useCallback, useEffect, useRef, useState } from 'react';
import {
  View,
  TouchableOpacity,
  Pressable,
  StyleSheet,
  Dimensions,
  Animated,
} from 'react-native';
import Text from '../components/Texto';
import CutscenePlayer from '../components/tutorial/CutscenePlayer';
import DeckTutorial from '../components/tutorial/DeckTutorial';
import { CUTSCENE } from '../tutorial/cenas';
import { activateKeepAwakeAsync, deactivateKeepAwake } from 'expo-keep-awake';

// Sequencia linear de quadros com metadados de cena (progresso no HUD).
const QUADROS = CUTSCENE.flatMap((cena, cenaIdx) =>
  cena.quadros.map((quadro, qIdx) => ({
    ...quadro,
    cenaIdx,
    cenaTotal: CUTSCENE.length,
    cenaTitulo: `CENA ${cenaIdx + 1} · ${cena.titulo}`,
    totalNaCena: cena.quadros.length,
    numero: quadro.numero || qIdx + 1,
  }))
);

const DUR_FADE = 700; // fade out (300) + fade in (400) do CutscenePlayer
const DUR_PORTAL = 2000; // luz crescendo + troca de cena

// Frases da tela preta de abertura (avancam so com toque).
const FRASES_INTRO = [
  'Olá peixe pequeno, seja bem vindo.',
  'Essa é a sua história.',
  'De como você fez história,',
];
const INTERVALO_TOQUE = 500; // ignora toque duplicado/acidental

// =============================================================================
// TelaTutorial — TutorialController do tutorial.
// Controla: indices da cutscene, pausas dramaticas, acoes (deck/fim),
// transicao do portal, overlay do deck e painel final.
// A renderizacao da narrativa fica em CutscenePlayer + cenas.js.
// =============================================================================
export default function TelaTutorial({ onVoltar, onIniciarBatalha, perfil, onSalvarPerfil }) {
  const [indice, setIndice] = useState(0);
  const [falaIdx, setFalaIdx] = useState(QUADROS[0].comecarSemCaixa ? -1 : 0);
  const [pausaAtiva, setPausaAtiva] = useState(false);
  const [transicao, setTransicao] = useState(null); // null | 'portal'
  const [overlayDeck, setOverlayDeck] = useState(false);
  const [fim, setFim] = useState(false);

  // Mantem a tela acesa durante o tutorial: o texto da intro so some quando o
  // usuario toca (nunca por timeout de tela do aparelho).
  useEffect(() => {
    console.log('[TUT] keepAwake ativado');
    activateKeepAwakeAsync('tutorial').catch(() => {});
    return () => deactivateKeepAwake('tutorial');
  }, []);

  // Abertura: frases so avancam com toque na tela; apos a 3a frase -> cutscene.
  const [fase, setFase] = useState('intro'); // 'intro' | 'cutscene'
  const [fraseIdx, setFraseIdx] = useState(0);
  const ultimoToqueRef = useRef(0);

  // Entrada da frase: fade + subida suave (600ms). Roda no mount e a cada toque.
  // Termina SEMPRE em opacidade 1 (nunca some depois de aparecer).
  const opFrase = useRef(new Animated.Value(0)).current;
  const sobeFrase = useRef(new Animated.Value(14)).current;

  useEffect(() => {
    opFrase.setValue(0);
    sobeFrase.setValue(14);
    Animated.parallel([
      Animated.timing(opFrase, { toValue: 1, duration: 600, useNativeDriver: true }),
      Animated.timing(sobeFrase, { toValue: 0, duration: 600, useNativeDriver: true }),
    ]).start(({ finished }) => {
      if (finished) {
        opFrase.setValue(1);
        sobeFrase.setValue(0);
      }
    });
    return () => {
      opFrase.stopAnimation();
      sobeFrase.stopAnimation();
    };
  }, [fraseIdx, opFrase, sobeFrase]);

  // Logs de depuracao (SO no console do Metro): transicoes e dims reais.
  useEffect(() => {
    console.log('[TUT] dims', Dimensions.get('window'));
  }, []);
  useEffect(() => {
    console.log('[TUT] fase:', fase);
  }, [fase]);
  useEffect(() => {
    console.log('[TUT] frase:', fraseIdx);
  }, [fraseIdx]);

  const busyRef = useRef(false); // ignora toques durante fades/portais
  const pausaRef = useRef(false); // ignora toques durante pausa dramatica
  const timersRef = useRef([]);
  // Guards sincronos (toque duplo no mesmo frame nao pode pular fala/quadro).
  const falaIdxRef = useRef(QUADROS[0].comecarSemCaixa ? -1 : 0);
  const overlayRef = useRef(false);
  const fimRef = useRef(false);
  const transicaoRef = useRef(null);

  const setFalaSeguro = (valor) => {
    falaIdxRef.current = valor;
    setFalaIdx(valor);
  };

  const agendar = useCallback((fn, ms) => {
    const t = setTimeout(fn, ms);
    timersRef.current.push(t);
    return t;
  }, []);

  // Limpa todos os timers ao desmontar (sem listeners/timers orfaos).
  useEffect(
    () => () => {
      timersRef.current.forEach((t) => clearTimeout(t));
      timersRef.current = [];
    },
    []
  );

  const quadroAtual = QUADROS[indice];
  // Fala vigente (clamp): usada na caixa do overlay do deck inicial.
  const falaAtual = quadroAtual.dialogues[
    Math.min(Math.max(falaIdx, 0), quadroAtual.dialogues.length - 1)
  ];

  const finalizar = useCallback(() => {
    fimRef.current = true;
    setFim(true);
    if (perfil && !perfil.tutorialConcluido && onSalvarPerfil) {
      onSalvarPerfil({ ...perfil, tutorialConcluido: true });
    }
  }, [perfil, onSalvarPerfil]);

  const proximoQuadro = useCallback(() => {
    if (indice >= QUADROS.length - 1) {
      finalizar();
      return;
    }
    const prox = indice + 1;
    busyRef.current = true;
    setIndice(prox);
    setFalaSeguro(QUADROS[prox].comecarSemCaixa ? -1 : 0);
    agendar(() => {
      busyRef.current = false;
    }, DUR_FADE);
  }, [indice, finalizar, agendar]);

  const iniciarPortal = useCallback(() => {
    if (indice >= QUADROS.length - 1) {
      finalizar();
      return;
    }
    busyRef.current = true;
    transicaoRef.current = 'portal';
    setTransicao('portal');
    agendar(() => {
      const prox = indice + 1;
      setIndice(prox);
      setFalaSeguro(QUADROS[prox].comecarSemCaixa ? -1 : 0);
      transicaoRef.current = null;
      setTransicao(null);
      agendar(() => {
        busyRef.current = false;
      }, DUR_FADE);
    }, DUR_PORTAL);
  }, [indice, finalizar, agendar]);

  const sairDoQuadro = useCallback(
    (quadro) => {
      console.log('[TUT] sairDoQuadro', quadro.id, quadro.transicaoSaida || quadro.acaoAoTerminar || 'proximo');
      if (quadro.transicaoSaida === 'portal') {
        iniciarPortal();
        return;
      }
      if (quadro.acaoAoTerminar === 'mostrarDeck') {
        overlayRef.current = true;
        setOverlayDeck(true);
        return;
      }
      if (quadro.acaoAoTerminar === 'fim') {
        finalizar();
        return;
      }
      proximoQuadro();
    },
    [iniciarPortal, finalizar, proximoQuadro]
  );

  // Avanco manual: proxima fala, ou saida do quadro na ultima fala.
  const avancar = useCallback(() => {
    const bloqueado =
      busyRef.current ||
      pausaRef.current ||
      overlayRef.current ||
      fimRef.current ||
      transicaoRef.current;
    console.log('[TUT] avancar', {
      busy: busyRef.current,
      pausa: pausaRef.current,
      overlay: overlayRef.current,
      fim: fimRef.current,
      transicao: transicaoRef.current,
      indice,
      fala: falaIdxRef.current,
    });
    if (bloqueado) {
      return;
    }
    const quadro = QUADROS[indice];
    const total = quadro.dialogues.length;
    const atual = falaIdxRef.current;
    console.log('[TUT] avancar OK', { quadro: quadro.id, atual, total });

    if (atual < total - 1) {
      const prox = atual + 1;
      setFalaSeguro(prox);
      // Pausa dramatica depois da ULTIMA fala do quadro (spec 12).
      if (prox === total - 1 && quadro.pausaAntesProximo > 0) {
        pausaRef.current = true;
        setPausaAtiva(true);
        agendar(() => {
          pausaRef.current = false;
          setPausaAtiva(false);
        }, quadro.pausaAntesProximo);
      }
      return;
    }

    sairDoQuadro(quadro);
  }, [indice, sairDoQuadro, agendar]);

  const concluirDeck = useCallback(() => {
    overlayRef.current = false;
    setOverlayDeck(false);
    proximoQuadro();
  }, [proximoQuadro]);

  // TOQUE em qualquer lugar: SO na fase de frases da abertura.
  // Sem fade, sem animacao: a frase muda instantaneamente.
  // O guard duplo (timestamp + setState funcional) evita pular frases.
  const toqueTela = () => {
    const agora = Date.now();
    if (agora - ultimoToqueRef.current < INTERVALO_TOQUE) return;
    ultimoToqueRef.current = agora;

    console.log('[TUT] toque intro', { fraseIdx });
    setFraseIdx((prev) => {
      if (prev < FRASES_INTRO.length - 1) {
        return prev + 1;
      }
      // Ultima frase: avanca para a cutscene (fora do setState abaixo).
      return prev;
    });
    if (fraseIdx >= FRASES_INTRO.length - 1) {
      setFase('cutscene');
    }
  };

  // Cutscene: dialogo/cena SO avanca quando clica na CAIXA DE LEGENDA.
  const toqueCaixa = () => {
    avancar();
  };

  const conteudo = (
    <Animated.View style={styles.container}>
      {fase === 'intro' && (
        <Animated.View
          style={[
            styles.introWrap,
            { opacity: opFrase, transform: [{ translateY: sobeFrase }] },
          ]}
          pointerEvents="none"
        >
          <Text style={styles.introTexto}>{FRASES_INTRO[fraseIdx]}</Text>
        </Animated.View>
      )}

      {fase === 'cutscene' && (
        <>
          <CutscenePlayer
            quadro={quadroAtual}
            falaIdx={falaIdx}
            pausaAtiva={pausaAtiva}
            transicao={transicao}
            onToque={toqueCaixa}
            mostrarGuia={!overlayDeck}
          />

          <DeckTutorial visivel={overlayDeck} onConcluir={concluirDeck} fala={falaAtual} />

          {fim && (
            <View style={styles.painelFim}>
              <Text style={styles.fimTitulo}>TUTORIAL CONCLUIDO</Text>
              <Text style={styles.fimFala}>Boa sorte. — GUIA</Text>
              <Text style={styles.fimDescricao}>
                {"O proximo passo e o seu primeiro duelo.\nO sistema de batalha e o mesmo do jogo normal."}
              </Text>

              <TouchableOpacity
                style={styles.botaoPrincipal}
                activeOpacity={0.8}
                onPress={onIniciarBatalha}
              >
                <Text style={styles.botaoPrincipalTexto}>COMEÇAR O PRIMEIRO DUELO</Text>
              </TouchableOpacity>

              <TouchableOpacity style={styles.botaoSecundario} activeOpacity={0.8} onPress={onVoltar}>
                <Text style={styles.botaoSecundarioTexto}>VOLTAR AO MENU</Text>
              </TouchableOpacity>
            </View>
          )}
        </>
      )}
    </Animated.View>
  );

  // Frases da abertura: toque em qualquer lugar (Pressable cobre a tela toda).
  // Cutscene: so a CAIXA DE LEGENDA passa dialogo/cena.
  if (fase === 'intro') {
    return (
      <Pressable onPress={toqueTela} accessibilityRole="button" style={styles.container}>
        {conteudo}
      </Pressable>
    );
  }
  return conteudo;
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    width: '100%',
    height: '100%',
    backgroundColor: '#05050A',
  },
  introWrap: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
    paddingHorizontal: 34,
    // Texto da intro acima de TODOS os elementos (deck=50, painel=60).
    zIndex: 999,
  },
  introTexto: {
    width: '100%',
    color: '#FFFFFF',
    fontSize: 23,
    lineHeight: 34,
    letterSpacing: 1,
    textAlign: 'center',
    textShadowColor: 'rgba(255,255,255,0.35)',
    textShadowOffset: { width: 0, height: 0 },
    textShadowRadius: 12,
  },
  // ---- painel final ----
  painelFim: {
    ...StyleSheet.absoluteFillObject,
    backgroundColor: 'rgba(3, 3, 8, 0.94)',
    alignItems: 'center',
    justifyContent: 'center',
    paddingHorizontal: 26,
    zIndex: 60,
  },
  fimTitulo: {
    color: '#FFD54F',
    fontSize: 22,
    letterSpacing: 4,
    marginBottom: 10,
  },
  fimFala: {
    color: '#FFFFFF',
    fontSize: 16,
    marginBottom: 10,
  },
  fimDescricao: {
    color: '#9B9BB4',
    fontSize: 12,
    lineHeight: 18,
    textAlign: 'center',
    marginBottom: 26,
  },
  botaoPrincipal: {
    width: '100%',
    paddingVertical: 14,
    backgroundColor: 'rgba(10,10,26,0.9)',
    borderWidth: 2,
    borderColor: '#FFD54F',
    borderRadius: 12,
    alignItems: 'center',
    marginBottom: 12,
    shadowColor: '#FFD54F',
    shadowOffset: { width: 0, height: 0 },
    shadowOpacity: 0.5,
    shadowRadius: 8,
    elevation: 8,
  },
  botaoPrincipalTexto: {
    color: '#FFD54F',
    fontSize: 13,
    letterSpacing: 2,
  },
  botaoSecundario: {
    width: '100%',
    paddingVertical: 12,
    borderRadius: 12,
    borderWidth: 1,
    borderColor: '#3A3A52',
    alignItems: 'center',
  },
  botaoSecundarioTexto: {
    color: '#9B9BB4',
    fontSize: 11,
    letterSpacing: 2,
  },
});