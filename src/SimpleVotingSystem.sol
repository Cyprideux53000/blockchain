// SPDX-License-Identifier: MIT
pragma solidity 0.8.31;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./VotingNFT.sol";

enum WorkflowStatus {
    REGISTER_CANDIDATES,
    FOUND_CANDIDATES,
    VOTE,
    COMPLETED
}

enum TypeVote {
    OuiNon,
    Unique,
    Multiple
}

contract SimpleVotingSystem is Ownable, AccessControl {
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant FOUNDER_ROLE = keccak256("FOUNDER_ROLE");

    WorkflowStatus public currentWorkflowStatus;
    uint256 public timestampVoteActivation;

    mapping(uint256 => mapping(uint256 => uint256)) public fondsParCandidat;

    // Events
    event WorkflowChanged(
        WorkflowStatus indexed previousStatus,
        WorkflowStatus indexed newStatus,
        uint256 timestamp
    );
    event CandidatFinance(
        address indexed founder,
        uint256 indexed electionId,
        uint256 indexed candidatId,
        uint256 montant
    );
    event ElecteurEnregistre(
        address indexed adresse,
        string nom,
        string prenom
    );
    event VoteEnregistre(
        address indexed electeur,
        uint256 indexed electionId,
        uint256 candidatId
    );
    event VoteModifie(
        address indexed electeur,
        uint256 indexed electionId,
        uint256 ancienCandidatId,
        uint256 nouveauCandidatId
    );
    event ElectionCreee(
        uint256 indexed electionId,
        string nom,
        uint256 dateDebut,
        uint256 dateFin
    );
    event CandidatAjoute(
        uint256 indexed electionId,
        uint256 indexed candidatId,
        string nom
    );
    event CandidatModifie(
        uint256 indexed electionId,
        uint256 indexed candidatId,
        string nouveauNom
    );
    event CandidatSupprime(
        uint256 indexed electionId,
        uint256 indexed candidatId,
        string nom
    );
    event ResultatCalcule(
        uint256 indexed electionId,
        uint256[] gagnants,
        uint256 nombreVotes,
        bool estEgalite
    );
    event ResultatsArchives(
        uint256 indexed electionId,
        uint256[] gagnants,
        bool estEgalite,
        uint256 dateArchivage
    );

    struct Candidat {
        uint256 id;
        string nom;
        uint256 nombreVotes;
    }

    struct Electeur {
        address adresse;
        string nom;
        string prenom;
        mapping(uint256 => bool) aVote;
    }

    struct Election {
        uint256 id;
        string nom;
        uint256 dateDebut;
        uint256 dateFin;
        TypeVote typeVote;
        Candidat[] candidats;
        uint256 totalVotes;
        uint256 votesBlancs;
    }

    struct ResultatElection {
        uint256[] gagnants;
        uint256 nombreVotesGagnant;
        bool estEgalite;
        uint256 totalVotes;
        uint256 votesBlancs;
    }

    struct CandidatArchive {
        uint256 id;
        string nom;
        uint256 nombreVotes;
    }

    struct ResultatArchive {
        uint256 electionId;
        string nomElection;
        uint256 dateArchivage;
        uint256 totalVotes;
        uint256 votesBlancs;
        CandidatArchive[] candidats;
        uint256[] gagnants;
        bool estEgalite;
    }

    uint256 public constant MAX_CANDIDATS_PAR_ELECTION = 50;
    VotingNFT public votingNFT;

    mapping(uint256 => Candidat) public candidates;
    uint256[] private candidateIds;

    mapping(address => Electeur) private electeurs;
    mapping(address => bool) public estElecteurEnregistre;
    address[] private adressesElecteurs;

    mapping(uint256 => Election) private elections;
    uint256 private prochainIdElection;
    uint256[] private idsElections;

    mapping(address => mapping(uint256 => uint256)) private votesElecteurs;

    mapping(uint256 => ResultatArchive) private resultatsArchives;
    mapping(uint256 => bool) private estArchive;

    constructor(address _votingNFT) Ownable(msg.sender) {
        prochainIdElection = 1;

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);

        currentWorkflowStatus = WorkflowStatus.REGISTER_CANDIDATES;

        if (_votingNFT == address(0)) {
            votingNFT = new VotingNFT();
        } else {
            votingNFT = VotingNFT(_votingNFT);
        }
    }

    function enregistrerElecteur(
        address _adresse,
        string memory _nom,
        string memory _prenom
    ) public onlyRole(ADMIN_ROLE) {
        require(_adresse != address(0), "Adresse invalide");
        require(!estElecteurEnregistre[_adresse], "Electeur deja enregistre");
        require(bytes(_nom).length > 0, "Le nom ne peut pas etre vide");
        require(bytes(_prenom).length > 0, "Le prenom ne peut pas etre vide");

        Electeur storage nouvelElecteur = electeurs[_adresse];
        nouvelElecteur.adresse = _adresse;
        nouvelElecteur.nom = _nom;
        nouvelElecteur.prenom = _prenom;

        estElecteurEnregistre[_adresse] = true;
        adressesElecteurs.push(_adresse);

        emit ElecteurEnregistre(_adresse, _nom, _prenom);
    }

    function verifierElecteurEnregistre(
        address _adresse
    ) public view returns (bool) {
        return estElecteurEnregistre[_adresse];
    }

    function obtenirInfoElecteur(
        address _adresse
    )
        public
        view
        returns (address adresse, string memory nom, string memory prenom)
    {
        require(estElecteurEnregistre[_adresse], "Electeur non enregistre");
        Electeur storage electeur = electeurs[_adresse];
        return (electeur.adresse, electeur.nom, electeur.prenom);
    }

    function obtenirNombreElecteurs() public view returns (uint256) {
        return adressesElecteurs.length;
    }

    function aVotePourElection(
        address _adresse,
        uint256 _electionId
    ) public view returns (bool) {
        require(estElecteurEnregistre[_adresse], "Electeur non enregistre");
        return electeurs[_adresse].aVote[_electionId];
    }

    function creerElection(
        string memory _nom,
        uint256 _dateDebut,
        uint256 _dateFin,
        TypeVote _typeVote
    ) public onlyRole(ADMIN_ROLE) returns (uint256) {
        require(
            bytes(_nom).length > 0,
            "Le nom de l'election ne peut pas etre vide"
        );
        require(
            _dateDebut > block.timestamp,
            "La date de debut doit etre dans le futur"
        );
        require(
            _dateFin > _dateDebut,
            "La date de fin doit etre apres la date de debut"
        );

        uint256 nouvelIdElection = prochainIdElection;
        prochainIdElection++;

        Election storage nouvelleElection = elections[nouvelIdElection];
        nouvelleElection.id = nouvelIdElection;
        nouvelleElection.nom = _nom;
        nouvelleElection.dateDebut = _dateDebut;
        nouvelleElection.dateFin = _dateFin;
        nouvelleElection.typeVote = _typeVote;
        nouvelleElection.totalVotes = 0;
        nouvelleElection.votesBlancs = 0;

        idsElections.push(nouvelIdElection);

        emit ElectionCreee(nouvelIdElection, _nom, _dateDebut, _dateFin);

        return nouvelIdElection;
    }

    function changerWorkflow(
        WorkflowStatus _nouveauStatut
    ) public onlyRole(ADMIN_ROLE) {
        WorkflowStatus ancienStatut = currentWorkflowStatus;

        if (ancienStatut == WorkflowStatus.REGISTER_CANDIDATES) {
            require(
                _nouveauStatut == WorkflowStatus.FOUND_CANDIDATES,
                "Transition invalide: REGISTER_CANDIDATES -> FOUND_CANDIDATES uniquement"
            );
        } else if (ancienStatut == WorkflowStatus.FOUND_CANDIDATES) {
            require(
                _nouveauStatut == WorkflowStatus.VOTE,
                "Transition invalide: FOUND_CANDIDATES -> VOTE uniquement"
            );
            timestampVoteActivation = block.timestamp;
        } else if (ancienStatut == WorkflowStatus.VOTE) {
            require(
                _nouveauStatut == WorkflowStatus.COMPLETED,
                "Transition invalide: VOTE -> COMPLETED uniquement"
            );
            for (uint256 i = 0; i < idsElections.length; i++) {
                uint256 electionId = idsElections[i];
                if (!estArchive[electionId]) {
                    _archiverResultats(electionId);
                }
            }
        } else {
            revert("Workflow deja termine");
        }

        currentWorkflowStatus = _nouveauStatut;
        emit WorkflowChanged(ancienStatut, _nouveauStatut, block.timestamp);
    }

    function obtenirElection(
        uint256 _electionId
    )
        public
        view
        returns (
            uint256 id,
            string memory nom,
            uint256 dateDebut,
            uint256 dateFin,
            TypeVote typeVote,
            uint256 nombreCandidats,
            uint256 totalVotes,
            uint256 votesBlancs
        )
    {
        require(
            _electionId > 0 && _electionId < prochainIdElection,
            "Election inexistante"
        );
        Election storage election = elections[_electionId];
        return (
            election.id,
            election.nom,
            election.dateDebut,
            election.dateFin,
            election.typeVote,
            election.candidats.length,
            election.totalVotes,
            election.votesBlancs
        );
    }

    function obtenirNombreElections() public view returns (uint256) {
        return idsElections.length;
    }

    function ajouterCandidatElection(
        uint256 _electionId,
        string memory _nomCandidat
    ) public onlyRole(ADMIN_ROLE) returns (uint256) {
        require(
            _electionId > 0 && _electionId < prochainIdElection,
            "Election inexistante"
        );
        require(
            bytes(_nomCandidat).length > 0,
            "Le nom du candidat ne peut pas etre vide"
        );
        require(
            currentWorkflowStatus == WorkflowStatus.REGISTER_CANDIDATES,
            "Les candidats ne peuvent etre ajoutes qu'en phase REGISTER_CANDIDATES"
        );

        Election storage election = elections[_electionId];
        require(
            election.candidats.length < MAX_CANDIDATS_PAR_ELECTION,
            "Nombre maximal de candidats atteint"
        );

        uint256 candidatId = election.candidats.length + 1;
        election.candidats.push(Candidat(candidatId, _nomCandidat, 0));

        emit CandidatAjoute(_electionId, candidatId, _nomCandidat);

        return candidatId;
    }

    function modifierCandidatElection(
        uint256 _electionId,
        uint256 _candidatId,
        string memory _nouveauNom
    ) public onlyRole(ADMIN_ROLE) {
        require(
            _electionId > 0 && _electionId < prochainIdElection,
            "Election inexistante"
        );
        require(
            bytes(_nouveauNom).length > 0,
            "Le nom du candidat ne peut pas etre vide"
        );
        require(
            currentWorkflowStatus == WorkflowStatus.REGISTER_CANDIDATES,
            "Les candidats ne peuvent etre modifies qu'en phase REGISTER_CANDIDATES"
        );

        Election storage election = elections[_electionId];
        require(
            _candidatId > 0 && _candidatId <= election.candidats.length,
            "ID de candidat invalide"
        );

        election.candidats[_candidatId - 1].nom = _nouveauNom;

        emit CandidatModifie(_electionId, _candidatId, _nouveauNom);
    }

    function supprimerCandidatElection(
        uint256 _electionId,
        uint256 _candidatId
    ) public onlyRole(ADMIN_ROLE) {
        require(
            _electionId > 0 && _electionId < prochainIdElection,
            "Election inexistante"
        );
        require(
            currentWorkflowStatus == WorkflowStatus.REGISTER_CANDIDATES,
            "Les candidats ne peuvent etre supprimes qu'en phase REGISTER_CANDIDATES"
        );

        Election storage election = elections[_electionId];
        require(
            _candidatId > 0 && _candidatId <= election.candidats.length,
            "ID de candidat invalide"
        );

        string memory nomCandidat = election.candidats[_candidatId - 1].nom;

        uint256 indexASupprimer = _candidatId - 1;
        uint256 dernierIndex = election.candidats.length - 1;

        if (indexASupprimer != dernierIndex) {
            election.candidats[indexASupprimer] = election.candidats[
                dernierIndex
            ];
            election.candidats[indexASupprimer].id = _candidatId;
        }

        election.candidats.pop();

        emit CandidatSupprime(_electionId, _candidatId, nomCandidat);
    }

    function obtenirCandidatsElection(
        uint256 _electionId
    ) public view returns (Candidat[] memory) {
        require(
            _electionId > 0 && _electionId < prochainIdElection,
            "Election inexistante"
        );
        return elections[_electionId].candidats;
    }

    function obtenirNombreCandidatsElection(
        uint256 _electionId
    ) public view returns (uint256) {
        require(
            _electionId > 0 && _electionId < prochainIdElection,
            "Election inexistante"
        );
        return elections[_electionId].candidats.length;
    }

    function financerCandidat(
        uint256 _electionId,
        uint256 _candidatId
    ) public payable onlyRole(FOUNDER_ROLE) {
        require(
            _electionId > 0 && _electionId < prochainIdElection,
            "Election inexistante"
        );
        require(msg.value > 0, "Le montant doit etre superieur a 0");
        require(
            currentWorkflowStatus == WorkflowStatus.FOUND_CANDIDATES,
            "Le financement n'est possible qu'en phase FOUND_CANDIDATES"
        );

        Election storage election = elections[_electionId];
        require(
            _candidatId > 0 && _candidatId <= election.candidats.length,
            "ID de candidat invalide"
        );

        fondsParCandidat[_electionId][_candidatId] += msg.value;

        emit CandidatFinance(msg.sender, _electionId, _candidatId, msg.value);
    }

    function obtenirFondsCandidat(
        uint256 _electionId,
        uint256 _candidatId
    ) public view returns (uint256) {
        require(
            _electionId > 0 && _electionId < prochainIdElection,
            "Election inexistante"
        );
        Election storage election = elections[_electionId];
        require(
            _candidatId > 0 && _candidatId <= election.candidats.length,
            "ID de candidat invalide"
        );
        return fondsParCandidat[_electionId][_candidatId];
    }

    function obtenirResultatElection(
        uint256 _electionId
    ) public view returns (ResultatElection memory) {
        require(
            _electionId > 0 && _electionId < prochainIdElection,
            "Election inexistante"
        );
        Election storage election = elections[_electionId];
        require(election.candidats.length > 0, "Election sans candidats");

        uint256 maxVotes = 0;
        for (uint256 i = 0; i < election.candidats.length; i++) {
            if (election.candidats[i].nombreVotes > maxVotes) {
                maxVotes = election.candidats[i].nombreVotes;
            }
        }

        uint256[] memory gagnants = new uint256[](election.candidats.length);
        uint256 countGagnants = 0;

        for (uint256 i = 0; i < election.candidats.length; i++) {
            if (election.candidats[i].nombreVotes == maxVotes) {
                gagnants[countGagnants] = election.candidats[i].id;
                countGagnants++;
            }
        }

        uint256[] memory gagnantsFinaux = new uint256[](countGagnants);
        for (uint256 i = 0; i < countGagnants; i++) {
            gagnantsFinaux[i] = gagnants[i];
        }

        return
            ResultatElection({
                gagnants: gagnantsFinaux,
                nombreVotesGagnant: maxVotes,
                estEgalite: countGagnants > 1,
                totalVotes: election.totalVotes,
                votesBlancs: election.votesBlancs
            });
    }

    function verifierEgalite(uint256 _electionId) public view returns (bool) {
        ResultatElection memory resultat = obtenirResultatElection(_electionId);
        return resultat.estEgalite;
    }

    function obtenirGagnants(
        uint256 _electionId
    ) public view returns (uint256[] memory) {
        ResultatElection memory resultat = obtenirResultatElection(_electionId);
        return resultat.gagnants;
    }

    function designerVainqueur(
        uint256 _electionId
    )
        public
        view
        returns (
            uint256[] memory gagnants,
            bool estEgalite,
            uint256 nombreVotesGagnant
        )
    {
        require(
            _electionId > 0 && _electionId < prochainIdElection,
            "Election inexistante"
        );
        require(
            currentWorkflowStatus == WorkflowStatus.COMPLETED,
            "Le vainqueur ne peut etre designe qu'en phase COMPLETED"
        );

        ResultatElection memory resultat = obtenirResultatElection(_electionId);

        return (
            resultat.gagnants,
            resultat.estEgalite,
            resultat.nombreVotesGagnant
        );
    }

    function obtenirResultatsFinaux(
        uint256 _electionId
    ) public view returns (Candidat[] memory) {
        require(
            _electionId > 0 && _electionId < prochainIdElection,
            "Election inexistante"
        );
        Election storage election = elections[_electionId];

        // CORRECTION: Utilisation de owner() au lieu de owner
        if (msg.sender != owner()) {
            require(
                currentWorkflowStatus == WorkflowStatus.COMPLETED,
                "Les resultats ne sont accessibles qu'en phase COMPLETED"
            );
        }

        return election.candidats;
    }

    function sontResultatsAccessibles(
        uint256 _electionId
    ) public view returns (bool) {
        require(
            _electionId > 0 && _electionId < prochainIdElection,
            "Election inexistante"
        );
        return (currentWorkflowStatus == WorkflowStatus.COMPLETED);
    }

    function _archiverResultats(uint256 _electionId) private {
        require(!estArchive[_electionId], "Resultats deja archives");

        Election storage election = elections[_electionId];

        ResultatElection memory resultat = obtenirResultatElection(_electionId);

        ResultatArchive storage archive = resultatsArchives[_electionId];
        archive.electionId = _electionId;
        archive.nomElection = election.nom;
        archive.dateArchivage = block.timestamp;
        archive.totalVotes = election.totalVotes;
        archive.votesBlancs = election.votesBlancs;
        archive.gagnants = resultat.gagnants;
        archive.estEgalite = resultat.estEgalite;

        for (uint256 i = 0; i < election.candidats.length; i++) {
            archive.candidats.push(
                CandidatArchive({
                    id: election.candidats[i].id,
                    nom: election.candidats[i].nom,
                    nombreVotes: election.candidats[i].nombreVotes
                })
            );
        }

        estArchive[_electionId] = true;

        emit ResultatsArchives(
            _electionId,
            resultat.gagnants,
            resultat.estEgalite,
            block.timestamp
        );
    }

    function obtenirResultatsArchives(
        uint256 _electionId
    ) public view returns (ResultatArchive memory) {
        require(
            estArchive[_electionId],
            "Aucun resultat archive pour cette election"
        );
        return resultatsArchives[_electionId];
    }

    function sontResultatsArchives(
        uint256 _electionId
    ) public view returns (bool) {
        return estArchive[_electionId];
    }

    function addCandidate(string memory _name) public onlyRole(ADMIN_ROLE) {
        require(bytes(_name).length > 0, "Candidate name cannot be empty");
        uint256 candidateId = candidateIds.length + 1;
        candidates[candidateId] = Candidat(candidateId, _name, 0);
        candidateIds.push(candidateId);
    }

    function vote(uint256 _candidateId) public {
        voteForElection(0, _candidateId);
    }

    function voteForElection(uint256 _electionId, uint256 _candidateId) public {
        require(estElecteurEnregistre[msg.sender], "Electeur non enregistre");
        require(
            !votingNFT.hasVotingNFT(msg.sender),
            "Vous possedez deja un NFT de vote"
        );
        require(
            _electionId > 0 && _electionId < prochainIdElection,
            "Election inexistante"
        );
        require(
            currentWorkflowStatus == WorkflowStatus.VOTE,
            "Le vote n'est possible qu'en phase VOTE"
        );
        require(
            block.timestamp >= timestampVoteActivation + 1 hours,
            "Le vote n'est possible que 1 heure apres l'activation de la phase VOTE"
        );

        Election storage election = elections[_electionId];

        require(
            block.timestamp >= election.dateDebut,
            "L'election n'a pas encore commence"
        );
        require(block.timestamp <= election.dateFin, "L'election est terminee");

        require(
            !electeurs[msg.sender].aVote[_electionId],
            "Vous avez deja vote pour cette election"
        );

        require(
            _candidateId <= election.candidats.length,
            "ID de candidat invalide pour cette election"
        );

        electeurs[msg.sender].aVote[_electionId] = true;
        votesElecteurs[msg.sender][_electionId] = _candidateId;

        if (_candidateId == 0) {
            election.votesBlancs += 1;
        } else {
            election.candidats[_candidateId - 1].nombreVotes += 1;
        }

        election.totalVotes += 1;

        votingNFT.mintForVoter(msg.sender);
        emit VoteEnregistre(msg.sender, _electionId, _candidateId);
    }

    function modifierVote(
        uint256 _electionId,
        uint256 _nouveauCandidatId
    ) public {
        require(estElecteurEnregistre[msg.sender], "Electeur non enregistre");
        require(
            _electionId > 0 && _electionId < prochainIdElection,
            "Election inexistante"
        );
        require(
            currentWorkflowStatus == WorkflowStatus.VOTE,
            "Le vote n'est possible qu'en phase VOTE"
        );

        Election storage election = elections[_electionId];

        require(
            block.timestamp >= election.dateDebut,
            "L'election n'a pas encore commence"
        );
        require(block.timestamp <= election.dateFin, "L'election est terminee");

        require(
            electeurs[msg.sender].aVote[_electionId],
            "Vous n'avez pas encore vote pour cette election"
        );

        require(
            _nouveauCandidatId <= election.candidats.length,
            "ID de candidat invalide pour cette election"
        );

        uint256 ancienCandidatId = votesElecteurs[msg.sender][_electionId];

        require(
            ancienCandidatId != _nouveauCandidatId,
            "Vous votez pour le meme candidat"
        );

        if (ancienCandidatId == 0) {
            election.votesBlancs -= 1;
        } else {
            election.candidats[ancienCandidatId - 1].nombreVotes -= 1;
        }

        if (_nouveauCandidatId == 0) {
            election.votesBlancs += 1;
        } else {
            election.candidats[_nouveauCandidatId - 1].nombreVotes += 1;
        }

        votesElecteurs[msg.sender][_electionId] = _nouveauCandidatId;
        emit VoteModifie(
            msg.sender,
            _electionId,
            ancienCandidatId,
            _nouveauCandidatId
        );
    }

    function obtenirVoteElecteur(
        address _adresse,
        uint256 _electionId
    ) public view returns (uint256) {
        require(estElecteurEnregistre[_adresse], "Electeur non enregistre");
        require(
            _electionId > 0 && _electionId < prochainIdElection,
            "Election inexistante"
        );
        require(
            electeurs[_adresse].aVote[_electionId],
            "L'electeur n'a pas vote pour cette election"
        );
        return votesElecteurs[_adresse][_electionId];
    }

    function getTotalVotes(uint256 _candidateId) public view returns (uint256) {
        require(
            _candidateId > 0 && _candidateId <= candidateIds.length,
            "Invalid candidate ID"
        );
        return candidates[_candidateId].nombreVotes;
    }

    function getCandidatesCount() public view returns (uint256) {
        return candidateIds.length;
    }

    function getCandidate(
        uint256 _candidateId
    ) public view returns (Candidat memory) {
        require(
            _candidateId > 0 && _candidateId <= candidateIds.length,
            "Invalid candidate ID"
        );
        return candidates[_candidateId];
    }
}
