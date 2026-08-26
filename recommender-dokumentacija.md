# Sistem preporuke kreditnih proizvoda

Dokumentacija odgovara implementaciji u
`backend/BankingApp.Infrastructure/Services/LoanRecommendationService.cs`.

---

## 1. Svrha sistema

Sistem preporucuje prijavljenom customeru **kreditni proizvod (Loan Product)**
koji najbolje odgovara njegovom trenutnom finansijskom profilu u banci.

Preporuka se koristi na ekranu **Loans** u mobilnoj aplikaciji: prikazuje se
kartica **"Recommended for you"** sa nazivom proizvoda, kamatnom stopom,
obrazlozenjem i dugmetom **Apply**, koje vodi u postojeci quote/application
flow.

Preporuka je **informativna** i ne predstavlja odobrenje kredita. Backend to
eksplicitno vraca u polju `disclaimer`, a mobilna aplikacija tu recenicu
prikazuje na samoj kartici.

---

## 2. Zasto rule-based pristup

Koristi se deterministicki, rule-based scoring model. Razlozi:

- Sistem ne posjeduje podatke kreditnog biroa, podatke o plati, zaposlenju niti
  istorijski dataset odobrenih/odbijenih kredita, pa nema osnove za treniranje
  ML modela.
- Rezultat je **objasnjiv** - svaki bod se moze pripisati konkretnom pravilu, a
  korisniku se vracaju tekstualni razlozi.
- Rezultat je **ponovljiv i testabilan**, sto je pokriveno unit testovima u
  `backend/BankingApp.Infrastructure.Tests/LoanRecommendationTests.cs`.

---

## 3. Ulazni podaci

Algoritam koristi iskljucivo podatke **prijavljenog** korisnika, uzete iz
tokena (`ICurrentUserService.UserId`), nikada sa klijenta:

| Izvor | Podatak | Upotreba |
|---|---|---|
| `Accounts` | valuta racuna | uslov prihvatljivosti (valutno poklapanje) |
| `Accounts` | zbir stanja po valuti | bodovanje (`Balance`) |
| `Transactions` | broj zavrsenih (`Completed`) transakcija u zadnjih 90 dana, grupisano po valuti racuna | bodovanje (`Activity`) |
| `Transactions` | zbir pozitivnih iznosa (prilivi) u istom periodu | bodovanje (`Inflow`) |
| `Loans` | postojanje kredita u statusu `Active` | blokada preporuke |
| `LoanApplications` | postojanje aplikacije u statusu `Pending` | blokada preporuke |
| `LoanProducts` | `IsActive`, valuta, `MinPrincipal`/`MaxPrincipal`, `AnnualInterestRate`, `MinTermMonths`/`MaxTermMonths`, `TermStepMonths` | prihvatljivost i bodovanje |

Algoritam **ne koristi**: platu, zaposlenje, dob, kreditni rejting, podatke
kreditnog biroa, niti podatke drugih korisnika. Ti podaci ne postoje u sistemu.

---

## 4. Uslovi prihvatljivosti (eligibility)

### 4.1. Kada korisnik ne moze dobiti preporuku

Provjere se izvrsavaju redom i prekidaju obradu:

| Uslov | Odgovor |
|---|---|
| Korisnik ima kredit u statusu `Active` | `canApply = false`, `blockReason = "A new recommendation is unavailable while you have an active loan."` |
| Korisnik ima aplikaciju u statusu `Pending` | `canApply = false`, `blockReason = "A new recommendation is unavailable while your application is pending."` |

U oba slucaja lista preporuka je prazna. Ovo je namjerno uskladjeno sa
postojecim apply flowom, koji takoder ne dozvoljava paralelnu aplikaciju.

### 4.2. Kada je proizvod prihvatljiv

Proizvod ulazi u bodovanje samo ako zadovoljava **sve** uslove:

- `IsActive = true`
- `MinPrincipal > 0` i `MaxPrincipal >= MinPrincipal`
- `AnnualInterestRate >= 0`
- `MinTermMonths > 0` i `MaxTermMonths >= MinTermMonths`
- `TermStepMonths > 0`
- **valuta proizvoda odgovara valuti bar jednog racuna korisnika**

