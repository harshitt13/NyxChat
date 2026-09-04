import 'dart:ui';

import '../l10n/generated/app_localizations.dart';

/// User-facing strings for voice notes and image previews. They are needed
/// by services that have no BuildContext (recorder, player, notifications),
/// so they resolve through the app's UI locale instead of a widget tree.
abstract final class MediaStrings {
  /// Set by main() to the app's effective UI locale (settings or device).
  static Locale Function() localeProvider =
      () => PlatformDispatcher.instance.locale;

  static AppLocalizations get _l {
    try {
      return lookupAppLocalizations(localeProvider());
    } catch (_) {
      return lookupAppLocalizations(const Locale('en'));
    }
  }

  /// Notification and chat-list preview of a voice note.
  static String get voiceMessage => _l.voiceMessage;

  /// Notification and chat-list preview of an image.
  static String get photo => _l.photo;

  static String get holdToRecord => _l.holdToRecord;
  static String get slideToCancel => _l.slideToCancel;
  static String get releaseToCancel => _l.releaseToCancel;
  static String get recordingUnavailable => _l.recordingUnavailable;
  static String get microphoneDenied => _l.microphoneDenied;
  static String get recordingFailed => _l.recordingFailed;
  static String get playbackUnavailable => _l.playbackUnavailable;
  static String get playbackFailed => _l.playbackFailed;
  static String get voiceNeedsCarrier => _l.voiceNeedsCarrier;
  static String get imageUnavailable => _l.imageUnavailable;
  static String get receiving => _l.receiving;
}
