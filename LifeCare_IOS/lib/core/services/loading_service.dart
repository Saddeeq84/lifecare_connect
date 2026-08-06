import 'package:flutter/material.dart';

/// Service for managing loading states across the application
class LoadingService {
  /// Show a loading dialog
  static OverlayEntry? _currentOverlay;

  /// Show full-screen loading indicator
  static void showLoading(
    BuildContext context, {
    String? message,
    bool canDismiss = false,
  }) {
    hideLoading(); // Hide any existing overlay

    _currentOverlay = OverlayEntry(
      builder: (context) =>
          LoadingOverlay(message: message, canDismiss: canDismiss),
    );

    Overlay.of(context).insert(_currentOverlay!);
  }

  /// Hide loading overlay
  static void hideLoading() {
    _currentOverlay?.remove();
    _currentOverlay = null;
  }

  /// Create a loading widget for inline use
  static Widget buildLoadingWidget({
    String? message,
    double size = 40.0,
    Color? color,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(
              strokeWidth: 3.0,
              valueColor: AlwaysStoppedAnimation<Color>(color ?? Colors.blue),
            ),
          ),
          if (message != null) ...[
            const SizedBox(height: 16),
            Text(
              message,
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }

  /// Create a shimmer loading effect for lists
  static Widget buildShimmerList({
    int itemCount = 5,
    double itemHeight = 80.0,
  }) {
    return ListView.builder(
      itemCount: itemCount,
      itemBuilder: (context, index) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        height: itemHeight,
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(8),
        ),
        child: const ShimmerEffect(),
      ),
    );
  }

  /// Create a card loading skeleton
  static Widget buildCardSkeleton({double height = 120.0, EdgeInsets? margin}) {
    return Container(
      margin: margin ?? const EdgeInsets.all(16),
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(12),
      ),
      child: const ShimmerEffect(),
    );
  }

  /// Handle async operations with loading states
  static Future<T?> withLoading<T>(
    BuildContext context,
    Future<T> Function() operation, {
    String? loadingMessage,
    String? successMessage,
    bool showSuccessMessage = false,
  }) async {
    showLoading(context, message: loadingMessage);

    try {
      final result = await operation();

      if (showSuccessMessage && successMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_outline, color: Colors.white),
                const SizedBox(width: 8),
                Text(successMessage),
              ],
            ),
            backgroundColor: Colors.green.shade600,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }

      return result;
    } finally {
      hideLoading();
    }
  }
}

/// Full-screen loading overlay
class LoadingOverlay extends StatelessWidget {
  final String? message;
  final bool canDismiss;

  const LoadingOverlay({super.key, this.message, this.canDismiss = false});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withOpacity(0.7),
      child: WillPopScope(
        onWillPop: () async => canDismiss,
        child: Center(
          child: Container(
            padding: const EdgeInsets.all(24),
            margin: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 50,
                  height: 50,
                  child: CircularProgressIndicator(strokeWidth: 3),
                ),
                if (message != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    message!,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
                if (canDismiss) ...[
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () => LoadingService.hideLoading(),
                    child: const Text('Cancel'),
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

/// Shimmer effect widget for loading skeletons
class ShimmerEffect extends StatefulWidget {
  final Color? baseColor;
  final Color? highlightColor;

  const ShimmerEffect({super.key, this.baseColor, this.highlightColor});

  @override
  State<ShimmerEffect> createState() => _ShimmerEffectState();
}

class _ShimmerEffectState extends State<ShimmerEffect>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat();

    _animation = Tween<double>(
      begin: -1.0,
      end: 2.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final baseColor = widget.baseColor ?? Colors.grey[300]!;
    final highlightColor = widget.highlightColor ?? Colors.grey[100]!;

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              stops: [
                (_animation.value - 1.0).clamp(0.0, 1.0),
                _animation.value.clamp(0.0, 1.0),
                (_animation.value + 1.0).clamp(0.0, 1.0),
              ],
              colors: [baseColor, highlightColor, baseColor],
            ),
          ),
        );
      },
    );
  }
}

/// Loading state mixin for StatefulWidgets
mixin LoadingStateMixin<T extends StatefulWidget> on State<T> {
  bool _isLoading = false;

  bool get isLoading => _isLoading;

  void setLoading(bool loading) {
    if (mounted) {
      setState(() {
        _isLoading = loading;
      });
    }
  }

  Future<void> runWithLoading(Future<void> Function() operation) async {
    setLoading(true);
    try {
      await operation();
    } finally {
      setLoading(false);
    }
  }
}

/// Enhanced StreamBuilder with loading states
class EnhancedStreamBuilder<T> extends StatelessWidget {
  final Stream<T> stream;
  final Widget Function(BuildContext context, T data) builder;
  final Widget Function(BuildContext context, Object error)? errorBuilder;
  final Widget Function(BuildContext context)? loadingBuilder;
  final Widget Function(BuildContext context)? emptyBuilder;
  final T? initialData;

  const EnhancedStreamBuilder({
    super.key,
    required this.stream,
    required this.builder,
    this.errorBuilder,
    this.loadingBuilder,
    this.emptyBuilder,
    this.initialData,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<T>(
      stream: stream,
      initialData: initialData,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return errorBuilder?.call(context, snapshot.error!) ??
              LoadingService.buildLoadingWidget(message: 'Error loading data');
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return loadingBuilder?.call(context) ??
              LoadingService.buildLoadingWidget(message: 'Loading...');
        }

        if (!snapshot.hasData) {
          return emptyBuilder?.call(context) ??
              const Center(child: Text('No data available'));
        }

        return builder(context, snapshot.data as T);
      },
    );
  }
}

/// Enhanced FutureBuilder with loading states
class EnhancedFutureBuilder<T> extends StatelessWidget {
  final Future<T> future;
  final Widget Function(BuildContext context, T data) builder;
  final Widget Function(BuildContext context, Object error)? errorBuilder;
  final Widget Function(BuildContext context)? loadingBuilder;
  final Widget Function(BuildContext context)? emptyBuilder;

  const EnhancedFutureBuilder({
    super.key,
    required this.future,
    required this.builder,
    this.errorBuilder,
    this.loadingBuilder,
    this.emptyBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<T>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return errorBuilder?.call(context, snapshot.error!) ??
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 64,
                      color: Colors.grey,
                    ),
                    const SizedBox(height: 16),
                    Text('Error: ${snapshot.error}'),
                  ],
                ),
              );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return loadingBuilder?.call(context) ??
              LoadingService.buildLoadingWidget(message: 'Loading...');
        }

        if (!snapshot.hasData) {
          return emptyBuilder?.call(context) ??
              const Center(child: Text('No data available'));
        }

        return builder(context, snapshot.data as T);
      },
    );
  }
}
