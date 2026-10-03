import React from 'react';
import { StyleSheet, Text as RNText } from 'react-native';

export const FONTE = 'VCR_OSD_MONO_1.001';

export default function Text({ style, ...props }) {
  const extra = StyleSheet.flatten(style);
  const estilo = { fontFamily: FONTE, ...extra };

  if (!extra?.fontFamily) {
    delete estilo.fontWeight;
    delete estilo.fontStyle;
  }

  return <RNText {...props} style={estilo} />;
}
