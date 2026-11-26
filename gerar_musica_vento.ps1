param()
# Vento da SELECAO DE CICLOS (sons/vento.wav): ambiencia de vento que
# soa CONSTANTEMENTE — leito de ruido branco filtrado em 4 camadas,
# com rajadas lentas (LFOs) respirando por cima. SEM melodias, SEM
# percussao: e sons/musica do ceu aberto, nao um tema. Mesma familia
# dos demais: 16-bit PCM 44100Hz mono, seed fixa, reproduzivel, SEM
# audio externo e SEM vocais.
#
# Camadas (todas ruido branco independente, sem correlacao cruzada):
#   A corpo grave:  lowpass de corte "respirando" (80..680 Hz) + rajadas
#   B assobio:     banda entre dois lowpasses (corte agitado 400..2400)
#   C ar fino:     highpass discreto, some so nas rajadas fortes
#   D rumble:      integrador com vazamento (sub-20Hz) bem fraco
#
# Loop perfeito (sem estalo): os LFOs completam ciclos INTEIROS no
# comprimento do loop (custura exata da modulacao) e o comeco recebe o
# fim em crossfade com smoothstep (2s). O sample 0 e continuacao exata
# do sample final — o loop nao tem costura audivel.
$ErrorActionPreference = "Stop"
$raiz = Split-Path -Parent $MyInvocation.MyCommand.Path
$saida = Join-Path $raiz "sons"
if (-not (Test-Path $saida)) { New-Item -ItemType Directory -Path $saida | Out-Null }

$cs = @'
using System;

public class VentoAmbiente {
  public const int SR = 44100;
  private double[] b;       // buffer bruto (loop + pedaco da costura)
  private double[] loop;    // loop final (tamanho exato do loop)
  private Random rnd = new Random(23);
  private readonly int nT;  // samples do loop
  private readonly int nX;  // samples do crossfade da costura

  public VentoAmbiente(double loopSec, double fadeSec) {
    nT = (int)Math.Round(loopSec * SR);
    nX = (int)Math.Round(fadeSec * SR);
    b = new double[nT + nX];
    loop = new double[nT];
  }

  private double W() { return rnd.NextDouble() * 2 - 1; }

  // Gera as camadas do vento. T = duracao do loop: todo LFO usa ciclos
  // inteiros em T, entao a modulacao na costura e exata.
  public void Gerar() {
    double T = (double)nT / SR;
    double lpA = 0, lpBf = 0, lpBs = 0, lpC = 0, brow = 0;
    for (int i = 0; i < b.Length; i++) {
      double t = (double)i / SR;
      // Rajadas lentas: 1 ciclo/loop + 2 ciclos/loop (vento que nunca
      // fica parado, mas tambem nunca some — sempre soa).
      double gust = 0.70
        + 0.16 * Math.Sin(2 * Math.PI * 1 * t / T + 0.6)
        + 0.14 * Math.Sin(2 * Math.PI * 2 * t / T + 2.1);

      // A) corpo grave: lowpass com corte respirando.
      double fcA = 380 + 200 * Math.Sin(2 * Math.PI * t / T)
        + 100 * Math.Sin(2 * Math.PI * 3 * t / T + 1.3);
      if (fcA < 70) fcA = 70;
      double aA = 1 - Math.Exp(-2 * Math.PI * fcA / SR);
      double w1 = W();
      lpA += aA * (w1 - lpA);

      // B) assobio do vento: ruido menos lowpass lento = banda (o corte
      // da banda sobe e desce, da o "vai e vem" do vento).
      double fcB = 1400 + 700 * Math.Sin(2 * Math.PI * 2 * t / T + 0.9)
        + 300 * Math.Sin(2 * Math.PI * t / T);
      double aB = 1 - Math.Exp(-2 * Math.PI * fcB / SR);
      double w2 = W();
      lpBf += aB * (w2 - lpBf);
      double aBs = 1 - Math.Exp(-2 * Math.PI * 260 / SR);
      lpBs += aBs * (w2 - lpBs);

      // C) ar fino: highpass por diferenca, so nas rajadas fortes.
      double aC = 1 - Math.Exp(-2 * Math.PI * 1800 / SR);
      double w3 = W();
      lpC += aC * (w3 - lpC);

      // D) rumble distante: integrador com vazamento (quase DC-free).
      brow = brow * 0.9985 + 0.03 * W();
      double rumble = brow * (0.8 + 0.2 * Math.Sin(2 * Math.PI * t / T + 3.0));

      b[i] = 0.85 * lpA * gust
        + 0.55 * (lpBf - lpBs) * (0.55 + 0.45 * gust)
        + 0.06 * (w3 - lpC) * gust * gust
        + 0.10 * rumble;
    }

    // Remove o DC do rumble antes da costura.
    double media = 0;
    for (int i = 0; i < b.Length; i++) media += b[i];
    media /= b.Length;
    for (int i = 0; i < b.Length; i++) b[i] -= media;

    // Costura: o comeco recebe o fim (crossfade smoothstep). nT e a
    // continuacao exata de nT-1 (dentro do buffer bruto), entao o loop
    // fecha sem degrau — e a modulacao dos LFOs fecha por ciclos inteiros.
    for (int i = 0; i < nX; i++) {
      double s = (double)i / nX;
      double w = s * s * (3 - 2 * s);   // smoothstep 0..1
      loop[i] = b[nT + i] * (1 - w) + b[i] * w;
    }
    for (int i = nX; i < nT; i++) loop[i] = b[i];
  }

  public byte[] ToWav() {
    double pico = 0;
    for (int i = 0; i < loop.Length; i++) {
      double a = Math.Abs(loop[i]);
      if (a > pico) pico = a;
    }
    double esc = pico > 0 ? 0.85 / pico : 1;
    byte[] outb = new byte[44 + loop.Length * 2];
    Array.Copy(System.Text.Encoding.ASCII.GetBytes("RIFF"), 0, outb, 0, 4);
    BitConverter.GetBytes((Int32)(36 + loop.Length * 2)).CopyTo(outb, 4);
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
    BitConverter.GetBytes((Int32)(loop.Length * 2)).CopyTo(outb, 40);
    for (int i = 0; i < loop.Length; i++) {
      double v = loop[i] * esc;
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

  public static byte[] Build() {
    // Loop de 20s com 2s de crossfade: constante, lento e sem costura.
    VentoAmbiente v = new VentoAmbiente(20.0, 2.0);
    v.Gerar();
    return v.ToWav();
  }
}
'@

Add-Type -TypeDefinition $cs -Language CSharp
$bytes = [VentoAmbiente]::Build()
$caminho = Join-Path $saida "vento.wav"
[IO.File]::WriteAllBytes($caminho, $bytes)
$seg = ($bytes.Length - 44) / 2.0 / 44100.0
Write-Host ("vento.wav gerado: {0} bytes ({1:N1}s)" -f $bytes.Length, $seg)
