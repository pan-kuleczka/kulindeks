/// Typed models for the mStudent (bazus) API.
///
/// Field names mirror the server's Polish keys; getters expose friendlier names.
/// Every core response is wrapped in [ApiEnvelope].
library;

/// Core bazus response wrapper: {status, result, totalResultCount, success,...}.
class ApiEnvelope<T> {
  final String? status;
  final T? result;
  final int totalResultCount;
  final bool success;
  final bool fail;

  ApiEnvelope({
    this.status,
    this.result,
    this.totalResultCount = 0,
    this.success = false,
    this.fail = false,
  });

  static ApiEnvelope<R> parse<R>(
    Map<String, dynamic> json,
    R Function(Object? result) build,
  ) {
    return ApiEnvelope<R>(
      status: json['status'] as String?,
      result: json['result'] == null ? null : build(json['result']),
      totalResultCount: (json['totalResultCount'] as num?)?.toInt() ?? 0,
      success: json['success'] as bool? ?? false,
      fail: json['fail'] as bool? ?? false,
    );
  }
}

/// Result of POST /api/auth.
class AuthSession {
  final String accessToken;
  final String refreshToken;
  final String tokenType;
  final int expiresIn; // seconds
  final DateTime obtainedAt;
  final String login;
  final String? studentId;
  final String? authId; // BAZUS_USER_ID
  final String? userName;

  AuthSession({
    required this.accessToken,
    required this.refreshToken,
    required this.tokenType,
    required this.expiresIn,
    required this.obtainedAt,
    required this.login,
    this.studentId,
    this.authId,
    this.userName,
  });

  DateTime get expiresAt => obtainedAt.add(Duration(seconds: expiresIn));
  bool get isExpired => DateTime.now().isAfter(
        expiresAt.subtract(const Duration(seconds: 30)),
      );

  factory AuthSession.fromJson(Map<String, dynamic> j) {
    String? studentId, authId, userName;
    for (final src in (j['availableDataSources'] as List? ?? const [])) {
      for (final id in (src['identifiers'] as List? ?? const [])) {
        switch (id['type']) {
          case 'STUDENT_ID':
            studentId = id['identifier'] as String?;
          case 'BAZUS_USER_ID':
            authId = id['identifier'] as String?;
          case 'USER_NAME':
            userName = id['identifier'] as String?;
        }
      }
    }
    return AuthSession(
      accessToken: j['access_token'] as String,
      refreshToken: j['refresh_token'] as String? ?? '',
      tokenType: j['token_type'] as String? ?? 'Bearer',
      expiresIn: (j['expire_in'] as num?)?.toInt() ?? 3600,
      obtainedAt: DateTime.now(),
      login: j['login'] as String? ?? '',
      studentId: studentId,
      authId: authId,
      userName: userName,
    );
  }

  Map<String, dynamic> toJson() => {
        'access_token': accessToken,
        'refresh_token': refreshToken,
        'token_type': tokenType,
        'expire_in': expiresIn,
        'obtainedAt': obtainedAt.toIso8601String(),
        'login': login,
        'studentId': studentId,
        'authId': authId,
        'userName': userName,
      };

  factory AuthSession.fromCache(Map<String, dynamic> j) => AuthSession(
        accessToken: j['access_token'] as String,
        refreshToken: j['refresh_token'] as String? ?? '',
        tokenType: j['token_type'] as String? ?? 'Bearer',
        expiresIn: (j['expire_in'] as num?)?.toInt() ?? 3600,
        obtainedAt: DateTime.parse(j['obtainedAt'] as String),
        login: j['login'] as String? ?? '',
        studentId: j['studentId'] as String?,
        authId: j['authId'] as String?,
        userName: j['userName'] as String?,
      );
}

/// One university from the discovery endpoint.
class College {
  final String id;
  final String name;
  final String baseUrl;
  final String primaryColor;
  final String secondaryColor;
  final bool mfa;
  final bool ldap;
  final double? latitude;
  final double? longitude;

  College({
    required this.id,
    required this.name,
    required this.baseUrl,
    required this.primaryColor,
    required this.secondaryColor,
    required this.mfa,
    required this.ldap,
    this.latitude,
    this.longitude,
  });

  factory College.fromJson(Map<String, dynamic> j) => College(
        id: j['collegeAttributesId'] as String? ?? '',
        name: j['collegeName'] as String? ?? '',
        baseUrl: (j['simpleCoreURL'] as String? ?? '').trim(),
        primaryColor: j['primaryColor'] as String? ?? '#2962FF',
        secondaryColor: j['secondaryColor'] as String? ?? '#607D8B',
        mfa: j['czy_mfa'] == '1',
        ldap: j['czy_ldap'] == '1',
        latitude: double.tryParse(j['latitude']?.toString() ?? ''),
        longitude: double.tryParse(j['longitude']?.toString() ?? ''),
      );
}

