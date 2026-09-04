import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_de.dart';
import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_fr.dart';
import 'app_localizations_hi.dart';
import 'app_localizations_id.dart';
import 'app_localizations_pt.dart';
import 'app_localizations_ru.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('de'),
    Locale('en'),
    Locale('es'),
    Locale('fr'),
    Locale('hi'),
    Locale('id'),
    Locale('pt'),
    Locale('ru'),
    Locale('zh'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'NyxChat'**
  String get appTitle;

  /// Notification body when message previews are disabled
  ///
  /// In en, this message translates to:
  /// **'New message'**
  String get notificationNewMessage;

  /// Android notification channel name for incoming messages
  ///
  /// In en, this message translates to:
  /// **'Messages'**
  String get notificationChannelMessages;

  /// No description provided for @notificationChannelMessagesDescription.
  ///
  /// In en, this message translates to:
  /// **'Incoming NyxChat messages'**
  String get notificationChannelMessagesDescription;

  /// Android notification channel name for the background mesh service
  ///
  /// In en, this message translates to:
  /// **'NyxChat Mesh Network'**
  String get meshChannelName;

  /// No description provided for @meshChannelDescription.
  ///
  /// In en, this message translates to:
  /// **'Keeps the decentralized mesh network running in the background.'**
  String get meshChannelDescription;

  /// No description provided for @meshNotificationInitial.
  ///
  /// In en, this message translates to:
  /// **'Mesh Network is active'**
  String get meshNotificationInitial;

  /// No description provided for @meshNotificationActive.
  ///
  /// In en, this message translates to:
  /// **'Mesh and DHT routing active'**
  String get meshNotificationActive;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @add.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// No description provided for @off.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get off;

  /// No description provided for @connect.
  ///
  /// In en, this message translates to:
  /// **'Connect'**
  String get connect;

  /// No description provided for @verified.
  ///
  /// In en, this message translates to:
  /// **'Verified'**
  String get verified;

  /// Label for a row describing how messages are encrypted
  ///
  /// In en, this message translates to:
  /// **'Messages'**
  String get messages;

  /// No description provided for @safetyNumberChangedTitle.
  ///
  /// In en, this message translates to:
  /// **'Safety number changed'**
  String get safetyNumberChangedTitle;

  /// No description provided for @safetyNumberChangedBody.
  ///
  /// In en, this message translates to:
  /// **'{name} ({id}) is presenting different identity keys than the ones you have pinned.\n\nThis happens when they reinstalled the app, or if someone is impersonating them. Verify the new safety number in person before accepting. The connection stays blocked until you decide.'**
  String safetyNumberChangedBody(String name, String id);

  /// No description provided for @keepBlocking.
  ///
  /// In en, this message translates to:
  /// **'Keep blocking'**
  String get keepBlocking;

  /// No description provided for @acceptNewKeys.
  ///
  /// In en, this message translates to:
  /// **'Accept new keys'**
  String get acceptNewKeys;

  /// No description provided for @searchConversationsHint.
  ///
  /// In en, this message translates to:
  /// **'Search conversations and messages'**
  String get searchConversationsHint;

  /// No description provided for @emergencyBroadcastTitle.
  ///
  /// In en, this message translates to:
  /// **'Emergency broadcast'**
  String get emergencyBroadcastTitle;

  /// No description provided for @noConversationsYet.
  ///
  /// In en, this message translates to:
  /// **'No conversations yet'**
  String get noConversationsYet;

  /// No description provided for @tapPlusToFindPeople.
  ///
  /// In en, this message translates to:
  /// **'Tap + to find people nearby'**
  String get tapPlusToFindPeople;

  /// No description provided for @noMatches.
  ///
  /// In en, this message translates to:
  /// **'No matches'**
  String get noMatches;

  /// No description provided for @verifySafetyNumber.
  ///
  /// In en, this message translates to:
  /// **'Verify safety number'**
  String get verifySafetyNumber;

  /// No description provided for @mute.
  ///
  /// In en, this message translates to:
  /// **'Mute'**
  String get mute;

  /// No description provided for @unmute.
  ///
  /// In en, this message translates to:
  /// **'Unmute'**
  String get unmute;

  /// No description provided for @leaveGroup.
  ///
  /// In en, this message translates to:
  /// **'Leave group'**
  String get leaveGroup;

  /// No description provided for @deleteConversation.
  ///
  /// In en, this message translates to:
  /// **'Delete conversation'**
  String get deleteConversation;

  /// No description provided for @membersCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 member} other{{count} members}}'**
  String membersCount(int count);

  /// Group status line after the user has left the group
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 member (left)} other{{count} members (left)}}'**
  String membersCountLeft(int count);

  /// No description provided for @noMessagesYet.
  ///
  /// In en, this message translates to:
  /// **'No messages yet'**
  String get noMessagesYet;

  /// No description provided for @filesNeedDirectConnection.
  ///
  /// In en, this message translates to:
  /// **'Files need a direct connection. Come within Wi-Fi range first.'**
  String get filesNeedDirectConnection;

  /// No description provided for @reply.
  ///
  /// In en, this message translates to:
  /// **'Reply'**
  String get reply;

  /// No description provided for @copyText.
  ///
  /// In en, this message translates to:
  /// **'Copy text'**
  String get copyText;

  /// No description provided for @deleteForMe.
  ///
  /// In en, this message translates to:
  /// **'Delete for me'**
  String get deleteForMe;

  /// No description provided for @disappearingMessages.
  ///
  /// In en, this message translates to:
  /// **'Disappearing messages'**
  String get disappearingMessages;

  /// No description provided for @disappear5Minutes.
  ///
  /// In en, this message translates to:
  /// **'5 minutes'**
  String get disappear5Minutes;

  /// No description provided for @disappear1Hour.
  ///
  /// In en, this message translates to:
  /// **'1 hour'**
  String get disappear1Hour;

  /// No description provided for @disappear1Day.
  ///
  /// In en, this message translates to:
  /// **'1 day'**
  String get disappear1Day;

  /// No description provided for @disappear1Week.
  ///
  /// In en, this message translates to:
  /// **'1 week'**
  String get disappear1Week;

  /// No description provided for @conversationDeleted.
  ///
  /// In en, this message translates to:
  /// **'Conversation deleted'**
  String get conversationDeleted;

  /// No description provided for @statusConnected.
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get statusConnected;

  /// No description provided for @statusReachableViaMesh.
  ///
  /// In en, this message translates to:
  /// **'Reachable via mesh'**
  String get statusReachableViaMesh;

  /// No description provided for @statusOfflineDeliverLater.
  ///
  /// In en, this message translates to:
  /// **'Offline · will deliver later'**
  String get statusOfflineDeliverLater;

  /// No description provided for @endToEndEncrypted.
  ///
  /// In en, this message translates to:
  /// **'End-to-end encrypted'**
  String get endToEndEncrypted;

  /// No description provided for @groupEncryptionHint.
  ///
  /// In en, this message translates to:
  /// **'Messages use per-sender keys; only members can read them.'**
  String get groupEncryptionHint;

  /// No description provided for @directEncryptionHint.
  ///
  /// In en, this message translates to:
  /// **'Messages are protected by a Double Ratchet session.'**
  String get directEncryptionHint;

  /// No description provided for @noLongerMemberHint.
  ///
  /// In en, this message translates to:
  /// **'You are no longer a member'**
  String get noLongerMemberHint;

  /// Placeholder text of the chat input field
  ///
  /// In en, this message translates to:
  /// **'Message'**
  String get messageHint;

  /// Transfer progress under an attachment, e.g. 40% · 1.2 MB
  ///
  /// In en, this message translates to:
  /// **'{percent}% · {size}'**
  String attachmentProgress(String percent, String size);

  /// No description provided for @sysMemberRemoved.
  ///
  /// In en, this message translates to:
  /// **'Member removed'**
  String get sysMemberRemoved;

  /// No description provided for @sysYouLeftGroup.
  ///
  /// In en, this message translates to:
  /// **'You left the group'**
  String get sysYouLeftGroup;

  /// No description provided for @sysGroupCreated.
  ///
  /// In en, this message translates to:
  /// **'Group \"{name}\" created'**
  String sysGroupCreated(String name);

  /// System message; names is a comma-separated list of display names
  ///
  /// In en, this message translates to:
  /// **'{names} added'**
  String sysMembersAdded(String names);

  /// No description provided for @sysAddedToGroupBy.
  ///
  /// In en, this message translates to:
  /// **'You were added to \"{name}\" by {who}'**
  String sysAddedToGroupBy(String name, String who);

  /// No description provided for @sysUpdatedMembers.
  ///
  /// In en, this message translates to:
  /// **'{who} updated the members'**
  String sysUpdatedMembers(String who);

  /// No description provided for @sysAMemberWasRemoved.
  ///
  /// In en, this message translates to:
  /// **'A member was removed'**
  String get sysAMemberWasRemoved;

  /// No description provided for @sysYouWereRemoved.
  ///
  /// In en, this message translates to:
  /// **'You were removed from the group'**
  String get sysYouWereRemoved;

  /// No description provided for @sysLeftGroup.
  ///
  /// In en, this message translates to:
  /// **'{who} left the group'**
  String sysLeftGroup(String who);

  /// No description provided for @sysRenamedGroup.
  ///
  /// In en, this message translates to:
  /// **'{who} renamed the group to \"{name}\"'**
  String sysRenamedGroup(String who, String name);

  /// No description provided for @sysGroupUpdated.
  ///
  /// In en, this message translates to:
  /// **'Group updated'**
  String get sysGroupUpdated;

  /// No description provided for @sysKeysRotated.
  ///
  /// In en, this message translates to:
  /// **'{name} rotated their keys (verified transition)'**
  String sysKeysRotated(String name);

  /// No description provided for @contactNotPinnedYet.
  ///
  /// In en, this message translates to:
  /// **'Contact not pinned yet'**
  String get contactNotPinnedYet;

  /// No description provided for @safetyNumber.
  ///
  /// In en, this message translates to:
  /// **'Safety number'**
  String get safetyNumber;

  /// No description provided for @safetyNumberExplanation.
  ///
  /// In en, this message translates to:
  /// **'Both of you see the same number if nobody is intercepting the connection. Compare it in person, by phone, or through another channel you trust.'**
  String get safetyNumberExplanation;

  /// No description provided for @markAsVerified.
  ///
  /// In en, this message translates to:
  /// **'Mark as verified'**
  String get markAsVerified;

  /// Button that opens a chat with the contact
  ///
  /// In en, this message translates to:
  /// **'Message'**
  String get messageAction;

  /// No description provided for @scanTheirQr.
  ///
  /// In en, this message translates to:
  /// **'Scan their QR code'**
  String get scanTheirQr;

  /// No description provided for @verifiedKeysMatch.
  ///
  /// In en, this message translates to:
  /// **'Verified: keys match this contact'**
  String get verifiedKeysMatch;

  /// No description provided for @cardBelongsToOther.
  ///
  /// In en, this message translates to:
  /// **'That card belongs to {name}, pinned separately'**
  String cardBelongsToOther(String name);

  /// No description provided for @theirFingerprint.
  ///
  /// In en, this message translates to:
  /// **'Their fingerprint'**
  String get theirFingerprint;

  /// No description provided for @yourFingerprint.
  ///
  /// In en, this message translates to:
  /// **'Your fingerprint'**
  String get yourFingerprint;

  /// No description provided for @showThemYourCard.
  ///
  /// In en, this message translates to:
  /// **'Show them your contact card'**
  String get showThemYourCard;

  /// No description provided for @contactCardContainsOnlyPublicKeys.
  ///
  /// In en, this message translates to:
  /// **'Contains only your public keys. Scanning or pasting it pins your identity on their device.'**
  String get contactCardContainsOnlyPublicKeys;

  /// No description provided for @details.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get details;

  /// No description provided for @nyxChatId.
  ///
  /// In en, this message translates to:
  /// **'NyxChat ID'**
  String get nyxChatId;

  /// No description provided for @handshake.
  ///
  /// In en, this message translates to:
  /// **'Handshake'**
  String get handshake;

  /// No description provided for @handshakeValue.
  ///
  /// In en, this message translates to:
  /// **'X25519 + ML-KEM-768 hybrid, Ed25519 signed'**
  String get handshakeValue;

  /// No description provided for @messagesValue.
  ///
  /// In en, this message translates to:
  /// **'Double Ratchet, AES-256-GCM'**
  String get messagesValue;

  /// No description provided for @firstSeen.
  ///
  /// In en, this message translates to:
  /// **'First seen'**
  String get firstSeen;

  /// No description provided for @keysChanged.
  ///
  /// In en, this message translates to:
  /// **'Keys changed'**
  String get keysChanged;

  /// No description provided for @idCopied.
  ///
  /// In en, this message translates to:
  /// **'ID copied'**
  String get idCopied;

  /// No description provided for @giveGroupAName.
  ///
  /// In en, this message translates to:
  /// **'Give the group a name'**
  String get giveGroupAName;

  /// No description provided for @selectAtLeastOneMember.
  ///
  /// In en, this message translates to:
  /// **'Select at least one member'**
  String get selectAtLeastOneMember;

  /// No description provided for @newGroup.
  ///
  /// In en, this message translates to:
  /// **'New group'**
  String get newGroup;

  /// No description provided for @create.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get create;

  /// No description provided for @groupNameHint.
  ///
  /// In en, this message translates to:
  /// **'Group name'**
  String get groupNameHint;

  /// No description provided for @descriptionOptionalHint.
  ///
  /// In en, this message translates to:
  /// **'Description (optional)'**
  String get descriptionOptionalHint;

  /// Section header above the member picker; rendered in upper case
  ///
  /// In en, this message translates to:
  /// **'Members · {count, plural, =1{1 selected} other{{count} selected}}'**
  String membersSelectedHeader(int count);

  /// No description provided for @noContactsYet.
  ///
  /// In en, this message translates to:
  /// **'No contacts yet. Connect to someone first so their keys are pinned.'**
  String get noContactsYet;

  /// No description provided for @noRecentPosition.
  ///
  /// In en, this message translates to:
  /// **'No recent position. Enter a geohash cell manually or move outdoors.'**
  String get noRecentPosition;

  /// No description provided for @invalidCell.
  ///
  /// In en, this message translates to:
  /// **'Invalid cell: {error}'**
  String invalidCell(String error);

  /// No description provided for @noNeighboursKept.
  ///
  /// In en, this message translates to:
  /// **'No neighbours right now. Your message is kept and sent to the first device that appears.'**
  String get noNeighboursKept;

  /// No description provided for @areaCellLabel.
  ///
  /// In en, this message translates to:
  /// **'Area cell (geohash)'**
  String get areaCellLabel;

  /// No description provided for @findingYourArea.
  ///
  /// In en, this message translates to:
  /// **'Finding your area...'**
  String get findingYourArea;

  /// No description provided for @meshNeighboursCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 mesh neighbour} other{{count} mesh neighbours}}'**
  String meshNeighboursCount(int count);

  /// No description provided for @directLinksCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 direct link} other{{count} direct links}}'**
  String directLinksCount(int count);

  /// area is like '~5 km'; neighbours and links are the already-pluralised strings
  ///
  /// In en, this message translates to:
  /// **'Listening in cell {cell} ({area}) · {neighbours}, {links}'**
  String listeningInCell(
    String cell,
    String area,
    String neighbours,
    String links,
  );

  /// No description provided for @emergencyEmptyHint.
  ///
  /// In en, this message translates to:
  /// **'Messages from anyone running NyxChat in this cell appear here. Your position never leaves the phone unless you include it explicitly.'**
  String get emergencyEmptyHint;

  /// No description provided for @anonymous.
  ///
  /// In en, this message translates to:
  /// **'Anonymous'**
  String get anonymous;

  /// No description provided for @positionLabel.
  ///
  /// In en, this message translates to:
  /// **'Position: {coords}'**
  String positionLabel(String coords);

  /// No description provided for @includeMyName.
  ///
  /// In en, this message translates to:
  /// **'Include my name'**
  String get includeMyName;

  /// No description provided for @includeMyPosition.
  ///
  /// In en, this message translates to:
  /// **'Include my position'**
  String get includeMyPosition;

  /// No description provided for @emergencyComposerHint.
  ///
  /// In en, this message translates to:
  /// **'What is happening? Where are you?'**
  String get emergencyComposerHint;

  /// No description provided for @joinCellFirst.
  ///
  /// In en, this message translates to:
  /// **'Join a cell first'**
  String get joinCellFirst;

  /// Emergency send button; rendered in upper case
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get send;

  /// No description provided for @presetNeedHelp.
  ///
  /// In en, this message translates to:
  /// **'I need help'**
  String get presetNeedHelp;

  /// No description provided for @presetSafe.
  ///
  /// In en, this message translates to:
  /// **'I am safe'**
  String get presetSafe;

  /// No description provided for @presetMedical.
  ///
  /// In en, this message translates to:
  /// **'Medical emergency'**
  String get presetMedical;

  /// No description provided for @addMembers.
  ///
  /// In en, this message translates to:
  /// **'Add members'**
  String get addMembers;

  /// No description provided for @groupEncryptionExplanation.
  ///
  /// In en, this message translates to:
  /// **'Group messages are encrypted with per-member sender keys distributed over pairwise Double Ratchet sessions. Keys rotate whenever someone leaves.'**
  String get groupEncryptionExplanation;

  /// No description provided for @memberYou.
  ///
  /// In en, this message translates to:
  /// **'{name} (you)'**
  String memberYou(String name);

  /// No description provided for @admin.
  ///
  /// In en, this message translates to:
  /// **'Admin'**
  String get admin;

  /// No description provided for @renameGroup.
  ///
  /// In en, this message translates to:
  /// **'Rename group'**
  String get renameGroup;

  /// No description provided for @noOtherKnownContacts.
  ///
  /// In en, this message translates to:
  /// **'No other known contacts'**
  String get noOtherKnownContacts;

  /// No description provided for @meshDiagnostics.
  ///
  /// In en, this message translates to:
  /// **'Mesh diagnostics'**
  String get meshDiagnostics;

  /// No description provided for @statBleLinks.
  ///
  /// In en, this message translates to:
  /// **'BLE links'**
  String get statBleLinks;

  /// No description provided for @statKnownRoutes.
  ///
  /// In en, this message translates to:
  /// **'Known routes'**
  String get statKnownRoutes;

  /// No description provided for @statStoredPackets.
  ///
  /// In en, this message translates to:
  /// **'Stored packets'**
  String get statStoredPackets;

  /// No description provided for @statDeliveredToMe.
  ///
  /// In en, this message translates to:
  /// **'Delivered to me'**
  String get statDeliveredToMe;

  /// No description provided for @statReceived.
  ///
  /// In en, this message translates to:
  /// **'Received'**
  String get statReceived;

  /// No description provided for @statForwarded.
  ///
  /// In en, this message translates to:
  /// **'Forwarded'**
  String get statForwarded;

  /// No description provided for @statDuplicatesDropped.
  ///
  /// In en, this message translates to:
  /// **'Duplicates dropped'**
  String get statDuplicatesDropped;

  /// No description provided for @statSeenIds.
  ///
  /// In en, this message translates to:
  /// **'Seen ids'**
  String get statSeenIds;

  /// No description provided for @linksHeader.
  ///
  /// In en, this message translates to:
  /// **'Links'**
  String get linksHeader;

  /// No description provided for @noBluetoothLinksHint.
  ///
  /// In en, this message translates to:
  /// **'No Bluetooth links. Devices within range link automatically while scanning and advertising are on.'**
  String get noBluetoothLinksHint;

  /// No description provided for @weDialled.
  ///
  /// In en, this message translates to:
  /// **'we dialled'**
  String get weDialled;

  /// No description provided for @theyDialled.
  ///
  /// In en, this message translates to:
  /// **'they dialled'**
  String get theyDialled;

  /// No description provided for @linkSubtitle.
  ///
  /// In en, this message translates to:
  /// **'{role} · MTU {mtu} · {address}'**
  String linkSubtitle(String role, int mtu, String address);

  /// No description provided for @routingTableHeader.
  ///
  /// In en, this message translates to:
  /// **'Routing table'**
  String get routingTableHeader;

  /// No description provided for @routingTableHint.
  ///
  /// In en, this message translates to:
  /// **'Routes are learned from the path recorded in every packet and from periodic beacons.'**
  String get routingTableHint;

  /// No description provided for @routeToken.
  ///
  /// In en, this message translates to:
  /// **'token {prefix}...'**
  String routeToken(String prefix);

  /// No description provided for @routeVia.
  ///
  /// In en, this message translates to:
  /// **'via relay {hop}... · {hops, plural, =1{1 hop} other{{hops} hops}}'**
  String routeVia(String hop, int hops);

  /// No description provided for @howItWorksHeader.
  ///
  /// In en, this message translates to:
  /// **'How it works'**
  String get howItWorksHeader;

  /// No description provided for @meshExplanation.
  ///
  /// In en, this message translates to:
  /// **'Packets are addressed by SHA-256 hashes and carry an end-to-end encrypted envelope. A relay stores each packet, forwards it to the learned next hop or sprays up to {copies} copies, and drops it after {hops} hops or 24 hours. Relays cannot read, alter or re-address what they carry.'**
  String meshExplanation(int copies, int hops);

  /// No description provided for @enterDisplayName.
  ///
  /// In en, this message translates to:
  /// **'Enter a display name (max 64 characters)'**
  String get enterDisplayName;

  /// No description provided for @couldNotCreateIdentity.
  ///
  /// In en, this message translates to:
  /// **'Could not create identity: {error}'**
  String couldNotCreateIdentity(String error);

  /// No description provided for @tagline.
  ///
  /// In en, this message translates to:
  /// **'peer-to-peer · encrypted · offline-capable'**
  String get tagline;

  /// No description provided for @featureE2eSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Double Ratchet with a hybrid X25519 + ML-KEM-768 handshake'**
  String get featureE2eSubtitle;

  /// No description provided for @featureOfflineTitle.
  ///
  /// In en, this message translates to:
  /// **'Works without internet'**
  String get featureOfflineTitle;

  /// No description provided for @featureOfflineSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Wi-Fi LAN and Bluetooth mesh, store-and-forward delivery'**
  String get featureOfflineSubtitle;

  /// No description provided for @featureNoServersTitle.
  ///
  /// In en, this message translates to:
  /// **'No servers, no accounts'**
  String get featureNoServersTitle;

  /// No description provided for @featureNoServersSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Your identity is a key pair that never leaves this device'**
  String get featureNoServersSubtitle;

  /// No description provided for @displayName.
  ///
  /// In en, this message translates to:
  /// **'Display name'**
  String get displayName;

  /// No description provided for @createIdentity.
  ///
  /// In en, this message translates to:
  /// **'Create identity'**
  String get createIdentity;

  /// No description provided for @keysGeneratedLocally.
  ///
  /// In en, this message translates to:
  /// **'Generates X25519, Ed25519 and ML-KEM-768 keys locally. Nothing is uploaded.'**
  String get keysGeneratedLocally;

  /// No description provided for @passwordRequired.
  ///
  /// In en, this message translates to:
  /// **'Password is required'**
  String get passwordRequired;

  /// No description provided for @atLeast8Characters.
  ///
  /// In en, this message translates to:
  /// **'At least 8 characters'**
  String get atLeast8Characters;

  /// No description provided for @passwordsDoNotMatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match'**
  String get passwordsDoNotMatch;

  /// No description provided for @enterYourPassword.
  ///
  /// In en, this message translates to:
  /// **'Enter your password'**
  String get enterYourPassword;

  /// No description provided for @allDataWiped.
  ///
  /// In en, this message translates to:
  /// **'All data has been wiped.'**
  String get allDataWiped;

  /// No description provided for @incorrectPassword.
  ///
  /// In en, this message translates to:
  /// **'Incorrect password'**
  String get incorrectPassword;

  /// No description provided for @incorrectPasswordAttemptsLeft.
  ///
  /// In en, this message translates to:
  /// **'Incorrect password · {count, plural, =1{1 attempt} other{{count} attempts}} left before wipe'**
  String incorrectPasswordAttemptsLeft(int count);

  /// No description provided for @setAppLock.
  ///
  /// In en, this message translates to:
  /// **'Set app lock'**
  String get setAppLock;

  /// No description provided for @nyxChatIsLocked.
  ///
  /// In en, this message translates to:
  /// **'NyxChat is locked'**
  String get nyxChatIsLocked;

  /// No description provided for @unlockPrompt.
  ///
  /// In en, this message translates to:
  /// **'Your database is encrypted. Enter your password to unlock.'**
  String get unlockPrompt;

  /// No description provided for @passwordSetupExplanation.
  ///
  /// In en, this message translates to:
  /// **'The database key will be wrapped with a key derived from this password using Argon2id. There is no recovery: a forgotten password means the data is gone.'**
  String get passwordSetupExplanation;

  /// No description provided for @passwordHint.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get passwordHint;

  /// No description provided for @confirmPasswordHint.
  ///
  /// In en, this message translates to:
  /// **'Confirm password'**
  String get confirmPasswordHint;

  /// No description provided for @enableLock.
  ///
  /// In en, this message translates to:
  /// **'Enable lock'**
  String get enableLock;

  /// No description provided for @unlock.
  ///
  /// In en, this message translates to:
  /// **'Unlock'**
  String get unlock;

  /// No description provided for @connectedAndAuthenticated.
  ///
  /// In en, this message translates to:
  /// **'Connected and authenticated'**
  String get connectedAndAuthenticated;

  /// No description provided for @connectionFailed.
  ///
  /// In en, this message translates to:
  /// **'Connection failed (unreachable, refused, or key mismatch)'**
  String get connectionFailed;

  /// No description provided for @pinnedAndVerified.
  ///
  /// In en, this message translates to:
  /// **'Pinned and verified {name}'**
  String pinnedAndVerified(String name);

  /// No description provided for @invalidContactCard.
  ///
  /// In en, this message translates to:
  /// **'Invalid contact card: {error}'**
  String invalidContactCard(String error);

  /// No description provided for @findPeople.
  ///
  /// In en, this message translates to:
  /// **'Find people'**
  String get findPeople;

  /// No description provided for @visibleToEveryoneNearby.
  ///
  /// In en, this message translates to:
  /// **'Visible to everyone nearby'**
  String get visibleToEveryoneNearby;

  /// No description provided for @visibleSubtitlePublic.
  ///
  /// In en, this message translates to:
  /// **'Your ID and name are broadcast so new people can find you.'**
  String get visibleSubtitlePublic;

  /// No description provided for @visibleSubtitlePrivate.
  ///
  /// In en, this message translates to:
  /// **'Private beacons: only pinned contacts can recognise you; others see random noise.'**
  String get visibleSubtitlePrivate;

  /// No description provided for @scanContactQr.
  ///
  /// In en, this message translates to:
  /// **'Scan contact QR'**
  String get scanContactQr;

  /// No description provided for @emergency.
  ///
  /// In en, this message translates to:
  /// **'Emergency'**
  String get emergency;

  /// No description provided for @nearbyOnWifi.
  ///
  /// In en, this message translates to:
  /// **'Nearby on Wi-Fi'**
  String get nearbyOnWifi;

  /// No description provided for @nobodyDiscoveredYet.
  ///
  /// In en, this message translates to:
  /// **'Nobody discovered yet. Peers on the same Wi-Fi appear here automatically.'**
  String get nobodyDiscoveredYet;

  /// No description provided for @bluetoothMesh.
  ///
  /// In en, this message translates to:
  /// **'Bluetooth mesh'**
  String get bluetoothMesh;

  /// No description provided for @bleNotAvailable.
  ///
  /// In en, this message translates to:
  /// **'Bluetooth LE is not available on this device.'**
  String get bleNotAvailable;

  /// No description provided for @bleScanningHint.
  ///
  /// In en, this message translates to:
  /// **'Scanning. Other NyxChat devices within range will link automatically.'**
  String get bleScanningHint;

  /// No description provided for @bleScanningAdvertisingHint.
  ///
  /// In en, this message translates to:
  /// **'Scanning and advertising. Other NyxChat devices within range will link automatically.'**
  String get bleScanningAdvertisingHint;

  /// No description provided for @roleCentral.
  ///
  /// In en, this message translates to:
  /// **'central'**
  String get roleCentral;

  /// No description provided for @rolePeripheral.
  ///
  /// In en, this message translates to:
  /// **'peripheral'**
  String get rolePeripheral;

  /// No description provided for @bleLinkedSubtitle.
  ///
  /// In en, this message translates to:
  /// **'linked · {role} · MTU {mtu}'**
  String bleLinkedSubtitle(String role, int mtu);

  /// No description provided for @rssiDbm.
  ///
  /// In en, this message translates to:
  /// **'{rssi} dBm'**
  String rssiDbm(int rssi);

  /// No description provided for @contacts.
  ///
  /// In en, this message translates to:
  /// **'Contacts'**
  String get contacts;

  /// No description provided for @contactsPinnedHint.
  ///
  /// In en, this message translates to:
  /// **'Keys of every peer you connect to are pinned here.'**
  String get contactsPinnedHint;

  /// No description provided for @addContactFromCard.
  ///
  /// In en, this message translates to:
  /// **'Add contact from card'**
  String get addContactFromCard;

  /// No description provided for @pasteContactCardHint.
  ///
  /// In en, this message translates to:
  /// **'Paste the text of a contact card (shown as QR in Verify). This pins and verifies their keys.'**
  String get pasteContactCardHint;

  /// No description provided for @importCard.
  ///
  /// In en, this message translates to:
  /// **'Import card'**
  String get importCard;

  /// No description provided for @manualConnection.
  ///
  /// In en, this message translates to:
  /// **'Manual connection'**
  String get manualConnection;

  /// No description provided for @ipAddressHint.
  ///
  /// In en, this message translates to:
  /// **'IP address'**
  String get ipAddressHint;

  /// No description provided for @portHint.
  ///
  /// In en, this message translates to:
  /// **'Port'**
  String get portHint;

  /// No description provided for @connecting.
  ///
  /// In en, this message translates to:
  /// **'Connecting...'**
  String get connecting;

  /// No description provided for @globalDirectory.
  ///
  /// In en, this message translates to:
  /// **'Global directory (DHT, experimental)'**
  String get globalDirectory;

  /// No description provided for @dhtHint.
  ///
  /// In en, this message translates to:
  /// **'Needs a reachable bootstrap node. Announcements are signed; the handshake still decides trust.'**
  String get dhtHint;

  /// No description provided for @dhtRunning.
  ///
  /// In en, this message translates to:
  /// **'Running · {count, plural, =1{1 node} other{{count} nodes}}'**
  String dhtRunning(int count);

  /// No description provided for @stopped.
  ///
  /// In en, this message translates to:
  /// **'Stopped'**
  String get stopped;

  /// No description provided for @stop.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get stop;

  /// No description provided for @start.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get start;

  /// No description provided for @bootstrapHint.
  ///
  /// In en, this message translates to:
  /// **'bootstrap host:port'**
  String get bootstrapHint;

  /// No description provided for @bootstrapNodeAdded.
  ///
  /// In en, this message translates to:
  /// **'Bootstrap node added'**
  String get bootstrapNodeAdded;

  /// No description provided for @lookupHint.
  ///
  /// In en, this message translates to:
  /// **'NC-... to look up'**
  String get lookupHint;

  /// No description provided for @find.
  ///
  /// In en, this message translates to:
  /// **'Find'**
  String get find;

  /// No description provided for @notFound.
  ///
  /// In en, this message translates to:
  /// **'Not found'**
  String get notFound;

  /// No description provided for @foundPeerAt.
  ///
  /// In en, this message translates to:
  /// **'Found {name} at {address}'**
  String foundPeerAt(String name, String address);

  /// No description provided for @lanOn.
  ///
  /// In en, this message translates to:
  /// **'LAN on'**
  String get lanOn;

  /// No description provided for @lanOff.
  ///
  /// In en, this message translates to:
  /// **'LAN off'**
  String get lanOff;

  /// No description provided for @bleOn.
  ///
  /// In en, this message translates to:
  /// **'BLE on'**
  String get bleOn;

  /// No description provided for @bleScan.
  ///
  /// In en, this message translates to:
  /// **'BLE scan'**
  String get bleScan;

  /// No description provided for @bleOff.
  ///
  /// In en, this message translates to:
  /// **'BLE off'**
  String get bleOff;

  /// No description provided for @linksCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 link} other{{count} links}}'**
  String linksCount(int count);

  /// No description provided for @stealth.
  ///
  /// In en, this message translates to:
  /// **'stealth'**
  String get stealth;

  /// No description provided for @visible.
  ///
  /// In en, this message translates to:
  /// **'visible'**
  String get visible;

  /// No description provided for @reachable.
  ///
  /// In en, this message translates to:
  /// **'reachable'**
  String get reachable;

  /// No description provided for @offlineQueued.
  ///
  /// In en, this message translates to:
  /// **'offline, queued delivery'**
  String get offlineQueued;

  /// No description provided for @notANyxChatContactCard.
  ///
  /// In en, this message translates to:
  /// **'Not a NyxChat contact card'**
  String get notANyxChatContactCard;

  /// No description provided for @invalidCard.
  ///
  /// In en, this message translates to:
  /// **'Invalid card: {error}'**
  String invalidCard(String error);

  /// No description provided for @scanContactCard.
  ///
  /// In en, this message translates to:
  /// **'Scan contact card'**
  String get scanContactCard;

  /// No description provided for @pointCameraHint.
  ///
  /// In en, this message translates to:
  /// **'Point the camera at the QR code on their Verify screen or Settings page.'**
  String get pointCameraHint;

  /// No description provided for @scanningPinsKeys.
  ///
  /// In en, this message translates to:
  /// **'Scanning pins their keys as verified. Nothing is sent over the network.'**
  String get scanningPinsKeys;

  /// No description provided for @security.
  ///
  /// In en, this message translates to:
  /// **'Security'**
  String get security;

  /// No description provided for @databaseLock.
  ///
  /// In en, this message translates to:
  /// **'Database lock'**
  String get databaseLock;

  /// No description provided for @requirePassword.
  ///
  /// In en, this message translates to:
  /// **'Require password'**
  String get requirePassword;

  /// No description provided for @requirePasswordSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Argon2id-wrapped database key. No recovery if forgotten.'**
  String get requirePasswordSubtitle;

  /// No description provided for @lockWhenInBackground.
  ///
  /// In en, this message translates to:
  /// **'Lock when in background'**
  String get lockWhenInBackground;

  /// No description provided for @wipeAfterFailedAttempts.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Wipe after 1 failed attempt} other{Wipe after {count} failed attempts}}'**
  String wipeAfterFailedAttempts(int count);

  /// No description provided for @duressPassword.
  ///
  /// In en, this message translates to:
  /// **'Duress password'**
  String get duressPassword;

  /// No description provided for @duressPasswordSet.
  ///
  /// In en, this message translates to:
  /// **'Duress password set'**
  String get duressPasswordSet;

  /// No description provided for @setADuressPassword.
  ///
  /// In en, this message translates to:
  /// **'Set a duress password'**
  String get setADuressPassword;

  /// No description provided for @duressOpensDecoyAndDestroys.
  ///
  /// In en, this message translates to:
  /// **'Opens a decoy profile and destroys the real one'**
  String get duressOpensDecoyAndDestroys;

  /// No description provided for @duressOpensEmptyDecoy.
  ///
  /// In en, this message translates to:
  /// **'Opens an empty decoy profile'**
  String get duressOpensEmptyDecoy;

  /// No description provided for @duressExplanation.
  ///
  /// In en, this message translates to:
  /// **'Entering it at the lock screen opens an empty decoy profile'**
  String get duressExplanation;

  /// No description provided for @removeDuressPassword.
  ///
  /// In en, this message translates to:
  /// **'Remove duress password'**
  String get removeDuressPassword;

  /// No description provided for @identity.
  ///
  /// In en, this message translates to:
  /// **'Identity'**
  String get identity;

  /// No description provided for @rotateIdentityKeys.
  ///
  /// In en, this message translates to:
  /// **'Rotate identity keys'**
  String get rotateIdentityKeys;

  /// No description provided for @rotateIdentitySubtitle.
  ///
  /// In en, this message translates to:
  /// **'New keys and handle. Contacts that are online now receive a signed transition immediately; others receive it the next time you connect directly. The app closes afterwards.'**
  String get rotateIdentitySubtitle;

  /// No description provided for @backup.
  ///
  /// In en, this message translates to:
  /// **'Backup'**
  String get backup;

  /// No description provided for @exportEncryptedBackup.
  ///
  /// In en, this message translates to:
  /// **'Export encrypted backup'**
  String get exportEncryptedBackup;

  /// No description provided for @exportBackupSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Identity keys, contacts, sessions and messages, sealed with a passphrase (Argon2id + AES-256-GCM).'**
  String get exportBackupSubtitle;

  /// No description provided for @restoreFromBackup.
  ///
  /// In en, this message translates to:
  /// **'Restore from backup'**
  String get restoreFromBackup;

  /// No description provided for @restoreBackupSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Replaces this profile. Wipe the old device afterwards: two live copies of one identity fork its sessions.'**
  String get restoreBackupSubtitle;

  /// No description provided for @dangerZone.
  ///
  /// In en, this message translates to:
  /// **'Danger zone'**
  String get dangerZone;

  /// No description provided for @panicWipe.
  ///
  /// In en, this message translates to:
  /// **'Panic wipe'**
  String get panicWipe;

  /// No description provided for @panicWipeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Destroys messages, contacts, sessions and identity keys. Irreversible.'**
  String get panicWipeSubtitle;

  /// No description provided for @securityFooter.
  ///
  /// In en, this message translates to:
  /// **'Keys live in the Android keystore-backed secure storage. The message database is AES-256 encrypted with a random master key; with a password enabled that key is additionally wrapped with AES-256-GCM under an Argon2id-derived key (32 MiB, 2 passes).'**
  String get securityFooter;

  /// No description provided for @passphraseHint.
  ///
  /// In en, this message translates to:
  /// **'Passphrase (8+ characters)'**
  String get passphraseHint;

  /// No description provided for @confirmPassphraseHint.
  ///
  /// In en, this message translates to:
  /// **'Confirm passphrase'**
  String get confirmPassphraseHint;

  /// No description provided for @continueAction.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueAction;

  /// No description provided for @passphraseTooShortOrMismatch.
  ///
  /// In en, this message translates to:
  /// **'Passphrase too short or mismatch'**
  String get passphraseTooShortOrMismatch;

  /// No description provided for @rotateIdentityKeysQuestion.
  ///
  /// In en, this message translates to:
  /// **'Rotate identity keys?'**
  String get rotateIdentityKeysQuestion;

  /// No description provided for @rotateIdentityWarning.
  ///
  /// In en, this message translates to:
  /// **'Your NyxChat ID will change. Contacts who are offline will not be able to reach you until you meet again directly.'**
  String get rotateIdentityWarning;

  /// No description provided for @rotate.
  ///
  /// In en, this message translates to:
  /// **'Rotate'**
  String get rotate;

  /// No description provided for @rotationFailed.
  ///
  /// In en, this message translates to:
  /// **'Rotation failed: {error}'**
  String rotationFailed(String error);

  /// No description provided for @backupPassphrase.
  ///
  /// In en, this message translates to:
  /// **'Backup passphrase'**
  String get backupPassphrase;

  /// No description provided for @saveBackupDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Save NyxChat backup'**
  String get saveBackupDialogTitle;

  /// No description provided for @backupCancelled.
  ///
  /// In en, this message translates to:
  /// **'Backup cancelled'**
  String get backupCancelled;

  /// No description provided for @backupSaved.
  ///
  /// In en, this message translates to:
  /// **'Backup saved'**
  String get backupSaved;

  /// No description provided for @backupFailed.
  ///
  /// In en, this message translates to:
  /// **'Backup failed: {error}'**
  String backupFailed(String error);

  /// No description provided for @replaceThisProfile.
  ///
  /// In en, this message translates to:
  /// **'Replace this profile?'**
  String get replaceThisProfile;

  /// No description provided for @restoreConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'Backup from {created} for \"{name}\". Everything on this device will be replaced and the app will close.'**
  String restoreConfirmBody(String created, String name);

  /// No description provided for @restore.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get restore;

  /// No description provided for @restoreFailed.
  ///
  /// In en, this message translates to:
  /// **'Restore failed: {error}'**
  String restoreFailed(String error);

  /// No description provided for @duressDifferentFromReal.
  ///
  /// In en, this message translates to:
  /// **'Different from your real password'**
  String get duressDifferentFromReal;

  /// No description provided for @alsoDestroyRealProfile.
  ///
  /// In en, this message translates to:
  /// **'Also destroy the real profile'**
  String get alsoDestroyRealProfile;

  /// No description provided for @wipeEverythingQuestion.
  ///
  /// In en, this message translates to:
  /// **'Wipe everything?'**
  String get wipeEverythingQuestion;

  /// No description provided for @wipeEverythingBody.
  ///
  /// In en, this message translates to:
  /// **'All messages, contacts, sessions and your identity keys will be destroyed on this device. Peers will see a key change the next time you meet.'**
  String get wipeEverythingBody;

  /// No description provided for @wipe.
  ///
  /// In en, this message translates to:
  /// **'Wipe'**
  String get wipe;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @privacy.
  ///
  /// In en, this message translates to:
  /// **'Privacy'**
  String get privacy;

  /// No description provided for @blockScreenshots.
  ///
  /// In en, this message translates to:
  /// **'Block screenshots'**
  String get blockScreenshots;

  /// No description provided for @blockScreenshotsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Hides the app in recents and prevents screen capture'**
  String get blockScreenshotsSubtitle;

  /// No description provided for @sendReadReceipts.
  ///
  /// In en, this message translates to:
  /// **'Send read receipts'**
  String get sendReadReceipts;

  /// No description provided for @notifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notifications;

  /// No description provided for @showMessageTextInNotifications.
  ///
  /// In en, this message translates to:
  /// **'Show message text in notifications'**
  String get showMessageTextInNotifications;

  /// No description provided for @coverTraffic.
  ///
  /// In en, this message translates to:
  /// **'Cover traffic'**
  String get coverTraffic;

  /// No description provided for @coverTrafficSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Random mesh packets so idle and active periods look alike'**
  String get coverTrafficSubtitle;

  /// No description provided for @stealthMode.
  ///
  /// In en, this message translates to:
  /// **'Stealth mode'**
  String get stealthMode;

  /// No description provided for @stealthModeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'No advertising or scanning. Existing links stay up.'**
  String get stealthModeSubtitle;

  /// No description provided for @network.
  ///
  /// In en, this message translates to:
  /// **'Network'**
  String get network;

  /// No description provided for @localNetwork.
  ///
  /// In en, this message translates to:
  /// **'Local network'**
  String get localNetwork;

  /// No description provided for @active.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get active;

  /// No description provided for @inactive.
  ///
  /// In en, this message translates to:
  /// **'Inactive'**
  String get inactive;

  /// No description provided for @directLinks.
  ///
  /// In en, this message translates to:
  /// **'Direct links'**
  String get directLinks;

  /// No description provided for @unsupported.
  ///
  /// In en, this message translates to:
  /// **'Unsupported'**
  String get unsupported;

  /// No description provided for @advertisingLinks.
  ///
  /// In en, this message translates to:
  /// **'Advertising · {count, plural, =1{1 link} other{{count} links}}'**
  String advertisingLinks(int count);

  /// No description provided for @scanningLinks.
  ///
  /// In en, this message translates to:
  /// **'Scanning · {count, plural, =1{1 link} other{{count} links}}'**
  String scanningLinks(int count);

  /// No description provided for @bleLongRange.
  ///
  /// In en, this message translates to:
  /// **'BLE long range (Coded PHY)'**
  String get bleLongRange;

  /// No description provided for @bleLongRangeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Bluetooth 5 S=8 coding; lower throughput, longer reach'**
  String get bleLongRangeSubtitle;

  /// No description provided for @listeningPort.
  ///
  /// In en, this message translates to:
  /// **'Listening port'**
  String get listeningPort;

  /// No description provided for @globalDht.
  ///
  /// In en, this message translates to:
  /// **'Global DHT'**
  String get globalDht;

  /// No description provided for @internetDelivery.
  ///
  /// In en, this message translates to:
  /// **'Internet delivery'**
  String get internetDelivery;

  /// No description provided for @deliverThroughRelays.
  ///
  /// In en, this message translates to:
  /// **'Deliver through public relays (Nostr)'**
  String get deliverThroughRelays;

  /// No description provided for @deliverThroughRelaysSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Sealed envelopes under rotating tokens on public Nostr relays. No account, no server of ours. Off by default.'**
  String get deliverThroughRelaysSubtitle;

  /// No description provided for @routeThroughTor.
  ///
  /// In en, this message translates to:
  /// **'Route relays through Tor (Orbot)'**
  String get routeThroughTor;

  /// No description provided for @routeThroughTorSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Requires Orbot running with its HTTP proxy on 127.0.0.1:8118'**
  String get routeThroughTorSubtitle;

  /// No description provided for @appLockDuressPanic.
  ///
  /// In en, this message translates to:
  /// **'App lock, duress password, panic wipe'**
  String get appLockDuressPanic;

  /// No description provided for @about.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get about;

  /// No description provided for @version.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get version;

  /// No description provided for @protocol.
  ///
  /// In en, this message translates to:
  /// **'Protocol'**
  String get protocol;

  /// No description provided for @protocolValue.
  ///
  /// In en, this message translates to:
  /// **'v{version} · X25519+ML-KEM-768 · Double Ratchet · Sender Keys'**
  String protocolValue(String version);

  /// No description provided for @license.
  ///
  /// In en, this message translates to:
  /// **'License'**
  String get license;

  /// No description provided for @nyxChatIdCopied.
  ///
  /// In en, this message translates to:
  /// **'NyxChat ID copied'**
  String get nyxChatIdCopied;

  /// No description provided for @contactCardCopied.
  ///
  /// In en, this message translates to:
  /// **'Contact card copied'**
  String get contactCardCopied;

  /// No description provided for @copyContactCard.
  ///
  /// In en, this message translates to:
  /// **'Copy contact card'**
  String get copyContactCard;

  /// No description provided for @shareContactCardHint.
  ///
  /// In en, this message translates to:
  /// **'Share this so others can pin and verify your keys out of band.'**
  String get shareContactCardHint;

  /// No description provided for @appearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appearance;

  /// No description provided for @theme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get theme;

  /// No description provided for @themeSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get themeSystem;

  /// No description provided for @themeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @languageSystemDefault.
  ///
  /// In en, this message translates to:
  /// **'System default'**
  String get languageSystemDefault;

  /// No description provided for @wifiAware.
  ///
  /// In en, this message translates to:
  /// **'Wi-Fi Aware'**
  String get wifiAware;

  /// No description provided for @useWifiAware.
  ///
  /// In en, this message translates to:
  /// **'Use Wi-Fi Aware'**
  String get useWifiAware;

  /// No description provided for @useWifiAwareSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Neighbour links without an access point (Android 8+). Same rotating beacon as Bluetooth.'**
  String get useWifiAwareSubtitle;

  /// No description provided for @offlineSessions.
  ///
  /// In en, this message translates to:
  /// **'Offline sessions'**
  String get offlineSessions;

  /// No description provided for @pqReady.
  ///
  /// In en, this message translates to:
  /// **'Post-quantum forward secrecy ready ({count} one-time prekeys)'**
  String pqReady(int count);

  /// No description provided for @pqPending.
  ///
  /// In en, this message translates to:
  /// **'Post-quantum forward secrecy pending next meeting'**
  String get pqPending;

  /// No description provided for @voiceMessage.
  ///
  /// In en, this message translates to:
  /// **'Voice message'**
  String get voiceMessage;

  /// No description provided for @photo.
  ///
  /// In en, this message translates to:
  /// **'Photo'**
  String get photo;

  /// No description provided for @holdToRecord.
  ///
  /// In en, this message translates to:
  /// **'Hold the microphone to record a voice message'**
  String get holdToRecord;

  /// No description provided for @slideToCancel.
  ///
  /// In en, this message translates to:
  /// **'Slide to cancel'**
  String get slideToCancel;

  /// No description provided for @releaseToCancel.
  ///
  /// In en, this message translates to:
  /// **'Release to cancel'**
  String get releaseToCancel;

  /// No description provided for @recordingUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Voice recording is not available on this device'**
  String get recordingUnavailable;

  /// No description provided for @microphoneDenied.
  ///
  /// In en, this message translates to:
  /// **'Microphone access is needed to record voice messages'**
  String get microphoneDenied;

  /// No description provided for @recordingFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not start recording'**
  String get recordingFailed;

  /// No description provided for @playbackUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Voice playback is not available on this device'**
  String get playbackUnavailable;

  /// No description provided for @playbackFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not play this voice message'**
  String get playbackFailed;

  /// No description provided for @voiceNeedsCarrier.
  ///
  /// In en, this message translates to:
  /// **'Voice notes need a direct connection or a mesh path'**
  String get voiceNeedsCarrier;

  /// No description provided for @imageUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Image not available'**
  String get imageUnavailable;

  /// No description provided for @receiving.
  ///
  /// In en, this message translates to:
  /// **'Receiving'**
  String get receiving;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>[
    'ar',
    'de',
    'en',
    'es',
    'fr',
    'hi',
    'id',
    'pt',
    'ru',
    'zh',
  ].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
    case 'fr':
      return AppLocalizationsFr();
    case 'hi':
      return AppLocalizationsHi();
    case 'id':
      return AppLocalizationsId();
    case 'pt':
      return AppLocalizationsPt();
    case 'ru':
      return AppLocalizationsRu();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
