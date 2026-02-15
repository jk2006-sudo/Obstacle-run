import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';

void main() {
  runApp(const TempleRunApp());
}

class TempleRunApp extends StatelessWidget {
  const TempleRunApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Temple Run Clone',
      theme: ThemeData.dark(),
      home: const GameScreen(),
    );
  }
}

enum Lane { left, center, right }

class Obstacle {
  Lane lane;
  double yPos;
  Color color;
  
  Obstacle({required this.lane, this.yPos = 0.0, this.color = Colors.red});
}

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with SingleTickerProviderStateMixin {
  Lane _playerLane = Lane.center;
  List<Obstacle> _obstacles = [];
  bool _isPlaying = false;
  bool _isJumping = false;
  int _score = 0;
  double _speed = 0.005;
  late Timer _gameLoop;

  final double _horizonY = 0.3;
  
  @override
  void dispose() {
    _gameLoop.cancel();
    super.dispose();
  }

  void _startGame() {
    setState(() {
      _isPlaying = true;
      _score = 0;
      _speed = 0.005;
      _obstacles.clear();
      _playerLane = Lane.center;
      _isJumping = false;
    });

    _gameLoop = Timer.periodic(const Duration(milliseconds: 16), (timer) {
      _updateGame();
    });
  }

  void _stopGame() {
    _gameLoop.cancel();
    setState(() {
      _isPlaying = false;
    });
    _showGameOverDialog();
  }

  void _updateGame() {
    setState(() {
      _score++;
      
      if (_score % 500 == 0) _speed += 0.0005;

      // Spawn Obstacles
      if (Random().nextInt(100) < 2 + (_score / 1000)) {
        _obstacles.add(Obstacle(
          lane: Lane.values[Random().nextInt(3)],
          color: Colors.redAccent.shade700
        ));
      }

      // Move Obstacles
      for (var obstacle in _obstacles) {
        double perspectiveFactor = (obstacle.yPos + 0.1); 
        obstacle.yPos += _speed * perspectiveFactor * 4;
      }

      _obstacles.removeWhere((o) => o.yPos > 1.2);

      _checkCollisions();
    });
  }

  void _checkCollisions() {
    const double playerHitboxTop = 0.80;
    const double playerHitboxBottom = 0.95;

    for (var obstacle in _obstacles) {
      if (obstacle.lane == _playerLane) {
        // If the obstacle is passing through the player
        if (obstacle.yPos > playerHitboxTop && obstacle.yPos < playerHitboxBottom) {
          // Only die if NOT jumping
          if (!_isJumping) {
            _stopGame();
          }
        }
      }
    }
  }

  // --- MOVEMENT LOGIC ---

  void _moveLeft() {
    if (!_isPlaying) return;
    setState(() {
      if (_playerLane == Lane.right) {
        _playerLane = Lane.center;
      } else if (_playerLane == Lane.center) {
        _playerLane = Lane.left;
      }
    });
  }

  void _moveRight() {
    if (!_isPlaying) return;
    setState(() {
      if (_playerLane == Lane.left) {
        _playerLane = Lane.center;
      } else if (_playerLane == Lane.center) {
        _playerLane = Lane.right;
      }
    });
  }

  void _jump() {
    if (!_isPlaying || _isJumping) return;
    
    setState(() {
      _isJumping = true;
    });

    Timer(const Duration(milliseconds: 800), () {
      if (mounted) {
        setState(() {
          _isJumping = false;
        });
      }
    });
  }

  // --- SWIPE HANDLERS ---

  void _handleHorizontalSwipe(DragEndDetails details) {
    if (details.primaryVelocity! > 0) {
      _moveRight();
    } else if (details.primaryVelocity! < 0) {
      _moveLeft();
    }
  }

  void _handleVerticalSwipe(DragEndDetails details) {
    if (details.primaryVelocity! < 0) {
      _jump();
    }
  }

  double _getLaneX(Lane lane) {
    switch (lane) {
      case Lane.left: return -0.7;
      case Lane.center: return 0.0;
      case Lane.right: return 0.7;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.lightBlue.shade200,
      body: GestureDetector(
        onHorizontalDragEnd: _handleHorizontalSwipe,
        onVerticalDragEnd: _handleVerticalSwipe,
        child: Stack(
          children: [
            // 1. Background
            Positioned(
              top: MediaQuery.of(context).size.height * _horizonY,
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.green.shade900, Colors.green.shade400],
                  ),
                ),
              ),
            ),
            
            // 2. Road Lines
            _buildPerspectiveLine(-0.35),
            _buildPerspectiveLine(0.35),

            // 3. Obstacles
            ..._obstacles.map((obstacle) {
              return _buildObject(
                lane: obstacle.lane, 
                yPos: obstacle.yPos, 
                color: obstacle.color,
                isPlayer: false
              );
            }),

            // 4. Player
            _buildObject(
              lane: _playerLane, 
              yPos: 0.85,
              color: Colors.amber, 
              isPlayer: true
            ),

            // 5. Score HUD
            SafeArea(
              child: Align(
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: const EdgeInsets.only(top: 20.0),
                  child: Column(
                    children: [
                      Text(
                        "Score: $_score",
                        style: const TextStyle(
                          fontSize: 32, 
                          fontWeight: FontWeight.bold, 
                          color: Colors.white,
                          shadows: [Shadow(blurRadius: 10, color: Colors.black)]
                        ),
                      ),
                      if (_isJumping) 
                        const Text(
                          "JUMPING!",
                          style: TextStyle(color: Colors.yellow, fontWeight: FontWeight.bold),
                        )
                    ],
                  ),
                ),
              ),
            ),

            // 6. Manual Controls (Buttons)
            if (_isPlaying)
              Positioned(
                bottom: 40,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildControlButton(Icons.arrow_back, _moveLeft),
                    _buildControlButton(Icons.arrow_upward, _jump),
                    _buildControlButton(Icons.arrow_forward, _moveRight),
                  ],
                ),
              ),

            // 7. Start Menu
            if (!_isPlaying)
              Center(
                child: ElevatedButton(
                  onPressed: _startGame,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                    backgroundColor: Colors.amber,
                  ),
                  child: const Text(
                    "RUN!", 
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.black)
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlButton(IconData icon, VoidCallback onPressed) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black45,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white30)
      ),
      child: IconButton(
        iconSize: 40,
        icon: Icon(icon, color: Colors.white),
        onPressed: onPressed,
      ),
    );
  }

  Widget _buildPerspectiveLine(double xAlignment) {
    return Positioned(
      top: MediaQuery.of(context).size.height * _horizonY,
      bottom: 0,
      left: 0,
      right: 0,
      child: CustomPaint(
        painter: RoadLinePainter(xAlignment: xAlignment),
      ),
    );
  }

  Widget _buildObject({required Lane lane, required double yPos, required Color color, required bool isPlayer}) {
    double scale = 0.2 + (yPos * 1.5); 
    
    double horizonPixels = MediaQuery.of(context).size.height * _horizonY;
    double remainingHeight = MediaQuery.of(context).size.height - horizonPixels;
    double topPos = horizonPixels + (yPos * remainingHeight);

    double laneX = _getLaneX(lane);
    double xSpread = laneX * (0.3 + (yPos * 0.7)); 

    // Visual jump offset
    double jumpOffset = 0.0;
    if (isPlayer && _isJumping) {
      jumpOffset = -100.0; 
      scale *= 1.2; 
    }

    return Positioned(
      top: topPos + jumpOffset,
      left: 0, 
      right: 0,
      child: Align(
        alignment: Alignment(xSpread, 0.0),
        child: Transform.scale(
          scale: scale,
          child: Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: color,
              shape: isPlayer ? BoxShape.circle : BoxShape.rectangle,
              boxShadow: [
                 BoxShadow(
                  color: Colors.black45, 
                  blurRadius: 10, 
                  offset: isPlayer && _isJumping ? const Offset(0, 30) : const Offset(0, 5)
                )
              ],
              border: Border.all(color: Colors.white, width: 2),
              borderRadius: isPlayer ? null : BorderRadius.circular(8)
            ),
            child: isPlayer 
              ? const Icon(Icons.directions_run, color: Colors.black, size: 40)
              : const Icon(Icons.warning, color: Colors.white24, size: 40),
          ),
        ),
      ),
    );
  }

  void _showGameOverDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text("GAME OVER"),
        content: Text("You ran ${_score}m!"),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _startGame();
            },
            child: const Text("Try Again"),
          )
        ],
      ),
    );
  }
}

class RoadLinePainter extends CustomPainter {
  final double xAlignment;
  RoadLinePainter({required this.xAlignment});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white24
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    final center = size.width / 2;
    final topX = center + (center * xAlignment * 0.2); 
    final bottomX = center + (center * xAlignment);

    final path = Path();
    path.moveTo(topX, 0);
    path.lineTo(bottomX, size.height);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
