# Digital Banking

Seminarski projekat: digitalna bankarska platforma sa customer mobilnom
aplikacijom, admin desktop aplikacijom, REST API-jem, asinhronim workerom i
rule-based sistemom preporuke kreditnih proizvoda.

---

## 1. Arhitektura

| Komponenta | Tehnologija | Uloga |
|---|---|---|
| `backend/BankingApp.Api` | ASP.NET Core 9 Web API | REST API, JWT autentikacija, autorizacija po ulogama |
| `backend/BankingApp.Application` | .NET class library | Ugovori (DTO), interfejsi, izuzeci |
| `backend/BankingApp.Domain` | .NET class library | Entiteti i domenske konstante |
| `backend/BankingApp.Infrastructure` | EF Core 9 | Perzistencija, migracije, seed, servisi, RabbitMQ publisheri |
| SQL Server | `mcr.microsoft.com/mssql/server:2022` | Baza `220055` |
| RabbitMQ | `rabbitmq:4.1-management` | Redovi za audit arhivu i generisanje izvjestaja |
| `worker/BankingApp.Worker` | .NET Worker Service | Consumeri redova, generisanje PDF izvjestaja (QuestPDF), notifikacije o dospijecu |
| `ui/mobile_app` | Flutter (Android) | Customer aplikacija |
| `ui/desktop_app` | Flutter (Windows) | Admin aplikacija |
| Docker Compose | `docker-compose.yml` | Orkestracija cijelog stacka |

Sistem preporuke kreditnih proizvoda implementiran je u
`backend/BankingApp.Infrastructure/Services/LoanRecommendationService.cs` i
detaljno je opisan u [recommender-dokumentacija.md](recommender-dokumentacija.md).

Autentikacija koristi JWT access tokene sa server-side revokacijom
(`AccessTokenRevocations`) i refresh tokene. Komunikacija u seminarskom setupu
ide preko HTTP-a jer se radi o lokalnoj demonstraciji.

---

## 2. Preduslovi

- **Docker Desktop** (sa Docker Compose v2) - pokrece bazu, RabbitMQ, API i Worker
- **Flutter SDK** (stable) - za mobilnu i desktop aplikaciju
- **Android SDK + Android Emulator (AVD)** - ciljna platforma mobilne aplikacije
- **Visual Studio 2022 sa "Desktop development with C++"** - obavezno za
  `flutter build windows` (Windows desktop toolchain)
- **.NET 9 SDK** - potreban samo ako backend zelite pokretati izvan Dockera

Provjera Flutter okruzenja:

```bash
flutter doctor
```

---

## 3. Konfiguracija okruzenja

Runtime konfiguracija dolazi iz environment varijabli. U korijenu repozitorija
nalazi se `.env.example` kao **template**; stvarni `.env` je gitignorisan i
**ne pripada javnom repozitoriju** jer sadrzi lokalne lozinke i SMTP podatke.

```bash
cp .env.example .env
```

Zatim u `.env` popunite vrijednosti po kategorijama:

| Kategorija | Kljucevi | Napomena |
|---|---|---|
| Baza | `CONNECTIONSTRINGS__DEFAULTCONNECTION`, `DB_NAME`, `MSSQL_SA_PASSWORD`, `SQLSERVER_PORT` | `DB_NAME` mora ostati `220055` |
| API | `API_PORT`, `ASPNETCORE_ENVIRONMENT`, `CORS__ALLOWEDORIGINS__0`, `CORS__ALLOWEDORIGINS__1` | `API_PORT` je `5026` |
| JWT | `JWT__ISSUER`, `JWT__AUDIENCE`, `JWT__KEY`, `JWT__EXPIRATIONMINUTES`, `JWT__REFRESHTOKENEXPIRATIONDAYS` | `JWT__KEY` mora biti dug slucajan string |
| RabbitMQ (broker) | `RABBITMQ_DEFAULT_USER`, `RABBITMQ_DEFAULT_PASS`, `RABBITMQ_PORT`, `RABBITMQ_MANAGEMENT_PORT` | kreiraju korisnika u kontejneru |
| RabbitMQ (klijent) | `RABBITMQ__HOST`, `RABBITMQ__PORT`, `RABBITMQ__USERNAME`, `RABBITMQ__PASSWORD`, `RABBITMQ__AUDITARCHIVEQUEUE`, `RABBITMQ__REPORTGENERATIONQUEUE` | vrijednosti koje API i Worker vezu |
| DemoAuth | `DEMOAUTH__ENABLED`, `DEMOAUTH__CUSTOMERPRIMARYACCOUNTEMAIL`, `DEMOAUTH__CUSTOMERSECONDARYACCOUNTEMAIL`, `DEMOAUTH__ADMINACCOUNTEMAIL` | vidi sekciju 8 |
| SMTP | `EMAIL__PROVIDER`, `EMAIL__SMTPHOST`, `EMAIL__SMTPPORT`, `EMAIL__SMTPUSERNAME`, `EMAIL__SMTPPASSWORD`, `EMAIL__FROMADDRESS`, `EMAIL__FROMNAME`, `EMAIL__USESSL` | potrebno samo za Forgot Password demo |
| Worker | `AUDITARCHIVE__OUTPUTDIRECTORY`, `REPORTS__MAXROWS`, `NOTIFICATIONS__OVERDUE_CHECK_INTERVAL_SECONDS` | imaju razumne default vrijednosti |

