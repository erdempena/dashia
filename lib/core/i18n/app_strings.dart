/// 6 dilli yerelleştirme sözlüğü: Türkçe (tr), İngilizce (en), Almanca (de),
/// Fransızca (fr), İspanyolca (es) ve Rusça (ru).
class AppLanguage {
  final String code;
  final String nativeName;
  final String flag;
  const AppLanguage(this.code, this.nativeName, this.flag);

  static const all = <AppLanguage>[
    AppLanguage('tr', 'Türkçe', '🇹🇷'),
    AppLanguage('en', 'English', '🇬🇧'),
    AppLanguage('de', 'Deutsch', '🇩🇪'),
    AppLanguage('fr', 'Français', '🇫🇷'),
    AppLanguage('es', 'Español', '🇪🇸'),
    AppLanguage('ru', 'Русский', '🇷🇺'),
  ];
}

class AppStrings {
  final String lang;
  const AppStrings(this.lang);

  String _t(Map<String, String> m) => m[lang] ?? m['en'] ?? m['tr']!;

  // --- Genel & Navigasyon ---
  String get settings => _t({'tr': 'Ayarlar', 'en': 'Settings', 'de': 'Einstellungen', 'fr': 'Paramètres', 'es': 'Ajustes', 'ru': 'Настройки'});
  String get allApps => _t({'tr': 'Uygulamalar', 'en': 'Apps', 'de': 'Apps', 'fr': 'Applications', 'es': 'Aplicaciones', 'ru': 'Приложения'});
  String get allAppsTitle => _t({'tr': 'Tüm Uygulamalar', 'en': 'All Applications', 'de': 'Alle Apps', 'fr': 'Toutes les applications', 'es': 'Todas las aplicaciones', 'ru': 'Все приложения'});
  String get cancel => _t({'tr': 'İptal', 'en': 'Cancel', 'de': 'Abbrechen', 'fr': 'Annuler', 'es': 'Cancelar', 'ru': 'Отмена'});
  String get save => _t({'tr': 'Kaydet', 'en': 'Save', 'de': 'Speichern', 'fr': 'Enregistrer', 'es': 'Guardar', 'ru': 'Сохранить'});
  String get apply => _t({'tr': 'Uygula', 'en': 'Apply', 'de': 'Anwenden', 'fr': 'Appliquer', 'es': 'Aplicar', 'ru': 'Применить'});
  String get open => _t({'tr': 'Aç', 'en': 'Open', 'de': 'Öffnen', 'fr': 'Ouvrir', 'es': 'Abrir', 'ru': 'Открыть'});

  // --- Ayarlar Sekmeleri ---
  List<String> get settingsTabs => [
        _t({'tr': 'Görünüm', 'en': 'Appearance', 'de': 'Darstellung', 'fr': 'Apparence', 'es': 'Apariencia', 'ru': 'Внешний вид'}),
        _t({'tr': 'Harita', 'en': 'Map', 'de': 'Karte', 'fr': 'Carte', 'es': 'Mapa', 'ru': 'Карта'}),
        _t({'tr': 'Saat & Hız', 'en': 'Clock & Speed', 'de': 'Uhr & Tempo', 'fr': 'Horloge & Vitesse', 'es': 'Reloj y Velocidad', 'ru': 'Часы и скорость'}),
        _t({'tr': 'Medya', 'en': 'Media', 'de': 'Medien', 'fr': 'Médias', 'es': 'Multimedia', 'ru': 'Медиа'}),
        _t({'tr': 'Kısayollar & Düzen', 'en': 'Shortcuts & Layout', 'de': 'Kürzel & Layout', 'fr': 'Raccourcis & Disposition', 'es': 'Accesos y Diseño', 'ru': 'Ярлыки и макет'}),
        _t({'tr': 'Sistem', 'en': 'System', 'de': 'System', 'fr': 'Système', 'es': 'Sistema', 'ru': 'Система'}),
      ];

