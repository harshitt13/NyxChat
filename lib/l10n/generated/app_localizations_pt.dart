// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Portuguese (`pt`).
class AppLocalizationsPt extends AppLocalizations {
  AppLocalizationsPt([String locale = 'pt']) : super(locale);

  @override
  String get appTitle => 'NyxChat';

  @override
  String get notificationNewMessage => 'Nova mensagem';

  @override
  String get notificationChannelMessages => 'Mensagens';

  @override
  String get notificationChannelMessagesDescription =>
      'Mensagens recebidas do NyxChat';

  @override
  String get meshChannelName => 'Rede Mesh NyxChat';

  @override
  String get meshChannelDescription =>
      'Mantém a rede mesh descentralizada em execução em segundo plano.';

  @override
  String get meshNotificationInitial => 'Rede mesh ativa';

  @override
  String get meshNotificationActive => 'Roteamento mesh e DHT ativos';

  @override
  String get cancel => 'Cancelar';

  @override
  String get save => 'Salvar';

  @override
  String get add => 'Adicionar';

  @override
  String get off => 'Desligado';

  @override
  String get connect => 'Conectar';

  @override
  String get verified => 'Verificado';

  @override
  String get messages => 'Mensagens';

  @override
  String get safetyNumberChangedTitle => 'Número de segurança alterado';

  @override
  String safetyNumberChangedBody(String name, String id) {
    return '$name ($id) está apresentando chaves de identidade diferentes das que você fixou.\n\nIsso acontece quando a pessoa reinstalou o app ou quando alguém está se passando por ela. Verifique o novo número de segurança pessoalmente antes de aceitar. A conexão permanece bloqueada até você decidir.';
  }

  @override
  String get keepBlocking => 'Manter bloqueio';

  @override
  String get acceptNewKeys => 'Aceitar novas chaves';

  @override
  String get searchConversationsHint => 'Pesquisar conversas e mensagens';

  @override
  String get emergencyBroadcastTitle => 'Transmissão de emergência';

  @override
  String get noConversationsYet => 'Nenhuma conversa ainda';

  @override
  String get tapPlusToFindPeople =>
      'Toque em + para encontrar pessoas por perto';

  @override
  String get noMatches => 'Nenhum resultado';

  @override
  String get verifySafetyNumber => 'Verificar número de segurança';

  @override
  String get mute => 'Silenciar';

  @override
  String get unmute => 'Reativar som';

  @override
  String get leaveGroup => 'Sair do grupo';

  @override
  String get deleteConversation => 'Excluir conversa';

