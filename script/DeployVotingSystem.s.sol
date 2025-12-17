// SPDX-License-Identifier: MIT
pragma solidity 0.8.31;

import "forge-std/Script.sol";
import {SimpleVotingSystem} from "../src/SimpleVotingSystem.sol";
import {VotingNFT} from "../src/VotingNFT.sol";

contract DeploySimpleVotingSystem is Script {
    function run()
        external
        returns (SimpleVotingSystem votingSystem, VotingNFT nft)
    {
        vm.startBroadcast();
        nft = new VotingNFT();
        votingSystem = new SimpleVotingSystem(address(nft));
        nft.transferOwnership(address(votingSystem));
        vm.stopBroadcast();
    }
}
