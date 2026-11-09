import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/about_you.dart';
import '../models/ad_hoc_data.dart';
import '../models/checklist_item.dart';
import '../models/contact.dart';
import '../models/funeral_arrangement.dart';
import '../models/notify_account_details.dart';
import '../models/prep_section.dart';
import '../models/tradesperson.dart';
import '../models/utility_detail.dart';
import '../models/who_to_notify.dart';
import 'estate_service.dart';

/// Sage, matching the invite sheet so printed material looks like one family.
const PdfColor _sage = PdfColor(0.357, 0.486, 0.416);
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

/// Prints every saved text field and step for the estate.
///
/// Uploaded documents (wills, certificates, photos and scanned ID) are
/// deliberately left out: they live in the cloud and are not part of this
/// paper record. The system print preview opened here also carries the
/// platform's "Save as PDF" option, so the same sheet can be filed
/// electronically.
Future<void> printEstateData({required String estateId}) async {
  final document = await _buildDocument(estateId);
  await Printing.layoutPdf(
    onLayout: (format) => document.save(),
    name: 'UnderCroft estate record',
  );
}

Future<pw.Document> _buildDocument(String estateId) async {
  final data = await _fetchEstateData(estateId);
  final document = pw.Document();

  document.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(48, 48, 48, 40),
      footer: (context) => pw.Align(
        alignment: pw.Alignment.centerRight,
        child: pw.Text(
          'Page ${context.pageNumber} of ${context.pagesCount}',
          style: _bodyMuted,
        ),
      ),
      build: (context) => [
        _titleBlock(data),
        ..._aboutYouBlock(data),
        ..._sectionBlocks(data),
        ..._adHocBlock(data),
      ],
    ),
  );

  return document;
}

// MARK: - Data

class _EstateData {
  final String estateName;
  final EstateProcessRegion processRegion;
  final List<PrepSection> sections;
  final Map<String, List<ChecklistItem>> checklistBySection;
  final List<AboutYou> aboutYou;
  final List<Contact> contacts;
  final List<WhoToNotify> whoToNotify;
  final Map<String, List<NotifyAccountDetails>> accountDetailsByWtn;
  final List<Tradesperson> tradespeople;
  final List<UtilityDetail> utilities;
  final List<FuneralArrangement> funerals;
  final List<AdHocData> adHoc;

  const _EstateData({
    required this.estateName,
    required this.processRegion,
    required this.sections,
    required this.checklistBySection,
    required this.aboutYou,
    required this.contacts,
    required this.whoToNotify,
    required this.accountDetailsByWtn,
    required this.tradespeople,
    required this.utilities,
    required this.funerals,
    required this.adHoc,
  });
}

