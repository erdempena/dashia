import 'package:flutter/material.dart';
import '../../../../core/theme/dashia_colors.dart';
import '../../../apps/services/app_launcher_service.dart';
import '../../../settings/settings_service.dart';
import 'app_icon.dart';
import 'shortcut_editor.dart';

/// Alt kısayol çubuğu: 0–6 kısayol. Sabit boyutlu kutular, doldurmak zorunda değilsiniz.
/// Dokun: aç · Basılı tut: düzenle · Boş alana basılı tut: yeni kısayol ekle.
class QuickAppsBar extends StatelessWidget {
  final SettingsService settings;
  final AppLauncherService apps;
  final VoidCallback onOpenDrawer;
  final VoidCallback onOpenSettings;
  const QuickAppsBar({super.key, required this.settings, required this.apps, required this.onOpenDrawer, required this.onOpenSettings});

  Future<void> _launch(BuildContext context, ShortcutConfig s) async {
    final messenger = ScaffoldMessenger.of(context);
    if (s.package == null) {
      await showShortcutEditor(context, settings: settings, apps: apps, existing: s);
      return;
    }
    final ok = await apps.launch(s.package!);
    if (!ok) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('"${s.label}" açılamadı. Uygulama yüklü olmayabilir — basılı tutup değiştirin.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tr = settings.tr;
    final list = settings.shortcuts;
    return SizedBox(
      height: settings.barHeight,
      child: LayoutBuilder(builder: (context, box) {
        const gap = 10.0;
        // En çok 6 kısayol + Uygulamalar + Ayarlar = 8 eşit kutu
        final w = (box.maxWidth - gap * 7) / 8;
        Widget sized(Widget child) => SizedBox(width: w, height: double.infinity, child: child);
        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onLongPress: list.length < SettingsService.maxShortcuts ? () => showShortcutEditor(context, settings: settings, apps: apps) : null,
          child: Row(children: [
            for (final s in list) ...[
              sized(_Tile(
                label: s.label,
                icon: ShortcutIcon(apps: apps, shortcut: s, size: settings.barHeight * 0.42),
                onTap: () => _launch(context, s),
                onLongPress: () => showShortcutEditor(context, settings: settings, apps: apps, existing: s),
              )),
              const SizedBox(width: gap),
            ],
            const Spacer(),
            sized(_Tile(label: tr.allApps, accent: true, icon: Icon(Icons.apps_rounded, size: settings.barHeight * 0.42, color: c.accent), onTap: onOpenDrawer)),
            const SizedBox(width: gap),
            sized(_Tile(label: tr.settings, accent: true, icon: Icon(Icons.tune_rounded, size: settings.barHeight * 0.42, color: c.accent), onTap: onOpenSettings)),
          ]),
        );
      }),
    );
  }
}

class _Tile extends StatelessWidget {
  final String label;
  final Widget icon;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool accent;
  const _Tile({required this.label, required this.icon, required this.onTap, this.onLongPress, this.accent = false});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final fill = accent ? (c.material ? c.accent.withValues(alpha: 0.18) : c.surfaceAlt) : c.surface;
    return Material(
      color: fill,
      borderRadius: BorderRadius.circular(c.radius),
      child: InkWell(
        borderRadius: BorderRadius.circular(c.radius),
        onTap: onTap,
        onLongPress: onLongPress,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(c.radius),
            border: Border.all(color: c.material ? Colors.transparent : (accent ? c.accent : c.border)),
          ),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            icon,
            const SizedBox(height: 3),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: accent ? c.accent : c.textMuted)),
            ),
          ]),
        ),
      ),
    );
  }
}

/// Yüklü tüm uygulamaların listelendiği çekmece.
Future<void> showAppDrawer(BuildContext context, {required AppLauncherService apps}) {
  return showDialog<void>(context: context, builder: (_) => _AppDrawer(apps: apps));
}

class _AppDrawer extends StatelessWidget {
  final AppLauncherService apps;
  const _AppDrawer({required this.apps});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final size = MediaQuery.of(context).size;
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: SizedBox(
        width: size.width,
        height: size.height * 0.92,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            Row(children: [
              const Expanded(child: Text('Tüm Uygulamalar', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700))),
              IconButton(icon: const Icon(Icons.close_rounded, size: 30), onPressed: () => Navigator.pop(context)),
            ]),
            const SizedBox(height: 8),
            Expanded(
              child: FutureBuilder<List<AppInfo>>(
                future: apps.installedApps(),
                builder: (context, snap) {
                  if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                  final list = snap.data!;
                  return GridView.builder(
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 130, mainAxisExtent: 104, crossAxisSpacing: 10, mainAxisSpacing: 10),
                    itemCount: list.length,
                    itemBuilder: (context, i) {
                      final a = list[i];
                      return InkWell(
                        borderRadius: BorderRadius.circular(c.radius),
                        onTap: () {
                          Navigator.pop(context);
                          apps.launch(a.package);
                        },
                        child: Container(
                          decoration: c.card(color: c.material ? c.surfaceAlt : null),
                          padding: const EdgeInsets.all(6),
                          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                            AppIcon(apps: apps, package: a.package, size: 44),
                            const SizedBox(height: 6),
                            Text(a.label, maxLines: 2, textAlign: TextAlign.center, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
                          ]),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
