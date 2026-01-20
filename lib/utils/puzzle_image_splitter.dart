import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;

/// Splits an image into a grid of puzzle pieces.
/// Returns a list of image bytes for each piece in row-major order.
class PuzzleImageSplitter {
  /// Split image into grid pieces.
  /// [imagePath] can be a local file path or network URL.
  /// [gridSize] is the number of pieces per side (e.g., 4 for 4x4 = 16 pieces).
  static Future<List<Uint8List>> splitImage(
    String imagePath,
    int gridSize,
  ) async {
    Uint8List imageBytes;

    // Load image bytes
    if (imagePath.toLowerCase().startsWith('http://') ||
        imagePath.toLowerCase().startsWith('https://')) {
      // Network image
      final response = await http.get(Uri.parse(imagePath));
      if (response.statusCode != 200) {
        throw Exception('Failed to load image from URL: ${response.statusCode}');
      }
      imageBytes = response.bodyBytes;
    } else {
      // Local file
      final file = File(imagePath);
      if (!await file.exists()) {
        throw Exception('Image file does not exist: $imagePath');
      }
      imageBytes = await file.readAsBytes();
    }

    // Decode image
    final image = img.decodeImage(imageBytes);
    if (image == null) {
      throw Exception('Failed to decode image');
    }

    // Calculate piece dimensions
    final pieceWidth = image.width ~/ gridSize;
    final pieceHeight = image.height ~/ gridSize;

    // Split into pieces
    final pieces = <Uint8List>[];
    for (int row = 0; row < gridSize; row++) {
      for (int col = 0; col < gridSize; col++) {
        final x = col * pieceWidth;
        final y = row * pieceHeight;
        final width = (col == gridSize - 1) ? image.width - x : pieceWidth;
        final height = (row == gridSize - 1) ? image.height - y : pieceHeight;

        // Crop piece
        final piece = img.copyCrop(
          image,
          x: x,
          y: y,
          width: width,
          height: height,
        );

        // Encode piece
        final pieceBytes = Uint8List.fromList(img.encodePng(piece));
        pieces.add(pieceBytes);
      }
    }

    return pieces;
  }

  /// Shuffle the order of puzzle pieces.
  /// Returns a list of indices representing the shuffled order.
  static List<int> shufflePieces(int totalPieces) {
    final indices = List.generate(totalPieces, (i) => i);
    indices.shuffle();
    return indices;
  }
}
