import 'package:adminmrz/package/packageProvider.dart';
import 'package:adminmrz/package/packagemodel.dart';
import 'package:adminmrz/core/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

// ─── Tier config ─────────────────────────────────────────────────────────────

class _TierCfg {
  final Color accent;
  final Color bg;
  final Color ring;
  final IconData icon;
  const _TierCfg(this.accent, this.bg, this.ring, this.icon);
}

_TierCfg _tierFor(String name) {
  switch (name.trim().toLowerCase()) {
    case 'diamond':
      return const _TierCfg(
        Color(0xFF0EA5E9), Color(0xFFEFF9FF), Color(0xFFBAE6FD), Icons.diamond_rounded);
    case 'gold':
      return const _TierCfg(
        Color(0xFFF59E0B), Color(0xFFFFFBEB), Color(0xFFFDE68A), Icons.star_rounded);
    case 'platinum':
      return const _TierCfg(
        Color(0xFF8B5CF6), Color(0xFFF5F3FF), Color(0xFFDDD6FE), Icons.workspace_premium_rounded);
    case 'silver':
      return const _TierCfg(
        Color(0xFF64748B), Color(0xFFF8FAFC), Color(0xFFCBD5E1), Icons.military_tech_rounded);
    default:
      return const _TierCfg(
        Color(0xFF3B82F6), Color(0xFFEEF2FF), Color(0xFFE0E7FF), Icons.card_membership_rounded);
  }
}

// ─── Stat card config ─────────────────────────────────────────────────────────

class _StatCfg {
  final String label;
  final String Function(List<Package>) value;
  final IconData icon;
  final Color color;
  _StatCfg(this.label, this.value, this.icon, this.color);
}

final List<_StatCfg> _kStats = [
  _StatCfg('Total Plans', _totalPkgs, Icons.widgets_rounded, Color(0xFF6366F1)),
  _StatCfg('Lowest Price', _minPrice, Icons.south_rounded, Color(0xFF10B981)),
  _StatCfg('Highest Price', _maxPrice, Icons.north_rounded, Color(0xFFF59E0B)),
  _StatCfg('Avg. Price', _avgPrice, Icons.equalizer_rounded, Color(0xFF3B82F6)),
];

String _totalPkgs(List<Package> p) => '${p.length}';
String _minPrice(List<Package> p) {
  if (p.isEmpty) return '—';
  final min = p.map((e) => e.numericPrice).reduce((a, b) => a < b ? a : b);
  return 'Rs ${min.toStringAsFixed(0)}';
}
String _maxPrice(List<Package> p) {
  if (p.isEmpty) return '—';
  final max = p.map((e) => e.numericPrice).reduce((a, b) => a > b ? a : b);
  return 'Rs ${max.toStringAsFixed(0)}';
}
String _avgPrice(List<Package> p) {
  if (p.isEmpty) return '—';
  final avg = p.map((e) => e.numericPrice).reduce((a, b) => a + b) / p.length;
  return 'Rs ${avg.toStringAsFixed(0)}';
}

// ─── Screen ───────────────────────────────────────────────────────────────────

class PackagesPage extends StatefulWidget {
  const PackagesPage({Key? key}) : super(key: key);

  @override
  State<PackagesPage> createState() => _PackagesPageState();
}

