import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/app_theme.dart';
import '../auth/auth_session.dart';
import 'card_models.dart';
import 'card_service.dart';

class MobileCardsScreen extends StatefulWidget {
  const MobileCardsScreen({
    super.key,
    required this.session,
    required this.onRequestCard,
  });

  final AuthSession session;
  final Future<void> Function() onRequestCard;

  @override
  State<MobileCardsScreen> createState() => _MobileCardsScreenState();
}

class _MobileCardsScreenState extends State<MobileCardsScreen> {
  late final CardService _cardService;
  late Future<_CardsScreenData> _cardsFuture;

  @override
  void initState() {
    super.initState();
    _cardService = CardService(ApiClient());
    _cardsFuture = _loadCards();
  }

  Future<_CardsScreenData> _loadCards() async {
    final token = widget.session.token;
    if (token == null) {
      throw ApiException('Sesija je istekla. Prijavite se ponovo.', 401);
    }

    final cards = await _cardService.getMyCards(token);
    final requests = await _cardService.getMyRequests(token);

    return _CardsScreenData(cards: cards, requests: requests);
  }

  void _refreshCards() {
    setState(() {
      _cardsFuture = _loadCards();
    });
  }

  Future<void> _openRequestCard() async {
    await widget.onRequestCard();
    _refreshCards();
  }

  Future<void> _uploadDocument(CardRequestModel request) async {
    final upload = await showModalBottomSheet<_DocumentUploadData>(
      context: context,
      isScrollControlled: true,
      builder: (context) => const _DocumentUploadSheet(),
    );

    if (upload == null) {
      return;
    }

    final token = widget.session.token;
    if (token == null) {
      return;
    }

    try {
      await _cardService.uploadDocument(
        token: token,
        requestId: request.id,
        fileName: upload.fileName,
        bytes: upload.bytes,
      );
      _refreshCards();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Document uploaded.')),
        );
      }
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.message)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        const Positioned(
          right: -190,
          top: 118,
          child: IgnorePointer(child: _CardsGlow()),
        ),
        FutureBuilder<_CardsScreenData>(
          future: _cardsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return _CardsErrorState(
                message: snapshot.error.toString(),
                onRetry: _refreshCards,
              );
            }

            final data = snapshot.requireData;
            final cards = data.cards;
            final requests = data.requests;
            return RefreshIndicator(
              onRefresh: () async => _refreshCards(),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(0, 0, 0, 176),
                children: [
                  if (cards.isEmpty)
                    const _EmptyCardsState()
                  else
                    ...cards.map(
                      (card) => Padding(
                        padding: const EdgeInsets.only(bottom: 22),
                        child: _MobileBankCard(card: card),
                      ),
                    ),
                  if (requests.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    _CardRequestsPanel(
                      requests: requests,
                      onUploadDocument: _uploadDocument,
                    ),
                  ],
                ],
              ),
            );
          },
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 84,
          child: ElevatedButton.icon(
            onPressed: _openRequestCard,
            icon: const Icon(Icons.add),
            label: const Text('Add Card'),
          ),
        ),
      ],
    );
  }
}

class _CardsScreenData {
  const _CardsScreenData({
    required this.cards,
    required this.requests,
  });

  final List<BankCardModel> cards;
  final List<CardRequestModel> requests;
}

class CardRequestScreen extends StatefulWidget {
  const CardRequestScreen({
    super.key,
    required this.session,
  });

  final AuthSession session;

  @override
  State<CardRequestScreen> createState() => _CardRequestScreenState();
}

