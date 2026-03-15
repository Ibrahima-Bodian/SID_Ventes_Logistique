/* ============================================================
   REQUÊTES MÉTIERS – DW (entreprise_dw)
   F1..F8 (Finance) – périodes : mois / trimestre / année
   L1..L5 (Logistique) – périodes : semaine / mois / trimestre
   Sources : dimTemps + dimProduit + dimClient + dimEmploye + dimTransporteur +
            dimGeoLivraison + faitVentes + faitLivraisons
   ============================================================ */

/* ============================================================
   FINANCE (F) – consultables par mois / trimestre / année
   ============================================================ */

/* =======================
   F1 : Liste décroissante des produits avec les plus grosses remises
        + client + nom employé de la commande
   ======================= */
WITH base AS (
  SELECT
    t.annee, t.trimestre, t.mois, t.date_jour,
    fv.nocom,
    dp.nomprod,
    dp.nomcateg,
    dc.codecli,
    dc.societe AS client_societe,
    de.nom AS emp_nom,
    de.prenom AS emp_prenom,
    fv.qte,
    fv.prixunit,
    fv.remise AS remise_taux,
    fv.montant_brut,
    fv.montant_net,
    (fv.montant_brut - fv.montant_net) AS remise_montant
  FROM entreprise_dw.faitventes fv
  JOIN entreprise_dw.dimtemps t       ON t.date_key = fv.date_key
  JOIN entreprise_dw.dimproduit dp    ON dp.produit_key = fv.produit_key
  JOIN entreprise_dw.dimclient dc     ON dc.client_key = fv.client_key
  JOIN entreprise_dw.dimemploye de    ON de.employe_key = fv.employe_key
  WHERE 1=1
)
SELECT
  annee, trimestre, mois,
  nocom,
  date_jour,
  nomprod,
  nomcateg,
  codecli,
  client_societe,
  emp_nom, emp_prenom,
  qte,
  prixunit,
  remise_taux,
  remise_montant,
  montant_net
FROM base
ORDER BY remise_montant DESC, remise_taux DESC, montant_net DESC;


--F2 : Liste du chiffre d’affaires (CA net) par produit
WITH base AS (
  SELECT
    t.annee, t.trimestre, t.mois,
    dp.nomcateg,
    dp.nomprod,
    SUM(fv.montant_net) AS ca_net
  FROM entreprise_dw.faitventes fv
  JOIN entreprise_dw.dimtemps t    ON t.date_key = fv.date_key
  JOIN entreprise_dw.dimproduit dp ON dp.produit_key = fv.produit_key
  WHERE 1=1
  -- AND t.annee = 2014 AND t.mois = 8
  GROUP BY t.annee, t.trimestre, t.mois, dp.nomcateg, dp.nomprod
),
prod AS (
  SELECT
    annee, trimestre, mois,
    nomcateg,
    nomprod,
    ca_net,
    2 AS niveau
  FROM base
),
categ AS (
  SELECT
    annee, trimestre, mois,
    nomcateg,
    NULL::text AS nomprod,
    SUM(ca_net) AS ca_net,
    1 AS niveau
  FROM base
  GROUP BY annee, trimestre, mois, nomcateg
)
SELECT
  annee, trimestre, mois,
  CASE WHEN niveau=1 THEN nomcateg ELSE '  - '||nomcateg END AS categorie,
  nomprod,
  ca_net
FROM (
  SELECT * FROM categ
  UNION ALL
  SELECT * FROM prod
) x
ORDER BY annee, trimestre, mois, nomcateg, niveau, ca_net DESC;


