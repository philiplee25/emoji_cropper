import 'package:web/web.dart' as web;
import 'dart:js_interop'; // 데이터를 최신 방식으로 변환해 주는 필수 도구
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../utils/image_cropper.dart';
import 'package:reorderable_grid_view/reorderable_grid_view.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // 잘린 42개의 이미지 조각(바이트 데이터)들을 담아둘 상태 변수입니다.
  List<Uint8List> _croppedPieces = [];
  // 이미지 조각들의 '순서 번호표'를 담을 리스트를 새로 추가합니다
  final List<int> _pieceOrder = [];
  bool _isLoading = false; // 로딩 상태 표시용

  // 이미지를 선택, 크롭
  Future<void> _pickAndProcessImage() async {
    final ImagePicker picker = ImagePicker();

    // 1. image file 열기
    final XFile? imageFile = await picker.pickImage(
      source: ImageSource.gallery,
    );

    // 사용자가 취소했다면 함수 종료
    if (imageFile == null) return;

    setState(() {
      _isLoading = true; // 로딩 시작!
      _croppedPieces = []; // 기존 조각들 초기화
    });

    try {
      // 2. 이미지 파일을 컴퓨터가 읽을 수 있는 바이트 데이터로 변환
      final Uint8List imageBytes = await imageFile.readAsBytes();

      // 3. ImageCropper에 데이터 넘기기
      final List<Uint8List> result = await ImageCropper.splitImage(imageBytes);

      // 4. crop 성공 후 setState
      setState(() {
        _croppedPieces = result;

        // setState 할 때마다 list clear
        _pieceOrder.clear();
        _pieceOrder.addAll(List.generate(result.length, (index) => index));
      });
    } catch (e) {
      // ImageCropper가 throw Exception으로 던진 에러 catch
      _showErrorDialog(e.toString().replaceAll("Exception: ", ""));
    } finally {
      setState(() {
        _isLoading = false; // 성공하든 실패하든 로딩 끝!
      });
    }
  }

  // WASM 호환 방식으로 웹 브라우저에서 이미지 다운로드
  void _downloadImage(Uint8List bytes, int index) {
    String fileNumber = (index + 1).toString().padLeft(2, '0');
    String fileName = '$fileNumber.png';

    // 1. 바이트 데이터를 최신 자바스크립트/WASM이 이해할 수 있는 형태로 변환합니다. (.toJS 사용)
    final blob = web.Blob([bytes.toJS].toJS);

    // 2. 가상의 다운로드 인터넷 주소(URL)를 만듭니다.
    final url = web.URL.createObjectURL(blob);

    // 3. 웹상에 보이지 않는 <a> 태그를 만들고, 거기에 주소를 걸어서 강제 클릭시킵니다!
    web.document.createElement('a') as web.HTMLAnchorElement
      ..href = url
      ..download = fileName
      ..click();

    // 4. 다운로드가 완료되면 임시 주소를 메모리에서 지워줍니다.
    web.URL.revokeObjectURL(url);
  }

  // 에러 발생 시 사용자에게 띄워줄 Alert 팝업창
  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text(
            '규격 확인 오류',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context), // 팝업 닫기
              child: const Text('확인'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('아아아아아아 너무 귀찮아아아아아'),
        backgroundColor: Colors.blueGrey,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 1. 이미지 업로드 버튼
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _pickAndProcessImage,
                icon: const Icon(Icons.upload_file),
                label: const Text('1260x1080 or 2520x2160 크기 아니면 후회할거임 ㅎㅎ'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                  textStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 30),

              // 2. 상태에 따른 화면 노출 (로딩 중 / 바둑판 / 대기 화면)
              if (_isLoading)
                const CircularProgressIndicator() // 로딩 뺑뺑이
              else if (_croppedPieces.isNotEmpty)
                // 이미지가 성공적으로 잘렸다면 7x6 GridView
                Expanded(
                  child: ReorderableGridView.builder(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 7,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                        ),
                    itemCount: _croppedPieces.length,
                    // 🌟 드래그 앤 드롭으로 위치가 바뀌었을 때 실행되는 함수입니다!
                    onReorder: (oldIndex, newIndex) {
                      setState(() {
                        // 번호표 리스트에서 원래 있던 번호를 빼서, 새로운 자리에 쏙 끼워 넣습니다.
                        final int item = _pieceOrder.removeAt(oldIndex);
                        _pieceOrder.insert(newIndex, item);
                      });
                    },
                    itemBuilder: (context, index) {
                      // 🌟 현재 자리에 와야 할 이미지의 진짜 번호표를 확인합니다.
                      int realPieceIndex = _pieceOrder[index];

                      return Container(
                        // ⚠️ [매우 중요] ReorderableGridView는 각 조각이 누군지 구분하기 위해 고유한 key가 꼭 필요합니다!
                        key: ValueKey(realPieceIndex),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              // 순서가 바뀐 번호표(realPieceIndex)에 맞는 이미지를 그려줍니다.
                              child: Image.memory(
                                _croppedPieces[realPieceIndex],
                                fit: BoxFit.cover,
                              ),
                            ),
                            Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () => _downloadImage(
                                  _croppedPieces[realPieceIndex],
                                  index,
                                ),
                                child: Container(
                                  alignment: Alignment.bottomRight,
                                  padding: const EdgeInsets.all(4),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(
                                        alpha: 0.6,
                                      ),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Padding(
                                      padding: EdgeInsets.all(6.0),
                                      child: Icon(
                                        Icons.download,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                )
              else
                // 이미지를 아직 올리지 않았을 때 보여주는 문구
                const Text(
                  '이미지를 업로드하면 42개의 조각으로 정밀하게 분할됩니다.',
                  style: TextStyle(color: Colors.grey, fontSize: 14),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
