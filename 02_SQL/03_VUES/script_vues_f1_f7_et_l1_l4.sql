--1) Finance — F1 à F7
--F1 — Remises : produit + client + employé (tri par remise décroissante)
CREATE OR REPLACE VIEW entreprise_dw.v_F1_remises AS
SELECT
  f.nocom,
  t.date_jour,
  p.refprod, p.nomprod,
  c.codecli, c.societe AS societe_client,
  e.noemp, e.nom AS nom_employe, e.prenom AS prenom_employe,
  f.qte, f.prixunit, f.remise,
  f.montant_brut, f.montant_net
FROM entreprise_dw.faitVentes f
JOIN entreprise_dw.dimTemps t   ON t.date_key = f.date_key
JOIN entreprise_dw.dimProduit p ON p.produit_key = f.produit_key
JOIN entreprise_dw.dimClient c  ON c.client_key = f.client_key
JOIN entreprise_dw.dimEmploye e ON e.employe_key = f.employe_key
ORDER BY f.remise DESC, f.montant_net DESC;


--F2 — CA par produit + sous-totaux par catégorie
CREATE OR REPLACE VIEW entreprise_dw.v_F2_ca_par_produit AS
SELECT
  p.nomcateg,
  p.refprod, p.nomprod,
  SUM(f.qte) AS qte_totale,
  SUM(f.montant_net) AS ca_net
FROM entreprise_dw.faitVentes f
JOIN entreprise_dw.dimProduit p ON p.produit_key = f.produit_key
GROUP BY p.nomcateg, p.refprod, p.nomprod
ORDER BY p.nomcateg, ca_net DESC;
-------------
CREATE OR REPLACE VIEW entreprise_dw.v_F2_ca_par_categorie AS
SELECT
  p.nomcateg,
  SUM(f.montant_net) AS ca_net
FROM entreprise_dw.faitVentes f
JOIN entreprise_dw.dimProduit p ON p.produit_key = f.produit_key
GROUP BY p.nomcateg
ORDER BY ca_net DESC;

--F3 — CA par pays + total des frais de port
CREATE OR REPLACE VIEW entreprise_dw.v_F3_ca_par_pays AS
SELECT
  g.paysliv,
  SUM(f.montant_net) AS ca_net,
  SUM(f.port_alloc) AS port_total
FROM entreprise_dw.faitVentes f
LEFT JOIN entreprise_dw.dimGeoLivraison g ON g.geo_key = f.geo_key
GROUP BY g.paysliv
ORDER BY ca_net DESC;


--F4 — CA transporté par transporteur
CREATE OR REPLACE VIEW entreprise_dw.v_F4_ca_par_transporteur AS
SELECT
  tr.notran,
  tr.nomtran,
  SUM(f.montant_net) AS ca_net,
  SUM(f.port_alloc) AS port_total
FROM entreprise_dw.faitVentes f
LEFT JOIN entreprise_dw.dimTransporteur tr ON tr.transporteur_key = f.transporteur_key
GROUP BY tr.notran, tr.nomtran
ORDER BY ca_net DESC;


--F5 — Commandes par employé + remises moyennes par client
CREATE OR REPLACE VIEW entreprise_dw.v_F5_cmd_par_employe AS
SELECT
  e.noemp, e.nom, e.prenom,
  COUNT(DISTINCT f.nocom) AS nb_commandes,
  SUM(f.montant_net) AS ca_net
FROM entreprise_dw.faitVentes f
JOIN entreprise_dw.dimEmploye e ON e.employe_key = f.employe_key
GROUP BY e.noemp, e.nom, e.prenom
ORDER BY nb_commandes DESC, ca_net DESC;

--------------------------
CREATE OR REPLACE VIEW entreprise_dw.v_F5_remise_moy_par_client AS
SELECT
  c.codecli, c.societe,
  AVG(f.remise) AS remise_moy,
  SUM(f.montant_net) AS ca_net
FROM entreprise_dw.faitVentes f
JOIN entreprise_dw.dimClient c ON c.client_key = f.client_key
GROUP BY c.codecli, c.societe
ORDER BY remise_moy DESC;

--F6 — CA et quantités par fournisseur et produit
CREATE OR REPLACE VIEW entreprise_dw.v_F6_ca_par_fournisseur_produit AS
SELECT
  p.nofour,
  p.fournisseur_societe,
  p.refprod, p.nomprod,
  SUM(f.qte) AS qte_totale,
  SUM(f.montant_net) AS ca_net
FROM entreprise_dw.faitVentes f
JOIN entreprise_dw.dimProduit p ON p.produit_key = f.produit_key
GROUP BY p.nofour, p.fournisseur_societe, p.refprod, p.nomprod
ORDER BY p.fournisseur_societe, ca_net DESC;


