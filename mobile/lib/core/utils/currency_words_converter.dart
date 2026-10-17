/// Utility to convert numbers into currency text (specifically Bahraini Dinars & Fils).
class CurrencyWordsConverter {
  static const List<String> _units = [
    '', 'one', 'two', 'three', 'four', 'five', 'six', 'seven', 'eight', 'nine',
    'ten', 'eleven', 'twelve', 'thirteen', 'fourteen', 'fifteen', 'sixteen',
    'seventeen', 'eighteen', 'nineteen'
  ];

  static const List<String> _tens = [
    '', '', 'twenty', 'thirty', 'forty', 'fifty', 'sixty', 'seventy', 'eighty', 'ninety'
  ];

  static String _convertThreeDigits(int n, {bool capitalizeHundred = false}) {
    if (n == 0) return '';
    String res = '';

    if (n >= 100) {
      res += '${_units[n ~/ 100]} ${capitalizeHundred ? "Hundred" : "hundred"}';
      n %= 100;
      if (n > 0) res += ' ';
    }

    if (n >= 20) {
      res += _tens[n ~/ 10];
      final rem = n % 10;
      if (rem > 0) {
        res += ' ${_units[rem]}';
      }
    } else if (n > 0) {
      res += _units[n];
    }

    return res;
  }

  /// Converts an integer amount into English words.
  static String numberToWords(int number, {bool isThousandsPart = false}) {
    if (number == 0) return 'zero';
    if (number < 0) return 'minus ${numberToWords(-number)}';

    String words = '';
    int num = number;

    // Billions
    if (num >= 1000000000) {
      final bill = num ~/ 1000000000;
      words += '${_convertThreeDigits(bill, capitalizeHundred: true)} Billion ';
      num %= 1000000000;
    }

    // Millions
    if (num >= 1000000) {
      final mill = num ~/ 1000000;
      words += '${_convertThreeDigits(mill, capitalizeHundred: true)} Million ';
      num %= 1000000;
    }

    // Thousands
    if (num >= 1000) {
      final thou = num ~/ 1000;
      words += '${_convertThreeDigits(thou, capitalizeHundred: true)} Thousand ';
      num %= 1000;
    }

    // Remaining hundreds, tens and units
    if (num > 0) {
      words += _convertThreeDigits(num, capitalizeHundred: false);
    }

    return words.trim();
  }

  /// Converts a BHD amount (e.g. 349994.700) to:
  /// "Bahraini Dinars three Hundred forty nine Thousand nine hundred ninety four and seven hundred fills only"
  static String toBahrainiDinarsWords(double amount) {
    if (amount.isNaN || amount.isInfinite) return '';
    final isNegative = amount < 0;
    final absAmount = amount.abs();

    final dinars = absAmount.floor();
    // Bahraini Dinars have 1000 Fils (3 decimal digits)
    final fills = ((absAmount - dinars) * 1000).round();

    final dinarText = numberToWords(dinars);
    final prefix = isNegative ? 'Minus Bahraini Dinars ' : 'Bahraini Dinars ';

    if (fills > 0) {
      final fillsText = numberToWords(fills);
      return '$prefix$dinarText and $fillsText fills only';
    } else {
      return '$prefix$dinarText only';
    }
  }
}
