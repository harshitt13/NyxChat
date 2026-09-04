/// User-facing strings for voice notes and image previews, kept in one
/// place so the localization pass can pick them up together.
abstract final class MediaStrings {
  /// Notification and chat-list preview of a voice note.
  static const String voiceMessage = 'Voice message';

  /// Notification and chat-list preview of an image.
  static const String photo = 'Photo';

  static const String holdToRecord =
      'Hold the microphone to record a voice message';
  static const String slideToCancel = 'Slide to cancel';
  static const String releaseToCancel = 'Release to cancel';
  static const String recordingUnavailable =
      'Voice recording is not available on this device';
  static const String microphoneDenied =
      'Microphone access is needed to record voice messages';
  static const String recordingFailed = 'Could not start recording';
  static const String playbackUnavailable =
      'Voice playback is not available on this device';
  static const String playbackFailed = 'Could not play this voice message';
  static const String voiceNeedsCarrier =
      'Voice notes need a direct connection or a mesh path';
  static const String imageUnavailable = 'Image not available';
  static const String receiving = 'Receiving';
}