/// Degree programme (kierunek).
class Kierunek {
  final int id;
  final String nazwa;
  final String wydzial;
  final String tryb;
  final String rodzaj;
  final String status;
  Kierunek(this.id, this.nazwa, this.wydzial, this.tryb, this.rodzaj, this.status);
  factory Kierunek.fromJson(Map<String, dynamic> j) => Kierunek(
        (j['id'] as num).toInt(),
        j['nazwa'] as String? ?? '',
        j['wydzial'] as String? ?? '',
        j['tryb'] as String? ?? '',
        j['rodzaj'] as String? ?? '',
        j['status'] as String? ?? '',
      );
}

/// Semester entry.
class Semestr {
  final int id;
  final String nazwa;
  final int semestr;
  final bool aktywny;
  final String status;
  Semestr(this.id, this.nazwa, this.semestr, this.aktywny, this.status);
  factory Semestr.fromJson(Map<String, dynamic> j) => Semestr(
        (j['id'] as num).toInt(),
        j['nazwa'] as String? ?? '',
        (j['semestr'] as num?)?.toInt() ?? 0,
        j['aktywny'] as bool? ?? false,
        j['status'] as String? ?? '',
      );
}

/// A single grade row.
class Grade {
  final String przedmiot;
  final String typPrzedmiotu;
  final String lecturer;
  final String grupa;
  final String? ocena; // nazwaOceny (may be null until graded)
  final String typZakonczenia;
  final double liczbaGodzin;
  final double ects; // liczbaPunktow
  final int numerTerminu;
  final DateTime? dataWystawienia;

  Grade({
    required this.przedmiot,
    required this.typPrzedmiotu,
    required this.lecturer,
    required this.grupa,
    required this.ocena,
    required this.typZakonczenia,
    required this.liczbaGodzin,
    required this.ects,
    required this.numerTerminu,
    required this.dataWystawienia,
  });

  factory Grade.fromJson(Map<String, dynamic> j) => Grade(
        przedmiot: j['przedmiot'] as String? ?? '',
        typPrzedmiotu: j['typPrzedmiotu'] as String? ?? '',
        lecturer: [
          j['dydaktykTytulNaukowy'],
          j['dydaktykImie'],
          j['dydaktykNazwisko'],
        ].whereType<String>().where((s) => s.isNotEmpty).join(' '),
        grupa: j['grupa'] as String? ?? '',
        ocena: j['nazwaOceny'] as String?,
        typZakonczenia: j['typZakonczenia'] as String? ?? '',
        liczbaGodzin: (j['liczbaGodzin'] as num?)?.toDouble() ?? 0,
        ects: (j['liczbaPunktow'] as num?)?.toDouble() ?? 0,
        numerTerminu: (j['numerTerminu'] as num?)?.toInt() ?? 1,
        dataWystawienia: _date(j['dataWystawienia']),
      );

  /// Numeric value of the Polish grade label, or null if not numeric.
  double? get numeric {
    final s = ocena?.replaceAll(',', '.');
    return s == null ? null : double.tryParse(s);
  }
}

/// One class/event in the timetable.
class ClassEvent {
  final String przedmiot;
  final String typPrzedmiotu;
  final String temat;
  final String grupa;
  final String lecturer;
  final String sala;
  final String salaAdres;
  final double? salaLat;
  final double? salaLong;
  final String dzienTygodnia;
  final DateTime? odDzien;
  final DateTime? doDzien;
  final String odGodzina;
  final String doGodzina;

  ClassEvent({
    required this.przedmiot,
    required this.typPrzedmiotu,
    required this.temat,
    required this.grupa,
    required this.lecturer,
    required this.sala,
    required this.salaAdres,
    required this.salaLat,
    required this.salaLong,
    required this.dzienTygodnia,
    required this.odDzien,
    required this.doDzien,
    required this.odGodzina,
    required this.doGodzina,
  });

  factory ClassEvent.fromJson(Map<String, dynamic> j) => ClassEvent(
        przedmiot: j['przedmiot'] as String? ?? '',
        typPrzedmiotu: j['typPrzedmiotu'] as String? ?? '',
        temat: j['temat'] as String? ?? '',
        grupa: j['grupa'] as String? ?? j['grupas'] as String? ?? '',
        lecturer: [j['tytul'], j['imie'], j['nazwisko']]
            .whereType<String>()
            .where((s) => s.isNotEmpty)
            .join(' '),
        sala: j['sala'] as String? ?? '',
        salaAdres: j['salaAdres'] as String? ?? '',
        salaLat: (j['sala_latitude'] as num?)?.toDouble(),
        salaLong: (j['sala_longitude'] as num?)?.toDouble(),
        dzienTygodnia: j['dzienTygodnia'] as String? ?? '',
        odDzien: _date(j['odDzien']),
        doDzien: _date(j['doDzien']),
        odGodzina: j['odGodzina'] as String? ?? '',
        doGodzina: j['doGodzina'] as String? ?? '',
      );
}

