import 'dart:typed_data';
import 'package:image/image.dart' as img;

class ImageCropper {
  /// 1260x1080 이미지를 받아서 180x180 42개로 나누는 함수
  static Future<List<Uint8List>> splitImage(
    Uint8List inputImageBytes, {
    Function(int current, int total)? onProgress,
  }) async {
    // 잘린 42개의 이미지 list
    List<Uint8List> pieces = [];

    // 1. 도마 위에 이미지 올리기
    // 사용자가 올린 파일을 픽셀 단위로 편집할 수 있게 변환합니다.
    img.Image? originalImage = img.decodeImage(inputImageBytes);

    // 만약 이미지가 깨졌거나 이상한 파일이면 에러
    if (originalImage == null) {
      throw Exception();
    }

    await Future.delayed(const Duration(milliseconds: 50));

    // 규격표 정의
    const int targetWidth = 1260;
    const int targetHeight = 1080;
    const int allowedWidth2 = 2520;
    const int allowedHeight2 = 2160;

    img.Image workingImage = originalImage;

    if (originalImage.width == targetWidth &&
        originalImage.height == targetHeight) {
      // 케이스 1: 1260 x 1080 (정상 규격) -> 통과! 아무것도 안 함.
    } else if (originalImage.width == allowedWidth2 &&
        originalImage.height == allowedHeight2) {
      // 케이스 2: 2520 x 2160 (2배 규격) -> 압축기 돌려서 1260x1080으로 만듦!
      workingImage = img.copyResize(
        originalImage,
        width: targetWidth,
        height: targetHeight,
      );
      await Future.delayed(const Duration(milliseconds: 50));
    } else {
      // 케이스 3: 그 외의 모든 이상한 사이즈 -> 작업 중단하고 에러 던지기!
      throw Exception();
    }

    // 자를 조각의 규격 설정
    const int pieceWidth = 180;
    const int pieceHeight = 180;

    int totalPieces = 42; // 총 조각 개수
    int currentPiece = 0; // 현재 자른 조각 개수

    // 2. crop range 설정 (세로 6줄, 가로 7칸 = 총 42번 반복)
    for (int y = 0; y < 6; y++) {
      for (int x = 0; x < 7; x++) {
        // 어디서부터 자를지 시작점 계산
        int startX = x * pieceWidth;
        int startY = y * pieceHeight;

        // 3. crop
        // copyCrop이라는 기본 제공 기능으로 원하는 위치와 크기만큼 잘라냅니다.
        img.Image croppedPiece = img.copyCrop(
          workingImage,
          x: startX,
          y: startY,
          width: pieceWidth,
          height: pieceHeight,
        );

        // 4. list에 넣기
        // 잘라낸 픽셀 데이터를 PNG 형태로 encoding
        pieces.add(img.encodePng(croppedPiece));

        currentPiece++;
        if (onProgress != null) {
          onProgress(currentPiece, totalPieces);
        }

        // 1개 이미지당 0.001초 대기
        await Future.delayed(const Duration(milliseconds: 1));
      }
    }

    // 5. 잘린 42개 이미지 return
    return pieces;
  }
}