--F7 — Port cumulé + nb d’expéditions par transporteur
CREATE OR REPLACE VIEW entreprise_dw.v_F7_port_par_transporteur AS
SELECT
  tr.notran, tr.nomtran,
  COUNT(*) AS nb_expeditions,
  SUM(l.port) AS port_total
FROM entreprise_dw.faitLivraisons l
LEFT JOIN entreprise_dw.dimTransporteur tr ON tr.transporteur_key = l.transporteur_key
GROUP BY tr.notran, tr.nomtran
ORDER BY port_total DESC;

----------------------------------
--2) Logistique — L1 à L4
--L1 — Plus grands écarts entre date objectif et date d’envoi (retards)
CREATE OR REPLACE VIEW entreprise_dw.v_L1_plus_grands_retards AS
SELECT
  l.nocom,
  tr.nomtran,
  g.paysliv, g.regionliv, g.villeliv,
  l.retard_jours,
  l.delai_envoi_jours,
  l.port
FROM entreprise_dw.faitLivraisons l
LEFT JOIN entreprise_dw.dimTransporteur tr ON tr.transporteur_key = l.transporteur_key
LEFT JOIN entreprise_dw.dimGeoLivraison g ON g.geo_key = l.geo_key
WHERE l.retard_jours IS NOT NULL
ORDER BY l.retard_jours DESC;


--L2 — Produits à réapprovisionner (stock - unités commandées < niveau réappro)
CREATE OR REPLACE VIEW entreprise_dw.v_L2_reappro AS
SELECT
  p.refprod, p.nomprod,
  p.unitesstock, p.unitescom, p.niveaureap,
  (p.unitesstock - p.unitescom) AS stock_dispo
FROM entreprise._produit p
WHERE (p.unitesstock - p.unitescom) < p.niveaureap
ORDER BY stock_dispo ASC;



--L3 — Quantités livrées par région/ville
CREATE OR REPLACE VIEW entreprise_dw.v_L3_qte_par_zone AS
SELECT
  g.paysliv, g.regionliv, g.villeliv,
  SUM(f.qte) AS qte_totale,
  SUM(f.montant_net) AS ca_net
FROM entreprise_dw.faitVentes f
LEFT JOIN entreprise_dw.dimGeoLivraison g ON g.geo_key = f.geo_key
GROUP BY g.paysliv, g.regionliv, g.villeliv
ORDER BY qte_totale DESC;



--L4 — “Commandes à livrer” dont le fournisseur est dans la même région
CREATE OR REPLACE VIEW entreprise_dw.v_L4_cmd_fourn_meme_region AS
SELECT DISTINCT
  c.nocom,
  c.regionliv,
  f.nofour,
  f.societe AS fournisseur,
  f.region AS region_fournisseur
FROM entreprise._commande c
JOIN entreprise._detailcommande dc ON dc.nocom = c.nocom
JOIN entreprise._produit p ON p.refprod = dc.refprod
JOIN entreprise._fournisseur f ON f.nofour = p.nofour
WHERE NULLIF(c.regionliv,'unknown_value_please_contact_support')
      IS NOT DISTINCT FROM NULLIF(f.region,'unknown_value_please_contact_support');


----3) Les rapports “à imaginer” (F8 / L5)----
--F8 — Top 10 clients par CA net (avec % du total)
CREATE OR REPLACE VIEW entreprise_dw.v_F8_top_clients AS
WITH base AS (
  SELECT c.codecli, c.societe, SUM(f.montant_net) AS ca_net
  FROM entreprise_dw.faitVentes f
  JOIN entreprise_dw.dimClient c ON c.client_key = f.client_key
  GROUP BY c.codecli, c.societe
),
tot AS (
  SELECT SUM(ca_net) AS ca_total FROM base
)
SELECT
  b.*,
  ROUND(100 * b.ca_net / NULLIF(t.ca_total,0), 2) AS pct_total
FROM base b CROSS JOIN tot t
ORDER BY b.ca_net DESC
LIMIT 10;



--L5 — Transporteurs : taux de retard (part des commandes en retard)
CREATE OR REPLACE VIEW entreprise_dw.v_L5_taux_retard_transporteur AS
SELECT
  tr.notran, tr.nomtran,
  COUNT(*) AS nb_cmd,
  SUM(CASE WHEN l.retard_jours IS NOT NULL AND l.retard_jours > 0 THEN 1 ELSE 0 END) AS nb_retard,
  ROUND(
    100.0 * SUM(CASE WHEN l.retard_jours IS NOT NULL AND l.retard_jours > 0 THEN 1 ELSE 0 END)
    / NULLIF(COUNT(*),0),
    2
  ) AS taux_retard_pct
FROM entreprise_dw.faitLivraisons l
LEFT JOIN entreprise_dw.dimTransporteur tr ON tr.transporteur_key = l.transporteur_key
GROUP BY tr.notran, tr.nomtran
ORDER BY taux_retard_pct DESC;
