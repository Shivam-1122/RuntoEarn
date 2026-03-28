import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class PaymentService {

  // Your receiving wallet / contract
  final String receiverAddress =
      dotenv.env['RECEIVER_ADDRESS'] ?? "";

  // Monad / EVM chain
  final int chainId = int.tryParse(dotenv.env['CHAIN_ID'] ?? '0') ?? 0;

  // ================= FEES =================

  double getFee(int min) {

    if (min == 10) return 0.05;
    if (min == 20) return 0.10;
    if (min == 30) return 0.50;

    return 0.0;
  }

  // ================= TO WEI =================

  String _toWei(double amount) {

    return (amount * 1e18).toInt().toString();
  }

  // ================= PAY =================

  Future<void> pay(int min) async {

    final double fee = getFee(min);

    if (fee <= 0) {
      throw Exception("Invalid duration");
    }

    final value = _toWei(fee);

    final url =
        "https://metamask.app.link/send"
        "?to=$receiverAddress"
        "&value=$value"
        "&chainId=$chainId";

    final uri = Uri.parse(url);

    if (!await canLaunchUrl(uri)) {
      throw Exception("MetaMask not installed");
    }

    await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );
  }
}