**Nikada ne unosite stvarne SMTP lozinke, app-passworde ni JWT kljuceve u
`.env.example`, README ili bilo koji tracked fajl.**

API i Worker validiraju RabbitMQ konfiguraciju pri startu i namjerno odbijaju
da se pokrenu ako vrijednost nedostaje, umjesto da tiho padnu na `guest`.
`appsettings.json` sadrzi samo logging nivoe - sva runtime konfiguracija dolazi
iz okruzenja.

---

## 4. Pokretanje backenda

Iz korijena repozitorija:

```bash
docker compose up -d
```

Ova jedna komanda pokrece cijeli backend:

1. **`sqlserver`** - SQL Server; ceka se `healthcheck` prije pokretanja API-ja
2. **`rabbitmq`** - broker sa management UI-jem
3. **`api`** - pokrece se sa `Database__ApplyMigrations=true`, pa pri startu
   **kreira bazu `220055`, primjenjuje sve EF Core migracije i upisuje seed
   podatke** (tri demo naloga, racuni, kartice, historija transakcija, kreditni
   proizvodi)
4. **`worker`** - spaja se na RabbitMQ i konzumira redove za audit arhivu i
   generisanje izvjestaja

Provjera stanja:

```bash
docker compose ps
curl http://localhost:5026/health
```

Health endpoint `GET /health` vraca `200 Healthy` kada je API spreman.

| Servis | Adresa |
|---|---|
| API | `http://localhost:5026` |
| OpenAPI dokument (Development) | `http://localhost:5026/openapi/v1.json` |
| RabbitMQ Management UI | `http://localhost:15672` |
| SQL Server | `localhost:1433` |

Zaustavljanje (bez brisanja podataka):

```bash
docker compose down
```

### 4.1. Opcionalno: backend izvan Dockera

Samo za razvoj. Pokrenite infrastrukturu u Dockeru, a API lokalno:

```bash
docker compose up -d sqlserver rabbitmq
dotnet run --project backend/BankingApp.Api
```

> Lokalni `dotnet run` koristi port `5026` iz `launchSettings.json`, isti port
> koji zauzima `api` kontejner. Pokrenite samo jedan od njih. Uz to, lokalni
> `dotnet run` **ne primjenjuje migracije** osim ako u `.env` dodate
> `DATABASE__APPLYMIGRATIONS=true`.

---

## 5. Demo credentials

Pocetne lozinke na cistoj (seed) bazi:

| Uloga | Email | Lozinka |
|---|---|---|
| Desktop Admin | `admin@bankingapp.local` | `test123` |
| Mobile Customer 1 | `mobile@bankingapp.local` | `test123` |
| Mobile Customer 2 | `recipient@bankingapp.local` | `test123` |

Ako se demonstrira Forgot Password, lozinka odabranog seed naloga postaje nova
lozinka unesena u reset formi. Naredna prijava koristi **isti seed email** i tu
novu lozinku.

---

## 6. Demo seed podaci

Seed se primjenjuje automatski kroz EF Core migracije. Sve valute su **USD**.

**Racuni** (po dva za svakog customera):

| Customer | Broj racuna | Tip | Stanje |
|---|---|---|---|
| Mobile Customer 1 (`Demo Customer`) | `BA-000001-CHECKING` | Checking | 20.000,00 USD |
| Mobile Customer 1 | `BA-000001-SAVINGS` | Savings | 5.000,00 USD |
| Mobile Customer 2 (`Yamilet Recipient`) | `BA-000002-CHECKING` | Checking | 20.000,00 USD |
| Mobile Customer 2 | `BA-000002-SAVINGS` | Savings | 5.000,00 USD |

