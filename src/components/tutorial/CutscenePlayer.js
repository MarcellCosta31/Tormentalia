import React, { useEffect, useRef, useState } from 'react';
import { View, StyleSheet, Animated, Dimensions } from 'react-native';
import PlaceholderQuadro from './PlaceholderQuadro';
import CaixaLegenda, { DicaAvulsa } from './CaixaLegenda';
import DestaqueTipos from './DestaqueTipos';
import { FundoCiclico, SpriteGuia } from './CenaLuz';
import { FALANTE } from '../../tutorial/cenas';
import logLayout from '../../utils/logLayout';

const { width: SCREEN_WIDTH, height: SCREEN_HEIGHT } = Dimensions.get('window');

// Transicao portal (spec 13): fade to black + luz branca crescendo.
function PortalLuz() {
  const luz = useRef(new Animated.Value(0)).current;

  useEffect(() => {
    const anim = Animated.timing(luz, {
      toValue: 1,
      duration: 1600,
      useNativeDriver: true,
    });
    anim.start();
    return () => luz.stopAnimation();
  }, [luz]);

  const escala = luz.interpolate({ inputRange: [0, 1], outputRange: [0.3, 28] });
  const brilho = luz.interpolate({ inputRange: [0, 0.6, 1], outputRange: [0, 1, 1] });

  return (
    <View style={styles.portalFundo} pointerEvents="none">
      <Animated.View
        style={[
          styles.portalLuz,
          { transform: [{ scale: escala }], opacity: brilho },
        ]}
      />
    </View>
  );
}

// Renderizacao da cutscene: quadro (arte ou placeholder) + legenda + toque.
// O CONTROLE (indices, pausas, acoes) fica no TelaTutorial (controller).
//
// props:
//   quadro      -> objeto do quadro atual (src/tutorial/cenas.js)
//   falaIdx     -> -1 = nenhuma fala em tela; senao indice da fala atual
//   pausaAtiva  -> true = toques bloqueados (pausa dramatica)
//   transicao   -> null | 'portal'
//   onToque     -> chamado SO ao tocar na CAIXA DE LEGENDA (passa dialogo/cena)
export default function CutscenePlayer({
  quadro,
  falaIdx,
  pausaAtiva,
  transicao,
  onToque,
  mostrarGuia = true,
}) {
  const op = useRef(new Animated.Value(1)).current;
  const exibindoRef = useRef(quadro);
  const [exibindo, setExibindo] = useState(quadro);

  // Entrada do 1o quadro: fade + zoom sutil (600ms) ao entrar na cutscene.
  // Termina SEMPRE em opacidade 1 / escala 1.
  const opQuadro = useRef(new Animated.Value(0)).current;
  const escalaQuadro = useRef(new Animated.Value(0.94)).current;

  useEffect(() => {
    opQuadro.setValue(0);
    escalaQuadro.setValue(0.94);
    Animated.parallel([
      Animated.timing(opQuadro, { toValue: 1, duration: 600, useNativeDriver: true }),
      Animated.timing(escalaQuadro, { toValue: 1, duration: 600, useNativeDriver: true }),
    ]).start(({ finished }) => {
      if (finished) {
        opQuadro.setValue(1);
        escalaQuadro.setValue(1);
      }
    });
    return () => {
      opQuadro.stopAnimation();
      escalaQuadro.stopAnimation();
    };
  }, [opQuadro, escalaQuadro]);

  // Fade out -> troca de quadro -> fade in (ou fade out do portal).
  useEffect(() => {
    if (transicao === 'portal') {
      Animated.timing(op, { toValue: 0, duration: 400, useNativeDriver: true }).start();
      return undefined;
    }
    if (quadro.id !== exibindoRef.current.id) {
      Animated.timing(op, { toValue: 0, duration: 300, useNativeDriver: true }).start(
        ({ finished }) => {
          if (!finished) return;
          exibindoRef.current = quadro;
          setExibindo(quadro);
          Animated.timing(op, { toValue: 1, duration: 400, useNativeDriver: true }).start();
        }
      );
    }
    return undefined;
  }, [quadro, transicao, op]);

  const falaAtual = falaIdx >= 0 ? exibindo.dialogues[falaIdx] : null;
  // Cena da luz: fundo preto/cinza ciclico + bola do Guia (sem placeholder 16:9).
  const cenaLuz = exibindo.fundo === 'ciclico';
  const falandoGuia = !!falaAtual && falaAtual.speaker === FALANTE.GUIA;

  return (
    // box-none: o container NAO captura toque; quem captura e a caixa de legenda.
    <View
      style={styles.container}
      pointerEvents="box-none"
      onLayout={logLayout('cutscene')}
    >
      {cenaLuz && <FundoCiclico />}
      {cenaLuz && mostrarGuia && (
        <View style={styles.areaBola} pointerEvents="none">
          <SpriteGuia falando={falandoGuia} />
        </View>
      )}
      <Animated.View style={[styles.camada, { opacity: op }]}>
        <Animated.View
          style={[
            styles.areaImagem,
            { opacity: opQuadro, transform: [{ scale: escalaQuadro }] },
          ]}
          onLayout={logLayout('areaImagem')}
        >
          {!cenaLuz && <PlaceholderQuadro quadro={exibindo} />}
        </Animated.View>

        <View style={styles.espacoLegenda}>
          <DestaqueTipos tipo={falaAtual?.destaque || null} />
        </View>

        {falaAtual ? (
          <CaixaLegenda
            speaker={falaAtual.speaker}
            texto={falaAtual.text}
            mostrarDica={!pausaAtiva}
            onToque={onToque}
          />
        ) : falaIdx === -1 ? (
          <DicaAvulsa onToque={onToque} />
        ) : null}
      </Animated.View>

      {transicao === 'portal' && <PortalLuz />}
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#05050A',
  },
  camada: {
    flex: 1,
    // Precisa ser posicao + zIndex para ficar ACIMA dos absolutos (fundo/bola):
    // o RN pinta elementos posicionados sobre o conteudo normal.
    position: 'relative',
    zIndex: 5,
  },
  areaBola: {
    position: 'absolute',
    left: 0,
    right: 0,
    top: 0,
    bottom: 128,
    alignItems: 'center',
    justifyContent: 'center',
    zIndex: 1,
  },
  areaImagem: {
    flex: 1,
    justifyContent: 'center',
  },
  espacoLegenda: {
    marginBottom: 128,
  },
  // ---- portal ----
  portalFundo: {
    ...StyleSheet.absoluteFillObject,
    backgroundColor: '#000000',
    alignItems: 'center',
    justifyContent: 'center',
    zIndex: 30,
  },
  portalLuz: {
    width: 24,
    height: 24,
    borderRadius: 12,
    backgroundColor: '#FFFFFF',
    shadowColor: '#FFFFFF',
    shadowOffset: { width: 0, height: 0 },
    shadowOpacity: 1,
    shadowRadius: 18,
    elevation: 16,
  },
});
