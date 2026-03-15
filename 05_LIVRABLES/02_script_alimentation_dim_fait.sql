--dimTemps : on génère un calendrier sur la plage des commandes
WITH bounds AS (
  SELECT
    MIN(datecom) AS dmin,
    MAX(GREATEST(
      datecom,
      COALESCE(dateenv, datecom),
      COALESCE(dateobjliv, datecom)
    )) AS dmax
  FROM entreprise._commande
)
INSERT INTO entreprise_dw.dimTemps(date_key, date_jour, annee, trimestre, mois, semaine_iso, jour_mois, jour_semaine_iso)
SELECT
  (EXTRACT(YEAR FROM d)::int * 10000 + EXTRACT(MONTH FROM d)::int * 100 + EXTRACT(DAY FROM d)::int) AS date_key,
  d::date AS date_jour,
  EXTRACT(YEAR FROM d)::int AS annee,
  EXTRACT(QUARTER FROM d)::int AS trimestre,
  EXTRACT(MONTH FROM d)::int AS mois,
  EXTRACT(WEEK FROM d)::int AS semaine_iso,
  EXTRACT(DAY FROM d)::int AS jour_mois,
  EXTRACT(ISODOW FROM d)::int AS jour_semaine_iso
FROM bounds, generate_series(bounds.dmin, bounds.dmax, interval '1 day') AS gs(d)
ON CONFLICT (date_key) DO NOTHING;

-- B) dimClient
INSERT INTO entreprise_dw.dimClient(codecli, societe, contact, fonction, ville, region, pays, codepostal)
SELECT
  c.codecli,
  NULLIF(c.societe,'unknown_value_please_contact_support'),
  NULLIF(c.contact,'unknown_value_please_contact_support'),
  NULLIF(c.fonction,'unknown_value_please_contact_support'),
  NULLIF(c.ville,'unknown_value_please_contact_support'),
  NULLIF(c.region,'unknown_value_please_contact_support'),
  NULLIF(c.pays,'unknown_value_please_contact_support'),
  NULLIF(c.codepostal,'unknown_value_please_contact_support')
FROM entreprise._client c
ON CONFLICT (codecli) DO NOTHING;

-- dimEmploye
INSERT INTO entreprise_dw.dimEmploye(noemp, nom, prenom, fonction, ville, region, pays, rendcomptea)
SELECT
  e.noemp,
  e.nom, e.prenom, e.fonction,
  NULLIF(e.ville,'unknown_value_please_contact_support'),
  NULLIF(e.region,'unknown_value_please_contact_support'),
  NULLIF(e.pays,'unknown_value_please_contact_support'),
  e.rendcomptea
FROM entreprise._employe e
ON CONFLICT (noemp) DO NOTHING;

--dimransporteur
INSERT INTO entreprise_dw.dimTransporteur(notran, nomtran, tel)
SELECT t.notran, t.nomtran, t.tel
FROM entreprise._transporteur t
ON CONFLICT (notran) DO NOTHING;

--dimGeoLivraison (distinct depuis commande)
INSERT INTO entreprise_dw.dimGeoLivraison(paysliv, regionliv, villeliv, codepostalliv)
SELECT DISTINCT
  NULLIF(c.paysliv,'unknown_value_please_contact_support'),
  NULLIF(c.regionliv,'unknown_value_please_contact_support'),
  NULLIF(c.villeliv,'unknown_value_please_contact_support'),
  NULLIF(c.codepostalliv,'unknown_value_please_contact_support')
FROM entreprise._commande c
ON CONFLICT (paysliv, regionliv, villeliv, codepostalliv) DO NOTHING;

-- dimProduit (dénormalisée)
INSERT INTO entreprise_dw.dimProduit(refprod, nomprod, prixcatalogue, indisponible,
            codecateg, nomcateg, nofour, fournisseur_societe, fournisseur_pays)
SELECT
  p.refprod,
  p.nomprod,
  p.prixunit,
  p.indisponible,
  cat.codecateg,
  cat.nomcateg,
  f.nofour,
  f.societe,
  f.pays
FROM entreprise._produit p
JOIN entreprise._categorie cat ON cat.codecateg = p.codecateg
JOIN entreprise._fournisseur f ON f.nofour = p.nofour
ON CONFLICT (refprod) DO NOTHING;

