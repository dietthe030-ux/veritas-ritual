// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC721} from "openzeppelin-contracts/contracts/token/ERC721/ERC721.sol";
import {Ownable} from "openzeppelin-contracts/contracts/access/Ownable.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {Strings} from "openzeppelin-contracts/contracts/utils/Strings.sol";

contract VeritasCore is ERC721, Ownable {
    using Strings for uint256;

    enum VerificationStatus { None, ContextFetched, Analyzing, Verified, Flagged, Failed }
    enum Verdict { Authentic, Suspicious, LikelyDeepfake }

    struct MediaRecord {
        bytes32 mediaHash;
        string mediaUri;
        address submitter;
        uint256 authenticityScore;
        Verdict verdict;
        uint256 verifiedAt;
        bytes32 contextHash;
        string reasoning;
        VerificationStatus status;
    }

    mapping(bytes32 => MediaRecord) public records;
    mapping(bytes32 => uint256) public tokenIdOf;
    
    uint256 private _nextTokenId = 1;
    address public agent;
    IERC20 public veriToken;
    uint256 public stakeRequired = 10 * 10 ** 18; // 10 VERI

    event VerificationRequested(bytes32 indexed mediaHash, address indexed submitter, string mediaUri);
    event VerificationCompleted(bytes32 indexed mediaHash, uint256 score, Verdict verdict);
    event VerificationFailed(bytes32 indexed mediaHash, string reason);

    modifier onlyAgent() {
        require(msg.sender == agent, "VeritasCore: caller is not the agent");
        _;
    }

    constructor(address _veriToken) ERC721("Veritas Certificate", "VERICERT") Ownable(msg.sender) {
        veriToken = IERC20(_veriToken);
    }

    function setAgent(address _agent) external onlyOwner {
        agent = _agent;
    }

    function setStakeRequired(uint256 _amount) external onlyOwner {
        stakeRequired = _amount;
    }

    function submitForVerification(bytes32 mediaHash, string calldata mediaUri) external {
        require(records[mediaHash].status == VerificationStatus.None, "VeritasCore: already submitted");
        
        // Stake required tokens
        require(veriToken.transferFrom(msg.sender, address(this), stakeRequired), "VeritasCore: stake failed");

        records[mediaHash] = MediaRecord({
            mediaHash: mediaHash,
            mediaUri: mediaUri,
            submitter: msg.sender,
            authenticityScore: 0,
            verdict: Verdict.Authentic,
            verifiedAt: 0,
            contextHash: bytes32(0),
            reasoning: "",
            status: VerificationStatus.None
        });

        if (agent != address(0)) {
            // Forward to agent
            // Using low level call to avoid circular dependency in imports here
            (bool success, ) = agent.call(abi.encodeWithSignature("fetchContext(bytes32,string)", mediaHash, mediaUri));
            require(success, "VeritasCore: Agent call failed");
        }

        emit VerificationRequested(mediaHash, msg.sender, mediaUri);
    }

    function fulfillVerification(
        bytes32 mediaHash,
        uint256 score,
        Verdict verdict,
        bytes32 contextHash,
        string calldata reasoning
    ) external onlyAgent {
        MediaRecord storage record = records[mediaHash];
        require(record.status != VerificationStatus.None, "VeritasCore: record not found");

        record.authenticityScore = score;
        record.verdict = verdict;
        record.contextHash = contextHash;
        record.reasoning = reasoning;
        record.verifiedAt = block.timestamp; // block.timestamp on Ritual is already ms
        record.status = VerificationStatus.Verified;

        if (tokenIdOf[mediaHash] == 0) {
            uint256 tokenId = _nextTokenId++;
            tokenIdOf[mediaHash] = tokenId;
            _mint(record.submitter, tokenId);
        }

        emit VerificationCompleted(mediaHash, score, verdict);
    }

    function updateStatus(bytes32 mediaHash, VerificationStatus status) external onlyAgent {
        records[mediaHash].status = status;
    }

    function _baseURI() internal pure override returns (string memory) {
        return "data:application/json;base64,";
    }

    // Simplified tokenURI for MVP, returning base64 JSON
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        require(ownerOf(tokenId) != address(0), "ERC721: invalid token ID");
        // For a full implementation, we'd base64 encode a JSON string containing the MediaRecord data.
        return string(abi.encodePacked(_baseURI(), "eyJuYW1lIjoiVmVyaXRhcyBDZXJ0aWZpY2F0ZSIsImRlc2NyaXB0aW9uIjoiQXV0aGVudGljaXR5IENlcnRpZmljYXRlIn0="));
    }
}
