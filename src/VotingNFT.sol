// SPDX-License-Identifier: MIT
pragma solidity 0.8.31;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract VotingNFT is ERC721, Ownable {
    uint256 private _nextTokenId;
    mapping(address => bool) public hasVoted;

    event NFTMinted(address indexed voter, uint256 indexed tokenId);

    constructor() ERC721("Voting NFT", "VNFT") Ownable(msg.sender) {
        _nextTokenId = 1;
    }

    function mintForVoter(address voter) external onlyOwner returns (uint256) {
        require(voter != address(0), "Adresse invalide");
        require(!hasVoted[voter], "Le votant possede deja un NFT");

        uint256 tokenId = _nextTokenId;
        _nextTokenId++;

        _safeMint(voter, tokenId);
        hasVoted[voter] = true;

        emit NFTMinted(voter, tokenId);

        return tokenId;
    }

    function hasVotingNFT(address voter) external view returns (bool) {
        return hasVoted[voter];
    }

    function totalSupply() external view returns (uint256) {
        return _nextTokenId - 1;
    }
}
