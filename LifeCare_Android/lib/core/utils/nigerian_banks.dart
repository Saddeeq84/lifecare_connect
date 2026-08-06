// Nigerian Banks with Paystack Bank Codes
class NigerianBanks {
  static final List<Map<String, String>> banks = [
    {'name': 'Access Bank', 'code': '044'},
    {'name': 'Citibank', 'code': '023'},
    {'name': 'Diamond Bank', 'code': '063'},
    {'name': 'Ecobank Nigeria', 'code': '050'},
    {'name': 'Fidelity Bank Nigeria', 'code': '070'},
    {'name': 'First Bank of Nigeria', 'code': '011'},
    {'name': 'First City Monument Bank', 'code': '214'},
    {'name': 'Guaranty Trust Bank', 'code': '058'},
    {'name': 'Heritage Bank Plc', 'code': '030'},
    {'name': 'Jaiz Bank', 'code': '301'},
    {'name': 'Keystone Bank Limited', 'code': '082'},
    {'name': 'Kuda Bank', 'code': '50211'},
    {'name': 'Opay', 'code': '999992'},
    {'name': 'Palmpay', 'code': '999991'},
    {'name': 'Polaris Bank', 'code': '076'},
    {'name': 'Providus Bank Plc', 'code': '101'},
    {'name': 'Stanbic IBTC Bank Nigeria Limited', 'code': '221'},
    {'name': 'Standard Chartered Bank', 'code': '068'},
    {'name': 'Sterling Bank', 'code': '232'},
    {'name': 'Suntrust Bank Nigeria Limited', 'code': '100'},
    {'name': 'Union Bank of Nigeria', 'code': '032'},
    {'name': 'United Bank for Africa', 'code': '033'},
    {'name': 'Unity Bank Plc', 'code': '215'},
    {'name': 'Wema Bank', 'code': '035'},
    {'name': 'Zenith Bank', 'code': '057'},
  ];

  static String? getBankCode(String bankName) {
    final bank = banks.firstWhere(
      (b) => b['name']!.toLowerCase() == bankName.toLowerCase(),
      orElse: () => {'name': '', 'code': ''},
    );
    return bank['code'];
  }

  static List<String> getBankNames() {
    return banks.map((b) => b['name']!).toList();
  }
}
