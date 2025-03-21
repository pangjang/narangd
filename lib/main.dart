import 'package:flame/game.dart';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/collisions.dart';
import 'package:flame/particles.dart';
import 'package:flame/parallax.dart';
import 'package:flame/text.dart';
import 'package:flutter/material.dart';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(
    const GameWidget<DodgeGame>.controlled(
      gameFactory: DodgeGame.new,
      overlayBuilderMap: {
        'mainMenu': MainMenuOverlay.builder,
        'gameOver': GameOverOverlay.builder,
        'hud': GameHUD.builder,
      },
    ),
  );
}

class DodgeGame extends FlameGame with HasCollisionDetection, DragCallbacks {
  static const double playerSize = 50.0;
  static const int scorePerLevel = 10;
  static const double baseSpeed = 280.0;
  static const double speedIncrement = 45.0;
  static const double minSpawnInterval = 0.55;
  static const double spawnIntervalDecrement = 0.045;

  late Player player;
  late List<Cloud> clouds;
  final ValueNotifier<int> score = ValueNotifier<int>(0);
  final ValueNotifier<int> level = ValueNotifier<int>(1);
  final ValueNotifier<int> highScore = ValueNotifier<int>(0);
  bool isPlaying = false;
  double spawnTimer = 0;
  double cloudSpawnTimer = 0;
  final Random random = Random();

  @override
  Future<void> onLoad() async {
    // 최고 점수 불러오기
    try {
      final prefs = await SharedPreferences.getInstance();
      highScore.value = prefs.getInt('highScore') ?? 0;
    } catch (e) {
      print('최고 점수 불러오기 실패: $e');
    }

    // 하늘과 논밭 그라데이션 배경
    final backgroundGradient = RectangleComponent(
      size: size,
      paint: Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF87CEEB), // 하늘색
            const Color(0xFFE0F7FA), // 연한 하늘색
            const Color(0xFF90A955), // 연한 초록색 (논)
            const Color(0xFF557153), // 진한 초록색 (논밭)
          ],
          stops: const [0.0, 0.3, 0.6, 1.0],
        ).createShader(Rect.fromLTWH(0, 0, size.x, size.y)),
    );
    add(backgroundGradient);

    // 논밭 패턴 추가
    final fieldPattern = RiceFieldPattern();
    add(fieldPattern);

    clouds = [];

    // 초기 구름 생성
    for (int i = 0; i < 3; i++) {
      final cloud = Cloud();
      add(cloud);
      clouds.add(cloud);
    }

    add(player = Player());
    overlays.add('mainMenu');
  }

  void startGame() {
    score.value = 0;
    level.value = 1;
    isPlaying = true;
    player.reset();
    removeWhere(
        (component) => component is Obstacle || component is LevelUpEffect);
    overlays.remove('mainMenu');
    overlays.remove('gameOver');
    overlays.add('hud');
  }

  void gameOver() {
    isPlaying = false;
    // 최고 점수 업데이트
    if (score.value > highScore.value) {
      highScore.value = score.value;
      _saveHighScore();
    }
    overlays.add('gameOver');
    overlays.remove('hud');
  }

  Future<void> _saveHighScore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('highScore', highScore.value);
    } catch (e) {
      print('최고 점수 저장 실패: $e');
    }
  }

  void increaseScore() {
    if (!isPlaying) return;
    score.value++;
    if (score.value > 0 && score.value % scorePerLevel == 0) {
      final newLevel = (score.value ~/ scorePerLevel) + 1;
      if (newLevel != level.value) {
        level.value = newLevel;
        showLevelUpEffect();
      }
    }
  }

  void showLevelUpEffect() {
    add(LevelUpEffect());
  }

  double get currentSpeed => baseSpeed + (speedIncrement * (level.value - 1));

  double get spawnInterval => max(
        minSpawnInterval,
        1.0 - (level.value - 1) * spawnIntervalDecrement,
      );

  @override
  void update(double dt) {
    super.update(dt);

    if (!isPlaying) return;

    // 장애물(참새) 생성
    spawnTimer += dt;
    if (spawnTimer >= spawnInterval) {
      spawnTimer = 0;
      add(Obstacle(speed: currentSpeed));
    }

    // 구름 생성
    cloudSpawnTimer += dt;
    if (cloudSpawnTimer >= 3.0) {
      cloudSpawnTimer = 0;
      if (clouds.length < 5) {
        final cloud = Cloud();
        add(cloud);
        clouds.add(cloud);
      }
    }

    // 화면 밖으로 나간 구름 제거
    clouds.removeWhere((cloud) {
      if (cloud.position.x > size.x + cloud.size.x) {
        cloud.removeFromParent();
        return true;
      }
      return false;
    });
  }
}

