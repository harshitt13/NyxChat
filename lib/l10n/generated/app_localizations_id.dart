// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Indonesian (`id`).
class AppLocalizationsId extends AppLocalizations {
  AppLocalizationsId([String locale = 'id']) : super(locale);

  @override
  String get appTitle => 'NyxChat';

  @override
  String get notificationNewMessage => 'Pesan baru';

  @override
  String get notificationChannelMessages => 'Pesan';

  @override
  String get notificationChannelMessagesDescription => 'Pesan NyxChat masuk';

  @override
  String get meshChannelName => 'Jaringan Mesh NyxChat';

  @override
  String get meshChannelDescription =>
      'Menjaga jaringan mesh terdesentralisasi tetap berjalan di latar belakang.';

  @override
  String get meshNotificationInitial => 'Jaringan Mesh aktif';

  @override
  String get meshNotificationActive => 'Perutean mesh dan DHT aktif';

  @override
  String get cancel => 'Batal';

  @override
  String get save => 'Simpan';

  @override
  String get add => 'Tambah';

  @override
  String get off => 'Nonaktif';

  @override
  String get connect => 'Hubungkan';

  @override
  String get verified => 'Terverifikasi';

  @override
  String get messages => 'Pesan';

  @override
  String get safetyNumberChangedTitle => 'Nomor keamanan berubah';

  @override
  String safetyNumberChangedBody(String name, String id) {
    return '$name ($id) menunjukkan kunci identitas yang berbeda dari yang telah Anda sematkan.\n\nIni terjadi jika mereka memasang ulang aplikasi, atau jika seseorang menyamar sebagai mereka. Verifikasi nomor keamanan yang baru secara langsung sebelum menerimanya. Koneksi tetap diblokir sampai Anda memutuskan.';
  }

  @override
  String get keepBlocking => 'Tetap blokir';

  @override
  String get acceptNewKeys => 'Terima kunci baru';

  @override
  String get searchConversationsHint => 'Cari percakapan dan pesan';

  @override
  String get emergencyBroadcastTitle => 'Siaran darurat';

  @override
  String get noConversationsYet => 'Belum ada percakapan';

  @override
  String get tapPlusToFindPeople => 'Ketuk + untuk menemukan orang di sekitar';

  @override
  String get noMatches => 'Tidak ada yang cocok';

  @override
  String get verifySafetyNumber => 'Verifikasi nomor keamanan';

  @override
  String get mute => 'Bisukan';

  @override
  String get unmute => 'Bunyikan';

  @override
  String get leaveGroup => 'Keluar dari grup';

  @override
  String get deleteConversation => 'Hapus percakapan';