Future<_EstateData> _fetchEstateData(String estateId) async {
  final client = Supabase.instance.client;

  final estateRow = await client
      .from('estates')
      .select('name, process_region')
      .eq('id', estateId)
      .maybeSingle();

  final sectionRows =
      await client.from('sections').select().eq('estate_id', estateId).order(
            'order_index',
            ascending: true,
          );
  final sections = sectionRows.map((e) => PrepSection.fromJson(e)).toList();

  // Checklists are fetched in one query and bucketed by section, so a long
  // record does not fan out into a request per section.
  final checklistBySection = <String, List<ChecklistItem>>{};
  final sectionIds = sections.map((s) => s.id).toList();
  if (sectionIds.isNotEmpty) {
    final rows = await client
        .from('checklist_items')
        .select()
        .inFilter('section_id', sectionIds)
        .order('order_index', ascending: true);
    for (final row in rows) {
      final item = ChecklistItem.fromJson(row);
      checklistBySection.putIfAbsent(item.sectionId, () => []).add(item);
    }
  }

  final aboutYouRows = await client
      .from('about_you')
      .select()
      .eq('estate_id', estateId)
      .order('created_at', ascending: true);

  final contactRows = await client
      .from('contacts')
      .select()
      .eq('estate_id', estateId)
      .order('created_at', ascending: true);

  final wtnRows = await client
      .from('who_to_notify')
      .select()
      .eq('estate_id', estateId)
      .order('company_name', ascending: true);
  final whoToNotify = wtnRows.map((e) => WhoToNotify.fromJson(e)).toList();

  final accountDetailsByWtn = <String, List<NotifyAccountDetails>>{};
  final wtnIds = whoToNotify.map((w) => w.whoToNotifyId).toList();
  if (wtnIds.isNotEmpty) {
    final rows = await client
        .from('notify_account_details')
        .select()
        .inFilter('who_to_notify_id', wtnIds)
        .order('created_at', ascending: true);
    for (final row in rows) {
      final details = NotifyAccountDetails.fromJson(row);
      accountDetailsByWtn
          .putIfAbsent(details.whoToNotifyId, () => [])
          .add(details);
    }
  }

  final tradeRows = await client
      .from('tradespeople')
      .select()
      .eq('estate_id', estateId)
      .order('created_at', ascending: true);

  final utilityRows =
      await client.from('utility_details').select().eq('estate_id', estateId);

  final funeralRows = await client
      .from('funeral_arrangements')
      .select()
      .eq('estate_id', estateId)
      .order('created_at', ascending: true);

  final adHocRows = await client
      .from('ad_hoc_data')
      .select()
      .eq('estate_id', estateId)
      .order('created_at', ascending: true);

  return _EstateData(
    estateName: (estateRow?['name'] as String?) ?? '',
    processRegion: EstateProcessRegion.fromDbValue(
      estateRow?['process_region'] as String?,
    ),
    sections: sections,
    checklistBySection: checklistBySection,
    aboutYou: aboutYouRows.map((e) => AboutYou.fromJson(e)).toList(),
    contacts: contactRows.map((e) => Contact.fromJson(e)).toList(),
    whoToNotify: whoToNotify,
    accountDetailsByWtn: accountDetailsByWtn,
    tradespeople: tradeRows.map((e) => Tradesperson.fromJson(e)).toList(),
    utilities: utilityRows.map((e) => UtilityDetail.fromJson(e)).toList(),
    funerals: funeralRows.map((e) => FuneralArrangement.fromJson(e)).toList(),
    adHoc: adHocRows.map((e) => AdHocData.fromJson(e)).toList(),
  );
}

// MARK: - Layout

final pw.TextStyle _body = pw.TextStyle(
  font: pw.Font.helvetica(),
  fontSize: 11,
  lineSpacing: 2.5,
  color: _ink,
);

final pw.TextStyle _bodyBold = pw.TextStyle(
  font: pw.Font.helveticaBold(),
  fontSize: 11,
  lineSpacing: 2.5,
  color: _ink,
);

final pw.TextStyle _bodyMuted = pw.TextStyle(
  font: pw.Font.helvetica(),
  fontSize: 9,
  lineSpacing: 2,
  color: _muted,
);

pw.Widget _titleBlock(_EstateData data) {
  final name = data.estateName.trim();
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text(
        'UnderCroft',
        style: pw.TextStyle(
          font: pw.Font.helveticaBold(),
          fontSize: 22,
          color: _sage,
        ),
      ),
      pw.SizedBox(height: 2),
      pw.Text('Estate record', style: _bodyMuted),
      pw.SizedBox(height: 14),
      pw.Text(
        name.isEmpty ? 'Estate' : name,
        style: pw.TextStyle(
          font: pw.Font.helveticaBold(),
          fontSize: 16,
          color: _ink,
        ),
      ),
      pw.SizedBox(height: 4),
      pw.Text('Legal process: ${data.processRegion.label}', style: _bodyMuted),
      pw.Text('Generated ${_formatDate(DateTime.now())}', style: _bodyMuted),
      pw.SizedBox(height: 10),
      pw.Text(
        'This record lists the text and steps saved in UnderCroft. Uploaded '
        'documents such as wills, certificates, photos and scanned ID are '
        'kept securely in the app and are not included here.',
        style: _bodyMuted,
      ),
      pw.SizedBox(height: 8),
      pw.Divider(color: _sage, thickness: 0.75, height: 1),
    ],
  );
}

