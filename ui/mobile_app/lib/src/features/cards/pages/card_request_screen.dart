import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/api_client.dart';
import '../../../core/app_theme.dart';
import '../../auth/auth_session.dart';
import '../card_service.dart';
import '../widgets/bank_card.dart';
import '../widgets/card_request_form.dart';

class CardRequestScreen extends StatefulWidget {
  const CardRequestScreen({super.key, required this.session});

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
      if (!mounted) {
        return;
      }
      setState(() => _errorMessage = error.message);
    } catch (_) {
      if (!mounted) {
        return;
      }
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
              child: IgnorePointer(child: CardsGlow()),
            ),
            ListView(
              padding: const EdgeInsets.fromLTRB(24, 18, 24, 28),
              children: [
                Row(
                  children: [
                    IconButton.filledTonal(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(LucideIcons.arrowLeft),
                      tooltip: 'Back',
                      style: IconButton.styleFrom(
                        backgroundColor: isDark
                            ? AppTheme.darkSurface
                            : const Color(0xFFF5F6FA),
                        foregroundColor: isDark
                            ? Colors.white
                            : AppTheme.textDark,
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
                const BankCard(),
                const SizedBox(height: 26),
                Text(
                  'Request Details',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                CardRequestForm(
                  formKey: _formKey,
                  holderName: _holderName(widget.session),
                  selectedCurrency: _selectedCurrency,
                  documentController: _documentController,
                  addressController: _addressController,
                  noteController: _noteController,
                  isLoading: _isLoading,
                  errorMessage: _errorMessage,
                  onCurrencyChanged: (currency) {
                    setState(() => _selectedCurrency = currency);
                  },
                  onSubmit: _submit,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

String _holderName(AuthSession session) {
  final firstName = session.user?.firstName ?? '';
  final lastName = session.user?.lastName ?? '';
  final fullName = '$firstName $lastName'.trim();
  return fullName.isEmpty ? 'BankPick Customer' : fullName;
}
