// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {VeritasToken} from "../src/VeritasToken.sol";
import {VeritasCore} from "../src/VeritasCore.sol";
import {VeritasAgent} from "../src/VeritasAgent.sol";

contract Deploy is Script {
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        vm.startBroadcast(deployerPrivateKey);

        // 1. Deploy VERI Token
        VeritasToken token = new VeritasToken();
        console2.log("VeritasToken deployed at:", address(token));

        // 2. Deploy VeritasCore
        VeritasCore core = new VeritasCore(address(token));
        console2.log("VeritasCore deployed at:", address(core));

        // 3. Deploy VeritasAgent
        VeritasAgent agent = new VeritasAgent(address(core));
        console2.log("VeritasAgent deployed at:", address(agent));

        // 4. Setup Agent inside Core
        core.setAgent(address(agent));
        console2.log("Agent set in VeritasCore");

        // 5. Optionally, set mock mode for initial testing
        // agent.setMockMode(true);
        // console2.log("Agent mock mode set to true for demo");

        // 6. Fund the agent on RitualWallet (Assuming standard payable receive or deposit method)
        // address ritualWallet = 0x532F0dF0896F353d8C3DD8cc134e8129DA2a3948;
        // In this script we won't call RitualWallet directly to avoid ABI mismatch if unknown,
        // user will do it via `cast send` as mentioned in prompt.

        vm.stopBroadcast();
    }
}