/// A financial due / liability.
class Naleznosc {
  final int id;
  final String rodzaj;
  final String typ;
  final String tytul;
  final double kwota; // ma
  final double pozostalo;
  final double rozliczono;
  final String waluta;
  final bool doZaplaty;
  final bool oplacono;
  Naleznosc({
    required this.id,
    required this.rodzaj,
    required this.typ,
    required this.tytul,
    required this.kwota,
    required this.pozostalo,
    required this.rozliczono,
    required this.waluta,
    required this.doZaplaty,
    required this.oplacono,
  });
  factory Naleznosc.fromJson(Map<String, dynamic> j) => Naleznosc(
        id: (j['idFinanse'] as num?)?.toInt() ?? 0,
        rodzaj: j['rodzaj'] as String? ?? '',
        typ: j['typ'] as String? ?? '',
        tytul: j['tytul'] as String? ?? '',
        kwota: (j['ma'] as num?)?.toDouble() ?? 0,
        pozostalo: (j['pozostalo'] as num?)?.toDouble() ?? 0,
        rozliczono: (j['rozliczono'] as num?)?.toDouble() ?? 0,
        waluta: j['waluta'] as String? ?? 'PLN',
        doZaplaty: j['czyDoOplaty'] as bool? ?? false,
        oplacono: j['czyOpacono'] as bool? ?? false,
      );
}

/// Message list row.
class MessageHeader {
  final int id;
  final String temat;
  final String osoba;
  final DateTime? data;
  final bool przeczytana;
  MessageHeader(this.id, this.temat, this.osoba, this.data, this.przeczytana);
  factory MessageHeader.fromJson(Map<String, dynamic> j) => MessageHeader(
        (j['id'] as num).toInt(),
        j['temat'] as String? ?? '',
        j['osoba'] as String? ?? '',
        _date(j['data']),
        j['przeczytana'] as bool? ?? false,
      );
}

/// Parse the API's date strings. The bazus API uses `DD-MM-YYYY` (e.g.
/// `01-10-2026`) for plan/message dates, but ISO-ish strings appear elsewhere.
/// Student group membership.
class Grupa {
  final int id;
  final String nazwa;
  final String typGrupy;
  final String kierunek;
  final String tryb;
  final String rodzaj;
  final String specjalizacja;
  final String jezyk;
  final int rokAkademicki;
  final bool aktywny;
  Grupa({
    required this.id,
    required this.nazwa,
    required this.typGrupy,
    required this.kierunek,
    required this.tryb,
    required this.rodzaj,
    required this.specjalizacja,
    required this.jezyk,
    required this.rokAkademicki,
    required this.aktywny,
  });
  factory Grupa.fromJson(Map<String, dynamic> j) => Grupa(
        id: (j['grupa_id'] as num?)?.toInt() ?? 0,
        nazwa: j['nazwa'] as String? ?? '',
        typGrupy: j['typ_grupy'] as String? ?? '',
        kierunek: j['kierunek_studiow'] as String? ?? '',
        tryb: j['tryb_studiow'] as String? ?? '',
        rodzaj: j['rodzaj_studiow'] as String? ?? '',
        specjalizacja: j['specjalizacja'] as String? ?? '',
        jezyk: j['jezyk'] as String? ?? '',
        rokAkademicki: (j['rok_akademicki'] as num?)?.toInt() ?? 0,
        aktywny: j['aktywny'] as bool? ?? false,
      );
}

/// Full message with body (HTML) and attachments.
class MessageDetail {
  final int id;
  final String nadawca;
  final String temat;
  final String tresc; // HTML
  final DateTime? data;
  final List<Attachment> zalaczniki;
  MessageDetail({
    required this.id,
    required this.nadawca,
    required this.temat,
    required this.tresc,
    required this.data,
    required this.zalaczniki,
  });
  factory MessageDetail.fromJson(Map<String, dynamic> j) => MessageDetail(
        id: (j['id'] as num?)?.toInt() ?? 0,
        nadawca: j['nadawca'] as String? ?? '',
        temat: j['temat'] as String? ?? '',
        tresc: j['tresc'] as String? ?? '',
        data: _date(j['data']),
        zalaczniki: ((j['zalaczniki'] as List?) ?? const [])
            .map((e) => Attachment.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class Attachment {
  final int id;
  final String nazwa;
  Attachment(this.id, this.nazwa);
  factory Attachment.fromJson(Map<String, dynamic> j) =>
      Attachment((j['zalacznikId'] as num?)?.toInt() ?? 0,
          j['zalacznikNazwa'] as String? ?? '');
}

DateTime? _date(Object? v) {
  if (v == null) return null;
  final s = v.toString().trim();
  if (s.isEmpty) return null;
  // DD-MM-YYYY or DD.MM.YYYY (optionally with a trailing time)
  final m = RegExp(r'^(\d{1,2})[-./](\d{1,2})[-./](\d{4})'
          r'(?:[ T](\d{1,2}):(\d{2}))?')
      .firstMatch(s);
  if (m != null) {
    return DateTime(
      int.parse(m[3]!), int.parse(m[2]!), int.parse(m[1]!),
      m[4] != null ? int.parse(m[4]!) : 0,
      m[5] != null ? int.parse(m[5]!) : 0,
    );
  }
  return DateTime.tryParse(s); // ISO fallback (YYYY-MM-DD…)
}
