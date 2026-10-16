/// Araç içi ergonomi ve sürüş güvenliği standartlarına
/// göre belirlenmiş minimum dokunmatik alanlar ve boyutlar.
class AppDimens {
  AppDimens._();

  // Boşluklar (Spacing & Padding)
  static const double spaceXS = 4.0;
  static const double spaceS = 8.0;
  static const double spaceM = 16.0;
  static const double spaceL = 24.0;
  static const double spaceXL = 32.0;

  // Köşe Yuvarlama (Corner Radius) - Performans için aşırı yuvarlama yerine sade yarıçaplar
  static const double radiusS = 8.0;
  static const double radiusM = 14.0;
  static const double radiusL = 20.0;

  // Sürüş Ergonomisi: Minimum Dokunmatik Hedef Boyutları (Touch Targets)
  // Sürüş sırasında parmak isabetini kolaylaştırmak için minimum 64-80dp
  static const double minTouchTarget = 64.0;
  static const double largeTouchTarget = 80.0;
  static const double navButtonHeight = 72.0;

  // Tipografi Boyutları (Sürüş mesafesinden okunabilecek büyük fontlar)
  static const double fontSpeedValue = 72.0;
  static const double fontSpeedUnit = 18.0;
  static const double fontClock = 42.0;
  static const double fontDate = 16.0;
  static const double fontTitle = 22.0;
  static const double fontBody = 16.0;
  static const double fontCaption = 13.0;

  // Kart Boyutları
  static const double mediaCardHeight = 160.0;
}
