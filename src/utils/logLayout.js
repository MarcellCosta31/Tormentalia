// Depuracao de layout: loga geometria (x/y/w/h) SO no console do Metro.
export default function logLayout(nome) {
  return (e) => {
    const l = e.nativeEvent.layout;
    console.log(`[TUT] layout ${nome}`, {
      x: Math.round(l.x),
      y: Math.round(l.y),
      w: Math.round(l.width),
      h: Math.round(l.height),
    });
  };
}
