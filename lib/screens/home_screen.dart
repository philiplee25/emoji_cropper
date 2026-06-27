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

  bool _isBonobonoMode = true;

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
      // ImageCropper가 throw Exception으로 던진 에러 catch
      _showErrorDialogs();
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

  Future<void> _showErrorDialogs() async {
    // 1. 23개의 각기 다른 멘트를 리스트로 준비합니다.
    final List<String> messages = [
      "30) 엇?",
      "29) ㅎㅎㅎㅎㅎㅎㅎㅎㅎㅎㅎ",
      "28) 규격에 맞지 않는 사진을 올리셨네요?ㅎㅎ",
      "27) 이러시면 제가 아주 곤란합니다",
      "26) 1260x1080 아니면 2520x2160 만 올리라 했는데 말이야",
      "25) 나는 분명 경고를 했었어 ㅎㅎ",
      "24) 왜 말을 안들으셨어요",
      "23) 안되겠다",
      "22) 너는 혼 좀 나야겠다",
      "21) 몇대 맞을래",
      "20) 한대? 한대로 되겠어?",
      "19) 짝!",
      "18) 다음부터는 안틀려야겠지?",
      "17) 괜히 잘못 올렸다 싶죠?",
      "16) 아차싶죠?",
      "15) 잘못 걸렸다 싶죠?",
      "14) 화나시나요 ㅎㅎㅎㅎㅎㅎㅎㅎㅎㅎㅎㅎ",
      "13) 그치만 센세가 뭘 할 수 있죠?",
      "12) 깔깔깔깔깔깔깔깔깔깔깔깔깔깔깔깔깔깔깔깔깔깔깔깔깔깔깔깔깔깔깔깔깔깔깔깔깔깔깔깔깔깔깔깔깔깔깔깔깔깔깔깔깔깔깔깔깔깔깔깔깔깔깔깔깔깔깔깔깔깔깔깔깔깔깔깔깔깔깔",
      "11) 꼬우면 개발자 하던가~",
      "10) 개빡쳐도 해야지 어쩌겠어요 ㅎㅎ 화이팅~",
      "9) 영!",
      "8) 차!",
      "7) 영!",
      "6) 차!",
      "5) 이제 진짜 다왔다.",
      "4)끝이 보이네ㅠ",
      "3)너무 아쉽고",
      "2) 두개만 더!",
      "1) 마지막 한개!",
      "1) 회원님 한개만 더!",
      "1) 회원님 진짜 마지막 한개만 더!",
      "1) 회원님 진짜 진짜 마지막으로 한개만 더!",
      "1) 진짜 마지막! 할 수 있따!",
      "다음부턴 틀리지 말고 잘 확인한 후 올리세요^^",
    ];

    // 2. 리스트의 길이(23번)만큼 반복문을 돌립니다.
    for (int i = 0; i < messages.length; i++) {
      // 🌟 await가 핵심! 사용자가 창을 닫을 때까지 여기서 코드가 멈춰서 기다립니다.
      await showDialog(
        context: context,
        barrierDismissible: false, // 😈 악마의 옵션: 창 바깥의 까만 배경을 눌러도 안 닫히게 막아버립니다!
        builder: (context) {
          return AlertDialog(
            title: Text(
              '저런ㅋ', // 타이틀에 현재 몇 번째 창인지 보여줍니다.
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            content: Text(messages[i]),
            actions: [
              TextButton(
                onPressed: () =>
                    Navigator.pop(context), // 팝업 닫기 (이걸 눌러야 다음 반복문으로 넘어감)
                child: const Text('확인ㅋ'),
              ),
            ],
          );
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,

      appBar: AppBar(
        title: GestureDetector(
          onTap: () {
            setState(() {
              _isBonobonoMode = !_isBonobonoMode;
            });
          },
          child: const Text('아아아아아아 너무 귀찮아아아아아'),
        ),
        backgroundColor: _isBonobonoMode ? Colors.transparent : Colors.blueGrey,
        elevation: _isBonobonoMode ? 0 : 4,
        foregroundColor: Colors.white,
      ),
      body: Container(
        decoration: BoxDecoration(
          color: _isBonobonoMode ? Colors.transparent : Colors.white,
          image: _isBonobonoMode
              ? DecorationImage(
                  image: AssetImage('assets/images/22.jpg'),
                  fit: BoxFit.cover,
                )
              : null,
        ),

        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // 🌟 [추가 3] 세그먼트 버튼 UI
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

                    // 🌟 enum에 등록된 모드들을 기반으로 버튼들을 생성합니다.
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

                    // 디자인 커스텀 (보노보노 테마에도 잘 어울리게 반투명 화이트/블루그레이 톤으로)
                    style: SegmentedButton.styleFrom(
                      selectedBackgroundColor: Colors.blueGrey,
                      selectedForegroundColor: Colors.white,
                      backgroundColor: Colors.white.withValues(alpha: 0.8),
                    ),
                  ),

                  const SizedBox(height: 30), // 버튼과 이미지 불러오기 사이 간격
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
                    )
                  else
                    // 이미지를 아직 올리지 않았을 때 보여주는 문구
                    const Text(
                      '1260x1080 or 2520x2160 크기 아니면 후회할거임 ㅎㅎㅎㅎ',
                      style: TextStyle(color: Colors.black, fontSize: 14),
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

//       body: Center(
//         child: Padding(
//           padding: const EdgeInsets.all(20.0),
//           child: Column(
//             mainAxisAlignment: MainAxisAlignment.center,
//             children: [
//               // 1. 이미지 업로드 버튼
//               ElevatedButton.icon(
//                 onPressed: _isLoading ? null : _pickAndProcessImage,
//                 icon: const Icon(Icons.upload_file),
//                 label: const Text('이미지 가져오기'),
//                 style: ElevatedButton.styleFrom(
//                   padding: const EdgeInsets.symmetric(
//                     horizontal: 24,
//                     vertical: 16,
//                   ),
//                   textStyle: const TextStyle(
//                     fontSize: 16,
//                     fontWeight: FontWeight.bold,
//                   ),
//                 ),
//               ),
//               const SizedBox(height: 30),

//               if (_croppedPieces.isNotEmpty && !_isLoading) ...[
//                 ElevatedButton.icon(
//                   onPressed: () {
//                     // 텍스트 필드가 사라졌으니, 조각과 순서표만 깔끔하게 넘깁니다!
//                     AllDownload.downloadZip(_croppedPieces, _pieceOrder);
//                   },
//                   icon: const Icon(Icons.folder_zip),
//                   label: const Text('모든 조각 한번에 다운로드 (ZIP)'),
//                   style: ElevatedButton.styleFrom(
//                     backgroundColor: Colors.teal,
//                     foregroundColor: Colors.white,
//                     padding: const EdgeInsets.symmetric(
//                       horizontal: 32,
//                       vertical: 18,
//                     ),
//                     textStyle: const TextStyle(
//                       fontSize: 15,
//                       fontWeight: FontWeight.bold,
//                     ),
//                     shape: RoundedRectangleBorder(
//                       borderRadius: BorderRadius.circular(8),
//                     ),
//                   ),
//                 ),
//                 const SizedBox(height: 30),
//               ],

//               // 2. 상태에 따른 화면 노출 (로딩 중 / 바둑판 / 대기 화면)
//               if (_isLoading)
//                 Column(
//                   mainAxisAlignment: MainAxisAlignment.center,
//                   children: [
//                     Text(
//                       _currentProgress == 0
//                           ? '이미지 분석 및 리사이즈 중...' // 0일 때
//                           : '$_currentProgress / 42 분할 중...', // 1부터
//                       style: const TextStyle(
//                         fontSize: 16,
//                         fontWeight: FontWeight.bold,
//                         color: Colors.teal,
//                       ),
//                     ),
//                   ],
//                 )
//               else if (_croppedPieces.isNotEmpty)
//                 // 이미지가 성공적으로 잘렸다면 7x6 GridView
//                 Expanded(
//                   child: ReorderableGridView.builder(
//                     // drag&drop 인식시간 0.3초
//                     dragStartDelay: const Duration(milliseconds: 300),

//                     gridDelegate:
//                         const SliverGridDelegateWithFixedCrossAxisCount(
//                           crossAxisCount: 7,
//                           crossAxisSpacing: 8,
//                           mainAxisSpacing: 8,
//                         ),
//                     itemCount: _croppedPieces.length,
//                     // 🌟 드래그 앤 드롭으로 위치가 바뀌었을 때 실행되는 함수입니다!
//                     onReorder: (oldIndex, newIndex) {
//                       setState(() {
//                         // 번호표 리스트에서 원래 있던 번호를 빼서, 새로운 자리에 쏙 끼워 넣습니다.
//                         final int item = _pieceOrder.removeAt(oldIndex);
//                         _pieceOrder.insert(newIndex, item);
//                       });
//                     },
//                     itemBuilder: (context, index) {
//                       // 현재 자리에 와야 할 이미지의 진짜 번호
//                       int realPieceIndex = _pieceOrder[index];

//                       return Container(
//                         // ReorderableGridView는 각 조각이 누군지 구분하기 위해 고유한 key가 반드시 필요!!!!!
//                         key: ValueKey(realPieceIndex),
//                         decoration: BoxDecoration(
//                           border: Border.all(color: Colors.grey.shade300),
//                           borderRadius: BorderRadius.circular(4),
//                         ),
//                         child: Stack(
//                           fit: StackFit.expand,
//                           children: [
//                             ClipRRect(
//                               borderRadius: BorderRadius.circular(4),
//                               // 순서가 바뀐 번호표(realPieceIndex)에 맞는 이미지를 그려줍니다.
//                               child: Image.memory(
//                                 _croppedPieces[realPieceIndex],
//                                 fit: BoxFit.cover,
//                               ),
//                             ),
//                             Material(
//                               color: Colors.transparent,
//                               child: InkWell(
//                                 onTap: () => _downloadImage(
//                                   _croppedPieces[realPieceIndex],
//                                   index,
//                                 ),
//                                 child: Container(
//                                   alignment: Alignment.bottomRight,
//                                   padding: const EdgeInsets.all(4),
//                                   child: Container(
//                                     decoration: BoxDecoration(
//                                       color: Colors.black.withValues(
//                                         alpha: 0.6,
//                                       ),
//                                       shape: BoxShape.circle,
//                                     ),
//                                     child: const Padding(
//                                       padding: EdgeInsets.all(6.0),
//                                       child: Icon(
//                                         Icons.download,
//                                         color: Colors.white,
//                                         size: 20,
//                                       ),
//                                     ),
//                                   ),
//                                 ),
//                               ),
//                             ),
//                           ],
//                         ),
//                       );
//                     },
//                   ),
//                 )
//               else
//                 // 이미지를 아직 올리지 않았을 때 보여주는 문구
//                 const Text(
//                   '1260x1080 or 2520x2160 크기 아니면 후회할거임 ㅎㅎㅎㅎ',
//                   style: TextStyle(color: Colors.black, fontSize: 14),
//                 ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }

//   //  보노보노 배경
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       // body를 appbar 뒤쪽 꼭대기까지 확장
//       extendBodyBehindAppBar: true,

//       appBar: AppBar(
//         title: const Text(
//           '아아아아아아 너무 귀찮아아아아아',
//           style: TextStyle(color: Colors.black),
//         ),
//         // appbar 배경 투명화, 그림자 제거
//         backgroundColor: Colors.transparent,
//         elevation: 0,
//         foregroundColor: Colors.white,
//       ),
