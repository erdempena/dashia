import 'dart:async';

/// Düşük frekanslı sensör veya event güncellemeleri için
/// gereksiz widget yeniden çizimlerini (rebuild) engelleyen Throttler.
class Throttler {
  final Duration interval;
  Timer? _timer;
  bool _isReady = true;

  Throttler({required this.interval});

  void run(void Function() action) {
    if (_isReady) {
      _isReady = false;
      action();
      _timer?.cancel();
      _timer = Timer(interval, () {
        _isReady = true;
      });
    }
  }

  void dispose() {
    _timer?.cancel();
  }
}
