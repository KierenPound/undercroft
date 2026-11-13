import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/attachment.dart';
import '../../repositories/sections_repository.dart';
import '../../services/estate_service.dart';
import 'attachments_section.dart';
import 'photo_section.dart';
import 'song_for_the_page_section.dart';

const _scotlandCertifiedCopiesUrl = 'https://my.pkc.gov.uk/en';
const _ewniCertifiedCopiesUrl =
    'https://www.gov.uk/order-copy-birth-death-marriage-certificate';

/// What To Do First rich-media dashboard.
///
/// Cloned from the FamilyPrep (iOS) `WhatToDoFirstDashboardView`. Contains:
/// 1. Memory — a replaceable photo (defaults to the bundled
///    `assets/images/defaults/default_wtdf.jpeg`), persisted to Supabase
///    storage via the existing attachments mechanism.
/// 2. Immediate things you need to do
/// 3. Medical certificate
/// 4. Death certificate
class WhatToDoFirstDashboard extends ConsumerStatefulWidget {
  final String sectionId;
  final String estateId;
  final bool isOwner;
  final String youtubeUrl;

  const WhatToDoFirstDashboard({
    super.key,
    required this.sectionId,
    required this.estateId,
    required this.isOwner,
    required this.youtubeUrl,
  });

  @override
  ConsumerState<WhatToDoFirstDashboard> createState() =>
      _WhatToDoFirstDashboardState();
}

