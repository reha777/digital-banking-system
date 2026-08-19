import 'dart:typed_data';

import 'package:image/image.dart' as image;
import 'package:zxing2/qrcode.dart';

class ReceiveQrImageDecoder {
  const ReceiveQrImageDecoder();

  String? decode(Uint8List bytes) {
    final decoded = image.decodeImage(bytes);
    if (decoded == null) return null;

    final pixels = decoded
        .convert(numChannels: 4)
        .getBytes(order: image.ChannelOrder.abgr)
        .buffer
        .asInt32List();
    final source = RGBLuminanceSource(decoded.width, decoded.height, pixels);
    final reader = QRCodeReader();

    try {
      return reader.decode(BinaryBitmap(HybridBinarizer(source))).text;
    } on ReaderException {
      try {
        return reader
            .decode(BinaryBitmap(GlobalHistogramBinarizer(source)))
            .text;
      } on ReaderException {
        return null;
      }
    }
  }
}