Ako nijedan proizvod ne prode filter, odgovor je `canApply = true` sa praznom
listom - korisnik nije blokiran, ali nema sta da mu se preporuci.

---

## 5. Algoritam bodovanja

Maksimalan score je **100 bodova**, raspodijeljenih na pet kriterija:

| Kriterij | Maks. bodova | Pravilo |
|---|---:|---|
| Aktivnost racuna | 25 | `min(25, broj_transakcija * 5)` |
| Prilivi | 15 | punih 15 ako je zbir priliva > 0, inace 0 |
| Stanje racuna | 10 | punih 10 ako je zbir stanja u toj valuti > 0, inace 0 |
| Kamatna stopa | 30 | relativno, prema formuli ispod |
| Fleksibilnost roka | 20 | relativno, prema formuli ispod |

### 5.1. Aktivnost racuna (max 25)

```text
brojTransakcija = broj transakcija korisnika u valuti proizvoda
                  sa statusom Completed i datumom >= (danas - 90 dana)

bodoviAktivnosti = min(25, brojTransakcija * 5)
```

Dakle 5 bodova po transakciji, do gornje granice od 25 (5 i vise transakcija).

### 5.2. Prilivi (max 15)

```text
zbirPriliva = suma iznosa > 0 medju istim transakcijama

bodoviPriliva = (zbirPriliva > 0) ? 15 : 0
```

Bitno je **postojanje** priliva, ne njegova velicina.

### 5.3. Stanje racuna (max 10)

```text
bodoviStanja = (zbir stanja svih racuna u toj valuti > 0) ? 10 : 0
```

Ovo je slab signal koriscenja racuna, a **ne** procjena kreditne sposobnosti.
Ovaj kriterij namjerno ne generise tekstualni razlog za korisnika.

### 5.4. Kamatna stopa (max 30)

Bodovanje je relativno u odnosu na skup prihvatljivih proizvoda:

```text
minStopa = najniza kamatna stopa medju prihvatljivim proizvodima
maxStopa = najvisa kamatna stopa medju prihvatljivim proizvodima

ako je maxStopa == minStopa:
    bodoviKamate = 30
inace:
    bodoviKamate = 30 * (maxStopa - stopaProizvoda) / (maxStopa - minStopa)
```

Proizvod sa najnizom kamatom dobija punih 30, proizvod sa najvisom dobija 0.
Kada je prihvatljiv samo jedan proizvod, `maxStopa == minStopa`, pa on dobija
punih 30 bodova.

### 5.5. Fleksibilnost roka (max 20)

```text
rasponRoka        = MaxTermMonths - MinTermMonths (za taj proizvod)
maxRasponRoka     = max(1, najveci rasponRoka medju prihvatljivim proizvodima)

bodoviRoka = 20 * rasponRoka / maxRasponRoka
```

> **Napomena o implementaciji:** sve tri velicine su cijeli brojevi, pa se ovdje
> koristi cjelobrojno dijeljenje - rezultat se odsijeca na cijeli broj bodova.

### 5.6. Konacni score

```text
score = bodoviAktivnosti + bodoviPriliva + bodoviStanja
      + bodoviKamate + bodoviRoka

score = clamp(round(score), 0, 100)
```

---

## 6. Rangiranje i izbor proizvoda

Prihvatljivi proizvodi se sortiraju deterministicki, po sljedecim kljucevima:

1. **score** - opadajuce
2. **kamatna stopa** - rastuce (niza kamata pobjeduje kod istog scorea)
3. **naziv proizvoda** - rastuce
4. **ID proizvoda** - rastuce (stabilan konacni tie-break)

Vracaju se **najvise tri** proizvoda, sa poljem `rank` vrijednosti 1, 2 i 3.

Zbog cetvrtog kljuca poredak je uvijek isti za isti ulaz - dva uzastopna poziva
vracaju identican rezultat, sto je pokriveno testom
`Lower_interest_rate_wins_deterministically_when_other_signals_match`.

---

## 7. Rezultat preporuke

