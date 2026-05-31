import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme.dart';
import '../core/routes.dart';
import '../core/session/session_controller.dart';
import '../services/app_services.dart';
import '../core/network/api_result.dart';

// ── TCard ─────────────────────────────────────────────────────────────────────
class TCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final EdgeInsets? margin;
  final VoidCallback? onTap;
  final Color? color;
  const TCard(
      {super.key,
      required this.child,
      this.padding,
      this.margin,
      this.onTap,
      this.color});

  @override
  Widget build(BuildContext context) {
    final card = Container(
        margin: margin,
        padding: padding ?? const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color ?? Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Theme.of(context).dividerColor),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2))
          ],
        ),
        child: child,
      );

    if (onTap == null) return card;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: card,
      ),
    );
  }
}

// ── TButton (Primary) ─────────────────────────────────────────────────────────
class TButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  final bool outline;
  const TButton(
      {super.key,
      required this.label,
      this.onTap,
      this.icon,
      this.outline = false});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: outline
          ? OutlinedButton(
              onPressed: onTap,
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.primary),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(label,
                  style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                      fontSize: 16)),
            )
          : ElevatedButton(
              onPressed: onTap,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Icon(icon, color: Colors.white, size: 18),
                    const SizedBox(width: 8)
                  ],
                  Text(label,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 16)),
                ],
              ),
            ),
    );
  }
}

// ── TAvatar ───────────────────────────────────────────────────────────────────
class TAvatar extends StatelessWidget {
  final String initials;
  final double radius;
  final Color? bg;
  final ImageProvider? backgroundImage;
  const TAvatar({
    super.key,
    required this.initials,
    this.radius = 22,
    this.bg,
    this.backgroundImage,
  });

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: bg ?? AppColors.primary,
      backgroundImage: backgroundImage,
      child: backgroundImage == null
          ? Text(initials,
              style: TextStyle(
                  color: Colors.white,
                  fontSize: radius * 0.65,
                  fontWeight: FontWeight.bold))
          : null,
    );
  }
}

// ── TChip ─────────────────────────────────────────────────────────────────────
class TChip extends StatelessWidget {
  final String label;
  final Color? bg;
  final Color? textColor;
  final double fontSize;
  const TChip(
      {super.key,
      required this.label,
      this.bg,
      this.textColor,
      this.fontSize = 11});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg ?? AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: fontSize,
              color: textColor ?? AppColors.primary,
              fontWeight: FontWeight.w600)),
    );
  }
}

// ── TBar (Progress) ───────────────────────────────────────────────────────────
class TBar extends StatelessWidget {
  final double value;
  final Color? color;
  final double height;
  const TBar({super.key, required this.value, this.color, this.height = 6});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: LinearProgressIndicator(
        value: value.clamp(0.0, 1.0),
        backgroundColor: AppColors.border,
        valueColor: AlwaysStoppedAnimation(color ?? AppColors.primary),
        minHeight: height,
      ),
    );
  }
}

// ── TSectionHeader ────────────────────────────────────────────────────────────
class TSectionHeader extends StatelessWidget {
  final String title;
  final String? action;
  final VoidCallback? onAction;
  const TSectionHeader(
      {super.key, required this.title, this.action, this.onAction});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title,
            style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary)),
        if (action != null)
          GestureDetector(
            onTap: onAction,
            child: Text(action!,
                style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600)),
          ),
      ],
    );
  }
}

// ── TBackButton ───────────────────────────────────────────────────────────────
class TBackButton extends StatelessWidget {
  const TBackButton({super.key});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.pop(context),
      child: const Icon(Icons.arrow_back_ios,
          size: 20, color: AppColors.textPrimary),
    );
  }
}

// ── BottomNav ─────────────────────────────────────────────────────────────────
class TBottomNav extends StatelessWidget {
  final int current;
  final ValueChanged<int> onTap;
  const TBottomNav({super.key, required this.current, required this.onTap});

