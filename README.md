# Outil décisionnel — Ventes & Logistique (PostgreSQL → Data Warehouse → Power BI)

## Aperçu
Ce projet met en place une chaîne décisionnelle complète autour d’un cas “Ventes / Commandes / Produits / Livraison” :
- import de données dans un schéma OLTP PostgreSQL,
- construction d’un Data Warehouse en étoile,
- création d’un rapport Power BI pour analyser la performance commerciale et logistique.

Le but est de passer de données transactionnelles (OLTP) à une lecture “métier” (KPI, axes d’analyse, pages thématiques).

---

## Objectifs
- Structurer une base OLTP (clients, commandes, lignes, produits, transporteurs…)
- Construire un DW en étoile (dimensions + faits) pour faciliter l’analyse
- Alimenter le DW depuis l’OLTP (INSERT…SELECT / upsert)
- Produire un rapport Power BI clair, filtrable et orienté décision

---

## Stack
- **PostgreSQL** (OLTP + DW)
- **SQL** (modélisation, ETL SQL, vues / requêtes métiers)
- **Power BI** (Import, Power Query, DAX, visuels, tooltips)
- **CSV** (données sources)

---

## Données & Modèles

### OLTP (schéma `entreprise`)
Tables principales :
- `_client`, `_commande`, `_detailcommande`
- `_produit`, `_categorie`, `_fournisseur`
- `_employe`, `_transporteur`

Logique métier :
- une commande a plusieurs lignes (`_detailcommande`)
- une ligne de commande référence un produit
- une commande est rattachée à un client, un employé et éventuellement un transporteur

### Data Warehouse (schéma `entreprise_dw`)
Dimensions :
- `dimTemps`, `dimClient`, `dimEmploye`, `dimTransporteur`
- `dimGeoLivraison` (pays/région/ville de livraison)
- `dimProduit` (dénormalisée : produit + catégorie + fournisseur)

Faits :
- `faitVentes` (grain = **ligne de commande**) : quantité, prix, remise, montants brut/net, port alloué, nocom
- `faitLivraisons` (grain = **commande**) : port, délais, écarts objectif/envoi, dates (commande/envoi/objectif), nocom

---

## Calculs clés
- **Montant brut** = qte × prixunit  
- **Montant net** = qte × prixunit × (1 − remise)

### Port alloué (éviter le double comptage)
Le port est au niveau commande. Pour analyser par ligne, il est réparti au prorata du montant net de chaque ligne :
- `port_alloc_ligne = port_commande × (montant_net_ligne / total_net_commande)`

---

## Contrôles de cohérence (exemples)
- CA net OLTP vs CA net DW
- Nombre de commandes OLTP vs faitLivraisons

> Remarque : si le fichier des lignes de commande est partiel, on peut avoir plus de commandes au niveau “entête” que de commandes “avec ventes”.

---

## Rapport Power BI (pages)
Le rapport est organisé en pages thématiques pour garder une lecture simple :
1. **Synthèse Finance** (vue globale KPI)
2. **Produits & Catégories** (contribution, prix vs quantité, fournisseurs)
3. **Clients & Remises** (top clients, distribution des remises, vue employés)
4. **Transport & Coûts** (pays de livraison, transporteurs, port)
5. **Logistique** (écarts date objectif vs date envoi, réappro, quantités par zone)

---

## Structure du dépôt
- `00_CONSIGNES/` : consignes PDF
- `01_DONNEES/` : CSV sources
- `02_SQL/` : scripts OLTP, DW, vues, requêtes métiers F/L
- `03_POWER_BI/` : PBIX + exports PDF + icônes KPI
- `04_DOCS/` : guide utilisateur + fiche technique (PDF + LaTeX)
- `05_LIVRABLES/` : livrables finaux prêts à rendre

---

## Reproduire le projet (résumé)
1. Créer la base PostgreSQL et les schémas.
2. Importer les CSV dans l’OLTP (`entreprise`).
3. Créer le DW (`entreprise_dw`) puis exécuter l’alimentation (dimensions → faits).
4. Lancer les contrôles de cohérence.
5. Ouvrir le `.pbix`, actualiser, puis naviguer dans les pages.

---

## Livrables
- Rapport Power BI (PDF)
- PBIX
- Guide utilisateur (1 page)
- Fiche technique (1–2 pages)
- Scripts SQL (OLTP, DW, vues, requêtes métiers)

---

## Auteur
Ibrahima Bodian