-- F3 : Liste du chiffre d’affaires par pays (livraison)
WITH base AS (
  SELECT
    t.annee, t.trimestre, t.mois,
    g.paysliv,
    SUM(fv.montant_net) AS ca_net,
    SUM(fv.port_alloc)  AS port_total_alloue
  FROM entreprise_dw.faitventes fv
  JOIN entreprise_dw.dimtemps t          ON t.date_key = fv.date_key
  LEFT JOIN entreprise_dw.dimgeolivraison g ON g.geo_key = fv.geo_key
  WHERE 1=1
  -- AND t.annee = 2014 AND t.mois = 8
  GROUP BY t.annee, t.trimestre, t.mois, g.paysliv
)
SELECT
  annee, trimestre, mois,
  COALESCE(paysliv, 'Non renseigné') AS paysliv,
  ca_net,
  port_total_alloue
FROM base
ORDER BY annee, trimestre, mois, ca_net DESC;


--F4 : Liste du chiffre d’affaires transporté par transporteur
WITH base AS (
  SELECT
    t.annee, t.trimestre, t.mois,
    tr.nomtran,
    SUM(fv.montant_net) AS ca_net
  FROM entreprise_dw.faitventes fv
  JOIN entreprise_dw.dimtemps t              ON t.date_key = fv.date_key
  LEFT JOIN entreprise_dw.dimtransporteur tr ON tr.transporteur_key = fv.transporteur_key
  WHERE 1=1
  GROUP BY t.annee, t.trimestre, t.mois, tr.nomtran
)
SELECT
  annee, trimestre, mois,
  COALESCE(nomtran, 'Non renseigné') AS transporteur,
  ca_net
FROM base
ORDER BY annee, trimestre, mois, ca_net DESC;


--F5 : Liste des commandes par employé + remises moyennes accordées par client
WITH base AS (
  SELECT
    t.annee, t.trimestre, t.mois,
    de.noemp,
    de.nom AS emp_nom,
    de.prenom AS emp_prenom,
    dc.codecli,
    dc.societe AS client_societe,
    COUNT(DISTINCT fv.nocom) AS nb_commandes,
    AVG(fv.remise) AS remise_moyenne,
    SUM(fv.montant_net) AS ca_net
  FROM entreprise_dw.faitventes fv
  JOIN entreprise_dw.dimtemps t       ON t.date_key = fv.date_key
  JOIN entreprise_dw.dimemploye de    ON de.employe_key = fv.employe_key
  JOIN entreprise_dw.dimclient dc     ON dc.client_key = fv.client_key
  WHERE 1=1
  GROUP BY t.annee, t.trimestre, t.mois, de.noemp, de.nom, de.prenom, dc.codecli, dc.societe
)
SELECT
  annee, trimestre, mois,
  noemp, emp_nom, emp_prenom,
  codecli, client_societe,
  nb_commandes,
  remise_moyenne,
  ca_net
FROM base
ORDER BY annee, trimestre, mois, nb_commandes DESC, ca_net DESC;


--F6 : Liste des chiffres d’affaires et quantités par fournisseur (et par produit)
WITH base AS (
  SELECT
    t.annee, t.trimestre, t.mois,
    dp.fournisseur_societe,
    dp.nomprod,
    SUM(fv.qte) AS qte_vendue,
    SUM(fv.montant_net) AS ca_net
  FROM entreprise_dw.faitventes fv
  JOIN entreprise_dw.dimtemps t    ON t.date_key = fv.date_key
  JOIN entreprise_dw.dimproduit dp ON dp.produit_key = fv.produit_key
  WHERE 1=1
  GROUP BY t.annee, t.trimestre, t.mois, dp.fournisseur_societe, dp.nomprod
),
prod AS (
  SELECT
    annee, trimestre, mois,
    fournisseur_societe,
    nomprod,
    qte_vendue,
    ca_net,
    2 AS niveau
  FROM base
),
four AS (
  SELECT
    annee, trimestre, mois,
    fournisseur_societe,
    NULL::text AS nomprod,
    SUM(qte_vendue) AS qte_vendue,
    SUM(ca_net) AS ca_net,
    1 AS niveau
  FROM base
  GROUP BY annee, trimestre, mois, fournisseur_societe
)
SELECT
  annee, trimestre, mois,
  CASE WHEN niveau=1 THEN fournisseur_societe ELSE '  - '||fournisseur_societe END AS fournisseur,
  nomprod,
  qte_vendue,
  ca_net
