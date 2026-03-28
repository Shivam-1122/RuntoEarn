Run2Earn – Play to Earn Fitness Game 

Run2Earn is a play-to-earn running competition platform built with Flutter, Firebase, and Web3. 
Users compete in real-time running matches, stake crypto tokens, and earn rewards based on distance. 

FEATURES 

Authentication 
- Email & Password Login/Signup 
- Firebase Authentication 

Matchmaking 
- Real-time queue 
- 20–30 second lobby 
- 2–4 players 

Crypto Payments 
- MetaMask deep linking 
- External payment approval 
- MON/EVM tokens 

Running Game 
- GPS tracking 
- Distance calculation 
- Countdown timer 

Results & Rewards 
- Leaderboard 
- Prize pool distribution 
- Platform fee 

Tech Stack 
- Flutter 
- Firebase 
- Solidity 
- MetaMask 
- Geolocator 

Project Structure 
lib/ 
screens/ 
services/ 
utils/ 
main.dart 

Setup Steps 
1. Install Flutter 
2. Setup Firebase 
3. Configure MetaMask 
4. Run flutter pub get 
5. Run flutter run 

App Flow 
Login → Home → Matchmaking → Preview → Payment → Run → Result 

Smart Contract 
Functions: 
createMatch 
joinMatch 
finishMatch 
getPool 
getPlayers 

Reward Distribution 
2 Players: 90% Winner, 10% Platform 
3 Players: 70% Winner, 20% Second, 10% Platform 
4+ Players: 70%, 20%, 5%, 5% 

Limitations 
- Depends on GPS 
- Testnet recommended 
- No in-app wallet 

Future Scope 
- WalletConnect 
- Anti-cheat 
- NFTs 
- Ranking 

Developer 
Run2Earn Project 
 

