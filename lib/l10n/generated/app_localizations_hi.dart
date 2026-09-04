// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Hindi (`hi`).
class AppLocalizationsHi extends AppLocalizations {
  AppLocalizationsHi([String locale = 'hi']) : super(locale);

  @override
  String get appTitle => 'NyxChat';

  @override
  String get notificationNewMessage => 'नया संदेश';

  @override
  String get notificationChannelMessages => 'संदेश';

  @override
  String get notificationChannelMessagesDescription => 'आने वाले NyxChat संदेश';

  @override
  String get meshChannelName => 'NyxChat मेश नेटवर्क';

  @override
  String get meshChannelDescription =>
      'विकेंद्रीकृत मेश नेटवर्क को बैकग्राउंड में चालू रखता है।';

  @override
  String get meshNotificationInitial => 'मेश नेटवर्क सक्रिय है';

  @override
  String get meshNotificationActive => 'मेश और DHT रूटिंग सक्रिय';

  @override
  String get cancel => 'रद्द करें';

  @override
  String get save => 'सेव करें';

  @override
  String get add => 'जोड़ें';

  @override
  String get off => 'बंद';

  @override
  String get connect => 'कनेक्ट करें';

  @override
  String get verified => 'सत्यापित';

  @override
  String get messages => 'संदेश';

  @override
  String get safetyNumberChangedTitle => 'सुरक्षा नंबर बदल गया';

  @override
  String safetyNumberChangedBody(String name, String id) {
    return '$name ($id) आपके द्वारा पिन की गई पहचान कुंजियों से अलग कुंजियाँ दिखा रहा है।\n\nऐसा तब होता है जब उन्होंने ऐप दोबारा इंस्टॉल किया हो, या कोई उनका रूप धरकर बात कर रहा हो। स्वीकार करने से पहले नया सुरक्षा नंबर आमने-सामने मिलकर सत्यापित करें। जब तक आप फ़ैसला नहीं लेते, कनेक्शन अवरुद्ध रहेगा।';
  }

  @override
  String get keepBlocking => 'अवरुद्ध रखें';

  @override
  String get acceptNewKeys => 'नई कुंजियाँ स्वीकार करें';

  @override
  String get searchConversationsHint => 'बातचीत और संदेश खोजें';

  @override
  String get emergencyBroadcastTitle => 'आपातकालीन प्रसारण';

  @override
  String get noConversationsYet => 'अभी कोई बातचीत नहीं';

  @override
  String get tapPlusToFindPeople => 'आस-पास के लोग खोजने के लिए + पर टैप करें';

  @override
  String get noMatches => 'कोई मेल नहीं मिला';

  @override
  String get verifySafetyNumber => 'सुरक्षा नंबर सत्यापित करें';

  @override
  String get mute => 'म्यूट करें';

  @override
  String get unmute => 'अनम्यूट करें';

  @override
  String get leaveGroup => 'ग्रुप छोड़ें';

  @override
  String get deleteConversation => 'बातचीत हटाएँ';

