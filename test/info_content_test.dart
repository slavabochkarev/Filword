import 'package:filword/ui/info_content.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('documents describe PoiskSlov without CrossSlow-only features', () {
    final allText = [privacyDocument, termsDocument, feedbackDocument]
        .expand((document) => document.sections)
        .map((section) => '${section.title} ${section.text}')
        .join(' ');
    expect(allText, contains('ПоискСлов'));
    expect(allText, contains('локально'));
    expect(allText, isNot(contains('КроссСлов')));
    expect(allText, contains('кристалл'));
    expect(allText, contains('незавершённого уровня'));
    expect(allText, isNot(contains('бесконечн')));
    expect(developerEmail, 'slavabochkarev@gmail.com');
    expect(developerTelegramUrl, 'https://t.me/slavabochkarev');
    expect(privacyPolicyUrl, 'https://bochk.ru/filword/privacy/');
    expect(userAgreementUrl, 'https://bochk.ru/filword/eula/');
  });
}
