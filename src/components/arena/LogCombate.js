import React, { useRef, useEffect } from 'react';
import { View, ScrollView, StyleSheet } from 'react-native';
import Text from '../Texto';

export default function LogCombate({ log }) {
  const scrollRef = useRef(null);

  useEffect(() => {
    if (scrollRef.current) {
      scrollRef.current.scrollToEnd({ animated: true });
    }
  }, [log]);

  if (!log || log.length === 0) return null;

  return (
    <View style={styles.container}>
      <Text style={styles.titulo}>LOG DE COMBATE</Text>
      <ScrollView ref={scrollRef} style={styles.scroll} showsVerticalScrollIndicator={false}>
        {log.map((entrada, idx) => (
          <Text key={idx} style={styles.entrada}>
            {entrada}
          </Text>
        ))}
      </ScrollView>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    position: 'absolute',
    top: 4,
    right: 4,
    width: 180,
    maxHeight: 120,
    backgroundColor: 'rgba(0, 0, 0, 0.75)',
    borderRadius: 6,
    borderWidth: 1,
    borderColor: '#555',
    padding: 4,
    zIndex: 10,
  },
  titulo: {
    fontSize: 8,
    color: '#888',
    fontWeight: 'bold',
    marginBottom: 2,
  },
  scroll: {
    flex: 1,
  },
  entrada: {
    fontSize: 8,
    color: '#CCC',
    paddingVertical: 1,
    borderBottomWidth: 0.5,
    borderBottomColor: '#333',
  },
});
