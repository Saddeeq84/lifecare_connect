import 'package:flutter/material.dart';

/// Non-intrusive inline AI suggestions widget
/// Displays suggestions in a collapsible, soft manner without disrupting workflow
class InlineAISuggestionsWidget extends StatefulWidget {
  final List<String> suggestions;
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback? onRefresh;

  const InlineAISuggestionsWidget({
    super.key,
    required this.suggestions,
    required this.title,
    this.icon = Icons.lightbulb_outline,
    this.color = Colors.blue,
    this.onRefresh,
  });

  @override
  State<InlineAISuggestionsWidget> createState() =>
      _InlineAISuggestionsWidgetState();
}

class _InlineAISuggestionsWidgetState extends State<InlineAISuggestionsWidget> {
  bool _isExpanded = true;

  @override
  Widget build(BuildContext context) {
    if (widget.suggestions.isEmpty) return const SizedBox.shrink();

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.only(top: 8, bottom: 8),
      child: Material(
        color: widget.color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: () => setState(() => _isExpanded = !_isExpanded),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: widget.color.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(widget.icon, size: 18, color: widget.color),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.title,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: widget.color.withOpacity(0.9),
                        ),
                      ),
                    ),
                    if (widget.onRefresh != null)
                      IconButton(
                        icon: const Icon(Icons.refresh, size: 16),
                        onPressed: widget.onRefresh,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        color: widget.color.withOpacity(0.7),
                      ),
                    const SizedBox(width: 4),
                    Icon(
                      _isExpanded ? Icons.expand_less : Icons.expand_more,
                      size: 20,
                      color: widget.color.withOpacity(0.7),
                    ),
                  ],
                ),
                if (_isExpanded) ...[
                  const SizedBox(height: 8),
                  ...widget.suggestions.map(
                    (suggestion) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Icon(
                              Icons.circle,
                              size: 6,
                              color: widget.color.withOpacity(0.6),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              suggestion,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade700,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Loading state for suggestions
class InlineAILoadingWidget extends StatelessWidget {
  final String title;
  final Color color;

  const InlineAILoadingWidget({
    super.key,
    required this.title,
    this.color = Colors.blue,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: color.withOpacity(0.8),
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}
