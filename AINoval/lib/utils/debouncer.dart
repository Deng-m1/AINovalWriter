import 'dart:async';

class Debouncer {

  Debouncer({this.delay = const Duration(milliseconds: 500)});
  Timer? _timer;
  final Duration delay;

  void run(Function() action) {
    _timer?.cancel();
    _timer = Timer(delay, action);
  }

  void dispose() {
    _timer?.cancel();
  }
}