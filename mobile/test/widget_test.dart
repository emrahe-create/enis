import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ai_wellness_mobile/src/features/app/presentation/splash_screen.dart';

void main() {
  testWidgets('Enis renders the Turkish-first splash', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SplashScreen()));

    expect(find.text('enis'), findsOneWidget);
    expect(find.text('İçinden geçenleri söyle.'), findsOneWidget);
  });
}
