import React, { useEffect, useState } from 'react';
import { Dimensions, Image, StyleSheet, TouchableWithoutFeedback } from 'react-native';
import Animated, {
  useSharedValue,
  useAnimatedStyle,
  withTiming,
  runOnJS,
} from 'react-native-reanimated';

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

function prefetchFrames(frames) {
  frames.forEach((frameModule) => {
    try {
      const { uri } = Image.resolveAssetSource(frameModule);
      if (uri) {
        Image.prefetch(uri).catch(() => {});
      }
    } catch (e) {}
  });
}

const TelaIntro = ({ onAvancar }) => {
  const translateX = useSharedValue(SCREEN_WIDTH);
  const [currentFrame, setCurrentFrame] = useState(andandoFrames[0]);
  const [fase, setFase] = useState('andando');
  const frameAndandoRef = React.useRef(0);
  const frameSimboloRef = React.useRef(0);

  const animatedStyle = useAnimatedStyle(() => ({
    transform: [{ translateX: translateX.value }],
  }));

  useEffect(() => {
    prefetchFrames(andandoFrames);
    prefetchFrames(simboloFrames);
  }, []);

  useEffect(() => {
    translateX.value = withTiming(0, { duration: 4000 }, (finished) => {
      if (finished) {
        runOnJS(setFase)('simbolo');
      }
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
          style={[styles.sprite, animatedStyle]}
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
