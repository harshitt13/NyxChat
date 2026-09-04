// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get appTitle => 'NyxChat';

  @override
  String get notificationNewMessage => 'رسالة جديدة';

  @override
  String get notificationChannelMessages => 'الرسائل';

  @override
  String get notificationChannelMessagesDescription => 'رسائل NyxChat الواردة';

  @override
  String get meshChannelName => 'شبكة NyxChat المتشابكة';

  @override
  String get meshChannelDescription =>
      'يُبقي الشبكة المتشابكة اللامركزية تعمل في الخلفية.';

  @override
  String get meshNotificationInitial => 'الشبكة المتشابكة نشطة';

  @override
  String get meshNotificationActive => 'توجيه الشبكة المتشابكة وDHT نشط';

  @override
  String get cancel => 'إلغاء';

  @override
  String get save => 'حفظ';

  @override
  String get add => 'إضافة';

  @override
  String get off => 'إيقاف';

  @override
  String get connect => 'اتصال';

  @override
  String get verified => 'تم التحقق';

  @override
  String get messages => 'الرسائل';

  @override
  String get safetyNumberChangedTitle => 'تغيّر رقم الأمان';

  @override
  String safetyNumberChangedBody(String name, String id) {
    return 'يقدّم $name ($id) مفاتيح هوية مختلفة عن المفاتيح التي ثبّتّها.\n\nيحدث هذا عند إعادة تثبيت التطبيق لديه، أو إذا كان أحدهم ينتحل شخصيته. تحقق من رقم الأمان الجديد شخصيًا قبل القبول. يبقى الاتصال محظورًا حتى تقرر.';
  }

  @override
  String get keepBlocking => 'الاستمرار في الحظر';

  @override
  String get acceptNewKeys => 'قبول المفاتيح الجديدة';

  @override
  String get searchConversationsHint => 'البحث في المحادثات والرسائل';

  @override
  String get emergencyBroadcastTitle => 'بث الطوارئ';

  @override
  String get noConversationsYet => 'لا توجد محادثات بعد';

  @override
  String get tapPlusToFindPeople => 'انقر على + للعثور على أشخاص بالقرب منك';

  @override
  String get noMatches => 'لا توجد نتائج مطابقة';

  @override
  String get verifySafetyNumber => 'التحقق من رقم الأمان';

  @override
  String get mute => 'كتم';

  @override
  String get unmute => 'إلغاء الكتم';

  @override
  String get leaveGroup => 'مغادرة المجموعة';

  @override
  String get deleteConversation => 'حذف المحادثة';

  @override
  String membersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count عضو',
      many: '$count عضوًا',
      few: '$count أعضاء',
      two: 'عضوان اثنان',
      one: 'عضو واحد',
      zero: 'لا أعضاء',
    );
    return '$_temp0';
  }

  @override
  String membersCountLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count عضو (غادرت)',
      many: '$count عضوًا (غادرت)',
      few: '$count أعضاء (غادرت)',
      two: 'عضوان (غادرت)',
      one: 'عضو واحد (غادرت)',
      zero: 'لا أعضاء (غادرت)',
    );
    return '$_temp0';
  }

  @override
  String get noMessagesYet => 'لا توجد رسائل بعد';

  @override
  String get filesNeedDirectConnection =>
      'تحتاج الملفات إلى اتصال مباشر. اقترب إلى نطاق Wi-Fi أولًا.';

  @override
  String get reply => 'رد';

  @override
  String get copyText => 'نسخ النص';

  @override
  String get deleteForMe => 'حذف لديّ';

  @override
  String get disappearingMessages => 'الرسائل ذاتية الاختفاء';

  @override
  String get disappear5Minutes => '5 دقائق';

  @override
  String get disappear1Hour => 'ساعة واحدة';

  @override
  String get disappear1Day => 'يوم واحد';

  @override
  String get disappear1Week => 'أسبوع واحد';

  @override
  String get conversationDeleted => 'تم حذف المحادثة';

  @override
  String get statusConnected => 'متصل';

  @override
  String get statusReachableViaMesh => 'يمكن الوصول إليه عبر الشبكة المتشابكة';

  @override
  String get statusOfflineDeliverLater => 'غير متصل · سيتم التسليم لاحقًا';

  @override
  String get endToEndEncrypted => 'مشفّر من طرف إلى طرف';

  @override
  String get groupEncryptionHint =>
      'تستخدم الرسائل مفاتيح خاصة بكل مرسل؛ ولا يمكن قراءتها إلا للأعضاء.';

  @override
  String get directEncryptionHint => 'الرسائل محمية بجلسة Double Ratchet.';

  @override
  String get noLongerMemberHint => 'لم تعد عضوًا';

  @override
  String get messageHint => 'رسالة';

  @override
  String attachmentProgress(String percent, String size) {
    return '$percent% · $size';
  }

  @override
  String get sysMemberRemoved => 'تمت إزالة عضو';

  @override
  String get sysYouLeftGroup => 'غادرت المجموعة';

  @override
  String sysGroupCreated(String name) {
    return 'تم إنشاء المجموعة \"$name\"';
  }

  @override
  String sysMembersAdded(String names) {
    return 'تمت إضافة $names';
  }

  @override
  String sysAddedToGroupBy(String name, String who) {
    return 'أضافك $who إلى \"$name\"';
  }

  @override
  String sysUpdatedMembers(String who) {
    return 'حدّث $who قائمة الأعضاء';
  }

  @override
  String get sysAMemberWasRemoved => 'تمت إزالة أحد الأعضاء';

  @override
  String get sysYouWereRemoved => 'تمت إزالتك من المجموعة';

  @override
  String sysLeftGroup(String who) {
    return 'غادر $who المجموعة';
  }

  @override
  String sysRenamedGroup(String who, String name) {
    return 'غيّر $who اسم المجموعة إلى \"$name\"';
  }

  @override
  String get sysGroupUpdated => 'تم تحديث المجموعة';

  @override
  String sysKeysRotated(String name) {
    return 'بدّل $name مفاتيحه (انتقال موثّق)';
  }

  @override
  String get contactNotPinnedYet => 'لم يتم تثبيت جهة الاتصال بعد';

  @override
  String get safetyNumber => 'رقم الأمان';

  @override
  String get safetyNumberExplanation =>
      'يرى كلاكما الرقم نفسه إذا لم يكن أحد يعترض الاتصال. قارناه شخصيًا أو عبر الهاتف أو عبر قناة أخرى تثق بها.';

  @override
  String get markAsVerified => 'تمييز كمُتحقَّق منه';

  @override
  String get messageAction => 'مراسلة';

  @override
  String get scanTheirQr => 'مسح رمز QR الخاص به';

  @override
  String get verifiedKeysMatch => 'تم التحقق: المفاتيح تطابق جهة الاتصال هذه';

  @override
  String cardBelongsToOther(String name) {
    return 'تلك البطاقة تخص $name، وقد تم تثبيتها بشكل منفصل';
  }

  @override
  String get theirFingerprint => 'بصمته';

  @override
  String get yourFingerprint => 'بصمتك';

  @override
  String get showThemYourCard => 'أظهر له بطاقة جهة الاتصال الخاصة بك';

  @override
  String get contactCardContainsOnlyPublicKeys =>
      'تحتوي على مفاتيحك العامة فقط. مسحها أو لصقها يثبّت هويتك على جهازه.';

  @override
  String get details => 'التفاصيل';

  @override
  String get nyxChatId => 'معرّف NyxChat';

  @override
  String get handshake => 'المصافحة';

  @override
  String get handshakeValue => 'هجين X25519 + ML-KEM-768، موقّع بـ Ed25519';

  @override
  String get messagesValue => 'Double Ratchet، AES-256-GCM';

  @override
  String get firstSeen => 'أول ظهور';

  @override
  String get keysChanged => 'تغيير المفاتيح';

  @override
  String get idCopied => 'تم نسخ المعرّف';

  @override
  String get giveGroupAName => 'أعطِ المجموعة اسمًا';

  @override
  String get selectAtLeastOneMember => 'اختر عضوًا واحدًا على الأقل';

  @override
  String get newGroup => 'مجموعة جديدة';

  @override
  String get create => 'إنشاء';

  @override
  String get groupNameHint => 'اسم المجموعة';

  @override
  String get descriptionOptionalHint => 'الوصف (اختياري)';

  @override
  String membersSelectedHeader(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'تم تحديد $count عضو',
      many: 'تم تحديد $count عضوًا',
      few: 'تم تحديد $count أعضاء',
      two: 'تم تحديد عضوين',
      one: 'تم تحديد عضو واحد',
      zero: 'لم يُحدَّد أي عضو',
    );
    return 'الأعضاء · $_temp0';
  }

  @override
  String get noContactsYet =>
      'لا توجد جهات اتصال بعد. اتصل بشخص ما أولًا حتى يتم تثبيت مفاتيحه.';

  @override
  String get noRecentPosition =>
      'لا يوجد موقع حديث. أدخل خلية geohash يدويًا أو انتقل إلى مكان مفتوح.';

  @override
  String invalidCell(String error) {
    return 'خلية غير صالحة: $error';
  }

  @override
  String get noNeighboursKept =>
      'لا يوجد جيران حاليًا. سيتم الاحتفاظ برسالتك وإرسالها إلى أول جهاز يظهر.';

  @override
  String get areaCellLabel => 'خلية المنطقة (geohash)';

  @override
  String get findingYourArea => 'جارٍ تحديد منطقتك...';

  @override
  String meshNeighboursCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count جار في الشبكة المتشابكة',
      many: '$count جارًا في الشبكة المتشابكة',
      few: '$count جيران في الشبكة المتشابكة',
      two: 'جاران في الشبكة المتشابكة',
      one: 'جار واحد في الشبكة المتشابكة',
      zero: 'لا جيران في الشبكة المتشابكة',
    );
    return '$_temp0';
  }

  @override
  String directLinksCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count رابط مباشر',
      many: '$count رابطًا مباشرًا',
      few: '$count روابط مباشرة',
      two: 'رابطان مباشران',
      one: 'رابط مباشر واحد',
      zero: 'لا روابط مباشرة',
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
    return 'الاستماع في الخلية $cell ($area) · $neighbours، $links';
  }

  @override
  String get emergencyEmptyHint =>
      'تظهر هنا الرسائل من أي شخص يستخدم NyxChat في هذه الخلية. لا يغادر موقعك الهاتف أبدًا ما لم تُضمّنه صراحةً.';

  @override
  String get anonymous => 'مجهول';

  @override
  String positionLabel(String coords) {
    return 'الموقع: $coords';
  }

  @override
  String get includeMyName => 'تضمين اسمي';

  @override
  String get includeMyPosition => 'تضمين موقعي';

  @override
  String get emergencyComposerHint => 'ماذا يحدث؟ أين أنت؟';

  @override
  String get joinCellFirst => 'انضم إلى خلية أولًا';

  @override
  String get send => 'إرسال';

  @override
  String get presetNeedHelp => 'أحتاج إلى مساعدة';

  @override
  String get presetSafe => 'أنا بأمان';

  @override
  String get presetMedical => 'حالة طبية طارئة';

  @override
  String get addMembers => 'إضافة أعضاء';

  @override
  String get groupEncryptionExplanation =>
      'تُشفَّر رسائل المجموعة بمفاتيح مرسل خاصة بكل عضو تُوزَّع عبر جلسات Double Ratchet ثنائية. وتُبدَّل المفاتيح كلما غادر أحد الأعضاء.';

  @override
  String memberYou(String name) {
    return '$name (أنت)';
  }

  @override
  String get admin => 'مشرف';

  @override
  String get renameGroup => 'إعادة تسمية المجموعة';

  @override
  String get noOtherKnownContacts => 'لا توجد جهات اتصال معروفة أخرى';

  @override
  String get meshDiagnostics => 'تشخيص الشبكة المتشابكة';

  @override
  String get statBleLinks => 'روابط BLE';

  @override
  String get statKnownRoutes => 'المسارات المعروفة';

  @override
  String get statStoredPackets => 'الحزم المخزّنة';

  @override
  String get statDeliveredToMe => 'المسلَّمة إليّ';

  @override
  String get statReceived => 'المستلَمة';

  @override
  String get statForwarded => 'المُعاد توجيهها';

  @override
  String get statDuplicatesDropped => 'التكرارات المُسقطة';

  @override
  String get statSeenIds => 'المعرّفات المشاهدة';

  @override
  String get linksHeader => 'الروابط';

  @override
  String get noBluetoothLinksHint =>
      'لا توجد روابط بلوتوث. ترتبط الأجهزة الموجودة ضمن النطاق تلقائيًا ما دام المسح والإعلان مفعّلين.';

  @override
  String get weDialled => 'نحن اتصلنا';

  @override
  String get theyDialled => 'هم اتصلوا';

  @override
  String linkSubtitle(String role, int mtu, String address) {
    return '$role · MTU $mtu · $address';
  }

  @override
  String get routingTableHeader => 'جدول التوجيه';

  @override
  String get routingTableHint =>
      'يتم تعلّم المسارات من المسار المسجّل في كل حزمة ومن الإشارات الدورية.';

  @override
  String routeToken(String prefix) {
    return 'الرمز $prefix...';
  }

  @override
  String routeVia(String hop, int hops) {
    String _temp0 = intl.Intl.pluralLogic(
      hops,
      locale: localeName,
      other: '$hops قفزة',
      many: '$hops قفزة',
      few: '$hops قفزات',
      two: 'قفزتان اثنتان',
      one: 'قفزة واحدة',
      zero: 'لا قفزات',
    );
    return 'عبر المرحّل $hop... · $_temp0';
  }

  @override
  String get howItWorksHeader => 'كيف يعمل';

  @override
  String meshExplanation(int copies, int hops) {
    return 'تُعنون الحزم بتجزئات SHA-256 وتحمل مغلفًا مشفّرًا من طرف إلى طرف. يخزّن المرحّل كل حزمة، ويعيد توجيهها إلى القفزة التالية المتعلَّمة أو ينثر ما يصل إلى $copies نسخ، ثم يُسقطها بعد $hops قفزات أو 24 ساعة. لا يستطيع المرحّلون قراءة ما يحملونه أو تعديله أو إعادة عنونته.';
  }

  @override
  String get enterDisplayName => 'أدخل اسم عرض (64 حرفًا كحد أقصى)';

  @override
  String couldNotCreateIdentity(String error) {
    return 'تعذّر إنشاء الهوية: $error';
  }

  @override
  String get tagline => 'نظير إلى نظير · مشفّر · يعمل دون اتصال';

  @override
  String get featureE2eSubtitle =>
      'Double Ratchet مع مصافحة هجينة X25519 + ML-KEM-768';

  @override
  String get featureOfflineTitle => 'يعمل بدون إنترنت';

  @override
  String get featureOfflineSubtitle =>
      'شبكة Wi-Fi محلية (LAN) وشبكة بلوتوث متشابكة، مع تسليم بأسلوب التخزين وإعادة الإرسال';

  @override
  String get featureNoServersTitle => 'لا خوادم ولا حسابات';

  @override
  String get featureNoServersSubtitle =>
      'هويتك زوج مفاتيح لا يغادر هذا الجهاز أبدًا';

  @override
  String get displayName => 'اسم العرض';

  @override
  String get createIdentity => 'إنشاء الهوية';

  @override
  String get keysGeneratedLocally =>
      'يولّد مفاتيح X25519 وEd25519 وML-KEM-768 محليًا. لا يتم رفع أي شيء.';

  @override
  String get passwordRequired => 'كلمة المرور مطلوبة';

  @override
  String get atLeast8Characters => '8 أحرف على الأقل';

  @override
  String get passwordsDoNotMatch => 'كلمتا المرور غير متطابقتين';

  @override
  String get enterYourPassword => 'أدخل كلمة المرور';

  @override
  String get allDataWiped => 'تم مسح جميع البيانات.';

  @override
  String get incorrectPassword => 'كلمة المرور غير صحيحة';

  @override
  String incorrectPasswordAttemptsLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'تبقّت $count محاولة',
      many: 'تبقّت $count محاولة',
      few: 'تبقّت $count محاولات',
      two: 'تبقّت محاولتان',
      one: 'تبقّت محاولة واحدة',
      zero: 'لم تتبقَّ أي محاولة',
    );
    return 'كلمة المرور غير صحيحة · $_temp0 قبل المسح';
  }

  @override
  String get setAppLock => 'تعيين قفل التطبيق';

  @override
  String get nyxChatIsLocked => 'NyxChat مقفل';

  @override
  String get unlockPrompt =>
      'قاعدة بياناتك مشفّرة. أدخل كلمة المرور لفتح القفل.';

  @override
  String get passwordSetupExplanation =>
      'سيتم تغليف مفتاح قاعدة البيانات بمفتاح مشتق من كلمة المرور هذه باستخدام Argon2id. لا توجد وسيلة للاستعادة: نسيان كلمة المرور يعني ضياع البيانات.';

  @override
  String get passwordHint => 'كلمة المرور';

  @override
  String get confirmPasswordHint => 'تأكيد كلمة المرور';

  @override
  String get enableLock => 'تفعيل القفل';

  @override
  String get unlock => 'فتح القفل';

  @override
  String get connectedAndAuthenticated => 'متصل ومصادَق عليه';

  @override
  String get connectionFailed =>
      'فشل الاتصال (تعذّر الوصول، أو رُفض الاتصال، أو عدم تطابق المفاتيح)';

  @override
  String pinnedAndVerified(String name) {
    return 'تم تثبيت $name والتحقق منه';
  }

  @override
  String invalidContactCard(String error) {
    return 'بطاقة جهة اتصال غير صالحة: $error';
  }

  @override
  String get findPeople => 'البحث عن أشخاص';

  @override
  String get visibleToEveryoneNearby => 'مرئي لكل من حولك';

  @override
  String get visibleSubtitlePublic =>
      'يتم بث معرّفك واسمك حتى يتمكن الأشخاص الجدد من العثور عليك.';

  @override
  String get visibleSubtitlePrivate =>
      'إشارات خاصة: جهات الاتصال المثبّتة فقط يمكنها التعرف عليك؛ ويرى الآخرون ضجيجًا عشوائيًا.';

  @override
  String get scanContactQr => 'مسح رمز QR لجهة اتصال';

  @override
  String get emergency => 'الطوارئ';

  @override
  String get nearbyOnWifi => 'بالقرب منك عبر Wi-Fi';

  @override
  String get nobodyDiscoveredYet =>
      'لم يتم اكتشاف أحد بعد. يظهر هنا تلقائيًا النظراء الموجودون على شبكة Wi-Fi نفسها.';

  @override
  String get bluetoothMesh => 'شبكة بلوتوث متشابكة';

  @override
  String get bleNotAvailable => 'Bluetooth LE غير متوفر على هذا الجهاز.';

  @override
  String get bleScanningHint =>
      'جارٍ المسح. سترتبط أجهزة NyxChat الأخرى الموجودة ضمن النطاق تلقائيًا.';

  @override
  String get bleScanningAdvertisingHint =>
      'جارٍ المسح والإعلان. سترتبط أجهزة NyxChat الأخرى الموجودة ضمن النطاق تلقائيًا.';

  @override
  String get roleCentral => 'مركزي';

  @override
  String get rolePeripheral => 'طرفي';

  @override
  String bleLinkedSubtitle(String role, int mtu) {
    return 'مرتبط · $role · MTU $mtu';
  }

  @override
  String rssiDbm(int rssi) {
    return '$rssi dBm';
  }

  @override
  String get contacts => 'جهات الاتصال';

  @override
  String get contactsPinnedHint => 'تُثبَّت هنا مفاتيح كل نظير تتصل به.';

  @override
  String get addContactFromCard => 'إضافة جهة اتصال من بطاقة';

  @override
  String get pasteContactCardHint =>
      'الصق نص بطاقة جهة الاتصال (المعروضة كرمز QR في شاشة التحقق). سيؤدي ذلك إلى تثبيت مفاتيحه والتحقق منها.';

  @override
  String get importCard => 'استيراد البطاقة';

  @override
  String get manualConnection => 'اتصال يدوي';

  @override
  String get ipAddressHint => 'عنوان IP';

  @override
  String get portHint => 'المنفذ';

  @override
  String get connecting => 'جارٍ الاتصال...';

  @override
  String get globalDirectory => 'الدليل العالمي (DHT، تجريبي)';

  @override
  String get dhtHint =>
      'يحتاج إلى عقدة تمهيد يمكن الوصول إليها. الإعلانات موقّعة؛ وتبقى المصافحة هي التي تحدد الثقة.';

  @override
  String dhtRunning(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count عقدة',
      many: '$count عقدة',
      few: '$count عُقد',
      two: 'عقدتان اثنتان',
      one: 'عقدة واحدة',
      zero: 'لا عُقد',
    );
    return 'قيد التشغيل · $_temp0';
  }

  @override
  String get stopped => 'متوقف';

  @override
  String get stop => 'إيقاف';

  @override
  String get start => 'بدء';

  @override
  String get bootstrapHint => 'عقدة التمهيد host:port';

  @override
  String get bootstrapNodeAdded => 'تمت إضافة عقدة التمهيد';

  @override
  String get lookupHint => 'NC-... للبحث عنه';

  @override
  String get find => 'بحث';

  @override
  String get notFound => 'غير موجود';

  @override
  String foundPeerAt(String name, String address) {
    return 'تم العثور على $name في $address';
  }

  @override
  String get lanOn => 'LAN مفعّل';

  @override
  String get lanOff => 'LAN متوقف';

  @override
  String get bleOn => 'BLE مفعّل';

  @override
  String get bleScan => 'مسح BLE';

  @override
  String get bleOff => 'BLE متوقف';

  @override
  String linksCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count رابط',
      many: '$count رابطًا',
      few: '$count روابط',
      two: 'رابطان اثنان',
      one: 'رابط واحد',
      zero: 'لا روابط',
    );
    return '$_temp0';
  }

  @override
  String get stealth => 'متخفٍ';

  @override
  String get visible => 'مرئي';

  @override
  String get reachable => 'يمكن الوصول إليه';

  @override
  String get offlineQueued => 'غير متصل، التسليم في قائمة الانتظار';

  @override
  String get notANyxChatContactCard => 'ليست بطاقة جهة اتصال NyxChat';

  @override
  String invalidCard(String error) {
    return 'بطاقة غير صالحة: $error';
  }

  @override
  String get scanContactCard => 'مسح بطاقة جهة اتصال';

  @override
  String get pointCameraHint =>
      'وجّه الكاميرا نحو رمز QR في شاشة التحقق أو صفحة الإعدادات لديه.';

  @override
  String get scanningPinsKeys =>
      'يؤدي المسح إلى تثبيت مفاتيحه كمفاتيح موثّقة. لا يُرسل أي شيء عبر الشبكة.';

  @override
  String get security => 'الأمان';

  @override
  String get databaseLock => 'قفل قاعدة البيانات';

  @override
  String get requirePassword => 'طلب كلمة مرور';

  @override
  String get requirePasswordSubtitle =>
      'مفتاح قاعدة بيانات مغلّف بـ Argon2id. لا يمكن الاستعادة عند النسيان.';

  @override
  String get lockWhenInBackground => 'القفل عند الانتقال إلى الخلفية';

  @override
  String wipeAfterFailedAttempts(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'المسح بعد $count محاولة فاشلة',
      many: 'المسح بعد $count محاولة فاشلة',
      few: 'المسح بعد $count محاولات فاشلة',
      two: 'المسح بعد محاولتين فاشلتين',
      one: 'المسح بعد محاولة فاشلة واحدة',
      zero: 'المسح بعد $count محاولات فاشلة',
    );
    return '$_temp0';
  }

  @override
  String get duressPassword => 'كلمة مرور الإكراه';

  @override
  String get duressPasswordSet => 'تم تعيين كلمة مرور الإكراه';

  @override
  String get setADuressPassword => 'تعيين كلمة مرور للإكراه';

  @override
  String get duressOpensDecoyAndDestroys =>
      'تفتح ملفًا شخصيًا تمويهيًا وتدمّر الملف الحقيقي';

  @override
  String get duressOpensEmptyDecoy => 'تفتح ملفًا شخصيًا تمويهيًا فارغًا';

  @override
  String get duressExplanation =>
      'إدخالها في شاشة القفل يفتح ملفًا شخصيًا تمويهيًا فارغًا';

  @override
  String get removeDuressPassword => 'إزالة كلمة مرور الإكراه';

  @override
  String get identity => 'الهوية';

  @override
  String get rotateIdentityKeys => 'تبديل مفاتيح الهوية';

  @override
  String get rotateIdentitySubtitle =>
      'مفاتيح ومعرّف جديدان. تتلقى جهات الاتصال المتصلة الآن انتقالًا موقّعًا فورًا؛ ويتلقاه الآخرون عند اتصالك بهم مباشرةً في المرة القادمة. يُغلق التطبيق بعد ذلك.';

  @override
  String get backup => 'النسخ الاحتياطي';

  @override
  String get exportEncryptedBackup => 'تصدير نسخة احتياطية مشفّرة';

  @override
  String get exportBackupSubtitle =>
      'مفاتيح الهوية وجهات الاتصال والجلسات والرسائل، مختومة بعبارة مرور (Argon2id + AES-256-GCM).';

  @override
  String get restoreFromBackup => 'الاستعادة من نسخة احتياطية';

  @override
  String get restoreBackupSubtitle =>
      'يستبدل هذا الملف الشخصي. امسح الجهاز القديم بعد ذلك: وجود نسختين حيّتين من هوية واحدة يشطر جلساتها.';

  @override
  String get dangerZone => 'منطقة الخطر';

  @override
  String get panicWipe => 'مسح الطوارئ';

  @override
  String get panicWipeSubtitle =>
      'يدمّر الرسائل وجهات الاتصال والجلسات ومفاتيح الهوية. لا يمكن التراجع عنه.';

  @override
  String get securityFooter =>
      'تُحفظ المفاتيح في التخزين الآمن المدعوم بمخزن مفاتيح Android. قاعدة بيانات الرسائل مشفّرة بـ AES-256 بمفتاح رئيسي عشوائي؛ وعند تفعيل كلمة مرور يُغلّف هذا المفتاح إضافيًا بـ AES-256-GCM تحت مفتاح مشتق عبر Argon2id (32 MiB، تمريرتان).';

  @override
  String get passphraseHint => 'عبارة المرور (8 أحرف أو أكثر)';

  @override
  String get confirmPassphraseHint => 'تأكيد عبارة المرور';

  @override
  String get continueAction => 'متابعة';

  @override
  String get passphraseTooShortOrMismatch =>
      'عبارة المرور قصيرة جدًا أو غير متطابقة';

  @override
  String get rotateIdentityKeysQuestion => 'هل تريد تبديل مفاتيح الهوية؟';

  @override
  String get rotateIdentityWarning =>
      'سيتغيّر معرّف NyxChat الخاص بك. لن تتمكن جهات الاتصال غير المتصلة من الوصول إليك حتى تلتقيا مجددًا مباشرةً.';

  @override
  String get rotate => 'تبديل';

  @override
  String rotationFailed(String error) {
    return 'فشل التبديل: $error';
  }

  @override
  String get backupPassphrase => 'عبارة مرور النسخة الاحتياطية';

  @override
  String get saveBackupDialogTitle => 'حفظ نسخة NyxChat الاحتياطية';

  @override
  String get backupCancelled => 'تم إلغاء النسخ الاحتياطي';

  @override
  String get backupSaved => 'تم حفظ النسخة الاحتياطية';

  @override
  String backupFailed(String error) {
    return 'فشل النسخ الاحتياطي: $error';
  }

  @override
  String get replaceThisProfile => 'هل تريد استبدال هذا الملف الشخصي؟';

  @override
  String restoreConfirmBody(String created, String name) {
    return 'نسخة احتياطية من $created لـ \"$name\". سيتم استبدال كل ما على هذا الجهاز وسيُغلق التطبيق.';
  }

  @override
  String get restore => 'استعادة';

  @override
  String restoreFailed(String error) {
    return 'فشلت الاستعادة: $error';
  }

  @override
  String get duressDifferentFromReal => 'مختلفة عن كلمة مرورك الحقيقية';

  @override
  String get alsoDestroyRealProfile => 'تدمير الملف الشخصي الحقيقي أيضًا';

  @override
  String get wipeEverythingQuestion => 'هل تريد مسح كل شيء؟';

  @override
  String get wipeEverythingBody =>
      'سيتم تدمير جميع الرسائل وجهات الاتصال والجلسات ومفاتيح هويتك على هذا الجهاز. سيرى النظراء تغيّرًا في المفاتيح عند لقائكم في المرة القادمة.';

  @override
  String get wipe => 'مسح';

  @override
  String get settings => 'الإعدادات';

  @override
  String get privacy => 'الخصوصية';

  @override
  String get blockScreenshots => 'حظر لقطات الشاشة';

  @override
  String get blockScreenshotsSubtitle =>
      'يخفي التطبيق في قائمة التطبيقات الأخيرة ويمنع التقاط الشاشة';

  @override
  String get sendReadReceipts => 'إرسال إيصالات القراءة';

  @override
  String get notifications => 'الإشعارات';

  @override
  String get showMessageTextInNotifications => 'إظهار نص الرسالة في الإشعارات';

  @override
  String get coverTraffic => 'حركة بيانات تمويهية';

  @override
  String get coverTrafficSubtitle =>
      'حزم عشوائية في الشبكة المتشابكة لتبدو فترات الخمول والنشاط متشابهة';

  @override
  String get stealthMode => 'وضع التخفي';

  @override
  String get stealthModeSubtitle =>
      'بدون إعلان أو مسح. تبقى الروابط الحالية قائمة.';

  @override
  String get network => 'الشبكة';

  @override
  String get localNetwork => 'الشبكة المحلية';

  @override
  String get active => 'نشط';

  @override
  String get inactive => 'غير نشط';

  @override
  String get directLinks => 'الروابط المباشرة';

  @override
  String get unsupported => 'غير مدعوم';

  @override
  String advertisingLinks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count رابط',
      many: '$count رابطًا',
      few: '$count روابط',
      two: 'رابطان اثنان',
      one: 'رابط واحد',
      zero: 'لا روابط',
    );
    return 'جارٍ الإعلان · $_temp0';
  }

  @override
  String scanningLinks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count رابط',
      many: '$count رابطًا',
      few: '$count روابط',
      two: 'رابطان اثنان',
      one: 'رابط واحد',
      zero: 'لا روابط',
    );
    return 'جارٍ المسح · $_temp0';
  }

  @override
  String get bleLongRange => 'BLE بعيد المدى (Coded PHY)';

  @override
  String get bleLongRangeSubtitle =>
      'ترميز Bluetooth 5 بمعامل S=8؛ إنتاجية أقل ومدى أبعد';

  @override
  String get listeningPort => 'منفذ الاستماع';

  @override
  String get globalDht => 'DHT العالمي';

  @override
  String get internetDelivery => 'التسليم عبر الإنترنت';

  @override
  String get deliverThroughRelays => 'التسليم عبر مرحّلات عامة (Nostr)';

  @override
  String get deliverThroughRelaysSubtitle =>
      'مغلفات مختومة تحت رموز متغيّرة على مرحّلات Nostr العامة. بلا حساب، وبلا خادم خاص بنا. متوقف افتراضيًا.';

  @override
  String get routeThroughTor => 'توجيه المرحّلات عبر Tor (Orbot)';

  @override
  String get routeThroughTorSubtitle =>
      'يتطلب تشغيل Orbot مع وكيل HTTP الخاص به على 127.0.0.1:8118';

  @override
  String get appLockDuressPanic =>
      'قفل التطبيق، كلمة مرور الإكراه، مسح الطوارئ';

  @override
  String get about => 'حول';

  @override
  String get version => 'الإصدار';

  @override
  String get protocol => 'البروتوكول';

  @override
  String protocolValue(String version) {
    return 'v$version · X25519+ML-KEM-768 · Double Ratchet · Sender Keys';
  }

  @override
  String get license => 'الترخيص';

  @override
  String get nyxChatIdCopied => 'تم نسخ معرّف NyxChat';

  @override
  String get contactCardCopied => 'تم نسخ بطاقة جهة الاتصال';

  @override
  String get copyContactCard => 'نسخ بطاقة جهة الاتصال';

  @override
  String get shareContactCardHint =>
      'شارك هذه البطاقة ليتمكن الآخرون من تثبيت مفاتيحك والتحقق منها خارج النطاق.';

  @override
  String get appearance => 'المظهر';

  @override
  String get theme => 'السمة';

  @override
  String get themeSystem => 'النظام';

  @override
  String get themeLight => 'فاتح';

  @override
  String get themeDark => 'داكن';

  @override
  String get language => 'اللغة';

  @override
  String get languageSystemDefault => 'الإعداد الافتراضي للنظام';

  @override
  String get wifiAware => 'Wi-Fi Aware';

  @override
  String get useWifiAware => 'استخدام Wi-Fi Aware';

  @override
  String get useWifiAwareSubtitle =>
      'روابط مع الأجهزة المجاورة دون نقطة وصول (Android 8+). نفس المنارة الدوّارة المستخدمة في البلوتوث.';

  @override
  String get offlineSessions => 'الجلسات دون اتصال';

  @override
  String pqReady(int count) {
    return 'السرية الأمامية ما بعد الكم جاهزة ($count مفاتيح مسبقة لمرة واحدة)';
  }

  @override
  String get pqPending => 'السرية الأمامية ما بعد الكم بانتظار اللقاء التالي';

  @override
  String get voiceMessage => 'رسالة صوتية';

  @override
  String get photo => 'صورة';

  @override
  String get holdToRecord => 'اضغط مطولًا على الميكروفون لتسجيل رسالة صوتية';

  @override
  String get slideToCancel => 'اسحب للإلغاء';

  @override
  String get releaseToCancel => 'اترك للإلغاء';

  @override
  String get recordingUnavailable => 'تسجيل الصوت غير متاح على هذا الجهاز';

  @override
  String get microphoneDenied =>
      'يلزم الوصول إلى الميكروفون لتسجيل الرسائل الصوتية';

  @override
  String get recordingFailed => 'تعذر بدء التسجيل';

  @override
  String get playbackUnavailable => 'تشغيل الصوت غير متاح على هذا الجهاز';

  @override
  String get playbackFailed => 'تعذر تشغيل هذه الرسالة الصوتية';

  @override
  String get voiceNeedsCarrier =>
      'تحتاج الملاحظات الصوتية إلى اتصال مباشر أو مسار عبر الشبكة المتداخلة';

  @override
  String get imageUnavailable => 'الصورة غير متاحة';

  @override
  String get receiving => 'جارٍ الاستلام';
}
