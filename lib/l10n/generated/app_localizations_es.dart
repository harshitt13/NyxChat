// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appTitle => 'NyxChat';

  @override
  String get notificationNewMessage => 'Mensaje nuevo';

  @override
  String get notificationChannelMessages => 'Mensajes';

  @override
  String get notificationChannelMessagesDescription =>
      'Mensajes entrantes de NyxChat';

  @override
  String get meshChannelName => 'Red de malla NyxChat';

  @override
  String get meshChannelDescription =>
      'Mantiene la red de malla descentralizada en ejecución en segundo plano.';

  @override
  String get meshNotificationInitial => 'La red de malla está activa';

  @override
  String get meshNotificationActive => 'Malla y enrutamiento DHT activos';

  @override
  String get cancel => 'Cancelar';

  @override
  String get save => 'Guardar';

  @override
  String get add => 'Añadir';

  @override
  String get off => 'Desactivado';

  @override
  String get connect => 'Conectar';

  @override
  String get verified => 'Verificado';

  @override
  String get messages => 'Mensajes';

  @override
  String get safetyNumberChangedTitle => 'El número de seguridad ha cambiado';

  @override
  String safetyNumberChangedBody(String name, String id) {
    return '$name ($id) presenta claves de identidad distintas de las que tienes fijadas.\n\nEsto ocurre cuando esa persona reinstaló la aplicación o si alguien se está haciendo pasar por ella. Verifica el nuevo número de seguridad en persona antes de aceptarlo. La conexión permanece bloqueada hasta que decidas.';
  }

  @override
  String get keepBlocking => 'Seguir bloqueando';

  @override
  String get acceptNewKeys => 'Aceptar claves nuevas';

  @override
  String get searchConversationsHint => 'Buscar conversaciones y mensajes';

  @override
  String get emergencyBroadcastTitle => 'Difusión de emergencia';

  @override
  String get noConversationsYet => 'Aún no hay conversaciones';

  @override
  String get tapPlusToFindPeople => 'Toca + para encontrar personas cerca';

  @override
  String get noMatches => 'Sin coincidencias';

  @override
  String get verifySafetyNumber => 'Verificar número de seguridad';

  @override
  String get mute => 'Silenciar';

  @override
  String get unmute => 'Dejar de silenciar';

  @override
  String get leaveGroup => 'Salir del grupo';

  @override
  String get deleteConversation => 'Eliminar conversación';

  @override
  String membersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count miembros',
      one: '1 miembro',
    );
    return '$_temp0';
  }

  @override
  String membersCountLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count miembros (saliste)',
      one: '1 miembro (saliste)',
    );
    return '$_temp0';
  }

  @override
  String get noMessagesYet => 'Aún no hay mensajes';

  @override
  String get filesNeedDirectConnection =>
      'Los archivos necesitan una conexión directa. Primero acércate hasta estar al alcance de la red Wi-Fi.';

  @override
  String get reply => 'Responder';

  @override
  String get copyText => 'Copiar texto';

  @override
  String get deleteForMe => 'Eliminar para mí';

  @override
  String get disappearingMessages => 'Mensajes temporales';

  @override
  String get disappear5Minutes => '5 minutos';

  @override
  String get disappear1Hour => '1 hora';

  @override
  String get disappear1Day => '1 día';

  @override
  String get disappear1Week => '1 semana';

  @override
  String get conversationDeleted => 'Conversación eliminada';

  @override
  String get statusConnected => 'Conectado';

  @override
  String get statusReachableViaMesh => 'Accesible a través de la malla';

  @override
  String get statusOfflineDeliverLater =>
      'Sin conexión · se entregará más tarde';

  @override
  String get endToEndEncrypted => 'Cifrado de extremo a extremo';

  @override
  String get groupEncryptionHint =>
      'Los mensajes usan claves por remitente; solo los miembros pueden leerlos.';

  @override
  String get directEncryptionHint =>
      'Los mensajes están protegidos por una sesión Double Ratchet.';

  @override
  String get noLongerMemberHint => 'Ya no eres miembro';

  @override
  String get messageHint => 'Mensaje';

  @override
  String attachmentProgress(String percent, String size) {
    return '$percent% · $size';
  }

  @override
  String get sysMemberRemoved => 'Miembro eliminado';

  @override
  String get sysYouLeftGroup => 'Saliste del grupo';

  @override
  String sysGroupCreated(String name) {
    return 'Grupo \"$name\" creado';
  }

  @override
  String sysMembersAdded(String names) {
    return 'Se añadió a $names';
  }

  @override
  String sysAddedToGroupBy(String name, String who) {
    return '$who te añadió a \"$name\"';
  }

  @override
  String sysUpdatedMembers(String who) {
    return '$who actualizó los miembros';
  }

  @override
  String get sysAMemberWasRemoved => 'Se eliminó a un miembro';

  @override
  String get sysYouWereRemoved => 'Te eliminaron del grupo';

  @override
  String sysLeftGroup(String who) {
    return '$who salió del grupo';
  }

  @override
  String sysRenamedGroup(String who, String name) {
    return '$who cambió el nombre del grupo a \"$name\"';
  }

  @override
  String get sysGroupUpdated => 'Grupo actualizado';

  @override
  String sysKeysRotated(String name) {
    return '$name rotó sus claves (transición verificada)';
  }

  @override
  String get contactNotPinnedYet => 'Contacto aún no fijado';

  @override
  String get safetyNumber => 'Número de seguridad';

  @override
  String get safetyNumberExplanation =>
      'Si nadie está interceptando la conexión, el número es el mismo en ambos dispositivos. Compáralo en persona, por teléfono o por otro canal en el que confíes.';

  @override
  String get markAsVerified => 'Marcar como verificado';

  @override
  String get messageAction => 'Mensaje';

  @override
  String get scanTheirQr => 'Escanear su código QR';

  @override
  String get verifiedKeysMatch =>
      'Verificado: las claves coinciden con este contacto';

  @override
  String cardBelongsToOther(String name) {
    return 'Esa tarjeta pertenece a $name y se fijó por separado';
  }

  @override
  String get theirFingerprint => 'Su huella digital';

  @override
  String get yourFingerprint => 'Tu huella digital';

  @override
  String get showThemYourCard => 'Muéstrale tu tarjeta de contacto';

  @override
  String get contactCardContainsOnlyPublicKeys =>
      'Contiene solo tus claves públicas. Al escanearla o pegarla, tu identidad queda fijada en su dispositivo.';

  @override
  String get details => 'Detalles';

  @override
  String get nyxChatId => 'ID de NyxChat';

  @override
  String get handshake => 'Negociación (handshake)';

  @override
  String get handshakeValue =>
      'Híbrido X25519 + Kyber-768, firmado con Ed25519';

  @override
  String get messagesValue => 'Double Ratchet, AES-256-GCM';

  @override
  String get firstSeen => 'Visto por primera vez';

  @override
  String get keysChanged => 'Cambio de claves';

  @override
  String get idCopied => 'ID copiado';

  @override
  String get giveGroupAName => 'Ponle un nombre al grupo';

  @override
  String get selectAtLeastOneMember => 'Selecciona al menos un miembro';

  @override
  String get newGroup => 'Nuevo grupo';

  @override
  String get create => 'Crear';

  @override
  String get groupNameHint => 'Nombre del grupo';

  @override
  String get descriptionOptionalHint => 'Descripción (opcional)';

  @override
  String membersSelectedHeader(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count seleccionados',
      one: '1 seleccionado',
    );
    return 'Miembros · $_temp0';
  }

  @override
  String get noContactsYet =>
      'Aún no hay contactos. Conéctate primero con alguien para que sus claves queden fijadas.';

  @override
  String get noRecentPosition =>
      'No hay una posición reciente. Indica una celda geohash manualmente o sal al exterior.';

  @override
  String invalidCell(String error) {
    return 'Celda no válida: $error';
  }

  @override
  String get noNeighboursKept =>
      'Ahora mismo no hay vecinos. Tu mensaje se conserva y se enviará al primer dispositivo que aparezca.';

  @override
  String get areaCellLabel => 'Celda de área (geohash)';

  @override
  String get findingYourArea => 'Buscando tu área...';

  @override
  String meshNeighboursCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count vecinos de malla',
      one: '1 vecino de malla',
    );
    return '$_temp0';
  }

  @override
  String directLinksCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count enlaces directos',
      one: '1 enlace directo',
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
    return 'Escuchando en la celda $cell ($area) · $neighbours, $links';
  }

  @override
  String get emergencyEmptyHint =>
      'Aquí aparecen los mensajes de cualquiera que use NyxChat en esta celda. Tu posición nunca sale del teléfono a menos que la incluyas explícitamente.';

  @override
  String get anonymous => 'Anónimo';

  @override
  String positionLabel(String coords) {
    return 'Posición: $coords';
  }

  @override
  String get includeMyName => 'Incluir mi nombre';

  @override
  String get includeMyPosition => 'Incluir mi posición';

  @override
  String get emergencyComposerHint => '¿Qué está pasando? ¿Dónde estás?';

  @override
  String get joinCellFirst => 'Primero únete a una celda';

  @override
  String get send => 'Enviar';

  @override
  String get presetNeedHelp => 'Necesito ayuda';

  @override
  String get presetSafe => 'Estoy a salvo';

  @override
  String get presetMedical => 'Emergencia médica';

  @override
  String get addMembers => 'Añadir miembros';

  @override
  String get groupEncryptionExplanation =>
      'Los mensajes del grupo se cifran con claves de remitente por miembro, distribuidas mediante sesiones Double Ratchet entre pares. Las claves rotan cada vez que alguien sale.';

  @override
  String memberYou(String name) {
    return '$name (tú)';
  }

  @override
  String get admin => 'Administrador';

  @override
  String get renameGroup => 'Cambiar nombre del grupo';

  @override
  String get noOtherKnownContacts => 'No hay otros contactos conocidos';

  @override
  String get meshDiagnostics => 'Diagnóstico de la malla';

  @override
  String get statBleLinks => 'Enlaces BLE';

  @override
  String get statKnownRoutes => 'Rutas conocidas';

  @override
  String get statStoredPackets => 'Paquetes almacenados';

  @override
  String get statDeliveredToMe => 'Entregados a mí';

  @override
  String get statReceived => 'Recibidos';

  @override
  String get statForwarded => 'Reenviados';

  @override
  String get statDuplicatesDropped => 'Duplicados descartados';

  @override
  String get statSeenIds => 'IDs vistos';

  @override
  String get linksHeader => 'Enlaces';

  @override
  String get noBluetoothLinksHint =>
      'No hay enlaces Bluetooth. Los dispositivos al alcance se enlazan automáticamente mientras el escaneo y el anuncio estén activados.';

  @override
  String get weDialled => 'iniciado por nosotros';

  @override
  String get theyDialled => 'iniciado por ellos';

  @override
  String linkSubtitle(String role, int mtu, String address) {
    return '$role · MTU $mtu · $address';
  }

  @override
  String get routingTableHeader => 'Tabla de enrutamiento';

  @override
  String get routingTableHint =>
      'Las rutas se aprenden a partir de la ruta registrada en cada paquete y de balizas periódicas.';

  @override
  String routeToken(String prefix) {
    return 'token $prefix...';
  }

  @override
  String routeVia(String hop, int hops) {
    String _temp0 = intl.Intl.pluralLogic(
      hops,
      locale: localeName,
      other: '$hops saltos',
      one: '1 salto',
    );
    return 'vía relé $hop... · $_temp0';
  }

  @override
  String get howItWorksHeader => 'Cómo funciona';

  @override
  String meshExplanation(int copies, int hops) {
    return 'Los paquetes se direccionan mediante hashes SHA-256 y llevan un sobre cifrado de extremo a extremo. Un relé almacena cada paquete, lo reenvía al siguiente salto aprendido o dispersa hasta $copies copias, y lo descarta tras $hops saltos o 24 horas. Los relés no pueden leer, alterar ni redirigir lo que transportan.';
  }

  @override
  String get enterDisplayName =>
      'Escribe un nombre para mostrar (máx. 64 caracteres)';

  @override
  String couldNotCreateIdentity(String error) {
    return 'No se pudo crear la identidad: $error';
  }

  @override
  String get tagline => 'entre pares · cifrado · funciona sin conexión';

  @override
  String get featureE2eSubtitle =>
      'Double Ratchet con negociación híbrida X25519 + Kyber-768';

  @override
  String get featureOfflineTitle => 'Funciona sin internet';

  @override
  String get featureOfflineSubtitle =>
      'Malla por Wi-Fi LAN y Bluetooth, entrega con almacenamiento y reenvío';

  @override
  String get featureNoServersTitle => 'Sin servidores, sin cuentas';

  @override
  String get featureNoServersSubtitle =>
      'Tu identidad es un par de claves que nunca sale de este dispositivo';

  @override
  String get displayName => 'Nombre para mostrar';

  @override
  String get createIdentity => 'Crear identidad';

  @override
  String get keysGeneratedLocally =>
      'Genera claves X25519, Ed25519 y Kyber-768 de forma local. No se sube nada.';

  @override
  String get passwordRequired => 'La contraseña es obligatoria';

  @override
  String get atLeast8Characters => 'Al menos 8 caracteres';

  @override
  String get passwordsDoNotMatch => 'Las contraseñas no coinciden';

  @override
  String get enterYourPassword => 'Escribe tu contraseña';

  @override
  String get allDataWiped => 'Se han borrado todos los datos.';

  @override
  String get incorrectPassword => 'Contraseña incorrecta';

  @override
  String incorrectPasswordAttemptsLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'quedan $count intentos',
      one: 'queda 1 intento',
    );
    return 'Contraseña incorrecta · $_temp0 antes del borrado';
  }

  @override
  String get setAppLock => 'Configurar bloqueo de la aplicación';

  @override
  String get nyxChatIsLocked => 'NyxChat está bloqueado';

  @override
  String get unlockPrompt =>
      'Tu base de datos está cifrada. Escribe tu contraseña para desbloquearla.';

  @override
  String get passwordSetupExplanation =>
      'La clave de la base de datos se envolverá con una clave derivada de esta contraseña mediante Argon2id. No hay recuperación: si olvidas la contraseña, los datos se pierden.';

  @override
  String get passwordHint => 'Contraseña';

  @override
  String get confirmPasswordHint => 'Confirmar contraseña';

  @override
  String get enableLock => 'Activar bloqueo';

  @override
  String get unlock => 'Desbloquear';

  @override
  String get connectedAndAuthenticated => 'Conectado y autenticado';

  @override
  String get connectionFailed =>
      'Error de conexión (inaccesible, rechazada o claves no coincidentes)';

  @override
  String pinnedAndVerified(String name) {
    return 'Se fijó y verificó a $name';
  }

  @override
  String invalidContactCard(String error) {
    return 'Tarjeta de contacto no válida: $error';
  }

  @override
  String get findPeople => 'Encontrar personas';

  @override
  String get visibleToEveryoneNearby =>
      'Visible para todos los que estén cerca';

  @override
  String get visibleSubtitlePublic =>
      'Tu ID y tu nombre se difunden para que personas nuevas puedan encontrarte.';

  @override
  String get visibleSubtitlePrivate =>
      'Balizas privadas: solo los contactos fijados pueden reconocerte; los demás ven ruido aleatorio.';

  @override
  String get scanContactQr => 'Escanear QR de contacto';

  @override
  String get emergency => 'Emergencia';

  @override
  String get nearbyOnWifi => 'Cerca por Wi-Fi';

  @override
  String get nobodyDiscoveredYet =>
      'Aún no se ha descubierto a nadie. Los pares en la misma red Wi-Fi aparecen aquí automáticamente.';

  @override
  String get bluetoothMesh => 'Malla Bluetooth';

  @override
  String get bleNotAvailable =>
      'Bluetooth LE no está disponible en este dispositivo.';

  @override
  String get bleScanningHint =>
      'Escaneando. Otros dispositivos NyxChat al alcance se enlazarán automáticamente.';

  @override
  String get bleScanningAdvertisingHint =>
      'Escaneando y anunciando. Otros dispositivos NyxChat al alcance se enlazarán automáticamente.';

  @override
  String get roleCentral => 'central';

  @override
  String get rolePeripheral => 'periférico';

  @override
  String bleLinkedSubtitle(String role, int mtu) {
    return 'enlazado · $role · MTU $mtu';
  }

  @override
  String rssiDbm(int rssi) {
    return '$rssi dBm';
  }

  @override
  String get contacts => 'Contactos';

  @override
  String get contactsPinnedHint =>
      'Aquí quedan fijadas las claves de cada par con el que te conectas.';

  @override
  String get addContactFromCard => 'Añadir contacto desde tarjeta';

  @override
  String get pasteContactCardHint =>
      'Pega el texto de una tarjeta de contacto (la que se muestra como QR en Verificar). Esto fija y verifica sus claves.';

  @override
  String get importCard => 'Importar tarjeta';

  @override
  String get manualConnection => 'Conexión manual';

  @override
  String get ipAddressHint => 'Dirección IP';

  @override
  String get portHint => 'Puerto';

  @override
  String get connecting => 'Conectando...';

  @override
  String get globalDirectory => 'Directorio global (DHT, experimental)';

  @override
  String get dhtHint =>
      'Necesita un nodo de arranque accesible. Los anuncios van firmados; la confianza la sigue decidiendo la negociación de claves.';

  @override
  String dhtRunning(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count nodos',
      one: '1 nodo',
    );
    return 'En ejecución · $_temp0';
  }

  @override
  String get stopped => 'Detenido';

  @override
  String get stop => 'Detener';

  @override
  String get start => 'Iniciar';

  @override
  String get bootstrapHint => 'host:puerto de arranque';

  @override
  String get bootstrapNodeAdded => 'Nodo de arranque añadido';

  @override
  String get lookupHint => 'NC-... a buscar';

  @override
  String get find => 'Buscar';

  @override
  String get notFound => 'No encontrado';

  @override
  String foundPeerAt(String name, String address) {
    return 'Se encontró a $name en $address';
  }

  @override
  String get lanOn => 'LAN activa';

  @override
  String get lanOff => 'LAN inactiva';

  @override
  String get bleOn => 'BLE activo';

  @override
  String get bleScan => 'Escaneo BLE';

  @override
  String get bleOff => 'BLE inactivo';

  @override
  String linksCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count enlaces',
      one: '1 enlace',
    );
    return '$_temp0';
  }

  @override
  String get stealth => 'sigilo';

  @override
  String get visible => 'visible';

  @override
  String get reachable => 'accesible';

  @override
  String get offlineQueued => 'sin conexión, entrega en cola';

  @override
  String get notANyxChatContactCard =>
      'No es una tarjeta de contacto de NyxChat';

  @override
  String invalidCard(String error) {
    return 'Tarjeta no válida: $error';
  }

  @override
  String get scanContactCard => 'Escanear tarjeta de contacto';

  @override
  String get pointCameraHint =>
      'Apunta la cámara al código QR de su pantalla Verificar o de su página de Ajustes.';

  @override
  String get scanningPinsKeys =>
      'Al escanear, sus claves quedan fijadas como verificadas. No se envía nada por la red.';

  @override
  String get security => 'Seguridad';

  @override
  String get databaseLock => 'Bloqueo de la base de datos';

  @override
  String get requirePassword => 'Exigir contraseña';

  @override
  String get requirePasswordSubtitle =>
      'Clave de la base de datos envuelta con Argon2id. Sin recuperación si la olvidas.';

  @override
  String get lockWhenInBackground => 'Bloquear en segundo plano';

  @override
  String wipeAfterFailedAttempts(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Borrar todo tras $count intentos fallidos',
      one: 'Borrar todo tras 1 intento fallido',
    );
    return '$_temp0';
  }

  @override
  String get duressPassword => 'Contraseña de coacción';

  @override
  String get duressPasswordSet => 'Contraseña de coacción configurada';

  @override
  String get setADuressPassword => 'Configurar una contraseña de coacción';

  @override
  String get duressOpensDecoyAndDestroys =>
      'Abre un perfil señuelo y destruye el real';

  @override
  String get duressOpensEmptyDecoy => 'Abre un perfil señuelo vacío';

  @override
  String get duressExplanation =>
      'Al escribirla en la pantalla de bloqueo se abre un perfil señuelo vacío';

  @override
  String get removeDuressPassword => 'Eliminar contraseña de coacción';

  @override
  String get identity => 'Identidad';

  @override
  String get rotateIdentityKeys => 'Rotar claves de identidad';

  @override
  String get rotateIdentitySubtitle =>
      'Claves e ID nuevos. Los contactos que estén en línea ahora reciben de inmediato una transición firmada; los demás la reciben la próxima vez que te conectes directamente. Después, la aplicación se cierra.';

  @override
  String get backup => 'Copia de seguridad';

  @override
  String get exportEncryptedBackup => 'Exportar copia de seguridad cifrada';

  @override
  String get exportBackupSubtitle =>
      'Claves de identidad, contactos, sesiones y mensajes, sellados con una frase de contraseña (Argon2id + AES-256-GCM).';

  @override
  String get restoreFromBackup => 'Restaurar desde copia de seguridad';

  @override
  String get restoreBackupSubtitle =>
      'Reemplaza este perfil. Borra después el dispositivo antiguo: dos copias activas de una misma identidad bifurcan sus sesiones.';

  @override
  String get dangerZone => 'Zona de peligro';

  @override
  String get panicWipe => 'Borrado de pánico';

  @override
  String get panicWipeSubtitle =>
      'Destruye mensajes, contactos, sesiones y claves de identidad. Irreversible.';

  @override
  String get securityFooter =>
      'Las claves se guardan en el almacenamiento seguro respaldado por el keystore de Android. La base de datos de mensajes está cifrada con AES-256 mediante una clave maestra aleatoria; con una contraseña activada, esa clave se envuelve además con AES-256-GCM bajo una clave derivada con Argon2id (32 MiB, 2 pasadas).';

  @override
  String get passphraseHint => 'Frase de contraseña (8+ caracteres)';

  @override
  String get confirmPassphraseHint => 'Confirmar frase de contraseña';

  @override
  String get continueAction => 'Continuar';

  @override
  String get passphraseTooShortOrMismatch =>
      'La frase de contraseña es demasiado corta o no coincide';

  @override
  String get rotateIdentityKeysQuestion => '¿Rotar claves de identidad?';

  @override
  String get rotateIdentityWarning =>
      'Tu ID de NyxChat cambiará. Los contactos que estén sin conexión no podrán localizarte hasta que vuelvas a encontrarte con ellos directamente.';

  @override
  String get rotate => 'Rotar';

  @override
  String rotationFailed(String error) {
    return 'Error al rotar: $error';
  }

  @override
  String get backupPassphrase => 'Frase de contraseña de la copia de seguridad';

  @override
  String get saveBackupDialogTitle => 'Guardar copia de seguridad de NyxChat';

  @override
  String get backupCancelled => 'Copia de seguridad cancelada';

  @override
  String get backupSaved => 'Copia de seguridad guardada';

  @override
  String backupFailed(String error) {
    return 'Error en la copia de seguridad: $error';
  }

  @override
  String get replaceThisProfile => '¿Reemplazar este perfil?';

  @override
  String restoreConfirmBody(String created, String name) {
    return 'Copia de seguridad del $created de \"$name\". Todo lo que hay en este dispositivo se reemplazará y la aplicación se cerrará.';
  }

  @override
  String get restore => 'Restaurar';

  @override
  String restoreFailed(String error) {
    return 'Error al restaurar: $error';
  }

  @override
  String get duressDifferentFromReal => 'Distinta de tu contraseña real';

  @override
  String get alsoDestroyRealProfile => 'Destruir también el perfil real';

  @override
  String get wipeEverythingQuestion => '¿Borrar todo?';

  @override
  String get wipeEverythingBody =>
      'Todos los mensajes, contactos, sesiones y tus claves de identidad se destruirán en este dispositivo. Los pares verán un cambio de claves la próxima vez que se encuentren contigo.';

  @override
  String get wipe => 'Borrar';

  @override
  String get settings => 'Ajustes';

  @override
  String get privacy => 'Privacidad';

  @override
  String get blockScreenshots => 'Bloquear capturas de pantalla';

  @override
  String get blockScreenshotsSubtitle =>
      'Oculta la aplicación en recientes e impide las capturas de pantalla';

  @override
  String get sendReadReceipts => 'Enviar confirmaciones de lectura';

  @override
  String get notifications => 'Notificaciones';

  @override
  String get showMessageTextInNotifications =>
      'Mostrar el texto del mensaje en las notificaciones';

  @override
  String get coverTraffic => 'Tráfico de cobertura';

  @override
  String get coverTrafficSubtitle =>
      'Paquetes de malla aleatorios para que los periodos inactivos y activos parezcan iguales';

  @override
  String get stealthMode => 'Modo sigilo';

  @override
  String get stealthModeSubtitle =>
      'Sin anuncios ni escaneo. Los enlaces existentes se mantienen.';

  @override
  String get network => 'Red';

  @override
  String get localNetwork => 'Red local';

  @override
  String get active => 'Activo';

  @override
  String get inactive => 'Inactivo';

  @override
  String get directLinks => 'Enlaces directos';

  @override
  String get unsupported => 'No compatible';

  @override
  String advertisingLinks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count enlaces',
      one: '1 enlace',
    );
    return 'Anunciando · $_temp0';
  }

  @override
  String scanningLinks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count enlaces',
      one: '1 enlace',
    );
    return 'Escaneando · $_temp0';
  }

  @override
  String get bleLongRange => 'BLE de largo alcance (Coded PHY)';

  @override
  String get bleLongRangeSubtitle =>
      'Codificación S=8 de Bluetooth 5; menos rendimiento, más alcance';

  @override
  String get listeningPort => 'Puerto de escucha';

  @override
  String get globalDht => 'DHT global';

  @override
  String get internetDelivery => 'Entrega por internet';

  @override
  String get deliverThroughRelays =>
      'Entregar a través de relés públicos (Nostr)';

  @override
  String get deliverThroughRelaysSubtitle =>
      'Sobres sellados bajo tokens rotativos en relés públicos de Nostr. Sin cuenta y sin servidores nuestros. Desactivado de forma predeterminada.';

  @override
  String get routeThroughTor => 'Enrutar los relés a través de Tor (Orbot)';

  @override
  String get routeThroughTorSubtitle =>
      'Requiere que Orbot esté en ejecución con su proxy HTTP en 127.0.0.1:8118';

  @override
  String get appLockDuressPanic =>
      'Bloqueo de la aplicación, contraseña de coacción, borrado de pánico';

  @override
  String get about => 'Acerca de';

  @override
  String get version => 'Versión';

  @override
  String get protocol => 'Protocolo';

  @override
  String protocolValue(String version) {
    return 'v$version · X25519+Kyber-768 · Double Ratchet · Sender Keys';
  }

  @override
  String get license => 'Licencia';

  @override
  String get nyxChatIdCopied => 'ID de NyxChat copiado';

  @override
  String get contactCardCopied => 'Tarjeta de contacto copiada';

  @override
  String get copyContactCard => 'Copiar tarjeta de contacto';

  @override
  String get shareContactCardHint =>
      'Compártela para que otros puedan fijar y verificar tus claves por otro canal.';

  @override
  String get appearance => 'Apariencia';

  @override
  String get theme => 'Tema';

  @override
  String get themeSystem => 'Sistema';

  @override
  String get themeLight => 'Claro';

  @override
  String get themeDark => 'Oscuro';

  @override
  String get language => 'Idioma';

  @override
  String get languageSystemDefault => 'Predeterminado del sistema';
}
