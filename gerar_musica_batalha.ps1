param()
# Musica de BATALHA (sons/batalha.wav): tema sintetico agitado de 64,0s
# (40 compassos a 150 BPM) — combate tenso de RPG: bateria forte em
# backbeat, baixo em colcheias "andando", arpejo em semicolcheias e
# melodia heroica que entra no segundo bloco. Mesma familia do menu:
# 16-bit PCM 44100Hz mono, seed fixa, reproduzivel, SEM audio externo.
#
# Harmonia (ciclo de 4, ci = barra % 4): Dm -> Bb -> F -> C
# (i - VI - III - VII em re menor). 10 ciclos = 40 compassos e o fim
# (barra 39 com preenchida de snare) cai direto na barra 0: LOOP PERFEITO
# com a energia continuando.
#
# Estrutura (b = compasso; BAR = 1,6s):
#   b0-7    A: bateria + baixo + arpejo (combate puro)
#   b8-15   A': entra a melodia (frase P1)
#   b16-19  quebra: so chapeu/baixo tenso + roldata de snare na barra 19
#   b20-27  queda: tudo de volta + melodia P1
#   b28-35  climax: P1 uma oitava acima + stab de acordes
#   b36-39  virada: sem melodia, preenchida de 16avos na barra 39 -> b0
$ErrorActionPreference = "Stop"
$raiz = Split-Path -Parent $MyInvocation.MyCommand.Path
$saida = Join-Path $raiz "sons"
if (-not (Test-Path $saida)) { New-Item -ItemType Directory -Path $saida | Out-Null }

$cs = @'
using System;
using System.IO;

public class BattleMusic {
  public const int SR = 44100;
  private double[] b;
  private Random rnd = new Random(11);
  private const int Fade = 700;

  public BattleMusic(double seconds) {
    b = new double[(int)Math.Round(seconds * SR)];
  }

  private void Add(int idx, double v) {
    if (idx >= 0 && idx < b.Length) b[idx] += v;
  }

  // Senoide com decaimento, 2a/3a harmonicas opcionais e fade de saida
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

  // Bumbo pesado (pitch caindo) — batida forte de batalha.
  public void Kick(double delay, double vol) {
    int off = (int)(delay * SR);
    int n = (int)(0.22 * SR);
    double ph = 0;
    for (int i = 0; i < n; i++) {
      double t = (double)i / SR;
      double f = 52 + 95 * Math.Exp(-26 * t);
      ph += 2 * Math.PI * f / SR;
      double v = vol * Math.Exp(-13 * t) * Math.Sin(ph);
      int nf = n - i;
      if (nf <= Fade) v *= (double)nf / Fade;
      Add(off + i, v);
    }
  }

  // Caixa: ruido filtrado + corpo de tom — backbeat nitido.
  public void Snare(double delay, double vol) {
    Noise(0.16, vol, 26, 0.5, delay);
    Sine(188, 0.09, vol * 0.7, 30, delay, 0, 0);
  }

  public void Hat(double delay, double vol) {
    Noise(0.05, vol, 110, 0.94, delay);
  }

  public void OpenHat(double delay, double vol) {
    Noise(0.24, vol, 16, 0.9, delay);
  }

  // Prato de secao (impacto nos blocos).
  public void Crash(double delay, double vol) {
    Noise(1.7, vol, 2.6, 0.8, delay);
  }

  // Baixo de combate: sub + quadrada com decaimento rapido.
  public void Bass(double f, double delay, double dur, double vol) {
    Sine(f, dur, vol * 0.9, 2.6, delay, 0, 0);
    Square(f, dur, vol * 0.35, 4.2, delay);
  }

  // Melodia: fundamental cheia + quadrada ao lado + brilho curto.
  public void Lead(double f, double delay, double dur, double vol) {
    Sine(f, dur, vol * 0.7, 1.1, delay, 0, 0);
    Square(f, dur, vol * 0.4, 1.3, delay);
    Sine(f * 2, dur * 0.4, vol * 0.18, 3.0, delay, 0, 0);
  }

