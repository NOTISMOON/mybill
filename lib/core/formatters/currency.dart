String formatCny(int cents) {
  final absolute = cents.abs();
  final yuan = (absolute ~/ 100).toString();
  final grouped = yuan.replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => ',',
  );
  return '${cents < 0 ? '-' : ''}¥$grouped.${twoDigits(absolute % 100)}';
}

String twoDigits(int value) => value.toString().padLeft(2, '0');