  @override
  Widget build(BuildContext context) {
    const items = [
      {'icon': Icons.home_outlined, 'activeIcon': Icons.home, 'label': 'Home'},
      {
        'icon': Icons.search_outlined,
        'activeIcon': Icons.search,
        'label': 'Search'
      },
      {
        'icon': Icons.auto_awesome_outlined,
        'activeIcon': Icons.auto_awesome,
        'label': 'AI'
      },
      {
        'icon': Icons.chat_bubble_outline,
        'activeIcon': Icons.chat_bubble,
        'label': 'Chat'
      },
      {
        'icon': Icons.person_outline,
        'activeIcon': Icons.person,
        'label': 'Profile'
      },
    ];
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 16,
              offset: const Offset(0, -4))
        ],
      ),
      child: SafeArea(
        child: SizedBox(
          height: 48,
          child: Row(
            children: List.generate(items.length, (i) {
              final sel = current == i;
              return Expanded(
                child: GestureDetector(
                  onTap: () => onTap(i),
                  behavior: HitTestBehavior.opaque,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                          sel
                              ? items[i]['activeIcon'] as IconData
                              : items[i]['icon'] as IconData,
                          color:
                              sel ? AppColors.primary : AppColors.textSecondary,
                          size: 24),
                      const SizedBox(height: 2),
                      Text(items[i]['label'] as String,
                          style: TextStyle(
                              fontSize: 11,
                              color: sel
                                  ? AppColors.primary
                                  : AppColors.textSecondary,
                              fontWeight:
                                  sel ? FontWeight.w600 : FontWeight.normal)),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

// ── StatBox ───────────────────────────────────────────────────────────────────
class StatBox extends StatelessWidget {
  final String value, label;
  final IconData icon;
  final Color? iconBg;
  const StatBox(
      {super.key,
      required this.value,
      required this.label,
      required this.icon,
      this.iconBg});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: TCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                  color: (iconBg ?? AppColors.primary).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, color: iconBg ?? AppColors.primary, size: 20),
            ),
            const SizedBox(height: 4),
            Text(value,
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary)),
            Text(label,
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}

// ── AIBanner ──────────────────────────────────────────────────────────────────
class AIBanner extends StatelessWidget {
  final String title, subtitle, badge;
  final VoidCallback? onTap;
  const AIBanner(
      {super.key,
      required this.title,
      required this.subtitle,
      this.badge = '',
      this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(12)),
            child:
                const Icon(Icons.auto_awesome, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                        fontSize: 14)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary)),
                if (badge.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(badge,
                      style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.success,
                          fontWeight: FontWeight.w600)),
                ],
              ],
            ),
          ),
          if (onTap != null)
            GestureDetector(
              onTap: onTap,
              child: const Text('Review now →',
                  style: TextStyle(
                      fontSize: 12,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600)),
            ),
        ],
      ),
    );
  }
}

// ── NavHelper ─────────────────────────────────────────────────────────────────
void handleFreelancerNav(BuildContext ctx, int i, {bool? isStudent}) {
  final student = isStudent ??
      (Provider.of<SessionController>(ctx, listen: false).currentUser?.isStudent ??
          false);
  switch (i) {
    case 0:
      Navigator.pushReplacementNamed(
          ctx, student ? R.studentHome : R.freelancerHome);
      break;
    case 1:
      Navigator.pushNamed(ctx, R.search);
      break;
    case 2:
      Navigator.pushNamed(ctx, R.aiHub);
      break;
    case 3:
      Navigator.pushNamed(ctx, R.chatList);
      break;
    case 4:
      Navigator.pushReplacementNamed(
          ctx, student ? R.studentProfile : R.freelancerProfile);
      break;
  }
}

/// Role-aware bottom navigation (student vs freelancer home/profile).
void handleRoleNav(BuildContext ctx, int i) {
  handleFreelancerNav(ctx, i);
}

// ── Repository Loader ─────────────────────────────────────────────────────────
class RepositoryLoader<T> extends StatefulWidget {
  final Future<T> Function() load;
  final Widget Function(BuildContext context, T data) builder;
  final bool Function(T data)? isEmpty;
  final String emptyMessage;

  const RepositoryLoader({
    super.key,
    required this.load,
    required this.builder,
    this.isEmpty,
    this.emptyMessage = 'No data found',
  });

  @override
  State<RepositoryLoader<T>> createState() => _RepositoryLoaderState<T>();
}

class _RepositoryLoaderState<T> extends State<RepositoryLoader<T>> {
  late Future<T> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.load();
  }

  void _retry() {
    setState(() {
      _future = widget.load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<T>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError || !snapshot.hasData) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    snapshot.error?.toString() ??
                        'Something went wrong. Try again.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: _retry,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        }

        final data = snapshot.data as T;
        if (widget.isEmpty != null && widget.isEmpty!(data)) {
          return Center(
            child: Text(
              widget.emptyMessage,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          );
        }

        return widget.builder(context, data);
      },
    );
  }
}

