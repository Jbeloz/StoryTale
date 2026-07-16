import 'package:flutter_test/flutter_test.dart';
import 'package:storytale/src/app.dart';

void main() {
  testWidgets('StoryTale shell navigates between its main sections', (
    tester,
  ) async {
    await tester.pumpWidget(const StoryTaleApp());

    expect(find.text('StoryTale'), findsOneWidget);
    expect(find.text('EPUB Library'), findsOneWidget);
    expect(find.text('Upload EPUB'), findsOneWidget);

    await tester.tap(find.text('Reader'));
    await tester.pumpAndSettle();
    expect(find.text('Reader & Translation'), findsOneWidget);

    await tester.tap(find.text('Story Mode'));
    await tester.pumpAndSettle();
    expect(find.text('Animated Story Mode'), findsOneWidget);
  });
}
