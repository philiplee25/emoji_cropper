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
                        // 메모리에 있는 바이트 데이터를 화면에 그리는 코드
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: Image.memory(
                            _croppedPieces[index],
                            fit: BoxFit.cover,
                          ),
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
