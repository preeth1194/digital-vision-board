import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/vision_components.dart';

class HabitTrackerHeader extends StatelessWidget {
  final VisionComponent component;
  final VoidCallback onClose;

  const HabitTrackerHeader({
    super.key,
    required this.component,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final link = component is ZoneComponent ? (component as ZoneComponent).link : null;
    final hasLink = link != null && link.isNotEmpty;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  component.id,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                if (hasLink)
                  TextButton.icon(
                    onPressed: () async {
                      try {
                        final url = Uri.parse(link);
                        if (await canLaunchUrl(url)) {
                          await launchUrl(url, mode: LaunchMode.externalApplication);
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Could not open link: $e')),
                          );
                        }
                      }
                    },
                    icon: const Icon(Icons.open_in_new, size: 16),
                    label: const Text('Open Link'),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: onClose,
          ),
        ],
      ),
    );
  }
}