class _WhatToDoFirstDashboardState extends ConsumerState<WhatToDoFirstDashboard>
    with WidgetsBindingObserver {
  bool _uploading = false;

  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _copiesUrlController = TextEditingController();
  final _copiesUrlFocusNode = FocusNode();
  bool _copiesUrlDirty = false;
  bool _registrarInitialized = false;
  Timer? _registrarSaveTimer;
  Future<void> Function()? _pendingRegistrarSave;
  String _lastSavedPhone = '';
  String _lastSavedEmail = '';
  String _lastSavedCopiesUrl = '';

  // Phones / Computers credentials (blue set + pink set)
  final _phonePin1Controller = TextEditingController();
  final _computerPassword1Controller = TextEditingController();
  final _phonePin2Controller = TextEditingController();
  final _computerPassword2Controller = TextEditingController();
  final _wifiPasswordController = TextEditingController();
  Timer? _credentialsSaveTimer;
  String _lastSavedPhonePin1 = '';
  String _lastSavedComputerPassword1 = '';
  String _lastSavedPhonePin2 = '';
  String _lastSavedComputerPassword2 = '';
  String _lastSavedWifiPassword = '';
  final Set<String> _revealedCredentialKeys = <String>{};

  // Pets — photo + notes + insurer/microchip details + vet contact details.
  final _petNotesController = TextEditingController();
  final _petNotesFocusNode = FocusNode();
  final _petInsuranceCompanyController = TextEditingController();
  final _petInsuranceCompanyFocusNode = FocusNode();
  final _petPolicyNumberController = TextEditingController();
  final _petPolicyNumberFocusNode = FocusNode();
  final _petMicrochipNumberController = TextEditingController();
  final _petMicrochipNumberFocusNode = FocusNode();
  final _vetNameController = TextEditingController();
  final _vetNameFocusNode = FocusNode();
  final _vetPhoneController = TextEditingController();
  final _vetPhoneFocusNode = FocusNode();
  final _vetUrlController = TextEditingController();
  final _vetUrlFocusNode = FocusNode();
  Timer? _petSaveTimer;
  String _lastSavedPetNotes = '';
  String? _lastAppliedStoredPetNotes;
  String? _lastAppliedStoredPetInsuranceCompany;
  String? _lastAppliedStoredPetPolicyNumber;
  String? _lastAppliedStoredPetMicrochipNumber;
  String? _lastAppliedStoredVetName;
  String? _lastAppliedStoredVetPhone;
  String? _lastAppliedStoredVetUrl;
  String _lastSavedPetInsuranceCompany = '';
  String _lastSavedPetPolicyNumber = '';
  String _lastSavedPetMicrochipNumber = '';
  String _lastSavedVetName = '';
  String _lastSavedVetPhone = '';
  String _lastSavedVetUrl = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _copiesUrlFocusNode.addListener(_handleCopiesUrlFocusChange);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) _flushPendingSaves();
  }

  void _handleCopiesUrlFocusChange() {
    if (!_copiesUrlFocusNode.hasFocus && mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _flushPendingSaves();
    _phoneController.dispose();
    _emailController.dispose();
    _copiesUrlController.dispose();
    _copiesUrlFocusNode
      ..removeListener(_handleCopiesUrlFocusChange)
      ..dispose();
    _phonePin1Controller.dispose();
    _computerPassword1Controller.dispose();
    _phonePin2Controller.dispose();
    _computerPassword2Controller.dispose();
    _wifiPasswordController.dispose();
    _petNotesController.dispose();
    _petNotesFocusNode.dispose();
    _petInsuranceCompanyController.dispose();
    _petInsuranceCompanyFocusNode.dispose();
    _petPolicyNumberController.dispose();
    _petPolicyNumberFocusNode.dispose();
    _petMicrochipNumberController.dispose();
    _petMicrochipNumberFocusNode.dispose();
    _vetNameController.dispose();
    _vetNameFocusNode.dispose();
    _vetPhoneController.dispose();
    _vetPhoneFocusNode.dispose();
    _vetUrlController.dispose();
    _vetUrlFocusNode.dispose();
    super.dispose();
  }

  void _flushPendingSaves() {
    final petPending = _petSaveTimer?.isActive ?? false;
    final registrarSave = _pendingRegistrarSave;
    final credentialsPending = _credentialsSaveTimer?.isActive ?? false;

    _petSaveTimer?.cancel();
    _petSaveTimer = null;
    _registrarSaveTimer?.cancel();
    _registrarSaveTimer = null;
    _pendingRegistrarSave = null;
    _credentialsSaveTimer?.cancel();
    _credentialsSaveTimer = null;

    if (petPending) unawaited(_savePetFields());
    if (registrarSave != null) unawaited(registrarSave());
    if (credentialsPending) unawaited(_saveCredentials());
  }

  String get _effectiveVetPhone => _vetPhoneController.text.trim();

  String get _effectiveVetUrl => _vetUrlController.text.trim();

  void _schedulePetSave() {
    _petSaveTimer?.cancel();
    _petSaveTimer = Timer(const Duration(milliseconds: 500), _savePetFields);
  }

  Future<void> _savePetFields() async {
    final notes = _petNotesController.text;
    final insuranceCompany = _petInsuranceCompanyController.text.trim();
    final policyNumber = _petPolicyNumberController.text.trim();
    final microchipNumber = _petMicrochipNumberController.text.trim();
    final vetName = _vetNameController.text.trim();
    final vetPhone = _vetPhoneController.text.trim();
    final vetUrl = _vetUrlController.text.trim();
    if (notes == _lastSavedPetNotes &&
        insuranceCompany == _lastSavedPetInsuranceCompany &&
        policyNumber == _lastSavedPetPolicyNumber &&
        microchipNumber == _lastSavedPetMicrochipNumber &&
        vetName == _lastSavedVetName &&
        vetPhone == _lastSavedVetPhone &&
        vetUrl == _lastSavedVetUrl) {
      return;
    }

    final repo = ref.read(sectionsRepositoryProvider);
    try {
      final section = ref.read(sectionProvider(widget.sectionId)).valueOrNull;
      if (section != null) {
        await repo.updateSection(
          section.copyWith(
            petNotes: notes,
            petInsuranceCompany: insuranceCompany,
            petPolicyNumber: policyNumber,
            petMicrochipNumber: microchipNumber,
            vetName: vetName,
            vetPhone: vetPhone,
            vetUrl: vetUrl,
          ),
        );
        _lastSavedPetNotes = notes;
        _lastSavedPetInsuranceCompany = insuranceCompany;
        _lastSavedPetPolicyNumber = policyNumber;
        _lastSavedPetMicrochipNumber = microchipNumber;
        _lastSavedVetName = vetName;
        _lastSavedVetPhone = vetPhone;
        _lastSavedVetUrl = vetUrl;
        if (mounted) ref.invalidate(sectionProvider(widget.sectionId));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to save pet details')),
        );
      }
    }
  }

  String get _effectivePhone => _phoneController.text.trim();

  String get _effectiveEmail => _emailController.text.trim();

  void _scheduleRegistrarSave() {
    _scheduleRegistrarSaveCallback(_saveRegistrarContact);
  }

  void _scheduleCopiesUrlSave() {
    _scheduleRegistrarSaveCallback(_saveCopiesUrl);
  }

  void _scheduleRegistrarSaveCallback(Future<void> Function() save) {
    _registrarSaveTimer?.cancel();
    _pendingRegistrarSave = save;
    _registrarSaveTimer = Timer(const Duration(milliseconds: 500), () {
      final pendingSave = _pendingRegistrarSave;
      _pendingRegistrarSave = null;
      _registrarSaveTimer = null;
      if (pendingSave != null) unawaited(pendingSave());
    });
  }

  void _onCopiesUrlChanged(String _) {
    _copiesUrlDirty = true;
    _scheduleCopiesUrlSave();
  }

  String get _currentCopiesDefaultUrl {
    final processRegion = ref.read(estateProcessRegionProvider).valueOrNull ??
        EstateProcessRegion.scotland;
    return processRegion == EstateProcessRegion.ewni
        ? _ewniCertifiedCopiesUrl
        : _scotlandCertifiedCopiesUrl;
  }

  Future<void> _saveCopiesUrl() async {
    final url = _copiesUrlController.text.trim();
    if (url == _lastSavedCopiesUrl) {
      _copiesUrlDirty = false;
      if (url.isEmpty) {
        _copiesUrlController.text = _currentCopiesDefaultUrl;
      }
      return;
    }

    final repo = ref.read(sectionsRepositoryProvider);
    try {
      final section = ref.read(sectionProvider(widget.sectionId)).valueOrNull;
      if (section != null) {
        await repo.updateSection(
          section.copyWith(certifiedCopiesUrl: url),
        );
        _lastSavedCopiesUrl = url;
        if (mounted) ref.invalidate(sectionProvider(widget.sectionId));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to save link')),
        );
      }
    }
  }

  Future<void> _saveRegistrarContact() async {
    final phone = _phoneController.text.trim();
    final email = _emailController.text.trim();
    if (phone == _lastSavedPhone && email == _lastSavedEmail) return;

    final repo = ref.read(sectionsRepositoryProvider);
    try {
      final section = ref.read(sectionProvider(widget.sectionId)).valueOrNull;
      if (section != null) {
        await repo.updateSection(
          section.copyWith(registrarPhone: phone, registrarEmail: email),
        );
        _lastSavedPhone = phone;
        _lastSavedEmail = email;
        if (mounted) ref.invalidate(sectionProvider(widget.sectionId));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to save registrar details')),
        );
      }
    }
  }

  void _scheduleCredentialsSave() {
    _credentialsSaveTimer?.cancel();
    _credentialsSaveTimer =
        Timer(const Duration(milliseconds: 500), _saveCredentials);
  }

  Future<void> _saveCredentials() async {
    final pin1 = _phonePin1Controller.text.trim();
    final pw1 = _computerPassword1Controller.text.trim();
    final pin2 = _phonePin2Controller.text.trim();
    final pw2 = _computerPassword2Controller.text.trim();
    final wifi = _wifiPasswordController.text.trim();
    if (pin1 == _lastSavedPhonePin1 &&
        pw1 == _lastSavedComputerPassword1 &&
        pin2 == _lastSavedPhonePin2 &&
        pw2 == _lastSavedComputerPassword2 &&
        wifi == _lastSavedWifiPassword) {
      return;
    }

    final repo = ref.read(sectionsRepositoryProvider);
    try {
      final section = ref.read(sectionProvider(widget.sectionId)).valueOrNull;
      if (section != null) {
        await repo.updateSection(
          section.copyWith(
            phonePin1: pin1,
            computerPassword1: pw1,
            phonePin2: pin2,
            computerPassword2: pw2,
            wifiPassword: wifi,
          ),
        );
        _lastSavedPhonePin1 = pin1;
        _lastSavedComputerPassword1 = pw1;
        _lastSavedPhonePin2 = pin2;
        _lastSavedComputerPassword2 = pw2;
        _lastSavedWifiPassword = wifi;
        if (mounted) ref.invalidate(sectionProvider(widget.sectionId));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to save credentials')),
        );
      }
    }
  }

  Attachment? _findMemoryAttachment(List<Attachment> attachments) {
    Attachment? latest;
    for (final a in attachments) {
      if (!a.fileName.toLowerCase().startsWith('memory_')) continue;
      if (latest == null || a.createdAt.isAfter(latest.createdAt)) {
        latest = a;
      }
    }
    return latest;
  }

  Future<void> _pickMemoryImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 80,
    );
    if (picked == null) return;

    setState(() => _uploading = true);
    final repo = ref.read(sectionsRepositoryProvider);

    try {
      // Remove any previously stored memory photo so we never keep stale
      // duplicates (the upload path is timestamped, so each upload creates a
      // new row + storage object).
      final existing =
          ref.read(attachmentsProvider(widget.sectionId)).valueOrNull ??
              <Attachment>[];
      for (final a in existing) {
        if (a.fileName.toLowerCase().startsWith('memory_')) {
          await repo.deleteAttachment(a);
        }
      }

      final bytes = await picked.readAsBytes();
      final mimeType = picked.mimeType ?? 'image/jpeg';
      await repo.uploadAttachment(
        sectionId: widget.sectionId,
        estateId: widget.estateId,
        fileName: 'memory_photo.jpg',
        type: AttachmentType.photo,
        bytes: bytes,
        mimeType: mimeType,
      );
      if (mounted) {
        // ignore: unused_result
        ref.refresh(attachmentsProvider(widget.sectionId));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Memory photo updated')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to upload image: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  void _viewFullscreen(Attachment? memoryAttachment) {
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _FullscreenPhotoViewer(
          memoryAttachment: memoryAttachment,
        ),
      ),
    );
  }

  Attachment? _findPetAttachment(List<Attachment> attachments) {
    Attachment? latest;
    for (final a in attachments) {
      if (!a.fileName.toLowerCase().startsWith('pet_')) continue;
      if (latest == null || a.createdAt.isAfter(latest.createdAt)) {
        latest = a;
      }
    }
    return latest;
  }

  Future<void> _pickPetImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 80,
    );
    if (picked == null) return;

    setState(() => _uploading = true);
    final repo = ref.read(sectionsRepositoryProvider);

    try {
      final existing =
          ref.read(attachmentsProvider(widget.sectionId)).valueOrNull ??
              <Attachment>[];
      for (final a in existing) {
        if (a.fileName.toLowerCase().startsWith('pet_')) {
          await repo.deleteAttachment(a);
        }
      }

      final bytes = await picked.readAsBytes();
      final mimeType = picked.mimeType ?? 'image/jpeg';
      await repo.uploadAttachment(
        sectionId: widget.sectionId,
        estateId: widget.estateId,
        fileName: 'pet_photo.jpg',
        type: AttachmentType.photo,
        bytes: bytes,
        mimeType: mimeType,
      );
      if (mounted) {
        // ignore: unused_result
        ref.refresh(attachmentsProvider(widget.sectionId));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pet photo updated')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to upload image: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Use valueOrNull so background re-fetches don't momentarily clear the
    // memory photo / certificates (which would cause a visible flicker).
    final asyncAttachments = ref.watch(attachmentsProvider(widget.sectionId));
    final attachments = asyncAttachments.valueOrNull ?? <Attachment>[];
    final memoryAttachment = _findMemoryAttachment(attachments);
    final petAttachment = _findPetAttachment(attachments);
    final certificateAttachments = _findCertificateAttachments(attachments);
    // Hold the Memory photo until the first fetch resolves: painting the
    // bundled default in the meantime shows two images in sequence.
    final memoryPending =
        asyncAttachments.isLoading && !asyncAttachments.hasValue;

    final asyncSection = ref.watch(sectionProvider(widget.sectionId));
    final asyncProcessRegion = ref.watch(estateProcessRegionProvider);
    final processRegion =
        asyncProcessRegion.valueOrNull ?? EstateProcessRegion.scotland;
    final isEwni = processRegion == EstateProcessRegion.ewni;

    final defaultCopiesUrl =
        isEwni ? _ewniCertifiedCopiesUrl : _scotlandCertifiedCopiesUrl;

    // Adopt whatever is stored the first time it arrives, and again whenever it
    // changes underneath us, without stomping on an in-flight edit. While the
    // field has focus the controller is the source of truth, so re-syncing here
    // would overwrite in-progress typing and jump the cursor.
    final storedPetNotes = asyncSection.valueOrNull?.petNotes ?? '';
    if (_lastAppliedStoredPetNotes != storedPetNotes &&
        !_petNotesFocusNode.hasFocus) {
      _petNotesController.text = storedPetNotes;
      _lastSavedPetNotes = storedPetNotes;
      _lastAppliedStoredPetNotes = storedPetNotes;
    }

    final storedPetInsuranceCompany =
        asyncSection.valueOrNull?.petInsuranceCompany ?? '';
    if (_lastAppliedStoredPetInsuranceCompany != storedPetInsuranceCompany &&
        !_petInsuranceCompanyFocusNode.hasFocus) {
      _petInsuranceCompanyController.text = storedPetInsuranceCompany;
      _lastSavedPetInsuranceCompany = storedPetInsuranceCompany;
      _lastAppliedStoredPetInsuranceCompany = storedPetInsuranceCompany;
    }

    final storedPetPolicyNumber =
        asyncSection.valueOrNull?.petPolicyNumber ?? '';
    if (_lastAppliedStoredPetPolicyNumber != storedPetPolicyNumber &&
        !_petPolicyNumberFocusNode.hasFocus) {
      _petPolicyNumberController.text = storedPetPolicyNumber;
      _lastSavedPetPolicyNumber = storedPetPolicyNumber;
      _lastAppliedStoredPetPolicyNumber = storedPetPolicyNumber;
    }

    final storedPetMicrochipNumber =
        asyncSection.valueOrNull?.petMicrochipNumber ?? '';
    if (_lastAppliedStoredPetMicrochipNumber != storedPetMicrochipNumber &&
        !_petMicrochipNumberFocusNode.hasFocus) {
      _petMicrochipNumberController.text = storedPetMicrochipNumber;
      _lastSavedPetMicrochipNumber = storedPetMicrochipNumber;
      _lastAppliedStoredPetMicrochipNumber = storedPetMicrochipNumber;
    }

    final storedVetName = asyncSection.valueOrNull?.vetName ?? '';
    if (_lastAppliedStoredVetName != storedVetName &&
        !_vetNameFocusNode.hasFocus) {
      _vetNameController.text = storedVetName;
      _lastSavedVetName = storedVetName;
      _lastAppliedStoredVetName = storedVetName;
    }

    final storedVetPhone = asyncSection.valueOrNull?.vetPhone ?? '';
    if (_lastAppliedStoredVetPhone != storedVetPhone &&
        !_vetPhoneFocusNode.hasFocus) {
      _vetPhoneController.text = storedVetPhone;
      _lastSavedVetPhone = storedVetPhone;
      _lastAppliedStoredVetPhone = storedVetPhone;
    }

    final storedVetUrl = asyncSection.valueOrNull?.vetUrl ?? '';
    if (_lastAppliedStoredVetUrl != storedVetUrl &&
        !_vetUrlFocusNode.hasFocus) {
      _vetUrlController.text = storedVetUrl;
      _lastSavedVetUrl = storedVetUrl;
      _lastAppliedStoredVetUrl = storedVetUrl;
    }

    asyncSection.maybeWhen(
      data: (section) {
        // Only initialize the controllers once from the stored section data.
        // After that, the text controllers are the source of truth while the
        // owner is typing — re-syncing here during a rebuild (e.g. after an
        // auto-save refreshes the section) would overwrite in-progress input
        // and jump the cursor.
        if (!_registrarInitialized) {
          _phoneController.text = section.registrarPhone;
          _emailController.text = section.registrarEmail;
          _lastSavedPhone = section.registrarPhone;
          _lastSavedEmail = section.registrarEmail;

          _phonePin1Controller.text = section.phonePin1;
          _computerPassword1Controller.text = section.computerPassword1;
          _phonePin2Controller.text = section.phonePin2;
          _computerPassword2Controller.text = section.computerPassword2;
          _wifiPasswordController.text = section.wifiPassword;
          _lastSavedPhonePin1 = section.phonePin1;
          _lastSavedComputerPassword1 = section.computerPassword1;
          _lastSavedPhonePin2 = section.phonePin2;
          _lastSavedComputerPassword2 = section.computerPassword2;
          _lastSavedWifiPassword = section.wifiPassword;

          _registrarInitialized = true;
        }
      },
      orElse: () {},
    );

    final storedCopiesUrl = asyncSection.valueOrNull?.certifiedCopiesUrl;
    if (storedCopiesUrl != null &&
        asyncProcessRegion.hasValue &&
        !_copiesUrlFocusNode.hasFocus) {
      if (_copiesUrlDirty &&
          storedCopiesUrl == _copiesUrlController.text.trim()) {
        _copiesUrlDirty = false;
      }
      if (!_copiesUrlDirty) {
        final displayedCopiesUrl =
            storedCopiesUrl.isNotEmpty ? storedCopiesUrl : defaultCopiesUrl;
        if (_copiesUrlController.text != displayedCopiesUrl) {
          _copiesUrlController.text = displayedCopiesUrl;
          _lastSavedCopiesUrl = storedCopiesUrl;
        }
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildMemorySection(memoryAttachment, memoryPending),
        const SizedBox(height: 28),
        _buildImmediateSection(),
        const SizedBox(height: 28),
        _buildPetsSection(petAttachment),
        const SizedBox(height: 28),
        _buildMedicalCertificateSection(),
        const SizedBox(height: 28),
        _buildDeathCertificateSection(certificateAttachments),
        const SizedBox(height: 28),
        _buildRegistrarOutcomeSection(isEwni: isEwni),
        const SizedBox(height: 28),
        _buildTellUsOnceSection(),
        const SizedBox(height: 28),
        _buildPhonesComputersSection(),
        const SizedBox(height: 28),
        SongForThePageSection(
          youtubeUrl: widget.youtubeUrl,
          sectionId: widget.sectionId,
          isOwner: widget.isOwner,
        ),
      ],
    );
  }

  // MARK: - Section helpers

  Widget _sectionHeader({
    required String title,
    required IconData icon,
    required Color tint,
  }) {
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: tint.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: tint, size: 20),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Color(0xFF2C2C2E),
            ),
          ),
        ),
      ],
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: child,
    );
  }

  // MARK: - Memory

  Widget _buildMemorySection(Attachment? memoryAttachment, bool pending) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(
          title: 'Memory',
          icon: Icons.photo_library,
          tint: Colors.blue,
        ),
        const SizedBox(height: 14),
        _card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: () => _viewFullscreen(memoryAttachment),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(11),
                    child: AspectRatio(
                      aspectRatio: 4 / 3,
                      child: pending
                          ? const MemoryPhotoPlaceholder()
                          : memoryAttachment != null &&
                                  memoryAttachment.downloadUrl.isNotEmpty
                              ? Image.network(
                                  memoryAttachment.downloadUrl,
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                  gaplessPlayback: true,
                                  // Hold the placeholder until the stored
                                  // photo has pixels: the default here would
                                  // show as a second image fading out.
                                  loadingBuilder:
                                      (context, child, loadingProgress) {
                                    if (loadingProgress == null) return child;
                                    return const MemoryPhotoPlaceholder();
                                  },
                                  errorBuilder: (_, __, ___) =>
                                      _defaultMemoryImage(),
                                )
                              : _defaultMemoryImage(),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(Icons.open_in_full,
                        size: 14, color: Colors.blue),
                    const SizedBox(width: 4),
                    Text(
                      pending
                          ? ''
                          : memoryAttachment != null
                              ? 'Tap to expand'
                              : 'Family photograph',
                      style:
                          TextStyle(fontSize: 12, color: Colors.blue.shade700),
                    ),
                  ],
                ),
                if (widget.isOwner) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _uploading ? null : _pickMemoryImage,
                      icon: _uploading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.edit),
                      label: Text(
                          _uploading ? 'Uploading...' : 'Replace memory photo'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _defaultMemoryImage() {
    return Image.asset(
      'assets/images/defaults/default_wtdf.jpeg',
      fit: BoxFit.cover,
      width: double.infinity,
      errorBuilder: (_, __, ___) => Container(color: Colors.grey.shade200),
    );
  }

  // MARK: - Immediate things you need to do

  Widget _buildImmediateSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(
          title: 'Immediate things you need to do',
          icon: Icons.flag,
          tint: Colors.red,
        ),
        const SizedBox(height: 12),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            "You don't need to do these all at once.  Take your time!  "
            "It's not like we are going anywhere!",
            style: TextStyle(fontSize: 15, color: Colors.grey),
          ),
        ),
      ],
    );
  }

  // MARK: - Pets

  Widget _buildPetsSection(Attachment? petAttachment) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(
          title: 'Pets',
          icon: Icons.pets,
          tint: const Color(0xFFE08A2C),
        ),
        const SizedBox(height: 14),
        _card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 150,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          GestureDetector(
                            onTap: widget.isOwner
                                ? (_uploading ? null : _pickPetImage)
                                : null,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(11),
                              child: SizedBox(
                                width: 150,
                                height: 150,
                                child: petAttachment != null &&
                                        petAttachment.downloadUrl.isNotEmpty
                                    ? Image.network(
                                        petAttachment.downloadUrl,
                                        fit: BoxFit.cover,
                                        width: double.infinity,
                                        height: double.infinity,
                                        gaplessPlayback: true,
                                        loadingBuilder:
                                            (context, child, loadingProgress) {
                                          if (loadingProgress == null) {
                                            return child;
                                          }
                                          return _defaultPetImage();
                                        },
                                        errorBuilder: (_, __, ___) =>
                                            _defaultPetImage(),
                                      )
                                    : _defaultPetImage(),
                              ),
                            ),
                          ),
                          if (widget.isOwner) ...[
                            const SizedBox(height: 12),
                            SizedBox(
                              width: 150,
                              child: ElevatedButton.icon(
                                onPressed: _uploading ? null : _pickPetImage,
                                icon: _uploading
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Icon(Icons.edit, size: 16),
                                label: Text(
                                  _uploading ? 'Uploading...' : 'Replace photo',
                                  style: const TextStyle(fontSize: 13),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFE08A2C),
                                  foregroundColor: Colors.white,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 10),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Notes',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF8E8E93),
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextField(
                            controller: _petNotesController,
                            focusNode: _petNotesFocusNode,
                            maxLines: 6,
                            minLines: 4,
                            enabled: widget.isOwner,
                            textCapitalization: TextCapitalization.sentences,
                            onChanged: (_) => _schedulePetSave(),
                            decoration: InputDecoration(
                              hintText: 'Notes about the pets...',
                              hintStyle: TextStyle(
                                  fontSize: 14, color: Colors.grey.shade400),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide:
                                    BorderSide(color: Colors.grey.shade300),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide:
                                    BorderSide(color: Colors.grey.shade300),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                    color: Color(0xFFE08A2C), width: 2),
                              ),
                              contentPadding: const EdgeInsets.all(12),
                            ),
                            style: const TextStyle(
                                fontSize: 14, color: Color(0xFF2C2C2E)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _petEditableField(
                  controller: _petInsuranceCompanyController,
                  focusNode: _petInsuranceCompanyFocusNode,
                  icon: Icons.shield_outlined,
                  tint: const Color(0xFFE08A2C),
                  label: 'Insurance company',
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 10),
                _petEditableField(
                  controller: _petPolicyNumberController,
                  focusNode: _petPolicyNumberFocusNode,
                  icon: Icons.numbers,
                  tint: const Color(0xFFE08A2C),
                  label: 'Policy number',
                ),
                const SizedBox(height: 10),
                _petEditableField(
                  controller: _petMicrochipNumberController,
                  focusNode: _petMicrochipNumberFocusNode,
                  icon: Icons.memory,
                  tint: const Color(0xFFE08A2C),
                  label: 'Microchip number',
                ),
                const SizedBox(height: 16),
                const Divider(height: 1),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Icon(Icons.local_hospital,
                        size: 18, color: Colors.teal.shade700),
                    const SizedBox(width: 8),
                    Text(
                      'Vet',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.teal.shade700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _petEditableField(
                  controller: _vetNameController,
                  focusNode: _vetNameFocusNode,
                  icon: Icons.store,
                  tint: Colors.teal,
                  label: 'Vet name',
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 10),
                _petEditableContactField(
                  controller: _vetPhoneController,
                  focusNode: _vetPhoneFocusNode,
                  icon: Icons.phone,
                  tint: Colors.green,
                  hint: 'Phone',
                  keyboardType: TextInputType.phone,
                  actionIcon: Icons.call,
                  onAction: () =>
                      _launch('tel:${_effectiveVetPhone.replaceAll(' ', '')}'),
                ),
                const SizedBox(height: 10),
                _petEditableContactField(
                  controller: _vetUrlController,
                  focusNode: _vetUrlFocusNode,
                  icon: Icons.public_rounded,
                  tint: Colors.blue,
                  hint: 'Website',
                  keyboardType: TextInputType.url,
                  actionIcon: Icons.open_in_new,
                  onAction: () => _launch(_effectiveVetUrl),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _defaultPetImage() {
    return Image.asset(
      'assets/images/defaults/default_cat.jpeg',
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      errorBuilder: (_, __, ___) =>
          Container(color: Colors.grey.shade200, child: const Icon(Icons.pets)),
    );
  }

  Widget _petEditableField({
    required TextEditingController controller,
    required IconData icon,
    required Color tint,
    required String label,
    TextCapitalization textCapitalization = TextCapitalization.none,
    FocusNode? focusNode,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: tint.withValues(alpha: 0.25)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: tint),
            const SizedBox(width: 8),
            SizedBox(
              width: 120,
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: tint.withValues(alpha: 0.9),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                enabled: widget.isOwner,
                textCapitalization: textCapitalization,
                onChanged: (_) => _schedulePetSave(),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  contentPadding:
                      EdgeInsets.symmetric(vertical: 6, horizontal: 0),
                  isDense: true,
                ),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2C2C2E),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _petEditableContactField({
    required TextEditingController controller,
    required IconData icon,
    required Color tint,
    required String hint,
    required TextInputType keyboardType,
    required IconData actionIcon,
    required VoidCallback onAction,
    FocusNode? focusNode,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: tint.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          const SizedBox(width: 12),
          Icon(icon, size: 18, color: tint),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              keyboardType: keyboardType,
              enabled: widget.isOwner,
              onChanged: (_) => _schedulePetSave(),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                border: InputBorder.none,
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 12, horizontal: 0),
                isDense: true,
              ),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: tint,
              ),
            ),
          ),
          IconButton(
            icon: Icon(actionIcon, size: 18, color: tint),
            onPressed: onAction,
          ),
        ],
      ),
    );
  }

  // MARK: - Medical certificate

  Widget _buildMedicalCertificateSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(
          title: 'Medical certificate',
          icon: Icons.medical_services,
          tint: Colors.red,
        ),
        const SizedBox(height: 14),
        _card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Contact the GP or hospital doctor to get the '
                  'Medical Certificate of Cause of Death (MCCD).',
                  style: TextStyle(fontSize: 15, color: Color(0xFF2C2C2E)),
                ),
                const SizedBox(height: 14),
                const Divider(height: 1),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Icon(Icons.location_on,
                        size: 18, color: Colors.red.shade700),
                    const SizedBox(width: 6),
                    Text(
                      'Local Process',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.red.shade700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'The doctor will email this certificate directly to '
                  'the local council Registrar. They will also pass your name '
                  'and phone number to the registration team so they know '
                  'who to contact.',
                  style: TextStyle(fontSize: 15, color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // MARK: - Death certificate

  Widget _buildDeathCertificateSection(List<Attachment> certificates) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(
          title: 'Death certificate',
          icon: Icons.description,
          tint: Colors.blue,
        ),
        const SizedBox(height: 14),
        _card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Once you know the MCCD has been sent over by the medical '
                  'team, contact the local Registrar to schedule your '
                  'formal phone appointment:',
                  style: TextStyle(fontSize: 15, color: Color(0xFF2C2C2E)),
                ),
                const SizedBox(height: 14),
                _buildRegistrarContactRow(),
                const SizedBox(height: 16),
                const Divider(height: 1),
                const SizedBox(height: 16),
                const Text(
                  'It helps to gather a few details about the person who '
                  'passed away before the registrar calls you.',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info, size: 16, color: Colors.blue.shade700),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Because the appointment is done over the phone, '
                        'you do not need the physical, original documents. '
                        'The registrar just needs you to read out the '
                        'information or confirm the details.',
                        style: TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        _buildCertificatesSubSection(certificates),
      ],
    );
  }

  // MARK: - Registrar contact (editable for owners)

  /// Builds the registrar contact row. Estate owners see editable phone/email
  /// fields (auto-saved); everyone else sees the tappable pill buttons.
  ///
  /// Nothing is pre-filled: each estate's registrar differs, so the owner
  /// enters their own details and empty values are simply not shown.
  Widget _buildRegistrarContactRow() {
    if (widget.isOwner) {
      return Column(
        children: [
          _buildEditableContactField(
            controller: _phoneController,
            icon: Icons.phone,
            tint: Colors.green,
            hint: 'Phone',
            keyboardType: TextInputType.phone,
            actionIcon: Icons.call,
            onAction: () =>
                _launch('tel:${_effectivePhone.replaceAll(' ', '')}'),
          ),
          const SizedBox(height: 10),
          _buildEditableContactField(
            controller: _emailController,
            icon: Icons.email,
            tint: Colors.blue,
            hint: 'Email',
            keyboardType: TextInputType.emailAddress,
            actionIcon: Icons.send,
            onAction: () => _launch('mailto:$_effectiveEmail'),
          ),
        ],
      );
    }

    return Row(
      children: [
        Expanded(
          child: _effectivePhone.isEmpty
              ? const SizedBox.shrink()
              : _pillButton(
                  icon: Icons.phone,
                  label: _effectivePhone,
                  tint: Colors.green,
                  onTap: () =>
                      _launch('tel:${_effectivePhone.replaceAll(' ', '')}'),
                ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _effectiveEmail.isEmpty
              ? const SizedBox.shrink()
              : _pillButton(
                  icon: Icons.email,
                  label: _effectiveEmail,
                  tint: Colors.blue,
                  onTap: () => _launch('mailto:$_effectiveEmail'),
                ),
        ),
      ],
    );
  }

  Widget _buildEditableContactField({
    required TextEditingController controller,
    required IconData icon,
    required Color tint,
    required String hint,
    required TextInputType keyboardType,
    required IconData actionIcon,
    required VoidCallback onAction,
    FocusNode? focusNode,
    ValueChanged<String>? onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: tint.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          const SizedBox(width: 12),
          Icon(icon, size: 18, color: tint),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              keyboardType: keyboardType,
              onChanged: onChanged ?? (_) => _scheduleRegistrarSave(),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                border: InputBorder.none,
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 12, horizontal: 0),
                isDense: true,
              ),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: tint,
              ),
            ),
          ),
          IconButton(
            icon: Icon(actionIcon, size: 18, color: tint),
            onPressed: onAction,
            tooltip: 'Use this contact',
          ),
        ],
      ),
    );
  }

  // MARK: - What the Registrar will Give You

  Widget _registrarBullet(String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 7),
            child: Icon(Icons.circle, size: 7, color: Colors.grey.shade800),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '$title: ',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  TextSpan(text: description),
                ],
              ),
              style: const TextStyle(
                fontSize: 15,
                color: Color(0xFF2C2C2E),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _registrarLabelText(String label, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '$label ',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            TextSpan(text: text),
          ],
        ),
        style: const TextStyle(
          fontSize: 14,
          color: Color(0xFF2C2C2E),
        ),
      ),
    );
  }

  Widget _buildRegistrarOutcomeSection({required bool isEwni}) {
    const intro = 'At the end of registration, the registrar will issue:';
    final savedCopiesUrl = _copiesUrlController.text.trim();
    final copiesUrl = savedCopiesUrl.isNotEmpty
        ? savedCopiesUrl
        : isEwni
            ? _ewniCertifiedCopiesUrl
            : _scotlandCertifiedCopiesUrl;
    final bulletPoints = isEwni
        ? <(String, String)>[
            (
              'The Green Form (Certificate for Burial or Cremation)',
              'Handed directly to your funeral director to allow the funeral to proceed.',
            ),
            (
              'Tell Us Once Reference Code',
              'A unique reference to report the death across government departments (DWP, DVLA, HMRC, etc.) at once.',
            ),
          ]
        : <(String, String)>[
            (
              'Form 14 (Certificate of Registration of Death)',
              'Sent to your funeral director to allow burial/cremation.',
            ),
            (
              'Abbreviated Death Certificate',
              'Issued free for basic records.',
            ),
            (
              'Tell Us Once Code',
              'A unique reference to report the death across government departments (DWP, DVLA, HMRC, etc.) at once.',
            ),
          ];
    final copiesHeading = isEwni
        ? 'Certified Copies of the Death Certificate'
        : 'Full Death Certificates (Extracts)';
    final copiesDescription = isEwni
        ? 'You will need official Full Death Certificates to settle the estate, close bank accounts, and deal with pensions/insurance.'
        : 'To manage accounts, pensions, and property, you will need Full Extract Copies.';
    final copiesCost = isEwni
        ? '£12.50 per copy at registration (via your local council\'s Register Office or GOV.UK).'
        : '£10.00 each at the time of registration (or £15.00 later via the link below).';
    final copiesRecommendation = isEwni
        ? 'Request several copies so you can notify multiple financial institutions at the same time. You can order more from the link below.'
        : 'Order several full copies so you can send them to multiple banks and insurers simultaneously.';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(
          title: 'What the Registrar Will Give You',
          icon: Icons.back_hand_rounded,
          tint: Colors.purple,
        ),
        const SizedBox(height: 14),
        _card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  intro,
                  style: TextStyle(
                    fontSize: 15,
                    color: Color(0xFF2C2C2E),
                  ),
                ),
                const SizedBox(height: 10),
                for (final point in bulletPoints)
                  _registrarBullet(point.$1, point.$2),
                const SizedBox(height: 14),
                const Divider(height: 1),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Icon(Icons.copy_all_rounded,
                        size: 18, color: Colors.purple.shade700),
                    const SizedBox(width: 8),
                    Text(
                      copiesHeading,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.purple.shade700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  copiesDescription,
                  style: const TextStyle(fontSize: 14, color: Colors.grey),
                ),
                const SizedBox(height: 8),
                _registrarLabelText('Cost:', copiesCost),
                _registrarLabelText('Recommendation:', copiesRecommendation),
                const SizedBox(height: 12),
                if (widget.isOwner)
                  _buildEditableContactField(
                    controller: _copiesUrlController,
                    focusNode: _copiesUrlFocusNode,
                    icon: Icons.public_rounded,
                    tint: Colors.blue,
                    hint: 'Order copies link',
                    keyboardType: TextInputType.url,
                    actionIcon: Icons.open_in_new_rounded,
                    onAction: () => _launch(copiesUrl),
                    onChanged: _onCopiesUrlChanged,
                  )
                else
                  _externalLinkRow(
                    url: copiesUrl,
                    tint: Colors.blue,
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // MARK: - Tell Us Once

  Widget _buildTellUsOnceSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(
          title: 'Tell Us Once',
          icon: Icons.campaign_rounded,
          tint: Colors.green,
        ),
        const SizedBox(height: 14),
        _card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'The registrar will provide a unique tracking code for the '
                  'free, official service. Entering this code online allows '
                  'you to report the bereavement to multiple government '
                  'systems simultaneously, automatically updating:',
                  style: TextStyle(fontSize: 15, color: Color(0xFF2C2C2E)),
                ),
                const SizedBox(height: 16),
                _buildBulletRow('HMRC (Taxes)', Colors.green),
                const SizedBox(height: 10),
                _buildBulletRow(
                    'DWP (State Pensions & Benefits)', Colors.green),
                const SizedBox(height: 10),
                _buildBulletRow('The Passport Office', Colors.green),
                const SizedBox(height: 10),
                _buildBulletRow('The DVLA (Driving Licences)', Colors.green),
                const SizedBox(height: 10),
                _buildBulletRow('Local Council Tax Teams', Colors.green),
                const SizedBox(height: 10),
                _buildBulletRow('Blue Badge (Parking Permits)', Colors.green),
                const SizedBox(height: 16),
                const Divider(height: 1),
                const SizedBox(height: 16),
                _externalLinkRow(
                  url:
                      'https://www.gov.uk/after-a-death/organisations-you-need-to-contact-and-tell-us-once',
                  tint: Colors.green,
                  title: 'Official GOV.UK Tell Us Once Service',
                  subtitle: 'www.gov.uk/after-a-death',
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // MARK: - Phones / Computers

  Widget _buildPhonesComputersSection() {
    const blue = Color(0xFF2E7BF5);
    const pink = Color(0xFFE84C88);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(
          title: 'Phones / Computers',
          icon: Icons.phone_android_rounded,
          tint: Colors.grey.shade700,
        ),
        const SizedBox(height: 14),
        _card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _credentialRow(
                  fieldKey: 'phone_pin_1',
                  icon: Icons.phone_android_rounded,
                  tint: blue,
                  controller: _phonePin1Controller,
                  hint: 'Phone PIN',
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 10),
                _credentialRow(
                  fieldKey: 'computer_password_1',
                  icon: Icons.keyboard_rounded,
                  tint: blue,
                  controller: _computerPassword1Controller,
                  hint: 'Computer password',
                  keyboardType: TextInputType.visiblePassword,
                ),
                const SizedBox(height: 10),
                _credentialRow(
                  fieldKey: 'phone_pin_2',
                  icon: Icons.phone_android_rounded,
                  tint: pink,
                  controller: _phonePin2Controller,
                  hint: 'Phone PIN',
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 10),
                _credentialRow(
                  fieldKey: 'computer_password_2',
                  icon: Icons.keyboard_rounded,
                  tint: pink,
                  controller: _computerPassword2Controller,
                  hint: 'Computer password',
                  keyboardType: TextInputType.visiblePassword,
                ),
                const SizedBox(height: 10),
                _credentialRow(
                  fieldKey: 'wifi_password',
                  icon: Icons.wifi_rounded,
                  tint: Colors.green,
                  controller: _wifiPasswordController,
                  hint: 'Wi-Fi password',
                  keyboardType: TextInputType.visiblePassword,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _credentialRow({
    required String fieldKey,
    required IconData icon,
    required Color tint,
    required TextEditingController controller,
    required String hint,
    required TextInputType keyboardType,
  }) {
    final value = controller.text.trim();
    final isRevealed = _revealedCredentialKeys.contains(fieldKey);
    if (!widget.isOwner) {
      // Read-only display for executors / viewers.
      return Container(
        decoration: BoxDecoration(
          color: tint.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: tint.withValues(alpha: 0.20)),
        ),
        child: Row(
          children: [
            const SizedBox(width: 12),
            Icon(icon, size: 20, color: tint),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                isRevealed ? value : _maskedCredentialValue(value),
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: tint,
                  fontFamily: 'monospace',
                ),
              ),
            ),
            IconButton(
              icon: Icon(
                isRevealed
                    ? Icons.visibility_off_rounded
                    : Icons.visibility_rounded,
                size: 20,
                color: tint,
              ),
              onPressed: value.isEmpty
                  ? null
                  : () => _toggleCredentialVisibility(fieldKey),
              tooltip: isRevealed ? 'Hide value' : 'Show value',
            ),
            const SizedBox(width: 12),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: tint.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          const SizedBox(width: 12),
          Icon(icon, size: 22, color: tint),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: keyboardType,
              obscureText: !isRevealed,
              onChanged: (_) => _scheduleCredentialsSave(),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: TextStyle(
                  fontSize: 15,
                  color: Colors.grey.shade400,
                  fontFamily: 'monospace',
                ),
                border: InputBorder.none,
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 14, horizontal: 0),
                isDense: true,
              ),
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: tint,
                fontFamily: 'monospace',
              ),
            ),
          ),
          IconButton(
            icon: Icon(
              isRevealed
                  ? Icons.visibility_off_rounded
                  : Icons.visibility_rounded,
              size: 20,
              color: tint,
            ),
            onPressed: () => _toggleCredentialVisibility(fieldKey),
            tooltip: isRevealed ? 'Hide value' : 'Show value',
          ),
          const SizedBox(width: 12),
        ],
      ),
    );
  }

  Widget _externalLinkRow({
    required String url,
    required Color tint,
    String? title,
    String? subtitle,
  }) {
    final trimmed = url.trim();
    final fallback = trimmed.replaceFirst(RegExp(r'^https?://'), '');
    return GestureDetector(
      onTap: () => _launch(trimmed),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: tint.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: tint.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            Icon(Icons.public_rounded, size: 24, color: tint),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title ?? fallback,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: tint,
                    ),
                  ),
                  if ((subtitle ?? (title != null ? fallback : ''))
                      .isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle ?? fallback,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            Icon(Icons.open_in_new_rounded, size: 22, color: tint),
          ],
        ),
      ),
    );
  }

  Widget _buildBulletRow(String text, Color color) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.check_circle, size: 18, color: color),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 15, color: Color(0xFF2C2C2E)),
          ),
        ),
      ],
    );
  }

  // MARK: - Certificates (sub-section)

  /// Returns attachments belonging to the certificates gallery, identified by
  /// the `cert_` filename prefix, ordered oldest-first so the gallery stays
  /// stable as new images are appended.
  List<Attachment> _findCertificateAttachments(List<Attachment> attachments) {
    final certs = attachments
        .where((a) => a.fileName.toLowerCase().startsWith('cert_'))
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return certs;
  }

  static const int _maxCertificates = 4;

  Future<void> _pickCertificateImages() async {
    final existing =
        ref.read(attachmentsProvider(widget.sectionId)).valueOrNull ??
            <Attachment>[];
    final currentCount = existing
        .where((a) => a.fileName.toLowerCase().startsWith('cert_'))
        .length;

    if (currentCount >= _maxCertificates) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You can upload up to 4 certificate images'),
        ),
      );
      return;
    }

    final picker = ImagePicker();
    final picked = await picker.pickMultiImage(
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 80,
    );
    if (picked.isEmpty) return;

    setState(() => _uploading = true);
    final repo = ref.read(sectionsRepositoryProvider);

    final availableSlots = _maxCertificates - currentCount;
    final toUpload = picked.take(availableSlots).toList();

    for (var i = 0; i < toUpload.length; i++) {
      final file = toUpload[i];
      try {
        final bytes = await file.readAsBytes();
        final mimeType = file.mimeType ?? 'image/jpeg';
        await repo.uploadAttachment(
          sectionId: widget.sectionId,
          estateId: widget.estateId,
          fileName: 'cert_${currentCount + i + 1}.jpg',
          type: AttachmentType.photo,
          bytes: bytes,
          mimeType: mimeType,
        );
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to upload ${file.name}')),
          );
        }
      }
    }

    if (mounted) {
      // ignore: unused_result
      ref.refresh(attachmentsProvider(widget.sectionId));
      setState(() => _uploading = false);
    }
  }

  Future<void> _deleteCertificate(Attachment attachment) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete certificate?'),
        content: const Text('This will permanently remove the image.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final repo = ref.read(sectionsRepositoryProvider);
      try {
        await repo.deleteAttachment(attachment);
        // ignore: unused_result
        ref.refresh(attachmentsProvider(widget.sectionId));
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to delete certificate')),
          );
        }
      }
    }
  }

  void _viewCertificateFullscreen(Attachment attachment) {
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _FullscreenCertificateViewer(attachment: attachment),
      ),
    );
  }

  Widget _buildCertificatesSubSection(List<Attachment> certificates) {
    return _card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.description,
                      color: Colors.orange, size: 16),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Certificates',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF2C2C2E),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${certificates.length}/$_maxCertificates',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.lightbulb, size: 14, color: Colors.orange.shade700),
                const SizedBox(width: 6),
                const Expanded(
                  child: Text(
                    'Tap any certificate image below to open the full '
                    'high-resolution scan.',
                    style: TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (certificates.isNotEmpty)
              _buildCertificateGrid(certificates)
            else
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  children: [
                    Icon(Icons.image_not_supported,
                        size: 36, color: Colors.grey.shade300),
                    const SizedBox(height: 8),
                    Text(
                      widget.isOwner
                          ? 'Upload up to $_maxCertificates certificate images.'
                          : 'No certificate images uploaded yet.',
                      textAlign: TextAlign.center,
                      style:
                          TextStyle(fontSize: 13, color: Colors.grey.shade500),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 12),
            if (widget.isOwner)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed:
                      _uploading || certificates.length >= _maxCertificates
                          ? null
                          : _pickCertificateImages,
                  icon: _uploading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.add_photo_alternate),
                  label: Text(
                    _uploading
                        ? 'Uploading...'
                        : certificates.length >= _maxCertificates
                            ? 'Maximum reached ($_maxCertificates)'
                            : 'Add certificate images',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Renders the uploaded certificate images in a 2-column grid matching the
  /// iOS FamilyPrep thumbnail dimensions (4:3 aspect ratio, 70px height).
  Widget _buildCertificateGrid(List<Attachment> certificates) {
    final rows = <Widget>[];
    for (var i = 0; i < certificates.length; i += 2) {
      final end = (i + 2 > certificates.length) ? certificates.length : i + 2;
      final rowItems = certificates.sublist(i, end);
      rows.add(
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _certificateThumbnail(rowItems[0])),
            if (rowItems.length > 1) ...[
              const SizedBox(width: 12),
              Expanded(child: _certificateThumbnail(rowItems[1])),
            ] else
              const Expanded(child: SizedBox.shrink()),
          ],
        ),
      );
      if (i + 2 < certificates.length) {
        rows.add(const SizedBox(height: 12));
      }
    }
    return Column(children: rows);
  }

  Widget _certificateThumbnail(Attachment attachment) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () => _viewCertificateFullscreen(attachment),
          child: Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  height: 70,
                  width: double.infinity,
                  child: Image.network(
                    attachment.downloadUrl,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    errorBuilder: (_, __, ___) => Container(
                      color: Colors.grey.shade200,
                      child: const Icon(Icons.broken_image,
                          color: Colors.grey, size: 24),
                    ),
                  ),
                ),
              ),
              if (widget.isOwner)
                Positioned(
                  top: 4,
                  left: 4,
                  child: GestureDetector(
                    onTap: () => _deleteCertificate(attachment),
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close,
                          color: Colors.white, size: 12),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Text(
          attachment.fileName.replaceFirst(RegExp(r'^cert_'), ''),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xFF2C2C2E),
          ),
        ),
        const SizedBox(height: 2),
        Row(
          children: [
            Icon(Icons.fullscreen, size: 10, color: Colors.orange.shade700),
            const SizedBox(width: 3),
            Text(
              'Tap to expand',
              style: TextStyle(fontSize: 10, color: Colors.orange.shade700),
            ),
          ],
        ),
      ],
    );
  }

  Widget _pillButton({
    required IconData icon,
    required String label,
    required Color tint,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: tint.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: tint.withValues(alpha: 0.25)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: tint),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: tint,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _toggleCredentialVisibility(String fieldKey) {
    setState(() {
      if (_revealedCredentialKeys.contains(fieldKey)) {
        _revealedCredentialKeys.remove(fieldKey);
      } else {
        _revealedCredentialKeys.add(fieldKey);
      }
    });
  }

  String _maskedCredentialValue(String value) {
    if (value.isEmpty) return '';
    return List.filled(value.length.clamp(8, 16), '•').join();
  }

  Future<void> _launch(String url) async {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return;
    final hasScheme = trimmed.startsWith('http://') ||
        trimmed.startsWith('https://') ||
        trimmed.startsWith('mailto:') ||
        trimmed.startsWith('tel:');
    final normalized = hasScheme ? trimmed : 'https://$trimmed';
    final uri = Uri.parse(normalized);
    if (await canLaunchUrl(uri)) {
      await launchUrl(
        uri,
        mode: uri.scheme == 'http' || uri.scheme == 'https'
            ? LaunchMode.externalApplication
            : LaunchMode.platformDefault,
      );
    }
  }
}

