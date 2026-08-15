import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Setting ValueNotifier during build', (tester) async {
    final notifier = ValueNotifier<int>(0);
    await tester.pumpWidget(
      Builder(builder: (context) {
        notifier.value = 1;
        return const SizedBox();
      })
    );
    expect(notifier.value, 1);
  });
}
