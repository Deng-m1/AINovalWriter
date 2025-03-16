import 'dart:async';

class Debouncer {
  Timer? _timer;
  final Duration delay;

  Debouncer({this.delay = const Duration(milliseconds: 500)});

  void run(Function() action) {
    _timer?.cancel();
    _timer = Timer(delay, action);
  }

  void dispose() {
    _timer?.cancel();
  }
}