class Player extends PositionComponent
    with CollisionCallbacks, DragCallbacks, HasGameRef<DodgeGame> {
  Player() : super(size: Vector2.all(DodgeGame.playerSize)) {
    add(RectangleHitbox());
  }

  void reset() {
    position = Vector2(
      game.size.x / 2 - size.x / 2,
      game.size.y - size.y - 50,
    );
  }

  @override
  void onLoad() {
    reset();
  }

  @override
  void render(Canvas canvas) {
    final center = Offset(size.x / 2, size.y / 2);
    final farmerSize = size.x * 0.9;

    // 밀짚모자
    final strawHatPath = Path()
      ..moveTo(center.dx - farmerSize / 1.8, center.dy - farmerSize / 4)
      ..lineTo(center.dx + farmerSize / 1.8, center.dy - farmerSize / 4)
      ..lineTo(center.dx + farmerSize / 2.2, center.dy - farmerSize / 2.2)
      ..quadraticBezierTo(
        center.dx,
        center.dy - farmerSize / 1.5,
        center.dx - farmerSize / 2.2,
        center.dy - farmerSize / 2.2,
      )
      ..close();
    canvas.drawPath(strawHatPath, Paint()..color = const Color(0xFFDEB887));

    // 모자 장식 끈
    final hatBandPath = Path()
      ..moveTo(center.dx - farmerSize / 2, center.dy - farmerSize / 3)
      ..lineTo(center.dx + farmerSize / 2, center.dy - farmerSize / 3);
    canvas.drawPath(
      hatBandPath,
      Paint()
        ..color = const Color(0xFF8B4513)
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke,
    );

    // 얼굴
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(center.dx, center.dy + farmerSize / 8),
        width: farmerSize / 1.8,
        height: farmerSize / 1.4,
      ),
      Paint()..color = const Color(0xFFF4C19E),
    );

    // 눈썹
    final leftEyebrowPath = Path()
      ..moveTo(center.dx - farmerSize / 5, center.dy - farmerSize / 12)
      ..quadraticBezierTo(
        center.dx - farmerSize / 7,
        center.dy - farmerSize / 8,
        center.dx - farmerSize / 10,
        center.dy - farmerSize / 12,
      );
    canvas.drawPath(
      leftEyebrowPath,
      Paint()
        ..color = Colors.brown
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke,
    );

    final rightEyebrowPath = Path()
      ..moveTo(center.dx + farmerSize / 5, center.dy - farmerSize / 12)
      ..quadraticBezierTo(
        center.dx + farmerSize / 7,
        center.dy - farmerSize / 8,
        center.dx + farmerSize / 10,
        center.dy - farmerSize / 12,
      );
    canvas.drawPath(
      rightEyebrowPath,
      Paint()
        ..color = Colors.brown
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke,
    );

    // 눈
    canvas.drawCircle(
      Offset(center.dx - farmerSize / 6, center.dy),
      farmerSize / 16,
      Paint()..color = Colors.black,
    );
    canvas.drawCircle(
      Offset(center.dx + farmerSize / 6, center.dy),
      farmerSize / 16,
      Paint()..color = Colors.black,
    );

    // 코
    final nosePath = Path()
      ..moveTo(center.dx, center.dy + farmerSize / 8)
      ..quadraticBezierTo(
        center.dx + farmerSize / 12,
        center.dy + farmerSize / 5,
        center.dx,
        center.dy + farmerSize / 4,
      );
    canvas.drawPath(
      nosePath,
      Paint()
        ..color = Colors.brown[700]!
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke,
    );

    // 입 (미소)
    final mouthPath = Path()
      ..moveTo(center.dx - farmerSize / 5, center.dy + farmerSize / 3)
      ..quadraticBezierTo(
        center.dx,
        center.dy + farmerSize / 2,
        center.dx + farmerSize / 5,
        center.dy + farmerSize / 3,
      );
    canvas.drawPath(
      mouthPath,
      Paint()
        ..color = Colors.brown[700]!
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke,
    );

    // 수염
    canvas.drawLine(
      Offset(center.dx - farmerSize / 8, center.dy + farmerSize / 3),
      Offset(center.dx - farmerSize / 4, center.dy + farmerSize / 2.8),
      Paint()
        ..color = Colors.brown[400]!
        ..strokeWidth = 1,
    );
    canvas.drawLine(
      Offset(center.dx + farmerSize / 8, center.dy + farmerSize / 3),
      Offset(center.dx + farmerSize / 4, center.dy + farmerSize / 2.8),
      Paint()
        ..color = Colors.brown[400]!
        ..strokeWidth = 1,
    );

    // 옷 (작업복)
    final overallPath = Path()
      ..moveTo(center.dx - farmerSize / 2.2, center.dy + farmerSize / 2)
      ..lineTo(center.dx - farmerSize / 2, center.dy + farmerSize)
      ..lineTo(center.dx + farmerSize / 2, center.dy + farmerSize)
      ..lineTo(center.dx + farmerSize / 2.2, center.dy + farmerSize / 2)
      ..quadraticBezierTo(
        center.dx,
        center.dy + farmerSize / 1.8,
        center.dx - farmerSize / 2.2,
        center.dy + farmerSize / 2,
      );
    canvas.drawPath(overallPath, Paint()..color = const Color(0xFF1E88E5));

    // 작업복 끈
    canvas.drawLine(
      Offset(center.dx - farmerSize / 4, center.dy + farmerSize / 2),
      Offset(center.dx - farmerSize / 4, center.dy + farmerSize / 1.2),
      Paint()
        ..color = const Color(0xFF1565C0)
        ..strokeWidth = 3,
    );
    canvas.drawLine(
      Offset(center.dx + farmerSize / 4, center.dy + farmerSize / 2),
      Offset(center.dx + farmerSize / 4, center.dy + farmerSize / 1.2),
      Paint()
        ..color = const Color(0xFF1565C0)
        ..strokeWidth = 3,
    );

    // 주머니
    final pocketPath = Path()
      ..addRRect(RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(center.dx, center.dy + farmerSize / 1.3),
          width: farmerSize / 2,
          height: farmerSize / 4,
        ),
        const Radius.circular(5),
      ));
    canvas.drawPath(pocketPath, Paint()..color = const Color(0xFF1565C0));
  }

  @override
  void onDragUpdate(DragUpdateEvent event) {
    position.x += event.delta.x;
    position.x = position.x.clamp(
      0,
      game.size.x - size.x,
    );
  }
}

