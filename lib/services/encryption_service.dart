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
      // The decrypt function in the library automatically uses and increments
      // the IV for CTR mode when the same IV instance is passed. 
      // This mimics the mbedtls_aes_crypt_ctr behavior.
      final decrypted = _encrypter.decrypt(encryptedData, iv: _iv);
      return decrypted;
    } catch (e) {
      print("Decryption Error: $e");
      return ""; // Return empty string on error
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