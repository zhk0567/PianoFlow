import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:piano_flow/app.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('App boots to login with guest entry', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: PianoFlowApp()));
    await tester.pumpAndSettle();
    expect(find.text('PianoFlow'), findsWidgets);
    expect(find.textContaining('游客'), findsWidgets);
  });
}
