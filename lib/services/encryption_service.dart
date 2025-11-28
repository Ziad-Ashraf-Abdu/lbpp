import 'package:encrypt/encrypt.dart';
import 'dart:typed_data';

class EncryptionService {
  late Encrypter _encrypter;

  // Initialize with the User's Activation Key (padded to 16 bytes)
  void init(String activationKey) {
    // Ensure key is 128-bit (16 bytes) [cite: 163]
    final keyString = activationKey.padRight(16, '0').substring(0, 16);
    final key = Key.fromUtf8(keyString);
    // AES Mode CTR [cite: 196]
    _encrypter = Encrypter(AES(key, mode: AESMode.ctr, padding: null));
  }

  // Decrypts data using a counter/IV (assumed to be part of the packet or synced)
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