import 'generated/app_localizations.dart';

/// System messages are stored in English by ChatService (their text is part
/// of the message record and travels in group updates). This maps the known
/// forms to the active language at display time; unknown text is shown as is.
String localizeSystemMessage(AppLocalizations l, String text) {
  switch (text) {
    case 'Member removed':
      return l.sysMemberRemoved;
    case 'You left the group':
      return l.sysYouLeftGroup;
    case 'A member was removed':
      return l.sysAMemberWasRemoved;
    case 'You were removed from the group':
      return l.sysYouWereRemoved;
    case 'Group updated':
      return l.sysGroupUpdated;
  }
  RegExpMatch? m;
  if ((m = _groupCreated.firstMatch(text)) != null) {
    return l.sysGroupCreated(m!.group(1)!);
  }
  if ((m = _addedToGroupBy.firstMatch(text)) != null) {
    return l.sysAddedToGroupBy(m!.group(1)!, m.group(2)!);
  }
  if ((m = _renamedGroup.firstMatch(text)) != null) {
    return l.sysRenamedGroup(m!.group(1)!, m.group(2)!);
  }
  if ((m = _keysRotated.firstMatch(text)) != null) {
    return l.sysKeysRotated(m!.group(1)!);
  }
  if ((m = _updatedMembers.firstMatch(text)) != null) {
    return l.sysUpdatedMembers(m!.group(1)!);
  }
  if ((m = _leftGroup.firstMatch(text)) != null) {
    return l.sysLeftGroup(m!.group(1)!);
  }
  if ((m = _membersAdded.firstMatch(text)) != null) {
    return l.sysMembersAdded(m!.group(1)!);
  }
  return text;
}

final RegExp _groupCreated = RegExp(r'^Group "(.*)" created$');
final RegExp _addedToGroupBy = RegExp(r'^You were added to "(.*)" by (.+)$');
final RegExp _renamedGroup = RegExp(r'^(.+) renamed the group to "(.*)"$');
final RegExp _keysRotated =
    RegExp(r'^(.+) rotated their keys \(verified transition\)$');
final RegExp _updatedMembers = RegExp(r'^(.+) updated the members$');
final RegExp _leftGroup = RegExp(r'^(.+) left the group$');
final RegExp _membersAdded = RegExp(r'^(.+) added$');