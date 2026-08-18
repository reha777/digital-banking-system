import 'package:flutter/material.dart';

import '../../../core/app_theme.dart';
import '../settings_models.dart';
import '../widgets/settings_widgets.dart';

class LanguagePage extends StatefulWidget {
  const LanguagePage({super.key, this.initialCode = 'en'});

  final String initialCode;

  @override
  State<LanguagePage> createState() => _LanguagePageState();
}

class _LanguagePageState extends State<LanguagePage> {
  late String _selectedCode = widget.initialCode;
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final languages = supportedLanguages
        .where(
          (language) =>
              language.displayName.toLowerCase().contains(_query.toLowerCase()),
        )
        .toList();
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: SettingsHeader(title: 'Language'),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextField(
                key: const ValueKey('language-search'),
                onChanged: (value) => setState(() => _query = value.trim()),
                decoration: const InputDecoration(
                  hintText: 'Search Language',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: languages.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final language = languages[index];
                  final selected = language.code == _selectedCode;
                  return ListTile(
                    key: ValueKey('language-${language.code}'),
                    contentPadding: EdgeInsets.zero,
                    title: Text(language.displayName),
                    trailing: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 180),
                      child: selected
                          ? const Icon(
                              Icons.check_circle,
                              key: ValueKey('selected'),
                              color: AppTheme.primary,
                            )
                          : const SizedBox(key: ValueKey('not-selected')),
                    ),
                    onTap: () => setState(() => _selectedCode = language.code),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
