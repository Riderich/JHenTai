import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';

import '../setting/translation_setting.dart';

class AndroidImageTranslationService {
  static const MethodChannel _channel = MethodChannel(
    'top.jtmonster.jhentai.image_translation',
  );

  Future<Uint8List> translate(Uint8List imageBytes) async {
    final List<Map<String, dynamic>> regions = await _recognize(imageBytes);
    if (regions.isEmpty) {
      throw StateError('No Japanese text was detected on this page');
    }

    final List<String> sourceTexts = regions
        .map((region) => (region['text'] as String? ?? '').trim())
        .where((text) => text.isNotEmpty)
        .toList(growable: false);
    final List<String> translatedTexts = await _translateTexts(sourceTexts);
    if (translatedTexts.length != regions.length) {
      throw StateError('The translation result does not match OCR regions');
    }

    final Uint8List? rendered = await _channel.invokeMethod<Uint8List>(
      'renderTranslations',
      {
        'image': imageBytes,
        'regions': [
          for (int i = 0; i < regions.length; i++)
            {...regions[i], 'translation': translatedTexts[i]},
        ],
      },
    );
    if (rendered == null || rendered.isEmpty) {
      throw StateError('Android renderer returned an empty image');
    }
    return rendered;
  }

  Future<bool> testConnection() async {
    final List<String> result = await _translateTexts(const ['接続テスト']);
    return result.length == 1 && result.first.trim().isNotEmpty;
  }

  Future<List<Map<String, dynamic>>> _recognize(Uint8List imageBytes) async {
    final List<dynamic>? raw = await _channel.invokeMethod<List<dynamic>>(
      'recognizeJapanese',
      {'image': imageBytes},
    );
    return (raw ?? const [])
        .map((item) => Map<String, dynamic>.from(item as Map))
        .where((item) => (item['text'] as String? ?? '').trim().isNotEmpty)
        .toList(growable: false);
  }

  Future<List<String>> _translateTexts(List<String> texts) async {
    if (texts.isEmpty) {
      return const [];
    }
    final String base = translationSetting.apiBaseUrl.value;
    final Dio client = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 15),
        sendTimeout: Duration(
          seconds: translationSetting.requestTimeoutSeconds.value,
        ),
        receiveTimeout: Duration(
          seconds: translationSetting.requestTimeoutSeconds.value,
        ),
        headers: {
          'Content-Type': 'application/json',
          if (translationSetting.apiKey.value.isNotEmpty)
            'Authorization': 'Bearer ${translationSetting.apiKey.value}',
        },
      ),
    );
    final Response<dynamic> response = await client.post<dynamic>(
      '$base/chat/completions',
      data: {
        'model': translationSetting.apiModel.value,
        'temperature': 0.1,
        'stream': false,
        if (translationSetting.disableThinking.value)
          'thinking': {'type': 'disabled'},
        'messages': [
          {
            'role': 'system',
            'content': 'You translate Japanese manga dialogue into natural Simplified Chinese. '
                'Preserve tone and sound effects. Return only a JSON array of strings '
                'in exactly the same order and length as the input. Do not use Markdown.',
          },
          {
            'role': 'user',
            'content': jsonEncode(texts),
          },
        ],
      },
    );
    final dynamic data = response.data;
    String content = '';
    if (data is Map && data['choices'] is List) {
      final List<dynamic> choices = data['choices'] as List<dynamic>;
      if (choices.isNotEmpty && choices.first is Map) {
        final dynamic message = (choices.first as Map)['message'];
        if (message is Map) {
          content = message['content']?.toString() ?? '';
        }
      }
    }
    final int start = content.indexOf('[');
    final int end = content.lastIndexOf(']');
    if (start < 0 || end <= start) {
      throw const FormatException('API did not return a JSON array');
    }
    final dynamic decoded = jsonDecode(content.substring(start, end + 1));
    if (decoded is! List || decoded.length != texts.length) {
      throw const FormatException(
          'API returned an unexpected translation count');
    }
    return decoded
        .map((item) => item.toString().trim())
        .toList(growable: false);
  }
}
