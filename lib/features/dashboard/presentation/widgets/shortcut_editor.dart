import 'dart:io';
import 'package:flutter/material.dart';
import '../../../../core/icon_registry.dart';
import '../../../../core/theme/dashia_colors.dart';
import '../../../apps/services/app_launcher_service.dart';
import '../../../settings/settings_service.dart';
import 'app_icon.dart';

/// Kısayol düzenleme penceresi: İkon | İsim | Uygulama sekmeleri.
Future<void> showShortcutEditor(
  BuildContext context, {
  required SettingsService settings,
  required AppLauncherService apps,
  ShortcutConfig? existing,
}) {
  return showDialog<void>(
    context: context,
    builder: (_) => _ShortcutEditor(settings: settings, apps: apps, existing: existing),
  );
}

class _ShortcutEditor extends StatefulWidget {
  final SettingsService settings;
  final AppLauncherService apps;
  final ShortcutConfig? existing;
  const _ShortcutEditor({required this.settings, required this.apps, this.existing});

  @override
  State<_ShortcutEditor> createState() => _ShortcutEditorState();
}

class _ShortcutEditorState extends State<_ShortcutEditor> with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 3, vsync: this);
  late final TextEditingController _label = TextEditingController(text: widget.existing?.label ?? '');
  late String _iconKey = widget.existing?.iconKey ?? 'apps';
  late String? _package = widget.existing?.package;
  String _query = '';
  List<AppInfo> _all = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    widget.apps.installedApps().then((v) {
      if (mounted) {
        setState(() {
          _all = v;
          _loading = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    _label.dispose();
    super.dispose();
  }

  ShortcutConfig get _draft => ShortcutConfig(
        id: widget.existing?.id ?? widget.settings.newShortcutId(),
        label: _label.text.trim().isEmpty ? 'Uygulama' : _label.text.trim(),
        iconKey: _iconKey,
        package: _package,
      );

  Future<void> _pickCustomGalleryIcon() async {
    final path = await widget.apps.pickCustomIcon();
    if (path != null && path.isNotEmpty && mounted) {
      setState(() => _iconKey = 'file:$path');
    }
  }

  void _save() {
    widget.settings.saveShortcut(_draft);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final size = MediaQuery.of(context).size;
    final selectedApp = _all.where((a) => a.package == _package).firstOrNull;
    final isCustomFile = _iconKey.startsWith('file:');

    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 760, maxHeight: size.height * 0.92),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              Container(
                width: 64,
                height: 64,
                decoration: c.card(color: c.surfaceAlt),
                child: Center(child: ShortcutIcon(apps: widget.apps, shortcut: _draft, size: 36)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(_draft.label, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                  Text(selectedApp?.label ?? _package ?? 'Uygulama seçilmedi', style: TextStyle(color: c.textMuted)),
                ]),
              ),
              if (widget.existing != null)
                IconButton(
                  tooltip: 'Kısayolu sil',
                  icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                  onPressed: () {
                    widget.settings.removeShortcut(widget.existing!.id);
                    Navigator.pop(context);
                  },
                ),
            ]),
            TabBar(controller: _tabs, tabs: const [
              Tab(icon: Icon(Icons.emoji_objects_outlined), text: 'İkon'),
              Tab(icon: Icon(Icons.edit_outlined), text: 'İsim'),
              Tab(icon: Icon(Icons.apps_rounded), text: 'Uygulama'),
            ]),
            Flexible(
              child: SizedBox(
                height: 300,
                child: TabBarView(controller: _tabs, children: [
                  // İKON
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 10, bottom: 8),
                        child: Row(
                          children: [
                            FilledButton.tonalIcon(
                              onPressed: _pickCustomGalleryIcon,
                              icon: const Icon(Icons.add_photo_alternate_rounded, size: 20),
                              label: Text(isCustomFile ? 'Galeriden Başka Simge Seç' : 'Galeriden Özel Simge Seç'),
                            ),
                            if (isCustomFile) ...[
                              const SizedBox(width: 10),
                              Text('Özel simge seçildi', style: TextStyle(fontSize: 13, color: c.accent, fontWeight: FontWeight.w600)),
                            ],
                          ],
                        ),
                      ),
                      Expanded(
                        child: GridView.count(
                          padding: const EdgeInsets.only(top: 4),
                          crossAxisCount: 8,
                          mainAxisSpacing: 8,
                          crossAxisSpacing: 8,
                          children: [
                            if (isCustomFile)
                              _IconTile(
                                selected: true,
                                onTap: _pickCustomGalleryIcon,
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.file(
                                    File(_iconKey.substring(5)),
                                    width: 34,
                                    height: 34,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_rounded, size: 28),
                                  ),
                                ),
                              ),
                            if (_package != null)
                              _IconTile(
                                selected: _iconKey == 'app',
                                onTap: () => setState(() => _iconKey = 'app'),
                                child: AppIcon(apps: widget.apps, package: _package, size: 32),
                              ),
                            for (final e in IconRegistry.icons.entries)
                              _IconTile(
                                selected: _iconKey == e.key,
                                onTap: () => setState(() => _iconKey = e.key),
                                child: Icon(e.value, size: 30),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  // İSİM
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: TextField(
                        controller: _label,
                        maxLength: 14,
                        style: const TextStyle(fontSize: 20),
                        decoration: const InputDecoration(labelText: 'Kısayol adı'),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                  ),
                  // UYGULAMA
                  Column(children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 10, bottom: 6),
                      child: TextField(
                        decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Uygulama ara', isDense: true),
                        onChanged: (v) => setState(() => _query = v.toLowerCase()),
                      ),
                    ),
                    Expanded(
                      child: _loading
                          ? const Center(child: CircularProgressIndicator())
                          : Builder(builder: (context) {
                              final list = _all.where((a) => a.label.toLowerCase().contains(_query) || a.package.contains(_query)).toList();
                              return ListView.builder(
                                itemCount: list.length,
                                itemExtent: 56,
                                itemBuilder: (context, i) {
                                  final a = list[i];
                                  return ListTile(
                                    dense: true,
                                    selected: a.package == _package,
                                    selectedTileColor: c.accent.withValues(alpha: 0.15),
                                    leading: AppIcon(apps: widget.apps, package: a.package, size: 34),
                                    title: Text(a.label, maxLines: 1, overflow: TextOverflow.ellipsis),
                                    subtitle: Text(a.package, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, color: c.textMuted)),
                                    onTap: () => setState(() {
                                      final oldApp = selectedApp;
                                      final auto = _label.text.trim().isEmpty || _label.text.trim() == (oldApp?.label ?? '') || _label.text.trim() == 'Uygulama';
                                      _package = a.package;
                                      if (auto) _label.text = a.label.length > 14 ? a.label.substring(0, 14) : a.label;
                                    }),
                                  );
                                },
                              );
                            }),
                    ),
                  ]),
                ]),
              ),
            ),
            const SizedBox(height: 8),
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('İptal')),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.check_rounded),
                label: const Text('Kaydet'),
              ),
            ]),
          ]),
        ),
      ),
    );
  }
}

class _IconTile extends StatelessWidget {
  final bool selected;
  final VoidCallback onTap;
  final Widget child;
  const _IconTile({required this.selected, required this.onTap, required this.child});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return InkWell(
      borderRadius: BorderRadius.circular(c.radius),
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: selected ? c.accent.withValues(alpha: 0.2) : c.surfaceAlt,
          borderRadius: BorderRadius.circular(c.radius),
          border: Border.all(color: selected ? c.accent : Colors.transparent, width: 2),
        ),
        child: Center(child: child),
      ),
    );
  }
}
