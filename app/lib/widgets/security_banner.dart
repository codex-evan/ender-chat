/// Security warning banner widget

import 'package:flutter/material.dart';
import '../main/app_theme.dart';

class SecurityBanner extends StatefulWidget {
  final String message;
  final VoidCallback onDismiss;
  
  const SecurityBanner({
    super.key,
    required this.message,
    required this.onDismiss,
  });

  @override
  State<SecurityBanner> createState() => _SecurityBannerState();
}

class _SecurityBannerState extends State<SecurityBanner>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _slideAnimation;
  bool _visible = true;
  
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    
    _slideAnimation = Tween<double>(begin: -1.0, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    
    _controller.forward();
    
    // Auto-dismiss after 8 seconds
    Future.delayed(const Duration(seconds: 8), () {
      _dismiss();
    });
  }
  
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  
  void _dismiss() {
    setState(() => _visible = false);
    _controller.reverse().then((_) => widget.onDismiss());
  }
  
  @override
  Widget build(BuildContext context) {
    if (!_visible) return const SizedBox.shrink();
    
    return SlideTransition(
      position: _slideAnimation,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFFF6B6B).withOpacity(0.9),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFF6B6B).withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                widget.message,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _dismiss,
              child: const Icon(Icons.close, color: Colors.white, size: 18),
            ),
          ],
        ),
      ),
    );
  }
}
