# mStudent API — protocol reference (confirmed by live capture)

App: `com.simple.mSimple_Student` v2.6.9. Vendor: **Simple S.A.** Backend product: **bazus**.
Flutter/Dart client (`User-Agent: Dart/3.9 (dart:io)`). Verified against
`https://mstudent.umw.edu.pl` (UMW Wrocław) on 2026-11-22. 286 flows captured;
raw dump in `captures/raw.mitm`, decoded per-call JSON in `captures/flows/`.

Each university runs its own instance; base URL comes from discovery (§1).
All calls are HTTPS, JSON. The client pins the server cert via the
`http_certificate_pinning` plugin (see `docs/RUNBOOK.md` for the capture bypass).

## 1. University discovery (no auth)
`GET https://mlicenses.simple.com.pl/ifhavemstud.php` → `base64(XOR(json, key))`,
key = `921A2C25-B544-4328-BE47-527D63ED6374`. Gives each college's `simpleCoreURL`
(the API base), branding, and `czy_mfa`/`czy_ldap`. See `tools/discovery.py`,
`captures/colleges.json`. MFA (when `czy_mfa=1`): `GET …/index2fa.php?email=<email>`.

## 2. Authentication
### 2.1 Login
```
POST {base}/api/auth
Content-Type: application/json
{ "login": "<user>", "password": "<pass>", "applicationName": "mStudent" }
```
Response 200:
```jsonc
{
  "access_token": "<JWT RS256>",       // Bearer, ~1h
  "expire_in": 3600,
  "refresh_token": "<JWT HS256>",
  "token_type": "Bearer",
  "login": "<user>",
  "availableDataSources": [{
    "dataSourceName": "bazus",
    "identifiers": [
      { "identifier": "123456", "type": "BAZUS_USER_ID", "status": "ACTIVE" },
      { "identifier": "Imie Nazwisko", "type": "USER_NAME", "status": "ACTIVE" },
      { "identifier": "99999", "type": "STUDENT_ID", "status": "ACTIVE" }
    ]
  }]
}
```
- **`STUDENT_ID`** → `studentId` query param on all `/student/*` calls.
- **`BAZUS_USER_ID`** → `authId` query param on `infoByAuthId*`.
- `access_token` JWT payload: `{ sub=login, accountId, bazusSession, exp, type:"USER" }`
  (header `{ kid, alg:"RS256" }`). The server session lives in `bazusSession`.

Observed behaviour: the app re-POSTs `/api/auth` with credentials repeatedly
(every refresh / resume) rather than exercising `refresh_token`. A better client
can simply keep the `access_token` until `exp` and re-login (or try the refresh
token) on 401. Missing/expired token → `401 {timestamp,status,error,path}`.

### 2.2 Authenticated requests
Every non-auth call sends `Authorization: Bearer <access_token>`,
`Accept: application/json`. No cookies required.

## 3. Gateway prefixes
- Platform layer: `{base}/api/...`
- Core REST (bazus), **actual prefix**:
  `{base}/automatic/rest/mStudent/bazus/wsrest/rest/` then either `edu/api/...`
  or `wiadomosci/...`. (`mStudent` = application name; `bazus` = data source.)

Shorthand below: `CORE = {base}/automatic/rest/mStudent/bazus/wsrest/rest`.

## 4. Response envelope
Core (bazus) endpoints wrap payloads:
```jsonc
{ "status": "OK", "operationMessageList": null,
  "result": <object | array | null>,
  "totalResultCount": <int>, "fail": false, "success": true }
```
Platform `/api/*` endpoints return their object directly (no envelope).

## 5. Endpoints (confirmed)

### Platform
| Method | Path | Notes |
|---|---|---|
| POST | `/api/auth` | login (§2.1) |
| GET  | `/api/version` | app/server version gate |
| GET  | `/api/datastore/app/mStudent` | app config/key-values |
| GET  | `/api/applications/mStudent/functionality/` | enabled features |
| GET  | `/api/collegeconfiguration/collegeattributes` · `/collegeflags` | branding/flags |
| GET  | `/api/notifications/user/current/application/mStudent` | notifications |
| POST | `/api/notifications/receivers/current` | push receiver reg (401 until authed) |
| —    | `/api/definitions/mapplication/adduser` | device/FCM registration |