// ── SyncStatusBadge ───────────────────────────────────────────────────────────
/// Wraps [child] and overlays a small cloud-off indicator when
/// [isPendingSync] is true (i.e. the entity was queued offline and
/// hasn't been confirmed by the server yet).
///
/// Usage:
/// ```dart
/// SyncStatusBadge(
///   isPendingSync: result.isPendingSync,
///   child: TaskCard(task: task),
/// )
/// ```
class SyncStatusBadge extends StatelessWidget {
  final Widget child;
  final bool isPendingSync;

  const SyncStatusBadge({
    super.key,
    required this.child,
    this.isPendingSync = false,
  });

  @override
  Widget build(BuildContext context) {
    if (!isPendingSync) return child;

    return Stack(
      children: [
        Opacity(opacity: 0.65, child: child),
        Positioned(
          top: 6,
          right: 6,
          child: Tooltip(
            message: 'Pending sync — will upload when back online',
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.orange.shade700,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.cloud_off_rounded,
                size: 12,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── SyncErrorBanner ───────────────────────────────────────────────────────────
/// An app-bar-level dismissible banner that surfaces queue health to the user.
///
/// Show it at the top of any [Scaffold] body when [queueDepth] > 0 or
/// [permanentFailures] > 0.
///
/// ```dart
/// body: Column(children: [
///   SyncErrorBanner(
///     queueDepth: 3,
///     permanentFailures: 1,
///     onRetry: () => context.read<OfflineManager>().replayQueue(),
///   ),
///   Expanded(child: ...),
/// ]),
/// ```
class SyncErrorBanner extends StatefulWidget {
  final int queueDepth;
  final int permanentFailures;
  final VoidCallback? onRetry;

  const SyncErrorBanner({
    super.key,
    required this.queueDepth,
    this.permanentFailures = 0,
    this.onRetry,
  });

  @override
  State<SyncErrorBanner> createState() => _SyncErrorBannerState();
}

class _SyncErrorBannerState extends State<SyncErrorBanner> {
  bool _dismissed = false;

  @override
  void didUpdateWidget(SyncErrorBanner old) {
    super.didUpdateWidget(old);
    // Re-show if queue grew
    if (widget.queueDepth > old.queueDepth) {
      _dismissed = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_dismissed) return const SizedBox.shrink();

    final hasPermanent = widget.permanentFailures > 0;
    final bannerColor =
        hasPermanent ? Colors.red.shade700 : Colors.orange.shade700;
    final icon =
        hasPermanent ? Icons.error_outline_rounded : Icons.cloud_sync_rounded;

    String message;
    if (hasPermanent) {
      message =
          '${widget.permanentFailures} action(s) failed permanently. '
          '${widget.queueDepth} pending.';
    } else {
      message =
          '${widget.queueDepth} action(s) queued — syncing when online…';
    }

    return AnimatedSlide(
      offset: Offset.zero,
      duration: const Duration(milliseconds: 300),
      child: Container(
        color: bannerColor,
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w500),
              ),
            ),
            if (widget.onRetry != null && !hasPermanent)
              TextButton(
                onPressed: widget.onRetry,
                style: TextButton.styleFrom(
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 8)),
                child: const Text('Retry',
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 18),
              padding: EdgeInsets.zero,
              onPressed: () => setState(() => _dismissed = true),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Notification Badge ────────────────────────────────────────────────────────
class NotificationBadgeWidget extends StatefulWidget {
  const NotificationBadgeWidget({super.key});

  @override
  State<NotificationBadgeWidget> createState() =>
      _NotificationBadgeWidgetState();
}

class _NotificationBadgeWidgetState extends State<NotificationBadgeWidget> {
  int _count = 0;
  StreamSubscription<int>? _sub;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sub ??= context
        .read<AppServices>()
        .notifications
        .unreadCountStream
        .listen((count) {
      if (mounted) setState(() => _count = count);
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    try {
      final count = await context
          .read<AppServices>()
          .notifications
          .getUnreadCount()
          .unwrap();
      if (mounted) setState(() => _count = count);
    } catch (_) {
      // Hide badge when count cannot be loaded.
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_count <= 0) return const SizedBox.shrink();
    return Positioned(
        top: 8,
        right: 8,
        child: Container(
            padding: const EdgeInsets.all(4),
            decoration: const BoxDecoration(
                color: Colors.red, shape: BoxShape.circle),
            constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
            child: Center(
                child: Text(
                    _count > 99 ? '99+' : '$_count',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.bold)))));
  }
}
