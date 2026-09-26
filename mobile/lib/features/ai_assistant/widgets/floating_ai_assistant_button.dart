import 'package:flutter/material.dart';
import '../ai_chat_sheet.dart';

class FloatingAiAssistantButton extends StatefulWidget {
  const FloatingAiAssistantButton({super.key});

  @override
  State<FloatingAiAssistantButton> createState() =>
      _FloatingAiAssistantButtonState();
}

class _FloatingAiAssistantButtonState extends State<FloatingAiAssistantButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;

  Offset? _position;
  final double _buttonSize = 58.0;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.06).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final padding = MediaQuery.of(context).padding;

    // Default position: Bottom-left (opposite of the bottom-right Add button)
    final double defaultLeft = 20.0;
    final double defaultTop = screenSize.height - padding.bottom - 160.0;

    _position ??= Offset(defaultLeft, defaultTop);

    // Boundary constraints so button never goes offscreen
    final minX = 10.0;
    final maxX = (screenSize.width - _buttonSize - 10.0).clamp(minX, double.infinity);
    final minY = padding.top + 10.0;
    final maxY = (screenSize.height - padding.bottom - 100.0).clamp(minY, double.infinity);

    final currentX = _position!.dx.clamp(minX, maxX);
    final currentY = _position!.dy.clamp(minY, maxY);

    return Positioned(
      left: currentX,
      top: currentY,
      child: GestureDetector(
        onPanUpdate: (details) {
          setState(() {
            _position = Offset(
              (_position!.dx + details.delta.dx).clamp(minX, maxX),
              (_position!.dy + details.delta.dy).clamp(minY, maxY),
            );
          });
        },
        onTap: () => AiChatSheet.show(context),
        child: AnimatedBuilder(
          animation: _scaleAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: _scaleAnimation.value,
              child: child,
            );
          },
          child: Container(
            width: _buttonSize,
            height: _buttonSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFF0072FF), Color(0xFF00C6FF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0072FF).withValues(alpha: 0.45),
                  blurRadius: 14,
                  spreadRadius: 2,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            padding: const EdgeInsets.all(2.5),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Assistant image inside circle
                Container(
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                  ),
                  child: ClipOval(
                    child: Image.asset(
                      'assets/images/ai_assistant.png',
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                      errorBuilder: (_, __, ___) => const Center(
                        child: Icon(
                          Icons.smart_toy_rounded,
                          color: Color(0xFF0072FF),
                          size: 30,
                        ),
                      ),
                    ),
                  ),
                ),
                // Sparkle indicator badge
                Positioned(
                  top: -2,
                  right: -2,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFF8A00), Color(0xFFE52E71)],
                      ),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                    child: const Icon(
                      Icons.auto_awesome,
                      size: 10,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