  // --- Bileşen Başlıkları ---
  String widgetTitle(String name) => switch (name) {
        'clock' => _t({'tr': 'Saat & Tarih', 'en': 'Clock & Date', 'de': 'Uhr & Datum', 'fr': 'Horloge & Date', 'es': 'Reloj y Fecha', 'ru': 'Часы и дата'}),
        'speed' => _t({'tr': 'Hız Göstergesi', 'en': 'Speedometer', 'de': 'Tachometer', 'fr': 'Compteur', 'es': 'Velocímetro', 'ru': 'Спидометр'}),
        'media' => _t({'tr': 'Müzik Kontrol', 'en': 'Media Player', 'de': 'Mediensteuerung', 'fr': 'Lecteur média', 'es': 'Control de música', 'ru': 'Плеер'}),
        'map' => _t({'tr': 'Harita', 'en': 'Map', 'de': 'Karte', 'fr': 'Carte', 'es': 'Mapa', 'ru': 'Карта'}),
        _ => _t({'tr': 'Boş', 'en': 'Empty', 'de': 'Leer', 'fr': 'Vide', 'es': 'Vacío', 'ru': 'Пусто'}),
      };

  String widgetDesc(String name) => switch (name) {
        'clock' => _t({'tr': 'Dijital saat ve tarih', 'en': 'Digital clock and date', 'de': 'Digitaluhr und Datum', 'fr': 'Horloge numérique et date', 'es': 'Reloj digital y fecha', 'ru': 'Цифровые часы и дата'}),
        'speed' => _t({'tr': 'GPS tabanlı anlık hız kadranı', 'en': 'GPS live speedometer gauge', 'de': 'GPS-Geschwindigkeitsanzeige', 'fr': 'Vitesse GPS en temps réel', 'es': 'Velocímetro GPS en tiempo real', 'ru': 'GPS-спидометр'}),
        'media' => _t({'tr': 'Çalan parça ve oynatma kontrolleri', 'en': 'Now playing and playback controls', 'de': 'Wiedergabe und Steuerung', 'fr': 'Lecture en cours et commandes', 'es': 'Reproducción y controles', 'ru': 'Текущий трек и управление'}),
        'map' => _t({'tr': 'Anlık konum (OpenStreetMap / Google)', 'en': 'Live location (OpenStreetMap / Google)', 'de': 'Live-Standort (OpenStreetMap / Google)', 'fr': 'Position en direct (OSM / Google)', 'es': 'Ubicación en vivo (OSM / Google)', 'ru': 'Геолокация (OSM / Google)'}),
        _ => _t({'tr': 'Bu alanı gizle, diğerleri genişlesin', 'en': 'Hide this slot and expand others', 'de': 'Bereich ausblenden', 'fr': 'Masquer cet emplacement', 'es': 'Ocultar este espacio', 'ru': 'Скрыть эту область'}),
      };

  // --- Saat & Tarih (Günler ve Aylar) ---
  List<String> get weekdays => switch (lang) {
        'en' => const ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'],
        'de' => const ['Montag', 'Dienstag', 'Mittwoch', 'Donnerstag', 'Freitag', 'Samstag', 'Sonntag'],
        'fr' => const ['Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi', 'Dimanche'],
        'es' => const ['Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'],
        'ru' => const ['Понедельник', 'Вторник', 'Среда', 'Четверг', 'Пятница', 'Суббота', 'Воскресенье'],
        _ => const ['Pazartesi', 'Salı', 'Çarşamba', 'Perşembe', 'Cuma', 'Cumartesi', 'Pazar'],
      };

  List<String> get months => switch (lang) {
        'en' => const ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'],
        'de' => const ['Januar', 'Februar', 'März', 'April', 'Mai', 'Juni', 'Juli', 'August', 'September', 'Oktober', 'November', 'Dezember'],
        'fr' => const ['Janvier', 'Février', 'Mars', 'Avril', 'Mai', 'Juin', 'Juillet', 'Août', 'Septembre', 'Octobre', 'Novembre', 'Décembre'],
        'es' => const ['Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio', 'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'],
        'ru' => const ['Января', 'Февраля', 'Марта', 'Апреля', 'Мая', 'Июня', 'Июля', 'Августа', 'Сентября', 'Октября', 'Ноября', 'Декабря'],
        _ => const ['Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran', 'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık'],
      };

