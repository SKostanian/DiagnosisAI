import 'package:flutter_test/flutter_test.dart';

void main() {
  group("Session API logic", () {
    test("parse question response", () {
      final Map<String, dynamic> response = {
        "type": "question",
        "sessionId": "123",
        "question": {
          "id": "quality",
          "text": "What does it feel like?",
          "type": "single",
          "topic": "quality",
          "options": ["Burning", "Sharp"]
        }
      };

      final question = response["question"] as Map<String, dynamic>;
      final options = question["options"] as List;

      expect(response["type"], "question");
      expect(question["id"], "quality");
      expect(options.length, 2);
    });

    test("parse diagnosis response", () {
      final Map<String, dynamic> response = {
        "type": "diagnosis",
        "diagnosis": {
          "dx": [
            {"label": "Pneumonia", "prob": 0.7},
            {"label": "Bronchitis", "prob": 0.3}
          ],
          "confidence": 0.7
        }
      };

      final diagnosis = response["diagnosis"] as Map<String, dynamic>;
      final dx = diagnosis["dx"] as List;

      expect(response["type"], "diagnosis");
      expect(dx.length, 2);
      expect(diagnosis["confidence"], 0.7);
    });
  });
}