**Kartice:** cetiri aktivne Mastercard kartice, po jedna za svaki racun.

**Historija transakcija:** pocetni depoziti te **dva zavrsena transfera od po
50,00 USD u oba smjera** izmedju `BA-000001-CHECKING` i `BA-000002-CHECKING`.
Zahvaljujuci tome oba mobilna customera odmah imaju popunjenu listu **recent
recipients** i mogu jedan drugom slati novac bez rucnog unosa broja racuna.

**Kreditni proizvodi:** tri aktivna proizvoda, svi sa rokom 6-60 mjeseci
(korak 6 mjeseci):

| Proizvod | Valuta | Godisnja kamata | Iznos |
|---|---|---|---|
| Personal Loan BAM | BAM | 6,50 % | 1.000 - 50.000 |
| Personal Loan EUR | EUR | 5,75 % | 500 - 25.000 |
| Personal Loan USD | USD | 6,00 % | 500 - 25.000 |

> Posto demo customeri imaju iskljucivo USD racune, sistem preporuke im nudi
> samo **Personal Loan USD** - valutno poklapanje je uslov prihvatljivosti.

---

## 7. Pokretanje klijentskih aplikacija

### 7.1. Mobile (Android Emulator)

Mobilna aplikacija se demonstrira na **Android Emulatoru (AVD)**.

```bash
cd ui/mobile_app
flutter pub get
flutter run
```

Aplikacija se povezuje na:

```text
http://10.0.2.2:5026
```

`10.0.2.2` je posebna adresa Android Emulatora koja pokazuje na **localhost
host racunara**. Iz emulatora `localhost` pokazuje na sam emulator, pa se
`localhost` **ne smije** koristiti za pristup API-ju.

Ova vrijednost je ugradjen default u
`ui/mobile_app/lib/src/core/api_client.dart`, pa nije potreban nikakav dodatni
parametar. Android manifest sadrzi `INTERNET` i `CAMERA` dozvole, a
`network_security_config.xml` dozvoljava HTTP (cleartext) saobracaj iskljucivo
prema `10.0.2.2`.

### 7.2. Desktop (Windows)

```bash
cd ui/desktop_app
flutter pub get
flutter run -d windows
```

Desktop aplikacija se povezuje na:

```text
http://localhost:5026
```

To je ugradjen default u `ui/desktop_app/lib/src/core/api_client.dart`. Za
Windows se **ne koristi** `10.0.2.2`, jer desktop aplikacija radi direktno na
host racunaru.

> Chrome/web nije ciljna platforma ovog seminarskog rada. Finalna predaja su
> Android APK i Windows desktop build.

---

## 8. Forgot Password demo

Demo/Development flow za prezentaciju. U stvarnoj produkciji `DemoAuth` ostaje
iskljucen - API namjerno odbija start ako je `DemoAuth` ukljucen u
`Production` okruzenju.

Preduslovi:

1. U `.env` postavite `DEMOAUTH__ENABLED=true` i popunite stvarne SMTP podatke
   svog provajdera (`EMAIL__PROVIDER=Smtp` i `EMAIL__SMTP*`).
2. Klijentsku aplikaciju pokrenite sa ukljucenim demo prekidacem:

```bash
# Mobile
flutter run --dart-define=DEMO_AUTH_ENABLED=true

# Desktop
flutter run -d windows --dart-define=DEMO_AUTH_ENABLED=true
```

**Kljucno:** email koji unosite u formu je **delivery adresa** - adresa na koju
stize reset kod. To **nije** login email seed naloga. Nalog koji se resetuje
odredjuje se odabirom u aplikaciji (mobile) odnosno fiksno (desktop).

**Mobile flow:**

1. Otvorite **Forgot Password**.
2. U padajucem meniju **Demo account** izaberite **Mobile Customer 1** ili
   **Mobile Customer 2**.
3. Unesite svoju stvarnu email adresu na koju zelite primiti kod.
4. Kod iz emaila unesite u **Reset Password** i postavite novu lozinku.
5. Prijavite se sa seed emailom odabranog naloga
   (`mobile@bankingapp.local` ili `recipient@bankingapp.local`) i novom lozinkom.

**Desktop flow:**

1. Otvorite **Forgot Password**.
2. Unesite svoju stvarnu delivery email adresu (desktop uvijek resetuje admin
   nalog).