/// Fullscreen viewer for the memory photo (asset or uploaded).
class _FullscreenPhotoViewer extends StatelessWidget {
  final Attachment? memoryAttachment;

  const _FullscreenPhotoViewer({required this.memoryAttachment});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Family photograph',
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: Center(
        child: InteractiveViewer(
          child: memoryAttachment != null &&
                  memoryAttachment!.downloadUrl.isNotEmpty
              ? Image.network(
                  memoryAttachment!.downloadUrl,
                  fit: BoxFit.contain,
                  gaplessPlayback: true,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return const Center(
                      child: CircularProgressIndicator(color: Colors.white54),
                    );
                  },
                  errorBuilder: (_, __, ___) => Image.asset(
                    'assets/images/defaults/default_wtdf.jpeg',
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
                )
              : Image.asset(
                  'assets/images/defaults/default_wtdf.jpeg',
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
        ),
      ),
    );
  }
}

/// Fullscreen viewer for an uploaded certificate image.
class _FullscreenCertificateViewer extends StatelessWidget {
  final Attachment attachment;

  const _FullscreenCertificateViewer({required this.attachment});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          attachment.fileName.replaceFirst(RegExp(r'^cert_'), ''),
          style: const TextStyle(color: Colors.white),
        ),
      ),
      body: Center(
        child: InteractiveViewer(
          child: Image.network(
            attachment.downloadUrl,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const SizedBox.shrink(),
          ),
        ),
      ),
    );
  }
}