class Obstacle extends PositionComponent
    with CollisionCallbacks, HasGameRef<DodgeGame> {
  final double speed;
  bool hasPassedPlayer = false;
  double wingAngle = 0;
  final Random random = Random();

  Obstacle({required this.speed})
      : super(size: Vector2.all(DodgeGame.playerSize)) {
    add(RectangleHitbox());
  }

  @override
  void onLoad() {
    position = Vector2(
      Random().nextDouble() * (game.size.x - size.x),
      -size.y,
    );
  }

  @override
  void render(Canvas canvas) {
    final center = Offset(size.x / 2, size.y / 2);
    final birdSize = size.x * 0.8;

    // 몸통
    final bodyPath = Path()
      ..moveTo(center.dx - birdSize / 2, center.dy)
      ..quadraticBezierTo(
        center.dx,
        center.dy + birdSize / 4,
        center.dx + birdSize / 2,
        center.dy,
      )
      ..quadraticBezierTo(
        center.dx,
        center.dy - birdSize / 4,
        center.dx - birdSize / 2,
        center.dy,
      );
    canvas.drawPath(bodyPath, Paint()..color = const Color(0xFF8B4513));

    // 머리
    final headPath = Path()
      ..addOval(Rect.fromCenter(
        center: Offset(center.dx + birdSize / 3, center.dy - birdSize / 4),
        width: birdSize / 2,
        height: birdSize / 2.2,
      ));
    canvas.drawPath(headPath, Paint()..color = const Color(0xFF8B4513));

    // 눈
    canvas.drawCircle(
      Offset(center.dx + birdSize / 2.3, center.dy - birdSize / 3.5),
      birdSize / 12,
      Paint()..color = Colors.black,
    );

    // 부리
    final beakPath = Path()
      ..moveTo(center.dx + birdSize / 1.8, center.dy - birdSize / 4)
      ..lineTo(center.dx + birdSize / 1.2, center.dy - birdSize / 4.5)
      ..lineTo(center.dx + birdSize / 1.8, center.dy - birdSize / 5.5)
      ..close();
    canvas.drawPath(beakPath, Paint()..color = const Color(0xFFFF8C00));

    // 날개 (움직이는 효과)
    wingAngle = (wingAngle + 0.1) % (pi / 2);
    final wingPath = Path()
      ..moveTo(center.dx - birdSize / 4, center.dy)
      ..quadraticBezierTo(
        center.dx - birdSize / 8,
        center.dy - birdSize / 2 - sin(wingAngle) * birdSize / 4,
        center.dx + birdSize / 4,
        center.dy - birdSize / 8,
      );
    canvas.drawPath(
      wingPath,
      Paint()
        ..color = const Color(0xFF8B4513)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );

    // 꼬리
    final tailPath = Path()
      ..moveTo(center.dx - birdSize / 2, center.dy)
      ..lineTo(center.dx - birdSize / 1.5, center.dy - birdSize / 4)
      ..lineTo(center.dx - birdSize / 1.8, center.dy + birdSize / 8)
      ..close();
    canvas.drawPath(tailPath, Paint()..color = const Color(0xFF8B4513));
  }

  @override
  void update(double dt) {
    super.update(dt);
    position.y += speed * dt;

    if (!hasPassedPlayer && position.y > game.size.y - 50) {
      hasPassedPlayer = true;
      game.increaseScore();
    }

    if (position.y > game.size.y + size.y) {
      removeFromParent();
    }
  }

  @override
  void onCollisionStart(
    Set<Vector2> intersectionPoints,
    PositionComponent other,
  ) {
    super.onCollisionStart(intersectionPoints, other);
    if (other is Player) {
      game.gameOver();
    }
  }
}

