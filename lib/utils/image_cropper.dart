import 'dart:typed_data';
import 'package:image/image.dart' as img;
// 🌟 [중요] SplitMode가 정의된 home_screen.dart 파일의 경로를 올바르게 연결해 줍니다.
import '../screens/home_screen.dart';

class ImageCropper {
  static Future<List<Uint8List>> splitImage(
    Uint8List inputImageBytes, {
    required SplitMode mode, // mode 파라미터 required
    Function(int current, int total)? onProgress,
  }) async {
    // 1. 이미지 디코드
    img.Image? originalImage = img.decodeImage(inputImageBytes);
    if (originalImage == null) throw Exception("이미지를 읽을 수 없습니다.");

    img.Image workingImage = originalImage;

    // 2배수 resize
    // 들어온 원본 이미지가 현재 모드의 최종 목표 크기보다 크다면 목표 크기로 resize

    final int targetWidth = mode.pieceWidth * mode.cols;
    final int targetHeight = mode.pieceHeight * mode.rows;

    if (originalImage.width != targetWidth ||
        originalImage.height != targetHeight) {
      workingImage = img.copyResize(
        originalImage,
        width: targetWidth,
        height: targetHeight,
        interpolation: img.Interpolation.linear,
      );
    }

    // 현재 mode에 등록된 값으로 교체
    final int pieceWidth = mode.pieceWidth; // 180 또는 360
    final int pieceHeight = mode.pieceHeight; // 180 또는 360
    final int cols = mode.cols; // 7 또는 6
    final int rows = mode.rows; // 6 또는 6
    final int totalPieces = mode.totalPieces; // 42 또는 32 (360 모드는 32장만!)

    List<Uint8List> pieces = [];
    int currentPiece = 0;

    // crop 시작 (가로 x 세로 반복문)
    for (int y = 0; y < rows; y++) {
      for (int x = 0; x < cols; x++) {
        // 360모드일 때 32장을 다 잘랐다면 마지막 줄 4칸은 자르지 않고 break
        if (currentPiece >= totalPieces) {
          break;
        }

        int startX = x * pieceWidth;
        int startY = y * pieceHeight;

        // 한 조각 떼어내기
        img.Image croppedPiece = img.copyCrop(
          workingImage,
          x: startX,
          y: startY,
          width: pieceWidth,
          height: pieceHeight,
        );

        // PNG 바이트 데이터로 인코딩해서 리스트에 담기
        pieces.add(Uint8List.fromList(img.encodePng(croppedPiece)));

        currentPiece++;

        // 화면에 진행률(1/32, 2/32...) 알려주기
        if (onProgress != null) {
          onProgress(currentPiece, totalPieces);
        }

        // 브라우저 멈춤 방지를 위한 아주 짧은 휴식
        await Future.delayed(const Duration(milliseconds: 1));
      }
      // 바깥쪽 반복문도 안전하게 탈출
      if (currentPiece >= totalPieces) {
        break;
      }
    }

    return pieces;
  }
}
