// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get cancel => 'Annuler';

  @override
  String get windowMinimize => 'Réduire';

  @override
  String get windowMaximize => 'Agrandir';

  @override
  String get windowRestore => 'Restaurer';

  @override
  String get databaseExplorer => 'Explorateur de bases de données';

  @override
  String get databases => 'Bases de données';

  @override
  String get newConnection => 'Nouvelle connexion';

  @override
  String get filterTree => 'Filtrer les connexions et les objets';

  @override
  String get treeFilterScope => 'Filtre les objets chargés de l’arborescence';

  @override
  String get searchObjects => 'Rechercher des objets de base de données';

  @override
  String get fileMenu => 'Fichier';

  @override
  String get editMenu => 'Modifier';

  @override
  String get viewMenu => 'Affichage';

  @override
  String get connectionMenu => 'Connexion';

  @override
  String get objectMenu => 'Objet';

  @override
  String get runMenu => 'Options d’exécution';

  @override
  String get commands => 'Commandes';

  @override
  String get findCommand => 'Rechercher une commande';

  @override
  String get newSql => 'Nouvelle requête';

  @override
  String get openSql => 'Ouvrir SQL';

  @override
  String get openSqlFile => 'Ouvrir un fichier SQL';

  @override
  String get saveSql => 'Enregistrer SQL';

  @override
  String get closeTab => 'Fermer l’onglet';

  @override
  String get openWorkspace => 'Ouvrir l’espace de travail';

  @override
  String get saveWorkspace => 'Enregistrer l’espace de travail';

  @override
  String get settings => 'Paramètres';

  @override
  String get findText => 'Rechercher';

  @override
  String get replaceText => 'Remplacer';

  @override
  String get formatSql => 'Formater SQL';

  @override
  String get lineComments => 'Basculer les commentaires de ligne';

  @override
  String get snippets => 'Extraits SQL';

  @override
  String get run => 'Exécuter';

  @override
  String get runStatement => 'Exécuter l’instruction actuelle';

  @override
  String get runSelection => 'Exécuter la sélection';

  @override
  String get runScript => 'Exécuter le script';

  @override
  String get explain => 'Plan d’exécution';

  @override
  String get explainAnalyze => 'Plan avec exécution';

  @override
  String get connect => 'Connecter';

  @override
  String get disconnect => 'Déconnecter';

  @override
  String get sessionDetails => 'Détails de la session';

  @override
  String get beginTransaction => 'Démarrer une transaction';

  @override
  String get commitTransaction => 'Valider la transaction';

  @override
  String get rollbackTransaction => 'Annuler la transaction';

  @override
  String get enableAutoCommit => 'Activer la validation automatique';

  @override
  String get disableAutoCommit => 'Désactiver la validation automatique';

  @override
  String get outcomeUnknown => 'Résultat inconnu';

  @override
  String get outcomeUnknownNote =>
      'L’opération peut être terminée. Cette session ne peut plus exécuter de SQL. Ne réessayez jamais automatiquement ; vérifiez le résultat avant de commencer un nouveau travail.';

  @override
  String get notConnected => 'Déconnecté';

  @override
  String get autoCommit => 'Validation automatique';

  @override
  String get manualTransaction => 'Transaction manuelle';

  @override
  String get readOnlyPolicy => 'Politique de lecture seule BusyData';

  @override
  String get data => 'Données';

  @override
  String get structure => 'Structure';

  @override
  String get results => 'Résultats';

  @override
  String get messages => 'Messages';

  @override
  String get plan => 'Plan';

  @override
  String get changes => 'Modifications';

  @override
  String get history => 'Historique';

  @override
  String get jobs => 'Tâches';

  @override
  String get retainedResults => 'Résultats conservés';

  @override
  String get recoverEdits => 'Récupérer les modifications préparées';

  @override
  String get applyAndCommit => 'Appliquer et valider';

  @override
  String get inspectStructure => 'Inspecter la structure';

  @override
  String get openData => 'Ouvrir les données';

  @override
  String get openDefinition => 'Ouvrir la définition';

  @override
  String get copyQualifiedName => 'Copier le nom qualifié';

  @override
  String get refresh => 'Actualiser';

  @override
  String get columns => 'Colonnes';

  @override
  String get indexes => 'Index';

  @override
  String get constraints => 'Clés et contraintes';

  @override
  String get foreignKeys => 'Clés étrangères';

  @override
  String get triggers => 'Déclencheurs';

  @override
  String get definition => 'Définition';

  @override
  String get dependencies => 'Dépendances';

  @override
  String get connectionCapabilities => 'Vue de la connexion';

  @override
  String get sessionsAndLocks => 'Sessions et verrous';

  @override
  String get usersAndRoles => 'Utilisateurs et rôles';

  @override
  String get saveSnapshot => 'Enregistrer un instantané du schéma';

  @override
  String get compareSchemas => 'Comparer les schémas';

  @override
  String get objectDesigner => 'Concepteur d’objets';

  @override
  String get diagram => 'Diagramme ER';

  @override
  String get backup => 'Sauvegarde';

  @override
  String get restore => 'Restaurer';

  @override
  String get importData => 'Importer des données';

  @override
  String get exportRetained => 'Exporter les données conservées';

  @override
  String get exportSql => 'Exécuter un export SQL';

  @override
  String get stageInsert => 'Insérer une ligne';

  @override
  String get stageUpdate => 'Modifier une ligne';

  @override
  String get stageDelete => 'Supprimer une ligne';

  @override
  String get discardChanges => 'Abandonner les modifications préparées';

  @override
  String get disposeResult => 'Libérer les données conservées';

  @override
  String get currentSchema => 'Schéma actuel (à modifier)';

  @override
  String get desiredSchema => 'Schéma souhaité';

  @override
  String get applyTo => 'Appliquer à';

  @override
  String get loading => 'Chargement';

  @override
  String get empty => 'Aucun objet dans ce périmètre';

  @override
  String get more => 'Plus';

  @override
  String get filter => 'Filtrer';

  @override
  String get sort => 'Trier';

  @override
  String get selectTarget => 'Choisir une connexion';

  @override
  String get requireSql => 'Nécessite un document SQL';

  @override
  String get requireSession =>
      'Nécessite une session connectée dont l’état est connu';

  @override
  String get requireResult => 'Nécessite des données conservées';

  @override
  String get requireObject => 'Nécessite un objet cible';

  @override
  String get cancelRequested => 'Annulation demandée';

  @override
  String get cancelled => 'Annulé';

  @override
  String get queued => 'En attente';

  @override
  String get running => 'En cours';

  @override
  String get completed => 'Terminé';

  @override
  String get failed => 'Échec';

  @override
  String get partial => 'Partiel';

  @override
  String get sessionSharing => 'Partager une session existante (avancé)';

  @override
  String get production => 'Production';

  @override
  String get staging => 'Préproduction';

  @override
  String get development => 'Développement';

  @override
  String get executionOptions => 'Options d’exécution';

  @override
  String get resultRowLimit => 'Limite de lignes du résultat (1–1000000)';

  @override
  String get boundedRead => 'Lecture limitée';

  @override
  String get streamingRead =>
      'Lecture en flux · possède une transaction de lecture';

  @override
  String get stopOnError => 'Arrêter le script en cas d’erreur';

  @override
  String get continueOnError =>
      'Continuer en cas d’erreur · les instructions précédentes peuvent être validées';

  @override
  String get loadMore => 'Charger la suite';

  @override
  String get favorite => 'Basculer le favori';

  @override
  String get connectionGroup => 'Groupe de connexions';

  @override
  String get copyRange => 'Copier la plage';

  @override
  String get inspectValue => 'Inspecter la valeur';

  @override
  String get editConnection => 'Modifier la connexion';

  @override
  String get chooseSnapshot => 'Choisir un instantané';

  @override
  String get captureSchema => 'Capturer le schéma';

  @override
  String get sameSchemaRestriction =>
      'Les instantanés doivent avoir le même moteur, nom de schéma et format de version. Comparer et enregistrer n’applique jamais de modifications.';

  @override
  String get restoredTaskState =>
      'Cette référence de document a été restaurée. Les données du backend, sessions et tâches précédentes ne sont plus disponibles. Choisissez une action explicite pour commencer un nouveau travail ; la restauration ne connecte pas, n’exécute pas de SQL et ne rejoue pas les modifications.';

  @override
  String get preChangeSnapshot =>
      'Instantané avant modification · modifications validées. Actualisez explicitement pour inspecter les lignes actuelles et les valeurs par défaut du serveur.';

  @override
  String get sqlProvenance => 'Provenance SQL';

  @override
  String get assessEditing => 'Évaluer la modification';

  @override
  String get viewDetails => 'Afficher les détails';

  @override
  String get gridMenu => 'Grille de données';

  @override
  String get visibleColumns => 'Colonnes visibles';

  @override
  String get hidden => 'Masquée';

  @override
  String get ascending => 'Croissant';

  @override
  String get descending => 'Décroissant';

  @override
  String get equals => 'Égal à';

  @override
  String get notEqual => 'Différent de';

  @override
  String get lessThan => 'Inférieur à';

  @override
  String get greaterThan => 'Supérieur à';

  @override
  String get isNull => 'Est NULL';

  @override
  String get isNotNull => 'N’est pas NULL';

  @override
  String get exactValue => 'Valeur exacte';

  @override
  String get sortTable => 'Trier les données de table';

  @override
  String get filterTable => 'Filtrer les données de table';

  @override
  String get sortRetained => 'Trier l’instantané conservé';

  @override
  String get filterRetained => 'Filtrer l’instantané conservé';

  @override
  String get applyView => 'Appliquer';

  @override
  String get rowsLabel => 'Lignes';

  @override
  String get fetchedRows => 'Lignes récupérées';

  @override
  String get fixedSnapshot => 'Instantané fixe des lignes récupérées';

  @override
  String get limitReached => 'Limite atteinte';

  @override
  String get retainedData => 'Données conservées';

  @override
  String get applyRequiresAutoCommit =>
      'Appliquer et valider exige une session inactive avec validation automatique activée.';

  @override
  String get connectionProfile => 'Profil de connexion';

  @override
  String get basic => 'Général';

  @override
  String get advanced => 'Avancé';

  @override
  String get connectionName => 'Nom';

  @override
  String get hostname => 'Nom d’hôte (aussi pour la vérification TLS)';

  @override
  String get port => 'Port';

  @override
  String get database => 'Base de données';

  @override
  String get user => 'Utilisateur';

  @override
  String get password => 'Mot de passe';

  @override
  String get writableProfile => 'Profil modifiable';

  @override
  String get readonlyProfile => 'Profil en lecture seule';

  @override
  String get tlsVerify => 'TLS : vérifier certificat et nom d’hôte';

  @override
  String get tlsInsecure => 'TLS : NON SÉCURISÉ, sans vérification';

  @override
  String get tlsDisabled => 'TLS : DÉSACTIVÉ';

  @override
  String get testConnection => 'Tester sans enregistrer';

  @override
  String get saveProfile => 'Enregistrer';

  @override
  String get saveConnect => 'Enregistrer et connecter';

  @override
  String get sessionPassword => 'Mot de passe pour cette session';

  @override
  String get storedPassword =>
      'Conserver le mot de passe dans le stockage sécurisé du système';

  @override
  String get chooseFile => 'Choisir un fichier';

  @override
  String get testRunning => 'Test de connexion…';

  @override
  String get cancelTest => 'Annuler le test';

  @override
  String get idle => 'Au repos';

  @override
  String get activeTransaction => 'Transaction ouverte';

  @override
  String get failedTransaction => 'Transaction en échec';

  @override
  String get inspectionContext => 'Session d’inspection';

  @override
  String get requireTableOrView => 'Sélectionner une table ou une vue';

  @override
  String get operationPending =>
      'Une opération du document attend une confirmation';

  @override
  String get requirePlan => 'Sélectionner une exécution Explain conservée';

  @override
  String get openPlanDocument => 'Ouvrir le document du plan';

  @override
  String get locks => 'Verrous';

  @override
  String get statistics => 'Statistiques';

  @override
  String get queryStatistics => 'Statistiques des requêtes';

  @override
  String get indexDiagnostics => 'Diagnostic des index';

  @override
  String get grants => 'Droits accordés';

  @override
  String get sqlExecution => 'Exécution SQL';

  @override
  String get planReady => 'Plan conservé prêt ; SQL n’a pas été réexécuté';

  @override
  String get executionPlan => 'Plan d’exécution';

  @override
  String get openOwner => 'Ouvrir le propriétaire';

  @override
  String get terminateActivity => 'Terminer l’activité';

  @override
  String get close => 'Fermer';

  @override
  String get previous => 'Précédent';

  @override
  String get next => 'Suivant';

  @override
  String get replaceSelection => 'Remplacer la sélection';

  @override
  String get replaceAll => 'Tout remplacer';

  @override
  String get restartBackend => 'Redémarrer le backend';

  @override
  String get structuredTree => 'Arbre structuré';

  @override
  String get rawOutput => 'Sortie brute';

  @override
  String get previousTextPage => 'Page de texte précédente';

  @override
  String get nextTextPage => 'Page de texte suivante';

  @override
  String get filterChangedObjects => 'Filtrer les objets modifiés';

  @override
  String get rebindVerifiedEdits => 'Réassocier les modifications vérifiées';

  @override
  String get discardRecoveryRecord =>
      'Supprimer l’enregistrement de récupération';

  @override
  String get revertChange => 'Annuler la modification en attente';

  @override
  String get chooseSource => 'Choisir la source';

  @override
  String get chooseDestination => 'Choisir la destination';

  @override
  String get delimiterField => 'Délimiteur (un caractère)';

  @override
  String get batchRowsField => 'Lignes par lot (1–1000)';

  @override
  String get rejectedLimit => 'Limite de lignes rejetées (1–1000)';

  @override
  String get previewSource => 'Aperçu de la source';

  @override
  String get reviewTransfer => 'Examiner le transfert';

  @override
  String get startImport => 'Démarrer l’importation';

  @override
  String get startRestore => 'Démarrer la restauration';

  @override
  String get startExport => 'Démarrer l’exportation';

  @override
  String get requestCancel => 'Demander l’annulation';

  @override
  String get sourceMapping => 'Correspondance source et cible';

  @override
  String get nativeTool => 'Outil natif';

  @override
  String get defaultOmit => 'Omettre / valeur par défaut de la base';

  @override
  String get overwriteNever => 'Ne pas écraser';

  @override
  String get overwriteExisting => 'Écraser le fichier existant';

  @override
  String get planDetails => 'Détails du plan';

  @override
  String get planMetricsNote =>
      'Les estimations et mesures réelles utilisent les noms de champs du serveur. Les mesures manquantes sont indisponibles.';

  @override
  String get connected => 'Connecté';

  @override
  String get disconnected => 'Déconnecté';

  @override
  String get tables => 'Tables';

  @override
  String get views => 'Vues';

  @override
  String get routines => 'Routines';

  @override
  String get expand => 'Développer';

  @override
  String get collapse => 'Réduire';

  @override
  String get databaseWorkbench => 'Atelier de base de données';

  @override
  String get sidebar => 'Barre latérale';

  @override
  String get unchanged => 'Inchangé';

  @override
  String get reviewDetails => 'Détails de la révision';

  @override
  String get generatedSql => 'SQL généré';

  @override
  String get changeReverted =>
      'Modification annulée. Demandez une nouvelle révision.';

  @override
  String get unknownBatch =>
      'Résultat inconnu. Le lot peut avoir été validé. Ne le rejouez jamais automatiquement ; vérifiez la session et l’enregistrement de récupération.';

  @override
  String get expiredChangeReview =>
      'La cible a changé ou la révision a expiré. Demandez une nouvelle révision.';

  @override
  String get applyCommitExplanation =>
      'Appliquer et valider démarre et valide sa propre transaction. La console source doit être inactive avec la validation automatique activée. Résolvez séparément les transactions SQL manuelles.';

  @override
  String get newRow => 'Nouvelle ligne';

  @override
  String get original => 'Original';

  @override
  String get proposed => 'Proposé';

  @override
  String changeCounts(int inserts, int updates, int deletes) {
    return '$inserts insertions · $updates modifications · $deletes suppressions';
  }

  @override
  String sourceRow(String row) {
    return 'Ligne source $row';
  }

  @override
  String get refreshing => 'Actualisation…';

  @override
  String get refreshActivities => 'Actualiser les activités';

  @override
  String get explicitRefresh => 'Actualisation explicite';

  @override
  String get pollFiveSeconds => 'Interroger toutes les 5 secondes';

  @override
  String get cancelSelectedActivity => 'Annuler l’activité sélectionnée';

  @override
  String get terminateSelectedSession => 'Terminer la session sélectionnée';

  @override
  String get filterActivities => 'Filtrer les activités actuelles';

  @override
  String get blockedBy => 'Bloqué par :';

  @override
  String get delete => 'Supprimer';

  @override
  String get remove => 'Supprimer';

  @override
  String get up => 'Haut';

  @override
  String get search => 'Chercher';

  @override
  String get yes => 'Oui';

  @override
  String get no => 'Non';

  @override
  String get clear => 'Vider';

  @override
  String get copy => 'Copier';

  @override
  String get insert => 'Insérer';

  @override
  String get update => 'Mettre à jour';

  @override
  String get open => 'Ouvrir';

  @override
  String get migrationEngineMismatch =>
      'La connexion cible doit utiliser le même moteur que les instantanés comparés. La migration entre moteurs est indisponible.';

  @override
  String get metadataContextChanged =>
      'Le contexte d’inspection a changé. Actualisez explicitement les métadonnées.';

  @override
  String get newTableName => 'Nom de la nouvelle table';

  @override
  String get routineIdentity => 'Identité exacte de la routine';

  @override
  String get objectColumnName => 'Nom de l’objet / colonne';

  @override
  String get builtInType => 'Type intégré';

  @override
  String get sqlExpression => 'Expression SQL (vide pour la supprimer)';

  @override
  String get newPropertyValue => 'Nouvelle valeur de propriété';

  @override
  String get columnComment => 'Commentaire de colonne';

  @override
  String get columnCollation =>
      'Classement de colonne (vide pour le réglage du serveur)';

  @override
  String get addDesignedColumn => 'Ajouter une colonne à la nouvelle table';

  @override
  String get checkExpression => 'Expression CHECK';

  @override
  String get referencedSchema => 'Schéma / base de données référencée';

  @override
  String get generating => 'Génération…';

  @override
  String get generateReviewedDdl => 'Générer le DDL à examiner';

  @override
  String get inspectCapturedDefinition => 'Inspecter la définition capturée';

  @override
  String get capturedObject => 'Objet capturé';

  @override
  String get designReviewNote =>
      'Les modifications sont générées pour examen. Le contenu de la base reste inchangé jusqu’à l’exécution examinée.';

  @override
  String get columnMetadataUnavailable =>
      'Les métadonnées de colonnes sont indisponibles dans ce périmètre ; inspectez le schéma sélectionné avant de concevoir une liste de colonnes.';

  @override
  String get ordinaryColumn => 'Colonne ordinaire';

  @override
  String get columnWithDefault => 'Colonne avec valeur par défaut';

  @override
  String get identityColumn => 'Identité / incrément automatique';

  @override
  String get generatedColumn => 'Colonne générée';

  @override
  String get columnType => 'Type de colonne';

  @override
  String get nullableNotNull => 'NULL autorisé / NOT NULL';

  @override
  String get defaultExpression => 'Expression par défaut';

  @override
  String get generatedExpression => 'Expression générée';

  @override
  String get columnCollationProperty => 'Classement de colonne';

  @override
  String get loggedUnlogged => 'Journalisée / non journalisée';

  @override
  String get tableComment => 'Commentaire de table';

  @override
  String get storageEngine => 'Moteur de stockage';

  @override
  String get tableCollation => 'Classement de table';

  @override
  String get rowFormat => 'Format de ligne';

  @override
  String get createOrReplace => 'Créer ou remplacer';

  @override
  String get dropSelectedObject => 'Supprimer l’objet sélectionné';

  @override
  String get addColumn => 'Ajouter une colonne';

  @override
  String get editColumnProperties => 'Modifier les propriétés de colonne';

  @override
  String get tableProperties => 'Propriétés de table';

  @override
  String get triggerDefinition => 'Définition du déclencheur';

  @override
  String get createTable => 'Créer une table';

  @override
  String get viewDefinition => 'Définition de vue';

  @override
  String get routineDefinition => 'Définition de routine';

  @override
  String get chooseExistingObject => 'Choisir un objet existant';

  @override
  String get nullable => 'NULL autorisé';

  @override
  String get removeIdentity => 'Supprimer l’identité';

  @override
  String get generatedAlways => 'Toujours généré';

  @override
  String get generatedByDefault => 'Généré par défaut / incrément automatique';

  @override
  String get loggedTable => 'Table journalisée';

  @override
  String get unloggedTable => 'Table non journalisée';

  @override
  String get orderedPrimaryKeyColumns => 'Colonnes ordonnées de clé primaire';

  @override
  String get orderedColumns => 'Colonnes ordonnées';

  @override
  String get ordinaryIndex => 'Index ordinaire';

  @override
  String get uniqueIndex => 'Index unique';

  @override
  String get primaryKey => 'Clé primaire';

  @override
  String get uniqueConstraint => 'Contrainte d’unicité';

  @override
  String get foreignKey => 'Clé étrangère';

  @override
  String get checkConstraint => 'Contrainte CHECK';

  @override
  String get immediateChecking => 'Vérification immédiate';

  @override
  String get deferrableChecking => 'Vérification différable';

  @override
  String get initiallyImmediate => 'Initialement immédiate';

  @override
  String get initiallyDeferred => 'Initialement différée';

  @override
  String get referencedTable => 'Table référencée';

  @override
  String get orderedReferencedColumns =>
      'Colonnes référencées dans l’ordre correspondant';

  @override
  String get objectDefinitionEditor =>
      'Éditeur SQL de définition native de l’objet';

  @override
  String get onDelete => 'À la suppression';

  @override
  String get onUpdate => 'À la mise à jour';

  @override
  String get stay => 'Rester';

  @override
  String get saveSqlClose => 'Enregistrer SQL et fermer';

  @override
  String get discardSqlClose => 'Abandonner SQL et fermer';

  @override
  String get closeBusyData => 'Fermer BusyData';

  @override
  String get saveDraftsClose => 'Enregistrer les brouillons et fermer';

  @override
  String get closeWithoutRecovery => 'Fermer sans récupération';

  @override
  String get recoveryFailed => 'Échec de la récupération';

  @override
  String get discardFailedSaveClose =>
      'Abandonner l’enregistrement échoué et fermer';

  @override
  String get closeWithoutSavingRecovery =>
      'Fermer sans enregistrer la récupération';

  @override
  String get disableSqlRecovery => 'Désactiver la récupération SQL';

  @override
  String get historyPrivacy => 'Confidentialité de l’historique';

  @override
  String get enableSqlRetention => 'Activer la conservation SQL';

  @override
  String get disableSqlRetention => 'Désactiver la conservation SQL';

  @override
  String get clearHistory => 'Effacer l’historique';

  @override
  String get deleteHistoryEntry => 'Supprimer l’entrée d’historique';

  @override
  String get deleteSelected => 'Supprimer la sélection';

  @override
  String get saveRetention => 'Enregistrer la conservation';

  @override
  String get retentionDays => 'Jours de conservation';

  @override
  String get sqlTextRetained => 'Texte SQL conservé';

  @override
  String get sqlTextDisabled => 'Texte SQL désactivé';

  @override
  String get openHistoryQuery => 'Ouvrir dans un nouvel onglet SQL';

  @override
  String get caCertificateFile => 'Fichier de certificat CA';

  @override
  String get clientCertificateFile => 'Fichier de certificat client';

  @override
  String get clientKeyFile => 'Fichier de clé client';

  @override
  String get directConnection => 'Connexion directe';

  @override
  String get sshTunnel => 'Tunnel SSH';

  @override
  String get sshHost => 'Hôte SSH';

  @override
  String get sshPort => 'Port SSH';

  @override
  String get sshUser => 'Utilisateur SSH';

  @override
  String get reviewedKnownHosts => 'Fichier known_hosts vérifié';

  @override
  String get reviewSshKey => 'Vérifier la clé d’hôte SSH';

  @override
  String get changedSshKey => 'Clé d’hôte SSH modifiée';

  @override
  String get verifyFingerprint =>
      'Vérifiez cette empreinte indépendamment avant de lui faire confiance.';

  @override
  String get selectedKeyPassword => 'Clé ou mot de passe sélectionné';

  @override
  String get selectedAgentIdentity => 'Identité sélectionnée de l’agent SSH';

  @override
  String get selectedAgentSocket =>
      'Socket d’agent Linux / canal nommé Windows sélectionné';

  @override
  String get selectedKeyFingerprint =>
      'Empreinte de la clé sélectionnée · SHA256:…';

  @override
  String get selectedPrivateKey => 'Clé privée sélectionnée (facultatif)';

  @override
  String get sshPassword => 'Mot de passe SSH';

  @override
  String get keyPassphrase => 'Phrase secrète de la clé';

  @override
  String get connectionTimeout => 'Délai de connexion · 1–120 secondes';

  @override
  String get sqlTimeout =>
      'Délai d’exécution/lecture SQL · 1–3600 secondes (0 = 60)';

  @override
  String get schemasEquivalent => 'Les schémas capturés sont équivalents.';

  @override
  String get migrationComplete =>
      'La migration couvre les différences capturées prises en charge.';

  @override
  String get migrationPartial =>
      'Migration partielle ; des différences non prises en charge restent.';

  @override
  String get differencesLimited =>
      'La présentation des différences est limitée. Vérifiez les captures enregistrées complètes et le SQL généré.';

  @override
  String get absent => 'Absent';

  @override
  String get definitionPreviewLimited =>
      'L’aperçu de définition est limité ; utilisez la capture d’origine pour les preuves complètes.';

  @override
  String get migrationBatchNote =>
      'SQL forme un seul lot ordonné par dépendances. La sélection d’un objet sert à l’inspection et ne sélectionne pas d’instructions à appliquer.';

  @override
  String get unsupportedLabel => 'Non pris en charge';

  @override
  String get differenceAdded => 'Ajouté';

  @override
  String get differenceRemoved => 'Supprimé';

  @override
  String get differenceChanged => 'Modifié';

  @override
  String get selectHistoryEntry => 'Sélectionnez une entrée d’historique';

  @override
  String get searchSqlTarget => 'Rechercher SQL ou cible';

  @override
  String get closeSqlTab => 'Fermer l’onglet SQL';

  @override
  String get historyMetadataRetained =>
      'Les métadonnées d’état et de cible restent dans l’historique.';

  @override
  String get historyPreviewNote =>
      'Aperçu uniquement. Ouvrez dans un nouvel onglet SQL pour récupérer le texte conservé.';

  @override
  String get selected => 'Sélectionné';

  @override
  String get authReviewNote =>
      'Vérifiez le principal exact et la cible avant l’application. Les identifiants ne sont jamais placés dans les documents SQL ni l’historique. Connexions existantes et mots de passe enregistrés restent séparés.';

  @override
  String get createLogin => 'Créer un compte de connexion';

  @override
  String get createRole => 'Créer un rôle sans connexion';

  @override
  String get setPassword => 'Définir le mot de passe';

  @override
  String get preventLogin => 'Empêcher les nouvelles connexions';

  @override
  String get allowLogin => 'Autoriser les nouvelles connexions';

  @override
  String get dropPrincipal => 'Supprimer le principal';

  @override
  String get principalName => 'Nom exact du principal';

  @override
  String get accountHost =>
      'Hôte exact du compte (les jokers élargissent la connexion)';

  @override
  String get newPassword => 'Nouveau mot de passe';

  @override
  String get repeatPassword => 'Répéter le nouveau mot de passe';

  @override
  String get reviewAccount => 'Vérifier l’opération de compte';

  @override
  String get passwordsMismatch =>
      'Saisissez deux fois le même mot de passe non vide';

  @override
  String get accountSubmitFailed =>
      'L’opération de compte n’a pas pu être envoyée. Vérifiez cible, politique d’authentification et privilèges de base de données.';

  @override
  String get privilegeReviewNote =>
      'Inspectez les droits directs ; le SQL généré exige toujours une vérification avant exécution.';

  @override
  String get inspectionLimited =>
      'Limité à 500 lignes par section. Affinez la recherche ; une section vide ne prouve pas l’absence d’accès effectif.';

  @override
  String get findPrincipal => 'Chercher un nom d’utilisateur / rôle';

  @override
  String get searchPrincipals => 'Rechercher les principaux';

  @override
  String get choosePrincipal => 'Choisir un principal';

  @override
  String get inspectGrants => 'Inspecter les droits sélectionnés';

  @override
  String get tablePrivileges => 'Droits de table / vue';

  @override
  String get schemaPrivileges => 'Droits de schéma';

  @override
  String get databasePrivileges => 'Droits de base de données';

  @override
  String get roleMembership => 'Appartenance aux rôles';

  @override
  String get defaultRole => 'Activation du rôle par défaut';

  @override
  String get chooseGrantRole => 'Choisir le rôle à accorder / révoquer';

  @override
  String get tableView => 'Table / vue';

  @override
  String get explicitPrivileges =>
      'Droits explicites (séparés par des virgules)';

  @override
  String get setDefaultRole => 'Définir le rôle par défaut sélectionné';

  @override
  String get clearDefaultRole => 'Retirer le rôle par défaut';

  @override
  String get grantAccess => 'Accorder l’accès';

  @override
  String get revokeAccess => 'Révoquer l’accès';

  @override
  String get withoutDelegation => 'Sans délégation';

  @override
  String get allowDelegation =>
      'Autoriser le destinataire à accorder à d’autres';

  @override
  String get readonlyChanges =>
      'Ce profil est en lecture seule. Les changements exigent une session explicitement accessible en écriture.';

  @override
  String get createPrincipal => 'Créer un utilisateur / rôle';

  @override
  String get manageAuthentication => 'Gérer l’authentification sélectionnée';

  @override
  String get openPrivilegeSql => 'Ouvrir le SQL des droits pour vérification';

  @override
  String get inspectPrincipalFirst =>
      'Inspectez le principal sélectionné avant de préparer un changement';

  @override
  String get accountAuthentication => 'Authentification du compte';

  @override
  String get schema => 'Schéma';

  @override
  String get available => 'Disponible';

  @override
  String get availableEmpty => 'Disponible · données vides';

  @override
  String get limitedVisibility => 'Visibilité ou portée limitée';

  @override
  String get permissionDenied => 'Permission refusée';

  @override
  String get unavailable => 'Indisponible';

  @override
  String get profileDisabled => 'Désactivé par le profil';

  @override
  String get unknownState => 'Inconnu';

  @override
  String get inspecting => 'Inspection…';

  @override
  String get refreshCapabilities => 'Actualiser les capacités';

  @override
  String get staleRefresh => 'Périmé · actualiser après connexion';

  @override
  String get staleContext =>
      'Périmé · actualiser après connexion ou changement de contexte';

  @override
  String get partialTreeLimit =>
      'Partiel · limite de l’arbre atteinte ; affinez avec la recherche d’objets';

  @override
  String get schemaComparison => 'Comparaison de schémas';

  @override
  String get searchTable => 'Rechercher une table';

  @override
  String get focusObject => 'Centrer';

  @override
  String get exportSvg => 'Exporter SVG';

  @override
  String get exportPng => 'Exporter PNG';

  @override
  String get diagramNotes => 'Notes du diagramme (incluses dans SVG)';

  @override
  String get openNotes => 'Ouvrir les notes';

  @override
  String get saveNotes => 'Enregistrer les notes';

  @override
  String get newSnippet => 'Nouvel extrait';

  @override
  String get snippetName => 'Nom de l’extrait';

  @override
  String get saveSnippet => 'Enregistrer l’extrait';

  @override
  String get deleteSnippet => 'Supprimer l’extrait enregistré';

  @override
  String get insertSnippet => 'Insérer dans le document SQL';

  @override
  String get snippetEditor => 'Éditeur d’extraits SQL';

  @override
  String get snippetsNote =>
      'Insérez le SQL local enregistré dans le document capturé avec annulation. L’exécution reste explicite.';

  @override
  String get level => 'Niveau';

  @override
  String get expanded => 'développé';

  @override
  String get collapsed => 'réduit';

  @override
  String get treeLevel => 'Niveau';

  @override
  String get retainedView => 'Vue retenue';

  @override
  String get tableQuerySnapshot => 'Instantané de requête de table';

  @override
  String get originalResultNote =>
      'Résultat retenu original ; pagination et inspection n’exécutent pas de SQL';

  @override
  String get tableFilterNote =>
      'Appliquer envoie une nouvelle requête vérifiée. L’instantané précédent reste disponible.';

  @override
  String get retainedFilterNote =>
      'Toutes les lignes récupérées dans un instantané fixe. SQL n’est pas relancé. L’ordre retenu peut différer du classement de la base.';

  @override
  String get retainedRowNote =>
      'Choisissez une ligne du résultat déjà récupéré. SQL n’est pas relancé.';

  @override
  String get copyLimitNote =>
      'Copie limitée à 10 000 cellules ; exportez les données retenues pour de plus grandes plages.';

  @override
  String get inlineValueLimit =>
      'L’édition directe accepte des valeurs de 8KiB';

  @override
  String get editContextChanged =>
      'Session source ou contexte d’édition modifié ; inspectez ou actualisez l’évaluation avant de préparer les changements';

  @override
  String get editAssessmentUnavailable =>
      'Édition indisponible ; actualisez l’évaluation lorsque la session est inactive';

  @override
  String get rowChangeReverted =>
      'Changement de ligne en attente annulé ; base inchangée';

  @override
  String get sqlCopyRequiresMetadata =>
      'La copie SQL nécessite le backend et ses métadonnées de types retenues.';

  @override
  String get exportFullValue => 'Exporter la valeur retenue complète';

  @override
  String valueExportReview(String bytes, String path) {
    return 'Enregistrer $bytes octets dans $path ? Le contenu existant sera remplacé. SQL n’est pas relancé.';
  }

  @override
  String get goToRetainedRow => 'Aller à la ligne retenue';

  @override
  String get row => 'Ligne';

  @override
  String get go => 'Aller';

  @override
  String get retryRows => 'Réessayer les lignes retenues';

  @override
  String get previousRows => 'Lignes précédentes';

  @override
  String get nextRows => 'Lignes suivantes';

  @override
  String get firstWindow => 'Première fenêtre retenue';

  @override
  String get lastWindow => 'Dernière fenêtre récupérée';

  @override
  String get setNull => 'Définir NULL';

  @override
  String copyFormat(String format) {
    return 'Copier $format';
  }

  @override
  String get textValue => 'Texte';

  @override
  String get sqlValues => 'Valeurs SQL';

  @override
  String get rowSelection => 'Sélection de lignes';

  @override
  String selectRow(String row) {
    return 'Sélectionner la ligne $row';
  }

  @override
  String columnHeader(String column) {
    return 'Colonne $column';
  }

  @override
  String get pendingChange => 'changement en attente';

  @override
  String get readonlyCell => 'Cellule en lecture seule';

  @override
  String get editableCell => 'Cellule modifiable';

  @override
  String get loadValueFirst => 'Chargez d’abord cette valeur retenue';

  @override
  String get editUnavailable => 'Édition indisponible';

  @override
  String get editCell => 'Modifier la cellule';

  @override
  String get unsupportedEditValue =>
      'Cette valeur retenue permet seulement l’inspection';

  @override
  String bytesCount(String bytes) {
    return '$bytes octets';
  }

  @override
  String get problems => 'Problèmes';

  @override
  String get ownedSessions => 'Sessions détenues';

  @override
  String get noProblems => 'Aucun problème enregistré';

  @override
  String get duplicateConnection => 'Dupliquer la connexion';

  @override
  String get deleteConnection => 'Supprimer la connexion';

  @override
  String deleteConnectionReview(String name) {
    return 'Supprimer $name ? Les sessions physiques existantes gardent leurs paramètres d’origine.';
  }

  @override
  String get unresolvedSessions => 'Sessions non résolues';

  @override
  String get disconnectSessionNote =>
      'Réglez d’abord les tâches et transactions actives. La déconnexion concerne tous les clients de cette session physique ; elle ne valide ni ne rejoue SQL. Les résultats inconnus restent inconnus.';

  @override
  String get transferSettingsChanged => 'Paramètres modifiés ; revérifier';

  @override
  String get transferReviewReady =>
      'Vérification prête · contrôler cible, portée, correspondances et fichier';

  @override
  String get sourcePreviewNotice => 'Aperçu source · aucune ligne importée';

  @override
  String get transferRequiresReview => 'Vérifier d’abord ce transfert exact';

  @override
  String get transferSubmittedNotice =>
      'Envoyé · annuler ne défait pas les commits ni les fichiers publiés';

  @override
  String get sqlExportExecutionNote => 'Nouvelle exécution SQL vérifiée';

  @override
  String get retainedExportSnapshotNote =>
      'Instantané récupéré ; aucune exécution SQL';

  @override
  String get restorePartialCommitNote =>
      'La restauration peut valider partiellement. Annuler ne l’inverse pas.';

  @override
  String get sourcePreviewLimit => 'Aperçu source · jusqu’à 20 lignes';

  @override
  String get importBatchSafetyNote =>
      'Erreurs et annulation conservent les commits antérieurs. Empreintes et source immuable sont vérifiées avant l’envoi.';

  @override
  String get nullMarkerLiteralNote =>
      'Marqueur NULL sans guillemets ; entre guillemets, texte littéral';

  @override
  String immutableSourceHash(String hash) {
    return 'SHA-256 de la source immuable : $hash';
  }

  @override
  String sourceColumnLabel(String column) {
    return 'Colonne source $column';
  }

  @override
  String previewRowLabel(String row, String column, String value) {
    return 'Ligne d’aperçu $row, $column : $value';
  }

  @override
  String get transferCancellationNotice =>
      'Annulation demandée · attendre l’accusé';

  @override
  String transferProgress(String processed, String committed, String rejected) {
    return '$processed traitées · $committed validées · $rejected rejetées';
  }

  @override
  String get importAtomicPolicy => 'Toutes les lignes en une transaction';

  @override
  String get importBatchPolicy => 'Valider par lots ; arrêter sur erreur';

  @override
  String get importSkipPolicy =>
      'Ignorer les lignes invalides ; valider par lots';

  @override
  String closeWorkCounts(
    String operations,
    String documents,
    String saves,
    String edits,
    String jobs,
    String transactions,
    String unknown,
    String sessions,
  ) {
    return 'Accusés/connexions : $operations\nDocuments non enregistrés : $documents\nEnregistrements en cours : $saves\nModifications en attente : $edits\nTâches actives : $jobs\nTransactions à nettoyer : $transactions\nRésultats inconnus : $unknown\nSessions incertaines : $sessions';
  }

  @override
  String get closeDraftSaved =>
      'Les brouillons SQL seront enregistrés localement.';

  @override
  String get closeDraftLost =>
      'Récupération désactivée ; SQL et conceptions non enregistrés seront perdus.';

  @override
  String get closeDesignRecovery =>
      'Les conceptions utilisent une récupération privée bornée. Reconnectez et inspectez explicitement les métadonnées après réouverture.';

  @override
  String get closeCleanupReview =>
      'Fermer le dernier propriétaire demande l’annulation, annule les transactions confirmées et déconnecte. Les résultats inconnus le restent ; SQL n’est jamais validé ni rejoué.';

  @override
  String get closeSharedSession =>
      'Les autres clients gardent leur session physique partagée.';

  @override
  String get closeStagedRecovery =>
      'Les modifications exigent une récupération privée confirmée, une reconnexion explicite et une nouvelle vérification.';

  @override
  String get closeRecoveryLoss =>
      'Documents et disposition non enregistrés. Fermer peut perdre SQL et modifications ; fichiers et récupération existants sont conservés.';

  @override
  String get closeWaitNotice =>
      'Attendez les accusés et le nettoyage des connexions avant de fermer.';

  @override
  String get saveFailedNotice =>
      'Échec d’enregistrement SQL. Gardez le texte modifié ou abandonnez-le explicitement.';

  @override
  String get closeCleanupFailed =>
      'Échec du nettoyage du backend ; BusyData reste ouvert.';

  @override
  String get closeBackendUnverified =>
      'État du backend non vérifié ; des tâches peuvent rester en attente.';

  @override
  String historyRetainSqlReview(String days) {
    return 'SQL peut contenir des secrets. Garder le texte $days jours ?';
  }

  @override
  String get historyStopSqlReview =>
      'Arrêter de conserver SQL et le retirer du précédent historique ?';

  @override
  String get historyClearReview =>
      'Effacer tout l’historique ? Les tâches actives peuvent enregistrer leur résultat à la fin.';

  @override
  String get historyDeleteReview => 'Supprimer l’entrée sélectionnée ?';

  @override
  String get historyRetentionRange =>
      'La conservation doit être de 1–3650 jours';

  @override
  String get enableSqlHistory => 'Activer l’historique SQL';

  @override
  String get stopSqlHistory => 'Arrêter la conservation SQL';

  @override
  String get recoveryDiscardReview =>
      'Abandonner cette récupération ? Résolvez les résultats inconnus d’abord ; cela n’annule aucun commit.';

  @override
  String closeSqlSummary(String unsaved, String edits, String jobs) {
    return 'SQL non enregistré : $unsaved\nModifications : $edits\nTâches actives : $jobs';
  }

  @override
  String get recoveryStayOpen =>
      'Échec de récupération. BusyData reste ouvert ; le travail non enregistré est conservé.';

  @override
  String get commitUncertaintyNote =>
      'Une panne réseau peut laisser le résultat du commit inconnu. Ne réessayez jamais automatiquement.';

  @override
  String get closeObjectDesignDiscard =>
      'Les champs de conception non enregistrés seront abandonnés. Générez et enregistrez d’abord SQL pour conserver la conception.';

  @override
  String get savePrivateDrafts =>
      'Enregistrer les brouillons privés de récupération';

  @override
  String get noPrivateDrafts =>
      'Ne pas enregistrer de brouillons de récupération';

  @override
  String shortcutField(String command) {
    return 'Raccourci de $command';
  }

  @override
  String get shortcutInvalid =>
      'Utilisez un raccourci valide non attribué à une autre action. F6 et Maj+F6 sont réservés.';

  @override
  String get disableRecoveryReview =>
      'Supprimer la récupération locale SQL, conceptions et modifications ? Le travail non enregistré reste ouvert ; un plantage peut le perdre. Résolvez les résultats inconnus d’abord.';

  @override
  String get preferencesSaved => 'Paramètres enregistrés';

  @override
  String get sharingSessionReview =>
      'La requête partage session physique, transaction, objets temporaires et réglages avec les clients indiqués. Fermer un client conserve les autres.';

  @override
  String get recoveryReconcileFirst =>
      'Résolvez les modifications en cours ou inconnues avant de désactiver la récupération. Abandonnez les enregistrements uniquement après leur vérification explicite.';

  @override
  String get enterSearchText => 'Saisir le texte de recherche';

  @override
  String get noSearchMatches => 'Aucune correspondance';

  @override
  String searchMatchCount(String position, String total) {
    return 'Correspondance $position sur $total';
  }

  @override
  String get formatSqlChanged =>
      'SQL ou cible modifiée. SQL original conservé ; demander un nouvel aperçu de formatage.';

  @override
  String get formatSqlUnavailable =>
      'Formatage indisponible pour une syntaxe incomplète ou non prise en charge, ou une limite d’analyse. SQL original conservé.';

  @override
  String get stageChange => 'Préparer le changement';

  @override
  String pendingChangesCount(String count) {
    return '$count changements en attente ; base inchangée jusqu’à l’application examinée.';
  }

  @override
  String discardChangesCount(String count) {
    return 'Ignorer $count changements en attente ? Aucune opération de base n’est envoyée.';
  }

  @override
  String get recoveryNoExecution =>
      'La récupération ne connecte pas, n’exécute pas le SQL source, ne reprend pas les transactions et ne rejoue pas les changements. Les entrées inconnues ou validées ne sont pas réappliquées.';

  @override
  String get recoveredDesign =>
      'Conception récupérée. Connecter et examiner les métadonnées actuelles explicitement avant un nouvel examen. La restauration n’a récupéré ni SQL ni métadonnées.';

  @override
  String get retainedUnavailable =>
      'Données conservées indisponibles. SQL enregistré et récupération privée restent locaux.';

  @override
  String get activityFingerprintNote =>
      'L’empreinte de l’activité choisie est revalidée avant envoi. Les écritures peuvent avoir un résultat inconnu.';

  @override
  String replaceFileReview(String path) {
    return 'Remplacer le fichier examiné à $path ? Une destination modifiée exige un nouvel examen.';
  }

  @override
  String get diagramPngSaved =>
      'PNG du diagramme enregistré. Les notes longues affichent jusqu’à six lignes.';

  @override
  String get editTargetChanged =>
      'Cible d’édition modifiée. Rouvrir l’éditeur de ligne avant de préparer.';

  @override
  String affectedRowCount(String count) {
    return 'Lignes affectées : $count';
  }

  @override
  String get zoomIn => 'Agrandir';

  @override
  String get zoomOut => 'Réduire';

  @override
  String get resetView => 'Réinitialiser la vue';

  @override
  String get diagramKeys =>
      'Les flèches déplacent ; + et - changent le zoom ; Home réinitialise la vue.';

  @override
  String get explorerConnected => 'Explorateur connecté';

  @override
  String get explorerDisconnected => 'Explorateur déconnecté';

  @override
  String querySessionCount(String count) {
    return 'Sessions de requête $count';
  }

  @override
  String get metadataColumn => 'Colonne';

  @override
  String get metadataPosition => 'Position';

  @override
  String get metadataUnique => 'Unique';

  @override
  String get metadataJdbcType => 'Type JDBC';

  @override
  String get metadataAutoIncrement => 'Incrément automatique';

  @override
  String get metadataReferencedColumn => 'Colonne référencée';

  @override
  String get metadataComment => 'Commentaire';

  @override
  String get metadataType => 'Type';

  @override
  String get metadataEvent => 'Événement';

  @override
  String get metadataSpecificName => 'Identifiant natif spécifique';

  @override
  String get metadataOptions => 'Options';

  @override
  String get metadataInheritance => 'Héritage';

  @override
  String get metadataDefinitionCaptured => 'Définition native capturée';

  @override
  String get metadataDefinitionUnavailable =>
      'Définition indisponible dans les métadonnées capturées';

  @override
  String get metadataDefinitionUnsupported =>
      'L’objet capturé ne possède pas de définition native prise en charge';

  @override
  String get connections => 'Connexions';

  @override
  String get noConnections => 'Aucune connexion';

  @override
  String get startTitle => 'Se connecter à une base de données';

  @override
  String get startDescription =>
      'Connectez-vous à PostgreSQL, MySQL ou MariaDB pour parcourir les objets, gérer les données et exécuter des requêtes.';

  @override
  String get savedStartTitle => 'Sélectionner une connexion';

  @override
  String get savedStartDescription =>
      'Connectez-vous à une connexion enregistrée dans l’explorateur pour parcourir les objets et exécuter des requêtes.';

  @override
  String get noConnection => 'Aucune connexion';

  @override
  String queryTitle(int number) {
    return 'Requête $number';
  }

  @override
  String get sessionMenu => 'Session';

  @override
  String get noFilterMatches =>
      'Aucune connexion ni aucun objet chargé correspondant';

  @override
  String get activityState => 'État';

  @override
  String get activityWait => 'Attente';

  @override
  String get generalSettings => 'Général';

  @override
  String get optionsSettings => 'Options';

  @override
  String get host => 'Hôte';

  @override
  String get databaseSystem => 'Système de base de données';

  @override
  String get passwordStorage => 'Stockage du mot de passe';

  @override
  String get environmentLabel => 'Environnement';

  @override
  String get readOnlySettings => 'Politique de lecture seule';

  @override
  String get tlsPolicy => 'Politique TLS';

  @override
  String get sshConnection => 'Connexion SSH';

  @override
  String get sshAuthentication => 'Authentification SSH';

  @override
  String get connectionTestAction => 'Tester la connexion';

  @override
  String get details => 'Détails';

  @override
  String get copyDetails => 'Copier les détails';

  @override
  String get retry => 'Réessayer';

  @override
  String get filterCellValue => 'Filtrer par cette valeur';

  @override
  String get connectsWhenRun => 'Connexion à l’exécution';

  @override
  String get connectionSaving => 'Enregistrer…';

  @override
  String get connectionConnecting => 'Connecter…';

  @override
  String get connectionCancelling => 'Annuler…';

  @override
  String get connectionSettingsChanged =>
      'Paramètres modifiés. Testez à nouveau cette version.';

  @override
  String get connectionTestChanged =>
      'Paramètres modifiés. Testez à nouveau cette version.';

  @override
  String get connectionRequired => 'Obligatoire';

  @override
  String get connectionCorrectFields => 'Vérifiez les paramètres indiqués.';

  @override
  String get connectionHostname => 'Hôte · Vérifiez les paramètres indiqués.';

  @override
  String get connectionSshHostname =>
      'SSH · Hôte · Vérifiez les paramètres indiqués.';

  @override
  String get connectionMaxLength => 'Nom ≤ 256';

  @override
  String get connectionTlsHelp =>
      'TLS · Hôte · SSH/SSL. Vérifiez les paramètres indiqués.';

  @override
  String get connectionTlsReview =>
      'TLS · Hôte · SSH/SSL. Vérifiez les paramètres indiqués.';

  @override
  String get connectionStorageUnavailable =>
      'Stockage du mot de passe: Indisponible. Mot de passe · Jamais.';

  @override
  String get connectionHostReviewed =>
      'Hôte · La confiance s’applique uniquement à ce profil et à cette destination exacte.';

  @override
  String get connectionSshReviewing => 'SSH · Vérifier la clé d’hôte SSH…';

  @override
  String get connectionFailureAuthentication =>
      'Échec · Authentification · Général. Vérifiez les paramètres indiqués.';

  @override
  String get connectionFailureTls =>
      'Échec · TLS · SSH/SSL. Vérifiez les paramètres indiqués.';

  @override
  String get connectionFailureSshKey =>
      'Échec · Vérifier la clé d’hôte SSH. Vérifiez les paramètres indiqués.';

  @override
  String get connectionFailureEndpoint =>
      'Échec · Hôte · Port. Vérifiez les paramètres indiqués.';

  @override
  String get connectionFailureCancelled => 'Annulé';

  @override
  String get connectionFailureSettings =>
      'Échec · Général. Vérifiez les paramètres indiqués.';

  @override
  String get connectionFailureAccess =>
      'Échec · Droits de table / vue. Vérifiez les paramètres indiqués.';

  @override
  String get connectionFailureUnavailable =>
      'Échec · Hôte · TLS · SSH. Vérifiez les paramètres indiqués.';

  @override
  String get connectionFailureTimeout =>
      'Échec · Délai de connexion · 1–120 secondes. Vérifiez les paramètres indiqués.';

  @override
  String get connectionFailureUnknown =>
      'Échec · Général · TLS · SSH. Vérifiez les paramètres indiqués.';

  @override
  String connectionNumber(int min, int max) {
    return 'Saisissez un entier de $min à $max';
  }

  @override
  String connectionSavedFailure(String name) {
    return 'Connexion enregistrée : $name. La tentative de connexion a échoué. ';
  }

  @override
  String get backendBusy =>
      'Le serveur est occupé. Attendez la requête en cours, puis réessayez.';

  @override
  String rpcRequestUnconfirmed(String code) {
    return 'La requête n’a pas été confirmée (RPC $code).';
  }

  @override
  String get operationUnconfirmed => 'L’opération n’a pas pu être terminée.';

  @override
  String get connectionFailureTlsMaterial =>
      'Le matériel TLS est indisponible ou invalide. Vérifiez les sources de confiance et la clé client dans SSH/SSL.';

  @override
  String get managerTitle => 'Sources de données et pilotes';

  @override
  String get sourceListTitle => 'Sources de données';

  @override
  String get driverLabel => 'Pilote';

  @override
  String get connectionTypeLabel => 'Type de connexion';

  @override
  String get defaultTcp => 'Par défaut (TCP)';

  @override
  String get authenticationLabel => 'Authentification';

  @override
  String get userPasswordAuth => 'Utilisateur et mot de passe';

  @override
  String get neverStorage => 'Jamais';

  @override
  String get initialDatabaseLabel => 'Base de données initiale';

  @override
  String get useSshTunnel => 'Utiliser un tunnel SSH';

  @override
  String get sshConfigurationLabel => 'Configuration SSH';

  @override
  String get createSshConfig => '<créer une configuration>';

  @override
  String get copySshSettings => 'Copier les paramètres SSH';

  @override
  String get localPortLabel => 'Port local';

  @override
  String get dynamicPortLabel => '<Dynamique>';

  @override
  String get useSsl => 'Utiliser SSL';

  @override
  String get useTruststore => 'Utiliser un magasin de confiance';

  @override
  String get clientKeyPasswordLabel => 'Mot de passe de la clé client';

  @override
  String get modeLabel => 'Mode';

  @override
  String get requireTls => 'Exiger';

  @override
  String get verifyCa => 'Vérifier la CA';

  @override
  String get fullVerification => 'Vérification complète';

  @override
  String get connectionSection => 'Connexion';

  @override
  String get configurationApplied => 'Configuration appliquée';

  @override
  String get noOtherSshConfig =>
      'Aucune autre source ne possède de configuration SSH.';

  @override
  String get generatedUrlHelp => 'Adresse JDBC générée, en lecture seule.';

  @override
  String get tlsDriverDefaultHelp =>
      'SSL n’est pas configuré ; le pilote fourni utilise sa valeur par défaut.';

  @override
  String get tlsClientKeyHelp =>
      'Clés PEM : PKCS#8 ou OpenSSL ; chiffrées ou non chiffrées.';

  @override
  String get legacyMariaTrustHelp =>
      'La vérification existante du pilote est conservée. Sélectionnez les sources de confiance pour définir les racines.';

  @override
  String get metadataStartValue => 'Valeur initiale';

  @override
  String get metadataMinimumValue => 'Valeur minimale';

  @override
  String get metadataMaximumValue => 'Valeur maximale';

  @override
  String get metadataIncrement => 'Incrément';

  @override
  String get metadataCycle => 'Cyclique';

  @override
  String get metadataCacheSize => 'Taille du cache';

  @override
  String get metadataLastValue => 'Dernière valeur';

  @override
  String get sequences => 'Séquences';

  @override
  String get namespaceSelection => 'Sélectionner les espaces de noms';

  @override
  String get namespaceSelectionNotice =>
      'La sélection contrôle l’introspection. Les consoles conservent leur contexte d’exécution.';

  @override
  String get allNamespaces => 'Tous les espaces de noms';

  @override
  String get defaultNamespace => 'Par défaut';

  @override
  String get namespacePattern => 'Motif de nom (expression régulière)';

  @override
  String namespaceCount(int selected, int known) {
    return '$selected sur $known';
  }

  @override
  String get previousPage => 'Page précédente';

  @override
  String get patternRejected =>
      'Le motif est invalide ou dépasse la limite de travail. La sélection précédente est conservée.';

  @override
  String get namespaceNotSelected =>
      'Espace de noms non sélectionné pour l’introspection';

  @override
  String get newMenu => 'Nouveau';

  @override
  String get queryConsoles => 'Consoles de requêtes';

  @override
  String get viewOptions => 'Options d’affichage';

  @override
  String get quickDocumentation => 'Documentation rapide';

  @override
  String get showEmptyGroups => 'Afficher les groupes vides';

  @override
  String get speedSearch => 'Recherche rapide';

  @override
  String get speedSearchScope => 'Uniquement les nœuds développés et chargés.';

  @override
  String get newSourceFolder => 'Nouveau dossier de sources';

  @override
  String get renameSourceFolder => 'Renommer le dossier';

  @override
  String get moveToFolder => 'Déplacer vers un dossier';

  @override
  String get moveUp => 'Monter';

  @override
  String get moveDown => 'Descendre';

  @override
  String get folderMustBeEmpty =>
      'Déplacez les sources et dossiers contenus avant de supprimer ce dossier.';

  @override
  String get newVirtualView => 'Nouvelle vue virtuelle';

  @override
  String get editVirtualDefinition => 'Modifier la définition locale';

  @override
  String get unboundVirtualView => 'Vues virtuelles non liées';

  @override
  String get localVirtualViewNotice =>
      'Définition SQL locale. Enregistrer ne lance pas de SQL et ne crée pas de vue sur le serveur. Exécuter utilise la vérification SQL habituelle et une console indépendante.';

  @override
  String get rebindVirtualView => 'Lier la définition locale ici';

  @override
  String get sourceFolderName => 'Nom du dossier';

  @override
  String get sourceFolderPathNotice =>
      'Utilisez / pour créer des dossiers imbriqués.';

  @override
  String get topLevel => 'Premier niveau';

  @override
  String get virtualViewName => 'Nom de la vue virtuelle';

  @override
  String get virtualViewSql => 'Définition SQL de la vue virtuelle';

  @override
  String get virtualViews => 'Vues virtuelles';

  @override
  String get revealInExplorer => 'Afficher dans l’explorateur de bases';

  @override
  String get objectNotFound =>
      'Objet introuvable dans cet espace de noms. Actualisez les métadonnées ou vérifiez les droits.';

  @override
  String get objectHiddenByFilter =>
      'Cet objet est masqué par le filtre actuel.';

  @override
  String get revealFilterNotice =>
      'La recherche réduit cette page ; le total de la catégorie est omis.';

  @override
  String get clearObjectFilter => 'Effacer la recherche d’objet';

  @override
  String get compareStructure => 'Comparer les structures';

  @override
  String get selectTwoCompatibleObjects =>
      'Sélectionnez deux tables compatibles avec Ctrl-clic.';

  @override
  String get scopedComparisonRestriction =>
      'La comparaison exige des tables ordinaires avec les mêmes nom natif, schéma et moteur. Les autres types et correspondances de renommage sont indisponibles.';

  @override
  String get groupNamespaces => 'Grouper les bases et schémas';

  @override
  String get groupSchemaObjects => 'Grouper les objets du schéma';

  @override
  String get groupTableElements => 'Grouper les éléments de table';

  @override
  String get sortAlphabetically => 'Trier par ordre alphabétique';

  @override
  String get showVirtualObjects => 'Afficher les objets virtuels';

  @override
  String get showObjectComments => 'Afficher les commentaires des objets';

  @override
  String get objectTypeFilter => 'Filtre de type d’objet';

  @override
  String get partitionedTable => 'Table partitionnée';

  @override
  String get foreignTable => 'Table étrangère';

  @override
  String get materializedView => 'Vue matérialisée';

  @override
  String get functionObject => 'Fonction';

  @override
  String get procedureObject => 'Procédure';

  @override
  String get sqlSymbolUnavailable =>
      'Aucun objet persistant résolu de façon sûre au curseur. Connectez cette console et utilisez une référence de table ou de vue hors des littéraux et commentaires.';

  @override
  String get sqlSymbolAmbiguous =>
      'Référence SQL ambiguë. Qualifiez son espace de noms ou choisissez un objet exact.';

  @override
  String get deactivateSource => 'Désactiver la source';

  @override
  String get functions => 'Fonctions';

  @override
  String get procedures => 'Procédures';

  @override
  String get separateProceduresFunctions =>
      'Séparer les procédures et les fonctions';

  @override
  String get renameVirtualView => 'Renommer la vue virtuelle';

  @override
  String get metadataPersistentScope =>
      'Objets persistants uniquement ; les objets temporaires ou propres à la session restent dans la navigation de la console.';

  @override
  String get metadataSessionScope =>
      'Objets persistants uniquement ; actualisez les objets propres à la console après exécution.';

  @override
  String get metadataLimitScope =>
      'Limite des métadonnées atteinte. Réduisez la portée des objets.';

  @override
  String get completeColumnMetadataRequired =>
      'Les métadonnées complètes des colonnes sont requises avant l’importation ou la préparation des modifications.';

  @override
  String resizeColumn(String name) {
    return 'Redimensionner la colonne $name';
  }

  @override
  String get keyboardShortcutsHeading => 'Raccourcis clavier';

  @override
  String sqlEditorLabel(String title) {
    return 'Éditeur SQL $title';
  }

  @override
  String get editorResultsDivider => 'Séparateur entre éditeur et résultats';

  @override
  String editorExtent(String percent) {
    return 'Éditeur à $percent pour cent';
  }

  @override
  String get largerEditor => 'Agrandir l’éditeur';

  @override
  String get smallerEditor => 'Réduire l’éditeur';

  @override
  String get explorerWidthDivider => 'Séparateur de largeur de l’explorateur';

  @override
  String get widerExplorer => 'Élargir l’explorateur';

  @override
  String get narrowerExplorer => 'Rétrécir l’explorateur';

  @override
  String explorerExtent(String width) {
    return '$width pixels de large';
  }

  @override
  String planTextPage(String start, String end, String total) {
    return '$start–$end sur $total unités UTF-16';
  }

  @override
  String get dropDesignedColumn => 'Supprimer la colonne';

  @override
  String get liveCatalogLabel => 'Catalogue actuel';

  @override
  String get liveSchemaLabel => 'Schéma actuel';

  @override
  String get searchPathLabel => 'Chemin de recherche';

  @override
  String get physicalSessionLabel => 'Session physique';

  @override
  String queryTimeoutDetail(String seconds, String rows) {
    return 'Délai : $seconds s · Limite de lignes : $rows';
  }

  @override
  String get saveFailedCloseTitle =>
      'Échec de l’enregistrement SQL · Fermer BusyData';

  @override
  String get createSection => 'Créer';

  @override
  String get newConnectionDescription =>
      'Configurer une connexion à une base de données';

  @override
  String get newQueryDescription => 'Écrire du SQL dans une nouvelle requête';

  @override
  String get openSqlDescription => 'Ouvrir un document SQL existant';

  @override
  String get searchNoResults => 'Aucune action correspondante';

  @override
  String get actionsCategory => 'Actions';

  @override
  String get privateRecoveryCategory => 'Récupération privée';

  @override
  String get shortcutRecordHelp =>
      'Appuyez sur un raccourci. Échap annule. F6 et Maj+F6 sont réservés à la navigation entre panneaux.';

  @override
  String get rowLimitInvalid =>
      'Saisissez une limite de 1 à 1 000 000 de lignes.';

  @override
  String get errorPolicy => 'En cas d’erreur d’exécution';

  @override
  String get tlsEncrypted => 'chiffré';

  @override
  String get tlsUnencrypted => 'non chiffré';

  @override
  String get tlsUnobserved => 'non observé';

  @override
  String get encryptionVerificationNote =>
      'Le chiffrement ne garantit pas la vérification du certificat ni du nom d’hôte.';

  @override
  String get uniqueDesignedColumnName =>
      'Utilisez un nom de colonne unique ; les nouvelles tables acceptent jusqu’à 128 colonnes';

  @override
  String activityBlockerUnavailable(String id) {
    return 'Le bloqueur $id n’est plus visible ; actualisez et vérifiez les autorisations de la base de données';
  }

  @override
  String get sshChangedKeyReview =>
      'Vérifiez indépendamment la clé modifiée avant de remplacer son association à ce profil.';

  @override
  String get sshProfileTrustBinding =>
      'La confiance s’applique uniquement à ce profil et à cette destination exacte.';

  @override
  String get databaseTlsEvidence => 'TLS · Système de base de données';

  @override
  String get sshAlgorithmLabel => 'SSH · Type';

  @override
  String get sshFingerprintLabel => 'SHA-256';

  @override
  String get sshPreviousFingerprintLabel => 'Précédent · SHA-256';

  @override
  String get sshReviewedLabel => 'Vérifier la clé d’hôte SSH';

  @override
  String get shortcutRecordAction => 'Enregistrer un raccourci';

  @override
  String get fileFormatLabel => 'Format du fichier';

  @override
  String get encodingLabel => 'Encodage';

  @override
  String get importPolicyLabel => 'Politique d’importation';

  @override
  String get mainMenu => 'Menu principal';

  @override
  String get activityReplyTooLarge =>
      'La réponse des activités dépasse la limite de l’inspecteur.';

  @override
  String get activityListLimited =>
      'Liste limitée ; examinez une cible plus précise avec du SQL explicite.';

  @override
  String get activitySelectionChanged =>
      'L’activité sélectionnée est terminée ou a changé. Sélectionnez son identité actuelle avant de vérifier une action.';

  @override
  String connectionSavedDraftChanged(String name) {
    return 'Les champs de connexion ont changé pendant l’enregistrement ; la configuration a été enregistrée : $name. Vérifiez les valeurs actuelles avant de vous connecter.';
  }

  @override
  String get sshReviewTargetChanged =>
      'La cible de la vérification SSH a changé ; vérifiez-la à nouveau';

  @override
  String get appearance => 'Apparence';

  @override
  String get theme => 'Thème';

  @override
  String get systemTheme => 'Système';

  @override
  String get lightTheme => 'Clair';

  @override
  String get darkTheme => 'Sombre';

  @override
  String get appLanguage => 'Langue';

  @override
  String get systemLanguage => 'Système';

  @override
  String get cut => 'Couper';

  @override
  String get paste => 'Coller';

  @override
  String get selectAll => 'Tout sélectionner';

  @override
  String get noSelection => 'Aucun texte disponible';

  @override
  String get clipboardEmpty => 'Le presse-papiers ne contient pas de texte';

  @override
  String get settingsDraftNotice =>
      'Les modifications d’exécution et de récupération privée ne sont pas enregistrées.';

  @override
  String get documentsMenu => 'Documents';

  @override
  String get currentSql => 'SQL actuel';

  @override
  String get searchActionsHint => 'Rechercher des actions…';

  @override
  String get searchCurrentSqlHint => 'Search current SQL…';

  @override
  String get searchObjectsHint => 'Search database objects…';

  @override
  String get searchHistoryHint => 'Search query history…';

  @override
  String get metadataAttributes => 'Attributs';

  @override
  String get metadataSelectionUnavailable =>
      'Sélectionnez un élément pour examiner ses propriétés capturées. La sélection précédente est indisponible.';

  @override
  String get secureStorage => 'Stockage sécurisé du système';

  @override
  String get resultPresentation => 'View as';

  @override
  String get resultTable => 'Table';

  @override
  String get resultTranspose => 'Transpose';

  @override
  String get resultTree => 'Tree';

  @override
  String get resultText => 'Text';

  @override
  String get recordView => 'Record View';

  @override
  String get valueEditor => 'Value Editor';

  @override
  String get aggregateView => 'Aggregate View';

  @override
  String get relatedRows => 'Related Rows';

  @override
  String get cloneRow => 'Clone Row';

  @override
  String get displayFormat => 'Display format';

  @override
  String get canonicalValue => 'Canonical / raw';

  @override
  String get groupedNumber => 'Numeric grouping';

  @override
  String get jsonPretty => 'JSON formatted text';

  @override
  String get binaryHex => 'Binary hexadecimal';

  @override
  String get binaryBase64 => 'Binary Base64';

  @override
  String get uuidPresentation => 'UUID (16 bytes)';

  @override
  String get wrapText => 'Wrap text';

  @override
  String get selectedCellsScope => 'Selected cells only';

  @override
  String get retainedWindowScope => 'Current retained window only';

  @override
  String get serverDataOperations => 'Server-side table sorting and filtering';

  @override
  String get localDataOperations =>
      'Local sorting and filtering of retained data';

  @override
  String get partialRetainedScope =>
      'Partial retained result; this view does not represent the complete server table.';

  @override
  String get valueComplete => 'Complete retained value';

  @override
  String get valueTruncated =>
      'Truncated preview; the complete value is retained.';

  @override
  String get loadValueChunk => 'Load next 64 KiB';

  @override
  String get resetValueChunks => 'Reset value preview';

  @override
  String get structuredParseError =>
      'Structured interpretation is unavailable; exact raw content remains accessible.';

  @override
  String get structuredValueLimit =>
      'Structured display is limited to 256 KiB, 4,096 nodes and 32 levels.';

  @override
  String valueChunkRange(String start, String end, String total) {
    return 'Bytes $start–$end of $total';
  }

  @override
  String get presentationScopeLimit =>
      'This presentation exceeds its bounded scope. Select fewer cells or use Export.';

  @override
  String get transposeSelectionLimit =>
      'Transpose shows at most 32 selected rows. Narrow the selection to inspect another range.';

  @override
  String get jsonTree => 'JSON tree';

  @override
  String get xmlInterpretation => 'XML interpretation';

  @override
  String get imagePreview => 'Image preview';

  @override
  String get imagePreviewUnavailable =>
      'Image preview requires recognized image bytes within the 1 MiB / 4 megapixel limit.';

  @override
  String get valueDraftLimit =>
      'Value drafts exceed the shared 1 MiB text / 2 MiB complete-value limit. Stage or discard another draft first.';

  @override
  String get valueDraftPreserved =>
      'Value draft preserved; stored value is unchanged.';

  @override
  String get setDefault => 'Set DEFAULT';

  @override
  String get assignmentUnset => 'Unchanged / unset';

  @override
  String get assignmentValue => 'Exact value';

  @override
  String get assignmentNull => 'SQL NULL';

  @override
  String get assignmentDefault => 'Server DEFAULT';

  @override
  String get originalValue => 'Original value';

  @override
  String get stagedValue => 'Staged value';

  @override
  String get noRelatedRows =>
      'No available relationships for this retained row.';

  @override
  String get aggregateSelectedCount => 'Selected count';

  @override
  String get aggregateNonNull => 'Non-NULL count';

  @override
  String get aggregateNull => 'NULL count';

  @override
  String get aggregateDistinct => 'Distinct count';

  @override
  String get aggregateSum => 'Sum';

  @override
  String get aggregateAverage => 'Average';

  @override
  String get aggregateMinimum => 'Minimum';

  @override
  String get aggregateMaximum => 'Maximum';

  @override
  String get aggregateStoredValues =>
      'Aggregates use original retained values; staged edits are excluded.';

  @override
  String get relatedRowsUnavailable =>
      'Related-row navigation requires complete metadata and verified retained provenance.';

  @override
  String get stagedInsertReview =>
      'Clone staged as an insert. Review and edit its assignments before Apply.';

  @override
  String get rawValue => 'Raw value';

  @override
  String get previousRecord => 'Previous record';

  @override
  String get nextRecord => 'Next record';

  @override
  String get binaryInputError =>
      'Enter complete hexadecimal bytes or valid Base64 for the selected binary mode.';

  @override
  String get valueChunkEncoding =>
      'This byte page begins or ends inside a UTF-8 character. Use hexadecimal or export the complete value.';

  @override
  String get copyDisplayedText => 'Copy displayed text';

  @override
  String get requiredColumn => 'NOT NULL';

  @override
  String get editStagedInserts => 'Edit staged inserts';

  @override
  String get metadataSettings => 'Metadata and introspection';

  @override
  String get metadataIncludeCatalogs =>
      'Included databases (one exact name per line; empty uses current database)';

  @override
  String get metadataExcludeCatalogs => 'Excluded databases';

  @override
  String get metadataIncludeSchemas =>
      'Included schemas (empty uses current resolution path)';

  @override
  String get metadataExcludeSchemas => 'Excluded schemas';

  @override
  String get metadataIncludePatterns => 'Included object patterns';

  @override
  String get metadataExcludePatterns => 'Excluded object patterns';

  @override
  String get metadataSystemObjects => 'Include system objects';

  @override
  String get metadataDefaultLevel => 'Default introspection level';

  @override
  String get metadataLevelNames => 'Names and identities';

  @override
  String get metadataLevelStructure => 'Structure';

  @override
  String get metadataLevelSource => 'Structure and source';

  @override
  String get metadataFullRefresh => 'Full refresh';

  @override
  String get metadataIncrementalRefresh => 'Incremental refresh';

  @override
  String get metadataScopeLevels =>
      'Scope levels: catalog / schema / level, one per line';

  @override
  String get metadataCacheState => 'Cache state';

  @override
  String get metadataConfigurationChanged =>
      'Metadata configuration changed; reopen to review current settings';

  @override
  String get metadataAddScope => 'Add scope level';

  @override
  String get metadataAddName => 'Add exact name';

  @override
  String get metadataObjectKinds => 'Object kinds';

  @override
  String get metadataLastRefresh => 'Last successful refresh';

  @override
  String get metadataPatternsNote =>
      'Patterns use * for any characters and ? for one character. Names remain exact database identifiers.';

  @override
  String get sqlLanguage => 'SQL language';

  @override
  String get sqlDialect => 'SQL dialect';

  @override
  String get sqlPostgresql => 'PostgreSQL';

  @override
  String get sqlMysql => 'MySQL';

  @override
  String get sqlMariadb => 'MariaDB';

  @override
  String get sqlPreferenceScope => 'Settings scope';

  @override
  String get sqlDialectDefaults => 'Dialect defaults';

  @override
  String get sqlDialectDefaultsDescription =>
      'Applies to SQL documents using this dialect unless their connection has an override.';

  @override
  String get sqlProfileOverrideDescription =>
      'Applies only to SQL documents owned by the selected connection.';

  @override
  String get sqlUseDialectDefaults =>
      'Use dialect defaults for this connection';

  @override
  String get sqlFormatting => 'SQL formatting';

  @override
  String get sqlKeywordCase => 'Keyword case';

  @override
  String get sqlPreserveCase => 'Preserve case';

  @override
  String get sqlUpperCase => 'Uppercase';

  @override
  String get sqlLowerCase => 'Lowercase';

  @override
  String get sqlIndentationWidth => 'Indentation width';

  @override
  String get sqlContinuationIndent => 'Continuation indentation';

  @override
  String get sqlClauseBreaks => 'Start clauses on new lines';

  @override
  String get sqlJoinLayout => 'JOIN layout';

  @override
  String get sqlNewLine => 'New line';

  @override
  String get sqlSameLine => 'Same line';

  @override
  String get sqlCommaPlacement => 'Comma placement';

  @override
  String get sqlLeading => 'Leading';

  @override
  String get sqlTrailing => 'Trailing';

  @override
  String get sqlLogicalPlacement => 'Logical operator placement';

  @override
  String get sqlWrapLists => 'Wrap field and assignment lists';

  @override
  String get sqlWrapArguments => 'Wrap function arguments';

  @override
  String get sqlIndentSubqueries => 'Indent subqueries';

  @override
  String get sqlCteBreaks => 'Separate common table expressions';

  @override
  String get sqlParenthesisSpacing => 'Space inside parentheses';

  @override
  String get sqlOperatorSpacing => 'Space around operators';

  @override
  String get sqlAlignment => 'Align wrapped assignments';

  @override
  String get sqlMaximumLine => 'Maximum line length';

  @override
  String get sqlPreserveBlankLines => 'Preserve intentional blank lines';

  @override
  String get sqlInspections => 'SQL inspections';

  @override
  String get sqlInspectionDisabled => 'Disabled';

  @override
  String get sqlSeverityError => 'Error';

  @override
  String get sqlSeverityWarning => 'Warning';

  @override
  String get sqlSeverityInformation => 'Information';

  @override
  String get sqlSeverityHint => 'Hint';

  @override
  String get sqlInspectionUpdateWhere => 'UPDATE without WHERE';

  @override
  String get sqlInspectionDeleteWhere => 'DELETE without WHERE';

  @override
  String get sqlInspectionRelation => 'Unresolved relation';

  @override
  String get sqlInspectionColumn => 'Unresolved column';

  @override
  String get sqlInspectionAmbiguous => 'Ambiguous column';

  @override
  String get sqlInspectionDerived => 'Invalid derived-table column';

  @override
  String get sqlInspectionDuplicateAlias => 'Duplicate relation alias';

  @override
  String get sqlInspectionDuplicateCte => 'Duplicate common table expression';

  @override
  String get sqlInspectionDuplicateInsert => 'Duplicate INSERT column';

  @override
  String get sqlInspectionInsertTarget => 'Unknown INSERT target column';

  @override
  String get sqlInspectionUpdateTarget => 'Unknown UPDATE target column';

  @override
  String get sqlInspectionArguments => 'Invalid routine argument count';

  @override
  String get sqlInspectionOverload => 'No matching routine overload';

  @override
  String get sqlInspectionAggregate => 'Invalid aggregate or window expression';

  @override
  String get sqlInspectionComparison => 'Incompatible comparison types';

  @override
  String get sqlInspectionAssignment => 'Incompatible assignment type';

  @override
  String get parameterInformation => 'Parameter information';

  @override
  String activeArgument(int index) {
    return 'Active argument: $index';
  }

  @override
  String get numericScale2 => 'Numeric grouping · 2 decimal places';

  @override
  String get numericScale4 => 'Numeric grouping · 4 decimal places';

  @override
  String get temporalDate => 'Temporal date · yyyy-MM-dd';

  @override
  String get temporalTime => 'Temporal time · ISO';

  @override
  String get temporalUtc => 'Timestamp · UTC (requires explicit offset)';

  @override
  String get temporalLocal =>
      'Timestamp · local timezone (requires explicit offset)';

  @override
  String get formatCurrentStatement => 'Format current statement';

  @override
  String get completionLimited =>
      'More matches are available. Type a longer prefix.';

  @override
  String get parameterInformationLimited =>
      'More overloads exist; parameter information is limited.';

  @override
  String get sqlInspectionSyntax => 'SQL syntax error';

  @override
  String get sqlInspectionDialect =>
      'SQL construct is unavailable for this dialect';

  @override
  String get sqlInspectionUnavailable =>
      'SQL analysis is unavailable for this construct';

  @override
  String get sqlInspectionUnknownFunction => 'Unknown routine';

  @override
  String get sqlInspectionMetadata =>
      'SQL inspection is incomplete because metadata is unavailable';

  @override
  String get sqlDiagnosticsEmpty =>
      'No SQL inspections were reported for this document.';

  @override
  String sqlDiagnosticSpan(int start, int end, String source) {
    return 'UTF-16 $start–$end · $source';
  }

  @override
  String get sqlDiagnosticGo => 'Go to SQL span';

  @override
  String get sqlDiagnosticFix => 'Apply selected correction';

  @override
  String get sqlDiagnosticReplacement => 'Replacement text';

  @override
  String get sqlDiagnosticStale =>
      'SQL inspection context changed. Request inspections again.';

  @override
  String get sqlDiagnosticUnavailable =>
      'SQL inspections are unavailable for the current document.';

  @override
  String sqlDiagnosticCount(int count) {
    return '$count SQL inspections';
  }

  @override
  String get aggregateTextOrder =>
      'Text minimum/maximum use retained UTF-16 ordinal order; database collation is not applied.';

  @override
  String get aggregateMixedTypes =>
      'The selected values have incompatible types. Select values with a common type.';

  @override
  String get aggregateUnsupportedOrder =>
      'Ordering and numeric calculations are unavailable for this value type.';

  @override
  String get relatedKeyNotProjected =>
      'Select all relationship key columns in the source result before navigating.';

  @override
  String get relatedNullKey =>
      'A NULL relationship key has no matching related row.';

  @override
  String get relatedTargetUnavailable =>
      'The relationship target is outside this session’s supported database scope.';

  @override
  String get relatedValueLimited =>
      'The relationship key is truncated or exceeds navigation limits. Browse the target explicitly.';

  @override
  String get temporalCustomPattern => 'Temporal · custom pattern';

  @override
  String get temporalPattern => 'Temporal display pattern';

  @override
  String get temporalSourceZone => 'Original calendar fields';

  @override
  String get temporalZone => 'Display timezone';

  @override
  String get temporalPatternHelp =>
      'Use ICU calendar fields and up to six S digits for exact fractions. UTC/local conversion requires an explicit offset. Unsupported temporal values remain raw.';

  @override
  String get temporalPatternInvalid =>
      'Use a pattern of 1–128 characters with supported calendar fields, balanced quotes, and at most six S digits. Timezone letters z, Z and v are unsupported; choose the display timezone separately.';

  @override
  String get editCompleteValue => 'Edit complete value';

  @override
  String get completeValueEditLimit =>
      'Complete editing requires verified retained ownership, at most 1 MiB across original and new values, and 262,144 text units per value. Larger values remain available for export.';

  @override
  String get completeValueReady =>
      'Complete retained value loaded for editing; changes are staged only.';

  @override
  String get binaryNextEditPage => 'Next 16 KiB';

  @override
  String get binaryPreviousEditPage => 'Previous 16 KiB';

  @override
  String get arrayEditLimit =>
      'Array edits use exact native PostgreSQL text, at most 16 KiB of text, six dimensions and 1,024 scalar values. Java validates the captured element type.';

  @override
  String get valueChangedDuringStage =>
      'The earlier value was staged. Your newer draft is preserved; review it before staging again.';

  @override
  String textValuePage(String current, String total) {
    return 'Text page $current of $total';
  }

  @override
  String get textValuePagesScope =>
      'Only this text page is shown. Copy and export actions keep their stated scope.';

  @override
  String get textValueEditScope => 'Stage change includes every text page.';

  @override
  String get textValuePreviousPage => 'Previous text page';

  @override
  String get textValueNextPage => 'Next text page';

  @override
  String get valuePageEditLimit =>
      'That text is invalid or too large for this page. The previous text was kept.';

  @override
  String get valueAddEditPage => 'Add editing page';

  @override
  String get binaryAppendPageReason =>
      'Finish a valid, full last binary page before adding another page. Bytes are never padded.';

  @override
  String get valueEditorActions => 'Value actions';

  @override
  String get utf8Hex => 'UTF-8 hexadecimal';

  @override
  String get utf8Base64 => 'UTF-8 Base64';

  @override
  String get nativeTextNulUnavailable =>
      'Plain text editing is unavailable for values containing a NUL character. UTF-8 byte views and exact export remain available.';

  @override
  String get textClipboardNulUnavailable =>
      'This text contains a NUL character and cannot be copied exactly. Export the value or choose another extractor.';

  @override
  String sqlVisibleLine(int line, int total, int column) {
    return 'Visible SQL line $line of $total, column $column';
  }

  @override
  String get sqlLinePreviewTruncated => 'Line preview truncated';

  @override
  String sqlActiveCarets(int count) {
    return '$count carets active';
  }

  @override
  String get sqlCompositionActive => 'Input composition active';

  @override
  String get sqlEditorDocumentLimit =>
      'The edit exceeds the 8M UTF-16 document limit. Use a smaller document.';

  @override
  String get sqlEditorLineLimit =>
      'The edit exceeds the 100,000-line document limit. Use a smaller document.';

  @override
  String get sqlEditorCaretLimit =>
      'The editor supports at most 64 carets. Remove extra carets before adding more.';

  @override
  String get sqlEditorFinishComposition =>
      'Finish input composition before changing this selection.';

  @override
  String get sqlEditorClipboardLimit =>
      'The exact selection exceeds the 1 MiB clipboard limit. Save or export the text instead.';

  @override
  String get sqlEditorSelectionUnavailable =>
      'The editor cannot apply this selection. The original SQL is retained.';

  @override
  String get sqlEditorClipboardUnavailable =>
      'The clipboard is unavailable. Your SQL and selection have been kept.';

  @override
  String get metadataCacheWriteUnavailable =>
      'Le cache n’a pas pu être enregistré. Les métadonnées actuelles restent disponibles.';

  @override
  String get metadataCacheRebuiltVersion =>
      'Reconstruit pour la version actuelle';

  @override
  String get metadataCacheRebuiltCorrupt =>
      'Reconstruit après une erreur de cache';

  @override
  String get editSessionBusy =>
      'Cette session est occupée. Attendez la fin de son opération en cours, puis demandez une nouvelle évaluation de la possibilité de modifier les données.';

  @override
  String get editIdentityRequired =>
      'Avant de modifier les données, sélectionnez une clé primaire complète ou un identifiant unique non nullable.';

  @override
  String get editColumnsReadOnly =>
      'Toutes les colonnes projetées sont générées ou en lecture seule.';

  @override
  String get editResultNotReady =>
      'Attendez que ce résultat conservé soit complet avant de demander une nouvelle évaluation de la possibilité de modifier les données.';

  @override
  String get editProjectionUnsupported =>
      'La modification nécessite un SELECT direct sur une seule table de base, avec chaque colonne de base projetée une seule fois.';

  @override
  String get sqlInspectionDuplicateUsingColumn =>
      'Colonne JOIN USING en double';

  @override
  String get sqlInspectionUnresolvedUsingColumn =>
      'Colonne JOIN USING absente d’un opérande';

  @override
  String get sqlInspectionAmbiguousUsingColumn =>
      'Colonne commune de JOIN ambiguë';

  @override
  String get sqlInspectionOutputColumnCount =>
      'Nombre de colonnes de sortie déclarées incorrect';

  @override
  String get sqlInspectionAmbiguousOverload => 'Surcharge de routine ambiguë';

  @override
  String get sqlInspectionBooleanType =>
      'Type d’expression booléenne incorrect';

  @override
  String get sqlInspectionOperatorTypes =>
      'Types d’opérandes de l’opérateur incompatibles';

  @override
  String get sqlInspectionArrayTypes =>
      'Types d’éléments de tableau incompatibles';

  @override
  String get sqlInspectionCaseConditionType =>
      'Type de condition CASE incompatible';

  @override
  String get sqlInspectionCaseResultTypes =>
      'Types de résultats CASE incompatibles';

  @override
  String get sqlInspectionCoalesceTypes =>
      'Types d’arguments COALESCE incompatibles';

  @override
  String get sqlInspectionSetColumnCount =>
      'Nombre de colonnes de l’opération ensembliste incorrect';

  @override
  String get sqlInspectionSetTypes =>
      'Types de résultats de l’opération ensembliste incompatibles';

  @override
  String get sqlInspectionRecursiveCteType =>
      'Type de CTE récursive incompatible';
}
