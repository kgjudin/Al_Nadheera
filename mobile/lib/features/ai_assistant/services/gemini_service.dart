import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import '../models/ai_message.dart';

class GeminiService {
  static final GeminiService instance = GeminiService._internal();
  GeminiService._internal();

  String get _apiKey {
    return dotenv.env['GEMINI_API_KEY'] ?? '';
  }

  static const List<String> _models = [
    'gemini-3.8-flash',
    'gemini-3.5-flash-lite',
    'gemini-flash-latest',
  ];

  static const String _systemInstruction = '''
You are the AL NADHEERA AI Assistant, a specialized construction, engineering, and project management AI for AL NADHEERA Construction & Trading.
Your goals:
1. Provide accurate, professional assistance on construction site operations, civil engineering, material estimations, safety protocols, budgeting, and project tracking.
2. Answer questions clearly, concisely, and with practical guidance.
3. Clean Mobile-Friendly Formatting:
   - Do NOT use markdown heading hashes (#, ##, ###). Use clear bold titles instead.
   - Do NOT use horizontal divider lines (--- or ***) or double dashes (--).
   - Do NOT overuse underscores (_) or asterisks (*). Keep formatting natural, clean, and readable.
   - Use simple clean bullet points (•) or numbered lists (1., 2., 3.) for steps and recommendations.
   - Keep paragraphs short and easy to read on mobile devices.
4. Maintain a polite, knowledgeable, and helpful tone at all times.
''';

  /// Sends the conversation history to Gemini and returns the assistant's reply.
  Future<String> sendMessage({
    required String prompt,
    required List<AiMessage> history,
  }) async {
    final key = _apiKey;
    if (key.isEmpty) {
      throw Exception('Gemini API key is missing. Please configure GEMINI_API_KEY.');
    }

    // Build contents for multi-turn chat
    final List<Map<String, dynamic>> contents = [];

    // Add recent history (up to last 10 messages)
    final recentHistory = history.length > 10 ? history.sublist(history.length - 10) : history;
    for (final msg in recentHistory) {
      if (msg.isLoading || msg.text.trim().isEmpty) continue;
      contents.add({
        'role': msg.isUser ? 'user' : 'model',
        'parts': [
          {'text': msg.text}
        ],
      });
    }

    // Add current user prompt
    contents.add({
      'role': 'user',
      'parts': [
        {'text': prompt}
      ],
    });

    final requestBody = jsonEncode({
      'systemInstruction': {
        'parts': [
          {'text': _systemInstruction}
        ]
      },
      'contents': contents,
      'generationConfig': {
        'temperature': 0.7,
        'maxOutputTokens': 2048,
      },
    });

    Exception? lastException;

    // Try models in order (primary -> fallbacks)
    for (final model in _models) {
      final url = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$key',
      );

      try {
        final response = await http
            .post(
              url,
              headers: {'Content-Type': 'application/json'},
              body: requestBody,
            )
            .timeout(const Duration(seconds: 30));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final candidates = data['candidates'] as List?;
          if (candidates != null && candidates.isNotEmpty) {
            final content = candidates[0]['content'];
            final parts = content?['parts'] as List?;
            if (parts != null && parts.isNotEmpty) {
              final text = parts[0]['text'] as String?;
              if (text != null && text.isNotEmpty) {
                return text.trim();
              }
            }
          }
          return 'I received your message, but no content was generated. Please try again.';
        } else {
          debugPrint('Gemini model $model returned ${response.statusCode}: ${response.body}');
          lastException = Exception('API Error (${response.statusCode}): ${response.reasonPhrase}');
        }
      } catch (e) {
        debugPrint('Gemini model $model request failed: $e');
        lastException = Exception(e.toString());
      }
    }

    throw lastException ?? Exception('Failed to connect to Gemini AI.');
  }
}