class _PackagesPageState extends State<PackagesPage>
    with SingleTickerProviderStateMixin {
  // ── controllers ────────────────────────────────────────────────────────────
  final TextEditingController _searchCtrl = TextEditingController();
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _durationCtrl = TextEditingController();
  final TextEditingController _descCtrl = TextEditingController();
  final TextEditingController _priceCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  // ── panel state ────────────────────────────────────────────────────────────
  bool _panelOpen = false;
  Package? _editingPkg;
  late final AnimationController _panelAnim;
  late final Animation<Offset> _panelSlide;

  @override
  void initState() {
    super.initState();
    _panelAnim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 280));
    _panelSlide = Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
        .animate(CurvedAnimation(parent: _panelAnim, curve: Curves.easeOutCubic));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PackageProvider>().fetchPackages();
    });
  }

  @override
  void dispose() {
    _panelAnim.dispose();
    _searchCtrl.dispose();
    _nameCtrl.dispose();
    _durationCtrl.dispose();
    _descCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  // ── panel helpers ──────────────────────────────────────────────────────────

  void _openCreate() {
    _editingPkg = null;
    _nameCtrl.clear();
    _durationCtrl.clear();
    _descCtrl.clear();
    _priceCtrl.clear();
    setState(() => _panelOpen = true);
    _panelAnim.forward();
  }

  void _openEdit(Package pkg) {
    _editingPkg = pkg;
    _nameCtrl.text = pkg.name;
    _durationCtrl.text = pkg.durationInMonths.toString();
    _descCtrl.text = pkg.description;
    _priceCtrl.text = pkg.numericPrice.toStringAsFixed(2);
    setState(() => _panelOpen = true);
    _panelAnim.forward();
  }

  Future<void> _closePanel() async {
    await _panelAnim.reverse();
    if (mounted) setState(() => _panelOpen = false);
  }

  // ── save logic ─────────────────────────────────────────────────────────────

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;
    final provider = context.read<PackageProvider>();
    final isEdit = _editingPkg != null;
    bool success;

    if (isEdit) {
      final updated = Package(
        id: _editingPkg!.id,
        name: _nameCtrl.text.trim(),
        duration: '${_durationCtrl.text.trim()} Month',
        description: _descCtrl.text.trim(),
        price: 'Rs ${double.parse(_priceCtrl.text.trim()).toStringAsFixed(2)}',
      );
      success = await provider.updatePackage(updated);
    } else {
      success = await provider.createPackage(
        name: _nameCtrl.text.trim(),
        duration: int.parse(_durationCtrl.text.trim()),
        description: _descCtrl.text.trim(),
        price: double.parse(_priceCtrl.text.trim()),
      );
    }

    if (!mounted) return;
    if (success) {
      await _closePanel();
      _showSnack(isEdit ? 'Package updated successfully' : 'Package created successfully',
          kEmerald);
    } else {
      _showSnack('Error: ${provider.error}', kRose);
    }
  }

  // ── delete ─────────────────────────────────────────────────────────────────

  Future<void> _confirmDelete(Package pkg) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(children: [
          Icon(Icons.warning_amber_rounded, color: kRose, size: 22),
          SizedBox(width: 8),
          Text('Delete Package', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        ]),
        content: RichText(
          text: TextSpan(
            style: const TextStyle(color: Color(0xFF475569), fontSize: 14, height: 1.5),
            children: [
              const TextSpan(text: 'Are you sure you want to delete '),
              TextSpan(text: '"${pkg.name}"', style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF1E293B))),
              const TextSpan(text: '? This action cannot be undone.'),
            ],
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: kRose,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final success = await context.read<PackageProvider>().deletePackage(pkg.id);
    if (!mounted) return;
    _showSnack(success ? 'Package deleted' : 'Error: ${context.read<PackageProvider>().error}',
        success ? kEmerald : kRose);
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w500)),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.all(16),
      duration: const Duration(seconds: 3),
    ));
  }

  // ── build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PackageProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
      body: Stack(
        children: [
          Column(
            children: [
              _buildTopBar(provider),
              _buildSearchBar(provider),
              _buildStatsRow(provider.allPackages),
              Expanded(child: _buildBody(provider)),
            ],
          ),
          // Dim overlay when panel open
          if (_panelOpen)
            GestureDetector(
              onTap: _closePanel,
              child: AnimatedOpacity(
                opacity: _panelOpen ? 0.35 : 0,
                duration: const Duration(milliseconds: 250),
                child: Container(color: Colors.black),
              ),
            ),
          // Slide-in panel
          if (_panelOpen)
            Positioned(
              top: 0,
              right: 0,
              bottom: 0,
              width: 380,
              child: SlideTransition(
                position: _panelSlide,
                child: _buildSidePanel(provider),
              ),
            ),
        ],
      ),
    );
  }

  // ── top bar ────────────────────────────────────────────────────────────────

  Widget _buildTopBar(PackageProvider provider) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF4F46E5), Color(0xFF6366F1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [BoxShadow(color: Color(0x30000000), blurRadius: 8, offset: Offset(0, 3))],
      ),
      padding: const EdgeInsets.fromLTRB(20, 14, 16, 14),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.card_membership_rounded, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Package Management',
                    style: TextStyle(
                        color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700,
                        letterSpacing: 0.2)),
                Text('${provider.allPackages.length} active plans',
                    style: TextStyle(color: Colors.white.withOpacity(0.75), fontSize: 12)),
              ],
            ),
          ),
          _headerBtn(icon: Icons.refresh_rounded, tooltip: 'Refresh',
              onTap: () => provider.fetchPackages()),
          const SizedBox(width: 8),
          _headerBtn(icon: Icons.add_rounded, tooltip: 'New Package',
              label: 'New Plan', onTap: _openCreate),
        ],
      ),
    );
  }

  Widget _headerBtn({required IconData icon, required String tooltip,
      String? label, required VoidCallback onTap}) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: EdgeInsets.symmetric(
              horizontal: label != null ? 12 : 8, vertical: 7),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white.withOpacity(0.25)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white, size: 16),
              if (label != null) ...[
                const SizedBox(width: 6),
                Text(label,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ── search bar ─────────────────────────────────────────────────────────────

  Widget _buildSearchBar(PackageProvider provider) {
    final cardBg = Theme.of(context).colorScheme.surface;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      color: cardBg,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: ValueListenableBuilder<TextEditingValue>(
        valueListenable: _searchCtrl,
        builder: (_, value, __) => TextField(
          controller: _searchCtrl,
          onChanged: provider.setSearchQuery,
          style: const TextStyle(fontSize: 14),
          decoration: InputDecoration(
            hintText: 'Search by name, description or price…',
            hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
            prefixIcon: Icon(Icons.search_rounded, color: Colors.grey.shade400, size: 20),
            suffixIcon: value.text.isNotEmpty
                ? IconButton(
                    icon: Icon(Icons.close_rounded, color: Colors.grey.shade400, size: 18),
                    onPressed: () {
                      _searchCtrl.clear();
                      provider.setSearchQuery('');
                    })
                : null,
            filled: true,
            fillColor: isDark ? const Color(0xFF263248) : const Color(0xFFF8FAFC),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: isDark ? Colors.white.withOpacity(0.10) : Colors.grey.shade200)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: isDark ? Colors.white.withOpacity(0.10) : Colors.grey.shade200)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFF6366F1), width: 1.5)),
          ),
        ),
      ),
    );
  }

  // ── stats row ──────────────────────────────────────────────────────────────

  Widget _buildStatsRow(List<Package> pkgs) {
    final cardBg = Theme.of(context).colorScheme.surface;
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 500;
        final cards = _kStats.map((s) {
          return Container(
            margin: const EdgeInsets.only(right: 8, bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: s.color.withOpacity(0.06),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: s.color.withOpacity(0.18)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: s.color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Icon(s.icon, color: s.color, size: 14),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.value(pkgs),
                          style: TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w700, color: s.color)),
                      Text(s.label,
                          style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
              ],
            ),
          );
        }).toList();

        if (isMobile) {
          return Container(
            color: cardBg,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: Column(
              children: [
                Row(children: [Expanded(child: cards[0]), Expanded(child: cards[1])]),
                Row(children: [Expanded(child: cards[2]), Expanded(child: cards[3])]),
              ],
            ),
          );
        }

        return Container(
          color: cardBg,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Row(
            children: cards.map((card) => Expanded(child: card)).toList(),
          ),
        );
      },
    );
  }

  // ── body ───────────────────────────────────────────────────────────────────

  Widget _buildBody(PackageProvider provider) {
    if (provider.isLoading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF6366F1)));
    }
    if (provider.error.isNotEmpty) {
      return _buildErrorState(provider);
    }
    if (provider.packages.isEmpty) {
      return _buildEmptyState();
    }
    return RefreshIndicator(
      onRefresh: provider.fetchPackages,
      color: const Color(0xFF6366F1),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
        itemCount: provider.packages.length,
        itemBuilder: (_, i) => _buildPackageCard(provider.packages[i]),
      ),
    );
  }

  // ── package card ───────────────────────────────────────────────────────────

  Widget _buildPackageCard(Package pkg) {
    final cfg = _tierFor(pkg.name);
    final cardBg = Theme.of(context).colorScheme.surface;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cfg.ring),
        boxShadow: [
          BoxShadow(
              color: cfg.accent.withOpacity(0.08),
              blurRadius: 12,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header strip ──────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? cfg.accent.withOpacity(0.12) : cfg.bg,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              border: Border(bottom: BorderSide(color: cfg.ring)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: cfg.accent.withOpacity(0.12),
                    shape: BoxShape.circle,
                    border: Border.all(color: cfg.accent.withOpacity(0.30)),
                  ),
                  child: Icon(cfg.icon, color: cfg.accent, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(pkg.name,
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: cfg.accent,
                              letterSpacing: 0.3)),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(Icons.schedule_rounded,
                              size: 11, color: Colors.grey.shade500),
                          const SizedBox(width: 3),
                          Text(pkg.duration,
                              style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade600,
                                  fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ],
                  ),
                ),
                // ── Price badge ────────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [cfg.accent, cfg.accent.withOpacity(0.80)],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                          color: cfg.accent.withOpacity(0.35),
                          blurRadius: 8,
                          offset: const Offset(0, 3)),
                    ],
                  ),
                  child: Text(pkg.price,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          letterSpacing: 0.2)),
                ),
              ],
            ),
          ),

          // ── Description + actions ─────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.info_outline_rounded,
                              size: 12, color: Colors.grey.shade400),
                          const SizedBox(width: 4),
                          Text('Description',
                              style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey.shade400,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.4)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(pkg.description,
                          style: TextStyle(
                              fontSize: 13,
                              color: isDark ? Colors.grey.shade300 : const Color(0xFF475569),
                              height: 1.45),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 8),
                      // ── Meta chips ────────────────────────────────────────
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          _metaChip(
                              Icons.tag_rounded,
                              '#${pkg.id}',
                              const Color(0xFF6366F1)),
                          _metaChip(
                              Icons.calendar_today_rounded,
                              '${pkg.durationInMonths} months',
                              const Color(0xFF10B981)),
                          _metaChip(
                              Icons.currency_rupee_rounded,
                              pkg.numericPrice.toStringAsFixed(0),
                              const Color(0xFFF59E0B)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                // ── Action buttons ────────────────────────────────────────
                Row(
                  children: [
                    _actionBtn(
                        icon: Icons.edit_rounded,
                        tooltip: 'Edit',
                        color: const Color(0xFF6366F1),
                        onTap: () => _openEdit(pkg)),
                    const SizedBox(width: 6),
                    _actionBtn(
                        icon: Icons.delete_outline_rounded,
                        tooltip: 'Delete',
                        color: kRose,
                        onTap: () => _confirmDelete(pkg)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _metaChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.20)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 10, color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _actionBtn({
    required IconData icon,
    required String tooltip,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withOpacity(0.25)),
          ),
          child: Icon(icon, size: 16, color: color),
        ),
      ),
    );
  }

  // ── empty / error states ───────────────────────────────────────────────────

  Widget _buildEmptyState() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFEEF2FF),
              shape: BoxShape.circle,
              border: Border.all(color: isDark ? const Color(0xFF4F46E5).withOpacity(0.4) : const Color(0xFFE0E7FF)),
            ),
            child: const Icon(Icons.card_membership_rounded,
                size: 52, color: Color(0xFF6366F1)),
          ),
          const SizedBox(height: 20),
          Text('No Packages Found',
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF1E293B))),
          const SizedBox(height: 8),
          Text('Create your first membership package to get started',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _openCreate,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6366F1),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Create Package', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(PackageProvider provider) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded, size: 52, color: kRose),
            const SizedBox(height: 16),
            const Text('Failed to load packages',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(provider.error,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                textAlign: TextAlign.center),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () {
                provider.clearError();
                provider.fetchPackages();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  // ── side panel ─────────────────────────────────────────────────────────────

  Widget _buildSidePanel(PackageProvider provider) {
    final isEdit = _editingPkg != null;
    final panelBg = Theme.of(context).colorScheme.surface;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      elevation: 24,
      shadowColor: Colors.black26,
      borderRadius: const BorderRadius.horizontal(left: Radius.circular(20)),
      child: Container(
        decoration: BoxDecoration(
          color: panelBg,
          borderRadius: const BorderRadius.horizontal(left: Radius.circular(20)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Panel header
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF4F46E5), Color(0xFF6366F1)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.only(topLeft: Radius.circular(20)),
              ),
              child: Row(
                children: [
                  Icon(
                    isEdit ? Icons.edit_rounded : Icons.add_circle_outline_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      isEdit ? 'Edit Package' : 'Create New Package',
                      style: const TextStyle(
                          color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                    onPressed: _closePanel,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  ),
                ],
              ),
            ),

            // Form
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (isEdit) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFEEF2FF),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: isDark ? const Color(0xFF4F46E5).withOpacity(0.4) : const Color(0xFFE0E7FF)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.info_outline_rounded,
                                  size: 14, color: Color(0xFF6366F1)),
                              const SizedBox(width: 8),
                              Text('Editing package ID: ${_editingPkg!.id}',
                                  style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF6366F1),
                                      fontWeight: FontWeight.w500)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      _panelField(
                        controller: _nameCtrl,
                        label: 'Package Name',
                        hint: 'e.g. Diamond, Gold, Silver…',
                        icon: Icons.badge_rounded,
                        isDark: isDark,
                        validator: (v) => (v == null || v.isEmpty)
                            ? 'Package name is required'
                            : null,
                      ),
                      const SizedBox(height: 14),

                      _panelField(
                        controller: _durationCtrl,
                        label: 'Duration (Months)',
                        hint: 'e.g. 1, 3, 6, 12',
                        icon: Icons.calendar_today_rounded,
                        suffixText: 'months',
                        isDark: isDark,
                        inputType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Duration is required';
                          if (int.tryParse(v) == null) return 'Enter a valid number';
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),

                      _panelField(
                        controller: _priceCtrl,
                        label: 'Price',
                        hint: 'e.g. 299.00',
                        icon: Icons.currency_rupee_rounded,
                        prefixText: 'Rs ',
                        isDark: isDark,
                        inputType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))
                        ],
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Price is required';
                          if (double.tryParse(v) == null) return 'Enter a valid price';
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),

                      _panelField(
                        controller: _descCtrl,
                        label: 'Description',
                        hint: 'Describe what this package includes…',
                        icon: Icons.description_rounded,
                        maxLines: 4,
                        isDark: isDark,
                        validator: (v) => (v == null || v.isEmpty)
                            ? 'Description is required'
                            : null,
                      ),
                      const SizedBox(height: 24),

                      // Actions
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _closePanel,
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 13),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10)),
                                side: BorderSide(color: isDark ? Colors.white.withOpacity(0.20) : Colors.grey.shade300),
                              ),
                              child: const Text('Cancel',
                                  style: TextStyle(fontWeight: FontWeight.w600)),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 2,
                            child: ElevatedButton(
                              onPressed: provider.isLoading ? null : _handleSave,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF6366F1),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 13),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10)),
                                elevation: 0,
                              ),
                              child: provider.isLoading
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2, color: Colors.white))
                                  : Text(
                                      isEdit ? 'Update Package' : 'Create Package',
                                      style: const TextStyle(fontWeight: FontWeight.w700)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _panelField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    String? suffixText,
    String? prefixText,
    TextInputType? inputType,
    List<TextInputFormatter>? inputFormatters,
    int? maxLines,
    String? Function(String?)? validator,
    bool isDark = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.grey.shade300 : const Color(0xFF374151))),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: inputType,
          inputFormatters: inputFormatters,
          maxLines: maxLines ?? 1,
          validator: validator,
          style: TextStyle(fontSize: 14, color: isDark ? Colors.white : const Color(0xFF1E293B)),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
            prefixIcon: Icon(icon, size: 16, color: Colors.grey.shade400),
            suffixText: suffixText,
            prefixText: prefixText,
            prefixStyle: TextStyle(
                fontSize: 14, color: isDark ? Colors.white : const Color(0xFF1E293B), fontWeight: FontWeight.w500),
            filled: true,
            fillColor: isDark ? const Color(0xFF263248) : const Color(0xFFF8FAFC),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: isDark ? Colors.white.withOpacity(0.10) : Colors.grey.shade200)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: isDark ? Colors.white.withOpacity(0.10) : Colors.grey.shade200)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFF6366F1), width: 1.5)),
            errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: kRose)),
          ),
        ),
      ],
    );
  }
}
