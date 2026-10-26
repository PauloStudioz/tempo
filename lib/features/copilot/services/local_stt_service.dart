import 'dart:convert';
import 'dart:io';

class LocalSttService {
  static List<String> get _candidateDirs {
    final exeDir = File(Platform.resolvedExecutable).parent.path;
    return [
      '$exeDir\\models\\stt',
      r'models\stt',
      r'..\models\stt',
      r'C:\Users\LOQ\.gemini\antigravity\scratch\tempo\models\stt',
    ];
  }

  static File? getModelFile() {
    for (final dirPath in _candidateDirs) {
      final dir = Directory(dirPath);
      if (dir.existsSync()) {
        final files = dir.listSync();
        for (final f in files) {
          if (f is File && (f.path.endsWith('.bin') || f.path.endsWith('.gguf'))) {
            return f;
          }
        }
      }
    }
    return null;
  }

  static File? getScriptFile() {
    for (final dirPath in _candidateDirs) {
      final f = File('$dirPath\\transcribe.py');
      if (f.existsSync()) {
        return f;
      }
    }
    return null;
  }

  static bool isModelAvailable() {
    return getModelFile() != null;
  }

  static String? getModelName() {
    final file = getModelFile();
    if (file == null) return null;
    return file.path.split(Platform.pathSeparator).last;
  }

  static Future<String> transcribe(String wavAudioPath) async {
    final modelFile = getModelFile();
    if (modelFile == null) {
      throw Exception('Local STT model not found in models/stt/. Please place your model in models/stt/');
    }

    final scriptFile = getScriptFile();
    if (scriptFile == null) {
      throw Exception('Transcription script not found in models/stt/transcribe.py');
    }

    final result = await Process.run(
      'python',
      [
        scriptFile.absolute.path,
        modelFile.absolute.path,
        wavAudioPath,
      ],
      runInShell: true,
    );

    final stdoutStr = result.stdout.toString();
    final stderrStr = result.stderr.toString();

    // Look for __RESULT_JSON__
    const marker = '__RESULT_JSON__';
    final idx = stdoutStr.indexOf(marker);
    if (idx != -1) {
      final jsonStr = stdoutStr.substring(idx + marker.length).trim();
      try {
        final decoded = jsonDecode(jsonStr) as Map<String, dynamic>;
        if (decoded.containsKey('text')) {
          return decoded['text'] as String? ?? '';
        } else if (decoded.containsKey('error')) {
          throw Exception(decoded['error']);
        }
      } catch (e) {
        if (e is Exception) rethrow;
      }
    }

    if (result.exitCode != 0) {
      throw Exception(stderrStr.isNotEmpty ? stderrStr : 'Failed to transcribe audio.');
    }

    return '';
  }
}