`GET /api/loans/recommendations` - zahtijeva JWT sa ulogom **Customer**
(`[Authorize(Roles = AppRoles.Customer)]`). Korisnik se identifikuje iskljucivo
iz tokena.

Struktura odgovora:

| Polje | Tip | Opis |
|---|---|---|
| `canApply` | bool | da li korisnik uopce moze dobiti preporuku |
| `blockReason` | string? | razlog blokade, `null` kada `canApply = true` |
| `disclaimer` | string | `"Recommendation is informational and does not represent loan approval."` |
| `recommendations` | lista | do tri rangirana proizvoda |

Svaka stavka liste sadrzi: `productId`, `productName`, `score`, `rank`,
`reasons`, `currency`, `interestRate`, `minAmount`, `maxAmount`,
`minTermMonths`, `maxTermMonths`.

### 7.1. Tekstualni razlozi

Razlozi se generisu redom, a u odgovor ulaze **prva tri**:

1. `"Matches your {VALUTA} account"` - uvijek prisutan
2. `"Your recent account activity matches this product"` - ako ima transakcija u zadnjih 90 dana
3. `"Recent completed inflows were detected in this currency"` - ako postoji priliv
4. `"Offers a lower interest rate among eligible products"` - ako proizvod ima najnizu kamatu
5. `"Offers flexible repayment terms"` - ako je raspon roka veci od nule

### 7.2. Koriscenje u mobilnoj aplikaciji

Mobilna aplikacija prikazuje **samo prvi rangirani proizvod** kao karticu
"Recommended for you", a od razloga ispisuje **prva dva** pod naslovom
"Why this fits:". Prikazuju se jos naziv proizvoda, kamatna stopa, dugme
**Apply** i disclaimer. Pull-to-refresh ponovo ucitava preporuku.

---

## 8. Demo scenario na seed bazi

Prijavite se u mobilnoj aplikaciji kao **Mobile Customer 1**
(`mobile@bankingapp.local`) ili **Mobile Customer 2**
(`recipient@bankingapp.local`), lozinka `test123`, i otvorite ekran **Loans**.

Oba naloga na cistoj seed bazi **mogu** dobiti preporuku: seed ne sadrzi nijedan
`Active` kredit ni `Pending` aplikaciju.

Polazno stanje je za oba customera simetricno:

- dva racuna, oba u **USD** (Checking 20.000,00 + Savings 5.000,00 = 25.000,00)
- **dvije** zavrsene transakcije u zadnjih 90 dana (transfer od 50 USD u svakom
  smjeru, seedovan sa datumom 25.08.2026.)
- priliv od 50,00 USD

Od tri seedovana proizvoda (BAM, EUR, USD) prihvatljiv je samo
**Personal Loan USD**, jer customeri nemaju BAM ni EUR racun.

Rezultat je za oba naloga **identican: Personal Loan USD, score 85/100**, sa
razlozima:

1. Matches your USD account
2. Your recent account activity matches this product
3. Recent completed inflows were detected in this currency

Scorevi se ne razlikuju jer je seed namjerno simetrican - oba customera imaju
ista stanja i po dvije transakcije sa prilivom.

> **Vremenska zavisnost:** kriterij aktivnosti gleda prozor od 90 dana. Seedovani
> transferi nose datum 25.08.2026. Nakon isteka tog prozora bodovi aktivnosti i
> priliva otpadaju, pa score pada na 60/100, a lista razloga se svodi na
> "Matches your USD account". Preporuka i dalje radi. Da bi demonstracija
> prikazala punih 85 bodova, dovoljno je prije prezentacije napraviti jedan
> transfer izmedju dva demo customera - time se ponovo popunjava prozor
> aktivnosti.

---

## 9. Primjer izracuna

**Ulaz:** Mobile Customer 1 na cistoj seed bazi.

| Velicina | Vrijednost |
|---|---|
| Valute racuna | USD |
| Zbir stanja u USD | 25.000,00 |
| Zavrsene transakcije u zadnjih 90 dana (USD) | 2 |
| Zbir priliva u zadnjih 90 dana (USD) | 50,00 |
| Prihvatljivi proizvodi | samo Personal Loan USD (6,00 %, rok 6-60 mj.) |