  // Stab de acorde (curto e seco).
  public void Stab(double[] fs, double delay, double dur, double vol) {
    for (int i = 0; i < fs.Length; i++)
      Square(fs[i], dur, vol, 6.5, delay);
  }

  // Arpejo de semicolcheia (rapido e tenso).
  public void Arp(double f, double delay, double dur, double vol) {
    Square(f, dur, vol, 5.5, delay);
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
    double BEAT = 0.4;                 // 150 BPM
    double BAR = 4 * BEAT;             // 1,6s
    int NB = 40;                       // 40 bar = 64,0s (loop exato)
    BattleMusic m = new BattleMusic(NB * BAR);

    // Ciclo Dm -> Bb -> F -> C: raizes do baixo (2a octave grave).
    double[] RAIZ = new double[]{ 73.42, 58.27, 87.31, 65.41 };
    double[] PROX = new double[]{ 58.27, 87.31, 65.41, 73.42 };
    // Tons do arpejo (4 notas por acorde, 2 octave).
    double[][] TONS = new double[][] {
      new double[]{293.66, 349.23, 440, 587.33},      // Dm: D4 F4 A4 D5
      new double[]{233.08, 293.66, 349.23, 466.16},   // Bb: Bb3 D4 F4 Bb4
      new double[]{349.23, 440, 523.25, 698.46},      // F:  F4 A4 C5 F5
      new double[]{261.63, 329.63, 392, 523.25}       // C:  C4 E4 G4 C5
    };
    // Triades para o stab do climax.
    double[][] TRIADES = new double[][] {
      new double[]{293.66, 349.23, 440},
      new double[]{233.08, 293.66, 349.23},
      new double[]{349.23, 440, 523.25},
      new double[]{261.63, 329.63, 392}
    };

    // Frase da melodia: {barra (0..7), batida, frequencia, duracao em
    // batidas} — toca em b8-15, b20-27 e (uma oitava acima) b28-35.
    double[][] P1 = new double[][] {
      new double[]{0, 0, 440, 1}, new double[]{0, 1, 587.33, 0.5},
      new double[]{0, 1.5, 523.25, 0.5}, new double[]{0, 2, 440, 1.5},
      new double[]{0, 3.5, 392, 0.5},
      new double[]{1, 0, 349.23, 1}, new double[]{1, 1, 440, 1},
      new double[]{1, 2, 466.16, 2},
      new double[]{2, 0, 523.25, 1}, new double[]{2, 1, 440, 1},
      new double[]{2, 2, 349.23, 2},
      new double[]{3, 0, 392, 1}, new double[]{3, 1, 440, 1},
      new double[]{3, 2, 523.25, 1}, new double[]{3, 3, 587.33, 1},
      new double[]{4, 0, 587.33, 1.5}, new double[]{4, 1.5, 523.25, 0.5},
      new double[]{4, 2, 440, 2},
      new double[]{5, 0, 466.16, 1}, new double[]{5, 1, 587.33, 1},
      new double[]{5, 2, 523.25, 2},
      new double[]{6, 0, 440, 1}, new double[]{6, 1, 523.25, 1},
      new double[]{6, 2, 587.33, 1}, new double[]{6, 3, 659.26, 1},
      new double[]{7, 0, 698.46, 2}, new double[]{7, 2, 587.33, 1},
      new double[]{7, 3, 440, 1}
    };

    for (int bar = 0; bar < NB; bar++) {
      int ci = bar % 4;
      double t0 = bar * BAR;
      bool quebra = bar >= 16 && bar <= 19;
      bool comLead = (bar >= 8 && bar <= 15) || (bar >= 20 && bar <= 35);
      bool oitava = bar >= 28 && bar <= 35;
      bool stabs = bar >= 28 && bar <= 35;

      // --- Bateria -----------------------------------------------------
      if (!quebra) {
        m.Kick(t0, 0.55);
        m.Kick(t0 + 2 * BEAT, 0.46);
        m.Kick(t0 + 2.75 * BEAT, 0.34);
        m.Snare(t0 + 1 * BEAT, 0.30);
        m.Snare(t0 + 3 * BEAT, 0.30);
        for (int k = 0; k < 8; k++) {
          double tt = t0 + k * 0.5 * BEAT;
          bool off = (k % 2) == 1;
          if (k == 7) m.OpenHat(tt, 0.10);
          else m.Hat(tt, off ? 0.08 : 0.12);
        }
      } else {
        // Quebra: so chapeu em semicolcheias, subindo de intensidade.
        double sobe = 0.05 + 0.015 * (bar - 16);
        for (int k = 0; k < 16; k++)
          m.Hat(t0 + k * 0.25 * BEAT, sobe + (k % 2 == 0 ? 0.03 : 0));
      }

      // --- Baixo -------------------------------------------------------
      if (quebra) {
        m.Bass(RAIZ[ci], t0, 4 * BEAT, 0.22);
        m.Bass(RAIZ[ci], t0 + 2 * BEAT, 2 * BEAT, 0.16);
      } else {
        for (int k = 0; k < 8; k++) {
          double tt = t0 + k * 0.5 * BEAT;
          // Antecipacao da proxima raiz na ultima colcheia = adiantamento.
          double f = (k == 7) ? PROX[ci] : RAIZ[ci];
          m.Bass(f, tt, 0.46 * BEAT, 0.30);
        }
      }

      // --- Arpejo (sempre, tenso) --------------------------------------
      double volArp = quebra ? 0.045 : (bar >= 20 ? 0.07 : 0.06);
      for (int k = 0; k < 16; k++) {
        double f = TONS[ci][k % 4];
        m.Arp(f, t0 + k * 0.25 * BEAT, 0.23 * BEAT, volArp);
      }

      // --- Melodia -----------------------------------------------------
      if (comLead) {
        int rel = bar <= 15 ? bar - 8 : (bar <= 27 ? bar - 20 : bar - 28);
        for (int i = 0; i < P1.Length; i++) {
          if ((int)P1[i][0] != rel) continue;
          double f = P1[i][2] * (oitava ? 2 : 1);
          double ini = t0 + P1[i][1] * BEAT;
          m.Lead(f, ini, P1[i][3] * BEAT * 0.95, 0.16);
        }
      }

      // --- Stab de acorde (climax) -------------------------------------
      if (stabs) {
        m.Stab(TRIADES[ci], t0, 0.3 * BEAT, 0.10);
        m.Stab(TRIADES[ci], t0 + 2.5 * BEAT, 0.25 * BEAT, 0.07);
      }
    }

    // Impactos de secao.
    m.Crash(0, 0.16);
    m.Crash(8 * BAR, 0.20);
    m.Crash(20 * BAR, 0.24);
    m.Crash(28 * BAR, 0.20);

    // Preenchidas (16avos) que costuram as viradas: barra 19 (sai da
    // quebra) e barra 39 (volta para a barra 0 do loop).
    for (int k = 0; k < 4; k++) {
      m.Snare(19 * BAR + (3 + k * 0.25) * BEAT, 0.14 + 0.05 * k);
      m.Snare(39 * BAR + (3 + k * 0.25) * BEAT, 0.16 + 0.06 * k);
    }

    return m.ToWav();
  }
}
'@

Add-Type -TypeDefinition $cs -Language CSharp
$bytes = [BattleMusic]::Build()
$caminho = Join-Path $saida "batalha.wav"
[IO.File]::WriteAllBytes($caminho, $bytes)
$seg = ($bytes.Length - 44) / 2.0 / 44100.0
Write-Host ("batalha.wav gerado: {0} bytes ({1:N1}s)" -f $bytes.Length, $seg)