-- G) faitLivraisons (grain = commande)
INSERT INTO entreprise_dw.faitLivraisons(
  datecom_key, dateenv_key, dateobj_key,
  client_key, employe_key, transporteur_key, geo_key,
  nocom, port, delai_envoi_jours, retard_jours
)
SELECT
  (EXTRACT(YEAR FROM c.datecom)::int * 10000 + EXTRACT(MONTH FROM c.datecom)::int * 100 + EXTRACT(DAY FROM c.datecom)::int),
  CASE WHEN c.dateenv IS NULL THEN NULL ELSE (EXTRACT(YEAR FROM c.dateenv)::int * 10000 + EXTRACT(MONTH FROM c.dateenv)::int * 100 + EXTRACT(DAY FROM c.dateenv)::int) END,
  CASE WHEN c.dateobjliv IS NULL THEN NULL ELSE (EXTRACT(YEAR FROM c.dateobjliv)::int * 10000 + EXTRACT(MONTH FROM c.dateobjliv)::int * 100 + EXTRACT(DAY FROM c.dateobjliv)::int) END,

  dc.client_key,
  de.employe_key,
  dt.transporteur_key,
  dg.geo_key,

  c.nocom,
  c.port,
  CASE WHEN c.dateenv IS NULL THEN NULL ELSE (c.dateenv - c.datecom) END AS delai_envoi_jours,
  CASE
    WHEN c.dateenv IS NULL OR c.dateobjliv IS NULL THEN NULL
    ELSE GREATEST(0, (c.dateenv - c.dateobjliv))
  END AS retard_jours
FROM entreprise._commande c
JOIN entreprise_dw.dimClient dc ON dc.codecli = c.codecli
JOIN entreprise_dw.dimEmploye de ON de.noemp = c.noemp
LEFT JOIN entreprise_dw.dimTransporteur dt ON dt.notran = c.notran
LEFT JOIN entreprise_dw.dimGeoLivraison dg
  ON dg.paysliv IS NOT DISTINCT FROM NULLIF(c.paysliv,'unknown_value_please_contact_support')
 AND dg.regionliv IS NOT DISTINCT FROM NULLIF(c.regionliv,'unknown_value_please_contact_support')
 AND dg.villeliv IS NOT DISTINCT FROM NULLIF(c.villeliv,'unknown_value_please_contact_support')
 AND dg.codepostalliv IS NOT DISTINCT FROM NULLIF(c.codepostalliv,'unknown_value_please_contact_support')
ON CONFLICT (nocom) DO NOTHING;

-- H) faitventes (grain = détail commande) + allocation du port
WITH lignes AS (
  SELECT
    dc.nocom, dc.refprod, dc.qte, dc.prixunit, dc.remise,
    (dc.qte * dc.prixunit) AS montant_brut,
    (dc.qte * dc.prixunit * (1 - dc.remise)) AS montant_net
  FROM entreprise._detailcommande dc
),
tot AS (
  SELECT nocom, SUM(montant_net) AS total_net
  FROM lignes
  GROUP BY nocom
),
enrich AS (
  SELECT
    l.*,
    c.codecli, c.noemp, c.notran,
    c.datecom,
    c.port,
    c.paysliv, c.regionliv, c.villeliv, c.codepostalliv,
    CASE WHEN t.total_net > 0 THEN (c.port * (l.montant_net / t.total_net)) ELSE 0 END AS port_alloc
  FROM lignes l
  JOIN tot t USING (nocom)
  JOIN entreprise._commande c USING (nocom)
)
INSERT INTO entreprise_dw.faitVentes(
  date_key, client_key, employe_key, transporteur_key, produit_key, geo_key,
  nocom, qte, prixunit, remise, montant_brut, montant_net, port_alloc
)
SELECT
  (EXTRACT(YEAR FROM e.datecom)::int * 10000 + EXTRACT(MONTH FROM e.datecom)::int * 100 + EXTRACT(DAY FROM e.datecom)::int) AS date_key,
  dcli.client_key,
  demp.employe_key,
  dtran.transporteur_key,
  dprod.produit_key,
  dgeo.geo_key,

  e.nocom,
  e.qte,
  e.prixunit,
  e.remise,
  e.montant_brut,
  e.montant_net,
  e.port_alloc
FROM enrich e
JOIN entreprise_dw.dimClient dcli ON dcli.codecli = e.codecli
JOIN entreprise_dw.dimEmploye demp ON demp.noemp = e.noemp
LEFT JOIN entreprise_dw.dimTransporteur dtran ON dtran.notran = e.notran
JOIN entreprise_dw.dimProduit dprod ON dprod.refprod = e.refprod
LEFT JOIN entreprise_dw.dimGeoLivraison dgeo
  ON dgeo.paysliv IS NOT DISTINCT FROM NULLIF(e.paysliv,'unknown_value_please_contact_support')
 AND dgeo.regionliv IS NOT DISTINCT FROM NULLIF(e.regionliv,'unknown_value_please_contact_support')
 AND dgeo.villeliv IS NOT DISTINCT FROM NULLIF(e.villeliv,'unknown_value_please_contact_support')
 AND dgeo.codepostalliv IS NOT DISTINCT FROM NULLIF(e.codepostalliv,'unknown_value_please_contact_support');
