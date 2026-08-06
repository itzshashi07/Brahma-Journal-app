import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:brahma_app/widgets/sacred.dart';

/// Regression test for the sign-in screen rendering with a black band below
/// the form.
///
/// SacredBackdrop paints the gradient on a Container wrapping a Stack whose
/// only non-Positioned child is the page content. A Stack sizes itself to its
/// largest non-positioned child, so on any screen whose content is shorter than
/// the viewport — sign-in, forgot-password, phone sign-in — the gradient
/// collapsed to the height of the form and the scaffold's flat black showed
/// through underneath.
void main() {
  Future<void> pumpWithContent(WidgetTester tester, double contentHeight) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SacredBackdrop(
            showMandala: false,
            child: SingleChildScrollView(
              child: SizedBox(height: contentHeight, key: const Key('content')),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('backdrop fills the screen when content is shorter than the viewport',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    // Deliberately short — this is the sign-in case that regressed.
    await pumpWithContent(tester, 200);

    final screen = tester.getSize(find.byType(MaterialApp));
    final backdrop = tester.getSize(find.byType(SacredBackdrop));

    expect(
      backdrop.height,
      screen.height,
      reason: 'backdrop must span the full screen, not collapse to content height',
    );
    expect(backdrop.width, screen.width);
  });

  testWidgets('backdrop still fills when content is taller than the viewport',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await pumpWithContent(tester, 5000);

    final screen = tester.getSize(find.byType(MaterialApp));
    final backdrop = tester.getSize(find.byType(SacredBackdrop));

    expect(backdrop.height, screen.height);
  });

  testWidgets('gradient is painted across the whole backdrop', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await pumpWithContent(tester, 200);

    // The gradient lives on the outermost Container inside SacredBackdrop.
    final container = tester.widget<Container>(
      find
          .descendant(
            of: find.byType(SacredBackdrop),
            matching: find.byType(Container),
          )
          .first,
    );
    final decoration = container.decoration as BoxDecoration;
    expect(decoration.gradient, isNotNull);

    final painted = tester.getSize(find.byType(SacredBackdrop));
    expect(painted.height, tester.getSize(find.byType(MaterialApp)).height);
  });
}
