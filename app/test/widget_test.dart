import 'package:flutter_test/flutter_test.dart';
import 'package:kulindeks/api/models.dart';
import 'package:kulindeks/ui/util.dart';

void main() {
  test('AuthSession parses identifiers and expiry', () {
    final s = AuthSession.fromJson({
      'access_token': 'a',
      'refresh_token': 'r',
      'token_type': 'Bearer',
      'expire_in': 3600,
      'login': 'u',
      'availableDataSources': [
        {
          'dataSourceName': 'bazus',
          'identifiers': [
            {'identifier': '12345', 'type': 'STUDENT_ID'},
            {'identifier': '67890', 'type': 'BAZUS_USER_ID'},
            {'identifier': 'Jan Kowalski', 'type': 'USER_NAME'},
          ],
        }
      ],
    });
    expect(s.studentId, '12345');
    expect(s.authId, '67890');
    expect(s.userName, 'Jan Kowalski');
    expect(s.isExpired, isFalse);
  });

  test('weighted GPA uses ECTS weights', () {
    final grades = [
      Grade.fromJson({'przedmiot': 'A', 'nazwaOceny': '5.0', 'liczbaPunktow': 6}),
      Grade.fromJson({'przedmiot': 'B', 'nazwaOceny': '3.0', 'liczbaPunktow': 2}),
      Grade.fromJson({'przedmiot': 'C', 'nazwaOceny': null, 'liczbaPunktow': 4}),
    ];
    // (5*6 + 3*2) / (6+2) = 36/8 = 4.5
    expect(weightedGpa(grades), closeTo(4.5, 1e-9));
    expect(meanGrade(grades), closeTo(4.0, 1e-9));
  });

  test('ICS export emits VEVENTs', () {
    final ev = ClassEvent.fromJson({
      'przedmiot': 'Anatomia',
      'typPrzedmiotu': 'wykład',
      'odDzien': '2026-10-05',
      'doDzien': '2026-10-05',
      'odGodzina': '08:00',
      'doGodzina': '09:30',
      'sala': 'A1',
    });
    final ics = buildIcs([ev]);
    expect(ics, contains('BEGIN:VEVENT'));
    expect(ics, contains('DTSTART:20261005T080000'));
    expect(ics, contains('SUMMARY:Anatomia'));
  });

  test('hexColor parses #rrggbb', () {
    expect(hexColor('#561032').toARGB32(), 0xFF561032);
  });

  test('DD-MM-YYYY plan dates parse and expand to the right day', () {
    final e = ClassEvent.fromJson({
      'przedmiot': 'Anatomia',
      'typPrzedmiotu': 'wykład',
      'dzienTygodnia': 'Czw.', // abbreviated — not weekly-recurring
      'odDzien': '01-10-2026', // DD-MM-YYYY
      'doDzien': '01-10-2026',
      'odGodzina': '15:00',
      'doGodzina': '16:30',
    });
    expect(e.odDzien, DateTime(2026, 10, 1));
    final byDay = expandOccurrences([e]);
    expect(byDay[dayKey(DateTime(2026, 10, 1))]?.length, 1);
  });

  test('occurrenceUid matches the Python sync daemon (cross-impl parity)', () {
    final e = ClassEvent.fromJson({
      'przedmiot': 'Anatomia',
      'typPrzedmiotu': 'wykład',
      'grupa': 'GR1',
      'odGodzina': '08:00',
    });
    // Python fnv1a of "Anatomia|wykład|GR1|2026-10-5|08:00"
    expect(occurrenceUid(e, DateTime.utc(2026, 10, 5)),
        'indeks-fcf72dfa@mstudent');
  });
}
