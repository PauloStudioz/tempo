import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:tempo/features/copilot/services/local_stt_service.dart';
import 'package:tempo/features/copilot/services/gemini_service.dart';
import 'package:tempo/features/copilot/views/copilot_view.dart';

void main() {
  group('Local STT and Copilot Service Tests', () {
    test('Local STT discovers ggml whisper model in models/stt', () {
      final isAvailable = LocalSttService.isModelAvailable();
      expect(isAvailable, isTrue);

      final modelName = LocalSttService.getModelName();
      expect(modelName, isNotNull);
      expect(modelName, contains('ggml'));
    });

    test('GeminiService includes gemini-3.5-flash-lite as primary model with fallbacks', () {
      expect(GeminiService.textModelCode, equals('gemini-3.5-flash-lite'));
      expect(GeminiService.candidateModels.first, equals('gemini-3.5-flash-lite'));
      expect(GeminiService.candidateModels.contains('gemini-2.5-flash'), isTrue);
    });

    test('ChatMessage serializes and deserializes image attachments correctly', () {
      final testBytes = Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10]); // PNG header
      final msg = ChatMessage(
        id: 'msg_img_test',
        isUser: true,
        text: 'Analyze this schedule',
        imageBytes: testBytes,
        imageName: 'schedule.png',
      );

      final json = msg.toJson();
      expect(json['imageName'], equals('schedule.png'));
      expect(json['imageBase64'], isNotNull);

      final reconstructed = ChatMessage.fromJson(json);
      expect(reconstructed.id, equals('msg_img_test'));
      expect(reconstructed.imageName, equals('schedule.png'));
      expect(reconstructed.imageBytes, isNotNull);
      expect(reconstructed.imageBytes, equals(testBytes));
    });
  });
}

