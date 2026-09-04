// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'NyxChat';

  @override
  String get notificationNewMessage => 'New message';

  @override
  String get notificationChannelMessages => 'Messages';

  @override
  String get notificationChannelMessagesDescription =>
      'Incoming NyxChat messages';

  @override
  String get meshChannelName => 'NyxChat Mesh Network';

  @override
  String get meshChannelDescription =>
      'Keeps the decentralized mesh network running in the background.';

  @override
  String get meshNotificationInitial => 'Mesh Network is active';

  @override
  String get meshNotificationActive => 'Mesh and DHT routing active';

  @override
  String get cancel => 'Cancel';

  @override
  String get save => 'Save';

  @override
  String get add => 'Add';

  @override
  String get off => 'Off';

  @override
  String get connect => 'Connect';

  @override
  String get verified => 'Verified';

  @override
  String get messages => 'Messages';

  @override
  String get safetyNumberChangedTitle => 'Safety number changed';

  @override
  String safetyNumberChangedBody(String name, String id) {
    return '$name ($id) is presenting different identity keys than the ones you have pinned.\n\nThis happens when they reinstalled the app, or if someone is impersonating them. Verify the new safety number in person before accepting. The connection stays blocked until you decide.';
  }

  @override
  String get keepBlocking => 'Keep blocking';

  @override
  String get acceptNewKeys => 'Accept new keys';

  @override
  String get searchConversationsHint => 'Search conversations and messages';

  @override
  String get emergencyBroadcastTitle => 'Emergency broadcast';

  @override
  String get noConversationsYet => 'No conversations yet';

  @override
  String get tapPlusToFindPeople => 'Tap + to find people nearby';

  @override
  String get noMatches => 'No matches';

  @override
  String get verifySafetyNumber => 'Verify safety number';

  @override
  String get mute => 'Mute';

  @override
  String get unmute => 'Unmute';

  @override
  String get leaveGroup => 'Leave group';

  @override
  String get deleteConversation => 'Delete conversation';

  @override
  String membersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count members',
      one: '1 member',
    );
    return '$_temp0';
  }

  @override
  String membersCountLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count members (left)',
      one: '1 member (left)',
    );
    return '$_temp0';
  }

  @override
  String get noMessagesYet => 'No messages yet';

  @override
  String get filesNeedDirectConnection =>
      'Files need a direct connection. Come within Wi-Fi range first.';

  @override
  String get reply => 'Reply';

  @override
  String get copyText => 'Copy text';

  @override
  String get deleteForMe => 'Delete for me';

  @override
  String get disappearingMessages => 'Disappearing messages';

  @override
  String get disappear5Minutes => '5 minutes';

  @override
  String get disappear1Hour => '1 hour';

  @override
  String get disappear1Day => '1 day';

  @override
  String get disappear1Week => '1 week';

  @override
  String get conversationDeleted => 'Conversation deleted';

  @override
  String get statusConnected => 'Connected';

  @override
  String get statusReachableViaMesh => 'Reachable via mesh';

  @override
  String get statusOfflineDeliverLater => 'Offline · will deliver later';

  @override
  String get endToEndEncrypted => 'End-to-end encrypted';

  @override
  String get groupEncryptionHint =>
      'Messages use per-sender keys; only members can read them.';

  @override
  String get directEncryptionHint =>
      'Messages are protected by a Double Ratchet session.';

  @override
  String get noLongerMemberHint => 'You are no longer a member';

  @override
  String get messageHint => 'Message';

  @override
  String attachmentProgress(String percent, String size) {
    return '$percent% · $size';
  }

  @override
  String get sysMemberRemoved => 'Member removed';

  @override
  String get sysYouLeftGroup => 'You left the group';

  @override
  String sysGroupCreated(String name) {
    return 'Group \"$name\" created';
  }

  @override
  String sysMembersAdded(String names) {
    return '$names added';
  }

  @override
  String sysAddedToGroupBy(String name, String who) {
    return 'You were added to \"$name\" by $who';
  }

  @override
  String sysUpdatedMembers(String who) {
    return '$who updated the members';
  }

  @override
  String get sysAMemberWasRemoved => 'A member was removed';

  @override
  String get sysYouWereRemoved => 'You were removed from the group';

  @override
  String sysLeftGroup(String who) {
    return '$who left the group';
  }

  @override
  String sysRenamedGroup(String who, String name) {
    return '$who renamed the group to \"$name\"';
  }

  @override
  String get sysGroupUpdated => 'Group updated';

  @override
  String sysKeysRotated(String name) {
    return '$name rotated their keys (verified transition)';
  }

  @override
  String get contactNotPinnedYet => 'Contact not pinned yet';

  @override
  String get safetyNumber => 'Safety number';

  @override
  String get safetyNumberExplanation =>
      'Both of you see the same number if nobody is intercepting the connection. Compare it in person, by phone, or through another channel you trust.';

  @override
  String get markAsVerified => 'Mark as verified';

  @override
  String get messageAction => 'Message';

  @override
  String get scanTheirQr => 'Scan their QR code';

  @override
  String get verifiedKeysMatch => 'Verified: keys match this contact';

  @override
  String cardBelongsToOther(String name) {
    return 'That card belongs to $name, pinned separately';
  }

  @override
  String get theirFingerprint => 'Their fingerprint';

  @override
  String get yourFingerprint => 'Your fingerprint';

  @override
  String get showThemYourCard => 'Show them your contact card';

  @override
  String get contactCardContainsOnlyPublicKeys =>
      'Contains only your public keys. Scanning or pasting it pins your identity on their device.';

  @override
  String get details => 'Details';

  @override
  String get nyxChatId => 'NyxChat ID';

  @override
  String get handshake => 'Handshake';

  @override
  String get handshakeValue => 'X25519 + Kyber-768 hybrid, Ed25519 signed';

  @override
  String get messagesValue => 'Double Ratchet, AES-256-GCM';

  @override
  String get firstSeen => 'First seen';

  @override
  String get keysChanged => 'Keys changed';

  @override
  String get idCopied => 'ID copied';

  @override
  String get giveGroupAName => 'Give the group a name';

  @override
  String get selectAtLeastOneMember => 'Select at least one member';

  @override
  String get newGroup => 'New group';

  @override
  String get create => 'Create';

  @override
  String get groupNameHint => 'Group name';

  @override
  String get descriptionOptionalHint => 'Description (optional)';

  @override
  String membersSelectedHeader(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count selected',
      one: '1 selected',
    );
    return 'Members · $_temp0';
  }

  @override
  String get noContactsYet =>
      'No contacts yet. Connect to someone first so their keys are pinned.';

  @override
  String get noRecentPosition =>
      'No recent position. Enter a geohash cell manually or move outdoors.';

  @override
  String invalidCell(String error) {
    return 'Invalid cell: $error';
  }

  @override
  String get noNeighboursKept =>
      'No neighbours right now. Your message is kept and sent to the first device that appears.';

  @override
  String get areaCellLabel => 'Area cell (geohash)';

  @override
  String get findingYourArea => 'Finding your area...';

  @override
  String meshNeighboursCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count mesh neighbours',
      one: '1 mesh neighbour',
    );
    return '$_temp0';
  }

  @override
  String directLinksCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count direct links',
      one: '1 direct link',
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
    return 'Listening in cell $cell ($area) · $neighbours, $links';
  }

  @override
  String get emergencyEmptyHint =>
      'Messages from anyone running NyxChat in this cell appear here. Your position never leaves the phone unless you include it explicitly.';

  @override
  String get anonymous => 'Anonymous';

  @override
  String positionLabel(String coords) {
    return 'Position: $coords';
  }

  @override
  String get includeMyName => 'Include my name';

  @override
  String get includeMyPosition => 'Include my position';

  @override
  String get emergencyComposerHint => 'What is happening? Where are you?';

  @override
  String get joinCellFirst => 'Join a cell first';

  @override
  String get send => 'Send';

  @override
  String get presetNeedHelp => 'I need help';

  @override
  String get presetSafe => 'I am safe';

  @override
  String get presetMedical => 'Medical emergency';

  @override
  String get addMembers => 'Add members';

  @override
  String get groupEncryptionExplanation =>
      'Group messages are encrypted with per-member sender keys distributed over pairwise Double Ratchet sessions. Keys rotate whenever someone leaves.';

  @override
  String memberYou(String name) {
    return '$name (you)';
  }

  @override
  String get admin => 'Admin';

  @override
  String get renameGroup => 'Rename group';

  @override
  String get noOtherKnownContacts => 'No other known contacts';

  @override
  String get meshDiagnostics => 'Mesh diagnostics';

  @override
  String get statBleLinks => 'BLE links';

  @override
  String get statKnownRoutes => 'Known routes';

  @override
  String get statStoredPackets => 'Stored packets';

  @override
  String get statDeliveredToMe => 'Delivered to me';

  @override
  String get statReceived => 'Received';

  @override
  String get statForwarded => 'Forwarded';

  @override
  String get statDuplicatesDropped => 'Duplicates dropped';

  @override
  String get statSeenIds => 'Seen ids';

  @override
  String get linksHeader => 'Links';

  @override
  String get noBluetoothLinksHint =>
      'No Bluetooth links. Devices within range link automatically while scanning and advertising are on.';

  @override
  String get weDialled => 'we dialled';

  @override
  String get theyDialled => 'they dialled';

  @override
  String linkSubtitle(String role, int mtu, String address) {
    return '$role · MTU $mtu · $address';
  }

  @override
  String get routingTableHeader => 'Routing table';

  @override
  String get routingTableHint =>
      'Routes are learned from the path recorded in every packet and from periodic beacons.';

  @override
  String routeToken(String prefix) {
    return 'token $prefix...';
  }

  @override
  String routeVia(String hop, int hops) {
    String _temp0 = intl.Intl.pluralLogic(
      hops,
      locale: localeName,
      other: '$hops hops',
      one: '1 hop',
    );
    return 'via relay $hop... · $_temp0';
  }

  @override
  String get howItWorksHeader => 'How it works';

  @override
  String meshExplanation(int copies, int hops) {
    return 'Packets are addressed by SHA-256 hashes and carry an end-to-end encrypted envelope. A relay stores each packet, forwards it to the learned next hop or sprays up to $copies copies, and drops it after $hops hops or 24 hours. Relays cannot read, alter or re-address what they carry.';
  }

  @override
  String get enterDisplayName => 'Enter a display name (max 64 characters)';

  @override
  String couldNotCreateIdentity(String error) {
    return 'Could not create identity: $error';
  }

  @override
  String get tagline => 'peer-to-peer · encrypted · offline-capable';

  @override
  String get featureE2eSubtitle =>
      'Double Ratchet with a hybrid X25519 + Kyber-768 handshake';

  @override
  String get featureOfflineTitle => 'Works without internet';

  @override
  String get featureOfflineSubtitle =>
      'Wi-Fi LAN and Bluetooth mesh, store-and-forward delivery';

  @override
  String get featureNoServersTitle => 'No servers, no accounts';

  @override
  String get featureNoServersSubtitle =>
      'Your identity is a key pair that never leaves this device';

  @override
  String get displayName => 'Display name';

  @override
  String get createIdentity => 'Create identity';

  @override
  String get keysGeneratedLocally =>
      'Generates X25519, Ed25519 and Kyber-768 keys locally. Nothing is uploaded.';

  @override
  String get passwordRequired => 'Password is required';

  @override
  String get atLeast8Characters => 'At least 8 characters';

  @override
  String get passwordsDoNotMatch => 'Passwords do not match';

  @override
  String get enterYourPassword => 'Enter your password';

  @override
  String get allDataWiped => 'All data has been wiped.';

  @override
  String get incorrectPassword => 'Incorrect password';

  @override
  String incorrectPasswordAttemptsLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count attempts',
      one: '1 attempt',
    );
    return 'Incorrect password · $_temp0 left before wipe';
  }

  @override
  String get setAppLock => 'Set app lock';

  @override
  String get nyxChatIsLocked => 'NyxChat is locked';

  @override
  String get unlockPrompt =>
      'Your database is encrypted. Enter your password to unlock.';

  @override
  String get passwordSetupExplanation =>
      'The database key will be wrapped with a key derived from this password using Argon2id. There is no recovery: a forgotten password means the data is gone.';

  @override
  String get passwordHint => 'Password';

  @override
  String get confirmPasswordHint => 'Confirm password';

  @override
  String get enableLock => 'Enable lock';

  @override
  String get unlock => 'Unlock';

  @override
  String get connectedAndAuthenticated => 'Connected and authenticated';

  @override
  String get connectionFailed =>
      'Connection failed (unreachable, refused, or key mismatch)';

  @override
  String pinnedAndVerified(String name) {
    return 'Pinned and verified $name';
  }

  @override
  String invalidContactCard(String error) {
    return 'Invalid contact card: $error';
  }

  @override
  String get findPeople => 'Find people';

  @override
  String get visibleToEveryoneNearby => 'Visible to everyone nearby';

  @override
  String get visibleSubtitlePublic =>
      'Your ID and name are broadcast so new people can find you.';

  @override
  String get visibleSubtitlePrivate =>
      'Private beacons: only pinned contacts can recognise you; others see random noise.';

  @override
  String get scanContactQr => 'Scan contact QR';

  @override
  String get emergency => 'Emergency';

  @override
  String get nearbyOnWifi => 'Nearby on Wi-Fi';

  @override
  String get nobodyDiscoveredYet =>
      'Nobody discovered yet. Peers on the same Wi-Fi appear here automatically.';

  @override
  String get bluetoothMesh => 'Bluetooth mesh';

  @override
  String get bleNotAvailable => 'Bluetooth LE is not available on this device.';

  @override
  String get bleScanningHint =>
      'Scanning. Other NyxChat devices within range will link automatically.';

  @override
  String get bleScanningAdvertisingHint =>
      'Scanning and advertising. Other NyxChat devices within range will link automatically.';

  @override
  String get roleCentral => 'central';

  @override
  String get rolePeripheral => 'peripheral';

  @override
  String bleLinkedSubtitle(String role, int mtu) {
    return 'linked · $role · MTU $mtu';
  }

  @override
  String rssiDbm(int rssi) {
    return '$rssi dBm';
  }

  @override
  String get contacts => 'Contacts';

  @override
  String get contactsPinnedHint =>
      'Keys of every peer you connect to are pinned here.';

  @override
  String get addContactFromCard => 'Add contact from card';

  @override
  String get pasteContactCardHint =>
      'Paste the text of a contact card (shown as QR in Verify). This pins and verifies their keys.';

  @override
  String get importCard => 'Import card';

  @override
  String get manualConnection => 'Manual connection';

  @override
  String get ipAddressHint => 'IP address';

  @override
  String get portHint => 'Port';

  @override
  String get connecting => 'Connecting...';

  @override
  String get globalDirectory => 'Global directory (DHT, experimental)';

  @override
  String get dhtHint =>
      'Needs a reachable bootstrap node. Announcements are signed; the handshake still decides trust.';

  @override
  String dhtRunning(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count nodes',
      one: '1 node',
    );
    return 'Running · $_temp0';
  }

  @override
  String get stopped => 'Stopped';

  @override
  String get stop => 'Stop';

  @override
  String get start => 'Start';

  @override
  String get bootstrapHint => 'bootstrap host:port';

  @override
  String get bootstrapNodeAdded => 'Bootstrap node added';

  @override
  String get lookupHint => 'NC-... to look up';

  @override
  String get find => 'Find';

  @override
  String get notFound => 'Not found';

  @override
  String foundPeerAt(String name, String address) {
    return 'Found $name at $address';
  }

  @override
  String get lanOn => 'LAN on';

  @override
  String get lanOff => 'LAN off';

  @override
  String get bleOn => 'BLE on';

  @override
  String get bleScan => 'BLE scan';

  @override
  String get bleOff => 'BLE off';

  @override
  String linksCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count links',
      one: '1 link',
    );
    return '$_temp0';
  }

  @override
  String get stealth => 'stealth';

  @override
  String get visible => 'visible';

  @override
  String get reachable => 'reachable';

  @override
  String get offlineQueued => 'offline, queued delivery';

  @override
  String get notANyxChatContactCard => 'Not a NyxChat contact card';

  @override
  String invalidCard(String error) {
    return 'Invalid card: $error';
  }

  @override
  String get scanContactCard => 'Scan contact card';

  @override
  String get pointCameraHint =>
      'Point the camera at the QR code on their Verify screen or Settings page.';

  @override
  String get scanningPinsKeys =>
      'Scanning pins their keys as verified. Nothing is sent over the network.';

  @override
  String get security => 'Security';

  @override
  String get databaseLock => 'Database lock';

  @override
  String get requirePassword => 'Require password';

  @override
  String get requirePasswordSubtitle =>
      'Argon2id-wrapped database key. No recovery if forgotten.';

  @override
  String get lockWhenInBackground => 'Lock when in background';

  @override
  String wipeAfterFailedAttempts(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Wipe after $count failed attempts',
      one: 'Wipe after 1 failed attempt',
    );
    return '$_temp0';
  }

  @override
  String get duressPassword => 'Duress password';

  @override
  String get duressPasswordSet => 'Duress password set';

  @override
  String get setADuressPassword => 'Set a duress password';

  @override
  String get duressOpensDecoyAndDestroys =>
      'Opens a decoy profile and destroys the real one';

  @override
  String get duressOpensEmptyDecoy => 'Opens an empty decoy profile';

  @override
  String get duressExplanation =>
      'Entering it at the lock screen opens an empty decoy profile';

  @override
  String get removeDuressPassword => 'Remove duress password';

  @override
  String get identity => 'Identity';

  @override
  String get rotateIdentityKeys => 'Rotate identity keys';

  @override
  String get rotateIdentitySubtitle =>
      'New keys and handle. Contacts that are online now receive a signed transition immediately; others receive it the next time you connect directly. The app closes afterwards.';

  @override
  String get backup => 'Backup';

  @override
  String get exportEncryptedBackup => 'Export encrypted backup';

  @override
  String get exportBackupSubtitle =>
      'Identity keys, contacts, sessions and messages, sealed with a passphrase (Argon2id + AES-256-GCM).';

  @override
  String get restoreFromBackup => 'Restore from backup';

  @override
  String get restoreBackupSubtitle =>
      'Replaces this profile. Wipe the old device afterwards: two live copies of one identity fork its sessions.';

  @override
  String get dangerZone => 'Danger zone';

  @override
  String get panicWipe => 'Panic wipe';

  @override
  String get panicWipeSubtitle =>
      'Destroys messages, contacts, sessions and identity keys. Irreversible.';

  @override
  String get securityFooter =>
      'Keys live in the Android keystore-backed secure storage. The message database is AES-256 encrypted with a random master key; with a password enabled that key is additionally wrapped with AES-256-GCM under an Argon2id-derived key (32 MiB, 2 passes).';

  @override
  String get passphraseHint => 'Passphrase (8+ characters)';

  @override
  String get confirmPassphraseHint => 'Confirm passphrase';

  @override
  String get continueAction => 'Continue';

  @override
  String get passphraseTooShortOrMismatch => 'Passphrase too short or mismatch';

  @override
  String get rotateIdentityKeysQuestion => 'Rotate identity keys?';

  @override
  String get rotateIdentityWarning =>
      'Your NyxChat ID will change. Contacts who are offline will not be able to reach you until you meet again directly.';

  @override
  String get rotate => 'Rotate';

  @override
  String rotationFailed(String error) {
    return 'Rotation failed: $error';
  }

  @override
  String get backupPassphrase => 'Backup passphrase';

  @override
  String get saveBackupDialogTitle => 'Save NyxChat backup';

  @override
  String get backupCancelled => 'Backup cancelled';

  @override
  String get backupSaved => 'Backup saved';

  @override
  String backupFailed(String error) {
    return 'Backup failed: $error';
  }

  @override
  String get replaceThisProfile => 'Replace this profile?';

  @override
  String restoreConfirmBody(String created, String name) {
    return 'Backup from $created for \"$name\". Everything on this device will be replaced and the app will close.';
  }

  @override
  String get restore => 'Restore';

  @override
  String restoreFailed(String error) {
    return 'Restore failed: $error';
  }

  @override
  String get duressDifferentFromReal => 'Different from your real password';

  @override
  String get alsoDestroyRealProfile => 'Also destroy the real profile';

  @override
  String get wipeEverythingQuestion => 'Wipe everything?';

  @override
  String get wipeEverythingBody =>
      'All messages, contacts, sessions and your identity keys will be destroyed on this device. Peers will see a key change the next time you meet.';

  @override
  String get wipe => 'Wipe';

  @override
  String get settings => 'Settings';

  @override
  String get privacy => 'Privacy';

  @override
  String get blockScreenshots => 'Block screenshots';

  @override
  String get blockScreenshotsSubtitle =>
      'Hides the app in recents and prevents screen capture';

  @override
  String get sendReadReceipts => 'Send read receipts';

  @override
  String get notifications => 'Notifications';

  @override
  String get showMessageTextInNotifications =>
      'Show message text in notifications';

  @override
  String get coverTraffic => 'Cover traffic';

  @override
  String get coverTrafficSubtitle =>
      'Random mesh packets so idle and active periods look alike';

  @override
  String get stealthMode => 'Stealth mode';

  @override
  String get stealthModeSubtitle =>
      'No advertising or scanning. Existing links stay up.';

  @override
  String get network => 'Network';

  @override
  String get localNetwork => 'Local network';

  @override
  String get active => 'Active';

  @override
  String get inactive => 'Inactive';

  @override
  String get directLinks => 'Direct links';

  @override
  String get unsupported => 'Unsupported';

  @override
  String advertisingLinks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count links',
      one: '1 link',
    );
    return 'Advertising · $_temp0';
  }

  @override
  String scanningLinks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count links',
      one: '1 link',
    );
    return 'Scanning · $_temp0';
  }

  @override
  String get bleLongRange => 'BLE long range (Coded PHY)';

  @override
  String get bleLongRangeSubtitle =>
      'Bluetooth 5 S=8 coding; lower throughput, longer reach';

  @override
  String get listeningPort => 'Listening port';

  @override
  String get globalDht => 'Global DHT';

  @override
  String get internetDelivery => 'Internet delivery';

  @override
  String get deliverThroughRelays => 'Deliver through public relays (Nostr)';

  @override
  String get deliverThroughRelaysSubtitle =>
      'Sealed envelopes under rotating tokens on public Nostr relays. No account, no server of ours. Off by default.';

  @override
  String get routeThroughTor => 'Route relays through Tor (Orbot)';

  @override
  String get routeThroughTorSubtitle =>
      'Requires Orbot running with its HTTP proxy on 127.0.0.1:8118';

  @override
  String get appLockDuressPanic => 'App lock, duress password, panic wipe';

  @override
  String get about => 'About';

  @override
  String get version => 'Version';

  @override
  String get protocol => 'Protocol';

  @override
  String protocolValue(String version) {
    return 'v$version · X25519+Kyber-768 · Double Ratchet · Sender Keys';
  }

  @override
  String get license => 'License';

  @override
  String get nyxChatIdCopied => 'NyxChat ID copied';

  @override
  String get contactCardCopied => 'Contact card copied';

  @override
  String get copyContactCard => 'Copy contact card';

  @override
  String get shareContactCardHint =>
      'Share this so others can pin and verify your keys out of band.';

  @override
  String get appearance => 'Appearance';

  @override
  String get theme => 'Theme';

  @override
  String get themeSystem => 'System';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get language => 'Language';

  @override
  String get languageSystemDefault => 'System default';
}
