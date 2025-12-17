// SPDX-License-Identifier: MIT
pragma solidity 0.8.31;

import "forge-std/Test.sol";
import "../src/SimpleVotingSystem.sol";
import "../src/VotingNFT.sol";

/**
 * @title UnifiedVotingSystemTest
 * @notice Fichier unique regroupant tous les tests :
 *  - Rôles & workflow
 *  - Vote, NFT, financement
 *  - Résultats, égalités, archivage
 */
contract UnifiedVotingSystemTest is Test {
    SimpleVotingSystem public voting;
    VotingNFT public nft;

    address public owner;
    address public admin;
    address public founder;
    address public voter;

    address public voter1;
    address public voter2;
    address public voter3;
    address public voter4;

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant FOUNDER_ROLE = keccak256("FOUNDER_ROLE");

    uint256 public electionId;
    uint256 public startTime;
    uint256 public endTime;

    // =============================================================
    // SETUP
    // =============================================================

    function setUp() public {
        owner = address(this);
        admin = address(0x1);
        founder = address(0x2);
        voter = address(0x3);

        voter1 = address(0x11);
        voter2 = address(0x12);
        voter3 = address(0x13);
        voter4 = address(0x14);

        nft = new VotingNFT();
        voting = new SimpleVotingSystem(address(nft));
        nft.transferOwnership(address(voting));

        vm.deal(founder, 10 ether);

        // Election standard utilisée par la majorité des tests
        startTime = block.timestamp + 1 hours;
        endTime = startTime + 1 days;
        electionId = voting.creerElection(
            "Election Test",
            startTime,
            endTime,
            TypeVote.Unique
        );

        voting.ajouterCandidatElection(electionId, "Candidat A");
        voting.ajouterCandidatElection(electionId, "Candidat B");
        voting.ajouterCandidatElection(electionId, "Candidat C");

        voting.enregistrerElecteur(voter1, "Dupont", "Jean");
        voting.enregistrerElecteur(voter2, "Martin", "Marie");
        voting.enregistrerElecteur(voter3, "Bernard", "Pierre");
        voting.enregistrerElecteur(voter4, "Durand", "Sophie");
    }

    // =============================================================
    // HELPERS
    // =============================================================

    function ouvrirElection() internal {
        voting.changerWorkflow(WorkflowStatus.FOUND_CANDIDATES);
        voting.changerWorkflow(WorkflowStatus.VOTE);
        vm.warp(block.timestamp + 1 hours);
    }

    function fermerElection() internal {
        voting.changerWorkflow(WorkflowStatus.COMPLETED);
    }

    // =============================================================
    // ROLES & WORKFLOW
    // =============================================================

    function testInitialRoles() public view {
        assertTrue(voting.hasRole(voting.DEFAULT_ADMIN_ROLE(), owner));
        assertTrue(voting.hasRole(ADMIN_ROLE, owner));
    }

    function testGrantAndRevokeRoles() public {
        voting.grantRole(ADMIN_ROLE, admin);
        assertTrue(voting.hasRole(ADMIN_ROLE, admin));
        voting.revokeRole(ADMIN_ROLE, admin);
        assertFalse(voting.hasRole(ADMIN_ROLE, admin));
    }

    function testWorkflowTransitions() public {
        assertEq(uint256(voting.currentWorkflowStatus()), 0);
        voting.changerWorkflow(WorkflowStatus.FOUND_CANDIDATES);
        voting.changerWorkflow(WorkflowStatus.VOTE);
        voting.changerWorkflow(WorkflowStatus.COMPLETED);
        assertEq(uint256(voting.currentWorkflowStatus()), 3);
    }

    // =============================================================
    // FUNDING & VOTE RULES
    // =============================================================

    function testFundingCandidate() public {
        voting.grantRole(FOUNDER_ROLE, founder);
        voting.changerWorkflow(WorkflowStatus.FOUND_CANDIDATES);
        vm.prank(founder);
        voting.financerCandidat{value: 1 ether}(electionId, 1);
        assertEq(voting.fondsParCandidat(electionId, 1), 1 ether);
    }

    function testCannotVoteBeforeVotePhase() public {
        vm.prank(voter1);
        vm.expectRevert("Le vote n'est possible qu'en phase VOTE");
        voting.voteForElection(electionId, 1);
    }

    // =============================================================
    // NFT
    // =============================================================

    function testNFTMintedAndPreventDoubleVote() public {
        vm.warp(startTime);
        ouvrirElection();

        assertFalse(nft.hasVotingNFT(voter1));

        vm.prank(voter1);
        voting.voteForElection(electionId, 1);

        assertTrue(nft.hasVotingNFT(voter1));
        assertEq(nft.totalSupply(), 1);

        vm.prank(voter1);
        vm.expectRevert("Vous possedez deja un NFT de vote");
        voting.voteForElection(electionId, 1);
    }

    // =============================================================
    // RESULTS & TIES
    // =============================================================

    function testNoTieResult() public {
        vm.warp(startTime);
        ouvrirElection();

        vm.prank(voter1);
        voting.voteForElection(electionId, 1);
        vm.prank(voter2);
        voting.voteForElection(electionId, 1);
        vm.prank(voter3);
        voting.voteForElection(electionId, 2);

        SimpleVotingSystem.ResultatElection memory r = voting
            .obtenirResultatElection(electionId);
        assertEq(r.gagnants.length, 1);
        assertEq(r.gagnants[0], 1);
        assertFalse(r.estEgalite);
        assertEq(r.totalVotes, 3);
    }

    function testTieDetection() public {
        vm.warp(startTime);
        ouvrirElection();

        vm.prank(voter1);
        voting.voteForElection(electionId, 1);
        vm.prank(voter2);
        voting.voteForElection(electionId, 2);

        SimpleVotingSystem.ResultatElection memory r = voting
            .obtenirResultatElection(electionId);
        assertTrue(r.estEgalite);
        assertEq(r.gagnants.length, 2);
    }

    function testBlankVotesDoNotWin() public {
        vm.warp(startTime);
        ouvrirElection();

        vm.prank(voter1);
        voting.voteForElection(electionId, 0);
        vm.prank(voter2);
        voting.voteForElection(electionId, 1);

        SimpleVotingSystem.ResultatElection memory r = voting
            .obtenirResultatElection(electionId);
        assertEq(r.gagnants.length, 1);
        assertEq(r.gagnants[0], 1);
        assertEq(r.votesBlancs, 1);
    }

    // =============================================================
    // ARCHIVING & ACCESS
    // =============================================================

    function testArchivingOnClose() public {
        vm.warp(startTime);
        ouvrirElection();

        vm.prank(voter1);
        voting.voteForElection(electionId, 1);

        fermerElection();
        assertTrue(voting.sontResultatsArchives(electionId));
    }

    function testArchiveIntegrity() public {
        vm.warp(startTime);
        ouvrirElection();

        vm.prank(voter1);
        voting.voteForElection(electionId, 1);
        vm.prank(voter2);
        voting.voteForElection(electionId, 1);
        vm.prank(voter3);
        voting.voteForElection(electionId, 2);

        fermerElection();

        SimpleVotingSystem.ResultatArchive memory a = voting
            .obtenirResultatsArchives(electionId);
        assertEq(a.totalVotes, 3);
        assertEq(a.candidats[0].nombreVotes, 2);
        assertEq(a.candidats[1].nombreVotes, 1);
    }

    function testResultsAccessRules() public {
        vm.prank(voter1);
        vm.expectRevert(
            "Les resultats ne sont accessibles qu'en phase COMPLETED"
        );
        voting.obtenirResultatsFinaux(electionId);

        vm.warp(startTime);
        ouvrirElection();
        vm.prank(voter1);
        vm.expectRevert(
            "Les resultats ne sont accessibles qu'en phase COMPLETED"
        );
        voting.obtenirResultatsFinaux(electionId);

        fermerElection();
        SimpleVotingSystem.Candidat[] memory c = voting.obtenirResultatsFinaux(
            electionId
        );
        assertEq(c.length, 3);
    }

    // =============================================================
    // EDGE CASE
    // =============================================================

    function testElectionWithoutCandidatesReverts() public {
        uint256 emptyId = voting.creerElection(
            "Election Vide",
            block.timestamp + 1 hours,
            block.timestamp + 2 days,
            TypeVote.Unique
        );

        vm.expectRevert("Election sans candidats");
        voting.obtenirResultatElection(emptyId);
    }
}
