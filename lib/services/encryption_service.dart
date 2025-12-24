import 'package:encrypt/encrypt.dart' as enc;
import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/foundation.dart';

class EncryptionService {
  late enc.Encrypter _encrypter;
  late Uint8List _ivBytes;
  int _blockCounter = 0; // Track total blocks processed

  void init(String activationKey) {
    // Ensure key is exactly 16 bytes
    final keyString = activationKey.padRight(16, '0').substring(0, 16);
    final key = enc.Key.fromUtf8(keyString);

    _encrypter = enc.Encrypter(
        enc.AES(key, mode: enc.AESMode.ctr, padding: null)
    );

    // Initialize IV to all zeros (matches ESP32)
    _ivBytes = Uint8List(16);
    _blockCounter = 0;

    debugPrint("[Encryption] Initialized with key: $keyString");
    debugPrint("[Encryption] Initial IV: ${_ivBytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}");
  }

  /// Decrypt data from ESP32
  String decrypt(Uint8List encryptedPacket) {
    if (encryptedPacket.isEmpty) {
      return "";
    }

    try {
      debugPrint("[Encryption] Decrypting ${encryptedPacket.length} bytes");
      debugPrint("[Encryption] Current IV: ${_ivBytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}");

      // Create IV for this decryption
      final currentIv = enc.IV(_ivBytes);

      // Decrypt
      final decryptedBytes = _encrypter.decryptBytes(
          enc.Encrypted(encryptedPacket),
          iv: currentIv
      );

      // Advance IV by number of blocks used
      int numBlocks = (encryptedPacket.length + 15) ~/ 16;
      _advanceIV(numBlocks);

      // Decode to string, handling possible malformed UTF-8
      String decryptedText = utf8.decode(
          decryptedBytes,
          allowMalformed: true
      ).trim();

      // Remove null terminators and control characters
      decryptedText = decryptedText.replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '').trim();

      debugPrint("[Encryption] Decrypted: '$decryptedText'");

      return decryptedText;

    } catch (e, stackTrace) {
      debugPrint("[Encryption] DECRYPTION FAILED: $e");
      debugPrint("[Encryption] Stack trace: $stackTrace");

      // Still advance IV to try to resync
      int numBlocks = (encryptedPacket.length + 15) ~/ 16;
      _advanceIV(numBlocks);

      return "";
    }
  }

  /// Advance the IV counter (128-bit big-endian increment)
  void _advanceIV(int numBlocks) {
    if (numBlocks <= 0) return;

    debugPrint("[Encryption] Advancing IV by $numBlocks blocks");

    // Convert IV to BigInt (big-endian)
    var ivBigInt = BigInt.zero;
    for (int i = 0; i < 16; i++) {
      ivBigInt = (ivBigInt << 8) | BigInt.from(_ivBytes[i]);
    }

    // Add number of blocks
    ivBigInt += BigInt.from(numBlocks);
    _blockCounter += numBlocks;

    // Handle 128-bit wraparound
    final maxIv = BigInt.one << 128;
    ivBigInt = ivBigInt % maxIv;

    // Convert back to bytes (big-endian)
    for (int i = 15; i >= 0; i--) {
      _ivBytes[i] = (ivBigInt & BigInt.from(0xFF)).toInt();
      ivBigInt = ivBigInt >> 8;
    }

    debugPrint("[Encryption] New IV: ${_ivBytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}");
    debugPrint("[Encryption] Total blocks processed: $_blockCounter");
  }

  /// Reset encryption state (call when reconnecting)
  void reset() {
    _ivBytes = Uint8List(16);
    _blockCounter = 0;
    debugPrint("[Encryption] Reset to initial state");
  }

  /// Get current IV state (for debugging)
  String getIVState() {
    return _ivBytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ');
  }
}