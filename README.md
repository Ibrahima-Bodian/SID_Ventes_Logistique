# SAE6 VCOD01 — Outil décisionnel Ventes & Logistique (PostgreSQL + DW + Power BI)

## Objectif
Construire une chaîne décisionnelle : OLTP (PostgreSQL) → Datawarehouse (étoile) → Power BI.
Le rapport répond aux besoins Finance (F1–F8) et Logistique (L1–L5).

## Contenu du dépôt
- `02_SQL/` : scripts OLTP, DW, vues, requêtes métiers
- `03_POWER_BI/` : fichier PBIX + exports PDF + icônes
- `04_DOCS/` : guide utilisateur + fiche technique (PDF + LaTeX)
- `05_LIVRABLES/` : livrables finaux prêts à rendre

## Rejouer le projet (résumé)
1. Importer les CSV dans le schéma `entreprise` (PostgreSQL).
2. Exécuter les scripts DW dans `entreprise_dw` (dimensions puis faits).
3. Lancer les contrôles qualité (CA net / nb commandes).
4. Ouvrir le `.pbix` et actualiser (mode Import).

## Livrables
Voir `05_LIVRABLES/`.