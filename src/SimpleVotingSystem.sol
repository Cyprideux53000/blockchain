// SPDX-License-Identifier: MIT
pragma solidity 0.8.31;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "./VotingNFT.sol";

contract SimpleVotingSystem is AccessControl {
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant FOUNDER_ROLE = keccak256("FOUNDER_ROLE");

    enum WorkflowStatus {
        REGISTER,
        FOUND_CANDIDATES,
        VOTE,
        COMPLETED
    }

    WorkflowStatus public workflow;
    uint256 public voteStartTimestamp;

    VotingNFT public votingNFT;

    struct Candidat {
        string nom;
        uint256 votes;
        uint256 fonds;
    }

    struct Election {
        string nom;
        uint256 debut;
        uint256 fin;
        Candidat[] candidats;
        uint256 totalVotes;
        uint256 votesBlancs;
    }

    mapping(uint256 => Election) public elections;
    mapping(address => mapping(uint256 => bool)) public aVote;
    mapping(address => bool) public electeurs;
    uint256 public electionCount;

    event ElectionCreee(uint256 indexed id, string nom);
    event CandidatAjoute(uint256 indexed electionId, string nom);
    event VoteEnregistre(
        address indexed electeur,
        uint256 indexed electionId,
        uint256 candidatId
    );
    event CandidatFinance(
        address indexed founder,
        uint256 indexed electionId,
        uint256 candidatId,
        uint256 montant
    );
    event WorkflowChange(WorkflowStatus nouveau);

    constructor(address _nft) {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
        _grantRole(FOUNDER_ROLE, msg.sender);

        votingNFT = VotingNFT(_nft);
        workflow = WorkflowStatus.REGISTER;
    }

    function enregistrerElecteur(address e) external onlyRole(ADMIN_ROLE) {
        electeurs[e] = true;
    }

    function creerElection(
        string memory nom,
        uint256 debut,
        uint256 fin
    ) external onlyRole(ADMIN_ROLE) {
        require(debut < fin, "Dates invalides");
        electionCount++;
        Election storage e = elections[electionCount];
        e.nom = nom;
        e.debut = debut;
        e.fin = fin;
        emit ElectionCreee(electionCount, nom);
    }

    function ajouterCandidat(
        uint256 id,
        string memory nom
    ) external onlyRole(ADMIN_ROLE) {
        require(workflow == WorkflowStatus.REGISTER, "Phase invalide");
        elections[id].candidats.push(Candidat(nom, 0, 0));
        emit CandidatAjoute(id, nom);
    }

    function changerWorkflow(WorkflowStatus s) external onlyRole(ADMIN_ROLE) {
        if (s == WorkflowStatus.VOTE) voteStartTimestamp = block.timestamp;
        workflow = s;
        emit WorkflowChange(s);
    }

    function financerCandidat(
        uint256 electionId,
        uint256 candidatId
    ) external payable onlyRole(FOUNDER_ROLE) {
        require(
            workflow == WorkflowStatus.FOUND_CANDIDATES,
            "Financement non autorise"
        );
        Election storage e = elections[electionId];
        require(
            candidatId > 0 && candidatId <= e.candidats.length,
            "Candidat invalide"
        );
        require(msg.value > 0, "Montant > 0");
        e.candidats[candidatId - 1].fonds += msg.value;
        emit CandidatFinance(msg.sender, electionId, candidatId, msg.value);
    }

    function voter(uint256 electionId, uint256 candidatId) external {
        require(workflow == WorkflowStatus.VOTE, "Vote ferme");
        require(electeurs[msg.sender], "Non electeur");
        require(!aVote[msg.sender][electionId], "Deja vote");
        require(!votingNFT.hasVotingNFT(msg.sender), "NFT deja recu");

        Election storage e = elections[electionId];
        require(
            block.timestamp >= e.debut && block.timestamp <= e.fin,
            "Hors periode"
        );

        aVote[msg.sender][electionId] = true;

        if (candidatId == 0) e.votesBlancs++;
        else e.candidats[candidatId - 1].votes++;

        e.totalVotes++;
        votingNFT.mintForVoter(msg.sender);

        emit VoteEnregistre(msg.sender, electionId, candidatId);
    }

    function resultat(
        uint256 id
    ) external view returns (uint256 gagnant, bool egalite) {
        require(workflow == WorkflowStatus.COMPLETED, "Non termine");
        Election storage e = elections[id];
        uint256 max;
        uint256 count;
        for (uint256 i; i < e.candidats.length; i++) {
            if (e.candidats[i].votes > max) {
                max = e.candidats[i].votes;
                gagnant = i + 1;
                count = 1;
            } else if (e.candidats[i].votes == max) count++;
        }
        egalite = count > 1;
    }
}
