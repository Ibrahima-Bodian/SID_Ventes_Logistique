--Vues SQL pour les rapports Finance / Logistique
--A) Finance
--CA par période
CREATE OR REPLACE VIEW entreprise_dw.v_fin_ca_par_periode AS
SELECT
  t.annee, t.trimestre, t.mois, t.semaine_iso,
  SUM(f.montant_net)  AS ca_net,
  SUM(f.montant_brut) AS ca_brut,
  SUM(f.port_alloc)   AS port_total
FROM entreprise_dw.faitVentes f
JOIN entreprise_dw.dimTemps t ON t.date_key = f.date_key
GROUP BY t.annee, t.trimestre, t.mois, t.semaine_iso;

--CA par produit + catégorie + fournisseur
CREATE OR REPLACE VIEW entreprise_dw.v_fin_ca_par_produit AS
SELECT
  p.refprod, p.nomprod,
  p.codecateg, p.nomcateg,
  p.nofour, p.fournisseur_societe,
  SUM(f.qte) AS qte_totale,
  SUM(f.montant_net) AS ca_net
FROM entreprise_dw.faitVentes f
JOIN entreprise_dw.dimProduit p ON p.produit_key = f.produit_key
GROUP BY p.refprod, p.nomprod, p.codecateg, p.nomcateg, p.nofour, p.fournisseur_societe;


--CA + port par pays de livraison
CREATE OR REPLACE VIEW entreprise_dw.v_fin_ca_par_pays_livraison AS
SELECT
  g.paysliv,
  SUM(f.montant_net) AS ca_net,
  SUM(f.port_alloc) AS port_total
FROM entreprise_dw.faitVentes f
LEFT JOIN entreprise_dw.dimGeoLivraison g ON g.geo_key = f.geo_key
GROUP BY g.paysliv;


--CA transporté par transporteur
CREATE OR REPLACE VIEW entreprise_dw.v_fin_ca_par_transporteur AS
SELECT
  tr.notran, tr.nomtran,
  SUM(f.montant_net) AS ca_net,
  SUM(f.port_alloc) AS port_total
FROM entreprise_dw.faitVentes f
LEFT JOIN entreprise_dw.dimTransporteur tr ON tr.transporteur_key = f.transporteur_key
GROUP BY tr.notran, tr.nomtran;


--Remise moyenne + top remises (utile pour “F1” style)
CREATE OR REPLACE VIEW entreprise_dw.v_fin_remises AS
SELECT
  c.codecli, c.societe,
  e.noemp, e.nom, e.prenom,
  p.refprod, p.nomprod,
  AVG(f.remise) AS remise_moy,
  MAX(f.remise) AS remise_max,
  SUM(f.montant_net) AS ca_net
FROM entreprise_dw.faitVentes f
JOIN entreprise_dw.dimClient c ON c.client_key = f.client_key
JOIN entreprise_dw.dimEmploye e ON e.employe_key = f.employe_key
JOIN entreprise_dw.dimProduit p ON p.produit_key = f.produit_key
GROUP BY c.codecli, c.societe, e.noemp, e.nom, e.prenom, p.refprod, p.nomprod;


--B)Logistique
--Retards (top écarts)
CREATE OR REPLACE VIEW entreprise_dw.v_log_retards AS
SELECT
  l.nocom,
  tr.notran, tr.nomtran,
  g.paysliv, g.regionliv, g.villeliv,
  l.retard_jours,
  l.delai_envoi_jours,
  l.port
FROM entreprise_dw.faitLivraisons l
LEFT JOIN entreprise_dw.dimTransporteur tr ON tr.transporteur_key = l.transporteur_key
LEFT JOIN entreprise_dw.dimGeoLivraison g ON g.geo_key = l.geo_key
WHERE l.retard_jours IS NOT NULL
ORDER BY l.retard_jours DESC;


--Volume livré par région/ville
CREATE OR REPLACE VIEW entreprise_dw.v_log_qte_par_zone AS
SELECT
  g.paysliv, g.regionliv, g.villeliv,
  SUM(f.qte) AS qte_totale,
  SUM(f.montant_net) AS ca_net
FROM entreprise_dw.faitVentes f
LEFT JOIN entreprise_dw.dimGeoLivraison g ON g.geo_key = f.geo_key
GROUP BY g.paysliv, g.regionliv, g.villeliv;

-- Transporteurs : stats de performance
CREATE OR REPLACE VIEW entreprise_dw.v_log_transporteurs AS
SELECT
  tr.notran, tr.nomtran,
  COUNT(*) AS nb_commandes,
  AVG(l.delai_envoi_jours) AS delai_moyen_envoi,
  AVG(l.retard_jours) AS retard_moyen,
  SUM(l.port) AS port_total
FROM entreprise_dw.faitLivraisons l
LEFT JOIN entreprise_dw.dimTransporteur tr ON tr.transporteur_key = l.transporteur_key
GROUP BY tr.notran, tr.nomtran;


--Indices pour Power BI ou requêtes rapides
CREATE INDEX IF NOT EXISTS ix_faitventes_date    ON entreprise_dw.faitVentes(date_key);
CREATE INDEX IF NOT EXISTS ix_faitventes_client  ON entreprise_dw.faitVentes(client_key);
CREATE INDEX IF NOT EXISTS ix_faitventes_produit ON entreprise_dw.faitVentes(produit_key);

CREATE INDEX IF NOT EXISTS ix_faitliv_datecom ON entreprise_dw.faitLivraisons(datecom_key);
CREATE INDEX IF NOT EXISTS ix_faitliv_tran    ON entreprise_dw.faitLivraisons(transporteur_key);
