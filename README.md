💊 Pharma Guard AI
Empowering Drug Safety with AI and Starknet.

Pharma Guard AI is a decentralized health-tech solution built for the RE{DEFINE} Starknet Hackathon. It provides a verifiable, immutable audit trail for drug interaction safety checks, ensuring patient safety through AI-driven insights and blockchain accountability.

🚀 Live Demo & Links
Live DApp: https://pharma-guard-ai-nextjs.vercel.app/

Demo Video: [https://youtube.com/shorts/PkpFO9c__Fs?si=UkLgDQfoquqMT6v8]

GitHub: https://github.com/BeeAlmighty/pharma-guard-ai

Network: Starknet Sepolia Testnet

🧐 What is Pharma Guard AI?
Adverse drug interactions are a leading cause of preventable hospitalizations. Medical records are often fragmented, making it hard to track safety history. Pharma Guard AI solves this by:

AI Risk Assessment: Using an n8n-orchestrated AI agent to analyze drug combinations.

Immutable Logging: Committing every safety check to Starknet to create a permanent, tamper-proof audit trail.

Provider Reputation: A Soulbound Token (SBT) system that rewards medical providers for consistent safety logging.

🛠️ Technical Stack
Smart Contracts: Cairo 2.0 (deployed on Starknet Sepolia).

Frontend: Next.js, Scaffold-Stark 2, Starknet-React.

Wallet & Identity: Braavos (Account Abstraction) + Starknet ID (moses.stark).

Orchestration: n8n for AI agent logic.

📜 Contract Addresses (Sepolia)
Medical Logger: 0x5245bdc9f2b35671f1112491964a8f442315ab3744c3ce8144c773f724b04c8

Reputation SBT: 0x362ac634610d42d1ed96caa98ef76c918f120d278a56a9f653ada970a786b67

🛡️ Security Features
Duplicate Prevention: The MedicalLogger contract uses commitment hashing to prevent the same safety check from being logged multiple times (ALREADY_EXISTS logic).

Verification: Only authorized providers can trigger high-level reputation updates.

⚙️ How to Run Locally
1. Clone the repo
```Bash
git clone https://github.com/BeeAlmighty/pharma-guard-ai.git
cd pharma-guard-ai
```
2. Install dependencies
```Bash
yarn install
```
3. Run the Frontend
```Bash
yarn start
```
👨‍💻 Author
Moses - Pharmacist & Web3 Developer
