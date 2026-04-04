import 'dart:io';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// Service for extracting text from document images using Google ML Kit
class OCRService {
  final TextRecognizer _textRecognizer = TextRecognizer();

  /// Scans an image and extracts document ID numbers
  /// Returns the extracted text or null if no text is found
  Future<String?> extractDocumentId(File imageFile) async {
    try {
      final inputImage = InputImage.fromFile(imageFile);
      final RecognizedText recognizedText = await _textRecognizer.processImage(inputImage);

      if (recognizedText.text.isEmpty) {
        return null;
      }

      // Extract text from all blocks
      final StringBuffer extractedText = StringBuffer();

      for (TextBlock block in recognizedText.blocks) {
        for (TextLine line in block.lines) {
          // Clean the text: remove extra spaces and special characters
          String lineText = line.text.trim();
          if (lineText.isNotEmpty) {
            extractedText.write(lineText);
            extractedText.write(' ');
          }
        }
      }

      String result = extractedText.toString().trim();

      // Try to extract ID-like patterns (numbers, alphanumeric codes)
      // This helps prioritize likely ID numbers
      String? extractedId = _extractIdPattern(result);

      return extractedId ?? result;
    } catch (e) {
      print('Error extracting text: $e');
      return null;
    }
  }

  /// Extracts common ID patterns from text
  /// Looks for patterns like:
  /// - Pure numbers (10+ digits)
  /// - Alphanumeric codes (passport, license format)
  String? _extractIdPattern(String text) {
    // Remove all whitespace for pattern matching
    String cleanText = text.replaceAll(RegExp(r'\s+'), '');

    // Pattern 1: Long number sequences (10+ digits)
    RegExp longNumberPattern = RegExp(r'\d{10,}');
    Match? longNumberMatch = longNumberPattern.firstMatch(cleanText);
    if (longNumberMatch != null) {
      return longNumberMatch.group(0);
    }

    // Pattern 2: Alphanumeric codes (common in passports, licenses)
    // Example: AB1234567, L123456789, etc.
    RegExp alphanumericPattern = RegExp(r'[A-Z]{1,3}\d{6,}');
    Match? alphanumericMatch = alphanumericPattern.firstMatch(cleanText);
    if (alphanumericMatch != null) {
      return alphanumericMatch.group(0);
    }

    // Pattern 3: Number sequences with dashes or spaces
    // Example: 1234-5678-9012
    RegExp dashedPattern = RegExp(r'[\d\-\s]{10,}');
    Match? dashedMatch = dashedPattern.firstMatch(text);
    if (dashedMatch != null) {
      return dashedMatch.group(0)?.replaceAll(RegExp(r'[\s\-]'), '');
    }

    // Return cleaned full text if no specific pattern found
    return cleanText.isNotEmpty ? cleanText : null;
  }

  /// Dispose of the text recognizer
  void dispose() {
    _textRecognizer.close();
  }
}
