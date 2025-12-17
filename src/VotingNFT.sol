// SPDX-License-Identifier: MIT
pragma solidity 0.8.31;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title VotingNFT
 * @notice NFT donné à chaque personne ayant voté
 * @dev Un seul NFT par votant pour empêcher le double vote
 */
contract VotingNFT is ERC721, Ownable {
    uint256 private _nextTokenId;

    // Mapping pour vérifier si une adresse a déjà reçu un NFT
    mapping(address => bool) public hasVoted;

    event NFTMinted(address indexed voter, uint256 indexed tokenId);

    constructor() ERC721("Voting NFT", "VNFT") Ownable(msg.sender) {
        _nextTokenId = 1; // Les token IDs commencent à 1
    }

    /**
     * @notice Mint un NFT pour un votant
     * @param voter Adresse du votant
     * @dev Seul le owner (contrat de vote) peut appeler cette fonction
     */
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

    /**
     * @notice Vérifie si un votant possède un NFT de vote
     * @param voter Adresse à vérifier
     * @return bool true si le votant possède un NFT
     */
    function hasVotingNFT(address voter) external view returns (bool) {
        return hasVoted[voter];
    }

    /**
     * @notice Obtient le nombre total de NFTs mintés
     * @return uint256 Nombre total de NFTs
     */
    function totalSupply() external view returns (uint256) {
        return _nextTokenId - 1;
    }
}
