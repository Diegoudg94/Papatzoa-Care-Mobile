import 'package:flutter/material.dart';

import '../../../../core/network/api_exceptions.dart';
import '../../../../core/routing/app_routes.dart';
import '../../../auth/data/repositories/auth_repository.dart';
import '../../data/models/diary_entry.dart';
import '../../data/repositories/patient_diary_repository.dart';
import '../widgets/patient_bottom_navigation.dart';
import 'diary_date_label.dart';
import 'patient_diary_detail_page.dart';
import 'patient_diary_new_page.dart';

class PatientDiaryPage extends StatefulWidget {
  const PatientDiaryPage({
    super.key,
    required this.repository,
    required this.diaryRepository,
  });
  final AuthRepository repository;
  final PatientDiaryRepository diaryRepository;

  @override
  State<PatientDiaryPage> createState() => _PatientDiaryPageState();
}

class _PatientDiaryPageState extends State<PatientDiaryPage> {
  List<DiaryEntry> _entries = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _sessionExpired() async {
    try {
      await widget.repository.invalidateSession();
    } catch (_) {}
    if (mounted) {
      Navigator.of(context)
          .pushNamedAndRemoveUntil(AppRoutes.login, (_) => false);
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final entries = await widget.diaryRepository.getDiaryEntries();
      if (mounted) setState(() => _entries = entries);
    } on ApiException catch (error) {
      if (error.statusCode == 401) {
        await _sessionExpired();
        return;
      }
      if (mounted) setState(() => _error = 'No pudimos cargar tu diario.');
    } on NetworkException {
      if (mounted) setState(() => _error = 'No pudimos cargar tu diario.');
    } catch (_) {
      if (mounted) setState(() => _error = 'No pudimos cargar tu diario.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _create() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => PatientDiaryNewPage(
          repository: widget.repository,
          diaryRepository: widget.diaryRepository,
        ),
      ),
    );
    if (!mounted) return;
    if (created == true) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Registro guardado')));
      await _load();
    }
  }

  Future<void> _open(DiaryEntry entry) async {
    final unavailable = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => PatientDiaryDetailPage(
          repository: widget.repository,
          diaryRepository: widget.diaryRepository,
          entryId: entry.id,
        ),
      ),
    );
    if (!mounted || unavailable != true) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Este registro ya no está disponible.')),
    );
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Scaffold(
      extendBody: true,
      appBar: AppBar(title: const Text('Diario emocional')),
      bottomNavigationBar: PatientBottomNavigation(
        currentRoute: AppRoutes.patientDiary,
        user: widget.repository.currentUser,
      ),
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 132),
            children: [
              Text(
                'Diario emocional',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Un espacio para registrar lo que estás sintiendo.',
                style: TextStyle(color: colors.onSurfaceVariant),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _create,
                icon: const Icon(Icons.edit_note),
                label: const Text('Nuevo registro'),
              ),
              const SizedBox(height: 20),
              if (_loading) const LinearProgressIndicator(minHeight: 2),
              if (_error != null)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Text(_error!),
                        TextButton(
                          onPressed: _load,
                          child: const Text('Reintentar'),
                        ),
                      ],
                    ),
                  ),
                ),
              if (!_loading && _error == null && _entries.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        Icon(
                          Icons.menu_book_outlined,
                          color: colors.primary,
                          size: 34,
                        ),
                        const SizedBox(height: 12),
                        const Text('Aún no tienes registros.'),
                        const SizedBox(height: 6),
                        const Text(
                          'Puedes empezar escribiendo cómo te sientes hoy.',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        OutlinedButton(
                          onPressed: _create,
                          child: const Text('Crear registro'),
                        ),
                      ],
                    ),
                  ),
                ),
              if (!_loading && _error == null)
                for (final entry in _entries)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Card(
                      margin: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(22),
                        onTap: () => _open(entry),
                        child: Padding(
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.spa_outlined,
                                    color: colors.primary,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      entry.emotion,
                                      style: theme.textTheme.titleMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                  ),
                                  const Icon(Icons.chevron_right),
                                ],
                              ),
                              if (entry.intensity != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Text(
                                    'Intensidad ${entry.intensity}/10',
                                  ),
                                ),
                              const SizedBox(height: 6),
                              Text(
                                diaryDateLabel(entry.recordedAt),
                                style: TextStyle(
                                  color: colors.onSurfaceVariant,
                                ),
                              ),
                              if (entry.preview?.trim().isNotEmpty == true)
                                Padding(
                                  padding: const EdgeInsets.only(top: 10),
                                  child: Text(
                                    entry.preview!,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}
