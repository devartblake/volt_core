import 'package:flutter/material.dart';

import 'nav_config.dart';

/// Section header for grouped navigation
class DrawerSection extends StatefulWidget {
  const DrawerSection({
    super.key,
    required this.section,
    required this.selectedItem,
    required this.badges,
    required this.onTap,
  });

  final NavSection section;
  final NavItem? selectedItem;
  final Map<String, int> badges;
  final ValueChanged<NavItem> onTap;

  @override
  State<DrawerSection> createState() => _DrawerSectionState();
}

class _DrawerSectionState extends State<DrawerSection> {
  late bool _expanded = _hasSelectedItem;

  bool get _hasSelectedItem => widget.section.items.any(
    (item) => item.route == widget.selectedItem?.route,
  );

  @override
  void didUpdateWidget(covariant DrawerSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_hasSelectedItem && !_expanded) _expanded = true;
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.section.title;
    if (title == null) {
      return Column(
        children: [
          _items(),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Divider(height: 16),
          ),
        ],
      );
    }

    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Column(
      children: [
        ListTile(
          dense: true,
          contentPadding: const EdgeInsets.only(left: 20, right: 12),
          title: Text(
            title.toUpperCase(),
            style: theme.textTheme.labelSmall?.copyWith(
              color: colors.onSurfaceVariant,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.1,
            ),
          ),
          trailing: Icon(_expanded ? Icons.expand_less : Icons.expand_more),
          onTap: () => setState(() => _expanded = !_expanded),
        ),
        AnimatedCrossFade(
          firstChild: _items(),
          secondChild: const SizedBox.shrink(),
          crossFadeState: _expanded
              ? CrossFadeState.showFirst
              : CrossFadeState.showSecond,
          duration: const Duration(milliseconds: 160),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Divider(height: 16),
        ),
      ],
    );
  }

  Widget _items() => Column(
    children: [
      for (final item in widget.section.items)
        ModernDrawerTile(
          item: item,
          selected: widget.selectedItem?.route == item.route,
          count: widget.badges[item.route] ?? 0,
          onTap: () => widget.onTap(item),
        ),
    ],
  );
}

/// Quick action buttons bar
class QuickActionsBar extends StatelessWidget {
  const QuickActionsBar({
    super.key,
    required this.actions,
    required this.onTap,
  });

  final List<NavItem> actions;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          for (int i = 0; i < actions.length; i++) ...[
            Expanded(
              child: FilledButton.tonalIcon(
                onPressed: () => onTap(actions[i].route),
                icon: Icon(actions[i].icon, size: 20),
                label: Text(
                  actions[i].label.replaceAll('Create ', ''),
                  style: const TextStyle(fontSize: 13),
                ),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            if (i < actions.length - 1) const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

/// Modern drawer header
class ModernDrawerHeader extends StatelessWidget {
  const ModernDrawerHeader({
    super.key,
    required this.companyName,
    required this.companySubtitle,
  });

  final String companyName;
  final String companySubtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colorScheme.primaryContainer,
            colorScheme.primaryContainer.withValues(alpha: 0.7),
          ],
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: colorScheme.primary,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: colorScheme.primary.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(
              Icons.bolt,
              color: colorScheme.onPrimary,
              size: 32,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  companyName,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  companySubtitle,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color:
                    colorScheme.onPrimaryContainer.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Modern drawer tile
class ModernDrawerTile extends StatelessWidget {
  const ModernDrawerTile({
    super.key,
    required this.item,
    required this.selected,
    required this.onTap,
    required this.count,
  });

  final NavItem item;
  final bool selected;
  final VoidCallback onTap;
  final int count;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    final trailing = count > 0
        ? Badge(
      label: Text('$count'),
      backgroundColor: colorScheme.error,
      textColor: colorScheme.onError,
    )
        : null;

    return Padding(
      padding: EdgeInsets.only(
        left: item.isSubItem ? 28 : 12,
        right: 12,
        top: 2,
        bottom: 2,
      ),
      child: ListTile(
        leading: Icon(
          item.icon,
          color:
          selected ? colorScheme.primary : colorScheme.onSurfaceVariant,
        ),
        title: Text(
          item.label,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            color: selected ? colorScheme.primary : colorScheme.onSurface,
          ),
        ),
        subtitle: item.description != null && selected
            ? Text(
          item.description!,
          style: theme.textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        )
            : null,
        selected: selected,
        trailing: trailing,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        onTap: onTap,
      ),
    );
  }
}

/// Badge icon for navigation rail
class BadgeIcon extends StatelessWidget {
  const BadgeIcon({
    super.key,
    required this.icon,
    required this.count,
    this.selected = false,
  });

  final IconData icon;
  final int count;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final ic = Icon(
      icon,
      color: selected ? colorScheme.primary : colorScheme.onSurfaceVariant,
    );
    if (count <= 0) return ic;
    return Badge(
      label: Text('$count'),
      backgroundColor: colorScheme.error,
      textColor: colorScheme.onError,
      child: ic,
    );
  }
}

/// App brand
class AppBrand extends StatelessWidget {
  const AppBrand({
    super.key,
    required this.isExtended,
    required this.companyName,
  });

  final bool isExtended;
  final String companyName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (isExtended) {
      return Container(
        padding:
        const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.bolt,
                size: 24,
                color: colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              companyName,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(
        Icons.bolt,
        size: 24,
        color: colorScheme.onPrimaryContainer,
      ),
    );
  }
}

