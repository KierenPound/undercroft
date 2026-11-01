import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

/// Sage, matching the invite panel in the app.
const PdfColor _sage = PdfColor(0.357, 0.486, 0.416);
const PdfColor _sagePale = PdfColor(0.945, 0.957, 0.949);
const PdfColor _ink = PdfColor(0.13, 0.13, 0.14);
const PdfColor _muted = PdfColor(0.42, 0.42, 0.45);

const List<String> _months = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

/// Prints a handover sheet for a pending invite code.
///
/// The owner may be handing this to someone who has never heard of UnderCroft,
/// or filing it with a solicitor, so the sheet has to explain itself rather
/// than being six characters on a page. Raising the system print dialog also
/// gives "Save as PDF", so the same sheet can be filed electronically.
Future<void> printInviteSheet({
  required String code,
  required String roleLabel,
  required String estateName,
}) async {
  final document = pw.Document();
  final estate = estateName.trim().isEmpty ? 'This estate' : estateName.trim();
  final now = DateTime.now();

  document.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(56, 56, 56, 48),
      build: (context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'UnderCroft',
            style: pw.TextStyle(
              font: pw.Font.helveticaBold(),
              fontSize: 20,
              color: _sage,
            ),
          ),
          pw.SizedBox(height: 2),
          pw.Text(
            'Estate handover invitation',
            style: pw.TextStyle(
              font: pw.Font.helvetica(),
              fontSize: 11,
              color: _muted,
            ),
          ),
          pw.SizedBox(height: 16),
          pw.Divider(color: _sage, thickness: 0.75, height: 0.75),
          pw.SizedBox(height: 20),
          pw.Text(
            estate,
            style: pw.TextStyle(
              font: pw.Font.helveticaBold(),
              fontSize: 16,
              color: _ink,
            ),
          ),
          pw.SizedBox(height: 14),
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.symmetric(vertical: 18),
            decoration: pw.BoxDecoration(
              color: _sagePale,
              border: pw.Border.all(color: _sage, width: 0.75),
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: pw.Column(
              children: [
                pw.Text(
                  'INVITE CODE',
                  style: pw.TextStyle(
                    font: pw.Font.helvetica(),
                    fontSize: 9,
                    letterSpacing: 1.5,
                    color: _muted,
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.Text(
                  code,
                  style: pw.TextStyle(
                    font: pw.Font.courierBold(),
                    fontSize: 28,
                    letterSpacing: 8,
                    color: _sage,
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 14),
          pw.RichText(
            text: pw.TextSpan(
              style: pw.TextStyle(
                font: pw.Font.helvetica(),
                fontSize: 12,
                color: _ink,
              ),
              children: [
                const pw.TextSpan(
                  text: 'This code invites you to join the estate records. '
                      'Access level: ',
                ),
                pw.TextSpan(
                  text: roleLabel,
                  style: pw.TextStyle(
                    font: pw.Font.helveticaBold(),
                    color: _sage,
                  ),
                ),
                const pw.TextSpan(text: '.'),
              ],
            ),
          ),
          pw.SizedBox(height: 22),
          _heading('What UnderCroft is'),
          pw.Text(
            'UnderCroft keeps a household\'s practical information in one '
            'place — account numbers, legal documents, photos, contacts, '
            'tradespeople and instructions — so the right person can step in '
            'if the owner is unable to.',
            style: _body,
          ),
          pw.SizedBox(height: 18),
          _heading('How to use this code'),
          _step('1', 'Download the UnderCroft app.'),
          _step('2', 'Create an account with your own email address.'),
          _step(
              '3', 'Choose "I have an invite code" and enter the code above.'),
          pw.SizedBox(height: 22),
          _notice(),
          pw.Spacer(),
          pw.Text(
            'Printed ${_formatDate(now)}',
            style: pw.TextStyle(
              font: pw.Font.helvetica(),
              fontSize: 9,
              color: _muted,
            ),
          ),
        ],
      ),
    ),
  );

  await Printing.layoutPdf(
    onLayout: (format) => document.save(),
    name: 'UnderCroft invite code',
  );
}

final pw.TextStyle _body = pw.TextStyle(
  font: pw.Font.helvetica(),
  fontSize: 11,
  lineSpacing: 3,
  color: _ink,
);

pw.Widget _heading(String text) => pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 6),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          font: pw.Font.helveticaBold(),
          fontSize: 10,
          letterSpacing: 0.5,
          color: _sage,
        ),
      ),
    );

pw.Widget _step(String number, String text) => pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 4),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 16,
            child: pw.Text(number, style: _body),
          ),
          pw.Expanded(child: pw.Text(text, style: _body)),
        ],
      ),
    );

/// The code is a bearer token, so the sheet has to say so: whoever holds it
/// can walk in.
pw.Widget _notice() => pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _sage, width: 0.75),
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Text(
        'Keep this somewhere safe. Anyone who has this code can access the '
        'estate records, so treat it like a key.',
        style: pw.TextStyle(
          font: pw.Font.helveticaBold(),
          fontSize: 11,
          lineSpacing: 3,
          color: _ink,
        ),
      ),
    );

String _formatDate(DateTime date) =>
    '${date.day} ${_months[date.month - 1]} ${date.year}';
