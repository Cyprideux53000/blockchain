# 🗳️ Simple Voting System

Ce projet implémente un système de vote décentralisé sur Ethereum, intégrant une gestion de rôles, un workflow strict et un système de NFT de vote afin de garantir l’intégrité du scrutin.

Le smart contract est développé en Solidity en s’appuyant sur les librairies OpenZeppelin, testé avec Foundry et déployé sur le testnet Sepolia.

---

## 📌 Fonctionnalités principales

### Gestion des rôles
- **ADMIN**
  - Enregistrement des candidats
  - Changement du statut du workflow
- **FOUNDER**
  - Envoi de fonds aux candidats
- **Votants**
  - Aucun rôle requis pour voter

Les rôles sont gérés via `AccessControl` d’OpenZeppelin.

---

### Workflow du vote
Le smart contract suit un workflow strict composé de 4 statuts :

1. `REGISTER_CANDIDATES`  
   → Enregistrement des candidats (ADMIN uniquement)

2. `FOUND_CANDIDATES`  
   → Phase intermédiaire de validation

3. `VOTE`  
   → Vote ouvert après un délai d’1 heure

4. `COMPLETED`  
   → Clôture du vote et désignation du vainqueur

Chaque fonction ne peut être exécutée que pendant sa phase correspondante.

---

### Système de vote
- Un utilisateur ne peut voter **qu’une seule fois**
- Le vote est possible **uniquement 1 heure après** le passage au statut `VOTE`
- Le vote est bloqué si le votant possède déjà un **NFT de vote**

---

### NFT de vote
- Un smart contract NFT simple est utilisé
- Un NFT est minté automatiquement lors du vote
- La possession de ce NFT empêche tout nouveau vote

---

### Résultat du vote
- Une fonction permet de désigner le vainqueur
- Elle est accessible uniquement lorsque le workflow est à l’état `COMPLETED`

---

## 🧪 Tests
- Tests unitaires écrits avec **Foundry**
- Couverture des cas suivants :
  - Gestion des rôles
  - Respect du workflow
  - Restrictions temporelles
  - Attribution du NFT
  - Calcul du vainqueur

---

## 🚀 Déploiement
- Déploiement effectué sur le testnet **Sepolia**
- Script de déploiement fourni

### Transactions Sepolia
- Smart Contract Voting :  
  👉 `URL_TRANSACTION`
- Smart Contract NFT :  
  👉 `URL_TRANSACTION`

---

## 🔧 Technologies utilisées
- Solidity
- OpenZeppelin
- Foundry
- Ethereum Sepolia

---

## 🔮 Améliorations sur le projet

### 🔁 Changement de vote
- Autoriser un votant à modifier son vote tant que le statut est `VOTE`
- Mettre à jour dynamiquement le comptage des voix

### 🗳️ Types de vote
- Vote **OUI / NON**
- Vote à **choix unique**
- Vote à **choix multiple**
- Pondération des votes (ex : en fonction d’un NFT ou d’un token)

### 🗂️ Archivage des votes
- Archivage des résultats une fois le vote terminé
- Historique des scrutins passés
- Possibilité de relancer un nouveau vote sans redéployer le smart contract

---

## 📄 Licence
Projet à but pédagogique.
