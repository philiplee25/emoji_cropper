import 'package:emoji_cropper/utils/all_download.dart';
import 'package:web/web.dart' as web;
import 'dart:js_interop'; // 데이터를 최신 방식으로 변환해 주는 필수 도구
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../utils/image_cropper.dart';
import 'package:reorderable_grid_view/reorderable_grid_view.dart';
import 'package:flutter/material.dart';

enum SplitMode {
  // 180 모드는 1260x1080 원본과 2520x2160(2배수) 모두 허용
  size180_42('180x180 분할', 180, 180, 7, 6, 42, [
    [1260, 1080],
    [2520, 2160],
  ]),

  // 360 모드는 2160x2160만 허용
  size360_32('360x360 이모티콘', 360, 360, 6, 6, 32, [
    [2160, 2160],
  ]);

  final String label;
  final int pieceWidth;
  final int pieceHeight;
  final int cols;
  final int rows;
  final int totalPieces;
  final List<List<int>> allowedDimensions; // 허용되는 해상도 리스트

  const SplitMode(
    this.label,
    this.pieceWidth,
    this.pieceHeight,
    this.cols,
    this.rows,
    this.totalPieces,
    this.allowedDimensions,
  );

  // 들어온 이미지가 허용 리스트에 있는지 검사
  bool isValidSize(int width, int height) {
    return allowedDimensions.any((dim) => dim[0] == width && dim[1] == height);
  }

  // 허용된 사이즈 리스트를 읽어서 안내 문구를 자동으로 만들어주는 기능
  String get guideText {
    // [[1260, 1080], [2520, 2160]] -> "1260x1080 또는 2520x2160" 형태로 자동 변환!
    final dimensionsText = allowedDimensions
        .map((dim) => '${dim[0]}x${dim[1]}')
        .join(' 또는 ');

    return '$dimensionsText 로만 올려야함';
  }
}

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

  int _currentProgress = 0;

  SplitMode _currentMode = SplitMode.size180_42;

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
      _currentProgress = 0; // 진행률 초기화
    });

    await Future.delayed(const Duration(milliseconds: 300));

    try {
      // 2. 이미지 파일을 컴퓨터가 읽을 수 있는 바이트 데이터로 변환
      final Uint8List imageBytes = await imageFile.readAsBytes();

      // 무거운 가위질 도구를 꺼내기 전에, 플러터 기본 엔진으로 껍데기(사이즈)만 먼저 스캔합니다!
      final imageInfo = await decodeImageFromList(imageBytes);
      final int w = imageInfo.width;
      final int h = imageInfo.height;

      // 🌟 [수정 1] 규격 검사 자동화!
      // 현재 세그먼트 버튼으로 선택된 모드(_currentMode)의 허용 리스트에 없으면 바로 에러를 냅니다.
      if (!_currentMode.isValidSize(w, h)) {
        throw Exception();
      }

      // 3. ImageCropper에 데이터 넘기기
      final List<Uint8List> result = await ImageCropper.splitImage(
        imageBytes,
        mode: _currentMode, // 🌟 [수정 2] 뒤에서 칼질할 요리사에게 현재 선택된 모드 명세서를 던져줍니다!
        onProgress: (current, total) {
          setState(() {
            _currentProgress = current; // 요리사가 부른 숫자를 화면 변수에 넣고 새로고침!
          });
        },
      );

      // 4. crop 성공 후 setState
      setState(() {
        _croppedPieces = result;

        // setState 할 때마다 list clear
        _pieceOrder.clear();
        _pieceOrder.addAll(List.generate(result.length, (index) => index));
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${_currentMode.label} 제대로 올리라고'),
            backgroundColor: Colors.redAccent,
            duration: const Duration(seconds: 3), // 3초 뒤에 자동으로 사라짐
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false; // 성공하든 실패하든 로딩 끝
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,

      appBar: AppBar(
        title: const Text('이모티콘 분할기'),

        // background, elevation을 블루그레이로 고정
        backgroundColor: Colors.blueGrey,
        elevation: 4,
        foregroundColor: Colors.white,
      ),
      body: Container(
        decoration: const BoxDecoration(color: Colors.white),

        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SegmentedButton<SplitMode>(
                    // 현재 선택된 모드 (Set 형태로 넣어줘야 합니다)
                    selected: <SplitMode>{_currentMode},

                    // 모드가 변경되었을 때 상태 변경
                    onSelectionChanged: (Set<SplitMode> newSelection) {
                      setState(() {
                        // 선택된 세트에서 첫 번째 요소를 가져옵니다.
                        _currentMode = newSelection.first;
                      });
                    },

                    // enum에 등록된 모드들을 기반으로 버튼 생성
                    segments: SplitMode.values.map<ButtonSegment<SplitMode>>((
                      SplitMode mode,
                    ) {
                      return ButtonSegment<SplitMode>(
                        value: mode,
                        label: Text(
                          // '180x180 분할' 처럼 글자만 깔끔하게 요약해서 노출
                          mode.label.split(' ').first,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      );
                    }).toList(),

                    style: SegmentedButton.styleFrom(
                      selectedBackgroundColor: Colors.blueGrey,
                      selectedForegroundColor: Colors.white,
                      backgroundColor: Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
                  const SizedBox(height: 16), // 버튼과 텍스트 사이 간격 살짝 좁힘
                  // 🌟 [추가] 모드가 바뀔 때마다 스르륵 바뀌는 마법의 안내 텍스트!
                  Text(
                    _currentMode.guideText,
                    style: const TextStyle(
                      color: Colors.blueGrey,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),

                  const SizedBox(height: 16), // 텍스트와 이미지 불러오기 버튼 사이 간격
                  // 1. 이미지 업로드 버튼
                  ElevatedButton.icon(
                    onPressed: _isLoading ? null : _pickAndProcessImage,
                    icon: const Icon(Icons.upload_file),
                    label: const Text('이미지 가져오기'),
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

                  if (_croppedPieces.isNotEmpty && !_isLoading) ...[
                    ElevatedButton.icon(
                      onPressed: () {
                        // 텍스트 필드가 사라졌으니, 조각과 순서표만 깔끔하게 넘깁니다!
                        AllDownload.downloadZip(_croppedPieces, _pieceOrder);
                      },
                      icon: const Icon(Icons.folder_zip),
                      label: const Text('모든 조각 한번에 다운로드 (ZIP)'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 18,
                        ),
                        textStyle: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),
                  ],

                  // 2. 상태에 따른 화면 노출 (로딩 중 / 바둑판 / 대기 화면)
                  if (_isLoading)
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _currentProgress == 0
                              ? '이미지 분석 및 리사이즈 중...' // 0일 때
                              : '$_currentProgress / 42 분할 중...', // 1부터
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.teal,
                          ),
                        ),
                      ],
                    )
                  else if (_croppedPieces.isNotEmpty)
                    // 이미지가 성공적으로 잘렸다면 7x6 GridView
                    Expanded(
                      child: ReorderableGridView.builder(
                        // drag&drop 인식시간 0.3초
                        dragStartDelay: const Duration(milliseconds: 300),

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
                          // 현재 자리에 와야 할 이미지의 진짜 번호
                          int realPieceIndex = _pieceOrder[index];

                          return Container(
                            // ReorderableGridView는 각 조각이 누군지 구분하기 위해 고유한 key가 반드시 필요!!!!!
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
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
