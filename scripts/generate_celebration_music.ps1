param([string]$OutputPath = '')

$repoRoot = Split-Path -Parent $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($OutputPath)) {
  $OutputPath = Join-Path $repoRoot 'app\assets\audio\celebration_fanfare.wav'
}
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $OutputPath) | Out-Null

Add-Type -TypeDefinition @'
using System;
using System.IO;
using System.Text;

public static class HomeQuestCelebrationMusic {
  public static void Generate(string path) {
    const int rate = 22050, seconds = 8;
    int count = rate * seconds, dataLength = count * 2;
    double[] melody = {293.66, 369.99, 440.00, 587.33, 493.88, 587.33, 739.99, 880.00};
    double[] bass = {73.42, 92.50, 110.00, 146.83};
    using (var stream = File.Create(path))
    using (var writer = new BinaryWriter(stream)) {
      writer.Write(Encoding.ASCII.GetBytes("RIFF")); writer.Write(36 + dataLength);
      writer.Write(Encoding.ASCII.GetBytes("WAVEfmt ")); writer.Write(16);
      writer.Write((short)1); writer.Write((short)1); writer.Write(rate);
      writer.Write(rate * 2); writer.Write((short)2); writer.Write((short)16);
      writer.Write(Encoding.ASCII.GetBytes("data")); writer.Write(dataLength);
      for (int i = 0; i < count; i++) {
        double t = (double)i / rate;
        int beat = Math.Min(melody.Length - 1, (int)t);
        double local = t - Math.Floor(t);
        double envelope = (1.0 - Math.Exp(-30 * local)) * Math.Exp(-2.2 * local);
        double note = melody[beat];
        double sample = envelope * (0.22 * Math.Sin(2 * Math.PI * note * t)
          + 0.08 * Math.Sin(2 * Math.PI * note * 2 * t));
        sample += 0.09 * Math.Sin(2 * Math.PI * bass[Math.Min(3, (int)(t / 2))] * t);
        double drumTime = (t * 2) - Math.Floor(t * 2);
        sample += 0.08 * Math.Exp(-14 * drumTime) * Math.Sin(2 * Math.PI * 58 * drumTime);
        double fade = Math.Min(1, Math.Min(t / 0.25, (seconds - t) / 1.2));
        short pcm = (short)(Math.Max(-1, Math.Min(1, Math.Tanh(sample * fade))) * 32767);
        writer.Write(pcm);
      }
    }
  }
}
'@

[HomeQuestCelebrationMusic]::Generate([System.IO.Path]::GetFullPath($OutputPath))
Write-Output "Original HomeQuest celebration music generated at $OutputPath"
