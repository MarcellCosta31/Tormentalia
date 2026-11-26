param()
# Musica de fundo do MENU (sons/menu.wav): tema original de 105,0s
# (40 compassos a 91,4 BPM) — SUSPENSE com mistura de conforto:
# misterio acolhedor de RPG (nao terror, nao batalha, nao épica).
# Mesma familia dos efeitos: 16-bit PCM 44100Hz mono, seed fixa,
# reproduzivel, SEM audio externo e SEM vocais.
#
# Harmonia (ciclo de 4, ci = barra % 4): Am9 -> Fmaj7 -> Dm9 -> Esus4.
# 10 ciclos = 40 compassos; o fim fica em Esus4 (tensao) e cai direto
# no Am9 do comeco: LOOP PERFEITO com respiro de suspense.
#
# Suspense: drone de la (A2) na intro e no breakdown, ostinato de
# arpejo em quartos, notas avulsas de sino, F5 sobre Esus4 e o
# Esus4 que nunca resolve enquanto a musica toca.
# Conforto: pad quente com conducao de vozes, piano eletrico (Rhodes)
# na melodia, walking bass jazz suave e bateria com swing discreta.
#
# Estrutura (b = compasso; BAR = 2,625s):
#   b0-5   intro: pad + drone A2 + sinos esparsos (suspense puro)
#   b6-15  pulso entra gradual: ostinato, baixo simples, chapeu,
#          kick (b10), snare (b12)
#   b16-27 nucleo de conforto: melodias P1/P2/P3 em piano eletrico,
#          walking bass e bateria leve
#   b28-33 breakdown: pad + drone + ostinato fraco + motivo de sino
#   b34-39 retorno: re-entrada (b34-35) e P1 que fecha em B4
#          (sem resolucao) — a costura mantem a tensao.
$ErrorActionPreference = "Stop"
$raiz = Split-Path -Parent $MyInvocation.MyCommand.Path
$saida = Join-Path $raiz "sons"
if (-not (Test-Path $saida)) { New-Item -ItemType Directory -Path $saida | Out-Null }

$cs = @'
using System;
using System.IO;

public class MenuMusic {
  public const int SR = 44100;
  private double[] b;
  private Random rnd = new Random(7);
  private const int Fade = 700;

  public MenuMusic(double seconds) {
    b = new double[(int)Math.Round(seconds * SR)];
  }

  private void Add(int idx, double v) {
    if (idx >= 0 && idx < b.Length) b[idx] += v;
  }

  // Senoide com decaimento, 1/2/3 harmonicos opcionais e fade de saida
  // (todas as vozes terminam em zero => loop sem estalo).
  public void Sine(double f, double dur, double vol, double decay,
                   double delay, double h2, double h3) {
    int off = (int)(delay * SR);
    int n = (int)(dur * SR);
    for (int i = 0; i < n; i++) {
      double t = (double)i / SR;
      double e = Math.Exp(-decay * t);
      double v = Math.Sin(2 * Math.PI * f * t);
      if (h2 != 0) v += h2 * Math.Sin(4 * Math.PI * f * t);
      if (h3 != 0) v += h3 * Math.Sin(6 * Math.PI * f * t);
      int nf = n - i;
      if (nf <= Fade) v *= (double)nf / Fade;
      Add(off + i, vol * e * v);
    }
  }

  // Quadrada banda-limitada (1 + 1/3 + 1/5): timbre 16-bit macio.
  public void Square(double f, double dur, double vol, double decay,
                     double delay) {
    int off = (int)(delay * SR);
    int n = (int)(dur * SR);
    for (int i = 0; i < n; i++) {
      double t = (double)i / SR;
      double e = Math.Exp(-decay * t);
      double v = Math.Sin(2 * Math.PI * f * t)
        + Math.Sin(6 * Math.PI * f * t) / 3.0
        + Math.Sin(10 * Math.PI * f * t) / 5.0;
      int nf = n - i;
      if (nf <= Fade) v *= (double)nf / Fade;
      Add(off + i, vol * e * v);
    }
  }