class MainMenuOverlay extends StatelessWidget {
  static Widget builder(BuildContext context, DodgeGame game) {
    return MainMenuOverlay(game: game);
  }

  final DodgeGame game;
  const MainMenuOverlay({super.key, required this.game});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.blue, Colors.purple],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              '떨어지는 물체 피하기',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: game.startGame,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 40,
                  vertical: 15,
                ),
                backgroundColor: Colors.white,
              ),
              child: const Text(
                '게임 시작',
                style: TextStyle(fontSize: 24, color: Colors.blue),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class GameOverOverlay extends StatelessWidget {
  static Widget builder(BuildContext context, DodgeGame game) {
    return GameOverOverlay(game: game);
  }

  final DodgeGame game;
  const GameOverOverlay({super.key, required this.game});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black54,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              '게임 오버!',
              style: TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 30),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Column(
                children: [
                  ValueListenableBuilder<int>(
                    valueListenable: game.score,
                    builder: (context, score, _) {
                      return Text(
                        '총 ${score}톨이 수집되었습니다!',
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 15),
                  ValueListenableBuilder<int>(
                    valueListenable: game.level,
                    builder: (context, level, _) {
                      return Text(
                        '달성 단계: $level',
                        style: const TextStyle(
                          fontSize: 24,
                          color: Colors.white70,
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 15),
                  ValueListenableBuilder<int>(
                    valueListenable: game.highScore,
                    builder: (context, highScore, _) {
                      return Text(
                        '최고 기록: $highScore톨',
                        style: const TextStyle(
                          fontSize: 24,
                          color: Colors.yellow,
                          fontWeight: FontWeight.bold,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: game.startGame,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                padding: const EdgeInsets.symmetric(
                  horizontal: 40,
                  vertical: 15,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              child: const Text(
                '재도전',
                style: TextStyle(
                  fontSize: 24,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class GameHUD extends StatefulWidget {
  static Widget builder(BuildContext context, DodgeGame game) {
    return GameHUD(game: game);
  }

  final DodgeGame game;
  const GameHUD({super.key, required this.game});

  @override
  State<GameHUD> createState() => _GameHUDState();
}

class _GameHUDState extends State<GameHUD> with SingleTickerProviderStateMixin {
  late AnimationController _levelAnimController;
  late Animation<double> _scaleAnimation;
  late Animation<Color?> _colorAnimation;
  int _lastLevel = 1;

  @override
  void initState() {
    super.initState();
    _levelAnimController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.5),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.5, end: 1.0),
        weight: 50,
      ),
    ]).animate(CurvedAnimation(
      parent: _levelAnimController,
      curve: Curves.easeInOut,
    ));

    _colorAnimation = ColorTween(
      begin: Colors.blue,
      end: Colors.red,
    ).animate(CurvedAnimation(
      parent: _levelAnimController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _levelAnimController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          ValueListenableBuilder<int>(
            valueListenable: widget.game.level,
            builder: (context, level, _) {
              if (level != _lastLevel) {
                _lastLevel = level;
                _levelAnimController.forward(from: 0);
              }

              return AnimatedBuilder(
                animation: _levelAnimController,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _scaleAnimation.value,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 15,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: _colorAnimation.value?.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(
                          color: _colorAnimation.value ?? Colors.blue,
                          width: 2,
                        ),
                      ),
                      child: Text(
                        '$level 단계',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: _colorAnimation.value,
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
          ValueListenableBuilder<int>(
            valueListenable: widget.game.score,
            builder: (context, score, _) {
              return Text(
                '점수: $score',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// 구름 컴포넌트
class Cloud extends PositionComponent with HasGameRef<DodgeGame> {
  static const double baseSpeed = 30.0;
  final Random random = Random();
  late double speed;

  Cloud() : super(size: Vector2(80, 40)) {
    speed = baseSpeed + random.nextDouble() * 20;
  }

  @override
  void onLoad() {
    position = Vector2(
      -size.x,
      random.nextDouble() * (game.size.y * 0.3), // 화면 상단 30% 영역에만 구름 생성
    );
  }

  @override
  void render(Canvas canvas) {
    final cloudPaint = Paint()..color = Colors.white.withOpacity(0.8);

    // 구름 그리기
    for (int i = 0; i < 3; i++) {
      canvas.drawCircle(
        Offset(size.x * (0.3 + i * 0.2), size.y * 0.5),
        size.x * 0.2,
        cloudPaint,
      );
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    position.x += speed * dt;
  }
}

// 논밭 패턴 컴포넌트 추가
class RiceFieldPattern extends PositionComponent with HasGameRef<DodgeGame> {
  late List<Vector2> plantPositions;

  @override
  Future<void> onLoad() async {
    size = Vector2(game.size.x, game.size.y * 0.7);
    position = Vector2(0, game.size.y * 0.3);

    // 벼 위치 생성 - 완전 랜덤 배치
    plantPositions = [];
    final random = Random();
    final numberOfPlants = 200; // 벼의 개수 조절

    for (int i = 0; i < numberOfPlants; i++) {
      plantPositions.add(Vector2(
        random.nextDouble() * size.x,
        random.nextDouble() * size.y,
      ));
    }
  }

  @override
  void render(Canvas canvas) {
    // 논바닥 그리기
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.x, size.y),
      Paint()..color = const Color(0xFF90A955).withOpacity(0.1),
    );

    final stemPaint = Paint()
      ..color = const Color(0xFFDAA520) // 황금색 줄기
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    final grainPaint = Paint()
      ..color = const Color(0xFFFAD02C) // 밝은 노란색 이삭
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    for (final pos in plantPositions) {
      // 벼 그리기 - 고정된 크기로
      const stemHeight = 15.0;

      // 줄기
      final stemPath = Path()
        ..moveTo(pos.x, pos.y)
        ..lineTo(pos.x, pos.y - stemHeight);
      canvas.drawPath(stemPath, stemPaint);

      // 이삭
      final grainPath = Path()
        ..moveTo(pos.x, pos.y - stemHeight)
        ..lineTo(pos.x + 4, pos.y - stemHeight - 3)
        ..moveTo(pos.x, pos.y - stemHeight)
        ..lineTo(pos.x - 4, pos.y - stemHeight - 3)
        ..moveTo(pos.x, pos.y - stemHeight + 2)
        ..lineTo(pos.x + 3, pos.y - stemHeight - 1)
        ..moveTo(pos.x, pos.y - stemHeight + 2)
        ..lineTo(pos.x - 3, pos.y - stemHeight - 1);
      canvas.drawPath(grainPath, grainPaint);

      // 이삭 채우기
      final grainFillPaint = Paint()
        ..color = const Color(0xFFFAD02C).withOpacity(0.3)
        ..style = PaintingStyle.fill;

      final grainFillPath = Path()
        ..moveTo(pos.x, pos.y - stemHeight)
        ..lineTo(pos.x + 4, pos.y - stemHeight - 3)
        ..lineTo(pos.x - 4, pos.y - stemHeight - 3)
        ..close();
      canvas.drawPath(grainFillPath, grainFillPaint);
    }
  }
}

// 레벨업 효과 컴포넌트 추가
class LevelUpEffect extends PositionComponent with HasGameRef<DodgeGame> {
  late Timer fadeOutTimer;
  late double opacity;
  late TextComponent levelUpText;
  static const duration = 2.0;

  LevelUpEffect() : super(priority: 100);

  @override
  Future<void> onLoad() async {
    opacity = 1.0;
    position = Vector2(game.size.x / 2, game.size.y / 2);

    levelUpText = TextComponent(
      text: 'LEVEL UP!',
      textRenderer: TextPaint(
        style: const TextStyle(
          fontSize: 48,
          fontWeight: FontWeight.bold,
          color: Colors.yellow,
        ),
      ),
      anchor: Anchor.center,
    );
    add(levelUpText);

    fadeOutTimer = Timer(
      duration,
      onTick: () => removeFromParent(),
      repeat: false,
    );
  }

  @override
  void update(double dt) {
    super.update(dt);
    fadeOutTimer.update(dt);
    opacity = (1 - fadeOutTimer.progress).clamp(0, 1);
    levelUpText.textRenderer = TextPaint(
      style: TextStyle(
        fontSize: 48,
        fontWeight: FontWeight.bold,
        color: Colors.yellow.withOpacity(opacity),
      ),
    );
    scale = Vector2.all(1 + opacity * 0.3);
  }
}