FROM (
  SELECT * FROM four
  UNION ALL
  SELECT * FROM prod
) x
ORDER BY annee, trimestre, mois, fournisseur_societe, niveau, ca_net DESC;


--F7 : Cumul des frais de port par transporteur + nombre d’expéditions
WITH base AS (
  SELECT
    t.annee, t.trimestre, t.mois,
    tr.nomtran,
    COUNT(*) AS nb_expeditions,
    SUM(fl.port) AS port_total,
    AVG(fl.port) AS port_moyen
  FROM entreprise_dw.faitlivraisons fl
  JOIN entreprise_dw.dimtemps t              ON t.date_key = fl.datecom_key
  LEFT JOIN entreprise_dw.dimtransporteur tr ON tr.transporteur_key = fl.transporteur_key
  WHERE 1=1
  GROUP BY t.annee, t.trimestre, t.mois, tr.nomtran
)
SELECT
  annee, trimestre, mois,
  COALESCE(nomtran, 'Non renseigné') AS transporteur,
  nb_expeditions,
  port_total,
  port_moyen
FROM base
ORDER BY annee, trimestre, mois, port_total DESC;


--F8 : Rapport “à imaginer” utile Finance
--Proposition : Top clients + part du CA (concentration)
WITH base AS (
  SELECT
    t.annee, t.trimestre, t.mois,
    dc.codecli,
    dc.societe AS client_societe,
    SUM(fv.montant_net) AS ca_net
  FROM entreprise_dw.faitventes fv
  JOIN entreprise_dw.dimtemps t    ON t.date_key = fv.date_key
  JOIN entreprise_dw.dimclient dc  ON dc.client_key = fv.client_key
  WHERE 1=1
  GROUP BY t.annee, t.trimestre, t.mois, dc.codecli, dc.societe
),
tot AS (
  SELECT annee, trimestre, mois, SUM(ca_net) AS ca_total
  FROM base
  GROUP BY annee, trimestre, mois
)
SELECT
  b.annee, b.trimestre, b.mois,
  b.codecli, b.client_societe,
  b.ca_net,
  t.ca_total,
  ROUND(100 * b.ca_net / NULLIF(t.ca_total,0), 2) AS ca_pct_du_total
FROM base b
JOIN tot t USING (annee, trimestre, mois)
ORDER BY b.annee, b.trimestre, b.mois, b.ca_net DESC
LIMIT 20;



/* ============================================================*/
   LOGISTIQUE (L) – consultables par semaine / mois / trimestre
/* ============================================================ */

 
--L1 : Liste des plus grands écarts entre date objectif et date d’envoi

-- Ici je vais utiliser dateenv_key et dateobj_key.
-- Si l’un est NULL, l’écart est NULL.
SELECT
  tcom.annee,
  tcom.trimestre,
  tcom.mois,
  tcom.semaine_iso,
  fl.nocom,
  tcom.date_jour AS date_commande,
  tenv.date_jour AS date_envoi,
  tobj.date_jour AS date_objectif,
  (tenv.date_jour - tobj.date_jour) AS ecart_obj_envoi_jours,
  ABS(tenv.date_jour - tobj.date_jour) AS ecart_abs_jours,
  tr.nomtran,
  g.paysliv, g.regionliv, g.villeliv
FROM entreprise_dw.faitlivraisons fl
JOIN entreprise_dw.dimtemps tcom ON tcom.date_key = fl.datecom_key
LEFT JOIN entreprise_dw.dimtemps tenv ON tenv.date_key = fl.dateenv_key
LEFT JOIN entreprise_dw.dimtemps tobj ON tobj.date_key = fl.dateobj_key
LEFT JOIN entreprise_dw.dimtransporteur tr ON tr.transporteur_key = fl.transporteur_key
LEFT JOIN entreprise_dw.dimgeolivraison g  ON g.geo_key = fl.geo_key
WHERE 1=1
ORDER BY ecart_abs_jours DESC NULLS LAST
LIMIT 50;


