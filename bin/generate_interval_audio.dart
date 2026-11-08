// ignore_for_file: avoid_print
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

void main() {
  const sampleRate = 22050;

  // 1. Generate interval_work.wav (energetic prompt: D5 587Hz -> A5 880Hz)
  final workSamples = <double>[];
  final workPart1Duration = 0.12;
  final workPart2Duration = 0.18;
  final nWork1 = (workPart1Duration * sampleRate).round();
  final nWork2 = (workPart2Duration * sampleRate).round();

  for (int i = 0; i < nWork1; i++) {
    final t = i / sampleRate;
    final env = math.min(1.0, math.min(i / 150.0, (nWork1 - i) / 150.0));
    final sample = math.sin(2 * math.pi * 587.33 * t) * 0.7 * env;
    workSamples.add(sample);
  }
  for (int i = 0; i < nWork2; i++) {
    final t = i / sampleRate;
    final env = math.min(1.0, math.min(i / 150.0, (nWork2 - i) / 150.0));
    final sample = math.sin(2 * math.pi * 880.0 * t) * 0.85 * env;
    workSamples.add(sample);
  }

  writeWavFile('assets/audio/interval_work.wav', workSamples, sampleRate);
  print('Generated assets/audio/interval_work.wav');

  // 2. Generate interval_rest.wav (calm prompt: E5 659Hz -> A4 440Hz)
  final restSamples = <double>[];
  final restPart1Duration = 0.12;
  final restPart2Duration = 0.18;
  final nRest1 = (restPart1Duration * sampleRate).round();
  final nRest2 = (restPart2Duration * sampleRate).round();

  for (int i = 0; i < nRest1; i++) {
    final t = i / sampleRate;
    final env = math.min(1.0, math.min(i / 150.0, (nRest1 - i) / 150.0));
    final sample = math.sin(2 * math.pi * 659.25 * t) * 0.7 * env;
    restSamples.add(sample);
  }
  for (int i = 0; i < nRest2; i++) {
    final t = i / sampleRate;
    final env = math.min(1.0, math.min(i / 150.0, (nRest2 - i) / 150.0));
    final sample = math.sin(2 * math.pi * 440.0 * t) * 0.7 * env;
    restSamples.add(sample);
  }

  writeWavFile('assets/audio/interval_rest.wav', restSamples, sampleRate);
  print('Generated assets/audio/interval_rest.wav');
}

void writeWavFile(String path, List<double> samples, int sampleRate) {
  final numSamples = samples.length;
  final subchunk2Size = numSamples * 2; // 16-bit mono = 2 bytes per sample
  final chunkSize = 36 + subchunk2Size;
  final byteRate = sampleRate * 2;
  const blockAlign = 2;
  const bitsPerSample = 16;

  final bytes = BytesBuilder();

  // RIFF Header
  bytes.add('RIFF'.codeUnits);
  final headerByteData = ByteData(4)..setUint32(0, chunkSize, Endian.little);
  bytes.add(headerByteData.buffer.asUint8List());
  bytes.add('WAVE'.codeUnits);

  // fmt subchunk
  bytes.add('fmt '.codeUnits);
  final fmtData = ByteData(20)
    ..setUint32(0, 16, Endian.little) // Subchunk1Size (always 16 for PCM)
    ..setUint16(4, 1, Endian.little) // AudioFormat: 1 (PCM)
    ..setUint16(6, 1, Endian.little) // NumChannels: 1 (Mono)
    ..setUint32(8, sampleRate, Endian.little) // SampleRate
    ..setUint32(12, byteRate, Endian.little) // ByteRate
    ..setUint16(16, blockAlign, Endian.little) // BlockAlign
    ..setUint16(18, bitsPerSample, Endian.little); // BitsPerSample
  bytes.add(fmtData.buffer.asUint8List());

  // data subchunk
  bytes.add('data'.codeUnits);
  final dataSizeHeader = ByteData(4)
    ..setUint32(0, subchunk2Size, Endian.little);
  bytes.add(dataSizeHeader.buffer.asUint8List());

  final pcmData = ByteData(subchunk2Size);
  for (int i = 0; i < numSamples; i++) {
    final clamped = samples[i].clamp(-1.0, 1.0);
    final pcmVal = (clamped * 32767).round();
    pcmData.setInt16(i * 2, pcmVal, Endian.little);
  }
  bytes.add(pcmData.buffer.asUint8List());

  File(path).writeAsBytesSync(bytes.toBytes());
}