  // --- Görünüm Sekmesi ---
  String get uiStyleTitle => _t({'tr': 'Arayüz stili', 'en': 'UI Style', 'de': 'Oberflächenstil', 'fr': 'Style d\'interface', 'es': 'Estilo de interfaz', 'ru': 'Стиль интерфейса'});
  String get uiStyleSub => _t({
        'tr': 'Material: Material 3 tonal renkler, çerçevesiz yuvarlak kartlar; renkler vurgu renginden üretilir.',
        'en': 'Material: Material 3 tonal surfaces and borderless rounded cards generated from accent color.',
        'de': 'Material: Material 3 Tonal-Design und rahmenlose abgerundete Karten.',
        'fr': 'Material : surfaces tonales Material 3 et cartes arrondies sans bordure.',
        'es': 'Material: colores tonales Material 3 y tarjetas redondeadas sin bordes.',
        'ru': 'Material: тональные цвета Material 3 и карточки без рамок.',
      });
  String get styleClassic => _t({'tr': 'Klasik', 'en': 'Classic', 'de': 'Klassisch', 'fr': 'Classique', 'es': 'Clásico', 'ru': 'Классика'});
  String get themeTitle => _t({'tr': 'Tema', 'en': 'Theme', 'de': 'Thema', 'fr': 'Thème', 'es': 'Tema', 'ru': 'Тема'});
  String get themeDark => _t({'tr': 'Koyu', 'en': 'Dark', 'de': 'Dunkel', 'fr': 'Sombre', 'es': 'Oscuro', 'ru': 'Тёмная'});
  String get themeLight => _t({'tr': 'Açık', 'en': 'Light', 'de': 'Hell', 'fr': 'Clair', 'es': 'Claro', 'ru': 'Светлая'});
  String get accentColor => _t({'tr': 'Vurgu rengi', 'en': 'Accent color', 'de': 'Akzentfarbe', 'fr': 'Couleur d\'accent', 'es': 'Color de acento', 'ru': 'Акцентный цвет'});
  String get customHexLabel => _t({'tr': 'Özel renk kodu (HEX)', 'en': 'Custom color (HEX)', 'de': 'Eigene Farbe (HEX)', 'fr': 'Couleur HEX', 'es': 'Color personalizado (HEX)', 'ru': 'Свой цвет (HEX)'});
  String get cornerRadius => _t({'tr': 'Köşe yuvarlaklığı', 'en': 'Corner radius', 'de': 'Eckenradius', 'fr': 'Rayon des coins', 'es': 'Radio de esquinas', 'ru': 'Скругление углов'});
  String get fontFamilyTitle => _t({'tr': 'Yazı tipi', 'en': 'Font family', 'de': 'Schriftart', 'fr': 'Police d\'écriture', 'es': 'Fuente', 'ru': 'Шрифт'});
  String get uploadFontBtn => _t({'tr': 'Font Yükle (.ttf / .otf)', 'en': 'Load Font (.ttf / .otf)', 'de': 'Schrift laden (.ttf / .otf)', 'fr': 'Charger police (.ttf / .otf)', 'es': 'Cargar fuente (.ttf / .otf)', 'ru': 'Загрузить шрифт (.ttf / .otf)'});
  String get fontSizeTitle => _t({'tr': 'Yazı boyutu', 'en': 'Text scale', 'de': 'Schriftgröße', 'fr': 'Taille du texte', 'es': 'Tamaño de texto', 'ru': 'Размер шрифта'});
  String get fullscreenTitle => _t({'tr': 'Tam ekran (sistem çubuklarını gizle)', 'en': 'Fullscreen (hide system bars)', 'de': 'Vollbild (Systemleisten ausblenden)', 'fr': 'Plein écran (masquer les barres)', 'es': 'Pantalla completa', 'ru': 'Полный экран'});
  String get fullscreenSub => _t({'tr': 'Araç ünitelerinde önerilir.', 'en': 'Recommended for car head units.', 'de': 'Empfohlen für Autoradios.', 'fr': 'Recommandé pour les écrans auto.', 'es': 'Recomendado para pantallas de coche.', 'ru': 'Рекомендуется для автомагнитол.'});

