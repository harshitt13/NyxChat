// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get appTitle => 'NyxChat';

  @override
  String get notificationNewMessage => 'Neue Nachricht';

  @override
  String get notificationChannelMessages => 'Nachrichten';

  @override
  String get notificationChannelMessagesDescription =>
      'Eingehende NyxChat-Nachrichten';

  @override
  String get meshChannelName => 'NyxChat-Mesh-Netzwerk';

  @override
  String get meshChannelDescription =>
      'Hält das dezentrale Mesh-Netzwerk im Hintergrund am Laufen.';

  @override
  String get meshNotificationInitial => 'Mesh-Netzwerk ist aktiv';

  @override
  String get meshNotificationActive => 'Mesh- und DHT-Routing aktiv';

  @override
  String get cancel => 'Abbrechen';

  @override
  String get save => 'Speichern';

  @override
  String get add => 'Hinzufügen';

  @override
  String get off => 'Aus';

  @override
  String get connect => 'Verbinden';

  @override
  String get verified => 'Verifiziert';

  @override
  String get messages => 'Nachrichten';

  @override
  String get safetyNumberChangedTitle => 'Sicherheitsnummer geändert';

  @override
  String safetyNumberChangedBody(String name, String id) {
    return '$name ($id) zeigt andere Identitätsschlüssel als die, die du gepinnt hast.\n\nDas passiert, wenn die App neu installiert wurde – oder wenn sich jemand als diese Person ausgibt. Überprüfe die neue Sicherheitsnummer persönlich, bevor du sie akzeptierst. Die Verbindung bleibt blockiert, bis du dich entscheidest.';
  }

  @override
  String get keepBlocking => 'Weiter blockieren';

  @override
  String get acceptNewKeys => 'Neue Schlüssel akzeptieren';

  @override
  String get searchConversationsHint => 'Chats und Nachrichten durchsuchen';

  @override
  String get emergencyBroadcastTitle => 'Notfall-Broadcast';

  @override
  String get noConversationsYet => 'Noch keine Chats';

  @override
  String get tapPlusToFindPeople =>
      'Tippe auf +, um Personen in der Nähe zu finden';

  @override
  String get noMatches => 'Keine Treffer';

  @override
  String get verifySafetyNumber => 'Sicherheitsnummer überprüfen';

  @override
  String get mute => 'Stummschalten';

  @override
  String get unmute => 'Stummschaltung aufheben';

  @override
  String get leaveGroup => 'Gruppe verlassen';

  @override
  String get deleteConversation => 'Chat löschen';

  @override
  String membersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Mitglieder',
      one: '1 Mitglied',
    );
    return '$_temp0';
  }

  @override
  String membersCountLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Mitglieder (verlassen)',
      one: '1 Mitglied (verlassen)',
    );
    return '$_temp0';
  }

  @override
  String get noMessagesYet => 'Noch keine Nachrichten';

  @override
  String get filesNeedDirectConnection =>
      'Dateien brauchen eine direkte Verbindung. Komm zuerst in WLAN-Reichweite.';

  @override
  String get reply => 'Antworten';

  @override
  String get copyText => 'Text kopieren';

  @override
  String get deleteForMe => 'Für mich löschen';

  @override
  String get disappearingMessages => 'Verschwindende Nachrichten';

  @override
  String get disappear5Minutes => '5 Minuten';

  @override
  String get disappear1Hour => '1 Stunde';

  @override
  String get disappear1Day => '1 Tag';

  @override
  String get disappear1Week => '1 Woche';

  @override
  String get conversationDeleted => 'Chat gelöscht';

  @override
  String get statusConnected => 'Verbunden';

  @override
  String get statusReachableViaMesh => 'Über Mesh erreichbar';

  @override
  String get statusOfflineDeliverLater => 'Offline · wird später zugestellt';

  @override
  String get endToEndEncrypted => 'Ende-zu-Ende-verschlüsselt';

  @override
  String get groupEncryptionHint =>
      'Nachrichten verwenden Schlüssel pro Absender; nur Mitglieder können sie lesen.';

  @override
  String get directEncryptionHint =>
      'Nachrichten sind durch eine Double-Ratchet-Sitzung geschützt.';

  @override
  String get noLongerMemberHint => 'Du bist kein Mitglied mehr';

  @override
  String get messageHint => 'Nachricht';

  @override
  String attachmentProgress(String percent, String size) {
    return '$percent% · $size';
  }

  @override
  String get sysMemberRemoved => 'Mitglied entfernt';

  @override
  String get sysYouLeftGroup => 'Du hast die Gruppe verlassen';

  @override
  String sysGroupCreated(String name) {
    return 'Gruppe „$name“ erstellt';
  }

  @override
  String sysMembersAdded(String names) {
    return '$names hinzugefügt';
  }

  @override
  String sysAddedToGroupBy(String name, String who) {
    return 'Du wurdest von $who zu „$name“ hinzugefügt';
  }

  @override
  String sysUpdatedMembers(String who) {
    return '$who hat die Mitglieder aktualisiert';
  }

  @override
  String get sysAMemberWasRemoved => 'Ein Mitglied wurde entfernt';

  @override
  String get sysYouWereRemoved => 'Du wurdest aus der Gruppe entfernt';

  @override
  String sysLeftGroup(String who) {
    return '$who hat die Gruppe verlassen';
  }

  @override
  String sysRenamedGroup(String who, String name) {
    return '$who hat die Gruppe in „$name“ umbenannt';
  }

  @override
  String get sysGroupUpdated => 'Gruppe aktualisiert';

  @override
  String sysKeysRotated(String name) {
    return '$name hat die Schlüssel rotiert (verifizierter Übergang)';
  }

  @override
  String get contactNotPinnedYet => 'Kontakt noch nicht gepinnt';

  @override
  String get safetyNumber => 'Sicherheitsnummer';

  @override
  String get safetyNumberExplanation =>
      'Ihr seht beide dieselbe Nummer, wenn niemand die Verbindung abfängt. Vergleicht sie persönlich, telefonisch oder über einen anderen Kanal, dem ihr vertraut.';

  @override
  String get markAsVerified => 'Als verifiziert markieren';

  @override
  String get messageAction => 'Nachricht';

  @override
  String get scanTheirQr => 'QR-Code des Kontakts scannen';

  @override
  String get verifiedKeysMatch =>
      'Verifiziert: Schlüssel stimmen mit diesem Kontakt überein';

  @override
  String cardBelongsToOther(String name) {
    return 'Diese Karte gehört $name und wurde separat gepinnt';
  }

  @override
  String get theirFingerprint => 'Fingerabdruck des Kontakts';

  @override
  String get yourFingerprint => 'Dein Fingerabdruck';

  @override
  String get showThemYourCard => 'Zeig deine Kontaktkarte vor';

  @override
  String get contactCardContainsOnlyPublicKeys =>
      'Enthält nur deine öffentlichen Schlüssel. Durch Scannen oder Einfügen wird deine Identität auf dem anderen Gerät gepinnt.';

  @override
  String get details => 'Details';

  @override
  String get nyxChatId => 'NyxChat-ID';

  @override
  String get handshake => 'Handshake';

  @override
  String get handshakeValue => 'X25519 + Kyber-768 hybrid, Ed25519-signiert';

  @override
  String get messagesValue => 'Double Ratchet, AES-256-GCM';

  @override
  String get firstSeen => 'Zuerst gesehen';

  @override
  String get keysChanged => 'Schlüssel geändert';

  @override
  String get idCopied => 'ID kopiert';

  @override
  String get giveGroupAName => 'Gib der Gruppe einen Namen';

  @override
  String get selectAtLeastOneMember => 'Wähle mindestens ein Mitglied aus';

  @override
  String get newGroup => 'Neue Gruppe';

  @override
  String get create => 'Erstellen';

  @override
  String get groupNameHint => 'Gruppenname';

  @override
  String get descriptionOptionalHint => 'Beschreibung (optional)';

  @override
  String membersSelectedHeader(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ausgewählt',
      one: '1 ausgewählt',
    );
    return 'Mitglieder · $_temp0';
  }

  @override
  String get noContactsYet =>
      'Noch keine Kontakte. Verbinde dich zuerst mit jemandem, damit die Schlüssel gepinnt werden.';

  @override
  String get noRecentPosition =>
      'Keine aktuelle Position. Gib eine Geohash-Zelle manuell ein oder geh nach draußen.';

  @override
  String invalidCell(String error) {
    return 'Ungültige Zelle: $error';
  }

  @override
  String get noNeighboursKept =>
      'Gerade keine Nachbarn. Deine Nachricht wird aufbewahrt und an das erste Gerät gesendet, das auftaucht.';

  @override
  String get areaCellLabel => 'Gebietszelle (Geohash)';

  @override
  String get findingYourArea => 'Dein Gebiet wird ermittelt...';

  @override
  String meshNeighboursCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Mesh-Nachbarn',
      one: '1 Mesh-Nachbar',
    );
    return '$_temp0';
  }

  @override
  String directLinksCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Direktverbindungen',
      one: '1 Direktverbindung',
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
    return 'Lausche in Zelle $cell ($area) · $neighbours, $links';
  }

  @override
  String get emergencyEmptyHint =>
      'Nachrichten von allen, die in dieser Zelle NyxChat nutzen, erscheinen hier. Deine Position verlässt das Telefon nie, es sei denn, du fügst sie ausdrücklich hinzu.';

  @override
  String get anonymous => 'Anonym';

  @override
  String positionLabel(String coords) {
    return 'Position: $coords';
  }

  @override
  String get includeMyName => 'Meinen Namen mitsenden';

  @override
  String get includeMyPosition => 'Meine Position mitsenden';

  @override
  String get emergencyComposerHint => 'Was passiert? Wo bist du?';

  @override
  String get joinCellFirst => 'Tritt zuerst einer Zelle bei';

  @override
  String get send => 'Senden';

  @override
  String get presetNeedHelp => 'Ich brauche Hilfe';

  @override
  String get presetSafe => 'Ich bin in Sicherheit';

  @override
  String get presetMedical => 'Medizinischer Notfall';

  @override
  String get addMembers => 'Mitglieder hinzufügen';

  @override
  String get groupEncryptionExplanation =>
      'Gruppennachrichten werden mit Sender Keys pro Mitglied verschlüsselt, die über paarweise Double-Ratchet-Sitzungen verteilt werden. Die Schlüssel rotieren, sobald jemand die Gruppe verlässt.';

  @override
  String memberYou(String name) {
    return '$name (du)';
  }

  @override
  String get admin => 'Admin';

  @override
  String get renameGroup => 'Gruppe umbenennen';

  @override
  String get noOtherKnownContacts => 'Keine weiteren bekannten Kontakte';

  @override
  String get meshDiagnostics => 'Mesh-Diagnose';

  @override
  String get statBleLinks => 'BLE-Verbindungen';

  @override
  String get statKnownRoutes => 'Bekannte Routen';

  @override
  String get statStoredPackets => 'Gespeicherte Pakete';

  @override
  String get statDeliveredToMe => 'An mich zugestellt';

  @override
  String get statReceived => 'Empfangen';

  @override
  String get statForwarded => 'Weitergeleitet';

  @override
  String get statDuplicatesDropped => 'Duplikate verworfen';

  @override
  String get statSeenIds => 'Gesehene IDs';

  @override
  String get linksHeader => 'Verbindungen';

  @override
  String get noBluetoothLinksHint =>
      'Keine Bluetooth-Verbindungen. Geräte in Reichweite verbinden sich automatisch, solange Scannen und Advertising aktiv sind.';

  @override
  String get weDialled => 'ausgehend';

  @override
  String get theyDialled => 'eingehend';

  @override
  String linkSubtitle(String role, int mtu, String address) {
    return '$role · MTU $mtu · $address';
  }

  @override
  String get routingTableHeader => 'Routingtabelle';

  @override
  String get routingTableHint =>
      'Routen werden aus dem in jedem Paket aufgezeichneten Pfad und aus regelmäßigen Beacons gelernt.';

  @override
  String routeToken(String prefix) {
    return 'Token $prefix...';
  }

  @override
  String routeVia(String hop, int hops) {
    String _temp0 = intl.Intl.pluralLogic(
      hops,
      locale: localeName,
      other: '$hops Hops',
      one: '1 Hop',
    );
    return 'über Relay $hop... · $_temp0';
  }

  @override
  String get howItWorksHeader => 'So funktioniert es';

  @override
  String meshExplanation(int copies, int hops) {
    return 'Pakete werden über SHA-256-Hashes adressiert und tragen einen Ende-zu-Ende-verschlüsselten Umschlag. Ein Relay speichert jedes Paket, leitet es an den gelernten nächsten Hop weiter oder streut bis zu $copies Kopien und verwirft es nach $hops Hops oder 24 Stunden. Relays können nicht lesen, verändern oder umadressieren, was sie transportieren.';
  }

  @override
  String get enterDisplayName => 'Gib einen Anzeigenamen ein (max. 64 Zeichen)';

  @override
  String couldNotCreateIdentity(String error) {
    return 'Identität konnte nicht erstellt werden: $error';
  }

  @override
  String get tagline => 'Peer-to-Peer · verschlüsselt · offlinefähig';

  @override
  String get featureE2eSubtitle =>
      'Double Ratchet mit hybridem X25519 + Kyber-768-Handshake';

  @override
  String get featureOfflineTitle => 'Funktioniert ohne Internet';

  @override
  String get featureOfflineSubtitle =>
      'WLAN und Bluetooth-Mesh, Zustellung per Store-and-Forward';

  @override
  String get featureNoServersTitle => 'Keine Server, keine Konten';

  @override
  String get featureNoServersSubtitle =>
      'Deine Identität ist ein Schlüsselpaar, das dieses Gerät nie verlässt';

  @override
  String get displayName => 'Anzeigename';

  @override
  String get createIdentity => 'Identität erstellen';

  @override
  String get keysGeneratedLocally =>
      'Erzeugt X25519-, Ed25519- und Kyber-768-Schlüssel lokal. Nichts wird hochgeladen.';

  @override
  String get passwordRequired => 'Passwort ist erforderlich';

  @override
  String get atLeast8Characters => 'Mindestens 8 Zeichen';

  @override
  String get passwordsDoNotMatch => 'Passwörter stimmen nicht überein';

  @override
  String get enterYourPassword => 'Gib dein Passwort ein';

  @override
  String get allDataWiped => 'Alle Daten wurden gelöscht.';

  @override
  String get incorrectPassword => 'Falsches Passwort';

  @override
  String incorrectPasswordAttemptsLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Versuche',
      one: '1 Versuch',
    );
    return 'Falsches Passwort · noch $_temp0 bis zur Löschung';
  }

  @override
  String get setAppLock => 'App-Sperre einrichten';

  @override
  String get nyxChatIsLocked => 'NyxChat ist gesperrt';

  @override
  String get unlockPrompt =>
      'Deine Datenbank ist verschlüsselt. Gib dein Passwort ein, um sie zu entsperren.';

  @override
  String get passwordSetupExplanation =>
      'Der Datenbankschlüssel wird mit einem per Argon2id aus diesem Passwort abgeleiteten Schlüssel verschlüsselt. Es gibt keine Wiederherstellung: Ein vergessenes Passwort bedeutet, dass die Daten verloren sind.';

  @override
  String get passwordHint => 'Passwort';

  @override
  String get confirmPasswordHint => 'Passwort bestätigen';

  @override
  String get enableLock => 'Sperre aktivieren';

  @override
  String get unlock => 'Entsperren';

  @override
  String get connectedAndAuthenticated => 'Verbunden und authentifiziert';

  @override
  String get connectionFailed =>
      'Verbindung fehlgeschlagen (nicht erreichbar, abgelehnt oder Schlüssel stimmen nicht überein)';

  @override
  String pinnedAndVerified(String name) {
    return '$name gepinnt und verifiziert';
  }

  @override
  String invalidContactCard(String error) {
    return 'Ungültige Kontaktkarte: $error';
  }

  @override
  String get findPeople => 'Personen finden';

  @override
  String get visibleToEveryoneNearby => 'Für alle in der Nähe sichtbar';

  @override
  String get visibleSubtitlePublic =>
      'Deine ID und dein Name werden per Broadcast gesendet, damit neue Personen dich finden können.';

  @override
  String get visibleSubtitlePrivate =>
      'Private Beacons: Nur gepinnte Kontakte können dich erkennen; andere sehen zufälliges Rauschen.';

  @override
  String get scanContactQr => 'Kontakt-QR scannen';

  @override
  String get emergency => 'Notfall';

  @override
  String get nearbyOnWifi => 'In der Nähe im WLAN';

  @override
  String get nobodyDiscoveredYet =>
      'Noch niemand gefunden. Geräte im selben WLAN erscheinen hier automatisch.';

  @override
  String get bluetoothMesh => 'Bluetooth-Mesh';

  @override
  String get bleNotAvailable =>
      'Bluetooth LE ist auf diesem Gerät nicht verfügbar.';

  @override
  String get bleScanningHint =>
      'Scannen läuft. Andere NyxChat-Geräte in Reichweite verbinden sich automatisch.';

  @override
  String get bleScanningAdvertisingHint =>
      'Scannen und Advertising laufen. Andere NyxChat-Geräte in Reichweite verbinden sich automatisch.';

  @override
  String get roleCentral => 'Central';

  @override
  String get rolePeripheral => 'Peripheral';

  @override
  String bleLinkedSubtitle(String role, int mtu) {
    return 'verbunden · $role · MTU $mtu';
  }

  @override
  String rssiDbm(int rssi) {
    return '$rssi dBm';
  }

  @override
  String get contacts => 'Kontakte';

  @override
  String get contactsPinnedHint =>
      'Hier werden die Schlüssel aller Peers gepinnt, mit denen du dich verbindest.';

  @override
  String get addContactFromCard => 'Kontakt aus Karte hinzufügen';

  @override
  String get pasteContactCardHint =>
      'Füge den Text einer Kontaktkarte ein (wird unter „Verifizieren“ als QR angezeigt). Damit werden die Schlüssel gepinnt und verifiziert.';

  @override
  String get importCard => 'Karte importieren';

  @override
  String get manualConnection => 'Manuelle Verbindung';

  @override
  String get ipAddressHint => 'IP-Adresse';

  @override
  String get portHint => 'Port';

  @override
  String get connecting => 'Verbindung wird hergestellt...';

  @override
  String get globalDirectory => 'Globales Verzeichnis (DHT, experimentell)';

  @override
  String get dhtHint =>
      'Benötigt einen erreichbaren Bootstrap-Knoten. Ankündigungen sind signiert; über Vertrauen entscheidet weiterhin der Handshake.';

  @override
  String dhtRunning(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Knoten',
      one: '1 Knoten',
    );
    return 'Läuft · $_temp0';
  }

  @override
  String get stopped => 'Gestoppt';

  @override
  String get stop => 'Stoppen';

  @override
  String get start => 'Starten';

  @override
  String get bootstrapHint => 'Bootstrap host:port';

  @override
  String get bootstrapNodeAdded => 'Bootstrap-Knoten hinzugefügt';

  @override
  String get lookupHint => 'NC-... zum Nachschlagen';

  @override
  String get find => 'Suchen';

  @override
  String get notFound => 'Nicht gefunden';

  @override
  String foundPeerAt(String name, String address) {
    return '$name unter $address gefunden';
  }

  @override
  String get lanOn => 'LAN an';

  @override
  String get lanOff => 'LAN aus';

  @override
  String get bleOn => 'BLE an';

  @override
  String get bleScan => 'BLE-Scan';

  @override
  String get bleOff => 'BLE aus';

  @override
  String linksCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Verbindungen',
      one: '1 Verbindung',
    );
    return '$_temp0';
  }

  @override
  String get stealth => 'Tarnmodus';

  @override
  String get visible => 'sichtbar';

  @override
  String get reachable => 'erreichbar';

  @override
  String get offlineQueued => 'offline, Zustellung in Warteschlange';

  @override
  String get notANyxChatContactCard => 'Keine NyxChat-Kontaktkarte';

  @override
  String invalidCard(String error) {
    return 'Ungültige Karte: $error';
  }

  @override
  String get scanContactCard => 'Kontaktkarte scannen';

  @override
  String get pointCameraHint =>
      'Richte die Kamera auf den QR-Code auf dem Verifizieren-Bildschirm oder in den Einstellungen des Kontakts.';

  @override
  String get scanningPinsKeys =>
      'Beim Scannen werden die Schlüssel als verifiziert gepinnt. Nichts wird über das Netzwerk gesendet.';

  @override
  String get security => 'Sicherheit';

  @override
  String get databaseLock => 'Datenbanksperre';

  @override
  String get requirePassword => 'Passwort erforderlich';

  @override
  String get requirePasswordSubtitle =>
      'Datenbankschlüssel per Argon2id verschlüsselt. Keine Wiederherstellung, wenn vergessen.';

  @override
  String get lockWhenInBackground => 'Im Hintergrund sperren';

  @override
  String wipeAfterFailedAttempts(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Löschen nach $count Fehlversuchen',
      one: 'Löschen nach 1 Fehlversuch',
    );
    return '$_temp0';
  }

  @override
  String get duressPassword => 'Tarnpasswort';

  @override
  String get duressPasswordSet => 'Tarnpasswort gesetzt';

  @override
  String get setADuressPassword => 'Tarnpasswort festlegen';

  @override
  String get duressOpensDecoyAndDestroys =>
      'Öffnet ein Tarnprofil und zerstört das echte';

  @override
  String get duressOpensEmptyDecoy => 'Öffnet ein leeres Tarnprofil';

  @override
  String get duressExplanation =>
      'Bei Eingabe auf dem Sperrbildschirm öffnet sich ein leeres Tarnprofil';

  @override
  String get removeDuressPassword => 'Tarnpasswort entfernen';

  @override
  String get identity => 'Identität';

  @override
  String get rotateIdentityKeys => 'Identitätsschlüssel rotieren';

  @override
  String get rotateIdentitySubtitle =>
      'Neue Schlüssel und neue ID. Kontakte, die gerade online sind, erhalten sofort einen signierten Übergang; alle anderen beim nächsten direkten Verbinden. Die App wird danach geschlossen.';

  @override
  String get backup => 'Backup';

  @override
  String get exportEncryptedBackup => 'Verschlüsseltes Backup exportieren';

  @override
  String get exportBackupSubtitle =>
      'Identitätsschlüssel, Kontakte, Sitzungen und Nachrichten, versiegelt mit einer Passphrase (Argon2id + AES-256-GCM).';

  @override
  String get restoreFromBackup => 'Aus Backup wiederherstellen';

  @override
  String get restoreBackupSubtitle =>
      'Ersetzt dieses Profil. Lösche danach das alte Gerät: Zwei aktive Kopien einer Identität spalten ihre Sitzungen auf.';

  @override
  String get dangerZone => 'Gefahrenzone';

  @override
  String get panicWipe => 'Panik-Löschung';

  @override
  String get panicWipeSubtitle =>
      'Zerstört Nachrichten, Kontakte, Sitzungen und Identitätsschlüssel. Unwiderruflich.';

  @override
  String get securityFooter =>
      'Schlüssel liegen im vom Android-Keystore gesicherten Speicher. Die Nachrichtendatenbank ist mit einem zufälligen Hauptschlüssel AES-256-verschlüsselt; bei aktiviertem Passwort wird dieser Schlüssel zusätzlich mit AES-256-GCM unter einem per Argon2id abgeleiteten Schlüssel (32 MiB, 2 Durchgänge) verschlüsselt.';

  @override
  String get passphraseHint => 'Passphrase (mind. 8 Zeichen)';

  @override
  String get confirmPassphraseHint => 'Passphrase bestätigen';

  @override
  String get continueAction => 'Weiter';

  @override
  String get passphraseTooShortOrMismatch =>
      'Passphrase zu kurz oder stimmt nicht überein';

  @override
  String get rotateIdentityKeysQuestion => 'Identitätsschlüssel rotieren?';

  @override
  String get rotateIdentityWarning =>
      'Deine NyxChat-ID wird sich ändern. Kontakte, die offline sind, können dich erst wieder erreichen, wenn ihr euch erneut direkt trefft.';

  @override
  String get rotate => 'Rotieren';

  @override
  String rotationFailed(String error) {
    return 'Rotation fehlgeschlagen: $error';
  }

  @override
  String get backupPassphrase => 'Backup-Passphrase';

  @override
  String get saveBackupDialogTitle => 'NyxChat-Backup speichern';

  @override
  String get backupCancelled => 'Backup abgebrochen';

  @override
  String get backupSaved => 'Backup gespeichert';

  @override
  String backupFailed(String error) {
    return 'Backup fehlgeschlagen: $error';
  }

  @override
  String get replaceThisProfile => 'Dieses Profil ersetzen?';

  @override
  String restoreConfirmBody(String created, String name) {
    return 'Backup vom $created für „$name“. Alles auf diesem Gerät wird ersetzt und die App wird geschlossen.';
  }

  @override
  String get restore => 'Wiederherstellen';

  @override
  String restoreFailed(String error) {
    return 'Wiederherstellung fehlgeschlagen: $error';
  }

  @override
  String get duressDifferentFromReal =>
      'Muss sich von deinem echten Passwort unterscheiden';

  @override
  String get alsoDestroyRealProfile => 'Auch das echte Profil zerstören';

  @override
  String get wipeEverythingQuestion => 'Alles löschen?';

  @override
  String get wipeEverythingBody =>
      'Alle Nachrichten, Kontakte, Sitzungen und deine Identitätsschlüssel werden auf diesem Gerät zerstört. Kontakte sehen beim nächsten Treffen eine Schlüsseländerung.';

  @override
  String get wipe => 'Löschen';

  @override
  String get settings => 'Einstellungen';

  @override
  String get privacy => 'Datenschutz';

  @override
  String get blockScreenshots => 'Screenshots blockieren';

  @override
  String get blockScreenshotsSubtitle =>
      'Verbirgt die App in der Übersicht der letzten Apps und verhindert Bildschirmaufnahmen';

  @override
  String get sendReadReceipts => 'Lesebestätigungen senden';

  @override
  String get notifications => 'Benachrichtigungen';

  @override
  String get showMessageTextInNotifications =>
      'Nachrichtentext in Benachrichtigungen anzeigen';

  @override
  String get coverTraffic => 'Tarnverkehr';

  @override
  String get coverTrafficSubtitle =>
      'Zufällige Mesh-Pakete, damit sich Leerlauf und Aktivität nicht unterscheiden lassen';

  @override
  String get stealthMode => 'Tarnmodus';

  @override
  String get stealthModeSubtitle =>
      'Kein Advertising und kein Scannen. Bestehende Verbindungen bleiben aktiv.';

  @override
  String get network => 'Netzwerk';

  @override
  String get localNetwork => 'Lokales Netzwerk';

  @override
  String get active => 'Aktiv';

  @override
  String get inactive => 'Inaktiv';

  @override
  String get directLinks => 'Direktverbindungen';

  @override
  String get unsupported => 'Nicht unterstützt';

  @override
  String advertisingLinks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Verbindungen',
      one: '1 Verbindung',
    );
    return 'Advertising · $_temp0';
  }

  @override
  String scanningLinks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Verbindungen',
      one: '1 Verbindung',
    );
    return 'Scannen · $_temp0';
  }

  @override
  String get bleLongRange => 'BLE Long Range (Coded PHY)';

  @override
  String get bleLongRangeSubtitle =>
      'Bluetooth 5 S=8-Codierung; geringerer Durchsatz, größere Reichweite';

  @override
  String get listeningPort => 'Empfangsport';

  @override
  String get globalDht => 'Globale DHT';

  @override
  String get internetDelivery => 'Zustellung über das Internet';

  @override
  String get deliverThroughRelays =>
      'Über öffentliche Relays zustellen (Nostr)';

  @override
  String get deliverThroughRelaysSubtitle =>
      'Versiegelte Umschläge unter rotierenden Tokens auf öffentlichen Nostr-Relays. Kein Konto, kein eigener Server. Standardmäßig aus.';

  @override
  String get routeThroughTor => 'Relays über Tor leiten (Orbot)';

  @override
  String get routeThroughTorSubtitle =>
      'Erfordert ein laufendes Orbot mit HTTP-Proxy auf 127.0.0.1:8118';

  @override
  String get appLockDuressPanic => 'App-Sperre, Tarnpasswort, Panik-Löschung';

  @override
  String get about => 'Info';

  @override
  String get version => 'Version';

  @override
  String get protocol => 'Protokoll';

  @override
  String protocolValue(String version) {
    return 'v$version · X25519+Kyber-768 · Double Ratchet · Sender Keys';
  }

  @override
  String get license => 'Lizenz';

  @override
  String get nyxChatIdCopied => 'NyxChat-ID kopiert';

  @override
  String get contactCardCopied => 'Kontaktkarte kopiert';

  @override
  String get copyContactCard => 'Kontaktkarte kopieren';

  @override
  String get shareContactCardHint =>
      'Teile dies, damit andere deine Schlüssel über einen separaten Kanal pinnen und verifizieren können.';

  @override
  String get appearance => 'Darstellung';

  @override
  String get theme => 'Design';

  @override
  String get themeSystem => 'Systemstandard';

  @override
  String get themeLight => 'Hell';

  @override
  String get themeDark => 'Dunkel';

  @override
  String get language => 'Sprache';

  @override
  String get languageSystemDefault => 'Systemstandard';
}