--L2 : Produits dont le réappro est déclenché
--Règle ici : (unitesstock - unitescom) < niveaureap
SELECT
  dp.refprod,
  dp.nomprod,
  dp.nomcateg,
  dp.fournisseur_societe,
  dp.unitesstock,
  dp.unitescom,
  dp.niveaureap,
  (dp.unitesstock - dp.unitescom) AS stock_dispo
FROM entreprise_dw.dimproduit dp
WHERE dp.unitesstock IS NOT NULL
  AND dp.unitescom   IS NOT NULL
  AND dp.niveaureap  IS NOT NULL
  AND (dp.unitesstock - dp.unitescom) < dp.niveaureap
ORDER BY stock_dispo ASC, dp.niveaureap DESC;


--L3 : Quantités de produits livrées par région et ville de livraison
WITH base AS (
  SELECT
    t.annee, t.trimestre, t.mois, t.semaine_iso,
    g.paysliv, g.regionliv, g.villeliv,
    SUM(fv.qte) AS qte_livree
  FROM entreprise_dw.faitventes fv
  JOIN entreprise_dw.dimtemps t           ON t.date_key = fv.date_key
  LEFT JOIN entreprise_dw.dimgeolivraison g ON g.geo_key = fv.geo_key
  WHERE 1=1
  GROUP BY t.annee, t.trimestre, t.mois, t.semaine_iso, g.paysliv, g.regionliv, g.villeliv
)
SELECT
  annee, trimestre, mois, semaine_iso,
  COALESCE(paysliv,'Non renseigné') AS paysliv,
  COALESCE(regionliv,'Non renseigné') AS regionliv,
  COALESCE(villeliv,'Non renseigné') AS villeliv,
  qte_livree
FROM base
ORDER BY annee, trimestre, mois, semaine_iso, qte_livree DESC;


--L4 : Commandes à livrer ayant un fournisseur dans la même région
SELECT DISTINCT
  fl.nocom,
  g.paysliv,
  dp.fournisseur_pays,
  dp.fournisseur_societe
FROM entreprise_dw.faitlivraisons fl
LEFT JOIN entreprise_dw.dimgeolivraison g ON g.geo_key = fl.geo_key
JOIN entreprise_dw.faitventes fv          ON fv.nocom = fl.nocom
JOIN entreprise_dw.dimproduit dp          ON dp.produit_key = fv.produit_key
WHERE g.paysliv IS NOT NULL
  AND dp.fournisseur_pays IS NOT NULL
  AND g.paysliv = dp.fournisseur_pays
ORDER BY fl.nocom;


--L5 : Rapport “à imaginer” utile Logistique
--Ma proposition : Délai moyen d’envoi par transporteur + nb expéditions + port total
SELECT
  t.annee, t.trimestre, t.mois, t.semaine_iso,
  COALESCE(tr.nomtran, 'Non renseigné') AS transporteur,
  COUNT(*) AS nb_expeditions,
  AVG(fl.delai_envoi_jours) AS delai_envoi_moyen_jours,
  SUM(fl.port) AS port_total
FROM entreprise_dw.faitlivraisons fl
JOIN entreprise_dw.dimtemps t              ON t.date_key = fl.datecom_key
LEFT JOIN entreprise_dw.dimtransporteur tr ON tr.transporteur_key = fl.transporteur_key
WHERE 1=1
GROUP BY t.annee, t.trimestre, t.mois, t.semaine_iso, tr.nomtran
ORDER BY t.annee, t.trimestre, t.mois, t.semaine_iso, delai_envoi_moyen_jours DESC;