  // --- Saat & Hız Sekmesi ---
  String get format24h => _t({'tr': '24 saat formatı', 'en': '24-hour format', 'de': '24-Stunden-Format', 'fr': 'Format 24 heures', 'es': 'Formato de 24 horas', 'ru': '24-часовой формат'});
  String get showSeconds => _t({'tr': 'Saniyeyi göster', 'en': 'Show seconds', 'de': 'Sekunden anzeigen', 'fr': 'Afficher les secondes', 'es': 'Mostrar segundos', 'ru': 'Показывать секунды'});
  String get showDate => _t({'tr': 'Tarihi göster', 'en': 'Show date', 'de': 'Datum anzeigen', 'fr': 'Afficher la date', 'es': 'Mostrar fecha', 'ru': 'Показывать дату'});
  String get speedUnit => _t({'tr': 'Hız birimi', 'en': 'Speed unit', 'de': 'Geschwindigkeitseinheit', 'fr': 'Unité de vitesse', 'es': 'Unidad de velocidad', 'ru': 'Единица скорости'});
  String get maxDialSpeed => _t({'tr': 'Kadran maksimum hızı', 'en': 'Max dial speed', 'de': 'Max. Tachogeschwindigkeit', 'fr': 'Vitesse max du cadran', 'es': 'Velocidad máx. del dial', 'ru': 'Макс. скорость шкалы'});

  // --- Medya ---
  String get showAlbumArt => _t({'tr': 'Albüm kapağını göster', 'en': 'Show album cover', 'de': 'Albumcover anzeigen', 'fr': 'Afficher la pochette', 'es': 'Mostrar carátula', 'ru': 'Показывать обложку'});
  String get notifAccess => _t({'tr': 'Bildirim erişimi', 'en': 'Notification access', 'de': 'Benachrichtigungszugriff', 'fr': 'Accès aux notifications', 'es': 'Acceso a notificaciones', 'ru': 'Доступ к уведомлениям'});
  String get notifGrantedSub => _t({
        'tr': 'Verildi. Spotify, YouTube Music, radyo vb. çalan parça okunabilir.',
        'en': 'Granted. Active tracks from Spotify, YouTube Music, radio, etc. can be read.',
        'de': 'Erteilt. Aktuelle Titel von Spotify, YouTube Music, Radio usw. werden erkannt.',
        'fr': 'Accordé. Les titres Spotify, YouTube Music, radio, etc. sont détectés.',
        'es': 'Concedido. Se puede leer la música de Spotify, YouTube Music, radio, etc.',
        'ru': 'Разрешено. Чтение треков из Spotify, YouTube Music, радио и др.',
      });
  String get notifMissingSub => _t({
        'tr': 'Çalan müziği okumak için Dashia\'ya "Bildirim erişimi" izni verin.',
        'en': 'Grant Notification Access to Dashia to display now playing media.',
        'de': 'Benachrichtigungszugriff gewähren, um aktuelle Musik anzuzeigen.',
        'fr': 'Autorisez l\'accès aux notifications pour afficher la musique en cours.',
        'es': 'Concede acceso a notificaciones para mostrar la música en reproducción.',
        'ru': 'Предоставьте доступ к уведомлениям для отображения текущей музыки.',
      });
  String get grantPermission => _t({'tr': 'İzin ver', 'en': 'Grant access', 'de': 'Erlauben', 'fr': 'Autoriser', 'es': 'Permitir', 'ru': 'Разрешить'});
  String get openSettingsBtn => _t({'tr': 'Ayarları aç', 'en': 'Open settings', 'de': 'Einstellungen', 'fr': 'Ouvrir paramètres', 'es': 'Abrir ajustes', 'ru': 'Открыть настройки'});
  String get refreshStatus => _t({'tr': 'Durumu yenile', 'en': 'Refresh status', 'de': 'Status aktualisieren', 'fr': 'Actualiser l\'état', 'es': 'Actualizar estado', 'ru': 'Обновить статус'});
  String get grantNotifBtn => _t({'tr': 'Bildirim erişimi ver', 'en': 'Grant notification access', 'de': 'Zugriff gewähren', 'fr': 'Autoriser les notifications', 'es': 'Dar acceso a notificaciones', 'ru': 'Дать доступ к уведомлениям'});
  String get waitingMediaTitle => _t({'tr': 'Müzik bekleniyor', 'en': 'Waiting for media', 'de': 'Warte auf Medien', 'fr': 'En attente de média', 'es': 'Esperando música', 'ru': 'Ожидание музыки'});
  String get waitingMediaArtist => _t({'tr': 'Bir medya oynatıcı başlatın', 'en': 'Start a media player', 'de': 'Mediaplayer starten', 'fr': 'Lancez un lecteur audio', 'es': 'Inicia un reproductor', 'ru': 'Запустите плеер'});