pw.Widget _heading(String text) => pw.Padding(
      padding: const pw.EdgeInsets.only(top: 20, bottom: 6),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            text,
            style: pw.TextStyle(
              font: pw.Font.helveticaBold(),
              fontSize: 15,
              color: _sage,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Divider(color: _sage, thickness: 0.6, height: 1),
        ],
      ),
    );

pw.Widget _subheading(String text) => pw.Padding(
      padding: const pw.EdgeInsets.only(top: 10, bottom: 4),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          font: pw.Font.helveticaBold(),
          fontSize: 11,
          letterSpacing: 0.3,
          color: _ink,
        ),
      ),
    );

/// A "label: value" line, or nothing at all when the value is blank.
List<pw.Widget> _field(String label, String? value) {
  final text = value?.trim() ?? '';
  if (text.isEmpty) return const [];
  return [
    pw.Padding(
      padding: const pw.EdgeInsets.only(left: 4, bottom: 3),
      child: pw.RichText(
        text: pw.TextSpan(
          style: _body,
          children: [
            pw.TextSpan(text: '$label: ', style: _bodyBold),
            pw.TextSpan(text: text),
          ],
        ),
      ),
    ),
  ];
}

pw.Widget _paragraph(String text) => pw.Padding(
      padding: const pw.EdgeInsets.only(left: 4, bottom: 4),
      child: pw.Text(text, style: _body),
    );

pw.Widget _boldLine(String text) => pw.Padding(
      padding: const pw.EdgeInsets.only(top: 4, bottom: 2),
      child: pw.Text(text, style: _bodyBold),
    );

pw.Widget _bullet(String text) => pw.Padding(
      padding: const pw.EdgeInsets.only(left: 8, bottom: 3),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('- ', style: _body),
          pw.Expanded(child: pw.Text(text, style: _body)),
        ],
      ),
    );

pw.Widget _checklistItem(bool done, String text) => pw.Padding(
      padding: const pw.EdgeInsets.only(left: 8, bottom: 3),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 22,
            child: pw.Text(done ? '[x]' : '[ ]', style: _body),
          ),
          pw.Expanded(child: pw.Text(text, style: _body)),
        ],
      ),
    );

String _formatDate(DateTime date) =>
    '${date.day} ${_months[date.month - 1]} ${date.year}';

// MARK: - Content

List<pw.Widget> _aboutYouBlock(_EstateData data) {
  if (data.aboutYou.isEmpty) return const [];
  final widgets = <pw.Widget>[_heading('About You')];
  for (final entry in data.aboutYou) {
    widgets.add(
      _boldLine(entry.fullName.trim().isEmpty ? 'Owner' : entry.fullName.trim()),
    );
    widgets.addAll(_field('NI number', entry.niNumber));
    widgets.addAll(_field('CHI number', entry.chiNumber));
  }
  return widgets;
}

List<pw.Widget> _sectionBlocks(_EstateData data) {
  final widgets = <pw.Widget>[];
  for (final section in data.sections) {
    // Readiness is a status page with nothing of its own to print.
    if (section.title == 'Readiness') continue;

    final title =
        section.title == 'Running the Houses' ? 'Running the House' : section.title;
    widgets.add(_heading(title));
    widgets.addAll(_sectionSpecific(data, section));

    final notes = section.notes.trim();
    if (notes.isNotEmpty) {
      widgets.add(_subheading('Notes'));
      widgets.add(_paragraph(notes));
    }

    final items = data.checklistBySection[section.id] ?? const [];
    if (items.isNotEmpty) {
      widgets.add(_subheading('Checklist'));
      for (final item in items) {
        widgets.add(_checklistItem(item.isCompleted, item.text));
      }
    }
  }
  return widgets;
}

