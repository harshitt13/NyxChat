import 'package:flutter_test/flutter_test.dart';
import 'package:nyxchat/core/crypto/nyx_id.dart';

void main() {
  test('NyxId format helpers', () {
    expect(NyxId.isModern('NC-0123456789ABCDEF'), isTrue);
    expect(NyxId.isLegacy('NC-AB12...CD34'), isTrue);
    expect(NyxId.isValidFormat('bogus'), isFalse);
  });
}
