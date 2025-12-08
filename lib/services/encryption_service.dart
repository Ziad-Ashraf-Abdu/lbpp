import 'package:encrypt/encrypt.dart';
import 'dart:typed_data';

class EncryptionService {
  late Encrypter _encrypter;
  late IV _iv;

  // Initialize with the User's Activation Key and a zeroed IV
  void init(String activationKey) {
    // Ensure key is 128-bit (16 bytes)
    final keyString = activationKey.padRight(16, '0').substring(0, 16);
    final key = Key.fromUtf8(keyString);
    _encrypter = Encrypter(AES(key, mode: AESMode.ctr, padding: null));
    
    // Initialize IV with all zeros, same as the ESP32
    _iv = IV(Uint8List(16));
  }

  // Decrypts a packet using the internally managed, auto-incrementing IV
  String decrypt(Encrypted encryptedData) {
    try {
      // The decrypt function uses the current IV state
      final decrypted = _encrypter.decrypt(encryptedData, iv: _iv);
      
      // MANUALLY INCREMENT THE IV for the next packet to match the ESP32
      _incrementIV();
      
      return decrypted;
    } catch (e) {
      print("Decryption Error: $e. This may happen if packets are out of order.");
      // On error, we might be out of sync. Consider resetting the IV or connection.
      return ""; // Return empty string on error
    }
  }
  
  /// Increments the 128-bit IV counter for AES-CTR mode.
  /// This must match the encryption-side logic.
  void _incrementIV() {
    final bytes = _iv.bytes;
    for (int i = bytes.length - 1; i >= 0; i--) {
        // Increment the byte
        bytes[i]++;
        // If the byte has not overflowed (wrapped to 0), we are done.
        if (bytes[i] != 0) {
            break;
        }
    }
  }

  // Legacy function - kept for reference but should not be used for streaming
  List<int> decryptPacket(Uint8List encryptedData, Uint8List ivBytes) {
    try {
      final iv = IV(ivBytes);
      return _encrypter.decryptBytes(Encrypted(encryptedData), iv: iv);
    } catch (e) {
      print("Decryption Error: $e");
      return [];
    }
  }
}