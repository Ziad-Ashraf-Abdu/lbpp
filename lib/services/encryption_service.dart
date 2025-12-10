import 'package:encrypt/encrypt.dart' as enc;
import 'dart:typed_data';
import 'dart:convert'; // For utf8.decode
import 'package:flutter/foundation.dart'; // For debugPrint

class EncryptionService {
  late enc.Encrypter _encrypter;
  late Uint8List _ivBytes; // This will hold the mutable IV counter state

  void init(String activationKey) {
    final keyString = activationKey.padRight(16, '0').substring(0, 16);
    final key = enc.Key.fromUtf8(keyString);
    
    _encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.ctr, padding: null));
    
    _ivBytes = Uint8List(16); // All zeros
    debugPrint("[EncryptionService] Initialized. Key and IV are set.");
  }

  /// Decrypts an entire data packet received from the ESP32.
  /// This method mimics the mbedtls_aes_crypt_ctr behavior by advancing the
  /// IV based on the number of 16-byte blocks the packet occupies.
  String decrypt(Uint8List encryptedPacket) {
    if (encryptedPacket.isEmpty) {
      return "";
    }

    final currentIv = enc.IV(_ivBytes);
    String decryptedText = "";

    try {
      debugPrint("[EncryptionService] Decrypting packet (${encryptedPacket.length} bytes) with IV: $_ivBytes");

      // Decrypt the entire packet.
      final decryptedBytes = _encrypter.decryptBytes(enc.Encrypted(encryptedPacket), iv: currentIv);
      
      // The ESP32 sends a CSV string. It might not be null-terminated.
      // We decode it as UTF-8. Using allowMalformed helps prevent errors if a
      // multi-byte character is split across packets, though with CSV this is unlikely.
      decryptedText = utf8.decode(decryptedBytes, allowMalformed: true);
      
      debugPrint("[EncryptionService] Decryption successful. Plaintext: \"$decryptedText\"");

    } catch (e) {
      debugPrint("[EncryptionService] DECRYPTION FAILED: $e. The packet might be corrupted or the IV is out of sync.");
      // We still advance the IV to try and re-sync with the next packet.
      decryptedText = ""; 
    } finally {
      // CRITICAL: Advance the IV by the number of blocks used for this packet,
      // regardless of whether decryption succeeded. This is how we stay in sync.
      int numBlocks = (encryptedPacket.length + 15) ~/ 16;
      _advanceIV(numBlocks);
      debugPrint("[EncryptionService] Advanced IV by $numBlocks blocks. Next packet will use IV: $_ivBytes");
    }
    
    return decryptedText;
  }
  
  /// Advances the 128-bit IV counter by a given number of steps.
  void _advanceIV(int numBlocks) {
    if (numBlocks <= 0) return;

    // The IV is treated as a 128-bit big-endian integer for the addition.
    var ivBigInt = BigInt.from(0);
    for (int i = 0; i < 16; i++) {
      ivBigInt = (ivBigInt << 8) | BigInt.from(_ivBytes[i]);
    }

    // Add the number of blocks.
    ivBigInt += BigInt.from(numBlocks);

    // Convert back to a 16-byte array, handling wrap-around.
    final maxIv = BigInt.one << 128;
    ivBigInt = ivBigInt % maxIv;

    for (int i = 15; i >= 0; i--) {
      _ivBytes[i] = (ivBigInt & BigInt.from(0xFF)).toInt();
      ivBigInt = ivBigInt >> 8;
    }
  }
}
