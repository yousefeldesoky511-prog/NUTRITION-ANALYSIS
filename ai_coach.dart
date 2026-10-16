import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'db.dart';

class AiCoach {
  static String get key => (Store.settings['geminiApiKey'] ?? '').toString().trim();
  static Future<Map<String, dynamic>> _request(String prompt, {File? image}) async {
    if (key.isEmpty) throw Exception('Add a Gemini API key in Settings first.');
    final parts = <Map<String, dynamic>>[{'text': prompt}];
    if (image != null) parts.add({'inline_data': {'mime_type': image.path.toLowerCase().endsWith('.png') ? 'image/png' : 'image/jpeg', 'data': base64Encode(await image.readAsBytes())}});
    final uri = Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=${Uri.encodeQueryComponent(key)}');
    final response = await http.post(uri, headers: {'Content-Type': 'application/json'}, body: jsonEncode({'contents': [{'parts': parts}], 'generationConfig': {'temperature': .2, 'responseMimeType': 'application/json'}})).timeout(const Duration(seconds: 45));
    if (response.statusCode < 200 || response.statusCode >= 300) throw Exception('Gemini error ${response.statusCode}. Check key, internet, model access, and quota.');
    final root = jsonDecode(response.body) as Map<String, dynamic>; final candidates = root['candidates'] as List?;
    if (candidates == null || candidates.isEmpty) throw Exception('AI returned no result. Try again.');
    final partsOut = ((candidates.first as Map)['content'] as Map)['parts'] as List;
    return jsonDecode((partsOut.first as Map)['text'] as String) as Map<String, dynamic>;
  }
  static Future<Map<String, dynamic>> estimate(String description, {File? image}) => _request('Estimate the meal from text/photo. Return only JSON keys name (string), kcal, protein, fat, carbs (numbers; macros in grams), note (uncertainty note). Use reasonable serving assumptions and treat values as estimates. Description: $description', image: image);
  static Future<String> weeklyPlan() async {
    if (Store.profile['age'] == null) throw Exception('Save your adult profile in Settings first.');
    return const JsonEncoder.withIndent('  ').convert(await _request('Create an affordable Egyptian-food-based 7-day plan for this adult profile ${jsonEncode(Store.profile)} with targets ${jsonEncode(Store.plan())}. Return JSON: title, guidance, days array (each day has day and meals; each meal has type,name,portion,kcal,protein), shopping_list array. Three meals plus snack daily. No extreme dieting; keep concise.'));
  }
  static Future<String> chat(String question) async {
    final r = await _request('You are a supportive evidence-informed nutrition coach, not a doctor. Profile ${jsonEncode(Store.profile)}, targets ${jsonEncode(Store.plan())}. Answer in same language as question, concise and practical. Question: $question');
    return r['answer']?.toString() ?? const JsonEncoder.withIndent('  ').convert(r);
  }
}