  // --- Kısayollar & Düzen ---
  String get layoutHint => _t({
        'tr': 'Ana ekranda bir alana veya kısayola basılı tutarak da düzenleyebilirsiniz.',
        'en': 'Long-press any dashboard slot or shortcut on the home screen to customize.',
        'de': 'Halten Sie ein Element auf dem Startbildschirm gedrückt, um es anzupassen.',
        'fr': 'Appuyez longuement sur un élément de l\'écran d\'accueil pour le modifier.',
        'es': 'Mantén pulsado cualquier elemento en la pantalla principal para editarlo.',
        'ru': 'Удерживайте любой элемент на главном экране для настройки.',
      });
  String get screenLayout => _t({'tr': 'Ekran düzeni', 'en': 'Screen layout', 'de': 'Bildschirmlayout', 'fr': 'Disposition de l\'écran', 'es': 'Diseño de pantalla', 'ru': 'Макет экрана'});
  String get slotTopLeft => _t({'tr': 'Sol üst', 'en': 'Top left', 'de': 'Oben links', 'fr': 'Haut gauche', 'es': 'Arriba izquierda', 'ru': 'Слева сверху'});
  String get slotBottomLeft => _t({'tr': 'Sol alt', 'en': 'Bottom left', 'de': 'Unten links', 'fr': 'Bas gauche', 'es': 'Abajo izquierda', 'ru': 'Слева снизу'});
  String get slotRightMain => _t({'tr': 'Sağ ana alan', 'en': 'Right main area', 'de': 'Rechter Hauptbereich', 'fr': 'Zone principale droite', 'es': 'Área principal derecha', 'ru': 'Правая основная панель'});
  String get showResizeHandlesTitle => _t({'tr': 'Ana ekranda boyutlandırma çubuklarını göster', 'en': 'Show resize handles on home screen', 'de': 'Größenregler auf Startbildschirm anzeigen', 'fr': 'Afficher les poignées de redimensionnement', 'es': 'Mostrar barras de tamaño en inicio', 'ru': 'Показывать ползунки размера на экране'});
  String get showResizeHandlesSub => _t({'tr': 'Yanlışlıkla dokunarak boyut değiştirmeyi önlemek için kapatabilirsiniz.', 'en': 'Disable to lock layout sizes and prevent accidental touches.', 'de': 'Deaktivieren, um versehentliche Größenänderungen zu verhindern.', 'fr': 'Désactivez pour éviter tout redimensionnement accidentel.', 'es': 'Desactívalo para evitar cambios de tamaño accidentales.', 'ru': 'Отключите, чтобы случайно не изменить размер панелей.'});
  String get leftColWidth => _t({'tr': 'Sol sütun genişliği', 'en': 'Left column width', 'de': 'Breite linke Spalte', 'fr': 'Largeur colonne gauche', 'es': 'Ancho columna izquierda', 'ru': 'Ширина левой колонки'});
  String get leftTopHeight => _t({'tr': 'Sol üst alan yüksekliği', 'en': 'Top-left slot height', 'de': 'Höhe oben links', 'fr': 'Hauteur haut gauche', 'es': 'Altura superior izquierda', 'ru': 'Высота верхнего блока'});
  String get bottomBarHeight => _t({'tr': 'Alt çubuk yüksekliği', 'en': 'Bottom bar height', 'de': 'Höhe untere Leiste', 'fr': 'Hauteur barre inférieure', 'es': 'Altura barra inferior', 'ru': 'Высота нижней панели'});
  String get resetLayoutBtn => _t({'tr': 'Düzeni ve boyutları sıfırla', 'en': 'Reset layout & sizes', 'de': 'Layout zurücksetzen', 'fr': 'Réinitialiser la disposition', 'es': 'Restablecer diseño', 'ru': 'Сбросить макет и размеры'});
  String get shortcutsTitle => _t({'tr': 'Kısayollar', 'en': 'Shortcuts', 'de': 'Kürzel', 'fr': 'Raccourcis', 'es': 'Accesos directos', 'ru': 'Ярлыки'});
  String get addShortcutBtn => _t({'tr': 'Kısayol ekle', 'en': 'Add shortcut', 'de': 'Hinzufügen', 'fr': 'Ajouter', 'es': 'Añadir acceso', 'ru': 'Добавить ярлык'});
  String get resetShortcutsBtn => _t({'tr': 'Kısayolları sıfırla', 'en': 'Reset shortcuts', 'de': 'Kürzel zurücksetzen', 'fr': 'Réinitialiser les raccourcis', 'es': 'Restablecer accesos', 'ru': 'Сбросить ярлыки'});

