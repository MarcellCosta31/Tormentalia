import React, { useEffect } from 'react';
import { TouchableOpacity, Image, StyleSheet, Dimensions } from 'react-native';

const { width: SCREEN_WIDTH, height: SCREEN_HEIGHT } = Dimensions.get('window');

const TelaLogo = ({ onAvancar }) => {
  useEffect(() => {
    const timer = setTimeout(() => {
      onAvancar();
    }, 3000);
    return () => clearTimeout(timer);
  }, []);

  return (
    <TouchableOpacity style={styles.container} activeOpacity={1} onPress={onAvancar}>
      <Image
        source={require('../assets/sprites/logoTela/logo.jpg')}
        style={styles.logo}
        resizeMode="contain"
      />
    </TouchableOpacity>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#07060bff',
    justifyContent: 'center',
    alignItems: 'center',
  },
  logo: {
    width: SCREEN_WIDTH * 0.8,
    height: SCREEN_HEIGHT * 0.8,
  },
});

export default TelaLogo;