class _CardRequestScreenState extends State<CardRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _documentController = TextEditingController();
  final _addressController = TextEditingController();
  final _noteController = TextEditingController();
  late final CardService _cardService;
  String _selectedCurrency = 'USD';
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _cardService = CardService(ApiClient());
  }

  @override
  void dispose() {
    _documentController.dispose();
    _addressController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final token = widget.session.token;
    if (token == null) {
      setState(() => _errorMessage = 'Sesija je istekla. Prijavite se ponovo.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _cardService.createRequest(
        token: token,
        cardholderName: _holderName(widget.session),
        currency: _selectedCurrency,
        documentNumber: _documentController.text.trim(),
        deliveryAddress: _addressController.text.trim(),
        note: _noteController.text.trim(),
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Account and card request sent for admin approval.'),
        ),
      );
      Navigator.of(context).pop(true);
    } on ApiException catch (error) {
      setState(() => _errorMessage = error.message);
    } catch (_) {
      setState(
        () => _errorMessage =
            'API nije dostupan. Provjerite da backend radi i da je API_BASE_URL ispravan.',
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            const Positioned(
              right: -210,
              top: 210,
              child: IgnorePointer(child: _CardsGlow()),
            ),
            ListView(
              padding: const EdgeInsets.fromLTRB(24, 18, 24, 28),
              children: [
                Row(
                  children: [
                    IconButton.filledTonal(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back_ios_new),
                      tooltip: 'Back',
                      style: IconButton.styleFrom(
                        backgroundColor: isDark
                            ? AppTheme.darkSurface
                            : const Color(0xFFF5F6FA),
                        foregroundColor: isDark ? Colors.white : AppTheme.textDark,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        'Request New Card',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
                const SizedBox(height: 28),
                const _MobileBankCard(),
                const SizedBox(height: 26),
                Text(
                  'Request Details',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      _RequestTextField(
                        label: 'Cardholder Name',
                        initialValue: _holderName(widget.session),
                        icon: Icons.person_outline,
                        readOnly: true,
                      ),
                      const SizedBox(height: 14),
                      DropdownButtonFormField<String>(
                        initialValue: _selectedCurrency,
                        decoration: const InputDecoration(
                          labelText: 'Requested currency',
                          prefixIcon: Icon(Icons.account_balance_wallet_outlined),
                        ),
                        items: const ['USD', 'EUR', 'BAM']
                            .map(
                              (currency) => DropdownMenuItem<String>(
                                value: currency,
                                child: Text(currency),
                              ),
                            )
                            .toList(),
                        onChanged: (currency) {
                          if (currency != null) {
                            setState(() => _selectedCurrency = currency);
                          }
                        },
                      ),
                      const SizedBox(height: 14),
                      _RequestTextField(
                        controller: _documentController,
                        label: 'Document ID Number',
                        icon: Icons.badge_outlined,
                        validator: _requiredValidator,
                      ),
                      const SizedBox(height: 14),
                      _RequestTextField(
                        controller: _addressController,
                        label: 'Delivery Address',
                        icon: Icons.location_on_outlined,
                        validator: _requiredValidator,
                      ),
                      const SizedBox(height: 14),
                      _RequestTextField(
                        controller: _noteController,
                        label: 'Request Note',
                        icon: Icons.notes_outlined,
                        maxLines: 2,
                      ),
                      if (_errorMessage != null) ...[
                        const SizedBox(height: 14),
                        Text(
                          _errorMessage!,
                          style: const TextStyle(
                            color: AppTheme.error,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                      const SizedBox(height: 28),
                      ElevatedButton(
                        onPressed: _isLoading ? null : _submit,
                        child: _isLoading
                            ? const SizedBox.square(
                                dimension: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Send Request'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RequestTextField extends StatelessWidget {
  const _RequestTextField({
    required this.label,
    required this.icon,
    this.controller,
    this.initialValue,
    this.readOnly = false,
    this.maxLines = 1,
    this.validator,
  });

  final String label;
  final IconData icon;
  final TextEditingController? controller;
  final String? initialValue;
  final bool readOnly;
  final int maxLines;
  final FormFieldValidator<String>? validator;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      initialValue: controller == null ? initialValue : null,
      readOnly: readOnly,
      maxLines: maxLines,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
      ),
    );
  }
}

class _EmptyCardsState extends StatelessWidget {
  const _EmptyCardsState();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : const Color(0xFFF5F6FA),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          const Icon(Icons.credit_card_off_outlined, size: 42),
          const SizedBox(height: 12),
          Text(
            'No cards yet',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          Text(
            'Request a card and admin will review it.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _CardRequestsPanel extends StatelessWidget {
  const _CardRequestsPanel({
    required this.requests,
    required this.onUploadDocument,
  });

  final List<CardRequestModel> requests;
  final ValueChanged<CardRequestModel> onUploadDocument;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : const Color(0xFFF5F6FA),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Card requests',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          ...requests.map(
            (request) => _CardRequestTile(
              request: request,
              onUploadDocument: onUploadDocument,
            ),
          ),
        ],
      ),
    );
  }
}

class _CardRequestTile extends StatelessWidget {
  const _CardRequestTile({
    required this.request,
    required this.onUploadDocument,
  });

  final CardRequestModel request;
  final ValueChanged<CardRequestModel> onUploadDocument;

  @override
  Widget build(BuildContext context) {
    final needsDocuments = request.statusValue == 4;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  color: Color(0x1A0066FF),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.credit_card, color: AppTheme.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${request.currency} card request',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      request.status,
                      style: TextStyle(
                        color: needsDocuments
                            ? const Color(0xFFB7791F)
                            : Theme.of(context).textTheme.bodySmall?.color,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              if (needsDocuments)
                TextButton(
                  onPressed: () => onUploadDocument(request),
                  child: const Text('Upload'),
                ),
            ],
          ),
          if (needsDocuments &&
              request.documentsRequestNote != null &&
              request.documentsRequestNote!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              request.documentsRequestNote!,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          if (request.documents.isNotEmpty) ...[
            const SizedBox(height: 8),
            ...request.documents.map(
              (document) => Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  children: [
                    const Icon(Icons.description_outlined, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        document.fileName,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DocumentUploadSheet extends StatefulWidget {
  const _DocumentUploadSheet();

  @override
  State<_DocumentUploadSheet> createState() => _DocumentUploadSheetState();
}

class _DocumentUploadSheetState extends State<_DocumentUploadSheet> {
  PlatformFile? _selectedFile;
  String? _errorMessage;

  Future<void> _pickFile() async {
    final result = await FilePicker.pickFiles(
      allowMultiple: false,
      withData: true,
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'pdf', 'txt'],
    );

    final file = result?.files.single;
    if (file == null) {
      return;
    }

    if (file.bytes == null || file.bytes!.isEmpty) {
      setState(() {
        _selectedFile = null;
        _errorMessage = 'Selected file could not be loaded.';
      });
      return;
    }

    setState(() {
      _selectedFile = file;
      _errorMessage = null;
    });
  }

  void _submit() {
    final file = _selectedFile;
    final bytes = file?.bytes;
    if (file == null || bytes == null || bytes.isEmpty) {
      setState(() => _errorMessage = 'Choose a document first.');
      return;
    }

    Navigator.of(context).pop(
      _DocumentUploadData(
        fileName: file.name,
        bytes: bytes,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(24, 20, 24, 24 + bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Upload document',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: _pickFile,
            icon: const Icon(Icons.attach_file),
            label: const Text('Choose file'),
          ),
          if (_selectedFile != null) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? AppTheme.darkSurface
                    : const Color(0xFFF5F6FA),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  const Icon(Icons.description_outlined),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _selectedFile!.name,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          _formatFileSize(_selectedFile!.size),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (_errorMessage != null) ...[
            const SizedBox(height: 12),
            Text(
              _errorMessage!,
              style: const TextStyle(
                color: AppTheme.error,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          const SizedBox(height: 18),
          ElevatedButton(
            onPressed: _submit,
            child: const Text('Upload Document'),
          ),
        ],
      ),
    );
  }
}

String _formatFileSize(int bytes) {
  if (bytes < 1024) {
    return '$bytes B';
  }

  final kilobytes = bytes / 1024;
  if (kilobytes < 1024) {
    return '${kilobytes.toStringAsFixed(1)} KB';
  }

  return '${(kilobytes / 1024).toStringAsFixed(1)} MB';
}

class _DocumentUploadData {
  const _DocumentUploadData({
    required this.fileName,
    required this.bytes,
  });

  final String fileName;
  final Uint8List bytes;
}

class _CardsErrorState extends StatelessWidget {
  const _CardsErrorState({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 14),
          ElevatedButton(
            onPressed: onRetry,
            child: const Text('Try again'),
          ),
        ],
      ),
    );
  }
}

class _MobileBankCard extends StatelessWidget {
  const _MobileBankCard({
    this.card,
  });

  final BankCardModel? card;

  @override
  Widget build(BuildContext context) {
    final groupedNumber = _formatCardNumber(card?.cardNumber ?? '');
    final isVisa = card?.brand == 'Visa';
    final holderName = card?.cardholderName ?? 'BankPick Customer';
    final expiry = card == null ? 'MM/YYYY' : _formatExpiry(card!.expiryDate);
    final cvv = card?.cvv ?? '****';

    return AspectRatio(
      aspectRatio: 335 / 199,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: isVisa ? const Color(0xFF292541) : const Color(0xFF25253D),
          borderRadius: BorderRadius.circular(25),
          border: Border.all(color: const Color(0xFF343552)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x1F0A1027),
              blurRadius: 24,
              offset: Offset(0, 12),
            ),
          ],
        ),
        child: Stack(
          children: [
            if (!isVisa)
              Positioned(
                left: 24,
                right: 20,
                top: 14,
                height: 92,
                child: Opacity(
                  opacity: 0.58,
                  child: Image.asset(
                    'assets/images/cards/worldmap.png',
                    fit: BoxFit.contain,
                    alignment: Alignment.topCenter,
                  ),
                ),
              ),
            if (!isVisa)
              Positioned(
                left: 24,
                top: 24,
                child: Image.asset(
                  'assets/icons/cards/chip.png',
                  width: 34,
                  height: 26,
                  fit: BoxFit.contain,
                ),
              )
            else
              const Positioned(
                left: 24,
                top: 24,
                child: Icon(Icons.credit_card, color: Color(0xFF6D7FE8), size: 30),
              ),
            if (!isVisa)
              const Positioned(
                right: 25,
                top: 28,
                child: _ContactlessIcon(),
              ),
            Positioned(
              left: 26,
              right: 26,
              top: isVisa ? 76 : 78,
              child: Text(
                groupedNumber,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 27,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0,
                ),
              ),
            ),
            Positioned(
              left: 26,
              top: isVisa ? 124 : 123,
              child: Text(
                holderName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const Positioned(
              left: 26,
              bottom: 38,
              child: Text(
                'Expiry Date',
                style: TextStyle(color: Color(0x99FFFFFF), fontSize: 11),
              ),
            ),
            Positioned(
              left: 26,
              bottom: 18,
              child: Text(
                expiry,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            if (!isVisa) ...[
              const Positioned(
                left: 112,
                bottom: 38,
                child: Text(
                  'CVV',
                  style: TextStyle(color: Color(0x99FFFFFF), fontSize: 11),
                ),
              ),
              Positioned(
                left: 112,
                bottom: 18,
                child: Text(
                  cvv,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
            Positioned(
              right: 28,
              bottom: isVisa ? 24 : 38,
              child: isVisa
                  ? const Text(
                      'VISA',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                        fontStyle: FontStyle.italic,
                      ),
                    )
                  : Image.asset(
                      'assets/icons/cards/mastercard.png',
                      width: 48,
                      height: 30,
                      fit: BoxFit.contain,
                    ),
            ),
            if (!isVisa)
              const Positioned(
                right: 28,
                bottom: 15,
                child: Text(
                  'Mastercard',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    height: 1.0,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CardsGlow extends StatelessWidget {
  const _CardsGlow();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 320,
      height: 320,
      decoration: const BoxDecoration(
        color: Color(0x333A66FF),
        shape: BoxShape.circle,
      ),
    );
  }
}

class _ContactlessIcon extends StatelessWidget {
  const _ContactlessIcon();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 27,
      height: 26,
      child: CustomPaint(
        painter: _ContactlessPainter(),
      ),
    );
  }
}

class _ContactlessPainter extends CustomPainter {
  const _ContactlessPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0x665C5A98)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 2.2;

    final center = Offset(0, size.height / 2);
    for (var i = 0; i < 4; i++) {
      final inset = i * 5.2;
      final rect = Rect.fromCircle(center: center, radius: 9 + inset);
      canvas.drawArc(rect, -0.72, 1.44, false, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

String _holderName(AuthSession session) {
  final firstName = session.user?.firstName ?? '';
  final lastName = session.user?.lastName ?? '';
  final fullName = '$firstName $lastName'.trim();
  return fullName.isEmpty ? 'BankPick Customer' : fullName;
}

String _formatCardNumber(String accountNumber) {
  final digits = accountNumber.replaceAll(RegExp('[^0-9]'), '');
  if (digits.length < 16) {
    return '4562  0000  0000  0000';
  }

  final cardDigits = digits.substring(0, 16);
  return '${cardDigits.substring(0, 4)}  ${cardDigits.substring(4, 8)}  '
      '${cardDigits.substring(8, 12)}  ${cardDigits.substring(12, 16)}';
}

String _formatExpiry(DateTime value) {
  return '${value.month.toString().padLeft(2, '0')}/${value.year}';
}

String? _requiredValidator(String? value) {
  if (value == null || value.trim().isEmpty) {
    return 'This field is required.';
  }

  return null;
}