List<pw.Widget> _sectionSpecific(_EstateData data, PrepSection section) {
  final title =
      section.title == 'Running the Houses' ? 'Running the House' : section.title;

  switch (title) {
    case 'My Letter to You':
      final letter = section.letterText.trim();
      return [
        _subheading('Letter'),
        letter.isEmpty
            ? _paragraph('No letter saved yet.')
            : _paragraph(letter),
      ];
    case 'What to Do First':
      return [
        ..._registrarBlock(section),
        ..._petsBlock(section),
        ..._phonesComputersBlock(section),
      ];
    case 'Legal Documents':
      return _solicitorBlock(section);
    case 'Who to Notify':
      return _whoToNotifyBlock(data);
    case 'Running the House':
      return _runningTheHouseBlock(data);
    case 'Funeral Arrangements':
      return _funeralBlock(data);
    case 'My Songs':
      return _songsBlock(section);
    default:
      return const [];
  }
}

List<pw.Widget> _registrarBlock(PrepSection section) {
  final fields = <pw.Widget>[
    ..._field('Registrar phone', section.registrarPhone),
    ..._field('Registrar email', section.registrarEmail),
    ..._field('Order certificates', section.certifiedCopiesUrl),
  ];
  if (fields.isEmpty) return const [];
  return [_subheading('Registrar'), ...fields];
}

List<pw.Widget> _petsBlock(PrepSection section) {
  final fields = <pw.Widget>[
    ..._field('Notes', section.petNotes),
    ..._field('Insurance company', section.petInsuranceCompany),
    ..._field('Policy number', section.petPolicyNumber),
    ..._field('Microchip number', section.petMicrochipNumber),
    ..._field('Vet', section.vetName),
    ..._field('Vet phone', section.vetPhone),
    ..._field('Vet website', section.vetUrl),
  ];
  if (fields.isEmpty) return const [];
  return [_subheading('Pets'), ...fields];
}

List<pw.Widget> _phonesComputersBlock(PrepSection section) {
  final fields = <pw.Widget>[
    ..._field('Phone PIN 1', section.phonePin1),
    ..._field('Computer password 1', section.computerPassword1),
    ..._field('Phone PIN 2', section.phonePin2),
    ..._field('Computer password 2', section.computerPassword2),
    ..._field('Wi-Fi password', section.wifiPassword),
  ];
  if (fields.isEmpty) return const [];
  return [_subheading('Phones / Computers'), ...fields];
}

List<pw.Widget> _solicitorBlock(PrepSection section) {
  final fields = <pw.Widget>[
    ..._field('Note', section.solicitorIntro),
    ..._field('Phone', section.solicitorPhone),
    ..._field('Email', section.solicitorEmail),
    ..._field('Website', section.solicitorUrl),
  ];
  if (fields.isEmpty) return const [];
  return [_subheading('Solicitor'), ...fields];
}

List<pw.Widget> _whoToNotifyBlock(_EstateData data) {
  final widgets = <pw.Widget>[];

  if (data.contacts.isNotEmpty) {
    widgets.add(_subheading('Contacts'));
    for (final contact in data.contacts) {
      final parts = <String>[
        if (contact.name.trim().isNotEmpty) contact.name.trim(),
        if (contact.telephone.trim().isNotEmpty) contact.telephone.trim(),
        if (contact.email.trim().isNotEmpty) contact.email.trim(),
      ];
      if (parts.isNotEmpty) widgets.add(_bullet(parts.join(' - ')));
    }
  }

  if (data.whoToNotify.isNotEmpty) {
    widgets.add(_subheading('Organisations'));
    for (final entry in data.whoToNotify) {
      widgets.add(_boldLine(entry.companyName.trim()));
      widgets.addAll(_field('Phone', entry.contactNumber));
      widgets.addAll(_field('Website', entry.weblink));
      widgets.addAll(_field('Notes', entry.supplementaryNotes));
      for (final details in data.accountDetailsByWtn[entry.whoToNotifyId] ??
          const []) {
        widgets.addAll(_field('Sort code', details.sortCode));
        widgets.addAll(_field('Account number', details.accountCode));
        widgets.addAll(_field('Other reference', details.otherCode));
        widgets.addAll(_field('Other description', details.otherDescription));
      }
    }
  }

  return widgets;
}

