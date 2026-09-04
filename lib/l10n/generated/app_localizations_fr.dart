// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get appTitle => 'NyxChat';

  @override
  String get notificationNewMessage => 'Nouveau message';

  @override
  String get notificationChannelMessages => 'Messages';

  @override
  String get notificationChannelMessagesDescription =>
      'Messages NyxChat entrants';

  @override
  String get meshChannelName => 'Réseau maillé NyxChat';

  @override
  String get meshChannelDescription =>
      'Maintient le réseau maillé décentralisé actif en arrière-plan.';

  @override
  String get meshNotificationInitial => 'Réseau maillé actif';

  @override
  String get meshNotificationActive => 'Routage maillé et DHT actifs';

  @override
  String get cancel => 'Annuler';

  @override
  String get save => 'Enregistrer';

  @override
  String get add => 'Ajouter';

  @override
  String get off => 'Désactivé';

  @override
  String get connect => 'Connecter';

  @override
  String get verified => 'Vérifié';

  @override
  String get messages => 'Messages';

  @override
  String get safetyNumberChangedTitle => 'Numéro de sécurité modifié';

  @override
  String safetyNumberChangedBody(String name, String id) {
    return '$name ($id) présente des clés d\'identité différentes de celles que vous avez épinglées.\n\nCela se produit lorsque la personne a réinstallé l\'application, ou si quelqu\'un tente de se faire passer pour elle. Vérifiez le nouveau numéro de sécurité en personne avant d\'accepter. La connexion reste bloquée jusqu\'à votre décision.';
  }

  @override
  String get keepBlocking => 'Continuer à bloquer';

  @override
  String get acceptNewKeys => 'Accepter les nouvelles clés';

  @override
  String get searchConversationsHint =>
      'Rechercher dans les conversations et les messages';

  @override
  String get emergencyBroadcastTitle => 'Diffusion d\'urgence';

  @override
  String get noConversationsYet => 'Aucune conversation pour l\'instant';

  @override
  String get tapPlusToFindPeople =>
      'Appuyez sur + pour trouver des personnes à proximité';

  @override
  String get noMatches => 'Aucun résultat';

  @override
  String get verifySafetyNumber => 'Vérifier le numéro de sécurité';

  @override
  String get mute => 'Mettre en sourdine';

  @override
  String get unmute => 'Retirer la sourdine';

  @override
  String get leaveGroup => 'Quitter le groupe';

  @override
  String get deleteConversation => 'Supprimer la conversation';

  @override
  String membersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count membres',
      one: '1 membre',
    );
    return '$_temp0';
  }

  @override
  String membersCountLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count membres (groupe quitté)',
      one: '1 membre (groupe quitté)',
    );
    return '$_temp0';
  }

  @override
  String get noMessagesYet => 'Aucun message pour l\'instant';

  @override
  String get filesNeedDirectConnection =>
      'Les fichiers nécessitent une connexion directe. Rapprochez-vous d\'abord à portée Wi-Fi.';

  @override
  String get reply => 'Répondre';

  @override
  String get copyText => 'Copier le texte';

  @override
  String get deleteForMe => 'Supprimer pour moi';

  @override
  String get disappearingMessages => 'Messages éphémères';

  @override
  String get disappear5Minutes => '5 minutes';

  @override
  String get disappear1Hour => '1 heure';

  @override
  String get disappear1Day => '1 jour';

  @override
  String get disappear1Week => '1 semaine';

  @override
  String get conversationDeleted => 'Conversation supprimée';

  @override
  String get statusConnected => 'Connecté';

  @override
  String get statusReachableViaMesh => 'Joignable via le réseau maillé';

  @override
  String get statusOfflineDeliverLater => 'Hors ligne · sera remis plus tard';

  @override
  String get endToEndEncrypted => 'Chiffré de bout en bout';

  @override
  String get groupEncryptionHint =>
      'Les messages utilisent des clés par expéditeur ; seuls les membres peuvent les lire.';

  @override
  String get directEncryptionHint =>
      'Les messages sont protégés par une session Double Ratchet.';

  @override
  String get noLongerMemberHint => 'Vous n\'êtes plus membre';

  @override
  String get messageHint => 'Message';

  @override
  String attachmentProgress(String percent, String size) {
    return '$percent% · $size';
  }

  @override
  String get sysMemberRemoved => 'Membre retiré';

  @override
  String get sysYouLeftGroup => 'Vous avez quitté le groupe';

  @override
  String sysGroupCreated(String name) {
    return 'Groupe « $name » créé';
  }

  @override
  String sysMembersAdded(String names) {
    return 'Membres ajoutés : $names';
  }

  @override
  String sysAddedToGroupBy(String name, String who) {
    return '$who vous a ajouté à « $name »';
  }

  @override
  String sysUpdatedMembers(String who) {
    return '$who a mis à jour les membres';
  }

  @override
  String get sysAMemberWasRemoved => 'Un membre a été retiré';

  @override
  String get sysYouWereRemoved => 'Vous avez été retiré du groupe';

  @override
  String sysLeftGroup(String who) {
    return '$who a quitté le groupe';
  }

  @override
  String sysRenamedGroup(String who, String name) {
    return '$who a renommé le groupe en « $name »';
  }

  @override
  String get sysGroupUpdated => 'Groupe mis à jour';

  @override
  String sysKeysRotated(String name) {
    return '$name a renouvelé ses clés (transition vérifiée)';
  }

  @override
  String get contactNotPinnedYet => 'Contact pas encore épinglé';

  @override
  String get safetyNumber => 'Numéro de sécurité';

  @override
  String get safetyNumberExplanation =>
      'Vous voyez tous les deux le même numéro si personne n\'intercepte la connexion. Comparez-le en personne, par téléphone ou via un autre canal de confiance.';

  @override
  String get markAsVerified => 'Marquer comme vérifié';

  @override
  String get messageAction => 'Envoyer un message';

  @override
  String get scanTheirQr => 'Scanner son code QR';

  @override
  String get verifiedKeysMatch =>
      'Vérifié : les clés correspondent à ce contact';

  @override
  String cardBelongsToOther(String name) {
    return 'Cette carte appartient à $name, épinglée séparément';
  }

  @override
  String get theirFingerprint => 'Son empreinte';

  @override
  String get yourFingerprint => 'Votre empreinte';

  @override
  String get showThemYourCard => 'Montrez-lui votre carte de contact';

  @override
  String get contactCardContainsOnlyPublicKeys =>
      'Contient uniquement vos clés publiques. La scanner ou la coller épingle votre identité sur son appareil.';

  @override
  String get details => 'Détails';

  @override
  String get nyxChatId => 'ID NyxChat';

  @override
  String get handshake => 'Négociation';

  @override
  String get handshakeValue => 'Hybride X25519 + ML-KEM-768, signé Ed25519';

  @override
  String get messagesValue => 'Double Ratchet, AES-256-GCM';

  @override
  String get firstSeen => 'Vu pour la première fois';

  @override
  String get keysChanged => 'Clés modifiées';

  @override
  String get idCopied => 'ID copié';

  @override
  String get giveGroupAName => 'Donnez un nom au groupe';

  @override
  String get selectAtLeastOneMember => 'Sélectionnez au moins un membre';

  @override
  String get newGroup => 'Nouveau groupe';

  @override
  String get create => 'Créer';

  @override
  String get groupNameHint => 'Nom du groupe';

  @override
  String get descriptionOptionalHint => 'Description (facultative)';

  @override
  String membersSelectedHeader(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sélectionnés',
      one: '1 sélectionné',
    );
    return 'Membres · $_temp0';
  }

  @override
  String get noContactsYet =>
      'Aucun contact pour l\'instant. Connectez-vous d\'abord à quelqu\'un pour que ses clés soient épinglées.';

  @override
  String get noRecentPosition =>
      'Aucune position récente. Saisissez une cellule geohash manuellement ou déplacez-vous à l\'extérieur.';

  @override
  String invalidCell(String error) {
    return 'Cellule invalide : $error';
  }

  @override
  String get noNeighboursKept =>
      'Aucun voisin pour le moment. Votre message est conservé et sera envoyé au premier appareil qui apparaît.';

  @override
  String get areaCellLabel => 'Cellule de zone (geohash)';

  @override
  String get findingYourArea => 'Recherche de votre zone...';

  @override
  String meshNeighboursCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count voisins maillés',
      one: '1 voisin maillé',
    );
    return '$_temp0';
  }

  @override
  String directLinksCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count liaisons directes',
      one: '1 liaison directe',
    );
    return '$_temp0';
  }

  @override
  String listeningInCell(
    String cell,
    String area,
    String neighbours,
    String links,
  ) {
    return 'À l\'écoute dans la cellule $cell ($area) · $neighbours, $links';
  }

  @override
  String get emergencyEmptyHint =>
      'Les messages de toute personne utilisant NyxChat dans cette cellule apparaissent ici. Votre position ne quitte jamais le téléphone, sauf si vous l\'incluez explicitement.';

  @override
  String get anonymous => 'Anonyme';

  @override
  String positionLabel(String coords) {
    return 'Position : $coords';
  }

  @override
  String get includeMyName => 'Inclure mon nom';

  @override
  String get includeMyPosition => 'Inclure ma position';

  @override
  String get emergencyComposerHint => 'Que se passe-t-il ? Où êtes-vous ?';

  @override
  String get joinCellFirst => 'Rejoignez d\'abord une cellule';

  @override
  String get send => 'Envoyer';

  @override
  String get presetNeedHelp => 'J\'ai besoin d\'aide';

  @override
  String get presetSafe => 'Je suis en sécurité';

  @override
  String get presetMedical => 'Urgence médicale';

  @override
  String get addMembers => 'Ajouter des membres';

  @override
  String get groupEncryptionExplanation =>
      'Les messages de groupe sont chiffrés avec des clés d\'expéditeur par membre, distribuées via des sessions Double Ratchet en paire. Les clés sont renouvelées dès que quelqu\'un quitte le groupe.';

  @override
  String memberYou(String name) {
    return '$name (vous)';
  }

  @override
  String get admin => 'Admin';

  @override
  String get renameGroup => 'Renommer le groupe';

  @override
  String get noOtherKnownContacts => 'Aucun autre contact connu';

  @override
  String get meshDiagnostics => 'Diagnostic du réseau maillé';

  @override
  String get statBleLinks => 'Liaisons BLE';

  @override
  String get statKnownRoutes => 'Routes connues';

  @override
  String get statStoredPackets => 'Paquets stockés';

  @override
  String get statDeliveredToMe => 'Remis à cet appareil';

  @override
  String get statReceived => 'Reçus';

  @override
  String get statForwarded => 'Relayés';

  @override
  String get statDuplicatesDropped => 'Doublons ignorés';

  @override
  String get statSeenIds => 'ID vus';

  @override
  String get linksHeader => 'Liaisons';

  @override
  String get noBluetoothLinksHint =>
      'Aucune liaison Bluetooth. Les appareils à portée se relient automatiquement tant que le balayage et la diffusion sont activés.';

  @override
  String get weDialled => 'initiée par nous';

  @override
  String get theyDialled => 'initiée par eux';

  @override
  String linkSubtitle(String role, int mtu, String address) {
    return '$role · MTU $mtu · $address';
  }

  @override
  String get routingTableHeader => 'Table de routage';

  @override
  String get routingTableHint =>
      'Les routes sont apprises à partir du chemin enregistré dans chaque paquet et des balises périodiques.';

  @override
  String routeToken(String prefix) {
    return 'jeton $prefix...';
  }

  @override
  String routeVia(String hop, int hops) {
    String _temp0 = intl.Intl.pluralLogic(
      hops,
      locale: localeName,
      other: '$hops sauts',
      one: '1 saut',
    );
    return 'via le relais $hop... · $_temp0';
  }

  @override
  String get howItWorksHeader => 'Fonctionnement';

  @override
  String meshExplanation(int copies, int hops) {
    return 'Les paquets sont adressés par des hachages SHA-256 et transportent une enveloppe chiffrée de bout en bout. Un relais stocke chaque paquet, le transmet au prochain saut connu ou en diffuse jusqu\'à $copies copies, puis le supprime après $hops sauts ou 24 heures. Les relais ne peuvent ni lire, ni modifier, ni réadresser ce qu\'ils transportent.';
  }

  @override
  String get enterDisplayName =>
      'Saisissez un nom d\'affichage (64 caractères max.)';

  @override
  String couldNotCreateIdentity(String error) {
    return 'Impossible de créer l\'identité : $error';
  }

  @override
  String get tagline => 'pair-à-pair · chiffré · fonctionne hors ligne';

  @override
  String get featureE2eSubtitle =>
      'Double Ratchet avec négociation hybride X25519 + ML-KEM-768';

  @override
  String get featureOfflineTitle => 'Fonctionne sans Internet';

  @override
  String get featureOfflineSubtitle =>
      'Réseau local Wi-Fi et maillage Bluetooth, remise différée (stockage puis transfert)';

  @override
  String get featureNoServersTitle => 'Ni serveurs, ni comptes';

  @override
  String get featureNoServersSubtitle =>
      'Votre identité est une paire de clés qui ne quitte jamais cet appareil';

  @override
  String get displayName => 'Nom d\'affichage';

  @override
  String get createIdentity => 'Créer l\'identité';

  @override
  String get keysGeneratedLocally =>
      'Génère les clés X25519, Ed25519 et ML-KEM-768 localement. Rien n\'est envoyé.';

  @override
  String get passwordRequired => 'Le mot de passe est requis';

  @override
  String get atLeast8Characters => 'Au moins 8 caractères';

  @override
  String get passwordsDoNotMatch => 'Les mots de passe ne correspondent pas';

  @override
  String get enterYourPassword => 'Saisissez votre mot de passe';

  @override
  String get allDataWiped => 'Toutes les données ont été effacées.';

  @override
  String get incorrectPassword => 'Mot de passe incorrect';

  @override
  String incorrectPasswordAttemptsLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tentatives restantes',
      one: '1 tentative restante',
    );
    return 'Mot de passe incorrect · $_temp0 avant effacement';
  }

  @override
  String get setAppLock => 'Définir le verrouillage';

  @override
  String get nyxChatIsLocked => 'NyxChat est verrouillé';

  @override
  String get unlockPrompt =>
      'Votre base de données est chiffrée. Saisissez votre mot de passe pour la déverrouiller.';

  @override
  String get passwordSetupExplanation =>
      'La clé de la base de données sera enveloppée avec une clé dérivée de ce mot de passe via Argon2id. Aucune récupération possible : un mot de passe oublié signifie la perte des données.';

  @override
  String get passwordHint => 'Mot de passe';

  @override
  String get confirmPasswordHint => 'Confirmer le mot de passe';

  @override
  String get enableLock => 'Activer le verrouillage';

  @override
  String get unlock => 'Déverrouiller';

  @override
  String get connectedAndAuthenticated => 'Connecté et authentifié';

  @override
  String get connectionFailed =>
      'Échec de la connexion (injoignable, refusée ou clés non concordantes)';

  @override
  String pinnedAndVerified(String name) {
    return '$name épinglé et vérifié';
  }

  @override
  String invalidContactCard(String error) {
    return 'Carte de contact invalide : $error';
  }

  @override
  String get findPeople => 'Trouver des personnes';

  @override
  String get visibleToEveryoneNearby => 'Visible par tous à proximité';

  @override
  String get visibleSubtitlePublic =>
      'Votre ID et votre nom sont diffusés pour que de nouvelles personnes puissent vous trouver.';

  @override
  String get visibleSubtitlePrivate =>
      'Balises privées : seuls les contacts épinglés peuvent vous reconnaître ; les autres ne voient que du bruit aléatoire.';

  @override
  String get scanContactQr => 'Scanner un QR de contact';

  @override
  String get emergency => 'Urgence';

  @override
  String get nearbyOnWifi => 'À proximité en Wi-Fi';

  @override
  String get nobodyDiscoveredYet =>
      'Personne n\'a encore été découvert. Les pairs sur le même Wi-Fi apparaissent ici automatiquement.';

  @override
  String get bluetoothMesh => 'Maillage Bluetooth';

  @override
  String get bleNotAvailable =>
      'Le Bluetooth LE n\'est pas disponible sur cet appareil.';

  @override
  String get bleScanningHint =>
      'Balayage en cours. Les autres appareils NyxChat à portée se relieront automatiquement.';

  @override
  String get bleScanningAdvertisingHint =>
      'Balayage et diffusion en cours. Les autres appareils NyxChat à portée se relieront automatiquement.';

  @override
  String get roleCentral => 'central';

  @override
  String get rolePeripheral => 'périphérique';

  @override
  String bleLinkedSubtitle(String role, int mtu) {
    return 'relié · $role · MTU $mtu';
  }

  @override
  String rssiDbm(int rssi) {
    return '$rssi dBm';
  }

  @override
  String get contacts => 'Contacts';

  @override
  String get contactsPinnedHint =>
      'Les clés de chaque pair auquel vous vous connectez sont épinglées ici.';

  @override
  String get addContactFromCard => 'Ajouter un contact depuis une carte';

  @override
  String get pasteContactCardHint =>
      'Collez le texte d\'une carte de contact (affichée en QR dans Vérifier). Cela épingle et vérifie ses clés.';

  @override
  String get importCard => 'Importer la carte';

  @override
  String get manualConnection => 'Connexion manuelle';

  @override
  String get ipAddressHint => 'Adresse IP';

  @override
  String get portHint => 'Port';

  @override
  String get connecting => 'Connexion...';

  @override
  String get globalDirectory => 'Annuaire global (DHT, expérimental)';

  @override
  String get dhtHint =>
      'Nécessite un nœud d\'amorçage joignable. Les annonces sont signées ; la négociation décide toujours de la confiance.';

  @override
  String dhtRunning(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count nœuds',
      one: '1 nœud',
    );
    return 'En cours · $_temp0';
  }

  @override
  String get stopped => 'Arrêté';

  @override
  String get stop => 'Arrêter';

  @override
  String get start => 'Démarrer';

  @override
  String get bootstrapHint => 'hôte:port d\'amorçage';

  @override
  String get bootstrapNodeAdded => 'Nœud d\'amorçage ajouté';

  @override
  String get lookupHint => 'NC-... à rechercher';

  @override
  String get find => 'Rechercher';

  @override
  String get notFound => 'Introuvable';

  @override
  String foundPeerAt(String name, String address) {
    return '$name trouvé à $address';
  }

  @override
  String get lanOn => 'LAN activé';

  @override
  String get lanOff => 'LAN désactivé';

  @override
  String get bleOn => 'BLE activé';

  @override
  String get bleScan => 'Balayage BLE';

  @override
  String get bleOff => 'BLE désactivé';

  @override
  String linksCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count liaisons',
      one: '1 liaison',
    );
    return '$_temp0';
  }

  @override
  String get stealth => 'furtif';

  @override
  String get visible => 'visible';

  @override
  String get reachable => 'joignable';

  @override
  String get offlineQueued => 'hors ligne, remise en attente';

  @override
  String get notANyxChatContactCard =>
      'Ce n\'est pas une carte de contact NyxChat';

  @override
  String invalidCard(String error) {
    return 'Carte invalide : $error';
  }

  @override
  String get scanContactCard => 'Scanner une carte de contact';

  @override
  String get pointCameraHint =>
      'Pointez la caméra vers le code QR de son écran Vérifier ou de sa page Paramètres.';

  @override
  String get scanningPinsKeys =>
      'Le scan épingle ses clés comme vérifiées. Rien n\'est envoyé sur le réseau.';

  @override
  String get security => 'Sécurité';

  @override
  String get databaseLock => 'Verrouillage de la base de données';

  @override
  String get requirePassword => 'Exiger un mot de passe';

  @override
  String get requirePasswordSubtitle =>
      'Clé de base de données enveloppée par Argon2id. Aucune récupération en cas d\'oubli.';

  @override
  String get lockWhenInBackground => 'Verrouiller en arrière-plan';

  @override
  String wipeAfterFailedAttempts(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Effacer après $count tentatives échouées',
      one: 'Effacer après 1 tentative échouée',
    );
    return '$_temp0';
  }

  @override
  String get duressPassword => 'Mot de passe de contrainte';

  @override
  String get duressPasswordSet => 'Mot de passe de contrainte défini';

  @override
  String get setADuressPassword => 'Définir un mot de passe de contrainte';

  @override
  String get duressOpensDecoyAndDestroys =>
      'Ouvre un profil leurre et détruit le vrai profil';

  @override
  String get duressOpensEmptyDecoy => 'Ouvre un profil leurre vide';

  @override
  String get duressExplanation =>
      'Le saisir sur l\'écran de verrouillage ouvre un profil leurre vide';

  @override
  String get removeDuressPassword => 'Supprimer le mot de passe de contrainte';

  @override
  String get identity => 'Identité';

  @override
  String get rotateIdentityKeys => 'Renouveler les clés d\'identité';

  @override
  String get rotateIdentitySubtitle =>
      'Nouvelles clés et nouvel identifiant. Les contacts en ligne reçoivent immédiatement une transition signée ; les autres la recevront à votre prochaine connexion directe. L\'application se ferme ensuite.';

  @override
  String get backup => 'Sauvegarde';

  @override
  String get exportEncryptedBackup => 'Exporter une sauvegarde chiffrée';

  @override
  String get exportBackupSubtitle =>
      'Clés d\'identité, contacts, sessions et messages, scellés avec une phrase secrète (Argon2id + AES-256-GCM).';

  @override
  String get restoreFromBackup => 'Restaurer depuis une sauvegarde';

  @override
  String get restoreBackupSubtitle =>
      'Remplace ce profil. Effacez ensuite l\'ancien appareil : deux copies actives d\'une même identité font diverger ses sessions.';

  @override
  String get dangerZone => 'Zone de danger';

  @override
  String get panicWipe => 'Effacement d\'urgence';

  @override
  String get panicWipeSubtitle =>
      'Détruit les messages, contacts, sessions et clés d\'identité. Irréversible.';

  @override
  String get securityFooter =>
      'Les clés résident dans le stockage sécurisé adossé au keystore Android. La base de données des messages est chiffrée en AES-256 avec une clé maîtresse aléatoire ; avec un mot de passe activé, cette clé est en plus enveloppée en AES-256-GCM sous une clé dérivée par Argon2id (32 MiB, 2 passes).';

  @override
  String get passphraseHint => 'Phrase secrète (8 caractères ou plus)';

  @override
  String get confirmPassphraseHint => 'Confirmer la phrase secrète';

  @override
  String get continueAction => 'Continuer';

  @override
  String get passphraseTooShortOrMismatch =>
      'Phrase secrète trop courte ou non concordante';

  @override
  String get rotateIdentityKeysQuestion => 'Renouveler les clés d\'identité ?';

  @override
  String get rotateIdentityWarning =>
      'Votre ID NyxChat va changer. Les contacts hors ligne ne pourront plus vous joindre tant que vous ne vous serez pas reconnectés directement.';

  @override
  String get rotate => 'Renouveler';

  @override
  String rotationFailed(String error) {
    return 'Échec du renouvellement : $error';
  }

  @override
  String get backupPassphrase => 'Phrase secrète de sauvegarde';

  @override
  String get saveBackupDialogTitle => 'Enregistrer la sauvegarde NyxChat';

  @override
  String get backupCancelled => 'Sauvegarde annulée';

  @override
  String get backupSaved => 'Sauvegarde enregistrée';

  @override
  String backupFailed(String error) {
    return 'Échec de la sauvegarde : $error';
  }

  @override
  String get replaceThisProfile => 'Remplacer ce profil ?';

  @override
  String restoreConfirmBody(String created, String name) {
    return 'Sauvegarde du $created pour « $name ». Tout le contenu de cet appareil sera remplacé et l\'application se fermera.';
  }

  @override
  String get restore => 'Restaurer';

  @override
  String restoreFailed(String error) {
    return 'Échec de la restauration : $error';
  }

  @override
  String get duressDifferentFromReal => 'Différent de votre vrai mot de passe';

  @override
  String get alsoDestroyRealProfile => 'Détruire aussi le vrai profil';

  @override
  String get wipeEverythingQuestion => 'Tout effacer ?';

  @override
  String get wipeEverythingBody =>
      'Tous les messages, contacts, sessions et vos clés d\'identité seront détruits sur cet appareil. Les pairs verront un changement de clés lors de votre prochaine rencontre.';

  @override
  String get wipe => 'Effacer';

  @override
  String get settings => 'Paramètres';

  @override
  String get privacy => 'Confidentialité';

  @override
  String get blockScreenshots => 'Bloquer les captures d\'écran';

  @override
  String get blockScreenshotsSubtitle =>
      'Masque l\'application dans les applis récentes et empêche la capture d\'écran';

  @override
  String get sendReadReceipts => 'Envoyer les accusés de lecture';

  @override
  String get notifications => 'Notifications';

  @override
  String get showMessageTextInNotifications =>
      'Afficher le texte des messages dans les notifications';

  @override
  String get coverTraffic => 'Trafic de couverture';

  @override
  String get coverTrafficSubtitle =>
      'Paquets maillés aléatoires pour que les périodes d\'inactivité et d\'activité se ressemblent';

  @override
  String get stealthMode => 'Mode furtif';

  @override
  String get stealthModeSubtitle =>
      'Ni diffusion ni balayage. Les liaisons existantes sont maintenues.';

  @override
  String get network => 'Réseau';

  @override
  String get localNetwork => 'Réseau local';

  @override
  String get active => 'Actif';

  @override
  String get inactive => 'Inactif';

  @override
  String get directLinks => 'Liaisons directes';

  @override
  String get unsupported => 'Non pris en charge';

  @override
  String advertisingLinks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count liaisons',
      one: '1 liaison',
    );
    return 'Diffusion · $_temp0';
  }

  @override
  String scanningLinks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count liaisons',
      one: '1 liaison',
    );
    return 'Balayage · $_temp0';
  }

  @override
  String get bleLongRange => 'BLE longue portée (Coded PHY)';

  @override
  String get bleLongRangeSubtitle =>
      'Codage Bluetooth 5 S=8 ; débit plus faible, portée plus longue';

  @override
  String get listeningPort => 'Port d\'écoute';

  @override
  String get globalDht => 'DHT globale';

  @override
  String get internetDelivery => 'Remise via Internet';

  @override
  String get deliverThroughRelays => 'Remettre via des relais publics (Nostr)';

  @override
  String get deliverThroughRelaysSubtitle =>
      'Enveloppes scellées sous des jetons tournants sur des relais Nostr publics. Aucun compte, aucun serveur à nous. Désactivé par défaut.';

  @override
  String get routeThroughTor => 'Acheminer les relais via Tor (Orbot)';

  @override
  String get routeThroughTorSubtitle =>
      'Nécessite Orbot en cours d\'exécution avec son proxy HTTP sur 127.0.0.1:8118';

  @override
  String get appLockDuressPanic =>
      'Verrouillage, mot de passe de contrainte, effacement d\'urgence';

  @override
  String get about => 'À propos';

  @override
  String get version => 'Version';

  @override
  String get protocol => 'Protocole';

  @override
  String protocolValue(String version) {
    return 'v$version · X25519+ML-KEM-768 · Double Ratchet · Sender Keys';
  }

  @override
  String get license => 'Licence';

  @override
  String get nyxChatIdCopied => 'ID NyxChat copié';

  @override
  String get contactCardCopied => 'Carte de contact copiée';

  @override
  String get copyContactCard => 'Copier la carte de contact';

  @override
  String get shareContactCardHint =>
      'Partagez-la pour que d\'autres puissent épingler et vérifier vos clés hors bande.';

  @override
  String get appearance => 'Apparence';

  @override
  String get theme => 'Thème';

  @override
  String get themeSystem => 'Système';

  @override
  String get themeLight => 'Clair';

  @override
  String get themeDark => 'Sombre';

  @override
  String get language => 'Langue';

  @override
  String get languageSystemDefault => 'Langue du système';

  @override
  String get wifiAware => 'Wi-Fi Aware';

  @override
  String get useWifiAware => 'Utiliser Wi-Fi Aware';

  @override
  String get useWifiAwareSubtitle =>
      'Liaisons de voisinage sans point d\'accès (Android 8+). Même balise tournante que le Bluetooth.';

  @override
  String get offlineSessions => 'Sessions hors ligne';

  @override
  String pqReady(int count) {
    return 'Confidentialité persistante post-quantique prête ($count préclés à usage unique)';
  }

  @override
  String get pqPending =>
      'Confidentialité persistante post-quantique en attente de la prochaine rencontre';

  @override
  String get voiceMessage => 'Message vocal';

  @override
  String get photo => 'Photo';

  @override
  String get holdToRecord =>
      'Maintenez le micro pour enregistrer un message vocal';

  @override
  String get slideToCancel => 'Glissez pour annuler';

  @override
  String get releaseToCancel => 'Relâchez pour annuler';

  @override
  String get recordingUnavailable =>
      'L\'enregistrement vocal n\'est pas disponible sur cet appareil';

  @override
  String get microphoneDenied =>
      'L\'accès au micro est nécessaire pour enregistrer des messages vocaux';

  @override
  String get recordingFailed => 'Impossible de démarrer l\'enregistrement';

  @override
  String get playbackUnavailable =>
      'La lecture vocale n\'est pas disponible sur cet appareil';

  @override
  String get playbackFailed => 'Impossible de lire ce message vocal';

  @override
  String get voiceNeedsCarrier =>
      'Les notes vocales nécessitent une connexion directe ou un chemin maillé';

  @override
  String get imageUnavailable => 'Image indisponible';

  @override
  String get receiving => 'Réception';
}
