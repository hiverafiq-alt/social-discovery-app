import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import '../../app/providers.dart';
import '../../design/theme.dart';
import '../../core/config.dart';
import 'redaction.dart';

class RequestsScreen extends ConsumerWidget {
  const RequestsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    appBar: AppBar(title: const Text('Your requests')),
    body: ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Eyebrow('A little life, shared'),
        const SizedBox(height: 16),
        Text(
          'Your story.\nYour boundaries.',
          style: Theme.of(context).textTheme.headlineLarge,
        ),
        const SizedBox(height: 20),
        const Text(
          'Original bills stay private. Only a reviewed, safe summary may appear on your profile.',
          style: TextStyle(color: P.mist),
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: () => sheet(context, const BillComposer()),
          icon: const Icon(Icons.add),
          label: const Text('Share a request'),
        ),
        const SizedBox(height: 24),
        ref
            .watch(billsProvider)
            .when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => TextButton(
                onPressed: () => ref.invalidate(billsProvider),
                child: const Text('Retry requests'),
              ),
              data: (bills) => Column(
                children: [
                  if (bills.isEmpty)
                    const Panel(
                      child: Text(
                        'A request can be simple. Keep the story personal and the evidence private.',
                      ),
                    ),
                  ...bills.map(
                    (b) => Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Panel(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              b.title,
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 12),
                            Text('${b.amount} · ${b.category}'),
                            const SizedBox(height: 12),
                            Text(
                              b.status == 'approved'
                                  ? 'Reviewed summary'
                                  : b.status == 'rejected'
                                  ? 'Changes needed, contact support to appeal'
                                  : 'Private · Awaiting review',
                              style: const TextStyle(color: P.amber),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
      ],
    ),
  );
}

class BillComposer extends ConsumerStatefulWidget {
  const BillComposer({super.key});
  @override
  ConsumerState<BillComposer> createState() => _BillComposerState();
}

class _BillComposerState extends ConsumerState<BillComposer> {
  final title = TextEditingController(),
      merchant = TextEditingController(),
      amount = TextEditingController();
  File? file;
  String extension = 'jpg', currency = 'GBP', category = 'Everyday';
  bool confirmed = false, busy = false, sampleEvidence = false;
  @override
  void dispose() {
    title.dispose();
    merchant.dispose();
    amount.dispose();
    super.dispose();
  }

  Future<void> selectEvidence(File selected, String ext) async {
    if (ext != 'pdf') {
      final redacted = await Navigator.of(context).push<File>(
        MaterialPageRoute(builder: (_) => RedactionEditor(source: selected)),
      );
      if (redacted == null || !mounted) return;
      setState(() {
        file = redacted;
        extension = 'png';
      });
    } else {
      setState(() {
        file = selected;
        extension = ext;
      });
    }
  }

  Future<void> capture() async {
    if (AppConfig.webPreview) {
      setState(() => sampleEvidence = true);
      notice(
        context,
        'Sample evidence selected. No document is uploaded in this preview.',
      );
      return;
    }
    try {
      final image = await ImagePicker().pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
      );
      if (image != null && mounted) {
        await selectEvidence(File(image.path), 'jpg');
      }
    } catch (_) {
      if (mounted) {
        notice(
          context,
          'Camera access is unavailable. You can import an image or PDF.',
        );
      }
    }
  }

  Future<void> pick() async {
    if (AppConfig.webPreview) {
      setState(() => sampleEvidence = true);
      notice(
        context,
        'Sample evidence selected. No document is uploaded in this preview.',
      );
      return;
    }
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
    );
    if (result?.files.single.path != null && mounted) {
      await selectEvidence(
        File(result!.files.single.path!),
        result.files.single.extension!.toLowerCase(),
      );
    }
  }

  Future<void> submit() async {
    final value = double.tryParse(amount.text.replaceAll(',', '.'));
    if ((file == null && !sampleEvidence) ||
        value == null ||
        value <= 0 ||
        value > 500 ||
        title.text.trim().length < 3 ||
        merchant.text.trim().isEmpty ||
        !confirmed) {
      notice(
        context,
        'Add redacted evidence and complete the details. Test requests are limited to 500 in the selected currency.',
      );
      return;
    }
    if (file != null && await file!.length() > 10 * 1024 * 1024) {
      if (mounted && context.mounted) {
        notice(context, 'Evidence must be smaller than 10 MB.');
      }
      return;
    }
    setState(() => busy = true);
    try {
      await ref
          .read(repositoryProvider)
          .submitBill(
            title: title.text.trim(),
            merchant: merchant.text.trim(),
            amountMinor: (value * 100).round(),
            currency: currency,
            category: category,
            bytes: sampleEvidence ? <int>[] : await file!.readAsBytes(),
            extension: extension,
          );
      ref.invalidate(billsProvider);
      if (mounted && context.mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted && context.mounted) {
        notice(
          context,
          'Submission could not finish. Your evidence has not been published.',
        );
      }
    }
    if (mounted && context.mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Eyebrow('Private evidence, thoughtful summary'),
      const SizedBox(height: 16),
      Text(
        'A moment to share.',
        style: Theme.of(context).textTheme.headlineMedium,
      ),
      const SizedBox(height: 20),
      const Text(
        'Hide addresses, account and card numbers, QR codes and other private details. Images open in a redaction editor. Redact PDFs before importing. Automated reading and verification are not enabled in this build.',
        style: TextStyle(color: P.mist),
      ),
      const SizedBox(height: 20),
      Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: capture,
              icon: const Icon(Icons.document_scanner_outlined),
              label: const Text('Photograph'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: pick,
              icon: const Icon(Icons.upload_file),
              label: const Text('Import'),
            ),
          ),
        ],
      ),
      if (sampleEvidence) ...[
        const SizedBox(height: 16),
        const Panel(
          child: Text('Sample evidence only. Nothing is uploaded or verified.'),
        ),
      ],
      if (file != null) ...[
        const SizedBox(height: 16),
        if (extension != 'pdf')
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 220),
            child: Image.file(file!, fit: BoxFit.contain),
          ),
        const Text(
          'Evidence selected, private upload only',
          style: TextStyle(color: P.teal),
        ),
      ],
      const SizedBox(height: 20),
      TextField(
        controller: title,
        maxLength: 100,
        decoration: const InputDecoration(labelText: 'Safe public title'),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: merchant,
        maxLength: 100,
        decoration: const InputDecoration(labelText: 'Merchant, for review'),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: amount,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: const InputDecoration(labelText: 'Amount'),
      ),
      DropdownButton<String>(
        value: currency,
        isExpanded: true,
        items: [
          'GBP',
          'EUR',
          'AED',
          'USD',
        ].map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
        onChanged: (c) => setState(() => currency = c!),
      ),
      DropdownButton<String>(
        value: category,
        isExpanded: true,
        items: [
          'Everyday',
          'Learning',
          'Travel',
        ].map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
        onChanged: (c) => setState(() => category = c!),
      ),
      CheckboxListTile(
        contentPadding: EdgeInsets.zero,
        value: confirmed,
        title: const Text(
          'This is my lawful request. I removed unnecessary personal information.',
        ),
        onChanged: (v) => setState(() => confirmed = v!),
      ),
      const SizedBox(height: 20),
      FilledButton(
        onPressed: busy ? null : submit,
        child: Text(busy ? 'Submitting privately…' : 'Submit for review'),
      ),
    ],
  );
}