  @override
  String membersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count anggota',
    );
    return '$_temp0';
  }

  @override
  String membersCountLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count anggota (sudah keluar)',
    );
    return '$_temp0';
  }

  @override
  String get noMessagesYet => 'Belum ada pesan';

  @override
  String get filesNeedDirectConnection =>
      'File memerlukan koneksi langsung. Masuklah ke jangkauan Wi-Fi terlebih dahulu.';

  @override
  String get reply => 'Balas';

  @override
  String get copyText => 'Salin teks';

  @override
  String get deleteForMe => 'Hapus untuk saya';

  @override
  String get disappearingMessages => 'Pesan sementara';

  @override
  String get disappear5Minutes => '5 menit';

  @override
  String get disappear1Hour => '1 jam';

  @override
  String get disappear1Day => '1 hari';

  @override
  String get disappear1Week => '1 minggu';

  @override
  String get conversationDeleted => 'Percakapan dihapus';

  @override
  String get statusConnected => 'Terhubung';

  @override
  String get statusReachableViaMesh => 'Terjangkau via mesh';

  @override
  String get statusOfflineDeliverLater => 'Offline · akan dikirim nanti';

  @override
  String get endToEndEncrypted => 'Terenkripsi end-to-end';

  @override
  String get groupEncryptionHint =>
      'Pesan menggunakan kunci per pengirim; hanya anggota yang dapat membacanya.';

  @override
  String get directEncryptionHint =>
      'Pesan dilindungi oleh sesi Double Ratchet.';

  @override
  String get noLongerMemberHint => 'Anda bukan lagi anggota';

  @override
  String get messageHint => 'Pesan';

  @override
  String attachmentProgress(String percent, String size) {
    return '$percent% · $size';
  }

  @override
  String get sysMemberRemoved => 'Anggota dikeluarkan';

  @override
  String get sysYouLeftGroup => 'Anda keluar dari grup';

  @override
  String sysGroupCreated(String name) {
    return 'Grup \"$name\" dibuat';
  }

  @override
  String sysMembersAdded(String names) {
    return '$names ditambahkan';
  }

  @override
  String sysAddedToGroupBy(String name, String who) {
    return 'Anda ditambahkan ke \"$name\" oleh $who';
  }

  @override
  String sysUpdatedMembers(String who) {
    return '$who memperbarui daftar anggota';
  }

  @override
  String get sysAMemberWasRemoved => 'Seorang anggota dikeluarkan';

  @override
  String get sysYouWereRemoved => 'Anda dikeluarkan dari grup';

  @override
  String sysLeftGroup(String who) {
    return '$who keluar dari grup';
  }

  @override
  String sysRenamedGroup(String who, String name) {
    return '$who mengganti nama grup menjadi \"$name\"';
  }

  @override
  String get sysGroupUpdated => 'Grup diperbarui';

  @override
  String sysKeysRotated(String name) {
    return '$name merotasi kuncinya (transisi terverifikasi)';
  }

  @override
  String get contactNotPinnedYet => 'Kontak belum disematkan';

  @override
  String get safetyNumber => 'Nomor keamanan';

  @override
  String get safetyNumberExplanation =>
      'Anda berdua melihat nomor yang sama jika tidak ada yang menyadap koneksi. Bandingkan secara langsung, lewat telepon, atau melalui saluran lain yang Anda percayai.';

  @override
  String get markAsVerified => 'Tandai terverifikasi';

  @override
  String get messageAction => 'Kirim pesan';

  @override
  String get scanTheirQr => 'Pindai kode QR mereka';

  @override
  String get verifiedKeysMatch =>
      'Terverifikasi: kunci cocok dengan kontak ini';

  @override
  String cardBelongsToOther(String name) {
    return 'Kartu itu milik $name, disematkan secara terpisah';
  }

  @override
  String get theirFingerprint => 'Sidik jari mereka';

  @override
  String get yourFingerprint => 'Sidik jari Anda';

  @override
  String get showThemYourCard => 'Tunjukkan kartu kontak Anda';

  @override
  String get contactCardContainsOnlyPublicKeys =>
      'Hanya berisi kunci publik Anda. Memindai atau menempelkannya akan menyematkan identitas Anda di perangkat mereka.';

  @override
  String get details => 'Detail';

  @override
  String get nyxChatId => 'ID NyxChat';

  @override
  String get handshake => 'Jabat tangan';

  @override
  String get handshakeValue =>
      'Hibrida X25519 + ML-KEM-768, ditandatangani Ed25519';

  @override
  String get messagesValue => 'Double Ratchet, AES-256-GCM';

  @override
  String get firstSeen => 'Pertama terlihat';

  @override
  String get keysChanged => 'Kunci berubah';

  @override
  String get idCopied => 'ID disalin';

  @override
  String get giveGroupAName => 'Beri nama grup';

  @override
  String get selectAtLeastOneMember => 'Pilih minimal satu anggota';

  @override
  String get newGroup => 'Grup baru';

  @override
  String get create => 'Buat';

  @override
  String get groupNameHint => 'Nama grup';

  @override
  String get descriptionOptionalHint => 'Deskripsi (opsional)';

  @override
  String membersSelectedHeader(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count dipilih',
    );
    return 'Anggota · $_temp0';
  }

  @override
  String get noContactsYet =>
      'Belum ada kontak. Hubungkan ke seseorang terlebih dahulu agar kuncinya disematkan.';

  @override
  String get noRecentPosition =>
      'Tidak ada posisi terbaru. Masukkan sel geohash secara manual atau pindah ke luar ruangan.';

  @override
  String invalidCell(String error) {
    return 'Sel tidak valid: $error';
  }

  @override
  String get noNeighboursKept =>
      'Tidak ada tetangga saat ini. Pesan Anda disimpan dan dikirim ke perangkat pertama yang muncul.';

  @override
  String get areaCellLabel => 'Sel area (geohash)';

  @override
  String get findingYourArea => 'Mencari area Anda...';

  @override
  String meshNeighboursCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tetangga mesh',
    );
    return '$_temp0';
  }

  @override
  String directLinksCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tautan langsung',
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
    return 'Mendengarkan di sel $cell ($area) · $neighbours, $links';
  }

  @override
  String get emergencyEmptyHint =>
      'Pesan dari siapa pun yang menjalankan NyxChat di sel ini muncul di sini. Posisi Anda tidak pernah meninggalkan ponsel kecuali Anda menyertakannya secara eksplisit.';

  @override
  String get anonymous => 'Anonim';

  @override
  String positionLabel(String coords) {
    return 'Posisi: $coords';
  }

  @override
  String get includeMyName => 'Sertakan nama saya';

  @override
  String get includeMyPosition => 'Sertakan posisi saya';

  @override
  String get emergencyComposerHint => 'Apa yang terjadi? Di mana Anda?';

  @override
  String get joinCellFirst => 'Gabung ke sel terlebih dahulu';

  @override
  String get send => 'Kirim';

  @override
  String get presetNeedHelp => 'Saya butuh bantuan';

  @override
  String get presetSafe => 'Saya aman';

  @override
  String get presetMedical => 'Darurat medis';

  @override
  String get addMembers => 'Tambah anggota';

  @override
  String get groupEncryptionExplanation =>
      'Pesan grup dienkripsi dengan kunci pengirim per anggota yang didistribusikan melalui sesi Double Ratchet berpasangan. Kunci dirotasi setiap kali seseorang keluar.';

  @override
  String memberYou(String name) {
    return '$name (Anda)';
  }

  @override
  String get admin => 'Admin';

  @override
  String get renameGroup => 'Ganti nama grup';

  @override
  String get noOtherKnownContacts => 'Tidak ada kontak lain yang dikenal';

  @override
  String get meshDiagnostics => 'Diagnostik mesh';

  @override
  String get statBleLinks => 'Tautan BLE';

  @override
  String get statKnownRoutes => 'Rute diketahui';

  @override
  String get statStoredPackets => 'Paket tersimpan';

  @override
  String get statDeliveredToMe => 'Terkirim ke saya';

  @override
  String get statReceived => 'Diterima';

  @override
  String get statForwarded => 'Diteruskan';

  @override
  String get statDuplicatesDropped => 'Duplikat dibuang';

  @override
  String get statSeenIds => 'ID terlihat';

  @override
  String get linksHeader => 'Tautan';

  @override
  String get noBluetoothLinksHint =>
      'Tidak ada tautan Bluetooth. Perangkat dalam jangkauan tertaut otomatis selama pemindaian dan penyiaran aktif.';

  @override
  String get weDialled => 'kami menghubungi';

  @override
  String get theyDialled => 'mereka menghubungi';

  @override
  String linkSubtitle(String role, int mtu, String address) {
    return '$role · MTU $mtu · $address';
  }

  @override
  String get routingTableHeader => 'Tabel perutean';

  @override
  String get routingTableHint =>
      'Rute dipelajari dari jalur yang tercatat di setiap paket dan dari beacon berkala.';

  @override
  String routeToken(String prefix) {
    return 'token $prefix...';
  }

  @override
  String routeVia(String hop, int hops) {
    String _temp0 = intl.Intl.pluralLogic(
      hops,
      locale: localeName,
      other: '$hops hop',
    );
    return 'via relai $hop... · $_temp0';
  }

  @override
  String get howItWorksHeader => 'Cara kerjanya';

  @override
  String meshExplanation(int copies, int hops) {
    return 'Paket dialamatkan dengan hash SHA-256 dan membawa amplop terenkripsi end-to-end. Relai menyimpan setiap paket, meneruskannya ke hop berikutnya yang telah dipelajari atau menyebarkan hingga $copies salinan, lalu membuangnya setelah $hops hop atau 24 jam. Relai tidak dapat membaca, mengubah, atau mengalamatkan ulang apa yang dibawanya.';
  }

  @override
  String get enterDisplayName => 'Masukkan nama tampilan (maks. 64 karakter)';

  @override
  String couldNotCreateIdentity(String error) {
    return 'Tidak dapat membuat identitas: $error';
  }

  @override
  String get tagline => 'peer-to-peer · terenkripsi · dapat digunakan offline';

  @override
  String get featureE2eSubtitle =>
      'Double Ratchet dengan jabat tangan hibrida X25519 + ML-KEM-768';

  @override
  String get featureOfflineTitle => 'Bekerja tanpa internet';

  @override
  String get featureOfflineSubtitle =>
      'LAN Wi-Fi dan mesh Bluetooth, pengiriman store-and-forward';

  @override
  String get featureNoServersTitle => 'Tanpa server, tanpa akun';

  @override
  String get featureNoServersSubtitle =>
      'Identitas Anda adalah pasangan kunci yang tidak pernah meninggalkan perangkat ini';

  @override
  String get displayName => 'Nama tampilan';

  @override
  String get createIdentity => 'Buat identitas';

  @override
  String get keysGeneratedLocally =>
      'Membuat kunci X25519, Ed25519, dan ML-KEM-768 secara lokal. Tidak ada yang diunggah.';

  @override
  String get passwordRequired => 'Sandi wajib diisi';

  @override
  String get atLeast8Characters => 'Minimal 8 karakter';

  @override
  String get passwordsDoNotMatch => 'Sandi tidak cocok';

  @override
  String get enterYourPassword => 'Masukkan sandi Anda';

  @override
  String get allDataWiped => 'Semua data telah dihapus.';

  @override
  String get incorrectPassword => 'Sandi salah';

  @override
  String incorrectPasswordAttemptsLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count percobaan',
    );
    return 'Sandi salah · $_temp0 tersisa sebelum penghapusan';
  }

  @override
  String get setAppLock => 'Setel kunci aplikasi';

  @override
  String get nyxChatIsLocked => 'NyxChat terkunci';

  @override
  String get unlockPrompt =>
      'Database Anda terenkripsi. Masukkan sandi untuk membuka kunci.';

  @override
  String get passwordSetupExplanation =>
      'Kunci database akan dibungkus dengan kunci yang diturunkan dari sandi ini menggunakan Argon2id. Tidak ada pemulihan: sandi yang terlupa berarti data hilang.';

  @override
  String get passwordHint => 'Sandi';

  @override
  String get confirmPasswordHint => 'Konfirmasi sandi';

  @override
  String get enableLock => 'Aktifkan kunci';

  @override
  String get unlock => 'Buka kunci';

  @override
  String get connectedAndAuthenticated => 'Terhubung dan terautentikasi';

  @override
  String get connectionFailed =>
      'Koneksi gagal (tidak terjangkau, ditolak, atau kunci tidak cocok)';

  @override
  String pinnedAndVerified(String name) {
    return '$name disematkan dan diverifikasi';
  }

  @override
  String invalidContactCard(String error) {
    return 'Kartu kontak tidak valid: $error';
  }

  @override
  String get findPeople => 'Temukan orang';

  @override
  String get visibleToEveryoneNearby => 'Terlihat oleh semua orang di sekitar';

  @override
  String get visibleSubtitlePublic =>
      'ID dan nama Anda disiarkan agar orang baru dapat menemukan Anda.';

  @override
  String get visibleSubtitlePrivate =>
      'Beacon privat: hanya kontak yang disematkan yang dapat mengenali Anda; yang lain melihat derau acak.';

  @override
  String get scanContactQr => 'Pindai QR kontak';

  @override
  String get emergency => 'Darurat';

  @override
  String get nearbyOnWifi => 'Di sekitar via Wi-Fi';

  @override
  String get nobodyDiscoveredYet =>
      'Belum ada yang ditemukan. Peer di Wi-Fi yang sama muncul di sini secara otomatis.';

  @override
  String get bluetoothMesh => 'Mesh Bluetooth';

  @override
  String get bleNotAvailable => 'Bluetooth LE tidak tersedia di perangkat ini.';

  @override
  String get bleScanningHint =>
      'Memindai. Perangkat NyxChat lain dalam jangkauan akan tertaut otomatis.';

  @override
  String get bleScanningAdvertisingHint =>
      'Memindai dan menyiarkan. Perangkat NyxChat lain dalam jangkauan akan tertaut otomatis.';

  @override
  String get roleCentral => 'sentral';

  @override
  String get rolePeripheral => 'periferal';

  @override
  String bleLinkedSubtitle(String role, int mtu) {
    return 'tertaut · $role · MTU $mtu';
  }

  @override
  String rssiDbm(int rssi) {
    return '$rssi dBm';
  }

  @override
  String get contacts => 'Kontak';

  @override
  String get contactsPinnedHint =>
      'Kunci setiap peer yang Anda hubungi disematkan di sini.';

  @override
  String get addContactFromCard => 'Tambah kontak dari kartu';

  @override
  String get pasteContactCardHint =>
      'Tempel teks kartu kontak (ditampilkan sebagai QR di Verifikasi). Ini menyematkan dan memverifikasi kunci mereka.';

  @override
  String get importCard => 'Impor kartu';

  @override
  String get manualConnection => 'Koneksi manual';

  @override
  String get ipAddressHint => 'Alamat IP';

  @override
  String get portHint => 'Port';

  @override
  String get connecting => 'Menghubungkan...';

  @override
  String get globalDirectory => 'Direktori global (DHT, eksperimental)';

  @override
  String get dhtHint =>
      'Memerlukan node bootstrap yang terjangkau. Pengumuman ditandatangani; jabat tangan tetap menentukan kepercayaan.';

  @override
  String dhtRunning(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count node',
    );
    return 'Berjalan · $_temp0';
  }

  @override
  String get stopped => 'Berhenti';

  @override
  String get stop => 'Hentikan';

  @override
  String get start => 'Mulai';

  @override
  String get bootstrapHint => 'host:port bootstrap';

  @override
  String get bootstrapNodeAdded => 'Node bootstrap ditambahkan';

  @override
  String get lookupHint => 'NC-... untuk dicari';

  @override
  String get find => 'Cari';

  @override
  String get notFound => 'Tidak ditemukan';

  @override
  String foundPeerAt(String name, String address) {
    return '$name ditemukan di $address';
  }

  @override
  String get lanOn => 'LAN aktif';

  @override
  String get lanOff => 'LAN nonaktif';

  @override
  String get bleOn => 'BLE aktif';

  @override
  String get bleScan => 'Pindai BLE';

  @override
  String get bleOff => 'BLE nonaktif';

  @override
  String linksCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tautan',
    );
    return '$_temp0';
  }

  @override
  String get stealth => 'siluman';

  @override
  String get visible => 'terlihat';

  @override
  String get reachable => 'terjangkau';

  @override
  String get offlineQueued => 'offline, pengiriman diantrekan';

  @override
  String get notANyxChatContactCard => 'Bukan kartu kontak NyxChat';

  @override
  String invalidCard(String error) {
    return 'Kartu tidak valid: $error';
  }

  @override
  String get scanContactCard => 'Pindai kartu kontak';

  @override
  String get pointCameraHint =>
      'Arahkan kamera ke kode QR di layar Verifikasi atau halaman Setelan mereka.';

  @override
  String get scanningPinsKeys =>
      'Memindai akan menyematkan kunci mereka sebagai terverifikasi. Tidak ada yang dikirim melalui jaringan.';

  @override
  String get security => 'Keamanan';

  @override
  String get databaseLock => 'Kunci database';

  @override
  String get requirePassword => 'Wajibkan sandi';

  @override
  String get requirePasswordSubtitle =>
      'Kunci database dibungkus Argon2id. Tidak ada pemulihan jika lupa.';

  @override
  String get lockWhenInBackground => 'Kunci saat di latar belakang';

  @override
  String wipeAfterFailedAttempts(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Hapus setelah $count percobaan gagal',
    );
    return '$_temp0';
  }

  @override
  String get duressPassword => 'Sandi paksaan';

  @override
  String get duressPasswordSet => 'Sandi paksaan telah disetel';

  @override
  String get setADuressPassword => 'Setel sandi paksaan';

  @override
  String get duressOpensDecoyAndDestroys =>
      'Membuka profil umpan dan menghancurkan profil asli';

  @override
  String get duressOpensEmptyDecoy => 'Membuka profil umpan kosong';

  @override
  String get duressExplanation =>
      'Memasukkannya di layar kunci akan membuka profil umpan kosong';

  @override
  String get removeDuressPassword => 'Hapus sandi paksaan';

  @override
  String get identity => 'Identitas';

  @override
  String get rotateIdentityKeys => 'Rotasi kunci identitas';

  @override
  String get rotateIdentitySubtitle =>
      'Kunci dan ID baru. Kontak yang sedang online langsung menerima transisi bertanda tangan; yang lain menerimanya saat Anda terhubung langsung lagi. Aplikasi akan ditutup setelahnya.';

  @override
  String get backup => 'Cadangan';

  @override
  String get exportEncryptedBackup => 'Ekspor cadangan terenkripsi';

  @override
  String get exportBackupSubtitle =>
      'Kunci identitas, kontak, sesi, dan pesan, disegel dengan frasa sandi (Argon2id + AES-256-GCM).';

  @override
  String get restoreFromBackup => 'Pulihkan dari cadangan';

  @override
  String get restoreBackupSubtitle =>
      'Menggantikan profil ini. Hapus data di perangkat lama setelahnya: dua salinan aktif dari satu identitas akan memecah sesinya.';

  @override
  String get dangerZone => 'Zona berbahaya';

  @override
  String get panicWipe => 'Penghapusan darurat';

  @override
  String get panicWipeSubtitle =>
      'Menghancurkan pesan, kontak, sesi, dan kunci identitas. Tidak dapat dibatalkan.';

  @override
  String get securityFooter =>
      'Kunci tersimpan di penyimpanan aman yang didukung keystore Android. Database pesan dienkripsi AES-256 dengan kunci utama acak; jika sandi diaktifkan, kunci tersebut dibungkus lagi dengan AES-256-GCM di bawah kunci turunan Argon2id (32 MiB, 2 lintasan).';

  @override
  String get passphraseHint => 'Frasa sandi (8+ karakter)';

  @override
  String get confirmPassphraseHint => 'Konfirmasi frasa sandi';

  @override
  String get continueAction => 'Lanjutkan';

  @override
  String get passphraseTooShortOrMismatch =>
      'Frasa sandi terlalu pendek atau tidak cocok';

  @override
  String get rotateIdentityKeysQuestion => 'Rotasi kunci identitas?';

  @override
  String get rotateIdentityWarning =>
      'ID NyxChat Anda akan berubah. Kontak yang sedang offline tidak akan dapat menghubungi Anda sampai Anda bertemu langsung lagi.';

  @override
  String get rotate => 'Rotasi';

  @override
  String rotationFailed(String error) {
    return 'Rotasi gagal: $error';
  }

  @override
  String get backupPassphrase => 'Frasa sandi cadangan';

  @override
  String get saveBackupDialogTitle => 'Simpan cadangan NyxChat';

  @override
  String get backupCancelled => 'Pencadangan dibatalkan';

  @override
  String get backupSaved => 'Cadangan disimpan';

  @override
  String backupFailed(String error) {
    return 'Pencadangan gagal: $error';
  }

  @override
  String get replaceThisProfile => 'Ganti profil ini?';

  @override
  String restoreConfirmBody(String created, String name) {
    return 'Cadangan dari $created untuk \"$name\". Semua yang ada di perangkat ini akan diganti dan aplikasi akan ditutup.';
  }

  @override
  String get restore => 'Pulihkan';

  @override
  String restoreFailed(String error) {
    return 'Pemulihan gagal: $error';
  }

  @override
  String get duressDifferentFromReal => 'Berbeda dari sandi asli Anda';

  @override
  String get alsoDestroyRealProfile => 'Hancurkan juga profil asli';

  @override
  String get wipeEverythingQuestion => 'Hapus semuanya?';

  @override
  String get wipeEverythingBody =>
      'Semua pesan, kontak, sesi, dan kunci identitas Anda akan dihancurkan di perangkat ini. Peer akan melihat perubahan kunci saat Anda bertemu lagi.';

  @override
  String get wipe => 'Hapus';

  @override
  String get settings => 'Setelan';

  @override
  String get privacy => 'Privasi';

  @override
  String get blockScreenshots => 'Blokir tangkapan layar';

  @override
  String get blockScreenshotsSubtitle =>
      'Menyembunyikan aplikasi di daftar terbaru dan mencegah perekaman layar';

  @override
  String get sendReadReceipts => 'Kirim tanda dibaca';

  @override
  String get notifications => 'Notifikasi';

  @override
  String get showMessageTextInNotifications =>
      'Tampilkan teks pesan di notifikasi';

  @override
  String get coverTraffic => 'Lalu lintas samaran';

  @override
  String get coverTrafficSubtitle =>
      'Paket mesh acak agar periode diam dan aktif tampak sama';

  @override
  String get stealthMode => 'Mode siluman';

  @override
  String get stealthModeSubtitle =>
      'Tanpa penyiaran atau pemindaian. Tautan yang ada tetap terhubung.';

  @override
  String get network => 'Jaringan';

  @override
  String get localNetwork => 'Jaringan lokal';

  @override
  String get active => 'Aktif';

  @override
  String get inactive => 'Tidak aktif';

  @override
  String get directLinks => 'Tautan langsung';

  @override
  String get unsupported => 'Tidak didukung';

  @override
  String advertisingLinks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tautan',
    );
    return 'Menyiarkan · $_temp0';
  }

  @override
  String scanningLinks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tautan',
    );
    return 'Memindai · $_temp0';
  }

  @override
  String get bleLongRange => 'BLE jarak jauh (Coded PHY)';

  @override
  String get bleLongRangeSubtitle =>
      'Pengodean Bluetooth 5 S=8; throughput lebih rendah, jangkauan lebih jauh';

  @override
  String get listeningPort => 'Port yang didengarkan';

  @override
  String get globalDht => 'DHT global';

  @override
  String get internetDelivery => 'Pengiriman internet';

  @override
  String get deliverThroughRelays => 'Kirim melalui relai publik (Nostr)';

  @override
  String get deliverThroughRelaysSubtitle =>
      'Amplop tersegel di bawah token yang berotasi pada relai Nostr publik. Tanpa akun, tanpa server milik kami. Nonaktif secara default.';

  @override
  String get routeThroughTor => 'Rutekan relai melalui Tor (Orbot)';

  @override
  String get routeThroughTorSubtitle =>
      'Memerlukan Orbot yang berjalan dengan proxy HTTP-nya di 127.0.0.1:8118';

  @override
  String get appLockDuressPanic =>
      'Kunci aplikasi, sandi paksaan, penghapusan darurat';

  @override
  String get about => 'Tentang';

  @override
  String get version => 'Versi';

  @override
  String get protocol => 'Protokol';

  @override
  String protocolValue(String version) {
    return 'v$version · X25519+ML-KEM-768 · Double Ratchet · Sender Keys';
  }

  @override
  String get license => 'Lisensi';

  @override
  String get nyxChatIdCopied => 'ID NyxChat disalin';

  @override
  String get contactCardCopied => 'Kartu kontak disalin';

  @override
  String get copyContactCard => 'Salin kartu kontak';

  @override
  String get shareContactCardHint =>
      'Bagikan ini agar orang lain dapat menyematkan dan memverifikasi kunci Anda di luar jaringan.';

  @override
  String get appearance => 'Tampilan';

  @override
  String get theme => 'Tema';

  @override
  String get themeSystem => 'Sistem';

  @override
  String get themeLight => 'Terang';

  @override
  String get themeDark => 'Gelap';

  @override
  String get language => 'Bahasa';

  @override
  String get languageSystemDefault => 'Default sistem';

  @override
  String get wifiAware => 'Wi-Fi Aware';

  @override
  String get useWifiAware => 'Gunakan Wi-Fi Aware';

  @override
  String get useWifiAwareSubtitle =>
      'Tautan tetangga tanpa titik akses (Android 8+). Beacon berputar yang sama seperti Bluetooth.';

  @override
  String get offlineSessions => 'Sesi luring';

  @override
  String pqReady(int count) {
    return 'Kerahasiaan maju pascakuantum siap ($count prakunci sekali pakai)';
  }

  @override
  String get pqPending =>
      'Kerahasiaan maju pascakuantum menunggu pertemuan berikutnya';

  @override
  String get voiceMessage => 'Pesan suara';

  @override
  String get photo => 'Foto';

  @override
  String get holdToRecord => 'Tahan mikrofon untuk merekam pesan suara';

  @override
  String get slideToCancel => 'Geser untuk membatalkan';

  @override
  String get releaseToCancel => 'Lepaskan untuk membatalkan';

  @override
  String get recordingUnavailable =>
      'Perekaman suara tidak tersedia di perangkat ini';

  @override
  String get microphoneDenied =>
      'Akses mikrofon diperlukan untuk merekam pesan suara';

  @override
  String get recordingFailed => 'Tidak dapat memulai perekaman';

  @override
  String get playbackUnavailable =>
      'Pemutaran suara tidak tersedia di perangkat ini';

  @override
  String get playbackFailed => 'Tidak dapat memutar pesan suara ini';

  @override
  String get voiceNeedsCarrier =>
      'Catatan suara memerlukan koneksi langsung atau jalur mesh';

  @override
  String get imageUnavailable => 'Gambar tidak tersedia';

  @override
  String get receiving => 'Menerima';
}
