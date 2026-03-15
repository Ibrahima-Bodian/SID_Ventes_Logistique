-- Table Catégories
CREATE TABLE entreprise._categorie (
    codecateg SERIAL PRIMARY KEY,
    nomcateg VARCHAR(255) NOT NULL,
    description TEXT
);

-- Table Fournisseurs
CREATE TABLE entreprise._fournisseur (
    nofour SERIAL PRIMARY KEY,
    societe varchar(255) DEFAULT NULL,
    contact varchar(255) DEFAULT NULL,
    fonction varchar(255) DEFAULT NULL,
    adresse varchar(255) DEFAULT NULL,
    ville varchar(255) DEFAULT NULL,
    region varchar(255) DEFAULT NULL,
    codepostal varchar(255) DEFAULT NULL,
    pays varchar(255) DEFAULT NULL,
    tel varchar(255) DEFAULT NULL,
    fax varchar(255) DEFAULT NULL,
    pageaccueil TEXT DEFAULT NULL
);

-- Table Clients
CREATE TABLE entreprise._client (
    codecli varchar(255) PRIMARY KEY,
    societe varchar(255),
    contact varchar(255),
    fonction varchar(255),
    adresse varchar(255),
    ville varchar(255),
    region varchar(255),
    codepostal varchar(255),
    pays varchar(255),
    tel varchar(255),
    fax varchar(255)
);


-- Table Employés
CREATE TABLE entreprise._employe (
    noemp INTEGER PRIMARY KEY,
    nom varchar(255),
    prenom varchar(255),
    fonction varchar(255),
    titrecourtoisie varchar(255),
    datenaissance DATE,
    dateembauche DATE,
    adresse varchar(255),
    ville varchar(255),
    region varchar(255),
    codepostal varchar(255),
    pays varchar(255),
    teldom varchar(255),
    extension smallint,
    rendcomptea INTEGER NULL REFERENCES entreprise._employe(noemp)
);


-- Table Transporteurs
CREATE TABLE entreprise._transporteur (
    notran SERIAL PRIMARY KEY,
    nomtran varchar(255) DEFAULT NULL,
    tel varchar(255) DEFAULT NULL
);

-- Table Produits
CREATE TABLE entreprise._produit (
    refprod SERIAL PRIMARY KEY,
    nomprod varchar(255) DEFAULT NULL,
    nofour INTEGER NOT NULL REFERENCES entreprise._fournisseur(nofour),
    codecateg INTEGER NOT NULL REFERENCES entreprise._categorie(codecateg),
    qteparunit varchar(255) DEFAULT NULL,
    prixunit NUMERIC(6,2) DEFAULT NULL,
    unitesstock smallint,
    unitescom smallint,
    niveaureap smallint,
	indisponible smallint
);

-- Table Commandes
CREATE TABLE entreprise._commande (
    nocom SERIAL PRIMARY KEY,
    codecli VARCHAR(255) NOT NULL REFERENCES entreprise._client(codecli),
    noemp INTEGER NOT NULL REFERENCES entreprise._employe(noemp),
    datecom DATE NOT NULL,
    dateobjliv DATE DEFAULT NULL,
    dateenv DATE DEFAULT NULL,
    notran INTEGER REFERENCES entreprise._transporteur(notran),
    port NUMERIC(10,2) DEFAULT NULL,
    destinataire varchar(255) DEFAULT NULL,
    adrliv varchar(255) DEFAULT NULL,
    villeliv varchar(255) DEFAULT NULL,
    regionliv varchar(255) DEFAULT NULL,
    codepostalliv varchar(255) DEFAULT NULL,
    paysliv varchar(255) DEFAULT NULL
);

-- Table DetailCommande(Table de liaison)
CREATE TABLE entreprise._detailcommande (
    nocom INTEGER NOT NULL REFERENCES entreprise._commande(nocom),
    refprod INTEGER NOT NULL REFERENCES entreprise._produit(refprod),
    prixunit NUMERIC(10,2) NOT NULL,
    qte INTEGER NOT NULL CHECK (qte > 0),
    remise NUMERIC(3,2) DEFAULT 0 CHECK (remise >= 0 AND remise <= 1),
    PRIMARY KEY (nocom, refprod)  -- Clé primaire sur nocom + refprod
);


