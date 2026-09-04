// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get appTitle => 'NyxChat';

  @override
  String get notificationNewMessage => 'Новое сообщение';

  @override
  String get notificationChannelMessages => 'Сообщения';

  @override
  String get notificationChannelMessagesDescription =>
      'Входящие сообщения NyxChat';

  @override
  String get meshChannelName => 'Mesh-сеть NyxChat';

  @override
  String get meshChannelDescription =>
      'Поддерживает работу децентрализованной mesh-сети в фоновом режиме.';

  @override
  String get meshNotificationInitial => 'Mesh-сеть активна';

  @override
  String get meshNotificationActive => 'Mesh-маршрутизация и DHT активны';

  @override
  String get cancel => 'Отмена';

  @override
  String get save => 'Сохранить';

  @override
  String get add => 'Добавить';

  @override
  String get off => 'Выкл.';

  @override
  String get connect => 'Подключиться';

  @override
  String get verified => 'Проверено';

  @override
  String get messages => 'Сообщения';

  @override
  String get safetyNumberChangedTitle => 'Код безопасности изменился';

  @override
  String safetyNumberChangedBody(String name, String id) {
    return '$name ($id) предъявляет ключи идентификации, отличные от закреплённых у вас.\n\nТак бывает, если собеседник переустановил приложение или если кто-то выдаёт себя за него. Сверьте новый код безопасности лично, прежде чем принимать ключи. Соединение остаётся заблокированным, пока вы не примете решение.';
  }

  @override
  String get keepBlocking => 'Оставить блокировку';

  @override
  String get acceptNewKeys => 'Принять новые ключи';

  @override
  String get searchConversationsHint => 'Поиск по чатам и сообщениям';

  @override
  String get emergencyBroadcastTitle => 'Экстренная рассылка';

  @override
  String get noConversationsYet => 'Чатов пока нет';

  @override
  String get tapPlusToFindPeople => 'Нажмите +, чтобы найти людей поблизости';

  @override
  String get noMatches => 'Ничего не найдено';

  @override
  String get verifySafetyNumber => 'Проверить код безопасности';

  @override
  String get mute => 'Без звука';

  @override
  String get unmute => 'Включить звук';

  @override
  String get leaveGroup => 'Покинуть группу';

  @override
  String get deleteConversation => 'Удалить чат';

  @override
  String membersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count участника',
      many: '$count участников',
      few: '$count участника',
      one: '$count участник',
    );
    return '$_temp0';
  }

  @override
  String membersCountLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count участника (вы вышли)',
      many: '$count участников (вы вышли)',
      few: '$count участника (вы вышли)',
      one: '$count участник (вы вышли)',
    );
    return '$_temp0';
  }

  @override
  String get noMessagesYet => 'Сообщений пока нет';

  @override
  String get filesNeedDirectConnection =>
      'Для передачи файлов нужно прямое соединение. Сначала войдите в зону действия Wi-Fi.';

  @override
  String get reply => 'Ответить';

  @override
  String get copyText => 'Копировать текст';

  @override
  String get deleteForMe => 'Удалить у меня';

  @override
  String get disappearingMessages => 'Исчезающие сообщения';

  @override
  String get disappear5Minutes => '5 минут';

  @override
  String get disappear1Hour => '1 час';

  @override
  String get disappear1Day => '1 день';

  @override
  String get disappear1Week => '1 неделя';

  @override
  String get conversationDeleted => 'Чат удалён';

  @override
  String get statusConnected => 'Подключено';

  @override
  String get statusReachableViaMesh => 'Доступен через mesh-сеть';

  @override
  String get statusOfflineDeliverLater => 'Не в сети · будет доставлено позже';

  @override
  String get endToEndEncrypted => 'Сквозное шифрование';

  @override
  String get groupEncryptionHint =>
      'Сообщения шифруются ключами отправителя; читать их могут только участники.';

  @override
  String get directEncryptionHint =>
      'Сообщения защищены сеансом Double Ratchet.';

  @override
  String get noLongerMemberHint => 'Вы больше не участник группы';

  @override
  String get messageHint => 'Сообщение';

  @override
  String attachmentProgress(String percent, String size) {
    return '$percent% · $size';
  }

  @override
  String get sysMemberRemoved => 'Участник удалён';

  @override
  String get sysYouLeftGroup => 'Вы покинули группу';

  @override
  String sysGroupCreated(String name) {
    return 'Группа «$name» создана';
  }

  @override
  String sysMembersAdded(String names) {
    return 'Добавлены: $names';
  }

  @override
  String sysAddedToGroupBy(String name, String who) {
    return '$who добавил(а) вас в группу «$name»';
  }

  @override
  String sysUpdatedMembers(String who) {
    return '$who обновил(а) состав участников';
  }

  @override
  String get sysAMemberWasRemoved => 'Участник был удалён';

  @override
  String get sysYouWereRemoved => 'Вас удалили из группы';

  @override
  String sysLeftGroup(String who) {
    return '$who покинул(а) группу';
  }

  @override
  String sysRenamedGroup(String who, String name) {
    return '$who переименовал(а) группу в «$name»';
  }

  @override
  String get sysGroupUpdated => 'Группа обновлена';

  @override
  String sysKeysRotated(String name) {
    return '$name сменил(а) ключи (проверенный переход)';
  }

  @override
  String get contactNotPinnedYet => 'Контакт ещё не закреплён';

  @override
  String get safetyNumber => 'Код безопасности';

  @override
  String get safetyNumberExplanation =>
      'Если никто не перехватывает соединение, вы оба видите одинаковый код. Сверьте его лично, по телефону или через другой канал, которому вы доверяете.';

  @override
  String get markAsVerified => 'Отметить как проверенный';

  @override
  String get messageAction => 'Написать';

  @override
  String get scanTheirQr => 'Сканировать QR-код собеседника';

  @override
  String get verifiedKeysMatch =>
      'Проверено: ключи соответствуют этому контакту';

  @override
  String cardBelongsToOther(String name) {
    return 'Эта карточка принадлежит $name и закреплена отдельно';
  }

  @override
  String get theirFingerprint => 'Отпечаток собеседника';

  @override
  String get yourFingerprint => 'Ваш отпечаток';

  @override
  String get showThemYourCard => 'Покажите собеседнику свою карточку контакта';

  @override
  String get contactCardContainsOnlyPublicKeys =>
      'Содержит только ваши открытые ключи. Сканирование или вставка карточки закрепляет вашу идентичность на устройстве собеседника.';

  @override
  String get details => 'Подробности';

  @override
  String get nyxChatId => 'NyxChat ID';

  @override
  String get handshake => 'Рукопожатие';

  @override
  String get handshakeValue => 'Гибрид X25519 + ML-KEM-768, подпись Ed25519';

  @override
  String get messagesValue => 'Double Ratchet, AES-256-GCM';

  @override
  String get firstSeen => 'Впервые замечен';

  @override
  String get keysChanged => 'Ключи изменены';

  @override
  String get idCopied => 'ID скопирован';

  @override
  String get giveGroupAName => 'Задайте название группы';

  @override
  String get selectAtLeastOneMember => 'Выберите хотя бы одного участника';

  @override
  String get newGroup => 'Новая группа';

  @override
  String get create => 'Создать';

  @override
  String get groupNameHint => 'Название группы';

  @override
  String get descriptionOptionalHint => 'Описание (необязательно)';

  @override
  String membersSelectedHeader(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'выбрано $count',
      many: 'выбрано $count',
      few: 'выбрано $count',
      one: 'выбран $count',
    );
    return 'Участники · $_temp0';
  }

  @override
  String get noContactsYet =>
      'Контактов пока нет. Сначала подключитесь к кому-нибудь, чтобы закрепить его ключи.';

  @override
  String get noRecentPosition =>
      'Нет актуального местоположения. Введите ячейку geohash вручную или выйдите на открытое место.';

  @override
  String invalidCell(String error) {
    return 'Неверная ячейка: $error';
  }

  @override
  String get noNeighboursKept =>
      'Соседей сейчас нет. Сообщение сохранено и будет отправлено первому появившемуся устройству.';

  @override
  String get areaCellLabel => 'Ячейка местности (geohash)';

  @override
  String get findingYourArea => 'Определяем ваш район...';

  @override
  String meshNeighboursCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count соседа в mesh-сети',
      many: '$count соседей в mesh-сети',
      few: '$count соседа в mesh-сети',
      one: '$count сосед в mesh-сети',
    );
    return '$_temp0';
  }

  @override
  String directLinksCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count прямого соединения',
      many: '$count прямых соединений',
      few: '$count прямых соединения',
      one: '$count прямое соединение',
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
    return 'Прослушивание ячейки $cell ($area) · $neighbours, $links';
  }

  @override
  String get emergencyEmptyHint =>
      'Здесь появляются сообщения от всех, кто запустил NyxChat в этой ячейке. Ваше местоположение не покидает телефон, если вы не добавите его явно.';

  @override
  String get anonymous => 'Аноним';

  @override
  String positionLabel(String coords) {
    return 'Позиция: $coords';
  }

  @override
  String get includeMyName => 'Добавить моё имя';

  @override
  String get includeMyPosition => 'Добавить моё местоположение';

  @override
  String get emergencyComposerHint => 'Что происходит? Где вы?';

  @override
  String get joinCellFirst => 'Сначала присоединитесь к ячейке';

  @override
  String get send => 'Отправить';

  @override
  String get presetNeedHelp => 'Мне нужна помощь';

  @override
  String get presetSafe => 'Я в безопасности';

  @override
  String get presetMedical => 'Нужна медицинская помощь';

  @override
  String get addMembers => 'Добавить участников';

  @override
  String get groupEncryptionExplanation =>
      'Сообщения группы шифруются ключами отправителя каждого участника, которые распространяются по попарным сеансам Double Ratchet. Ключи сменяются каждый раз, когда кто-то выходит из группы.';

  @override
  String memberYou(String name) {
    return '$name (вы)';
  }

  @override
  String get admin => 'Администратор';

  @override
  String get renameGroup => 'Переименовать группу';

  @override
  String get noOtherKnownContacts => 'Других известных контактов нет';

  @override
  String get meshDiagnostics => 'Диагностика mesh-сети';

  @override
  String get statBleLinks => 'Соединения BLE';

  @override
  String get statKnownRoutes => 'Известные маршруты';

  @override
  String get statStoredPackets => 'Сохранённые пакеты';

  @override
  String get statDeliveredToMe => 'Доставлено мне';

  @override
  String get statReceived => 'Получено';

  @override
  String get statForwarded => 'Переслано';

  @override
  String get statDuplicatesDropped => 'Отброшено дубликатов';

  @override
  String get statSeenIds => 'Известные ID';

  @override
  String get linksHeader => 'Соединения';

  @override
  String get noBluetoothLinksHint =>
      'Нет соединений Bluetooth. Устройства в зоне действия соединяются автоматически, пока включены сканирование и вещание.';

  @override
  String get weDialled => 'исходящее';

  @override
  String get theyDialled => 'входящее';

  @override
  String linkSubtitle(String role, int mtu, String address) {
    return '$role · MTU $mtu · $address';
  }

  @override
  String get routingTableHeader => 'Таблица маршрутизации';

  @override
  String get routingTableHint =>
      'Маршруты изучаются по пути, записанному в каждом пакете, и по периодическим маякам.';

  @override
  String routeToken(String prefix) {
    return 'токен $prefix...';
  }

  @override
  String routeVia(String hop, int hops) {
    String _temp0 = intl.Intl.pluralLogic(
      hops,
      locale: localeName,
      other: '$hops перехода',
      many: '$hops переходов',
      few: '$hops перехода',
      one: '$hops переход',
    );
    return 'через ретранслятор $hop... · $_temp0';
  }

  @override
  String get howItWorksHeader => 'Как это работает';

  @override
  String meshExplanation(int copies, int hops) {
    return 'Пакеты адресуются по хешам SHA-256 и несут конверт со сквозным шифрованием. Ретранслятор сохраняет каждый пакет, пересылает его на известный следующий узел или рассылает до $copies копий и отбрасывает после $hops переходов или через 24 часа. Ретрансляторы не могут прочитать, изменить или переадресовать то, что переносят.';
  }

  @override
  String get enterDisplayName =>
      'Введите отображаемое имя (не более 64 символов)';

  @override
  String couldNotCreateIdentity(String error) {
    return 'Не удалось создать идентичность: $error';
  }

  @override
  String get tagline => 'peer-to-peer · шифрование · работа офлайн';

  @override
  String get featureE2eSubtitle =>
      'Double Ratchet с гибридным рукопожатием X25519 + ML-KEM-768';

  @override
  String get featureOfflineTitle => 'Работает без интернета';

  @override
  String get featureOfflineSubtitle =>
      'Wi-Fi LAN и Bluetooth mesh, доставка по принципу store-and-forward';

  @override
  String get featureNoServersTitle => 'Без серверов и аккаунтов';

  @override
  String get featureNoServersSubtitle =>
      'Ваша идентичность — пара ключей, которая никогда не покидает это устройство';

  @override
  String get displayName => 'Отображаемое имя';

  @override
  String get createIdentity => 'Создать идентичность';

  @override
  String get keysGeneratedLocally =>
      'Ключи X25519, Ed25519 и ML-KEM-768 генерируются локально. Ничего никуда не отправляется.';

  @override
  String get passwordRequired => 'Требуется пароль';

  @override
  String get atLeast8Characters => 'Не менее 8 символов';

  @override
  String get passwordsDoNotMatch => 'Пароли не совпадают';

  @override
  String get enterYourPassword => 'Введите пароль';

  @override
  String get allDataWiped => 'Все данные уничтожены.';

  @override
  String get incorrectPassword => 'Неверный пароль';

  @override
  String incorrectPasswordAttemptsLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'осталось $count попытки',
      many: 'осталось $count попыток',
      few: 'осталось $count попытки',
      one: 'осталась $count попытка',
    );
    return 'Неверный пароль · до уничтожения данных $_temp0';
  }

  @override
  String get setAppLock => 'Настроить блокировку приложения';

  @override
  String get nyxChatIsLocked => 'NyxChat заблокирован';

  @override
  String get unlockPrompt =>
      'Ваша база данных зашифрована. Введите пароль, чтобы разблокировать её.';

  @override
  String get passwordSetupExplanation =>
      'Ключ базы данных будет обёрнут ключом, полученным из этого пароля с помощью Argon2id. Восстановление невозможно: забытый пароль означает потерю данных.';

  @override
  String get passwordHint => 'Пароль';

  @override
  String get confirmPasswordHint => 'Подтвердите пароль';

  @override
  String get enableLock => 'Включить блокировку';

  @override
  String get unlock => 'Разблокировать';

  @override
  String get connectedAndAuthenticated => 'Подключено и аутентифицировано';

  @override
  String get connectionFailed =>
      'Не удалось подключиться (недоступен, отказ или несовпадение ключей)';

  @override
  String pinnedAndVerified(String name) {
    return '$name: ключи закреплены и проверены';
  }

  @override
  String invalidContactCard(String error) {
    return 'Неверная карточка контакта: $error';
  }

  @override
  String get findPeople => 'Найти людей';

  @override
  String get visibleToEveryoneNearby => 'Виден всем поблизости';

  @override
  String get visibleSubtitlePublic =>
      'Ваш ID и имя транслируются, чтобы новые люди могли вас найти.';

  @override
  String get visibleSubtitlePrivate =>
      'Приватные маяки: узнать вас могут только закреплённые контакты; остальные видят случайный шум.';

  @override
  String get scanContactQr => 'Сканировать QR-код контакта';

  @override
  String get emergency => 'Экстренная связь';

  @override
  String get nearbyOnWifi => 'Рядом по Wi-Fi';

  @override
  String get nobodyDiscoveredYet =>
      'Пока никого не найдено. Устройства в той же сети Wi-Fi появляются здесь автоматически.';

  @override
  String get bluetoothMesh => 'Mesh-сеть Bluetooth';

  @override
  String get bleNotAvailable => 'Bluetooth LE недоступен на этом устройстве.';

  @override
  String get bleScanningHint =>
      'Идёт сканирование. Другие устройства с NyxChat в зоне действия подключатся автоматически.';

  @override
  String get bleScanningAdvertisingHint =>
      'Идут сканирование и вещание. Другие устройства с NyxChat в зоне действия подключатся автоматически.';

  @override
  String get roleCentral => 'центральное';

  @override
  String get rolePeripheral => 'периферийное';

  @override
  String bleLinkedSubtitle(String role, int mtu) {
    return 'подключено · $role · MTU $mtu';
  }

  @override
  String rssiDbm(int rssi) {
    return '$rssi дБм';
  }

  @override
  String get contacts => 'Контакты';

  @override
  String get contactsPinnedHint =>
      'Здесь закрепляются ключи всех, к кому вы подключаетесь.';

  @override
  String get addContactFromCard => 'Добавить контакт из карточки';

  @override
  String get pasteContactCardHint =>
      'Вставьте текст карточки контакта (показывается как QR-код на экране проверки). Это закрепит и подтвердит ключи контакта.';

  @override
  String get importCard => 'Импортировать карточку';

  @override
  String get manualConnection => 'Ручное подключение';

  @override
  String get ipAddressHint => 'IP-адрес';

  @override
  String get portHint => 'Порт';

  @override
  String get connecting => 'Подключение...';

  @override
  String get globalDirectory => 'Глобальный каталог (DHT, экспериментально)';

  @override
  String get dhtHint =>
      'Нужен доступный узел начальной загрузки. Объявления подписаны; доверие по-прежнему определяется рукопожатием.';

  @override
  String dhtRunning(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count узла',
      many: '$count узлов',
      few: '$count узла',
      one: '$count узел',
    );
    return 'Работает · $_temp0';
  }

  @override
  String get stopped => 'Остановлено';

  @override
  String get stop => 'Остановить';

  @override
  String get start => 'Запустить';

  @override
  String get bootstrapHint => 'bootstrap-узел host:port';

  @override
  String get bootstrapNodeAdded => 'Узел начальной загрузки добавлен';

  @override
  String get lookupHint => 'NC-... для поиска';

  @override
  String get find => 'Найти';

  @override
  String get notFound => 'Не найдено';

  @override
  String foundPeerAt(String name, String address) {
    return '$name найден по адресу $address';
  }

  @override
  String get lanOn => 'LAN вкл.';

  @override
  String get lanOff => 'LAN выкл.';

  @override
  String get bleOn => 'BLE вкл.';

  @override
  String get bleScan => 'BLE скан.';

  @override
  String get bleOff => 'BLE выкл.';

  @override
  String linksCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count соединения',
      many: '$count соединений',
      few: '$count соединения',
      one: '$count соединение',
    );
    return '$_temp0';
  }

  @override
  String get stealth => 'скрытый режим';

  @override
  String get visible => 'виден';

  @override
  String get reachable => 'доступен';

  @override
  String get offlineQueued => 'офлайн, доставка в очереди';

  @override
  String get notANyxChatContactCard => 'Это не карточка контакта NyxChat';

  @override
  String invalidCard(String error) {
    return 'Неверная карточка: $error';
  }

  @override
  String get scanContactCard => 'Сканировать карточку контакта';

  @override
  String get pointCameraHint =>
      'Наведите камеру на QR-код на экране проверки или в настройках собеседника.';

  @override
  String get scanningPinsKeys =>
      'Сканирование закрепляет ключи как проверенные. Ничего не передаётся по сети.';

  @override
  String get security => 'Безопасность';

  @override
  String get databaseLock => 'Блокировка базы данных';

  @override
  String get requirePassword => 'Требовать пароль';

  @override
  String get requirePasswordSubtitle =>
      'Ключ базы данных обёрнут с помощью Argon2id. При утере пароля восстановление невозможно.';

  @override
  String get lockWhenInBackground => 'Блокировать в фоновом режиме';

  @override
  String wipeAfterFailedAttempts(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Уничтожить данные после $count неудачной попытки',
      many: 'Уничтожить данные после $count неудачных попыток',
      few: 'Уничтожить данные после $count неудачных попыток',
      one: 'Уничтожить данные после $count неудачной попытки',
    );
    return '$_temp0';
  }

  @override
  String get duressPassword => 'Пароль под принуждением';

  @override
  String get duressPasswordSet => 'Пароль под принуждением задан';

  @override
  String get setADuressPassword => 'Задать пароль под принуждением';

  @override
  String get duressOpensDecoyAndDestroys =>
      'Открывает ложный профиль и уничтожает настоящий';

  @override
  String get duressOpensEmptyDecoy => 'Открывает пустой ложный профиль';

  @override
  String get duressExplanation =>
      'Ввод этого пароля на экране блокировки открывает пустой ложный профиль';

  @override
  String get removeDuressPassword => 'Удалить пароль под принуждением';

  @override
  String get identity => 'Идентичность';

  @override
  String get rotateIdentityKeys => 'Сменить ключи идентификации';

  @override
  String get rotateIdentitySubtitle =>
      'Новые ключи и новый ID. Контакты, которые сейчас в сети, сразу получат подписанный переход; остальные — при следующем прямом подключении. После этого приложение закроется.';

  @override
  String get backup => 'Резервная копия';

  @override
  String get exportEncryptedBackup =>
      'Экспортировать зашифрованную резервную копию';

  @override
  String get exportBackupSubtitle =>
      'Ключи идентификации, контакты, сеансы и сообщения, запечатанные парольной фразой (Argon2id + AES-256-GCM).';

  @override
  String get restoreFromBackup => 'Восстановить из резервной копии';

  @override
  String get restoreBackupSubtitle =>
      'Заменяет этот профиль. Затем очистите старое устройство: две активные копии одной идентичности расщепляют её сеансы.';

  @override
  String get dangerZone => 'Опасная зона';

  @override
  String get panicWipe => 'Экстренное уничтожение';

  @override
  String get panicWipeSubtitle =>
      'Уничтожает сообщения, контакты, сеансы и ключи идентификации. Необратимо.';

  @override
  String get securityFooter =>
      'Ключи хранятся в защищённом хранилище на основе Android Keystore. База сообщений зашифрована AES-256 случайным мастер-ключом; при включённом пароле этот ключ дополнительно обёрнут AES-256-GCM под ключом, полученным через Argon2id (32 МиБ, 2 прохода).';

  @override
  String get passphraseHint => 'Парольная фраза (от 8 символов)';

  @override
  String get confirmPassphraseHint => 'Подтвердите парольную фразу';

  @override
  String get continueAction => 'Продолжить';

  @override
  String get passphraseTooShortOrMismatch =>
      'Парольная фраза слишком короткая или не совпадает';

  @override
  String get rotateIdentityKeysQuestion => 'Сменить ключи идентификации?';

  @override
  String get rotateIdentityWarning =>
      'Ваш NyxChat ID изменится. Контакты, которые сейчас не в сети, не смогут связаться с вами до следующей прямой встречи.';

  @override
  String get rotate => 'Сменить';

  @override
  String rotationFailed(String error) {
    return 'Не удалось сменить ключи: $error';
  }

  @override
  String get backupPassphrase => 'Парольная фраза резервной копии';

  @override
  String get saveBackupDialogTitle => 'Сохранить резервную копию NyxChat';

  @override
  String get backupCancelled => 'Резервное копирование отменено';

  @override
  String get backupSaved => 'Резервная копия сохранена';

  @override
  String backupFailed(String error) {
    return 'Ошибка резервного копирования: $error';
  }

  @override
  String get replaceThisProfile => 'Заменить этот профиль?';

  @override
  String restoreConfirmBody(String created, String name) {
    return 'Резервная копия от $created для «$name». Всё на этом устройстве будет заменено, и приложение закроется.';
  }

  @override
  String get restore => 'Восстановить';

  @override
  String restoreFailed(String error) {
    return 'Ошибка восстановления: $error';
  }

  @override
  String get duressDifferentFromReal =>
      'Должен отличаться от вашего настоящего пароля';

  @override
  String get alsoDestroyRealProfile => 'Также уничтожить настоящий профиль';

  @override
  String get wipeEverythingQuestion => 'Уничтожить всё?';

  @override
  String get wipeEverythingBody =>
      'Все сообщения, контакты, сеансы и ваши ключи идентификации будут уничтожены на этом устройстве. При следующей встрече собеседники увидят смену ключей.';

  @override
  String get wipe => 'Уничтожить';

  @override
  String get settings => 'Настройки';

  @override
  String get privacy => 'Конфиденциальность';

  @override
  String get blockScreenshots => 'Запретить снимки экрана';

  @override
  String get blockScreenshotsSubtitle =>
      'Скрывает приложение в списке недавних и запрещает запись экрана';

  @override
  String get sendReadReceipts => 'Отправлять отчёты о прочтении';

  @override
  String get notifications => 'Уведомления';

  @override
  String get showMessageTextInNotifications =>
      'Показывать текст сообщений в уведомлениях';

  @override
  String get coverTraffic => 'Маскирующий трафик';

  @override
  String get coverTrafficSubtitle =>
      'Случайные mesh-пакеты, чтобы периоды простоя и активности выглядели одинаково';

  @override
  String get stealthMode => 'Скрытый режим';

  @override
  String get stealthModeSubtitle =>
      'Без вещания и сканирования. Существующие соединения сохраняются.';

  @override
  String get network => 'Сеть';

  @override
  String get localNetwork => 'Локальная сеть';

  @override
  String get active => 'Активна';

  @override
  String get inactive => 'Неактивна';

  @override
  String get directLinks => 'Прямые соединения';

  @override
  String get unsupported => 'Не поддерживается';

  @override
  String advertisingLinks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count соединения',
      many: '$count соединений',
      few: '$count соединения',
      one: '$count соединение',
    );
    return 'Вещание · $_temp0';
  }

  @override
  String scanningLinks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count соединения',
      many: '$count соединений',
      few: '$count соединения',
      one: '$count соединение',
    );
    return 'Сканирование · $_temp0';
  }

  @override
  String get bleLongRange => 'BLE дальнего радиуса (Coded PHY)';

  @override
  String get bleLongRangeSubtitle =>
      'Кодирование Bluetooth 5 S=8: ниже скорость, больше дальность';

  @override
  String get listeningPort => 'Порт прослушивания';

  @override
  String get globalDht => 'Глобальная DHT';

  @override
  String get internetDelivery => 'Доставка через интернет';

  @override
  String get deliverThroughRelays =>
      'Доставлять через публичные ретрансляторы (Nostr)';

  @override
  String get deliverThroughRelaysSubtitle =>
      'Запечатанные конверты под сменяемыми токенами на публичных ретрансляторах Nostr. Без аккаунта и без наших серверов. По умолчанию выключено.';

  @override
  String get routeThroughTor =>
      'Подключаться к ретрансляторам через Tor (Orbot)';

  @override
  String get routeThroughTorSubtitle =>
      'Требуется запущенный Orbot с HTTP-прокси на 127.0.0.1:8118';

  @override
  String get appLockDuressPanic =>
      'Блокировка приложения, пароль под принуждением, экстренное уничтожение';

  @override
  String get about => 'О приложении';

  @override
  String get version => 'Версия';

  @override
  String get protocol => 'Протокол';

  @override
  String protocolValue(String version) {
    return 'v$version · X25519+ML-KEM-768 · Double Ratchet · Sender Keys';
  }

  @override
  String get license => 'Лицензия';

  @override
  String get nyxChatIdCopied => 'NyxChat ID скопирован';

  @override
  String get contactCardCopied => 'Карточка контакта скопирована';

  @override
  String get copyContactCard => 'Копировать карточку контакта';

  @override
  String get shareContactCardHint =>
      'Поделитесь этим, чтобы другие могли закрепить и проверить ваши ключи по другому каналу.';

  @override
  String get appearance => 'Оформление';

  @override
  String get theme => 'Тема';

  @override
  String get themeSystem => 'Системная';

  @override
  String get themeLight => 'Светлая';

  @override
  String get themeDark => 'Тёмная';

  @override
  String get language => 'Язык';

  @override
  String get languageSystemDefault => 'Как в системе';

  @override
  String get wifiAware => 'Wi-Fi Aware';

  @override
  String get useWifiAware => 'Использовать Wi-Fi Aware';

  @override
  String get useWifiAwareSubtitle =>
      'Связь с соседями без точки доступа (Android 8+). Тот же ротируемый маячок, что и у Bluetooth.';

  @override
  String get offlineSessions => 'Офлайн-сессии';

  @override
  String pqReady(int count) {
    return 'Постквантовая прямая секретность готова ($count одноразовых предключей)';
  }

  @override
  String get pqPending =>
      'Постквантовая прямая секретность появится после следующей встречи';

  @override
  String get voiceMessage => 'Голосовое сообщение';

  @override
  String get photo => 'Фото';

  @override
  String get holdToRecord =>
      'Удерживайте микрофон, чтобы записать голосовое сообщение';

  @override
  String get slideToCancel => 'Проведите, чтобы отменить';

  @override
  String get releaseToCancel => 'Отпустите, чтобы отменить';

  @override
  String get recordingUnavailable =>
      'Запись голоса недоступна на этом устройстве';

  @override
  String get microphoneDenied =>
      'Для записи голосовых сообщений нужен доступ к микрофону';

  @override
  String get recordingFailed => 'Не удалось начать запись';

  @override
  String get playbackUnavailable =>
      'Воспроизведение голоса недоступно на этом устройстве';

  @override
  String get playbackFailed =>
      'Не удалось воспроизвести это голосовое сообщение';

  @override
  String get voiceNeedsCarrier =>
      'Для голосовых заметок нужно прямое соединение или путь через mesh-сеть';

  @override
  String get imageUnavailable => 'Изображение недоступно';

  @override
  String get receiving => 'Получение';
}
