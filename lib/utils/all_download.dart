import 'dart:typed_data';
import 'package:web/web.dart' as web;
import 'dart:js_interop';
import 'package:archive/archive.dart';

class AllDownload {
  // 각각의 이름 고정
  static void downloadImage(Uint8List bytes, int index) {
    String fileNumber = (index + 1).toString().padLeft(2, '0');
    String fileName = 'piece_$fileNumber.png'; // 이름 고정!

    final blob = web.Blob([bytes.toJS].toJS);
    final url = web.URL.createObjectURL(blob);

    web.document.createElement('a') as web.HTMLAnchorElement
      ..href = url
      ..download = fileName
      ..click();

    web.URL.revokeObjectURL(url);
  }

  // zip 안에 파일 이름 고정
  static void downloadZip(List<Uint8List> pieces, List<int> order) {
    final archive = Archive();
    final encoder = ZipEncoder();

    for (int i = 0; i < order.length; i++) {
      int realIndex = order[i];
      String fileNumber = (i + 1).toString().padLeft(2, '0');
      String fileName = 'piece_$fileNumber.png'; // 이름 고정

      final archiveFile = ArchiveFile(
        fileName,
        pieces[realIndex].length,
        pieces[realIndex],
      );
      archive.addFile(archiveFile);
    }

    final List<int> zipBytes = encoder.encode(archive);

    final Uint8List zipUint8List = Uint8List.fromList(zipBytes);
    final blob = web.Blob([zipUint8List.toJS].toJS);
    final url = web.URL.createObjectURL(blob);

    web.document.createElement('a') as web.HTMLAnchorElement
      ..href = url
      ..download =
          '카카오 이모티콘.zip' // 압축파일 이름도 고정
      ..click();

    web.URL.revokeObjectURL(url);
  }
}