**Izracun po kriterijima:**

| Kriterij | Racun | Bodovi |
|---|---|---:|
| Aktivnost | `min(25, 2 * 5) = min(25, 10)` | **10** |
| Prilivi | `50,00 > 0` | **15** |
| Stanje | `25.000,00 > 0` | **10** |
| Kamata | jedini prihvatljiv proizvod, pa `maxStopa == minStopa` | **30** |
| Fleksibilnost roka | `rasponRoka = 60 - 6 = 54`; `maxRasponRoka = 54`; `20 * 54 / 54` | **20** |

**Zbir:**

```text
score = 10 + 15 + 10 + 30 + 20 = 85
score = clamp(round(85), 0, 100) = 85
```

**Rezultat:** `Personal Loan USD`, `rank = 1`, `score = 85`, `canApply = true`.

### 9.1. Ilustracija relativnog bodovanja kamate

Ako bi customer imao i BAM racun, prihvatljivi bi bili i BAM (6,50 %) i USD
(6,00 %) proizvod, pa bi `minStopa = 6,00` i `maxStopa = 6,50`:

```text
Personal Loan USD:  30 * (6,50 - 6,00) / (6,50 - 6,00) = 30 * 1,0 = 30
Personal Loan BAM:  30 * (6,50 - 6,50) / (6,50 - 6,00) = 30 * 0,0 =  0
```

USD proizvod bi zadrzao prednost od 30 bodova zbog nize kamate i dodatno dobio
razlog "Offers a lower interest rate among eligible products".

---

## 10. Sigurnost i privatnost

- Endpoint zahtijeva validan JWT sa ulogom `Customer`.
- Korisnicki ID se uzima **iz tokena**, nikada iz tijela ili query stringa, pa
  korisnik ne moze traziti preporuku za tudji nalog.
- Svi upiti su filtrirani po tom ID-u; podaci drugih korisnika se ne citaju.
  Ovo je pokriveno testom `Activity_is_isolated_by_customer_and_currency`.
- Upiti koriste `AsNoTracking`, jer je operacija iskljucivo za citanje.
- Postojeci lifecycle guard na nivou autentikacije blokira neaktivne korisnike.

---

## 11. Ogranicenja

- **Rule-based, ne ML.** Sistem nema model masinskog ucenja niti trening
  dataset; radi se o deterministickom scoring modelu sa fiksnim tezinama
  definisanim kao konstante u kodu.
- **Nije procjena kreditne sposobnosti i nije odobrenje kredita.** Score mjeri
  koliko proizvod odgovara profilu koriscenja racuna, a ne sposobnost otplate.
- **Zavisi iskljucivo od podataka dostupnih u banci.** Bez plate, zaposlenja,
  dobi i kreditnog biroa, model ne moze procijeniti rizik.
- **Uzak vremenski prozor.** Aktivnost se gleda samo 90 dana unazad, pa novi
  korisnici i korisnici bez skorasnjeg prometa dobijaju niske bodove aktivnosti.
- **Valutno ogranicenje.** Ako korisnik nema racun u valuti proizvoda, proizvod
  se uopste ne razmatra, bez obzira na ostale signale.
- **Relativno bodovanje kamate i roka.** Bodovi zavise od skupa trenutno
  prihvatljivih proizvoda, pa dodavanje novog proizvoda mijenja scorove
  postojecih.
- **Fiksne tezine.** Tezine nisu konfigurabilne kroz bazu ni admin UI; njihova
  izmjena zahtijeva izmjenu koda.

---

## 12. Moguca unapredjenja

Uz odgovarajucu pravnu osnovu i kvalitetnije podatke moguce je dodati:

- konfigurabilne tezine kriterija (baza ili admin UI umjesto konstanti),
- duzi i stabilniji model posmatranja priliva umjesto proste provjere "> 0",
- normalizaciju bodova stanja u odnosu na trazeni iznos kredita,
- kontrolisanu offline evaluaciju kvaliteta preporuka.

U svakom slucaju, preporuka bi i dalje ostala informativna - odluka o odobrenju
kredita ostaje na postojecem admin review procesu.
