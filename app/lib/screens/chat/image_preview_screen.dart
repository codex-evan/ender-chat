/// Image preview screen

import 'package:flutter/material.dart';
import '../../i18n/app_localizations.dart';

class ImagePreviewScreen extends StatelessWidget {
  final String imageUrl;
  final String? title;
  
  const ImagePreviewScreen({
    super.key,
    required this.imageUrl,
    this.title,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: title != null
            ? Text(title!, style: const TextStyle(color: Colors.white))
            : null,
      ),
      body: Center(
        child: Image.network(
          imageUrl,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.broken_image, size: 64, color: Colors.white54),
                const SizedBox(height: 16),
                Text(
                  'Failed to load image',
                  style: theme.textTheme.bodyLarge?.copyWith(color: Colors.white54),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
