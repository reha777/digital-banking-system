import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;
import 'package:mobile_app/src/core/api_client.dart';
import 'package:mobile_app/src/features/accounts/account_models.dart';
import 'package:mobile_app/src/features/auth/auth_models.dart';
import 'package:mobile_app/src/features/auth/auth_session.dart';
import 'package:mobile_app/src/features/cards/card_models.dart';
import 'package:mobile_app/src/features/home/widgets/home_quick_actions.dart';
import 'package:mobile_app/src/features/receive/pages/receive_money_page.dart';
import 'package:mobile_app/src/features/receive/receive_qr_payload.dart';
import 'package:mobile_app/src/features/receive/receive_qr_image_decoder.dart';
import 'package:mobile_app/src/features/receive/receive_recipient_resolver.dart';
import 'package:mobile_app/src/features/transactions/transaction_models.dart';
import 'package:mobile_app/src/features/transactions/transaction_service.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:zxing2/qrcode.dart';

const _accountOne = Account(
  id: 'account-1',
  accountNumber: 'BA-RECEIVE-001',
  balance: 100,
  currency: 'EUR',
);
const _accountTwo = Account(
  id: 'account-2',
  accountNumber: 'BA-RECEIVE-002',
  balance: 200,
  currency: 'USD',
);

void main() {
  test('valid Receive QR round-trips and contains only allowed fields', () {
    const payload = ReceiveQrPayload(
      accountNumber: 'BA-RECEIVE-001',
      currency: 'EUR',
    );
    final encoded = payload.encode();
    final decoded = ReceiveQrPayload.decode(encoded);
    expect(decoded.accountNumber, payload.accountNumber);
    expect(decoded.currency, payload.currency);
    expect(encoded, isNot(contains('4111111111111111')));
    expect(encoded.toLowerCase(), isNot(contains('cvv')));
    expect(encoded.toLowerCase(), isNot(contains('token')));
    expect(encoded.toLowerCase(), isNot(contains('balance')));
  });

  test('gallery image decoder reads a real Receive QR PNG', () {
    final payload = const ReceiveQrPayload(
      accountNumber: 'BA-RECEIVE-001',
      currency: 'EUR',
    ).encode();
    final matrix = Encoder.encode(payload, ErrorCorrectionLevel.h).matrix!;
    const scale = 8;
    final qrImage = image.Image(
      width: matrix.width * scale,
      height: matrix.height * scale,
      numChannels: 4,
    );
    image.fill(qrImage, color: image.ColorRgb8(255, 255, 255));
    for (var x = 0; x < matrix.width; x++) {
      for (var y = 0; y < matrix.height; y++) {
        if (matrix.get(x, y) == 1) {
          image.fillRect(
            qrImage,
            x1: x * scale,
            y1: y * scale,
            x2: (x + 1) * scale - 1,
            y2: (y + 1) * scale - 1,
            color: image.ColorRgb8(0, 0, 0),
          );
        }
      }
    }
    expect(
      const ReceiveQrImageDecoder().decode(image.encodePng(qrImage)),
      payload,
    );
  });

  test('malformed, unsupported version and wrong type are rejected', () {
    expect(
      () => ReceiveQrPayload.decode('not-json'),
      throwsA(isA<ReceiveQrPayloadException>()),
    );
    expect(
      () => ReceiveQrPayload.decode(
        '{"version":2,"type":"receive_money","accountNumber":"BA-1","currency":"EUR"}',
      ),
      throwsA(isA<ReceiveQrPayloadException>()),
    );
    expect(
      () => ReceiveQrPayload.decode(
        '{"version":1,"type":"login","accountNumber":"BA-1","currency":"EUR"}',
      ),
      throwsA(isA<ReceiveQrPayloadException>()),
    );
  });

  test('scanned account is selected only through recipient lookup', () async {
    final service = _FakeTransactionService();
    final recipient = await ReceiveRecipientResolver(service).resolve(
      rawValue: const ReceiveQrPayload(
        accountNumber: 'BA-DESTINATION',
        currency: 'EUR',
      ).encode(),
      sourceAccountNumber: 'BA-SOURCE',
      token: 'token',
    );
    expect(service.lookedUpAccount, 'BA-DESTINATION');
    expect(recipient.firstName, 'Verified');
  });

  test('scanned source account is rejected before recipient lookup', () async {
    final service = _FakeTransactionService();
    await expectLater(
      ReceiveRecipientResolver(service).resolve(
        rawValue: const ReceiveQrPayload(
          accountNumber: 'BA-SOURCE',
          currency: 'EUR',
        ).encode(),
        sourceAccountNumber: 'BA-SOURCE',
        token: 'token',
      ),
      throwsA(isA<ReceiveQrPayloadException>()),
    );
    expect(service.lookedUpAccount, isNull);
  });

  testWidgets('Home Receive action invokes navigation callback', (
    tester,
  ) async {
    var opened = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HomeQuickActions(onReceiveMoney: () => opened = true),
        ),
      ),
    );
    await tester.tap(find.text('Receive'));
    expect(opened, isTrue);
  });

  testWidgets('Receive renders authenticated holder and selected account', (
    tester,
  ) async {
    await _pumpReceive(
      tester,
      accounts: const [_accountOne],
      cards: [_cardOne],
    );
    expect(find.text('Test Customer'), findsWidgets);
    expect(find.text('EUR Account'), findsOneWidget);
    expect(find.text(_accountOne.accountNumber), findsWidgets);
    final qr = tester.widget<QrImageView>(find.byType(QrImageView));
    final encoded = (qr.key! as ValueKey<String>).value;
    expect(
      ReceiveQrPayload.decode(encoded).accountNumber,
      _accountOne.accountNumber,
    );
  });

  testWidgets('card swipe changes account details and QR payload', (
    tester,
  ) async {
    await _pumpReceive(
      tester,
      accounts: const [_accountOne, _accountTwo],
      cards: [_cardOne, _cardTwo],
    );
    await tester.drag(find.byType(PageView).first, const Offset(-360, 0));
    await tester.pumpAndSettle();
    expect(find.text(_accountTwo.accountNumber), findsWidgets);
    final qr = tester.widget<QrImageView>(find.byType(QrImageView));
    final payload = ReceiveQrPayload.decode(
      (qr.key! as ValueKey<String>).value,
    );
    expect(payload.accountNumber, _accountTwo.accountNumber);
    expect(payload.currency, 'USD');
  });

  testWidgets('Copy Account Number copies the full account number', (
    tester,
  ) async {
    String? copiedText;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copiedText =
              (call.arguments as Map<Object?, Object?>)['text'] as String?;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await _pumpReceive(
      tester,
      accounts: const [_accountOne],
      cards: [_cardOne],
    );
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('copy-account-number')),
      250,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.byKey(const ValueKey('copy-account-number')));
    await tester.pump();
    expect(copiedText, _accountOne.accountNumber);
    expect(find.text('Account number copied'), findsOneWidget);
  });

  testWidgets('Receive shows an empty state without accounts', (tester) async {
    await _pumpReceive(tester, accounts: const [], cards: const []);
    expect(find.text('No account available to receive money.'), findsOneWidget);
    expect(find.byType(QrImageView), findsNothing);
  });
}