  @override
  String membersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count सदस्य',
      one: '1 सदस्य',
    );
    return '$_temp0';
  }

  @override
  String membersCountLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count सदस्य (ग्रुप छोड़ा)',
      one: '1 सदस्य (ग्रुप छोड़ा)',
    );
    return '$_temp0';
  }

  @override
  String get noMessagesYet => 'अभी कोई संदेश नहीं';

  @override
  String get filesNeedDirectConnection =>
      'फ़ाइलों के लिए सीधा कनेक्शन ज़रूरी है। पहले Wi-Fi की रेंज में आएँ।';

  @override
  String get reply => 'जवाब दें';

  @override
  String get copyText => 'टेक्स्ट कॉपी करें';

  @override
  String get deleteForMe => 'मेरे लिए हटाएँ';

  @override
  String get disappearingMessages => 'गायब होने वाले संदेश';

  @override
  String get disappear5Minutes => '5 मिनट';

  @override
  String get disappear1Hour => '1 घंटा';

  @override
  String get disappear1Day => '1 दिन';

  @override
  String get disappear1Week => '1 सप्ताह';

  @override
  String get conversationDeleted => 'बातचीत हटा दी गई';

  @override
  String get statusConnected => 'कनेक्टेड';

  @override
  String get statusReachableViaMesh => 'मेश के ज़रिए पहुँच योग्य';

  @override
  String get statusOfflineDeliverLater => 'ऑफ़लाइन · बाद में डिलीवर होगा';

  @override
  String get endToEndEncrypted => 'एंड-टू-एंड एन्क्रिप्टेड';

  @override
  String get groupEncryptionHint =>
      'संदेश प्रति-प्रेषक कुंजियों से सुरक्षित हैं; केवल सदस्य ही इन्हें पढ़ सकते हैं।';

  @override
  String get directEncryptionHint =>
      'संदेश Double Ratchet सत्र से सुरक्षित हैं।';

  @override
  String get noLongerMemberHint => 'अब आप सदस्य नहीं हैं';

  @override
  String get messageHint => 'संदेश';

  @override
  String attachmentProgress(String percent, String size) {
    return '$percent% · $size';
  }

  @override
  String get sysMemberRemoved => 'सदस्य हटाया गया';

  @override
  String get sysYouLeftGroup => 'आपने ग्रुप छोड़ दिया';

  @override
  String sysGroupCreated(String name) {
    return 'ग्रुप \"$name\" बनाया गया';
  }

  @override
  String sysMembersAdded(String names) {
    return '$names को जोड़ा गया';
  }

  @override
  String sysAddedToGroupBy(String name, String who) {
    return '$who ने आपको \"$name\" में जोड़ा';
  }

  @override
  String sysUpdatedMembers(String who) {
    return '$who ने सदस्यों को अपडेट किया';
  }

  @override
  String get sysAMemberWasRemoved => 'एक सदस्य को हटाया गया';

  @override
  String get sysYouWereRemoved => 'आपको ग्रुप से हटा दिया गया';

  @override
  String sysLeftGroup(String who) {
    return '$who ने ग्रुप छोड़ दिया';
  }

  @override
  String sysRenamedGroup(String who, String name) {
    return '$who ने ग्रुप का नाम बदलकर \"$name\" रखा';
  }

  @override
  String get sysGroupUpdated => 'ग्रुप अपडेट किया गया';

  @override
  String sysKeysRotated(String name) {
    return '$name ने अपनी कुंजियाँ बदलीं (सत्यापित परिवर्तन)';
  }

  @override
  String get contactNotPinnedYet => 'संपर्क अभी पिन नहीं किया गया';

  @override
  String get safetyNumber => 'सुरक्षा नंबर';

  @override
  String get safetyNumberExplanation =>
      'अगर कोई कनेक्शन को बीच में नहीं पकड़ रहा है, तो आप दोनों को एक ही नंबर दिखेगा। इसकी तुलना आमने-सामने, फ़ोन पर, या किसी अन्य भरोसेमंद माध्यम से करें।';

  @override
  String get markAsVerified => 'सत्यापित के रूप में चिह्नित करें';

  @override
  String get messageAction => 'संदेश भेजें';

  @override
  String get scanTheirQr => 'उनका QR कोड स्कैन करें';

  @override
  String get verifiedKeysMatch =>
      'सत्यापित: कुंजियाँ इस संपर्क से मेल खाती हैं';

  @override
  String cardBelongsToOther(String name) {
    return 'वह कार्ड $name का है, उसे अलग से पिन किया गया';
  }

  @override
  String get theirFingerprint => 'उनका फ़िंगरप्रिंट';

  @override
  String get yourFingerprint => 'आपका फ़िंगरप्रिंट';

  @override
  String get showThemYourCard => 'उन्हें अपना संपर्क कार्ड दिखाएँ';

  @override
  String get contactCardContainsOnlyPublicKeys =>
      'इसमें केवल आपकी सार्वजनिक कुंजियाँ हैं। इसे स्कैन या पेस्ट करने पर आपकी पहचान उनके डिवाइस पर पिन हो जाती है।';

  @override
  String get details => 'विवरण';

  @override
  String get nyxChatId => 'NyxChat ID';

  @override
  String get handshake => 'हैंडशेक';

  @override
  String get handshakeValue =>
      'X25519 + ML-KEM-768 हाइब्रिड, Ed25519 हस्ताक्षरित';

  @override
  String get messagesValue => 'Double Ratchet, AES-256-GCM';

  @override
  String get firstSeen => 'पहली बार देखा गया';

  @override
  String get keysChanged => 'कुंजियाँ बदलीं';

  @override
  String get idCopied => 'ID कॉपी की गई';

  @override
  String get giveGroupAName => 'ग्रुप को एक नाम दें';

  @override
  String get selectAtLeastOneMember => 'कम से कम एक सदस्य चुनें';

  @override
  String get newGroup => 'नया ग्रुप';

  @override
  String get create => 'बनाएँ';

  @override
  String get groupNameHint => 'ग्रुप का नाम';

  @override
  String get descriptionOptionalHint => 'विवरण (वैकल्पिक)';

  @override
  String membersSelectedHeader(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count चुने गए',
      one: '1 चुना गया',
    );
    return 'सदस्य · $_temp0';
  }

  @override
  String get noContactsYet =>
      'अभी कोई संपर्क नहीं। पहले किसी से कनेक्ट करें ताकि उनकी कुंजियाँ पिन हो जाएँ।';

  @override
  String get noRecentPosition =>
      'हाल की कोई स्थिति नहीं। geohash सेल मैन्युअल रूप से दर्ज करें या खुले में जाएँ।';

  @override
  String invalidCell(String error) {
    return 'अमान्य सेल: $error';
  }

  @override
  String get noNeighboursKept =>
      'अभी कोई पड़ोसी डिवाइस नहीं। आपका संदेश सुरक्षित रखा गया है और सबसे पहले दिखने वाले डिवाइस को भेजा जाएगा।';

  @override
  String get areaCellLabel => 'क्षेत्र सेल (geohash)';

  @override
  String get findingYourArea => 'आपका क्षेत्र खोजा जा रहा है...';

  @override
  String meshNeighboursCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count मेश पड़ोसी',
      one: '1 मेश पड़ोसी',
    );
    return '$_temp0';
  }

  @override
  String directLinksCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count सीधे लिंक',
      one: '1 सीधा लिंक',
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
    return 'सेल $cell ($area) में सुन रहा है · $neighbours, $links';
  }

  @override
  String get emergencyEmptyHint =>
      'इस सेल में NyxChat चलाने वाले किसी भी व्यक्ति के संदेश यहाँ दिखेंगे। जब तक आप स्पष्ट रूप से शामिल न करें, आपकी स्थिति फ़ोन से बाहर नहीं जाती।';

  @override
  String get anonymous => 'अज्ञात';

  @override
  String positionLabel(String coords) {
    return 'स्थिति: $coords';
  }

  @override
  String get includeMyName => 'मेरा नाम शामिल करें';

  @override
  String get includeMyPosition => 'मेरी स्थिति शामिल करें';

  @override
  String get emergencyComposerHint => 'क्या हो रहा है? आप कहाँ हैं?';

  @override
  String get joinCellFirst => 'पहले किसी सेल में शामिल हों';

  @override
  String get send => 'भेजें';

  @override
  String get presetNeedHelp => 'मुझे मदद चाहिए';

  @override
  String get presetSafe => 'मैं सुरक्षित हूँ';

  @override
  String get presetMedical => 'चिकित्सा आपातकाल';

  @override
  String get addMembers => 'सदस्य जोड़ें';

  @override
  String get groupEncryptionExplanation =>
      'ग्रुप संदेश प्रति-सदस्य प्रेषक कुंजियों से एन्क्रिप्ट किए जाते हैं, जो जोड़ीवार Double Ratchet सत्रों के ज़रिए वितरित होती हैं। जब भी कोई ग्रुप छोड़ता है, कुंजियाँ बदल दी जाती हैं।';

  @override
  String memberYou(String name) {
    return '$name (आप)';
  }

  @override
  String get admin => 'एडमिन';

  @override
  String get renameGroup => 'ग्रुप का नाम बदलें';

  @override
  String get noOtherKnownContacts => 'कोई अन्य ज्ञात संपर्क नहीं';

  @override
  String get meshDiagnostics => 'मेश डायग्नोस्टिक्स';

  @override
  String get statBleLinks => 'BLE लिंक';

  @override
  String get statKnownRoutes => 'ज्ञात रूट';

  @override
  String get statStoredPackets => 'संग्रहीत पैकेट';

  @override
  String get statDeliveredToMe => 'मुझे डिलीवर हुए';

  @override
  String get statReceived => 'प्राप्त';

  @override
  String get statForwarded => 'अग्रेषित';

  @override
  String get statDuplicatesDropped => 'डुप्लिकेट हटाए गए';

  @override
  String get statSeenIds => 'देखी गई ID';

  @override
  String get linksHeader => 'लिंक';

  @override
  String get noBluetoothLinksHint =>
      'कोई ब्लूटूथ लिंक नहीं। स्कैनिंग और प्रसारण चालू रहने पर रेंज में मौजूद डिवाइस अपने-आप लिंक हो जाते हैं।';

  @override
  String get weDialled => 'हमने डायल किया';

  @override
  String get theyDialled => 'उन्होंने डायल किया';

  @override
  String linkSubtitle(String role, int mtu, String address) {
    return '$role · MTU $mtu · $address';
  }

  @override
  String get routingTableHeader => 'रूटिंग टेबल';

  @override
  String get routingTableHint =>
      'रूट हर पैकेट में दर्ज पथ और समय-समय पर भेजे जाने वाले बीकन से सीखे जाते हैं।';

  @override
  String routeToken(String prefix) {
    return 'टोकन $prefix...';
  }

  @override
  String routeVia(String hop, int hops) {
    String _temp0 = intl.Intl.pluralLogic(
      hops,
      locale: localeName,
      other: '$hops हॉप',
      one: '1 हॉप',
    );
    return 'रिले $hop... के ज़रिए · $_temp0';
  }

  @override
  String get howItWorksHeader => 'यह कैसे काम करता है';

  @override
  String meshExplanation(int copies, int hops) {
    return 'पैकेट SHA-256 हैश से संबोधित होते हैं और एक एंड-टू-एंड एन्क्रिप्टेड लिफ़ाफ़ा ले जाते हैं। रिले हर पैकेट को संग्रहीत करता है, उसे सीखे गए अगले हॉप तक अग्रेषित करता है या अधिकतम $copies प्रतियाँ फैलाता है, और $hops हॉप या 24 घंटे के बाद उसे हटा देता है। रिले जो ले जाते हैं, उसे न पढ़ सकते हैं, न बदल सकते हैं, न किसी और को संबोधित कर सकते हैं।';
  }

  @override
  String get enterDisplayName => 'एक प्रदर्शित नाम दर्ज करें (अधिकतम 64 अक्षर)';

  @override
  String couldNotCreateIdentity(String error) {
    return 'पहचान नहीं बनाई जा सकी: $error';
  }

  @override
  String get tagline => 'पीयर-टू-पीयर · एन्क्रिप्टेड · ऑफ़लाइन में भी सक्षम';

  @override
  String get featureE2eSubtitle =>
      'हाइब्रिड X25519 + ML-KEM-768 हैंडशेक के साथ Double Ratchet';

  @override
  String get featureOfflineTitle => 'इंटरनेट के बिना काम करता है';

  @override
  String get featureOfflineSubtitle =>
      'Wi-Fi LAN और ब्लूटूथ मेश, स्टोर-एंड-फ़ॉरवर्ड डिलीवरी';

  @override
  String get featureNoServersTitle => 'न सर्वर, न खाते';

  @override
  String get featureNoServersSubtitle =>
      'आपकी पहचान एक कुंजी युग्म है जो कभी इस डिवाइस से बाहर नहीं जाती';

  @override
  String get displayName => 'प्रदर्शित नाम';

  @override
  String get createIdentity => 'पहचान बनाएँ';

  @override
  String get keysGeneratedLocally =>
      'X25519, Ed25519 और ML-KEM-768 कुंजियाँ स्थानीय रूप से बनाई जाती हैं। कुछ भी अपलोड नहीं होता।';

  @override
  String get passwordRequired => 'पासवर्ड ज़रूरी है';

  @override
  String get atLeast8Characters => 'कम से कम 8 अक्षर';

  @override
  String get passwordsDoNotMatch => 'पासवर्ड मेल नहीं खाते';

  @override
  String get enterYourPassword => 'अपना पासवर्ड दर्ज करें';

  @override
  String get allDataWiped => 'सारा डेटा मिटा दिया गया है।';

  @override
  String get incorrectPassword => 'गलत पासवर्ड';

  @override
  String incorrectPasswordAttemptsLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count प्रयास',
      one: '1 प्रयास',
    );
    return 'गलत पासवर्ड · मिटाने से पहले $_temp0 बाकी';
  }

  @override
  String get setAppLock => 'ऐप लॉक सेट करें';

  @override
  String get nyxChatIsLocked => 'NyxChat लॉक है';

  @override
  String get unlockPrompt =>
      'आपका डेटाबेस एन्क्रिप्टेड है। अनलॉक करने के लिए अपना पासवर्ड दर्ज करें।';

  @override
  String get passwordSetupExplanation =>
      'डेटाबेस कुंजी को इस पासवर्ड से Argon2id द्वारा बनाई गई कुंजी से रैप किया जाएगा। कोई रिकवरी नहीं है: पासवर्ड भूल जाने का मतलब है डेटा हमेशा के लिए खो जाना।';

  @override
  String get passwordHint => 'पासवर्ड';

  @override
  String get confirmPasswordHint => 'पासवर्ड की पुष्टि करें';

  @override
  String get enableLock => 'लॉक चालू करें';

  @override
  String get unlock => 'अनलॉक करें';

  @override
  String get connectedAndAuthenticated => 'कनेक्टेड और प्रमाणित';

  @override
  String get connectionFailed =>
      'कनेक्शन विफल (पहुँच से बाहर, अस्वीकृत, या कुंजी मेल नहीं खाती)';

  @override
  String pinnedAndVerified(String name) {
    return '$name को पिन और सत्यापित किया गया';
  }

  @override
  String invalidContactCard(String error) {
    return 'अमान्य संपर्क कार्ड: $error';
  }

  @override
  String get findPeople => 'लोग खोजें';

  @override
  String get visibleToEveryoneNearby => 'आस-पास के सभी लोगों को दिखाई दें';

  @override
  String get visibleSubtitlePublic =>
      'आपकी ID और नाम प्रसारित होते हैं ताकि नए लोग आपको ढूँढ सकें।';

  @override
  String get visibleSubtitlePrivate =>
      'निजी बीकन: केवल पिन किए गए संपर्क ही आपको पहचान सकते हैं; बाकी को बेतरतीब शोर दिखता है।';

  @override
  String get scanContactQr => 'संपर्क QR स्कैन करें';

  @override
  String get emergency => 'आपातकाल';

  @override
  String get nearbyOnWifi => 'Wi-Fi पर आस-पास';

  @override
  String get nobodyDiscoveredYet =>
      'अभी कोई नहीं मिला। एक ही Wi-Fi पर मौजूद पीयर यहाँ अपने-आप दिखेंगे।';

  @override
  String get bluetoothMesh => 'ब्लूटूथ मेश';

  @override
  String get bleNotAvailable => 'इस डिवाइस पर Bluetooth LE उपलब्ध नहीं है।';

  @override
  String get bleScanningHint =>
      'स्कैन हो रहा है। रेंज में मौजूद अन्य NyxChat डिवाइस अपने-आप लिंक हो जाएँगे।';

  @override
  String get bleScanningAdvertisingHint =>
      'स्कैनिंग और प्रसारण चालू। रेंज में मौजूद अन्य NyxChat डिवाइस अपने-आप लिंक हो जाएँगे।';

  @override
  String get roleCentral => 'सेंट्रल';

  @override
  String get rolePeripheral => 'पेरिफ़ेरल';

  @override
  String bleLinkedSubtitle(String role, int mtu) {
    return 'लिंक्ड · $role · MTU $mtu';
  }

  @override
  String rssiDbm(int rssi) {
    return '$rssi dBm';
  }

  @override
  String get contacts => 'संपर्क';

  @override
  String get contactsPinnedHint =>
      'आप जिस भी पीयर से कनेक्ट करते हैं, उसकी कुंजियाँ यहाँ पिन होती हैं।';

  @override
  String get addContactFromCard => 'कार्ड से संपर्क जोड़ें';

  @override
  String get pasteContactCardHint =>
      'संपर्क कार्ड का टेक्स्ट पेस्ट करें (सत्यापन स्क्रीन पर QR के रूप में दिखता है)। इससे उनकी कुंजियाँ पिन और सत्यापित हो जाती हैं।';

  @override
  String get importCard => 'कार्ड इंपोर्ट करें';

  @override
  String get manualConnection => 'मैन्युअल कनेक्शन';

  @override
  String get ipAddressHint => 'IP पता';

  @override
  String get portHint => 'पोर्ट';

  @override
  String get connecting => 'कनेक्ट हो रहा है...';

  @override
  String get globalDirectory => 'वैश्विक डायरेक्टरी (DHT, प्रायोगिक)';

  @override
  String get dhtHint =>
      'एक पहुँच योग्य बूटस्ट्रैप नोड ज़रूरी है। घोषणाएँ हस्ताक्षरित होती हैं; भरोसा फिर भी हैंडशेक से तय होता है।';

  @override
  String dhtRunning(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count नोड',
      one: '1 नोड',
    );
    return 'चालू · $_temp0';
  }

  @override
  String get stopped => 'रुका हुआ';

  @override
  String get stop => 'रोकें';

  @override
  String get start => 'शुरू करें';

  @override
  String get bootstrapHint => 'बूटस्ट्रैप host:port';

  @override
  String get bootstrapNodeAdded => 'बूटस्ट्रैप नोड जोड़ा गया';

  @override
  String get lookupHint => 'खोजने के लिए NC-...';

  @override
  String get find => 'खोजें';

  @override
  String get notFound => 'नहीं मिला';

  @override
  String foundPeerAt(String name, String address) {
    return '$name $address पर मिला';
  }

  @override
  String get lanOn => 'LAN चालू';

  @override
  String get lanOff => 'LAN बंद';

  @override
  String get bleOn => 'BLE चालू';

  @override
  String get bleScan => 'BLE स्कैन';

  @override
  String get bleOff => 'BLE बंद';

  @override
  String linksCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count लिंक',
      one: '1 लिंक',
    );
    return '$_temp0';
  }

  @override
  String get stealth => 'स्टेल्थ';

  @override
  String get visible => 'दृश्यमान';

  @override
  String get reachable => 'पहुँच योग्य';

  @override
  String get offlineQueued => 'ऑफ़लाइन, डिलीवरी कतार में';

  @override
  String get notANyxChatContactCard => 'यह NyxChat संपर्क कार्ड नहीं है';

  @override
  String invalidCard(String error) {
    return 'अमान्य कार्ड: $error';
  }

  @override
  String get scanContactCard => 'संपर्क कार्ड स्कैन करें';

  @override
  String get pointCameraHint =>
      'कैमरे को उनकी सत्यापन स्क्रीन या सेटिंग्स पेज पर दिख रहे QR कोड की ओर करें।';

  @override
  String get scanningPinsKeys =>
      'स्कैन करने से उनकी कुंजियाँ सत्यापित के रूप में पिन हो जाती हैं। नेटवर्क पर कुछ भी नहीं भेजा जाता।';

  @override
  String get security => 'सुरक्षा';

  @override
  String get databaseLock => 'डेटाबेस लॉक';

  @override
  String get requirePassword => 'पासवर्ड ज़रूरी करें';

  @override
  String get requirePasswordSubtitle =>
      'Argon2id से रैप की गई डेटाबेस कुंजी। भूल जाने पर कोई रिकवरी नहीं।';

  @override
  String get lockWhenInBackground => 'बैकग्राउंड में जाने पर लॉक करें';

  @override
  String wipeAfterFailedAttempts(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count विफल प्रयासों के बाद मिटाएँ',
      one: '1 विफल प्रयास के बाद मिटाएँ',
    );
    return '$_temp0';
  }

  @override
  String get duressPassword => 'दबाव पासवर्ड';

  @override
  String get duressPasswordSet => 'दबाव पासवर्ड सेट है';

  @override
  String get setADuressPassword => 'दबाव पासवर्ड सेट करें';

  @override
  String get duressOpensDecoyAndDestroys =>
      'एक नकली प्रोफ़ाइल खोलता है और असली को नष्ट कर देता है';

  @override
  String get duressOpensEmptyDecoy => 'एक खाली नकली प्रोफ़ाइल खोलता है';

  @override
  String get duressExplanation =>
      'लॉक स्क्रीन पर इसे दर्ज करने से एक खाली नकली प्रोफ़ाइल खुलती है';

  @override
  String get removeDuressPassword => 'दबाव पासवर्ड हटाएँ';

  @override
  String get identity => 'पहचान';

  @override
  String get rotateIdentityKeys => 'पहचान कुंजियाँ बदलें';

  @override
  String get rotateIdentitySubtitle =>
      'नई कुंजियाँ और हैंडल। जो संपर्क अभी ऑनलाइन हैं उन्हें हस्ताक्षरित परिवर्तन तुरंत मिलता है; बाकी को अगली बार सीधे कनेक्ट होने पर मिलेगा। इसके बाद ऐप बंद हो जाता है।';

  @override
  String get backup => 'बैकअप';

  @override
  String get exportEncryptedBackup => 'एन्क्रिप्टेड बैकअप एक्सपोर्ट करें';

  @override
  String get exportBackupSubtitle =>
      'पहचान कुंजियाँ, संपर्क, सत्र और संदेश, एक पासफ़्रेज़ से सील किए गए (Argon2id + AES-256-GCM)।';

  @override
  String get restoreFromBackup => 'बैकअप से पुनर्स्थापित करें';

  @override
  String get restoreBackupSubtitle =>
      'यह इस प्रोफ़ाइल को बदल देता है। इसके बाद पुराना डिवाइस मिटा दें: एक पहचान की दो सक्रिय प्रतियाँ उसके सत्रों को विभाजित कर देती हैं।';

  @override
  String get dangerZone => 'खतरे का क्षेत्र';

  @override
  String get panicWipe => 'पैनिक वाइप';

  @override
  String get panicWipeSubtitle =>
      'संदेश, संपर्क, सत्र और पहचान कुंजियाँ नष्ट कर देता है। इसे पूर्ववत नहीं किया जा सकता।';

  @override
  String get securityFooter =>
      'कुंजियाँ Android कीस्टोर-समर्थित सुरक्षित स्टोरेज में रहती हैं। संदेश डेटाबेस एक रैंडम मास्टर कुंजी से AES-256 एन्क्रिप्टेड है; पासवर्ड चालू होने पर वह कुंजी अतिरिक्त रूप से Argon2id से बनी कुंजी (32 MiB, 2 पास) के तहत AES-256-GCM से रैप की जाती है।';

  @override
  String get passphraseHint => 'पासफ़्रेज़ (8+ अक्षर)';

  @override
  String get confirmPassphraseHint => 'पासफ़्रेज़ की पुष्टि करें';

  @override
  String get continueAction => 'जारी रखें';

  @override
  String get passphraseTooShortOrMismatch =>
      'पासफ़्रेज़ बहुत छोटा है या मेल नहीं खाता';

  @override
  String get rotateIdentityKeysQuestion => 'पहचान कुंजियाँ बदलें?';

  @override
  String get rotateIdentityWarning =>
      'आपकी NyxChat ID बदल जाएगी। जो संपर्क ऑफ़लाइन हैं, वे तब तक आपसे संपर्क नहीं कर पाएँगे जब तक आप दोबारा सीधे न मिलें।';

  @override
  String get rotate => 'बदलें';

  @override
  String rotationFailed(String error) {
    return 'कुंजी बदलना विफल: $error';
  }

  @override
  String get backupPassphrase => 'बैकअप पासफ़्रेज़';

  @override
  String get saveBackupDialogTitle => 'NyxChat बैकअप सेव करें';

  @override
  String get backupCancelled => 'बैकअप रद्द किया गया';

  @override
  String get backupSaved => 'बैकअप सेव हो गया';

  @override
  String backupFailed(String error) {
    return 'बैकअप विफल: $error';
  }

  @override
  String get replaceThisProfile => 'इस प्रोफ़ाइल को बदलें?';

  @override
  String restoreConfirmBody(String created, String name) {
    return '\"$name\" का $created का बैकअप। इस डिवाइस पर मौजूद सब कुछ बदल दिया जाएगा और ऐप बंद हो जाएगा।';
  }

  @override
  String get restore => 'पुनर्स्थापित करें';

  @override
  String restoreFailed(String error) {
    return 'पुनर्स्थापना विफल: $error';
  }

  @override
  String get duressDifferentFromReal => 'आपके असली पासवर्ड से अलग';

  @override
  String get alsoDestroyRealProfile => 'असली प्रोफ़ाइल भी नष्ट करें';

  @override
  String get wipeEverythingQuestion => 'सब कुछ मिटाएँ?';

  @override
  String get wipeEverythingBody =>
      'इस डिवाइस पर सभी संदेश, संपर्क, सत्र और आपकी पहचान कुंजियाँ नष्ट कर दी जाएँगी। अगली बार मिलने पर पीयर को कुंजी परिवर्तन दिखेगा।';

  @override
  String get wipe => 'मिटाएँ';

  @override
  String get settings => 'सेटिंग्स';

  @override
  String get privacy => 'गोपनीयता';

  @override
  String get blockScreenshots => 'स्क्रीनशॉट ब्लॉक करें';

  @override
  String get blockScreenshotsSubtitle =>
      'हाल के ऐप्स में ऐप को छिपाता है और स्क्रीन कैप्चर रोकता है';

  @override
  String get sendReadReceipts => 'पढ़े जाने की रसीद भेजें';

  @override
  String get notifications => 'सूचनाएँ';

  @override
  String get showMessageTextInNotifications =>
      'सूचनाओं में संदेश का टेक्स्ट दिखाएँ';

  @override
  String get coverTraffic => 'कवर ट्रैफ़िक';

  @override
  String get coverTrafficSubtitle =>
      'बेतरतीब मेश पैकेट ताकि निष्क्रिय और सक्रिय समय एक जैसे दिखें';

  @override
  String get stealthMode => 'स्टेल्थ मोड';

  @override
  String get stealthModeSubtitle =>
      'न प्रसारण, न स्कैनिंग। मौजूदा लिंक बने रहते हैं।';

  @override
  String get network => 'नेटवर्क';

  @override
  String get localNetwork => 'स्थानीय नेटवर्क';

  @override
  String get active => 'सक्रिय';

  @override
  String get inactive => 'निष्क्रिय';

  @override
  String get directLinks => 'सीधे लिंक';

  @override
  String get unsupported => 'असमर्थित';

  @override
  String advertisingLinks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count लिंक',
      one: '1 लिंक',
    );
    return 'प्रसारण चालू · $_temp0';
  }

  @override
  String scanningLinks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count लिंक',
      one: '1 लिंक',
    );
    return 'स्कैन जारी · $_temp0';
  }

  @override
  String get bleLongRange => 'BLE लंबी रेंज (Coded PHY)';

  @override
  String get bleLongRangeSubtitle =>
      'Bluetooth 5 S=8 कोडिंग; कम थ्रूपुट, ज़्यादा पहुँच';

  @override
  String get listeningPort => 'लिसनिंग पोर्ट';

  @override
  String get globalDht => 'वैश्विक DHT';

  @override
  String get internetDelivery => 'इंटरनेट डिलीवरी';

  @override
  String get deliverThroughRelays =>
      'सार्वजनिक रिले (Nostr) के ज़रिए डिलीवर करें';

  @override
  String get deliverThroughRelaysSubtitle =>
      'सार्वजनिक Nostr रिले पर बदलते टोकन के तहत सील किए गए लिफ़ाफ़े। न कोई खाता, न हमारा कोई सर्वर। डिफ़ॉल्ट रूप से बंद।';

  @override
  String get routeThroughTor => 'रिले को Tor (Orbot) के ज़रिए रूट करें';

  @override
  String get routeThroughTorSubtitle =>
      'Orbot का 127.0.0.1:8118 पर HTTP प्रॉक्सी के साथ चलना ज़रूरी है';

  @override
  String get appLockDuressPanic => 'ऐप लॉक, दबाव पासवर्ड, पैनिक वाइप';

  @override
  String get about => 'इसके बारे में';

  @override
  String get version => 'संस्करण';

  @override
  String get protocol => 'प्रोटोकॉल';

  @override
  String protocolValue(String version) {
    return 'v$version · X25519+ML-KEM-768 · Double Ratchet · Sender Keys';
  }

  @override
  String get license => 'लाइसेंस';

  @override
  String get nyxChatIdCopied => 'NyxChat ID कॉपी की गई';

  @override
  String get contactCardCopied => 'संपर्क कार्ड कॉपी किया गया';

  @override
  String get copyContactCard => 'संपर्क कार्ड कॉपी करें';

  @override
  String get shareContactCardHint =>
      'इसे साझा करें ताकि अन्य लोग आपकी कुंजियाँ ऑफ़-बैंड पिन और सत्यापित कर सकें।';

  @override
  String get appearance => 'दिखावट';

  @override
  String get theme => 'थीम';

  @override
  String get themeSystem => 'सिस्टम';

  @override
  String get themeLight => 'लाइट';

  @override
  String get themeDark => 'डार्क';

  @override
  String get language => 'भाषा';

  @override
  String get languageSystemDefault => 'सिस्टम डिफ़ॉल्ट';

  @override
  String get wifiAware => 'Wi-Fi Aware';

  @override
  String get useWifiAware => 'Wi-Fi Aware का उपयोग करें';

  @override
  String get useWifiAwareSubtitle =>
      'एक्सेस पॉइंट के बिना पड़ोसी लिंक (Android 8+)। Bluetooth जैसा ही घूमता हुआ बीकन।';

  @override
  String get offlineSessions => 'ऑफ़लाइन सत्र';

  @override
  String pqReady(int count) {
    return 'पोस्ट-क्वांटम फ़ॉरवर्ड सीक्रेसी तैयार ($count एक-बार के प्रीकी)';
  }

  @override
  String get pqPending =>
      'पोस्ट-क्वांटम फ़ॉरवर्ड सीक्रेसी अगली मुलाक़ात तक लंबित';

  @override
  String get voiceMessage => 'वॉइस संदेश';

  @override
  String get photo => 'फ़ोटो';

  @override
  String get holdToRecord =>
      'वॉइस संदेश रिकॉर्ड करने के लिए माइक्रोफ़ोन दबाए रखें';

  @override
  String get slideToCancel => 'रद्द करने के लिए स्लाइड करें';

  @override
  String get releaseToCancel => 'रद्द करने के लिए छोड़ें';

  @override
  String get recordingUnavailable =>
      'इस डिवाइस पर वॉइस रिकॉर्डिंग उपलब्ध नहीं है';

  @override
  String get microphoneDenied =>
      'वॉइस संदेश रिकॉर्ड करने के लिए माइक्रोफ़ोन की अनुमति ज़रूरी है';

  @override
  String get recordingFailed => 'रिकॉर्डिंग शुरू नहीं हो सकी';

  @override
  String get playbackUnavailable => 'इस डिवाइस पर वॉइस प्लेबैक उपलब्ध नहीं है';

  @override
  String get playbackFailed => 'यह वॉइस संदेश चलाया नहीं जा सका';

  @override
  String get voiceNeedsCarrier =>
      'वॉइस नोट के लिए सीधा कनेक्शन या मेश पथ चाहिए';

  @override
  String get imageUnavailable => 'छवि उपलब्ध नहीं है';

  @override
  String get receiving => 'प्राप्त हो रहा है';
}