  // --- Sistem Sekmesi ---
  String get languageTitle => _t({'tr': 'Uygulama dili', 'en': 'App language', 'de': 'App-Sprache', 'fr': 'Langue de l\'application', 'es': 'Idioma de la aplicación', 'ru': 'Язык приложения'});
  String get languageSub => _t({'tr': 'Arayüz dilini seçin.', 'en': 'Select interface language.', 'de': 'Sprache der Benutzeroberfläche wählen.', 'fr': 'Choisissez la langue de l\'interface.', 'es': 'Selecciona el idioma de la interfaz.', 'ru': 'Выберите язык интерфейса.'});
  String get defaultHomeTitle => _t({'tr': 'Varsayılan ana ekran', 'en': 'Default home launcher', 'de': 'Standard-Startbildschirm', 'fr': 'Écran d\'accueil par défaut', 'es': 'Pantalla de inicio predeterminada', 'ru': 'Лаунчер по умолчанию'});
  String get defaultHomeSub => _t({
        'tr': 'Cihaz açılınca Dashia\'nın otomatik başlaması için ana ekran uygulaması olarak Dashia\'yı seçin.',
        'en': 'Select Dashia as your default Home app so it starts automatically on boot.',
        'de': 'Wählen Sie Dashia als Standard-Start-App für den automatischen Start.',
        'fr': 'Définissez Dashia comme application d\'accueil par défaut au démarrage.',
        'es': 'Selecciona Dashia como inicio predeterminado para que arranque automáticamente.',
        'ru': 'Выберите Dashia главным экраном по умолчанию для автозапуска.',
      });
  String get systemAboutDesc => _t({
        'tr': 'Android araç multimedya üniteleri için açık kaynaklı, hafif ve modern Car Launcher.',
        'en': 'Open-source, lightweight, and modern Car Launcher for Android automotive head units.',
        'de': 'Moderner, leichtgewichtiger Open-Source Car Launcher für Android-Autoradios.',
        'fr': 'Car Launcher open-source, léger et moderne pour systèmes multimédias Android.',
        'es': 'Car Launcher moderno, ligero y de código abierto para pantallas Android de coche.',
        'ru': 'Современный и лёгкий Car Launcher с открытым исходным кодом для Android-магнитол.',
      });

