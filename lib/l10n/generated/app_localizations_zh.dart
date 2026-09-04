// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => 'NyxChat';

  @override
  String get notificationNewMessage => '新消息';

  @override
  String get notificationChannelMessages => '消息';

  @override
  String get notificationChannelMessagesDescription => 'NyxChat 收到的消息';

  @override
  String get meshChannelName => 'NyxChat 网状网络';

  @override
  String get meshChannelDescription => '在后台保持去中心化网状网络运行。';

  @override
  String get meshNotificationInitial => '网状网络已激活';

  @override
  String get meshNotificationActive => '网状网络与 DHT 路由运行中';

  @override
  String get cancel => '取消';

  @override
  String get save => '保存';

  @override
  String get add => '添加';

  @override
  String get off => '关闭';

  @override
  String get connect => '连接';

  @override
  String get verified => '已验证';

  @override
  String get messages => '消息';

  @override
  String get safetyNumberChangedTitle => '安全码已更改';

  @override
  String safetyNumberChangedBody(String name, String id) {
    return '$name（$id）出示的身份密钥与你已固定的密钥不同。\n\n这可能是因为对方重新安装了应用，也可能是有人在冒充对方。请先当面核对新的安全码，再决定是否接受。在你做出决定之前，连接将保持阻止状态。';
  }

  @override
  String get keepBlocking => '继续阻止';

  @override
  String get acceptNewKeys => '接受新密钥';

  @override
  String get searchConversationsHint => '搜索对话和消息';

  @override
  String get emergencyBroadcastTitle => '紧急广播';

  @override
  String get noConversationsYet => '暂无对话';

  @override
  String get tapPlusToFindPeople => '点按 + 查找附近的人';

  @override
  String get noMatches => '无匹配结果';

  @override
  String get verifySafetyNumber => '验证安全码';

  @override
  String get mute => '静音';

  @override
  String get unmute => '取消静音';

  @override
  String get leaveGroup => '退出群组';

  @override
  String get deleteConversation => '删除对话';

  @override
  String membersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 位成员',
    );
    return '$_temp0';
  }

  @override
  String membersCountLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 位成员（已退出）',
    );
    return '$_temp0';
  }

  @override
  String get noMessagesYet => '暂无消息';

  @override
  String get filesNeedDirectConnection => '发送文件需要直接连接。请先进入 Wi-Fi 范围内。';

  @override
  String get reply => '回复';

  @override
  String get copyText => '复制文本';

  @override
  String get deleteForMe => '为我删除';

  @override
  String get disappearingMessages => '阅后即焚消息';

  @override
  String get disappear5Minutes => '5 分钟';

  @override
  String get disappear1Hour => '1 小时';

  @override
  String get disappear1Day => '1 天';

  @override
  String get disappear1Week => '1 周';

  @override
  String get conversationDeleted => '对话已删除';

  @override
  String get statusConnected => '已连接';

  @override
  String get statusReachableViaMesh => '可通过网状网络到达';

  @override
  String get statusOfflineDeliverLater => '离线 · 稍后送达';

  @override
  String get endToEndEncrypted => '端到端加密';

  @override
  String get groupEncryptionHint => '消息使用每位发送者各自的密钥，只有成员才能读取。';

  @override
  String get directEncryptionHint => '消息由 Double Ratchet 会话保护。';

  @override
  String get noLongerMemberHint => '你已不再是成员';

  @override
  String get messageHint => '消息';

  @override
  String attachmentProgress(String percent, String size) {
    return '$percent% · $size';
  }

  @override
  String get sysMemberRemoved => '成员已被移除';

  @override
  String get sysYouLeftGroup => '你已退出群组';

  @override
  String sysGroupCreated(String name) {
    return '群组“$name”已创建';
  }

  @override
  String sysMembersAdded(String names) {
    return '已添加 $names';
  }

  @override
  String sysAddedToGroupBy(String name, String who) {
    return '$who 已将你添加到“$name”';
  }

  @override
  String sysUpdatedMembers(String who) {
    return '$who 更新了成员';
  }

  @override
  String get sysAMemberWasRemoved => '一位成员已被移除';

  @override
  String get sysYouWereRemoved => '你已被移出群组';

  @override
  String sysLeftGroup(String who) {
    return '$who 退出了群组';
  }

  @override
  String sysRenamedGroup(String who, String name) {
    return '$who 将群组重命名为“$name”';
  }

  @override
  String get sysGroupUpdated => '群组已更新';

  @override
  String sysKeysRotated(String name) {
    return '$name 轮换了密钥（已验证的过渡）';
  }

  @override
  String get contactNotPinnedYet => '尚未固定该联系人';

  @override
  String get safetyNumber => '安全码';

  @override
  String get safetyNumberExplanation =>
      '如果没有人拦截连接，你们双方看到的号码应完全相同。请当面、通过电话或其他你信任的渠道进行比对。';

  @override
  String get markAsVerified => '标记为已验证';

  @override
  String get messageAction => '发消息';

  @override
  String get scanTheirQr => '扫描对方的 QR 码';

  @override
  String get verifiedKeysMatch => '已验证：密钥与此联系人匹配';

  @override
  String cardBelongsToOther(String name) {
    return '该名片属于 $name，已单独固定';
  }

  @override
  String get theirFingerprint => '对方的指纹';

  @override
  String get yourFingerprint => '你的指纹';

  @override
  String get showThemYourCard => '向对方出示你的联系人名片';

  @override
  String get contactCardContainsOnlyPublicKeys =>
      '仅包含你的公钥。对方扫描或粘贴后，即可在其设备上固定你的身份。';

  @override
  String get details => '详情';

  @override
  String get nyxChatId => 'NyxChat ID';

  @override
  String get handshake => '握手';

  @override
  String get handshakeValue => 'X25519 + ML-KEM-768 混合，Ed25519 签名';

  @override
  String get messagesValue => 'Double Ratchet，AES-256-GCM';

  @override
  String get firstSeen => '首次出现';

  @override
  String get keysChanged => '密钥已更改';

  @override
  String get idCopied => 'ID 已复制';

  @override
  String get giveGroupAName => '请为群组命名';

  @override
  String get selectAtLeastOneMember => '请至少选择一位成员';

  @override
  String get newGroup => '新建群组';

  @override
  String get create => '创建';

  @override
  String get groupNameHint => '群组名称';

  @override
  String get descriptionOptionalHint => '描述（可选）';

  @override
  String membersSelectedHeader(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '已选择 $count 位',
    );
    return '成员 · $_temp0';
  }

  @override
  String get noContactsYet => '暂无联系人。请先与某人建立连接，以固定其密钥。';

  @override
  String get noRecentPosition => '没有最近的位置。请手动输入 geohash 单元格，或移动到室外。';

  @override
  String invalidCell(String error) {
    return '无效的单元格：$error';
  }

  @override
  String get noNeighboursKept => '当前没有邻居。你的消息已保存，将发送给第一个出现的设备。';

  @override
  String get areaCellLabel => '区域单元格（geohash）';

  @override
  String get findingYourArea => '正在定位你的区域…';

  @override
  String meshNeighboursCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 个网状邻居',
    );
    return '$_temp0';
  }

  @override
  String directLinksCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 条直接链路',
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
    return '正在监听单元格 $cell（$area）· $neighbours，$links';
  }

  @override
  String get emergencyEmptyHint =>
      '此单元格内任何运行 NyxChat 的人发出的消息都会显示在这里。除非你明确选择包含，否则你的位置绝不会离开手机。';

  @override
  String get anonymous => '匿名';

  @override
  String positionLabel(String coords) {
    return '位置：$coords';
  }

  @override
  String get includeMyName => '包含我的姓名';

  @override
  String get includeMyPosition => '包含我的位置';

  @override
  String get emergencyComposerHint => '发生了什么？你在哪里？';

  @override
  String get joinCellFirst => '请先加入一个单元格';

  @override
  String get send => '发送';

  @override
  String get presetNeedHelp => '我需要帮助';

  @override
  String get presetSafe => '我很安全';

  @override
  String get presetMedical => '医疗紧急情况';

  @override
  String get addMembers => '添加成员';

  @override
  String get groupEncryptionExplanation =>
      '群组消息使用每位成员各自的发送者密钥加密，这些密钥通过成对的 Double Ratchet 会话分发。每当有人退出，密钥都会轮换。';

  @override
  String memberYou(String name) {
    return '$name（你）';
  }

  @override
  String get admin => '管理员';

  @override
  String get renameGroup => '重命名群组';

  @override
  String get noOtherKnownContacts => '没有其他已知联系人';

  @override
  String get meshDiagnostics => '网状网络诊断';

  @override
  String get statBleLinks => 'BLE 链路';

  @override
  String get statKnownRoutes => '已知路由';

  @override
  String get statStoredPackets => '已存储数据包';

  @override
  String get statDeliveredToMe => '送达给我';

  @override
  String get statReceived => '已接收';

  @override
  String get statForwarded => '已转发';

  @override
  String get statDuplicatesDropped => '已丢弃的重复包';

  @override
  String get statSeenIds => '已见 ID';

  @override
  String get linksHeader => '链路';

  @override
  String get noBluetoothLinksHint => '没有蓝牙链路。开启扫描和广播后，范围内的设备会自动建立链路。';

  @override
  String get weDialled => '我方发起';

  @override
  String get theyDialled => '对方发起';

  @override
  String linkSubtitle(String role, int mtu, String address) {
    return '$role · MTU $mtu · $address';
  }

  @override
  String get routingTableHeader => '路由表';

  @override
  String get routingTableHint => '路由是从每个数据包中记录的路径以及周期性信标中学习到的。';

  @override
  String routeToken(String prefix) {
    return '令牌 $prefix...';
  }

  @override
  String routeVia(String hop, int hops) {
    String _temp0 = intl.Intl.pluralLogic(
      hops,
      locale: localeName,
      other: '$hops 跳',
    );
    return '经由中继 $hop... · $_temp0';
  }

  @override
  String get howItWorksHeader => '工作原理';

  @override
  String meshExplanation(int copies, int hops) {
    return '数据包以 SHA-256 哈希寻址，并携带端到端加密的信封。中继会存储每个数据包，将其转发到已学习的下一跳，或最多喷洒 $copies 份副本，并在 $hops 跳或 24 小时后将其丢弃。中继无法读取、篡改或重新寻址其所传递的内容。';
  }

  @override
  String get enterDisplayName => '请输入显示名称（最多 64 个字符）';

  @override
  String couldNotCreateIdentity(String error) {
    return '无法创建身份：$error';
  }

  @override
  String get tagline => '点对点 · 加密 · 可离线使用';

  @override
  String get featureE2eSubtitle => 'Double Ratchet，配合 X25519 + ML-KEM-768 混合握手';

  @override
  String get featureOfflineTitle => '无需互联网也能使用';

  @override
  String get featureOfflineSubtitle => 'Wi-Fi LAN 与蓝牙网状网络，存储转发式投递';

  @override
  String get featureNoServersTitle => '无服务器，无账户';

  @override
  String get featureNoServersSubtitle => '你的身份是一对永不离开此设备的密钥';

  @override
  String get displayName => '显示名称';

  @override
  String get createIdentity => '创建身份';

  @override
  String get keysGeneratedLocally =>
      '在本地生成 X25519、Ed25519 和 ML-KEM-768 密钥。不会上传任何内容。';

  @override
  String get passwordRequired => '必须输入密码';

  @override
  String get atLeast8Characters => '至少 8 个字符';

  @override
  String get passwordsDoNotMatch => '两次输入的密码不一致';

  @override
  String get enterYourPassword => '请输入密码';

  @override
  String get allDataWiped => '所有数据已被抹除。';

  @override
  String get incorrectPassword => '密码错误';

  @override
  String incorrectPasswordAttemptsLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 次',
    );
    return '密码错误 · 还可尝试 $_temp0，之后将抹除数据';
  }

  @override
  String get setAppLock => '设置应用锁';

  @override
  String get nyxChatIsLocked => 'NyxChat 已锁定';

  @override
  String get unlockPrompt => '你的数据库已加密。请输入密码解锁。';

  @override
  String get passwordSetupExplanation =>
      '数据库密钥将使用由此密码通过 Argon2id 派生的密钥进行封装。没有任何恢复途径：忘记密码意味着数据将永久丢失。';

  @override
  String get passwordHint => '密码';

  @override
  String get confirmPasswordHint => '确认密码';

  @override
  String get enableLock => '启用锁定';

  @override
  String get unlock => '解锁';

  @override
  String get connectedAndAuthenticated => '已连接并通过认证';

  @override
  String get connectionFailed => '连接失败（无法到达、被拒绝或密钥不匹配）';

  @override
  String pinnedAndVerified(String name) {
    return '已固定并验证 $name';
  }

  @override
  String invalidContactCard(String error) {
    return '无效的联系人名片：$error';
  }

  @override
  String get findPeople => '查找联系人';

  @override
  String get visibleToEveryoneNearby => '对附近所有人可见';

  @override
  String get visibleSubtitlePublic => '你的 ID 和名称会被广播，以便新的人找到你。';

  @override
  String get visibleSubtitlePrivate => '私密信标：只有已固定的联系人能识别你；其他人只会看到随机噪声。';

  @override
  String get scanContactQr => '扫描联系人 QR 码';

  @override
  String get emergency => '紧急';

  @override
  String get nearbyOnWifi => 'Wi-Fi 上的附近设备';

  @override
  String get nobodyDiscoveredYet => '尚未发现任何人。同一 Wi-Fi 上的对等设备会自动显示在这里。';

  @override
  String get bluetoothMesh => '蓝牙网状网络';

  @override
  String get bleNotAvailable => '此设备不支持低功耗蓝牙。';

  @override
  String get bleScanningHint => '正在扫描。范围内的其他 NyxChat 设备会自动建立链路。';

  @override
  String get bleScanningAdvertisingHint => '正在扫描并广播。范围内的其他 NyxChat 设备会自动建立链路。';

  @override
  String get roleCentral => '中心设备';

  @override
  String get rolePeripheral => '外围设备';

  @override
  String bleLinkedSubtitle(String role, int mtu) {
    return '已链接 · $role · MTU $mtu';
  }

  @override
  String rssiDbm(int rssi) {
    return '$rssi dBm';
  }

  @override
  String get contacts => '联系人';

  @override
  String get contactsPinnedHint => '你连接过的每个对等方的密钥都固定在这里。';

  @override
  String get addContactFromCard => '通过名片添加联系人';

  @override
  String get pasteContactCardHint =>
      '粘贴联系人名片的文本（在“验证”页面以 QR 码显示）。这将固定并验证对方的密钥。';

  @override
  String get importCard => '导入名片';

  @override
  String get manualConnection => '手动连接';

  @override
  String get ipAddressHint => 'IP 地址';

  @override
  String get portHint => '端口';

  @override
  String get connecting => '正在连接…';

  @override
  String get globalDirectory => '全球目录（DHT，实验性）';

  @override
  String get dhtHint => '需要一个可到达的引导节点。公告已签名；信任仍由握手决定。';

  @override
  String dhtRunning(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 个节点',
    );
    return '运行中 · $_temp0';
  }

  @override
  String get stopped => '已停止';

  @override
  String get stop => '停止';

  @override
  String get start => '启动';

  @override
  String get bootstrapHint => '引导节点 host:port';

  @override
  String get bootstrapNodeAdded => '引导节点已添加';

  @override
  String get lookupHint => '要查找的 NC-...';

  @override
  String get find => '查找';

  @override
  String get notFound => '未找到';

  @override
  String foundPeerAt(String name, String address) {
    return '在 $address 找到 $name';
  }

  @override
  String get lanOn => 'LAN 开启';

  @override
  String get lanOff => 'LAN 关闭';

  @override
  String get bleOn => 'BLE 开启';

  @override
  String get bleScan => 'BLE 扫描';

  @override
  String get bleOff => 'BLE 关闭';

  @override
  String linksCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 条链路',
    );
    return '$_temp0';
  }

  @override
  String get stealth => '隐身';

  @override
  String get visible => '可见';

  @override
  String get reachable => '可到达';

  @override
  String get offlineQueued => '离线，排队等待投递';

  @override
  String get notANyxChatContactCard => '不是 NyxChat 联系人名片';

  @override
  String invalidCard(String error) {
    return '无效的名片：$error';
  }

  @override
  String get scanContactCard => '扫描联系人名片';

  @override
  String get pointCameraHint => '将相机对准对方“验证”页面或“设置”页面上的 QR 码。';

  @override
  String get scanningPinsKeys => '扫描后会将对方的密钥固定为已验证。不会通过网络发送任何内容。';

  @override
  String get security => '安全';

  @override
  String get databaseLock => '数据库锁';

  @override
  String get requirePassword => '需要密码';

  @override
  String get requirePasswordSubtitle => '数据库密钥由 Argon2id 封装。忘记密码将无法恢复。';

  @override
  String get lockWhenInBackground => '进入后台时锁定';

  @override
  String wipeAfterFailedAttempts(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '失败 $count 次后抹除数据',
    );
    return '$_temp0';
  }

  @override
  String get duressPassword => '胁迫密码';

  @override
  String get duressPasswordSet => '已设置胁迫密码';

  @override
  String get setADuressPassword => '设置胁迫密码';

  @override
  String get duressOpensDecoyAndDestroys => '打开诱饵配置文件并销毁真实配置文件';

  @override
  String get duressOpensEmptyDecoy => '打开一个空的诱饵配置文件';

  @override
  String get duressExplanation => '在锁定屏幕输入此密码会打开一个空的诱饵配置文件';

  @override
  String get removeDuressPassword => '移除胁迫密码';

  @override
  String get identity => '身份';

  @override
  String get rotateIdentityKeys => '轮换身份密钥';

  @override
  String get rotateIdentitySubtitle =>
      '生成新的密钥和标识。当前在线的联系人会立即收到签名的过渡通知；其他联系人会在你下次直接连接时收到。完成后应用将关闭。';

  @override
  String get backup => '备份';

  @override
  String get exportEncryptedBackup => '导出加密备份';

  @override
  String get exportBackupSubtitle =>
      '身份密钥、联系人、会话和消息，使用口令加密封存（Argon2id + AES-256-GCM）。';

  @override
  String get restoreFromBackup => '从备份恢复';

  @override
  String get restoreBackupSubtitle => '将替换此配置文件。之后请抹除旧设备：同一身份的两个活动副本会导致会话分叉。';

  @override
  String get dangerZone => '危险区域';

  @override
  String get panicWipe => '紧急抹除';

  @override
  String get panicWipeSubtitle => '销毁消息、联系人、会话和身份密钥。不可撤销。';

  @override
  String get securityFooter =>
      '密钥保存在由 Android 密钥库支持的安全存储中。消息数据库使用随机主密钥进行 AES-256 加密；启用密码后，该密钥还会在 Argon2id 派生密钥（32 MiB，2 轮）下额外使用 AES-256-GCM 封装。';

  @override
  String get passphraseHint => '口令（8 个字符以上）';

  @override
  String get confirmPassphraseHint => '确认口令';

  @override
  String get continueAction => '继续';

  @override
  String get passphraseTooShortOrMismatch => '口令太短或不一致';

  @override
  String get rotateIdentityKeysQuestion => '轮换身份密钥？';

  @override
  String get rotateIdentityWarning =>
      '你的 NyxChat ID 将会改变。离线的联系人在与你再次直接见面之前将无法联系你。';

  @override
  String get rotate => '轮换';

  @override
  String rotationFailed(String error) {
    return '轮换失败：$error';
  }

  @override
  String get backupPassphrase => '备份口令';

  @override
  String get saveBackupDialogTitle => '保存 NyxChat 备份';

  @override
  String get backupCancelled => '备份已取消';

  @override
  String get backupSaved => '备份已保存';

  @override
  String backupFailed(String error) {
    return '备份失败：$error';
  }

  @override
  String get replaceThisProfile => '替换此配置文件？';

  @override
  String restoreConfirmBody(String created, String name) {
    return '来自 $created 的“$name”的备份。此设备上的所有内容都将被替换，应用随后将关闭。';
  }

  @override
  String get restore => '恢复';

  @override
  String restoreFailed(String error) {
    return '恢复失败：$error';
  }

  @override
  String get duressDifferentFromReal => '与你的真实密码不同';

  @override
  String get alsoDestroyRealProfile => '同时销毁真实配置文件';

  @override
  String get wipeEverythingQuestion => '抹除所有数据？';

  @override
  String get wipeEverythingBody =>
      '此设备上的所有消息、联系人、会话和身份密钥都将被销毁。对等方在下次与你见面时会看到密钥变更。';

  @override
  String get wipe => '抹除';

  @override
  String get settings => '设置';

  @override
  String get privacy => '隐私';

  @override
  String get blockScreenshots => '禁止截屏';

  @override
  String get blockScreenshotsSubtitle => '在最近任务中隐藏本应用并阻止屏幕捕获';

  @override
  String get sendReadReceipts => '发送已读回执';

  @override
  String get notifications => '通知';

  @override
  String get showMessageTextInNotifications => '在通知中显示消息内容';

  @override
  String get coverTraffic => '掩护流量';

  @override
  String get coverTrafficSubtitle => '发送随机网状数据包，使空闲与活跃时段看起来一致';

  @override
  String get stealthMode => '隐身模式';

  @override
  String get stealthModeSubtitle => '不广播也不扫描。现有链路保持连接。';

  @override
  String get network => '网络';

  @override
  String get localNetwork => '本地网络';

  @override
  String get active => '运行中';

  @override
  String get inactive => '未运行';

  @override
  String get directLinks => '直接链路';

  @override
  String get unsupported => '不支持';

  @override
  String advertisingLinks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 条链路',
    );
    return '广播中 · $_temp0';
  }

  @override
  String scanningLinks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 条链路',
    );
    return '扫描中 · $_temp0';
  }

  @override
  String get bleLongRange => 'BLE 长距离模式（Coded PHY）';

  @override
  String get bleLongRangeSubtitle => '蓝牙 5 S=8 编码；吞吐量较低，覆盖距离更远';

  @override
  String get listeningPort => '监听端口';

  @override
  String get globalDht => '全球 DHT';

  @override
  String get internetDelivery => '互联网投递';

  @override
  String get deliverThroughRelays => '通过公共中继投递（Nostr）';

  @override
  String get deliverThroughRelaysSubtitle =>
      '在公共 Nostr 中继上以轮换令牌发布密封信封。无需账户，我们也没有服务器。默认关闭。';

  @override
  String get routeThroughTor => '通过 Tor（Orbot）路由中继';

  @override
  String get routeThroughTorSubtitle =>
      '需要 Orbot 正在运行，且其 HTTP 代理位于 127.0.0.1:8118';

  @override
  String get appLockDuressPanic => '应用锁、胁迫密码、紧急抹除';

  @override
  String get about => '关于';

  @override
  String get version => '版本';

  @override
  String get protocol => '协议';

  @override
  String protocolValue(String version) {
    return 'v$version · X25519+ML-KEM-768 · Double Ratchet · Sender Keys';
  }

  @override
  String get license => '许可证';

  @override
  String get nyxChatIdCopied => 'NyxChat ID 已复制';

  @override
  String get contactCardCopied => '联系人名片已复制';

  @override
  String get copyContactCard => '复制联系人名片';

  @override
  String get shareContactCardHint => '分享此名片，以便他人通过带外方式固定并验证你的密钥。';

  @override
  String get appearance => '外观';

  @override
  String get theme => '主题';

  @override
  String get themeSystem => '跟随系统';

  @override
  String get themeLight => '浅色';

  @override
  String get themeDark => '深色';

  @override
  String get language => '语言';

  @override
  String get languageSystemDefault => '系统默认';

  @override
  String get wifiAware => 'Wi-Fi Aware';

  @override
  String get useWifiAware => '使用 Wi-Fi Aware';

  @override
  String get useWifiAwareSubtitle => '无需接入点的邻近链路（Android 8+）。与蓝牙相同的轮换信标。';

  @override
  String get offlineSessions => '离线会话';

  @override
  String pqReady(int count) {
    return '后量子前向保密已就绪（$count 个一次性预共享密钥）';
  }

  @override
  String get pqPending => '后量子前向保密待下次见面后启用';

  @override
  String get voiceMessage => '语音消息';

  @override
  String get photo => '照片';

  @override
  String get holdToRecord => '按住麦克风录制语音消息';

  @override
  String get slideToCancel => '滑动以取消';

  @override
  String get releaseToCancel => '松开以取消';

  @override
  String get recordingUnavailable => '此设备不支持语音录制';

  @override
  String get microphoneDenied => '录制语音消息需要麦克风权限';

  @override
  String get recordingFailed => '无法开始录制';

  @override
  String get playbackUnavailable => '此设备不支持语音播放';

  @override
  String get playbackFailed => '无法播放此语音消息';

  @override
  String get voiceNeedsCarrier => '语音留言需要直接连接或网状路径';

  @override
  String get imageUnavailable => '图片不可用';

  @override
  String get receiving => '接收中';
}
