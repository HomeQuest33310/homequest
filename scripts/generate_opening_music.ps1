param(
  [string]$OutputPath = ''
)

$repoRoot = Split-Path -Parent $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($OutputPath)) {
  $OutputPath = Join-Path $repoRoot 'app\assets\audio\opening_theme.wav'
}

$outputDirectory = Split-Path -Parent $OutputPath
New-Item -ItemType Directory -Force -Path $outputDirectory | Out-Null

Add-Type -TypeDefinition @'
using System;
using System.IO;
using System.Text;

public static class HomeQuestOpeningMusic
{
    public static void Generate(string outputPath)
    {
        const int sampleRate = 22050;
        const int channels = 1;
        const int bitsPerSample = 16;
        const double durationSeconds = 24.0;
        int sampleCount = (int)(sampleRate * durationSeconds);
        int dataLength = sampleCount * channels * (bitsPerSample / 8);

        double[][] chords = new double[][]
        {
            new double[] { 146.83, 174.61, 220.00, 329.63 },
            new double[] { 116.54, 146.83, 174.61, 261.63 },
            new double[] { 130.81, 164.81, 196.00, 293.66 },
            new double[] { 130.81, 196.00, 220.00, 293.66 },
        };
        double[] bellNotes = new double[]
        {
            293.66, 440.00, 349.23, 523.25,
            329.63, 440.00, 392.00, 293.66,
        };

        using (var stream = File.Create(outputPath))
        using (var writer = new BinaryWriter(stream))
        {
            writer.Write(Encoding.ASCII.GetBytes("RIFF"));
            writer.Write(36 + dataLength);
            writer.Write(Encoding.ASCII.GetBytes("WAVE"));
            writer.Write(Encoding.ASCII.GetBytes("fmt "));
            writer.Write(16);
            writer.Write((short)1);
            writer.Write((short)channels);
            writer.Write(sampleRate);
            writer.Write(sampleRate * channels * (bitsPerSample / 8));
            writer.Write((short)(channels * (bitsPerSample / 8)));
            writer.Write((short)bitsPerSample);
            writer.Write(Encoding.ASCII.GetBytes("data"));
            writer.Write(dataLength);

            var random = new Random(7319);
            double softenedNoise = 0.0;

            for (int i = 0; i < sampleCount; i++)
            {
                double t = (double)i / sampleRate;
                int chordIndex = Math.Min(chords.Length - 1, (int)(t / 6.0));
                double sample = 0.0;

                // A slow, breathing harmonic veil.
                for (int voice = 0; voice < chords[chordIndex].Length; voice++)
                {
                    double frequency = chords[chordIndex][voice];
                    double drift = 1.0 + 0.0018 * Math.Sin(2.0 * Math.PI * (0.031 + voice * 0.007) * t);
                    double breath = 0.72 + 0.28 * Math.Sin(2.0 * Math.PI * (0.055 + voice * 0.011) * t + voice);
                    sample += 0.045 * breath * Math.Sin(2.0 * Math.PI * frequency * drift * t + voice * 0.9);
                }

                // A quiet low D anchors the heroic atmosphere.
                sample += 0.055 * Math.Sin(2.0 * Math.PI * 73.42 * t);
                sample += 0.018 * Math.Sin(2.0 * Math.PI * 110.00 * t + 0.4);

                // Bell-like runes awaken at regular intervals.
                const double bellSpacing = 2.25;
                int bellIndex = (int)(t / bellSpacing);
                double bellTime = t - bellIndex * bellSpacing;
                if (bellTime < 2.0)
                {
                    double frequency = bellNotes[bellIndex % bellNotes.Length];
                    double attack = 1.0 - Math.Exp(-38.0 * bellTime);
                    double decay = Math.Exp(-2.35 * bellTime);
                    double envelope = attack * decay;
                    sample += envelope * (
                        0.115 * Math.Sin(2.0 * Math.PI * frequency * bellTime) +
                        0.047 * Math.Sin(2.0 * Math.PI * frequency * 2.01 * bellTime + 0.2) +
                        0.021 * Math.Sin(2.0 * Math.PI * frequency * 3.98 * bellTime + 0.6)
                    );
                }

                // Barely audible air keeps the piece organic without using samples.
                double whiteNoise = random.NextDouble() * 2.0 - 1.0;
                softenedNoise = softenedNoise * 0.997 + whiteNoise * 0.003;
                sample += softenedNoise * 0.018;

                double fadeIn = Math.Min(1.0, t / 1.8);
                double fadeOut = Math.Min(1.0, (durationSeconds - t) / 2.8);
                double master = Math.Max(0.0, Math.Min(fadeIn, fadeOut));
                sample *= master * 0.82;
                sample = Math.Tanh(sample * 1.15);

                short pcm = (short)Math.Round(Math.Max(-1.0, Math.Min(1.0, sample)) * short.MaxValue);
                writer.Write(pcm);
            }
        }
    }
}
'@

[HomeQuestOpeningMusic]::Generate([System.IO.Path]::GetFullPath($OutputPath))
Write-Output "Original HomeQuest opening music generated at $OutputPath"