  // Pad: frequencia ajustada para ciclos inteiros na duracao (termina em
  // zero exato) — costura perfeita entre compassos.
  public void Pad(double f, double dur, double vol, double delay) {
    double fq = Math.Round(f * dur) / dur;
    Sine(fq, dur, vol, 0.10, delay, 0, 0);
  }

  // Piano eletrico (Rhodes): fundamental + 2a harmonica + ataque campainha.
  public void Epi(double f, double delay, double dur, double vol) {
    Sine(f, dur, vol, 0.75, delay, 0.32, 0);
    Sine(f * 4, 0.05, vol * 0.45, 26, delay, 0, 0);
  }

  // Sino/celesta (suspense): fundamental + par harmonico agudo.
  public void Bell(double f, double delay, double dur, double vol) {
    Sine(f, dur, vol, 1.9, delay, 0, 0.5);
    Sine(f * 2.76, dur * 0.55, vol * 0.4, 3.5, delay, 0, 0);
  }

  // Baixo redondo: fundamental + leve 2a para corpo.
  public void BassN(double f, double delay, double dur, double vol) {
    Sine(f, dur, vol, 3.6, delay, 0.18, 0);
  }

  public void Kick(double delay, double vol) {
    int off = (int)(delay * SR);
    int n = (int)(0.18 * SR);
    double ph = 0;
    for (int i = 0; i < n; i++) {
      double t = (double)i / SR;
      double f = 48 + 75 * Math.Exp(-28 * t);
      ph += 2 * Math.PI * f / SR;
      double v = vol * Math.Exp(-16 * t) * Math.Sin(ph);
      int nf = n - i;
      if (nf <= Fade) v *= (double)nf / Fade;
      Add(off + i, v);
    }
  }

  private double Noise(double dur, double vol, double decay, double lp,
                       double delay) {
    int off = (int)(delay * SR);
    int n = (int)(dur * SR);
    double prev = 0;
    double sum = 0;
    for (int i = 0; i < n; i++) {
      double t = (double)i / SR;
      double w = rnd.NextDouble() * 2 - 1;
      prev = prev + lp * (w - prev);
      double v = vol * Math.Exp(-decay * t) * prev;
      int nf = n - i;
      if (nf <= Fade) v *= (double)nf / Fade;
      Add(off + i, v);
      sum += Math.Abs(v);
    }
    return sum;
  }

  // Snare leve (ruido filtrado + tom curto) — som discreto, nao agressivo.
  public void Snare(double delay, double vol) {
    Noise(0.12, vol, 24, 0.5, delay);
    Sine(195, 0.07, vol * 0.6, 35, delay, 0, 0);
  }

  public void Hat(double delay, double vol, double dur) {
    Noise(dur, vol, 90, 0.92, delay);
  }

  public byte[] ToWav() {
    double pico = 0;
    for (int i = 0; i < b.Length; i++) {
      double a = Math.Abs(b[i]);
      if (a > pico) pico = a;
    }
    double esc = pico > 0 ? 0.85 / pico : 1;
    byte[] outb = new byte[44 + b.Length * 2];
    Array.Copy(System.Text.Encoding.ASCII.GetBytes("RIFF"), 0, outb, 0, 4);
    BitConverter.GetBytes((Int32)(36 + b.Length * 2)).CopyTo(outb, 4);
    Array.Copy(System.Text.Encoding.ASCII.GetBytes("WAVE"), 0, outb, 8, 4);
    Array.Copy(System.Text.Encoding.ASCII.GetBytes("fmt "), 0, outb, 12, 4);
    BitConverter.GetBytes((Int32)16).CopyTo(outb, 16);
    BitConverter.GetBytes((Int16)1).CopyTo(outb, 20);
    BitConverter.GetBytes((Int16)1).CopyTo(outb, 22);
    BitConverter.GetBytes((Int32)SR).CopyTo(outb, 24);
    BitConverter.GetBytes((Int32)(SR * 2)).CopyTo(outb, 28);
    BitConverter.GetBytes((Int16)2).CopyTo(outb, 32);
    BitConverter.GetBytes((Int16)16).CopyTo(outb, 34);
    Array.Copy(System.Text.Encoding.ASCII.GetBytes("data"), 0, outb, 36, 4);
    BitConverter.GetBytes((Int32)(b.Length * 2)).CopyTo(outb, 40);
    for (int i = 0; i < b.Length; i++) {
      double v = b[i] * esc;
      if (v > 1) v = 1;
      if (v < -1) v = -1;
      Int16 s = (Int16)Math.Round(v * 32000);
      byte lo = (byte)(s & 0xff);
      byte hi = (byte)((s >> 8) & 0xff);
      outb[44 + i * 2] = lo;
      outb[44 + i * 2 + 1] = hi;
    }
    return outb;
  }

