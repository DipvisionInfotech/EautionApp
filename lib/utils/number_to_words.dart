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

String formatQuantityWithWords(dynamic qty, [dynamic unit]) {
  if (qty == null || qty.toString().trim().isEmpty) return '';
  final rawStr = qty.toString().trim();
  final unitStr = (unit != null && unit.toString().trim().isNotEmpty) ? unit.toString().trim() : '';

  if (rawStr.startsWith('🔒')) {
    return rawStr;
  }

  // Check if rawStr is numeric or has trailing unit e.g. "1432 MT" or "1432"
  final numMatch = RegExp(r'^([0-9]+)\s*(.*)$').firstMatch(rawStr);
  if (numMatch != null) {
    final numVal = int.tryParse(numMatch.group(1)!);
    final trailingUnit = numMatch.group(2)?.trim() ?? '';
    final finalUnit = unitStr.isNotEmpty ? unitStr : trailingUnit;

    if (numVal != null) {
      final words = numberToWords(numVal);
      final unitDisplay = finalUnit.isNotEmpty ? ' $finalUnit' : '';
      return '$numVal$unitDisplay ($words$unitDisplay)'.trim();
    }
  }

  final unitDisplay = unitStr.isNotEmpty ? ' $unitStr' : '';
  return '$rawStr$unitDisplay'.trim();
}

String formatCurrency(dynamic amount, {bool withSymbol = true}) {
  if (amount == null) return withSymbol ? '₹0.00' : '0.00';
  final num? val = (amount is num) ? amount : num.tryParse(amount.toString());
  if (val == null) return withSymbol ? '₹0.00' : '0.00';

  String str = val.toStringAsFixed(2);
  final rawStr = val.toString();
  if (rawStr.contains('.')) {
    final decPart = rawStr.split('.')[1];
    if (decPart.length > 2) {
      str = val.toStringAsFixed(4).replaceAll(RegExp(r'0+$'), '');
      if (str.endsWith('.')) str += '00';
    }
  }
  final parts = str.split('.');
  final whole = parts[0];
  final dec = parts.length > 1 ? parts[1] : '00';
  final regex = RegExp(r'(\d+?)(?=(\d\d)+(\d)(?!\d))');
  final formattedWhole = whole.replaceAllMapped(regex, (match) => '${match[1]},');
  final result = '$formattedWhole.$dec';
  return withSymbol ? '₹$result' : result;
}
