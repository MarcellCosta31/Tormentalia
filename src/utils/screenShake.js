import { withSequence, withTiming, runOnJS } from 'react-native-reanimated';

/**
 * Executa screen shake (tremor de tela) em dois shared values do Reanimated.
 * @param {SharedValue} shakeX - SharedValue para translateX
 * @param {SharedValue} shakeY - SharedValue para translateY
 * @param {number} intensidade - Intensidade do shake (padrão: 6)
 * @param {function} onCompleto - Callback opcional ao finalizar
 */
export function screenShake(shakeX, shakeY, intensidade = 6, onCompleto) {
  'worklet';
  const duracao = 40;

  const callbackFinal = onCompleto ? runOnJS(onCompleto) : undefined;

  shakeX.value = withSequence(
    withTiming(intensidade, { duration: duracao }),
    withTiming(-intensidade, { duration: duracao }),
    withTiming(intensidade * 0.6, { duration: duracao }),
    withTiming(0, { duration: duracao }, (finished) => {
      if (finished && callbackFinal) {
        callbackFinal();
      }
    })
  );

  shakeY.value = withSequence(
    withTiming(intensidade * 0.5, { duration: duracao }),
    withTiming(-intensidade * 0.5, { duration: duracao }),
    withTiming(intensidade * 0.3, { duration: duracao }),
    withTiming(0, { duration: duracao })
  );
}