  // --- Harita & Çevrimdışı OSM ---
  String get mapProviderTitle => _t({'tr': 'Harita sağlayıcısı', 'en': 'Map provider', 'de': 'Kartenanbieter', 'fr': 'Fournisseur de carte', 'es': 'Proveedor de mapa', 'ru': 'Поставщик карт'});
  String get offlineOsmTitle => _t({'tr': 'Çevrimdışı Harita İndir (Offline OpenStreetMap)', 'en': 'Offline Map Downloader (OpenStreetMap)', 'de': 'Offline-Karten herunterladen (OSM)', 'fr': 'Cartes hors-ligne (OpenStreetMap)', 'es': 'Descargar Mapas Sin Conexión (OSM)', 'ru': 'Офлайн-карты (OpenStreetMap)'});
  String get offlineOsmSub => _t({
        'tr': 'Multimedya cihazınız internetsiz çalışırken haritanın sorunsuz görünmesi için bulunduğunuz şehri veya bölgeyi önceden Wi-Fi ile indirin.',
        'en': 'Download your city or region over Wi-Fi so the map works seamlessly without an internet connection.',
        'de': 'Laden Sie Ihre Stadt oder Region per WLAN herunter, um die Karte offline zu nutzen.',
        'fr': 'Téléchargez votre ville ou région en Wi-Fi pour utiliser la carte sans connexion internet.',
        'es': 'Descarga tu ciudad o región por Wi-Fi para usar el mapa sin conexión a internet.',
        'ru': 'Скачайте нужный город или область по Wi-Fi для работы карты без интернета.',
      });
  String get cityOrRegion => _t({'tr': 'Şehir / Bölge:', 'en': 'City / Region:', 'de': 'Stadt / Region:', 'fr': 'Ville / Région :', 'es': 'Ciudad / Región:', 'ru': 'Город / Регион:'});
  String get pickRegionOnMap => _t({'tr': 'Haritadan Bölge Seç', 'en': 'Pick Area on Map', 'de': 'Auf Karte wählen', 'fr': 'Choisir sur la carte', 'es': 'Elegir en el mapa', 'ru': 'Выбрать на карте'});
  String get radiusLabel => _t({'tr': 'Kapsama Yarıçapı:', 'en': 'Coverage Radius:', 'de': 'Abdeckungsradius:', 'fr': 'Rayon de couverture :', 'es': 'Radio de cobertura:', 'ru': 'Радиус охвата:'});
  String get detailLevelLabel => _t({'tr': 'Harita Detay Seviyesi:', 'en': 'Map Detail Level:', 'de': 'Kartendetailstufe:', 'fr': 'Niveau de détail :', 'es': 'Nivel de detalle:', 'ru': 'Детализация:'});
  String get downloadRegionBtn => _t({'tr': 'Bölgeyi İndir', 'en': 'Download Region', 'de': 'Herunterladen', 'fr': 'Télécharger', 'es': 'Descargar zona', 'ru': 'Скачать область'});
  String get stopBtn => _t({'tr': 'Durdur', 'en': 'Stop', 'de': 'Stopp', 'fr': 'Arrêter', 'es': 'Detener', 'ru': 'Стоп'});
  String get clearAllBtn => _t({'tr': 'Tümünü Temizle', 'en': 'Clear All', 'de': 'Alle löschen', 'fr': 'Tout effacer', 'es': 'Borrar todo', 'ru': 'Очистить всё'});
  String get mapThemeTitle => _t({'tr': 'Harita Teması (Karanlık Mod Seçenekleri)', 'en': 'Map Theme (Dark Mode Options)', 'de': 'Kartenthema (Dunkelmodus)', 'fr': 'Thème de la carte (Mode sombre)', 'es': 'Tema del mapa (Modo oscuro)', 'ru': 'Тема карты (Ночной режим)'});
  String get mapShowSpeedTitle => _t({'tr': 'Hız çipini haritada göster', 'en': 'Show speed badge on map', 'de': 'Geschwindigkeit auf Karte zeigen', 'fr': 'Afficher la vitesse sur la carte', 'es': 'Mostrar velocidad en el mapa', 'ru': 'Показывать скорость на карте'});
  String get mapRotateTitle => _t({'tr': 'Haritayı gidiş yönüne döndür', 'en': 'Rotate map to driving heading', 'de': 'Karte in Fahrtrichtung drehen', 'fr': 'Orienter la carte selon la direction', 'es': 'Rotar mapa según dirección', 'ru': 'Вращать карту по направлению движения'});
  String get defaultZoomTitle => _t({'tr': 'Varsayılan yakınlık', 'en': 'Default zoom level', 'de': 'Standard-Zoomstufe', 'fr': 'Zoom par défaut', 'es': 'Zoom predeterminado', 'ru': 'Масштаб по умолчанию'});
  String get locPermDenied => _t({'tr': 'Konum izni verilmedi', 'en': 'Location permission denied', 'de': 'Standortberechtigung fehlt', 'fr': 'Permission de localisation refusée', 'es': 'Permiso de ubicación denegado', 'ru': 'Нет доступа к геолокации'});
  String get locServiceDisabled => _t({'tr': 'Cihazın konum (GPS) özelliği kapalı', 'en': 'Device GPS / Location service is disabled', 'de': 'GPS / Standortdienst ist deaktiviert', 'fr': 'Le service GPS est désactivé', 'es': 'El GPS del dispositivo está desactivado', 'ru': 'GPS отключён на устройстве'});
  String get emptySlotHint => _t({'tr': 'Boş alan\nBasılı tutup bileşen seçin', 'en': 'Empty slot\nLong-press to select a widget', 'de': 'Leerer Bereich\nGedrückt halten zum Auswählen', 'fr': 'Emplacement vide\nAppui long pour choisir un widget', 'es': 'Espacio vacío\nMantén pulsado para elegir', 'ru': 'Пустая область\nУдерживайте для выбора виджета'});

