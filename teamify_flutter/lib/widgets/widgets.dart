import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../core/routes.dart';

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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: margin,
        padding: padding ?? const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color ?? AppColors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 2))
          ],
        ),
        child: child,
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
  const TAvatar({super.key, required this.initials, this.radius = 22, this.bg});

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: bg ?? AppColors.primary,
      child: Text(initials,
          style: TextStyle(
              color: Colors.white,
              fontSize: radius * 0.65,
              fontWeight: FontWeight.bold)),
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
        color: bg ?? AppColors.primary.withOpacity(0.1),
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
              color: Colors.black.withOpacity(0.08),
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
                  color: (iconBg ?? AppColors.primary).withOpacity(0.1),
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
        color: AppColors.primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withOpacity(0.15)),
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
void handleFreelancerNav(BuildContext ctx, int i) {
  switch (i) {
    case 0:
      Navigator.pushReplacementNamed(ctx, R.freelancerHome);
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
      Navigator.pushNamed(ctx, R.freelancerProfile);
      break;
  }
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
