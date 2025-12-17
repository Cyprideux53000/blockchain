// SPDX-License-Identifier: MIT
pragma solidity 0.8.31;

import "forge-std/Script.sol";
import {SimpleVotingSystem} from "../src/SimpleVotingSystem.sol";
import {VotingNFT} from "../src/VotingNFT.sol";

contract DeploySimpleStorage is Script {
    function run() external returns (SimpleVotingSystem) {
        //start and stop braodcast indicates that everything inside means that we are going to call a RPC Node
        vm.startBroadcast();
        VotingNFT nft = new VotingNFT();
        SimpleVotingSystem votingSystem = new SimpleVotingSystem(address(nft));
        nft.transferOwnership(address(votingSystem));
        vm.stopBroadcast();
        return votingSystem;
    }
}
