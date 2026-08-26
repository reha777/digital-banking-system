# Loan Product Recommender

## 1. Svrha

Recommender rangira do tri postojeća Loan proizvoda koja su najprikladnija trenutno prijavljenom customeru. Rezultat je informativan i nije odluka o odobrenju kredita.

## 2. Zašto rule-based pristup

Pristup je determinističan, objašnjiv i testabilan. Sistem nema kvalitetan ML dataset ni podatke kreditnog biroa, pa bi AI/ML tvrdnje bile obmanjujuće.

## 3. Ulazni podaci

Koriste se customer računi i njihove valute/balansi, završene transakcije u posljednjih 90 dana, aktivni Loan, Pending aplikacija te aktivni Loan proizvodi, kamate, iznosi i rokovi.

## 4. Eligibility pravila

Proizvod mora biti aktivan, imati ispravne iznose i rokove i customer mora imati račun iste valute. Aktivni Loan ili Pending aplikacija blokiraju novu preporuku, jednako kao postojeći apply flow.

## 5. Scoring algoritam

| Criterion | Weight | Reason |
|---|---:|---|
| Account activity | 25 | Do pet bodova po završenoj transakciji u posljednjih 90 dana |
| Incoming activity | 15 | Postoji pozitivan završeni priliv u valuti proizvoda |
| Available balance | 10 | Mali signal korištenja računa, ne kreditna sposobnost |
| Interest rate | 30 | Niža kamata među eligible proizvodima dobija više bodova |
| Term flexibility | 20 | Širi raspon rokova dobija više bodova |

Score se zaokružuje i ograničava na 0–100. Valutno poklapanje je eligibility uslov i ne sabira se sa drugim valutama.

## 6. Ranking

Poredak je: score silazno, kamata uzlazno, naziv proizvoda, pa stabilni product ID. Vraćaju se najviše tri rezultata.

## 7. Example

Demonstracijski customer ima BAM račun, pozitivne prilive i redovnu aktivnost. Personal Loan BAM sa nižom kamatom i širim rokovima postiže 84, a Quick Loan BAM 71. Personal Loan je prvi zbog kamate, aktivnosti iste valute i fleksibilnijeg roka.

## 8. API

`GET /api/loans/recommendations` zahtijeva Customer JWT. User ID se uzima iz tokena. Odgovor sadrži `canApply`, opcionalni `blockReason`, disclaimer i rangirane proizvode sa scoreom i stvarnim razlozima.

## 9. Mobile integration

Top rezultat se prikazuje kao suptilna "Recommended for you" kartica. Apply otvara postojeći quote/application flow. Pull-to-refresh ponovo učitava preporuku.

## 10. Security and Privacy

Upiti su ograničeni na authenticated customer ID. Ne koriste se podaci drugih korisnika, niti se user ID prima sa klijenta. Postojeći lifecycle guard blokira neaktivne korisnike.

## 11. Limitations

Ovo nije credit approval niti procjena kreditne sposobnosti. Ne koriste se plata, zaposlenje, dob, credit score, poslodavac ili kreditni biro jer ti podaci ne postoje u sistemu.

## 12. Future improvements

Uz pravnu osnovu i kvalitetne podatke moguće je dodati konfigurabilne težine, duži model stabilnosti priliva i kontrolisane offline evaluacije, bez automatskog donošenja odluke o kreditu.
