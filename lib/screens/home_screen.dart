import 'dart:html' as html; // 웹 브라우저 다운로드 기능
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../utils/image_cutter.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // 잘린 42개의 이미지 조각(바이트 데이터)들을 담아둘 상태 변수입니다.
  List<Uint8List> _croppedPieces = [];
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

      // 3. ImageCutter에 데이터 넘기기
      final List<Uint8List> result = await ImageCutter.splitImage(imageBytes);

      // 4. crop 성공 후 setState
      setState(() {
        _croppedPieces = result;
      });
    } catch (e) {
      // ImageCutter가 throw Exception으로 던진 에러 catch
      _showErrorDialog(e.toString().replaceAll("Exception: ", ""));
    } finally {
      setState(() {
        _isLoading = false; // 성공하든 실패하든 로딩 끝!
      });
    }
  }

  // 💾 웹 브라우저에서 이미지를 다운로드하는 함수
  void _downloadImage(Uint8List bytes, int index) {
    // 1. 파일 이름 규칙 적용: 1번부터 42번까지 '01', '02' 형태로 번호를 매깁니다.
    // index는 0부터 시작하므로 1을 더해주고 padLeft를 써서 무조건 2자리로 만듭니다.
    String fileNumber = (index + 1).toString().padLeft(2, '0');
    String fileName = 'image_piece_$fileNumber.png';

    // 2. 바이트 데이터를 웹 브라우저가 인식할 수 있는 파일 형태(Blob)로 포장
    final blob = html.Blob([bytes]);

    // 3. 포장된 파일의 임시 URL 생성
    final url = html.Url.createObjectUrlFromBlob(blob);

    // 4. 가상의 다운로드 링크를 만들어서 강제 클릭
    html.AnchorElement(href: url)
      ..setAttribute("download", fileName)
      ..click(); // 사용자 대신 클릭!

    // 5. 다운로드가 끝났으면 임시 주소를 청소해 줍니다. (메모리 절약)
    html.Url.revokeObjectUrl(url);
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
                  child: GridView.builder(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 7, // 가로 7칸 정렬!
                          crossAxisSpacing: 8, // 조각 사이 가로 여백
                          mainAxisSpacing: 8, // 조각 사이 세로 여백
                        ),
                    itemCount: _croppedPieces.length, // 총 42개
                    itemBuilder: (context, index) {
                      return Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        // 🌟 Stack을 사용하면 이미지 위에 버튼을 겹쳐서 올릴 수 있습니다!
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            // 1. 바닥에 깔리는 잘린 이미지
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: Image.memory(
                                _croppedPieces[index],
                                fit: BoxFit.cover,
                              ),
                            ),
                            // 2. 이미지 위에 올라가는 반투명 다운로드 버튼
                            Material(
                              color: Colors.transparent, // 배경은 투명하게
                              child: InkWell(
                                onTap: () => _downloadImage(
                                  _croppedPieces[index],
                                  index,
                                ),
                                child: Container(
                                  alignment: Alignment.bottomRight,
                                  padding: const EdgeInsets.all(4),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(
                                        alpha: 0.6,
                                      ), // 반투명 검은색 배경
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
