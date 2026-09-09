import React, { useEffect, useRef, useState } from 'react';
import { Animated, Dimensions, Image, StyleSheet, TouchableWithoutFeedback } from 'react-native';

const { width: SCREEN_WIDTH, height: SCREEN_HEIGHT } = Dimensions.get('window');

const andandoFrames = [
  require('../assets/sprites/logoTela/andando/1.png'),
  require('../assets/sprites/logoTela/andando/2.png'),
  require('../assets/sprites/logoTela/andando/3.png'),
  require('../assets/sprites/logoTela/andando/4.png'),
  require('../assets/sprites/logoTela/andando/5.png'),
  require('../assets/sprites/logoTela/andando/6.png'),
  require('../assets/sprites/logoTela/andando/7.png'),
  require('../assets/sprites/logoTela/andando/8.png'),
];

const simboloFrames = [
  require('../assets/sprites/logoTela/simbolo/1.png'),
  require('../assets/sprites/logoTela/simbolo/2.png'),
  require('../assets/sprites/logoTela/simbolo/3.png'),
  require('../assets/sprites/logoTela/simbolo/4.png'),
  require('../assets/sprites/logoTela/simbolo/5.png'),
  require('../assets/sprites/logoTela/simbolo/6.png'),
  require('../assets/sprites/logoTela/simbolo/7.png'),
  require('../assets/sprites/logoTela/simbolo/8.png'),
];

const SPRITE_SIZE = SCREEN_HEIGHT * 0.3;
const FPS_ANDANDO = 8;
const FPS_SIMBOLO = 6;

// Forca o RN a decodificar/cachear cada frame ANTES de usa-lo na troca rapida
// de source. Sem isso, principalmente no Android, o primeiro uso de cada
// imagem pode dar um "flash" em branco (parece piscar) enquanto decodifica.
function prefetchFrames(frames) {
  frames.forEach((frameModule) => {
    try {
      const { uri } = Image.resolveAssetSource(frameModule);
      if (uri) {
        Image.prefetch(uri).catch(() => {});
      }
    } catch (e) {
      // Se o resolve falhar (ex: ambiente sem suporte), apenas ignora -
      // o require() local ja garante que a imagem existe no bundle.
    }
  });
}

const TelaIntro = ({ onAvancar }) => {
  const translateX = useRef(new Animated.Value(SCREEN_WIDTH)).current;
  const [currentFrame, setCurrentFrame] = useState(andandoFrames[0]);
  const [fase, setFase] = useState('andando');
  const frameAndandoRef = useRef(0);
  const frameSimboloRef = useRef(0);

  // Pre-carrega TODOS os frames (andando + simbolo) assim que o componente monta,
  // dando tempo de sobra (a caminhada dura 4s) para tudo estar em cache antes
  // da fase do simbolo comecar a trocar de frame rapidamente.
  useEffect(() => {
    prefetchFrames(andandoFrames);
    prefetchFrames(simboloFrames);
  }, []);

  useEffect(() => {
    Animated.timing(translateX, {
      toValue: 0,
      duration: 4000,
      useNativeDriver: true,
    }).start(() => {
      setFase('simbolo');
    });
  }, []);

  useEffect(() => {
    if (fase === 'andando') {
      const interval = setInterval(() => {
        frameAndandoRef.current = (frameAndandoRef.current + 1) % andandoFrames.length;
        setCurrentFrame(andandoFrames[frameAndandoRef.current]);
      }, 1000 / FPS_ANDANDO);
      return () => clearInterval(interval);
    }
  }, [fase]);

  useEffect(() => {
    if (fase === 'simbolo') {
      frameSimboloRef.current = 0;
      setCurrentFrame(simboloFrames[0]);
      const interval = setInterval(() => {
        if (frameSimboloRef.current < simboloFrames.length - 1) {
          frameSimboloRef.current += 1;
          setCurrentFrame(simboloFrames[frameSimboloRef.current]);
        } else {
          clearInterval(interval);
          setTimeout(() => onAvancar(), 800);
        }
      }, 1000 / FPS_SIMBOLO);
      return () => clearInterval(interval);
    }
  }, [fase]);

  return (
    <TouchableWithoutFeedback onPress={onAvancar}>
      <Animated.View style={styles.container}>
        <Animated.Image
          source={currentFrame}
          fadeDuration={0}
          style={[
            styles.sprite,
            { transform: [{ translateX }] },
          ]}
          resizeMode="contain"
        />
      </Animated.View>
    </TouchableWithoutFeedback>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#07060bff',
    justifyContent: 'center',
    alignItems: 'center',
  },
  sprite: {
    width: SPRITE_SIZE,
    height: SPRITE_SIZE,
  },
});

export default TelaIntro;