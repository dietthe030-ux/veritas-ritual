// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {VeritasCore} from "../src/VeritasCore.sol";
import {VeritasAgent} from "../src/VeritasAgent.sol";
import {VeritasToken} from "../src/VeritasToken.sol";

contract MockHTTPPrecompile {
    fallback(bytes calldata input) external returns (bytes memory) {
        bytes memory actualOutput = abi.encode("Mocked HTTP Context Metadata");
        return abi.encode(input, actualOutput);
    }
}

contract MockLLMPrecompile {
    fallback(bytes calldata input) external returns (bytes memory) {
        bytes memory actualOutput = abi.encode(
            false,
            bytes('{"score":812,"verdict":0,"reasoning":"Authentic image confirmed"}'),
            bytes(""),
            ""
        );
        return abi.encode(input, actualOutput);
    }
}

contract MockScheduler {
    uint256 public scheduleCount;
    function schedule(
        bytes calldata,
        uint256,
        uint32,
        uint32,
        uint32,
        uint32,
        uint256,
        uint256,
        uint256,
        address
    ) external returns (uint256) {
        scheduleCount++;
        return scheduleCount;
    }
}

contract VeritasTest is Test {
    VeritasToken public token;
    VeritasCore public core;
    VeritasAgent public agent;

    address constant HTTP_PRECOMPILE = 0x0000000000000000000000000000000000000801;
    address constant LLM_PRECOMPILE  = 0x0000000000000000000000000000000000000802;
    address constant SCHEDULER       = 0x56e776BAE2DD60664b69Bd5F865F1180ffB7D58B;

    address public user = address(0x1337);

    function setUp() public {
        vm.etch(HTTP_PRECOMPILE, address(new MockHTTPPrecompile()).code);
        vm.etch(LLM_PRECOMPILE, address(new MockLLMPrecompile()).code);
        vm.etch(SCHEDULER, address(new MockScheduler()).code);

        token = new VeritasToken();
        core = new VeritasCore(address(token));
        agent = new VeritasAgent(address(core));

        core.setAgent(address(agent));

        token.mint(user, 1000 * 10 ** 18);
        vm.prank(user);
        token.approve(address(core), type(uint256).max);
    }

    function test_SubmitAndVerify_MockMode_FullFlow_Success() public {
        agent.setMockMode(true);
        bytes32 mediaHash = keccak256("test_media");
        string memory mediaUri = "ipfs://test";

        vm.prank(user);
        core.submitForVerification(mediaHash, mediaUri);

        (,,,,,,,,VeritasCore.VerificationStatus status) = core.records(mediaHash);
        assertEq(uint(status), uint(VeritasCore.VerificationStatus.ContextFetched));

        agent.analyzeAuthenticity(mediaHash);

        (,,,, VeritasCore.Verdict verdict, , , string memory reasoning, VeritasCore.VerificationStatus finalStatus) = core.records(mediaHash);
        
        assertEq(uint(finalStatus), uint(VeritasCore.VerificationStatus.Verified));
        assertEq(core.ownerOf(core.tokenIdOf(mediaHash)), user);
    }

    function test_FetchContext_RealMode_CallsHTTPPrecompile() public {
        bytes32 mediaHash = keccak256("test_media_real");
        vm.prank(user);
        core.submitForVerification(mediaHash, "ipfs://real");
        
        // In real mode, it calls HTTP precompile mock and saves pending context
        bytes memory pending = agent.pendingContext(mediaHash);
        assertTrue(pending.length > 0);
    }

    function test_AnalyzeAuthenticity_ParsesLLMResponse_Correctly() public {
        bytes32 mediaHash = keccak256("test_media_llm");
        vm.prank(user);
        core.submitForVerification(mediaHash, "ipfs://real");
        
        // This will call the mock LLM
        agent.analyzeAuthenticity(mediaHash);

        (,,, uint256 score, VeritasCore.Verdict verdict, , , , ) = core.records(mediaHash);
        assertEq(score, 812);
        assertEq(uint(verdict), uint(VeritasCore.Verdict.Authentic));
    }

    function test_FulfillVerification_MintsCertificateNFT_OnFirstVerification() public {
        agent.setMockMode(true);
        bytes32 mediaHash = keccak256("mint_test");
        vm.prank(user);
        core.submitForVerification(mediaHash, "ipfs://mint");
        agent.analyzeAuthenticity(mediaHash);

        uint256 tokenId = core.tokenIdOf(mediaHash);
        assertTrue(tokenId > 0);
        assertEq(core.ownerOf(tokenId), user);
    }

    function test_FulfillVerification_UpdatesExistingCertificate_OnReVerification() public {
        agent.setMockMode(true);
        bytes32 mediaHash = keccak256("reverify_test");
        vm.prank(user);
        core.submitForVerification(mediaHash, "ipfs://reverify");
        agent.analyzeAuthenticity(mediaHash);

        uint256 tokenId1 = core.tokenIdOf(mediaHash);

        // Re-verify logic: we can just call analyzeAuthenticity again if context exists
        // Wait, analyzeAuthenticity doesn't clear pendingContext, so it can be re-run
        agent.analyzeAuthenticity(mediaHash);
        uint256 tokenId2 = core.tokenIdOf(mediaHash);

        assertEq(tokenId1, tokenId2);
    }

    function test_RevertWhen_NonAgent_CallsFulfillVerification() public {
        bytes32 mediaHash = keccak256("non_agent");
        vm.expectRevert("VeritasCore: caller is not the agent");
        core.fulfillVerification(mediaHash, 900, VeritasCore.Verdict.Authentic, bytes32(0), "Testing");
    }

    function test_ScheduleRegistration_CalledAfterFetchContext() public {
        // Already checked implicitly if MockScheduler was called. Let's cast to get count.
        MockScheduler schedulerMock = MockScheduler(SCHEDULER);
        uint256 beforeCount = schedulerMock.scheduleCount();

        bytes32 mediaHash = keccak256("schedule_test");
        vm.prank(user);
        core.submitForVerification(mediaHash, "ipfs://schedule");

        uint256 afterCount = schedulerMock.scheduleCount();
        assertEq(afterCount, beforeCount + 1);
    }

    function test_ToggleMockMode_OnlyOwner() public {
        vm.prank(user);
        vm.expectRevert(); // Ownable revert
        agent.setMockMode(true);
    }

    function test_SubmitForVerification_RequiresVERIStake() public {
        address poorUser = address(0x999);
        vm.prank(poorUser);
        vm.expectRevert(); // TransferFrom fail or ERC20 insufficient allowance
        core.submitForVerification(keccak256("poor"), "ipfs://poor");
    }
}