  // --- Slot Özelleştirme Penceresi ---
  String get customizeSlot => _t({'tr': 'Bu alanı özelleştir', 'en': 'Customize this slot', 'de': 'Diesen Bereich anpassen', 'fr': 'Personnaliser cet emplacement', 'es': 'Personalizar este espacio', 'ru': 'Настроить эту область'});
  String get customizeSlotSub => _t({'tr': 'Bu alanda gösterilecek bileşeni seçin (başka alandaysa yer değiştirirler).', 'en': 'Choose the widget to display here (swaps if already placed elsewhere).', 'de': 'Wählen Sie das Widget für diesen Bereich.', 'fr': 'Choisissez le widget à afficher ici.', 'es': 'Elige el widget para mostrar aquí.', 'ru': 'Выберите виджет для этой области.'});
  String get currentlyHidden => _t({'tr': 'Şu an gizli', 'en': 'Currently hidden', 'de': 'Derzeit ausgeblendet', 'fr': 'Actuellement masqué', 'es': 'Actualmente oculto', 'ru': 'Сейчас скрыто'});
  String get sizeAndLock => _t({'tr': 'Boyut & Düzen Kilidi', 'en': 'Size & Layout Lock', 'de': 'Größe & Layout-Sperre', 'fr': 'Taille & Verrouillage', 'es': 'Tamaño y Bloqueo', 'ru': 'Размер и блокировка'});
  String get showResizeHandles => showResizeHandlesTitle;
  String get topLeftHeight => leftTopHeight;
  String get needTwoSlots => _t({'tr': 'Boyut ayarı için en az iki alan dolu olmalı.', 'en': 'At least two slots must be active to resize.', 'de': 'Mindestens zwei Bereiche müssen aktiv sein.', 'fr': 'Au moins deux emplacements doivent être actifs.', 'es': 'Deben estar activos al menos dos espacios.', 'ru': 'Для изменения размера нужны минимум две области.'});
  String get resetLayout => resetLayoutBtn;
  String get allSettings => _t({'tr': 'Tüm Dashia ayarları', 'en': 'All Dashia settings', 'de': 'Alle Einstellungen', 'fr': 'Tous les paramètres', 'es': 'Todos los ajustes', 'ru': 'Все настройки Dashia'});
  String get wClock => widgetTitle('clock');
  String get wSpeed => widgetTitle('speed');
  String get wMedia => widgetTitle('media');
  String get wMap => widgetTitle('map');
  String get wNone => widgetTitle('none');
  String get wClockDesc => widgetDesc('clock');
  String get wSpeedDesc => widgetDesc('speed');
  String get wMediaDesc => widgetDesc('media');
  String get wMapDesc => widgetDesc('map');
  String get wNoneDesc => widgetDesc('none');
  String get osmThemeTitle => mapThemeTitle;
  String get mapLight => themeLight;
  String get mapDark => themeDark;
  String get mapMidnight => _t({'tr': 'Gece Mavisi', 'en': 'Midnight', 'de': 'Mitternacht', 'fr': 'Bleu nuit', 'es': 'Medianoche', 'ru': 'Полночь'});
  String get mapWarm => _t({'tr': 'Kehribar', 'en': 'Amber', 'de': 'Bernstein', 'fr': 'Ambre', 'es': 'Ámbar', 'ru': 'Янтарь'});
  String get showSpeedChip => mapShowSpeedTitle;
  String get rotateMapHeading => mapRotateTitle;
}