Future<void> _pumpReceive(
  WidgetTester tester, {
  required List<Account> accounts,
  required List<BankCardModel> cards,
}) async {
  tester.view.physicalSize = const Size(430, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      home: ReceiveMoneyPage(
        session: _session(),
        initialSummary: AccountBalanceSummary(
          totals: const [],
          accounts: accounts,
        ),
        initialCards: cards,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

AuthSession _session() {
  final session = AuthSession(ApiClient());
  session.token = 'test-token';
  session.user = const AuthUser(
    id: 'user-1',
    firstName: 'Test',
    lastName: 'Customer',
    email: 'test@example.com',
    role: 'Customer',
  );
  return session;
}

final _cardOne = _card('card-1', _accountOne, '4111111111111111', '123');
final _cardTwo = _card('card-2', _accountTwo, '5555555555554444', '456');

BankCardModel _card(String id, Account account, String pan, String cvv) =>
    BankCardModel(
      id: id,
      accountId: account.id,
      accountNumber: account.accountNumber,
      cardNumber: pan,
      maskedCardNumber: '**** **** **** ${pan.substring(12)}',
      cardholderName: 'Test Customer',
      cvv: cvv,
      expiryDate: DateTime.utc(2030),
      brand: 'Mastercard',
      status: 'Active',
      balance: account.balance,
      currency: account.currency,
    );

class _FakeTransactionService extends TransactionService {
  _FakeTransactionService() : super(ApiClient());

  String? lookedUpAccount;

  @override
  Future<RecentRecipient> lookupRecipient({
    required String token,
    required String accountNumber,
  }) async {
    lookedUpAccount = accountNumber;
    return RecentRecipient(
      accountId: 'verified-account',
      firstName: 'Verified',
      lastName: 'Recipient',
      accountNumber: accountNumber,
    );
  }
}
