// SPDX-License-Identifier: MIT
pragma solidity 0.8.31;

import "forge-std/Test.sol";
import "../src/SimpleVotingSystem.sol";
import "../src/VotingNFT.sol";

contract SimpleVotingSystemTest is Test {
    SimpleVotingSystem public voting;
    VotingNFT public nft;

    address admin;
    address voter1;
    address voter2;
    address voter3;

    uint256 electionId;
    uint256 start;
    uint256 end;

    function setUp() public {
        admin = address(this);
        voter1 = address(0x1);
        voter2 = address(0x2);
        voter3 = address(0x3);

        nft = new VotingNFT();
        voting = new SimpleVotingSystem(address(nft));

        // Enregistrer les électeurs
        voting.enregistrerElecteur(voter1);
        voting.enregistrerElecteur(voter2);
        voting.enregistrerElecteur(voter3);

        // Création d'une élection
        start = block.timestamp + 1 hours;
        end = start + 1 days;

        voting.creerElection("Election Test", start, end);
        electionId = voting.electionCount();

        // Ajouter des candidats (seulement en phase REGISTER_CANDIDATES)
        voting.ajouterCandidat(electionId, "Alice");
        voting.ajouterCandidat(electionId, "Bob");
        voting.ajouterCandidat(electionId, "Charlie");
    }

    // Fonction interne pour passer à la phase VOTE
    function ouvrirElection() internal {
        voting.changerWorkflow(
            SimpleVotingSystem.WorkflowStatus.FOUND_CANDIDATES
        );
        voting.changerWorkflow(SimpleVotingSystem.WorkflowStatus.VOTE);
        // Simuler 1h après activation du vote
        vm.warp(block.timestamp + 1 hours + 1);
    }

    // Fonction interne pour fermer l'élection
    function fermerElection() internal {
        voting.changerWorkflow(SimpleVotingSystem.WorkflowStatus.COMPLETED);
    }

    function testInitialWorkflow() public {
        assertEq(
            uint256(voting.workflow()),
            uint256(SimpleVotingSystem.WorkflowStatus.REGISTER)
        );
    }

    function testWorkflowTransitions() public {
        voting.changerWorkflow(
            SimpleVotingSystem.WorkflowStatus.FOUND_CANDIDATES
        );
        assertEq(
            uint256(voting.workflow()),
            uint256(SimpleVotingSystem.WorkflowStatus.FOUND_CANDIDATES)
        );

        voting.changerWorkflow(SimpleVotingSystem.WorkflowStatus.VOTE);
        assertEq(
            uint256(voting.workflow()),
            uint256(SimpleVotingSystem.WorkflowStatus.VOTE)
        );

        voting.changerWorkflow(SimpleVotingSystem.WorkflowStatus.COMPLETED);
        assertEq(
            uint256(voting.workflow()),
            uint256(SimpleVotingSystem.WorkflowStatus.COMPLETED)
        );
    }

    /*function testCannotVoteTwice() public {
        ouvrirElection();

        vm.prank(voter1);
        voting.voter(electionId, 1);

        vm.prank(voter1);
        vm.expectRevert("Vous possedez deja un NFT de vote");
        voting.voter(electionId, 2);
    }*/

    /*function testWinnerIsCorrect() public {
        ouvrirElection();

        vm.prank(voter1);
        voting.voter(electionId, 1);

        vm.prank(voter2);
        voting.voter(electionId, 1);

        vm.prank(voter3);
        voting.voter(electionId, 2);

        fermerElection();

        (uint256 gagnant, bool egalite) = voting.resultat(electionId);
        assertEq(gagnant, 1);
    }*/

    /*function testVoteOutsidePeriodFails() public {
        voting.changerWorkflow(SimpleVotingSystem.WorkflowStatus.VOTE);

        vm.prank(voter1);
        vm.expectRevert("Le vote n'est possible qu'en phase VOTE");
        voting.voter(electionId, 1);
    }*/

    function testElectionWithoutCandidates() public {
        voting.creerElection(
            "Vide",
            block.timestamp + 1 hours,
            block.timestamp + 2 days
        );
        uint256 emptyId = voting.electionCount();

        voting.changerWorkflow(
            SimpleVotingSystem.WorkflowStatus.FOUND_CANDIDATES
        );
        voting.changerWorkflow(SimpleVotingSystem.WorkflowStatus.VOTE);
        vm.warp(block.timestamp + 2 hours);

        vm.expectRevert("Non termine");
        voting.resultat(emptyId);
    }
}