  @override
  String membersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count membros',
      one: '1 membro',
    );
    return '$_temp0';
  }

  @override
  String membersCountLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count membros (você saiu)',
      one: '1 membro (você saiu)',
    );
    return '$_temp0';
  }

  @override
  String get noMessagesYet => 'Nenhuma mensagem ainda';

  @override
  String get filesNeedDirectConnection =>
      'Arquivos exigem uma conexão direta. Aproxime-se até ficar ao alcance do Wi-Fi.';

  @override
  String get reply => 'Responder';

  @override
  String get copyText => 'Copiar texto';

  @override
  String get deleteForMe => 'Excluir para mim';

  @override
  String get disappearingMessages => 'Mensagens temporárias';

  @override
  String get disappear5Minutes => '5 minutos';

  @override
  String get disappear1Hour => '1 hora';

  @override
  String get disappear1Day => '1 dia';

  @override
  String get disappear1Week => '1 semana';

  @override
  String get conversationDeleted => 'Conversa excluída';

  @override
  String get statusConnected => 'Conectado';

  @override
  String get statusReachableViaMesh => 'Alcançável via mesh';

  @override
  String get statusOfflineDeliverLater => 'Offline · será entregue mais tarde';

  @override
  String get endToEndEncrypted => 'Criptografia de ponta a ponta';

  @override
  String get groupEncryptionHint =>
      'As mensagens usam chaves por remetente; só os membros podem lê-las.';

  @override
  String get directEncryptionHint =>
      'As mensagens são protegidas por uma sessão Double Ratchet.';

  @override
  String get noLongerMemberHint => 'Você não é mais membro';

  @override
  String get messageHint => 'Mensagem';

  @override
  String attachmentProgress(String percent, String size) {
    return '$percent% · $size';
  }

  @override
  String get sysMemberRemoved => 'Membro removido';

  @override
  String get sysYouLeftGroup => 'Você saiu do grupo';

  @override
  String sysGroupCreated(String name) {
    return 'Grupo \"$name\" criado';
  }

  @override
  String sysMembersAdded(String names) {
    return 'Membros adicionados: $names';
  }

  @override
  String sysAddedToGroupBy(String name, String who) {
    return 'Você foi adicionado a \"$name\" por $who';
  }

  @override
  String sysUpdatedMembers(String who) {
    return '$who atualizou os membros';
  }

  @override
  String get sysAMemberWasRemoved => 'Um membro foi removido';

  @override
  String get sysYouWereRemoved => 'Você foi removido do grupo';

  @override
  String sysLeftGroup(String who) {
    return '$who saiu do grupo';
  }

  @override
  String sysRenamedGroup(String who, String name) {
    return '$who renomeou o grupo para \"$name\"';
  }

  @override
  String get sysGroupUpdated => 'Grupo atualizado';

  @override
  String sysKeysRotated(String name) {
    return '$name trocou as chaves (transição verificada)';
  }

  @override
  String get contactNotPinnedYet => 'Contato ainda não fixado';

  @override
  String get safetyNumber => 'Número de segurança';

  @override
  String get safetyNumberExplanation =>
      'Vocês dois veem o mesmo número se ninguém estiver interceptando a conexão. Compare pessoalmente, por telefone ou por outro canal em que você confie.';

  @override
  String get markAsVerified => 'Marcar como verificado';

  @override
  String get messageAction => 'Mensagem';

  @override
  String get scanTheirQr => 'Escanear o QR code da pessoa';

  @override
  String get verifiedKeysMatch =>
      'Verificado: as chaves correspondem a este contato';

  @override
  String cardBelongsToOther(String name) {
    return 'Esse cartão pertence a $name, fixado separadamente';
  }

  @override
  String get theirFingerprint => 'Impressão digital da pessoa';

  @override
  String get yourFingerprint => 'Sua impressão digital';

  @override
  String get showThemYourCard => 'Mostre seu cartão de contato';

  @override
  String get contactCardContainsOnlyPublicKeys =>
      'Contém apenas suas chaves públicas. Escanear ou colar o cartão fixa sua identidade no dispositivo da outra pessoa.';

  @override
  String get details => 'Detalhes';

  @override
  String get nyxChatId => 'ID NyxChat';

  @override
  String get handshake => 'Negociação de chaves';

  @override
  String get handshakeValue =>
      'Híbrido X25519 + ML-KEM-768, assinado com Ed25519';

  @override
  String get messagesValue => 'Double Ratchet, AES-256-GCM';

  @override
  String get firstSeen => 'Visto pela primeira vez';

  @override
  String get keysChanged => 'Chaves alteradas';

  @override
  String get idCopied => 'ID copiado';

  @override
  String get giveGroupAName => 'Dê um nome ao grupo';

  @override
  String get selectAtLeastOneMember => 'Selecione pelo menos um membro';

  @override
  String get newGroup => 'Novo grupo';

  @override
  String get create => 'Criar';

  @override
  String get groupNameHint => 'Nome do grupo';

  @override
  String get descriptionOptionalHint => 'Descrição (opcional)';

  @override
  String membersSelectedHeader(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count selecionados',
      one: '1 selecionado',
    );
    return 'Membros · $_temp0';
  }

  @override
  String get noContactsYet =>
      'Nenhum contato ainda. Conecte-se a alguém primeiro para que as chaves da pessoa sejam fixadas.';

  @override
  String get noRecentPosition =>
      'Nenhuma posição recente. Insira uma célula geohash manualmente ou vá para um local aberto.';

  @override
  String invalidCell(String error) {
    return 'Célula inválida: $error';
  }

  @override
  String get noNeighboursKept =>
      'Nenhum vizinho no momento. Sua mensagem fica guardada e será enviada ao primeiro dispositivo que aparecer.';

  @override
  String get areaCellLabel => 'Célula da área (geohash)';

  @override
  String get findingYourArea => 'Localizando sua área...';

  @override
  String meshNeighboursCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count vizinhos mesh',
      one: '1 vizinho mesh',
    );
    return '$_temp0';
  }

  @override
  String directLinksCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count conexões diretas',
      one: '1 conexão direta',
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
    return 'Ouvindo na célula $cell ($area) · $neighbours, $links';
  }

  @override
  String get emergencyEmptyHint =>
      'Mensagens de qualquer pessoa usando o NyxChat nesta célula aparecem aqui. Sua posição nunca sai do telefone, a menos que você a inclua explicitamente.';

  @override
  String get anonymous => 'Anônimo';

  @override
  String positionLabel(String coords) {
    return 'Posição: $coords';
  }

  @override
  String get includeMyName => 'Incluir meu nome';

  @override
  String get includeMyPosition => 'Incluir minha posição';

  @override
  String get emergencyComposerHint => 'O que está acontecendo? Onde você está?';

  @override
  String get joinCellFirst => 'Entre em uma célula primeiro';

  @override
  String get send => 'Enviar';

  @override
  String get presetNeedHelp => 'Preciso de ajuda';

  @override
  String get presetSafe => 'Estou em segurança';

  @override
  String get presetMedical => 'Emergência médica';

  @override
  String get addMembers => 'Adicionar membros';

  @override
  String get groupEncryptionExplanation =>
      'As mensagens do grupo são criptografadas com chaves de remetente por membro, distribuídas por sessões Double Ratchet entre pares. As chaves são trocadas sempre que alguém sai.';

  @override
  String memberYou(String name) {
    return '$name (você)';
  }

  @override
  String get admin => 'Administrador';

  @override
  String get renameGroup => 'Renomear grupo';

  @override
  String get noOtherKnownContacts => 'Nenhum outro contato conhecido';

  @override
  String get meshDiagnostics => 'Diagnóstico da mesh';

  @override
  String get statBleLinks => 'Conexões BLE';

  @override
  String get statKnownRoutes => 'Rotas conhecidas';

  @override
  String get statStoredPackets => 'Pacotes armazenados';

  @override
  String get statDeliveredToMe => 'Entregues a mim';

  @override
  String get statReceived => 'Recebidos';

  @override
  String get statForwarded => 'Encaminhados';

  @override
  String get statDuplicatesDropped => 'Duplicados descartados';

  @override
  String get statSeenIds => 'IDs vistos';

  @override
  String get linksHeader => 'Conexões';

  @override
  String get noBluetoothLinksHint =>
      'Nenhuma conexão Bluetooth. Dispositivos ao alcance se conectam automaticamente enquanto a busca e o anúncio estiverem ativos.';

  @override
  String get weDialled => 'iniciada por nós';

  @override
  String get theyDialled => 'iniciada por eles';

  @override
  String linkSubtitle(String role, int mtu, String address) {
    return '$role · MTU $mtu · $address';
  }

  @override
  String get routingTableHeader => 'Tabela de roteamento';

  @override
  String get routingTableHint =>
      'As rotas são aprendidas a partir do caminho registrado em cada pacote e de beacons periódicos.';

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
    return 'via retransmissor $hop... · $_temp0';
  }

  @override
  String get howItWorksHeader => 'Como funciona';

  @override
  String meshExplanation(int copies, int hops) {
    return 'Os pacotes são endereçados por hashes SHA-256 e carregam um envelope criptografado de ponta a ponta. Um retransmissor armazena cada pacote, encaminha-o ao próximo salto conhecido ou espalha até $copies cópias, e o descarta após $hops saltos ou 24 horas. Os retransmissores não conseguem ler, alterar nem reendereçar o que transportam.';
  }

  @override
  String get enterDisplayName =>
      'Insira um nome de exibição (máx. 64 caracteres)';

  @override
  String couldNotCreateIdentity(String error) {
    return 'Não foi possível criar a identidade: $error';
  }

  @override
  String get tagline => 'ponto a ponto · criptografado · funciona offline';

  @override
  String get featureE2eSubtitle =>
      'Double Ratchet com negociação híbrida X25519 + ML-KEM-768';

  @override
  String get featureOfflineTitle => 'Funciona sem internet';

  @override
  String get featureOfflineSubtitle =>
      'LAN Wi-Fi e mesh Bluetooth, entrega por armazenar e encaminhar';

  @override
  String get featureNoServersTitle => 'Sem servidores, sem contas';

  @override
  String get featureNoServersSubtitle =>
      'Sua identidade é um par de chaves que nunca sai deste dispositivo';

  @override
  String get displayName => 'Nome de exibição';

  @override
  String get createIdentity => 'Criar identidade';

  @override
  String get keysGeneratedLocally =>
      'Gera chaves X25519, Ed25519 e ML-KEM-768 localmente. Nada é enviado.';

  @override
  String get passwordRequired => 'A senha é obrigatória';

  @override
  String get atLeast8Characters => 'Pelo menos 8 caracteres';

  @override
  String get passwordsDoNotMatch => 'As senhas não coincidem';

  @override
  String get enterYourPassword => 'Digite sua senha';

  @override
  String get allDataWiped => 'Todos os dados foram apagados.';

  @override
  String get incorrectPassword => 'Senha incorreta';

  @override
  String incorrectPasswordAttemptsLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'restam $count tentativas',
      one: 'resta 1 tentativa',
    );
    return 'Senha incorreta · $_temp0 antes de apagar tudo';
  }

  @override
  String get setAppLock => 'Definir bloqueio do app';

  @override
  String get nyxChatIsLocked => 'O NyxChat está bloqueado';

  @override
  String get unlockPrompt =>
      'Seu banco de dados está criptografado. Digite sua senha para desbloquear.';

  @override
  String get passwordSetupExplanation =>
      'A chave do banco de dados será protegida com uma chave derivada desta senha usando Argon2id. Não há recuperação: se a senha for esquecida, os dados estarão perdidos.';

  @override
  String get passwordHint => 'Senha';

  @override
  String get confirmPasswordHint => 'Confirmar senha';

  @override
  String get enableLock => 'Ativar bloqueio';

  @override
  String get unlock => 'Desbloquear';

  @override
  String get connectedAndAuthenticated => 'Conectado e autenticado';

  @override
  String get connectionFailed =>
      'Falha na conexão (inalcançável, recusada ou chave incompatível)';

  @override
  String pinnedAndVerified(String name) {
    return '$name fixado e verificado';
  }

  @override
  String invalidContactCard(String error) {
    return 'Cartão de contato inválido: $error';
  }

  @override
  String get findPeople => 'Encontrar pessoas';

  @override
  String get visibleToEveryoneNearby => 'Visível para todos por perto';

  @override
  String get visibleSubtitlePublic =>
      'Seu ID e nome são transmitidos para que novas pessoas possam encontrar você.';

  @override
  String get visibleSubtitlePrivate =>
      'Beacons privados: só contatos fixados conseguem reconhecer você; os outros veem ruído aleatório.';

  @override
  String get scanContactQr => 'Escanear QR do contato';

  @override
  String get emergency => 'Emergência';

  @override
  String get nearbyOnWifi => 'Por perto no Wi-Fi';

  @override
  String get nobodyDiscoveredYet =>
      'Ninguém encontrado ainda. Pares na mesma rede Wi-Fi aparecem aqui automaticamente.';

  @override
  String get bluetoothMesh => 'Mesh Bluetooth';

  @override
  String get bleNotAvailable =>
      'Bluetooth LE não está disponível neste dispositivo.';

  @override
  String get bleScanningHint =>
      'Buscando. Outros dispositivos NyxChat ao alcance se conectarão automaticamente.';

  @override
  String get bleScanningAdvertisingHint =>
      'Buscando e anunciando. Outros dispositivos NyxChat ao alcance se conectarão automaticamente.';

  @override
  String get roleCentral => 'central';

  @override
  String get rolePeripheral => 'periférico';

  @override
  String bleLinkedSubtitle(String role, int mtu) {
    return 'conectado · $role · MTU $mtu';
  }

  @override
  String rssiDbm(int rssi) {
    return '$rssi dBm';
  }

  @override
  String get contacts => 'Contatos';

  @override
  String get contactsPinnedHint =>
      'As chaves de cada par ao qual você se conecta são fixadas aqui.';

  @override
  String get addContactFromCard => 'Adicionar contato a partir do cartão';

  @override
  String get pasteContactCardHint =>
      'Cole o texto de um cartão de contato (exibido como QR em Verificar). Isso fixa e verifica as chaves da pessoa.';

  @override
  String get importCard => 'Importar cartão';

  @override
  String get manualConnection => 'Conexão manual';

  @override
  String get ipAddressHint => 'Endereço IP';

  @override
  String get portHint => 'Porta';

  @override
  String get connecting => 'Conectando...';

  @override
  String get globalDirectory => 'Diretório global (DHT, experimental)';

  @override
  String get dhtHint =>
      'Precisa de um nó bootstrap alcançável. Os anúncios são assinados; a negociação de chaves continua decidindo a confiança.';

  @override
  String dhtRunning(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count nós',
      one: '1 nó',
    );
    return 'Em execução · $_temp0';
  }

  @override
  String get stopped => 'Parado';

  @override
  String get stop => 'Parar';

  @override
  String get start => 'Iniciar';

  @override
  String get bootstrapHint => 'bootstrap host:porta';

  @override
  String get bootstrapNodeAdded => 'Nó bootstrap adicionado';

  @override
  String get lookupHint => 'NC-... para procurar';

  @override
  String get find => 'Procurar';

  @override
  String get notFound => 'Não encontrado';

  @override
  String foundPeerAt(String name, String address) {
    return '$name encontrado em $address';
  }

  @override
  String get lanOn => 'LAN ligada';

  @override
  String get lanOff => 'LAN desligada';

  @override
  String get bleOn => 'BLE ligado';

  @override
  String get bleScan => 'Busca BLE';

  @override
  String get bleOff => 'BLE desligado';

  @override
  String linksCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count conexões',
      one: '1 conexão',
    );
    return '$_temp0';
  }

  @override
  String get stealth => 'furtivo';

  @override
  String get visible => 'visível';

  @override
  String get reachable => 'alcançável';

  @override
  String get offlineQueued => 'offline, entrega na fila';

  @override
  String get notANyxChatContactCard => 'Não é um cartão de contato NyxChat';

  @override
  String invalidCard(String error) {
    return 'Cartão inválido: $error';
  }

  @override
  String get scanContactCard => 'Escanear cartão de contato';

  @override
  String get pointCameraHint =>
      'Aponte a câmera para o QR code na tela Verificar ou na página de Configurações da pessoa.';

  @override
  String get scanningPinsKeys =>
      'Escanear fixa as chaves da pessoa como verificadas. Nada é enviado pela rede.';

  @override
  String get security => 'Segurança';

  @override
  String get databaseLock => 'Bloqueio do banco de dados';

  @override
  String get requirePassword => 'Exigir senha';

  @override
  String get requirePasswordSubtitle =>
      'Chave do banco de dados protegida com Argon2id. Sem recuperação se for esquecida.';

  @override
  String get lockWhenInBackground => 'Bloquear em segundo plano';

  @override
  String wipeAfterFailedAttempts(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Apagar tudo após $count tentativas falhas',
      one: 'Apagar tudo após 1 tentativa falha',
    );
    return '$_temp0';
  }

  @override
  String get duressPassword => 'Senha de coação';

  @override
  String get duressPasswordSet => 'Senha de coação definida';

  @override
  String get setADuressPassword => 'Definir uma senha de coação';

  @override
  String get duressOpensDecoyAndDestroys =>
      'Abre um perfil falso e destrói o verdadeiro';

  @override
  String get duressOpensEmptyDecoy => 'Abre um perfil falso vazio';

  @override
  String get duressExplanation =>
      'Digitá-la na tela de bloqueio abre um perfil falso vazio';

  @override
  String get removeDuressPassword => 'Remover senha de coação';

  @override
  String get identity => 'Identidade';

  @override
  String get rotateIdentityKeys => 'Trocar chaves de identidade';

  @override
  String get rotateIdentitySubtitle =>
      'Novas chaves e novo identificador. Contatos online agora recebem uma transição assinada imediatamente; os demais a recebem na próxima conexão direta. O app fecha em seguida.';

  @override
  String get backup => 'Backup';

  @override
  String get exportEncryptedBackup => 'Exportar backup criptografado';

  @override
  String get exportBackupSubtitle =>
      'Chaves de identidade, contatos, sessões e mensagens, selados com uma frase secreta (Argon2id + AES-256-GCM).';

  @override
  String get restoreFromBackup => 'Restaurar de um backup';

  @override
  String get restoreBackupSubtitle =>
      'Substitui este perfil. Apague o dispositivo antigo depois: duas cópias ativas de uma identidade bifurcam suas sessões.';

  @override
  String get dangerZone => 'Zona de perigo';

  @override
  String get panicWipe => 'Apagamento de emergência';

  @override
  String get panicWipeSubtitle =>
      'Destrói mensagens, contatos, sessões e chaves de identidade. Irreversível.';

  @override
  String get securityFooter =>
      'As chaves ficam no armazenamento seguro protegido pelo keystore do Android. O banco de dados de mensagens é criptografado com AES-256 usando uma chave mestra aleatória; com uma senha ativada, essa chave é adicionalmente protegida com AES-256-GCM sob uma chave derivada por Argon2id (32 MiB, 2 passagens).';

  @override
  String get passphraseHint => 'Frase secreta (8+ caracteres)';

  @override
  String get confirmPassphraseHint => 'Confirmar frase secreta';

  @override
  String get continueAction => 'Continuar';

  @override
  String get passphraseTooShortOrMismatch =>
      'Frase secreta muito curta ou não coincide';

  @override
  String get rotateIdentityKeysQuestion => 'Trocar chaves de identidade?';

  @override
  String get rotateIdentityWarning =>
      'Seu ID NyxChat mudará. Contatos que estiverem offline não conseguirão alcançar você até que se encontrem diretamente de novo.';

  @override
  String get rotate => 'Trocar';

  @override
  String rotationFailed(String error) {
    return 'Falha na troca: $error';
  }

  @override
  String get backupPassphrase => 'Frase secreta do backup';

  @override
  String get saveBackupDialogTitle => 'Salvar backup do NyxChat';

  @override
  String get backupCancelled => 'Backup cancelado';

  @override
  String get backupSaved => 'Backup salvo';

  @override
  String backupFailed(String error) {
    return 'Falha no backup: $error';
  }

  @override
  String get replaceThisProfile => 'Substituir este perfil?';

  @override
  String restoreConfirmBody(String created, String name) {
    return 'Backup de $created para \"$name\". Tudo neste dispositivo será substituído e o app será fechado.';
  }

  @override
  String get restore => 'Restaurar';

  @override
  String restoreFailed(String error) {
    return 'Falha na restauração: $error';
  }

  @override
  String get duressDifferentFromReal => 'Diferente da sua senha verdadeira';

  @override
  String get alsoDestroyRealProfile => 'Também destruir o perfil verdadeiro';

  @override
  String get wipeEverythingQuestion => 'Apagar tudo?';

  @override
  String get wipeEverythingBody =>
      'Todas as mensagens, contatos, sessões e suas chaves de identidade serão destruídos neste dispositivo. Os pares verão uma mudança de chave na próxima vez que se encontrarem.';

  @override
  String get wipe => 'Apagar';

  @override
  String get settings => 'Configurações';

  @override
  String get privacy => 'Privacidade';

  @override
  String get blockScreenshots => 'Bloquear capturas de tela';

  @override
  String get blockScreenshotsSubtitle =>
      'Oculta o app nos recentes e impede a captura de tela';

  @override
  String get sendReadReceipts => 'Enviar confirmações de leitura';

  @override
  String get notifications => 'Notificações';

  @override
  String get showMessageTextInNotifications =>
      'Mostrar texto da mensagem nas notificações';

  @override
  String get coverTraffic => 'Tráfego de cobertura';

  @override
  String get coverTrafficSubtitle =>
      'Pacotes mesh aleatórios para que períodos ociosos e ativos pareçam iguais';

  @override
  String get stealthMode => 'Modo furtivo';

  @override
  String get stealthModeSubtitle =>
      'Sem anúncio nem busca. As conexões existentes continuam ativas.';

  @override
  String get network => 'Rede';

  @override
  String get localNetwork => 'Rede local';

  @override
  String get active => 'Ativo';

  @override
  String get inactive => 'Inativo';

  @override
  String get directLinks => 'Conexões diretas';

  @override
  String get unsupported => 'Não suportado';

  @override
  String advertisingLinks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count conexões',
      one: '1 conexão',
    );
    return 'Anunciando · $_temp0';
  }

  @override
  String scanningLinks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count conexões',
      one: '1 conexão',
    );
    return 'Buscando · $_temp0';
  }

  @override
  String get bleLongRange => 'BLE de longo alcance (Coded PHY)';

  @override
  String get bleLongRangeSubtitle =>
      'Codificação Bluetooth 5 S=8; menor vazão, maior alcance';

  @override
  String get listeningPort => 'Porta de escuta';

  @override
  String get globalDht => 'DHT global';

  @override
  String get internetDelivery => 'Entrega pela internet';

  @override
  String get deliverThroughRelays => 'Entregar por relays públicos (Nostr)';

  @override
  String get deliverThroughRelaysSubtitle =>
      'Envelopes selados sob tokens rotativos em relays Nostr públicos. Sem conta, sem servidor nosso. Desligado por padrão.';

  @override
  String get routeThroughTor => 'Rotear relays pelo Tor (Orbot)';

  @override
  String get routeThroughTorSubtitle =>
      'Requer o Orbot em execução com o proxy HTTP em 127.0.0.1:8118';

  @override
  String get appLockDuressPanic =>
      'Bloqueio do app, senha de coação, apagamento de emergência';

  @override
  String get about => 'Sobre';

  @override
  String get version => 'Versão';

  @override
  String get protocol => 'Protocolo';

  @override
  String protocolValue(String version) {
    return 'v$version · X25519+ML-KEM-768 · Double Ratchet · Sender Keys';
  }

  @override
  String get license => 'Licença';

  @override
  String get nyxChatIdCopied => 'ID NyxChat copiado';

  @override
  String get contactCardCopied => 'Cartão de contato copiado';

  @override
  String get copyContactCard => 'Copiar cartão de contato';

  @override
  String get shareContactCardHint =>
      'Compartilhe isto para que outras pessoas possam fixar e verificar suas chaves por outro canal.';

  @override
  String get appearance => 'Aparência';

  @override
  String get theme => 'Tema';

  @override
  String get themeSystem => 'Sistema';

  @override
  String get themeLight => 'Claro';

  @override
  String get themeDark => 'Escuro';

  @override
  String get language => 'Idioma';

  @override
  String get languageSystemDefault => 'Padrão do sistema';

  @override
  String get wifiAware => 'Wi-Fi Aware';

  @override
  String get useWifiAware => 'Usar Wi-Fi Aware';

  @override
  String get useWifiAwareSubtitle =>
      'Ligações com vizinhos sem ponto de acesso (Android 8+). O mesmo beacon rotativo do Bluetooth.';

  @override
  String get offlineSessions => 'Sessões offline';

  @override
  String pqReady(int count) {
    return 'Sigilo futuro pós-quântico pronto ($count pré-chaves de uso único)';
  }

  @override
  String get pqPending =>
      'Sigilo futuro pós-quântico pendente até ao próximo encontro';

  @override
  String get voiceMessage => 'Mensagem de voz';

  @override
  String get photo => 'Foto';

  @override
  String get holdToRecord =>
      'Mantenha o microfone premido para gravar uma mensagem de voz';

  @override
  String get slideToCancel => 'Deslize para cancelar';

  @override
  String get releaseToCancel => 'Solte para cancelar';

  @override
  String get recordingUnavailable =>
      'A gravação de voz não está disponível neste dispositivo';

  @override
  String get microphoneDenied =>
      'É necessário acesso ao microfone para gravar mensagens de voz';

  @override
  String get recordingFailed => 'Não foi possível iniciar a gravação';

  @override
  String get playbackUnavailable =>
      'A reprodução de voz não está disponível neste dispositivo';

  @override
  String get playbackFailed =>
      'Não foi possível reproduzir esta mensagem de voz';

  @override
  String get voiceNeedsCarrier =>
      'As notas de voz precisam de uma ligação direta ou de um caminho na malha';

  @override
  String get imageUnavailable => 'Imagem indisponível';

  @override
  String get receiving => 'A receber';
}
