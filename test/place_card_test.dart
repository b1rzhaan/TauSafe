import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tausafe/core/models.dart';
import 'package:tausafe/features/explore/explore_screen.dart';

void main() {
  testWidgets('legacy cached catalog renders a bounded, readable card', (
    tester,
  ) async {
    final place = Place({
      'id': 'medeu',
      'name': 'Medeu',
      'kind': 'Rink',
      'description': 'Mountain skating rink',
      'source': 'https://example.com',
    });
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            children: [
              Wrap(
                children: [
                  SizedBox(
                    width: 320,
                    child: PlaceCard(
                      place: place,
                      favorite: false,
                      onFavorite: () {},
                      onTap: () {},
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('Medeu'), findsOneWidget);
    expect(tester.getSize(find.byType(PlaceCard)).height, lessThan(450));
  });
}
