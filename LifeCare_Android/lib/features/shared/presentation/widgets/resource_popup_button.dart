import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../screens/ai_assistant_screen.dart';

class ResourcePopupButton extends StatelessWidget {
  final AIAssistantType assistantType;
  const ResourcePopupButton({
    super.key,
    this.assistantType = AIAssistantType.doctor,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<int>(
      icon: const Icon(Icons.article),
      tooltip: 'Resources',
      onSelected: (value) {
        if (value == 1) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AIAssistantScreen(assistantType: assistantType),
            ),
          );
        } else if (value == 2) {
          // Take Course
          context.push('/chw_dashboard/take_course');
        } else if (value == 3) {
          // Materials (CHW training materials) - route used by CHW dashboard
          context.push('/chw_dashboard/training');
        }
      },
      itemBuilder: (context) => const [
        PopupMenuItem(value: 1, child: Text('AI Assistant')),
        PopupMenuItem(value: 2, child: Text('Take Course')),
        PopupMenuItem(value: 3, child: Text('Materials')),
      ],
    );
  }
}
