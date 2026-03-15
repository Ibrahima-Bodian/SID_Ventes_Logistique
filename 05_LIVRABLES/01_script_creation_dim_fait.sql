-- 0) Schéma DW
CREATE SCHEMA IF NOT EXISTS entreprise_dw;

-- 1) Dimension Temps
CREATE TABLE IF NOT EXISTS entreprise_dw.dimTemps (
  date_key      INTEGER PRIMARY KEY,         -- format YYYYMMDD
  date_jour     DATE UNIQUE NOT NULL,
  annee         SMALLINT NOT NULL,
  trimestre     SMALLINT NOT NULL,
  mois          SMALLINT NOT NULL,
  semaine_iso   SMALLINT NOT NULL,
  jour_mois     SMALLINT NOT NULL,
  jour_semaine_iso SMALLINT NOT NULL
);

-- 2) Dimension Client
CREATE TABLE IF NOT EXISTS entreprise_dw.dimClient (
  client_key BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  codecli    VARCHAR(255) UNIQUE NOT NULL,
  societe    VARCHAR(255),
  contact    VARCHAR(255),
  fonction   VARCHAR(255),
  ville      VARCHAR(255),
  region     VARCHAR(255),
  pays       VARCHAR(255),
  codepostal VARCHAR(255)
);

-- 3) Dimension Employé
CREATE TABLE IF NOT EXISTS entreprise_dw.dimEmploye (
  employe_key BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  noemp       INTEGER UNIQUE NOT NULL,
  nom         VARCHAR(255),
  prenom      VARCHAR(255),
  fonction    VARCHAR(255),
  ville       VARCHAR(255),
  region      VARCHAR(255),
  pays        VARCHAR(255),
  rendcomptea INTEGER
);

-- 4) Dimension Transporteur
CREATE TABLE IF NOT EXISTS entreprise_dw.dimTransporteur (
  transporteur_key BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  notran           INTEGER UNIQUE NOT NULL,
  nomtran          VARCHAR(255),
  tel              VARCHAR(255)
);

-- 5) Dimension Géographie de livraison (depuis les champs de livraison de _commande)
CREATE TABLE IF NOT EXISTS entreprise_dw.dimGeoLivraison (
  geo_key    BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  paysliv    VARCHAR(255),
  regionliv  VARCHAR(255),
  villeliv   VARCHAR(255),
  codepostalliv VARCHAR(255),
  UNIQUE (paysliv, regionliv, villeliv, codepostalliv)
);

-- 6) Dimension Produit (dénormalisée avec Catégorie + Fournisseur pour simplifier l’étoile)
CREATE TABLE IF NOT EXISTS entreprise_dw.dimProduit (
  produit_key BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  refprod     INTEGER UNIQUE NOT NULL,
  nomprod     VARCHAR(255),
  prixcatalogue NUMERIC(10,2),
  indisponible SMALLINT,
  codecateg   INTEGER,
  nomcateg    VARCHAR(255),
  nofour      INTEGER,
  fournisseur_societe VARCHAR(255),
  fournisseur_pays    VARCHAR(255)
);

-- 7) Fait Ventes (grain = ligne de commande)
CREATE TABLE IF NOT EXISTS entreprise_dw.faitVentes (
  ventes_key BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,

  date_key INTEGER NOT NULL REFERENCES entreprise_dw.dimTemps(date_key),
  client_key BIGINT NOT NULL REFERENCES entreprise_dw.dimClient(client_key),
  employe_key BIGINT NOT NULL REFERENCES entreprise_dw.dimEmploye(employe_key),
  transporteur_key BIGINT REFERENCES entreprise_dw.dimTransporteur(transporteur_key),
  produit_key BIGINT NOT NULL REFERENCES entreprise_dw.dimProduit(produit_key),
  geo_key BIGINT REFERENCES entreprise_dw.dimGeoLivraison(geo_key),

  nocom INTEGER NOT NULL,                    -- dimension dégénérée (numéro de commande)
  qte INTEGER NOT NULL,
  prixunit NUMERIC(10,2) NOT NULL,
  remise NUMERIC(5,4) NOT NULL,

  montant_brut NUMERIC(18,2) NOT NULL,
  montant_net  NUMERIC(18,2) NOT NULL,
  port_alloc   NUMERIC(18,2) NOT NULL
);

-- 8) Fait Livraisons (grain = commande)
CREATE TABLE IF NOT EXISTS entreprise_dw.faitLivraisons (
  liv_key BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,

  datecom_key  INTEGER NOT NULL REFERENCES entreprise_dw.dimTemps(date_key),
  dateenv_key  INTEGER REFERENCES entreprise_dw.dimTemps(date_key),
  dateobj_key  INTEGER REFERENCES entreprise_dw.dimTemps(date_key),

  client_key BIGINT NOT NULL REFERENCES entreprise_dw.dimClient(client_key),
  employe_key BIGINT NOT NULL REFERENCES entreprise_dw.dimEmploye(employe_key),
  transporteur_key BIGINT REFERENCES entreprise_dw.dimTransporteur(transporteur_key),
  geo_key BIGINT REFERENCES entreprise_dw.dimGeoLivraison(geo_key),

  nocom INTEGER UNIQUE NOT NULL,
  port NUMERIC(10,2),

  delai_envoi_jours INTEGER,     -- dateenv - datecom
  retard_jours INTEGER           -- max(0, dateenv - dateobjliv)
);