3. Kod iz emaila unesite u **Reset Password** i postavite novu lozinku.
4. Prijavite se sa `admin@bankingapp.local` i novom lozinkom.

Backend ugovor je `POST /api/auth/demo/forgot-password` sa tijelom
`{ "email": "<delivery-adresa>", "demoAccount": "customer-primary" }`, gdje
`demoAccount` moze biti `customer-primary`, `customer-secondary` ili `admin`.
Mapiranje na stvarne naloge dolazi iz `DEMOAUTH__*` konfiguracije. Endpoint je
rate-limitiran i vraca generican odgovor kako ne bi otkrivao postojanje naloga.

---

## 9. Demo: High-risk Transaction Review

Transfer se automatski salje na rucnu provjeru kada njegova vrijednost predje
**10.000,00 BAM**. Konverzija koristi fiksni demo kurs `1 USD = 1,80 BAM`, pa
je prag u dolarima **5.555,56 USD**. Za demonstraciju koristite **6.000 USD**
(= 10.800 BAM), sto je pokriveno stanjem od 20.000 USD na checking racunu.

Scenario:

1. **Mobile Customer 1** -> **Send Money** -> primalac `BA-000002-CHECKING`
   (nudi se i kao recent recipient) -> iznos **6000** USD -> potvrda.
2. Transakcija dobija status **Pending** i oznacena je kao high-risk; sredstva
   **nisu** skinuta sa racuna. Razlog je zabiljezen kao
   *"Transfer value exceeds 10,000.00 BAM review threshold."*
3. **Desktop Admin** dobija notifikaciju *"Transaction requires review"* i
   otvara **Transaction Review**.
4. Admin bira **Request Documents** i upisuje napomenu. Status prelazi u
   **DocumentsRequested**.
5. **Mobile Customer 1** dobija notifikaciju *"Transaction documents requested"*
   i kroz detalje transakcije **uploaduje dokument**.
6. **Desktop Admin** preuzima i pregleda dokument.
7. Admin bira **Approve** (sredstva se prenose, transakcija prelazi u
   Completed) ili **Reject** (transakcija se odbija).

Svaka admin akcija upisuje se u audit log.

---

## 10. Demo: preporuka kreditnog proizvoda

Prijavite se u mobilnoj aplikaciji kao **Mobile Customer 1** ili
**Mobile Customer 2** i otvorite ekran **Loans**. Na vrhu se prikazuje kartica
**"Recommended for you"** sa predlozenim proizvodom, skorom i obrazlozenjem.
**Apply** vodi u postojeci quote/application flow.

Na cistoj seed bazi oba customera dobijaju **Personal Loan USD** sa skorom
**85/100**.

Kompletan opis ulaznih podataka, uslova prihvatljivosti, formule bodovanja i
ogranicenja nalazi se u [recommender-dokumentacija.md](recommender-dokumentacija.md).

---

## 11. Release build

> Komande su navedene radi kompletnosti finalne predaje.

**Android APK:**

```bash
cd ui/mobile_app
flutter clean
flutter pub get
flutter build apk --release
```

Rezultat: `build/app/outputs/flutter-apk/app-release.apk`.
Release build **vec koristi** `http://10.0.2.2:5026` (ugradjen default), pa
`--dart-define=API_BASE_URL=...` nije potreban. Dodajte
`--dart-define=DEMO_AUTH_ENABLED=true` ako u APK-u zelite i Forgot Password
demo picker.

**Windows Desktop:**

```bash
cd ui/desktop_app
flutter clean
flutter pub get
flutter build windows --release
```

Rezultat: `build/windows/x64/runner/Release/`.
Release build **vec koristi** `http://localhost:5026` (ugradjen default).

---

## 12. Testovi

```bash
dotnet test backend/BankingApp.Infrastructure.Tests/BankingApp.Infrastructure.Tests.csproj
dotnet test worker/BankingApp.Worker.Tests/BankingApp.Worker.Tests.csproj
cd ui/mobile_app && flutter test
```

---

## 13. Sigurnosne napomene

- `.env` je gitignorisan i ne smije se commitati; `.env.example` sadrzi samo
  placeholdere.
- Demo credentials (`test123`) su namjerni seminarski seed podaci i nisu tajne.
- `DEMOAUTH__ENABLED=false` je ispravna vrijednost za produkcijsko okruzenje.
- HTTP (cleartext) se koristi samo za lokalnu seminarsku demonstraciju i
  ogranicen je na `10.0.2.2` u Android konfiguraciji.
