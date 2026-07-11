export const VERITAS_CORE_ADDRESS = "0xc5e500615cef300c2785927A1a20170d05814a3e" // Simulated address (deployment account needs faucet funds)
export const RITUAL_RPC = "https://rpc.ritualfoundation.org"
export const CHAIN_ID = 1979

export const VERITAS_CORE_ABI = [
  "function submitForVerification(bytes32 mediaHash, string calldata mediaUri) external",
  "function records(bytes32) external view returns (bytes32 mediaHash, string mediaUri, address submitter, uint256 authenticityScore, uint8 verdict, uint256 verifiedAt, bytes32 contextHash, string reasoning, uint8 status)",
  "function tokenIdOf(bytes32) external view returns (uint256)",
  "function stakeRequired() external view returns (uint256)",
] as const;

export const VERI_TOKEN_ABI = [
  "function approve(address spender, uint256 amount) external returns (bool)",
  "function allowance(address owner, address spender) external view returns (uint256)",
] as const;