List<pw.Widget> _runningTheHouseBlock(_EstateData data) {
  final widgets = <pw.Widget>[];

  if (data.utilities.isNotEmpty) {
    widgets.add(_subheading('Utilities'));
    for (final utility in data.utilities) {
      widgets.add(_boldLine(utility.kind.label));
      widgets.addAll(_field('Where it is / how to read it', utility.notes));
    }
  }

  if (data.tradespeople.isNotEmpty) {
    widgets.add(_subheading('Tradespeople'));
    for (final trade in data.tradespeople) {
      widgets.add(
        _boldLine(trade.name.trim().isEmpty ? 'Tradesperson' : trade.name.trim()),
      );
      widgets.addAll(_field('Phone', trade.telephone));
      widgets.addAll(_field('Email', trade.email));
      widgets.addAll(_field('Website', trade.url));
      widgets.addAll(_field('Notes', trade.notes));
    }
  }

  return widgets;
}

List<pw.Widget> _funeralBlock(_EstateData data) {
  final widgets = <pw.Widget>[];
  for (final entry in data.funerals) {
    widgets.add(
      _boldLine(entry.name.trim().isEmpty ? 'Funeral arrangements' : entry.name.trim()),
    );
    widgets.addAll(_field('Wishes', entry.notes));
    widgets.addAll(_field('Prepaid details', entry.prepaidDetails));
    widgets.addAll(_field('Website', entry.url));
  }
  return widgets;
}

List<pw.Widget> _songsBlock(PrepSection section) {
  // Only a playlist the owner has actually saved is printed. An empty column
  // means the app is still showing its built-in starter list, which would
  // just add pages of noise to a paper record.
  final songs = _parseSongs(section.songsCsv);
  if (songs.isEmpty) return const [];
  return [
    _subheading('Playlist'),
    for (final song in songs) _bullet(song),
  ];
}

List<pw.Widget> _adHocBlock(_EstateData data) {
  if (data.adHoc.isEmpty) return const [];
  final widgets = <pw.Widget>[_heading('Ad Hoc Data')];
  for (final entry in data.adHoc) {
    widgets.add(_boldLine(entry.title.trim().isEmpty ? 'Entry' : entry.title.trim()));
    widgets.addAll(_field('Email', entry.email));
    widgets.addAll(_field('Website', entry.url));
    widgets.addAll(_field('Notes', entry.notes));
  }
  return widgets;
}

// MARK: - Playlist parsing

/// Turns the stored playlist CSV into printable "Title - Artist" lines.
///
/// Only well-formed rows survive: an 11-character video id is required, which
/// also filters out any header line without needing a separate check.
List<String> _parseSongs(String csv) {
  final trimmed = csv.trim();
  if (trimmed.isEmpty) return const [];

  final seen = <String>{};
  final songs = <String>[];

  final lines = trimmed
      .replaceAll('\r\n', '\n')
      .replaceAll('\r', '\n')
      .split('\n');

  for (final line in lines) {
    if (line.trim().isEmpty) continue;
    final fields = _splitCsvRow(line);
    if (fields.length < 3) continue;

    final id = fields[0].trim();
    if (id.length != 11 || !seen.add(id)) continue;

    final title = _unquoteCsv(fields[1]);
    if (title.isEmpty) continue;
    final artist = _unquoteCsv(fields[2]);

    songs.add(artist.isEmpty ? title : '$title - $artist');
  }

  return songs;
}

List<String> _splitCsvRow(String line) {
  final fields = <String>[];
  final current = StringBuffer();
  var inQuotes = false;

  for (var i = 0; i < line.length; i++) {
    final c = line[i];
    if (inQuotes) {
      if (c == '"') {
        if (i + 1 < line.length && line[i + 1] == '"') {
          current.write('"');
          i++;
        } else {
          inQuotes = false;
        }
      } else {
        current.write(c);
      }
    } else if (c == ',') {
      fields.add(current.toString());
      current.clear();
    } else if (c == '"') {
      inQuotes = true;
    } else {
      current.write(c);
    }
  }
  fields.add(current.toString());
  return fields;
}

String _unquoteCsv(String value) {
  var cleaned = value.trim();
  if (cleaned.length >= 2 && cleaned.startsWith('"') && cleaned.endsWith('"')) {
    cleaned = cleaned.substring(1, cleaned.length - 1);
  }
  return cleaned.replaceAll('""', '"').trim();
}
