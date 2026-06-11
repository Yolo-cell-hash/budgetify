import 'package:flutter/material.dart';

/// Widget for requesting SMS permission from the user
class PermissionRequestCard extends StatelessWidget {
  final VoidCallback onRequestPermission;
  final VoidCallback? onOpenSettings;
  final bool isPermanentlyDenied;

  const PermissionRequestCard({
    super.key,
    required this.onRequestPermission,
    this.onOpenSettings,
    this.isPermanentlyDenied = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF33486A), Color(0xFF4A6489)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Color(0xFF4A6489).withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Icon
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.sms_outlined,
              size: 40,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),

          // Title
          const Text(
            'Enable SMS Reading',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),

          // Description
          Text(
            isPermanentlyDenied
                ? 'SMS permission was denied. Please enable it in Settings to auto-detect bank transactions.'
                : 'Allow Budget Tracker to read your SMS messages to automatically detect and log bank transactions.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withOpacity(0.9),
            ),
          ),
          const SizedBox(height: 20),

          // Features list
          if (!isPermanentlyDenied) ...[
            _buildFeature('Auto-detect credits & debits'),
            _buildFeature('Works in background'),
            _buildFeature('Secure & private'),
            const SizedBox(height: 20),
          ],

          // Action button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: isPermanentlyDenied
                  ? onOpenSettings
                  : onRequestPermission,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Color(0xFF33486A),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: Text(
                isPermanentlyDenied ? 'Open Settings' : 'Grant Permission',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),

          if (!isPermanentlyDenied) ...[
            const SizedBox(height: 12),
            Text(
              'Your data stays on your device',
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withOpacity(0.7),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFeature(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            Icons.check_circle,
            size: 18,
            color: Color(0xFF4CC795),
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withOpacity(0.9),
            ),
          ),
        ],
      ),
    );
  }
}
