import 'package:flutter/material.dart';

class AppButton extends StatelessWidget {
  const AppButton({
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.icon,
    this.isOutlined = false,
    this.minimumHeight = 52.0,
    super.key,
  });

  final bool isLoading;
  final String label;
  final VoidCallback? onPressed;
  final Widget? icon;
  final bool isOutlined;
  final double minimumHeight;

  @override
  Widget build(BuildContext context) {
    final effectiveMinSize = Size.fromHeight(minimumHeight);

    Widget buildContent({required bool outlined}) {
      return AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        transitionBuilder: (child, animation) =>
            FadeTransition(opacity: animation, child: child),
        child: isLoading
            ? SizedBox.square(
                key: const ValueKey('app-button-loading'),
                dimension: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: outlined
                      ? Theme.of(context).colorScheme.primary
                      : Colors.white,
                ),
              )
            : (icon != null
                  ? Row(
                      key: const ValueKey('app-button-content-icon'),
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        icon!,
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            label,
                            textAlign: TextAlign.center,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    )
                  : Text(
                      label,
                      key: const ValueKey('app-button-content-text'),
                      textAlign: TextAlign.center,
                    )),
      );
    }

    if (isOutlined) {
      return OutlinedButton(
        onPressed: isLoading ? null : onPressed,
        style: OutlinedButton.styleFrom(minimumSize: effectiveMinSize),
        child: buildContent(outlined: true),
      );
    }

    return FilledButton(
      onPressed: isLoading ? null : onPressed,
      style: FilledButton.styleFrom(minimumSize: effectiveMinSize),
      child: buildContent(outlined: false),
    );
  }
}