### Student — `CORE/edu/api/student/...`
| Path | Query | result |
|---|---|---|
| `infoByAuthId` / `infoByAuthIdWithPhoto` | `authId` | object: personal data (album nr, PESEL, names, addresses, documents, photo) |
| `kierunkiByStudentId` | `studentId` | [ {id, nazwa, wydzial, tryb, rodzaj, nabor, status} ] — degree programmes |
| `semestryByStudentIdAndKierunekId` | `studentId,kierunekId` | [ {id, nazwa, status, aktywny, semestr} ] |
| `grupyByStudentId` | `studentId` | [ group membership: kierunek/tryb/rok/specjalizacja + ids ] |
| `ocenyStudentaByStudentAndKierunekAndSemestr` | `studentId,kierunekId,semestr` | [ grades: dydaktyk, przedmiot, typPrzedmiotu, dataWystawienia, typZakonczenia, liczbaGodzin, liczbaPunktow(ECTS), numerTerminu ] |
| `sredniaOcenStudentaByStudent` (+ `…ByStudentAndKierunek`, `…SemestrByStudent`, `…RokByStudent`) | `studentId` (+kierunek/semestr/rok) | GPA (empty when none) |
| `bilansFinansowyByStudentId` | `studentId` | finance balance |
| `finanseNaleznosciByStudentId` | `studentId` | [ dues: rodzaj,typ,tytul,ma,pozostalo,rozliczono,waluta,czyDoOplaty,czyOpacono,mikroplatnoscSzczegoly,… ] |
| `finanseStypendiumByStudentId` | `studentId` | scholarships |
| `rachunkiBankoweByStudentId` | `studentId` | [ bank accounts: numerKonta, kontekst, kierunek,… ] |

### Timetable — `CORE/edu/api/planZajec/...`
| Path | Query | result |
|---|---|---|
| `planBySemestrAndZalogowany` | `semestr` | [ classes: przedmiot, typPrzedmiotu, grupa, temat, prowadzący(imie/nazwisko/tytul), sala+adres+**lat/long**, dzienTygodnia, odGodzina/doGodzina, odDzien/doDzien, rok ] |
| `planByKierunekAndSemestr` | kierunek/semestr | same shape |
| `planByRokAkademickiAndZalogowanyDydaktyk` | — | lecturer view |

### Messages — `CORE/wiadomosci/...`
| Path | Query | result |
|---|---|---|
| `grids/wiadomosciOdebrane` / `…Wyslane` / `…Zarchiwizowane` / `…WKoszu` | `start,limit,page` (required, e.g. `0,100,0`) | [ {id, temat, osoba, data, przeczytana} ] |
| `podglad/wiadomosc` | message id | {id, nadawca, odbiorcy, temat, tresc, data, zalaczniki[{zalacznikId,zalacznikNazwa}], idAuth…} |

### Dictionaries / lecturers — `CORE/edu/api/...`
| Path | result |
|---|---|
| `dictionary/rokAkademicki` | [ academic years {id,nazwa,rok,semestr,aktywny,nazwaSkr,rokAkademickiOd/Do} ] |
| `dydaktyk/wszyscyDydaktycy` | [ staff {id,imie,nazwisko,tytulNaukowy,email,telefon} ] |
| `dydaktyk/infoByDydaktykIdWithPhoto` | lecturer profile |

### Payments
`CORE/.../micropayment/oplacBM`, `…/oplacP24` — Przelewy24 / BLIK micropayments
(tied to `finanseNaleznosci.mikroplatnoscSzczegoly`). Not exercised in capture.

## 6. Minimal client flow
1. Discovery → pick `simpleCoreURL` for the university.
2. `POST /api/auth` → store `access_token`, `studentId`, `authId`.
3. `GET …/student/kierunkiByStudentId?studentId=…` → pick `kierunekId`.
4. `…/semestryByStudentIdAndKierunekId` → pick `semestr`.
5. Fan out: grades (`ocenyStudenta…`), timetable (`planBySemestrAndZalogowany`),
   finances, messages — all with `Authorization: Bearer <token>`.
6. On 401 → re-login.
