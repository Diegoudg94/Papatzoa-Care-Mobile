import 'package:flutter/material.dart';

import '../../../../core/network/api_exceptions.dart';
import '../../../../core/routing/app_routes.dart';
import '../../../auth/data/repositories/auth_repository.dart';
import '../../data/models/diary_entry.dart';
import '../../data/repositories/patient_diary_repository.dart';
import 'diary_date_label.dart';

class PatientDiaryDetailPage extends StatefulWidget {
  const PatientDiaryDetailPage({
    super.key,
    required this.repository,
    required this.diaryRepository,
    required this.entryId,
  });
  final AuthRepository repository;
  final PatientDiaryRepository diaryRepository;
  final int entryId;

  @override
  State<PatientDiaryDetailPage> createState() => _PatientDiaryDetailPageState();
}

class _PatientDiaryDetailPageState extends State<PatientDiaryDetailPage> {
  DiaryEntry? _entry;
  bool _loading = true;
  String? _error;

  Future<void> _addFollowUp() async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _FollowUpSheet(
        diaryRepository: widget.diaryRepository,
        entryId: widget.entryId,
        onUnavailable: () {
          Navigator.of(context).pop();
          Navigator.of(context).pop(true);
        },
        onSessionExpired: () async {
          try {
            await widget.repository.invalidateSession();
          } catch (_) {}
          if (mounted) {
            Navigator.of(context)
                .pushNamedAndRemoveUntil(AppRoutes.login, (_) => false);
          }
        },
      ),
    );
    if (!mounted || saved != true) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Seguimiento guardado')));
    await _load();
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final entry = await widget.diaryRepository.getDiaryEntry(widget.entryId);
      if (mounted) setState(() => _entry = entry);
    } on ApiException catch (error) {
      if (error.statusCode == 401) {
        try {
          await widget.repository.invalidateSession();
        } catch (_) {}
        if (mounted) {
          Navigator.of(context)
              .pushNamedAndRemoveUntil(AppRoutes.login, (_) => false);
        }
        return;
      }
      if (mounted) {
        setState(
          () => _error = error.statusCode == 404
              ? 'Este registro ya no está disponible.'
              : 'No pudimos cargar este registro.',
        );
      }
    } on NetworkException {
      if (mounted) setState(() => _error = 'No pudimos cargar este registro.');
    } catch (_) {
      if (mounted) setState(() => _error = 'No pudimos cargar este registro.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final entry = _entry;
    return Scaffold(
      appBar: AppBar(title: const Text('Mi registro')),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_error!),
                    TextButton(
                      onPressed: _load,
                      child: const Text('Reintentar'),
                    ),
                  ],
                ),
              )
            : entry == null
            ? const SizedBox.shrink()
            : ListView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                children: [
                  Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            entry.emotion,
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (entry.intensity != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text('Intensidad ${entry.intensity}/10'),
                            ),
                          const SizedBox(height: 8),
                          Text(
                            diaryDateLabel(entry.recordedAt),
                            style: TextStyle(color: colors.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _DiarySection(
                    title: 'Qué estaba pasando',
                    value: entry.situation,
                  ),
                  _DiarySection(title: 'Qué pensé', value: entry.thought),
                  _DiarySection(title: 'Cómo reaccioné', value: entry.behavior),
                  _DiarySection(
                    title: 'Cómo lo interpreto',
                    value: entry.interpretation,
                  ),
                  _DiarySection(
                    title: 'Otra forma de verlo',
                    value: entry.restructuring,
                  ),
                  const SizedBox(height: 12),
                  Text('Seguimientos', style: theme.textTheme.titleLarge),
                  const SizedBox(height: 8),
                  if (entry.followUps.every(
                    (item) => item.note?.trim().isNotEmpty != true,
                  ))
                    Text(
                      'Aún no has añadido seguimientos.',
                      style: TextStyle(color: colors.onSurfaceVariant),
                    ),
                  if (entry.followUps.isNotEmpty) ...[
                    for (final item in entry.followUps)
                      if (item.note?.trim().isNotEmpty == true)
                        Card(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(18),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  diaryDateLabel(item.recordedAt),
                                  style: TextStyle(
                                    color: colors.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(item.note!),
                              ],
                            ),
                          ),
                        ),
                  ],
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _addFollowUp,
                    icon: const Icon(Icons.add),
                    label: const Text('Añadir seguimiento'),
                  ),
                ],
              ),
      ),
    );
  }
}

class _FollowUpSheet extends StatefulWidget {
  const _FollowUpSheet({
    required this.diaryRepository,
    required this.entryId,
    required this.onUnavailable,
    required this.onSessionExpired,
  });

  final PatientDiaryRepository diaryRepository;
  final int entryId;
  final VoidCallback onUnavailable;
  final Future<void> Function() onSessionExpired;

  @override
  State<_FollowUpSheet> createState() => _FollowUpSheetState();
}

class _FollowUpSheetState extends State<_FollowUpSheet> {
  final _controller = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    final note = _controller.text.trim();
    if (note.isEmpty || note.length > 2000) {
      setState(
        () => _error = 'Escribe un seguimiento de hasta 2000 caracteres.',
      );
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.diaryRepository.addFollowUp(
        entryId: widget.entryId,
        note: note,
      );
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (error) {
      if (error.statusCode == 401) {
        await widget.onSessionExpired();
      } else if (error.statusCode == 404) {
        widget.onUnavailable();
      } else if (mounted) {
        setState(
          () => _error = error.statusCode == 422
              ? 'Revisa el seguimiento e inténtalo de nuevo.'
              : 'No pudimos guardar el seguimiento. Intenta nuevamente.',
        );
      }
    } on NetworkException {
      if (mounted) {
        setState(
          () =>
              _error = 'No pudimos guardar el seguimiento. Intenta nuevamente.',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        8,
        24,
        MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Añadir seguimiento', style: theme.textTheme.titleLarge),
              const SizedBox(height: 8),
              const Text(
                'Puedes volver a este registro y escribir cómo ves la situación ahora.',
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _controller,
                maxLines: 5,
                minLines: 3,
                maxLength: 2000,
                onChanged: (_) => setState(() => _error = null),
                decoration: const InputDecoration(
                  labelText:
                      '¿Qué ha cambiado desde que hiciste este registro?',
                  border: OutlineInputBorder(),
                  counterText: '',
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: Text('${_controller.text.length} / 2000'),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    _error!,
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Guardar seguimiento'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DiarySection extends StatelessWidget {
  const _DiarySection({required this.title, required this.value});
  final String title;
  final String? value;

  @override
  Widget build(BuildContext context) {
    if (value?.trim().isNotEmpty != true) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(value!),
            ],
          ),
        ),
      ),
    );
  }
}
