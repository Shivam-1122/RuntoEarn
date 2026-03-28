import 'package:web3dart/web3dart.dart';
import 'package:http/http.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class WalletService {
  static final WalletService _instance = WalletService._internal();
  factory WalletService() => _instance;
  WalletService._internal();

  // RPC (Sepolia for testing)
  final String rpcUrl = dotenv.env['RPC_URL'] ?? "https://rpc.testnet.monad.xyz";

  Web3Client? _client;

  String? _walletAddress;

  // ================= INIT =================

  void init() {
    _client = Web3Client(rpcUrl, Client());
  }

  // ================= SET WALLET =================

  void setWalletAddress(String address) {
    _walletAddress = address.trim();
  }

  String? get walletAddress => _walletAddress;

  // ================= VALIDATE ADDRESS =================

  bool _isValidAddress(String addr) {
    return addr.startsWith("0x") && addr.length == 42;
  }

  // ================= GET BALANCE =================

  Future<double> getBalance() async {
    try {
      if (_client == null) {
        throw Exception("WalletService not initialized");
      }

      if (_walletAddress == null || _walletAddress!.isEmpty) {
        throw Exception("Wallet not connected");
      }

      if (!_isValidAddress(_walletAddress!)) {
        throw Exception("Invalid wallet address");
      }

      final addr = EthereumAddress.fromHex(_walletAddress!);

      final balance = await _client!.getBalance(addr);

      return balance.getValueInUnit(EtherUnit.ether);

    } catch (e) {
      print("❌ Wallet Balance Error: $e");

      // NEVER crash app
      return 0.0;
    }
  }

  // ================= METAMASK OPEN =================

  Future<bool> connectWallet() async {
    // For now: just open MetaMask
    return true;
  }
}
