import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

class ShareableProfileWidget extends StatelessWidget {
  final String userId;
  final String userName;

  const ShareableProfileWidget({
    super.key,
    required this.userId,
    required this.userName,
  });

  String get profileUrl => 'https://lifecare-connect.web.app/profile/$userId';

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.share, color: Colors.teal, size: 28),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Shareable Profile Link',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'Share your profile so people can view your services and book appointments.',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 20),

            // Profile URL
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      profileUrl,
                      style: const TextStyle(
                        fontSize: 14,
                        fontFamily: 'monospace',
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy, size: 20),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: profileUrl));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Link copied to clipboard!'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                    tooltip: 'Copy link',
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Share.share(
                        'Check out my profile on LifeCare Connect: $profileUrl',
                        subject: '$userName - LifeCare Connect',
                      );
                    },
                    icon: const Icon(Icons.share),
                    label: const Text('Share'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      _showQRCode(context);
                    },
                    icon: const Icon(Icons.qr_code),
                    label: const Text('QR Code'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.teal,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Social Media Share Buttons
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildSocialButton(
                  context,
                  icon: Icons.message,
                  label: 'WhatsApp',
                  color: Colors.green,
                  onPressed: () {
                    final message = Uri.encodeComponent(
                      'Check out my profile on LifeCare Connect: $profileUrl',
                    );
                    Share.share('whatsapp://send?text=$message');
                  },
                ),
                _buildSocialButton(
                  context,
                  icon: Icons.email,
                  label: 'Email',
                  color: Colors.blue,
                  onPressed: () {
                    final subject = Uri.encodeComponent(
                      '$userName - LifeCare Connect',
                    );
                    final body = Uri.encodeComponent(
                      'Check out my profile on LifeCare Connect: $profileUrl',
                    );
                    Share.share('mailto:?subject=$subject&body=$body');
                  },
                ),
                _buildSocialButton(
                  context,
                  icon: Icons.link,
                  label: 'Copy Link',
                  color: Colors.orange,
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: profileUrl));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Link copied!'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSocialButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(color: color),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
    );
  }

  void _showQRCode(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Profile QR Code'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            QrImageView(
              data: profileUrl,
              version: QrVersions.auto,
              size: 250.0,
              backgroundColor: Colors.white,
            ),
            const SizedBox(height: 16),
            Text(
              'Scan to visit $userName\'s profile',
              style: const TextStyle(fontSize: 14, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              // TODO: Add functionality to save QR code as image
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('QR code download coming soon!')),
              );
            },
            icon: const Icon(Icons.download),
            label: const Text('Save'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
