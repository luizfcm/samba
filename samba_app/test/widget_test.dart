import 'package:flutter_test/flutter_test.dart';
import 'package:samba_app/main.dart';

void main() {
  testWidgets('Teste de carregamento inicial', (WidgetTester tester) async {
    await tester.pumpWidget(const SambaApp());
  });
}