  // --------------------------------------------------------------------
  public static byte[] Build() {
    // 91,4286 BPM: 40 compassos x 2,625s = 105,0s exatos.
    double BEAT = 105.0 / (40 * 4);
    double BAR = 4 * BEAT;
    int NB = 40;
    MenuMusic m = new MenuMusic(NB * BAR);

    // Pad quente (3 vozes, conducao suave): Am9 Fmaj7 Dm9 Esus4.
    double[][] PAD = new double[][] {
      new double[]{261.63, 329.63, 493.88},  // Am9: C4 E4 B4
      new double[]{261.63, 329.63, 440},     // Fmaj7: C4 E4 A4
      new double[]{261.63, 349.23, 440},     // Dm9: C4 F4 A4
      new double[]{246.94, 293.66, 440}      // Esus4: B3 D4 A4
    };
    for (int bar = 0; bar < NB; bar++) {
      int ci = bar % 4;
      double t0 = bar * BAR;
      double vol = (bar <= 5 || (bar >= 28 && bar <= 33)) ? 0.034 : 0.030;
      for (int j = 0; j < 3; j++) m.Pad(PAD[ci][j], BAR, vol, t0);
    }

    // Drone de la (A2): suspense puro na intro e no breakdown. Quantizado
    // para ciclos inteiros — a costura continua exata.
    for (int bar = 0; bar <= 5; bar++) m.Pad(110, BAR, 0.050, bar * BAR);
    for (int bar = 28; bar <= 33; bar++) m.Pad(110, BAR, 0.050, bar * BAR);

    // Ostinato de arpejo (quartos): hipnotico, discreto. Existe so na
    // entrada e no breakdown — no nucleo de conforto ele sai.
    double[][] OST = new double[][] {
      new double[]{440, 659.26, 493.88, 659.26},     // Am9
      new double[]{349.23, 523.25, 440, 523.25},     // Fmaj7
      new double[]{293.66, 440, 659.26, 440},        // Dm9
      new double[]{329.63, 493.88, 659.26, 493.88}   // Esus4
    };
    for (int bar = 5; bar <= 15; bar++) {
      int ci = bar % 4;
      double t0 = bar * BAR;
      double vol = (bar == 5) ? 0.030 : 0.035;
      for (int k = 0; k < 4; k++)
        m.Square(OST[ci][k], 0.7 * BEAT, vol, 2.6, t0 + k * BEAT);
    }
    for (int bar = 28; bar <= 33; bar++) {
      int ci = bar % 4;
      double t0 = bar * BAR;
      for (int k = 0; k < 4; k++)
        m.Square(OST[ci][k], 0.7 * BEAT, 0.030, 2.6, t0 + k * BEAT);
    }

    // Baixo: simples na entrada gradual (b6-15: raiz + quinta) e
    // walking jazz suave no conforto (b16-27, b34-39). Quartos leves;
    // G#2 do fim aponta para o A2 da costura (loop invisivel).
    double[][] WALK = new double[][] {
      new double[]{110, 130.81, 164.81, 98},      // Am9 -> G2 aprox. F2
      new double[]{87.31, 110, 130.81, 82.41},    // Fmaj7 -> E2 aprox. D2
      new double[]{73.42, 87.31, 110, 87.31},     // Dm9 -> F2 -> E2
      new double[]{82.41, 110, 123.47, 103.83}    // Esus4 -> G#2 -> A2
    };
    double[] sRaiz = new double[]{110, 87.31, 73.42, 82.41};
    double[] sQuin = new double[]{82.41, 65.41, 110, 123.47};
    for (int bar = 6; bar <= 15; bar++) {
      int ci = bar % 4;
      double t0 = bar * BAR;
      m.BassN(sRaiz[ci], t0, 1.75 * BEAT, 0.17);
      m.BassN(sQuin[ci], t0 + 2.5 * BEAT, 1.0 * BEAT, 0.15);
    }
    for (int bar = 16; bar <= 27; bar++) {
      int ci = bar % 4;
      double t0 = bar * BAR;
      for (int k = 0; k < 4; k++)
        m.BassN(WALK[ci][k], t0 + k * BEAT, 0.8 * BEAT, 0.21);
    }
    for (int bar = 34; bar <= 39; bar++) {
      int ci = bar % 4;
      double t0 = bar * BAR;
      for (int k = 0; k < 4; k++)
        m.BassN(WALK[ci][k], t0 + k * BEAT, 0.8 * BEAT, 0.21);
    }

    // Bateria sintetica discreta com swing (offbeats em 2/3 de batida).
    double[] H = new double[]{0, 2.0 / 3, 1, 5.0 / 3, 2, 7.0 / 3, 3, 8.0 / 3};
    for (int bar = 0; bar < NB; bar++) {
      double t0 = bar * BAR;
      bool kick = (bar >= 10 && bar <= 27) || bar >= 34;
      bool snare = (bar >= 12 && bar <= 27) || bar >= 34;
      bool chapeu = (bar >= 6 && bar <= 27) || bar >= 34;
      if (kick) {
        m.Kick(t0, 0.32);
        m.Kick(t0 + 2 * BEAT, 0.24);
      }
      if (snare) {
        m.Snare(t0 + 1 * BEAT, 0.12);
        m.Snare(t0 + 3 * BEAT, 0.12);
        if (bar % 4 == 3) m.Snare(t0 + 11.0 / 3 * BEAT, 0.035);
      }
      if (chapeu) {
        double esc = (bar >= 6 && bar <= 8) ? 0.75 : 1.0;
        for (int k = 0; k < H.Length; k++) {
          bool off = H[k] != Math.Floor(H[k]);
          m.Hat(t0 + H[k] * BEAT, (off ? 0.026 : 0.042) * esc, 0.045);
        }
      }
    }
    // chapeus de costura: fim da intro (b5) e entrada do retorno (b33).
    m.Hat(5 * BAR + 11.0 / 3 * BEAT, 0.03, 0.06);
    double[] entra33 = new double[]{2, 8.0 / 3, 3, 11.0 / 3};
    for (int k = 0; k < entra33.Length; k++)
      m.Hat(33 * BAR + entra33[k] * BEAT, 0.03, 0.05);

    // Sinos: avulsos na intro (mistério) e motivo no breakdown.
    double A4 = 440, B4 = 493.88, C5 = 523.25, D5 = 587.33;
    double E5 = 659.26, F5 = 698.46, G5 = 783.99;
    m.Bell(A4, 1 * BAR + 1.5 * BEAT, 2.5 * BEAT, 0.050);
    m.Bell(E5, 2 * BAR + 3 * BEAT, 1.5 * BEAT, 0.040);
    m.Bell(B4, 3 * BAR, 2.5 * BEAT, 0.045);
    // Motivo suspenso-consolador (sino): E-G-F-E (vizinho superior).
    double[][] sinB28 = new double[][] {
      new double[]{0, E5, 1}, new double[]{1, G5, 0.5},
      new double[]{1.5, F5, 0.5}, new double[]{2, E5, 1.5}
    };
    for (int i = 0; i < sinB28.Length; i++)
      m.Bell(sinB28[i][1], 28 * BAR + sinB28[i][0] * BEAT,
        sinB28[i][2] * BEAT, 0.060);
    // Variante mais fraca sobre o Esus4 (b31) e ponte do retorno (b33).
    double[][] sinB31 = new double[][] {
      new double[]{0, E5, 0.75}, new double[]{0.75, D5, 0.75},
      new double[]{1.5, B4, 1.5}
    };
    for (int i = 0; i < sinB31.Length; i++)
      m.Bell(sinB31[i][1], 31 * BAR + sinB31[i][0] * BEAT,
        sinB31[i][2] * BEAT, 0.050);
    m.Bell(E5, 33 * BAR + 2 * BEAT, 2 * BEAT, 0.045);

    // Nucleo de conforto: melodias em piano eletrico.
    // P1 (calma, passo a passo), P2 (varia mais alto, com F5 tenso
    // sobre o Esus4), P3 (descida rumo ao breakdown).
    double[][] P1 = new double[][] {
      new double[]{0, 0, E5, 1.5}, new double[]{0, 1.5, D5, 0.5},
      new double[]{0, 2, C5, 1.5},
      new double[]{1, 0, C5, 1.5}, new double[]{1, 1.5, A4, 0.5},
      new double[]{1, 2, C5, 1.5},
      new double[]{2, 0, D5, 1}, new double[]{2, 1, E5, 1},
      new double[]{2, 2, F5, 1}, new double[]{2, 3, E5, 1},
      new double[]{3, 0, E5, 1.5}, new double[]{3, 1.5, D5, 0.5},
      new double[]{3, 2, B4, 2}
    };
    double[][] P2 = new double[][] {
      new double[]{0, 0, 880, 1}, new double[]{0, 1, G5, 0.5},
      new double[]{0, 1.5, E5, 1.5}, new double[]{0, 3, D5, 0.5},
      new double[]{1, 0, C5, 0.5}, new double[]{1, 0.5, D5, 0.5},
      new double[]{1, 1, C5, 1}, new double[]{1, 2, A4, 1.5},
      new double[]{2, 0, E5, 1}, new double[]{2, 1, F5, 1},
      new double[]{2, 2, 880, 1}, new double[]{2, 3, G5, 1},
      new double[]{3, 0, E5, 1.5}, new double[]{3, 1.5, F5, 0.5},
      new double[]{3, 2, E5, 1}, new double[]{3, 3, B4, 1}
    };
    double[][] P3 = new double[][] {
      new double[]{0, 0, E5, 1}, new double[]{0, 1, D5, 1},
      new double[]{0, 2, C5, 2},
      new double[]{1, 0, A4, 1}, new double[]{1, 1, C5, 1},
      new double[]{1, 2, A4, 2},
      new double[]{2, 0, F5, 1.5}, new double[]{2, 1.5, E5, 0.5},
      new double[]{2, 2, D5, 2},
      new double[]{3, 0, B4, 1}, new double[]{3, 1.5, D5, 0.5},
      new double[]{3, 2, E5, 1.5}
    };
    // Re-entrada do retorno (b34 = Dm9, b35 = Esus4).
    double[][] PR = new double[][] {
      new double[]{0, 0, D5, 1}, new double[]{0, 1, E5, 1},
      new double[]{0, 2, F5, 1.5},
      new double[]{1, 0, E5, 1}, new double[]{1, 1, D5, 1},
      new double[]{1, 2, B4, 1.5}
    };

    // Colocacoes: {frase, barra inicial, volume}.
    double[][] frases = new double[][] {
      new double[]{16, 100, 0}, new double[]{20, 110, 1},
      new double[]{24, 100, 2}, new double[]{36, 100, 0}
    };
    double[][][] conteudos = new double[][][]{P1, P2, P3};
    for (int i = 0; i < frases.Length; i++) {
      int baseBar = (int)frases[i][0];
      double vol = frases[i][1] / 1000.0;
      double[][] frase = conteudos[(int)frases[i][2]];
      for (int j = 0; j < frase.Length; j++) {
        double[] n = frase[j];
        m.Epi(n[2], (baseBar + n[0]) * BAR + n[1] * BEAT,
          n[3] * BEAT, vol);
      }
    }
    double volR = 0.09;
    for (int j = 0; j < PR.Length; j++) {
      double[] n = PR[j];
      m.Epi(n[2], (34 + n[0]) * BAR + n[1] * BEAT, n[3] * BEAT, volR);
    }

    return m.ToWav();
  }
}
'@

Add-Type -TypeDefinition $cs -Language CSharp
$bytes = [MenuMusic]::Build()
$caminho = Join-Path $saida "menu.wav"
[IO.File]::WriteAllBytes($caminho, $bytes)
$seg = ($bytes.Length - 44) / 2.0 / 44100.0
Write-Host ("menu.wav gerado: {0} bytes ({1:N1}s)" -f $bytes.Length, $seg)
