/// Converts an integer into Indian Numbering Format words
/// e.g. 150 -> "One Hundred Fifty"
/// 1500 -> "One Thousand Five Hundred"
/// 100000 -> "One Lakh"

String numberToWords(int number) {
  if (number == 0) return 'Zero';
  if (number < 0) return 'Minus ${numberToWords(-number)}';

  final units = [
    '', 'One', 'Two', 'Three', 'Four', 'Five', 'Six', 'Seven', 'Eight', 'Nine',
    'Ten', 'Eleven', 'Twelve', 'Thirteen', 'Fourteen', 'Fifteen', 'Sixteen',
    'Seventeen', 'Eighteen', 'Nineteen'
  ];

  final tens = [
    '', '', 'Twenty', 'Thirty', 'Forty', 'Fifty', 'Sixty', 'Seventy', 'Eighty', 'Ninety'
  ];

  String convertChunk(int n) {
    if (n == 0) return '';
    if (n < 20) return units[n];
    if (n < 100) {
      final t = tens[n ~/ 10];
      final u = units[n % 10];
      return u.isEmpty ? t : '$t $u';
    }
    final h = units[n ~/ 100];
    final rest = convertChunk(n % 100);
    return rest.isEmpty ? '$h Hundred' : '$h Hundred $rest';
  }

  String result = '';
  int n = number;

  // Crore (10,00,00,000)
  if (n >= 10000000) {
    final crores = n ~/ 10000000;
    result += '${convertChunk(crores)} Crore ';
    n %= 10000000;
  }

  // Lakh (1,00,000)
  if (n >= 100000) {
    final lakhs = n ~/ 100000;
    result += '${convertChunk(lakhs)} Lakh ';
    n %= 100000;
  }

  // Thousand (1,000)
  if (n >= 1000) {
    final thousands = n ~/ 1000;
    result += '${convertChunk(thousands)} Thousand ';
    n %= 1000;
  }

  if (n > 0) {
    result += convertChunk(n);
  }

  return result.trim();
}

String formatQuantityWithWords(dynamic qty) {
  if (qty == null) return '1 (One)';
  final int val = int.tryParse(qty.toString()) ?? 1;
  final words = numberToWords(val);
  return '$val ($words)';
}