-- Insertion des données
INSERT INTO entreprise._categorie (codecateg, nomcateg, description) VALUES
(1, 'Boissons', 'Boissons, cafés, thés, bières'),
(2, 'Condiments Sauces', 'Assaisonnements et épices'),
(3, 'Desserts', 'Desserts et friandises'),
(4, 'Produits laitiers', 'Fromages'),
(5, 'Pâtes et céréales', 'Pains, biscuits, pâtes & céréales'),
(6, 'Viandes', 'Viandes préparées'),
(7, 'Produits secs', 'Fruits secs, raisins secs, autres'),
(8, 'Poissons et fruits de mer', 'Poissons, fruits de mer, escargots');

INSERT INTO entreprise._transporteur (notran, nomtran, tel) VALUES
(1, 'Speedy Express', '(503) 555-9831'),
(2, 'Forfait United', '(503) 555-3199'),
(3, 'Expédition fédérale', '(503) 555-9931');

INSERT INTO entreprise._employe
(noemp, nom, prenom, fonction, titrecourtoisie, datenaissance, dateembauche, adresse, ville, region, codepostal, pays, teldom, extension, rendcomptea)VALUES
(1,'Davolio','Nancy','Représentant(e)','Mlle', DATE '1960-12-08', DATE '2012-05-01','507 - 20th Ave. E. Apt. 2A','Seattle','WA','98122','Etats-Unis','(206) 555-9857',5467,2),
(2,'Fuller','Andrew','Vice-Président','Dr.', DATE '1972-12-19', DATE '2012-08-14','908 W. Capital Way','Tacoma','WA','98401','Etats-Unis','(206) 555-9482',3457,NULL),
(3,'Leverling','Janet','Représentant(e)','Mlle', DATE '1983-08-30', DATE '2012-04-01','722 Moss Bay Blvd.','Kirkland','WA','98033','Etats-Unis','(206) 555-3412',3355,2),
(4,'Peacock','Margaret','Représentant(e)','Mme', DATE '1957-09-19', DATE '2013-05-03','4110 Old Redmond Rd.','Redmond','WA','98052','Etats-Unis','(206) 555-8122',5176,'2'),
(5,'Buchanan','Steven','Chef des ventes','M.', DATE '1975-03-04', DATE '2013-10-17','14 Garrett Hill','Londres','unknown','SW1 8JR','Royaume-Uni','(71) 555-4848',345,'2'),
(6,'Suyama','Michael','Représentant(e)','M.', DATE '1983-07-02', DATE '2013-10-17','Coventry House Miner Rd.','Londres','unknown','EC2 7JR','Royaume-Uni','(71) 555-7773',428,'7'),
(7,'Emery','Patrick','Chef des ventes','M.', DATE '1980-05-29', DATE '2014-01-02','Edgeham Hollow Winchester Way','Londres','unknown','RG1 9SP','Royaume-Uni','(71) 555-5598',465,'5'),
(8,'Callahan','Laura','Assistante commerciale','Mlle', DATE '1978-01-09', DATE '2014-03-05','4726 - 11th Ave. NE','Seattle','WA','98105','Etats-Unis','(206) 555-1189',2344,'2'),
(9,'Dodsworth','Anne','Représentant(e)','Mlle', DATE '1986-01-27', DATE '2014-11-15','7 Houndstooth Rd.','London','unknown','WG2 7LT','Royaume-Uni','(71) 555-4444',452,'5'),
(10,'Suyama','Jordan','Représentant(e)','M.', DATE '1983-07-02', DATE '2013-10-21','Coventry House Miner Rd.','Londres','unknown','EC2 7JR','Royaume-Uni','(71) 555-7773',428,'7');