import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/app_state.dart';
import '../../core/models.dart';
import '../../core/ui.dart';
import '../../core/trip_plan.dart';
import 'readiness_panel.dart';

class PreparationScreen extends ConsumerWidget {
  const PreparationScreen({super.key});
  Future<void> pickTime(BuildContext context, AppState s, bool turn) async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 30)),
    );
    if (date == null || !context.mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(
        now.add(Duration(hours: turn ? 3 : 6)),
      ),
    );
    if (time == null) return;
    final result = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    if (turn) {
      s.turnAt = result;
    } else {
      s.returnAt = result;
    }
    s.changed();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(appProvider), r = s.route;
    return Scaffold(
      appBar: AppBar(title: const Text('Перед выходом')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(22, 6, 22, 30),
            children: [
              const Tag('ПЛАН ПОХОДА'),
              const SizedBox(height: 16),
              Text(r.name, style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 12),
              Notice(
                r.demo
                    ? 'Демонстрационная линия. Не используйте её для реального похода.'
                    : 'Импортированный трек не проверен. Выбор маршрута требует самостоятельной проверки.',
                warning: true,
              ),
              ReadinessPanel(state: s),
              const SectionTitle('Маршрут на телефоне'),
              Panel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${(r.distance / 1000).toStringAsFixed(1)} км по геометрии · ${r.demo ? 'синтетический' : 'импортированный'} трек',
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Сложность, набор высоты и время: нет подтверждённых данных.',
                      style: TextStyle(color: muted, fontSize: 12),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Начало линии: ${r.points.first[1].toStringAsFixed(6)}, ${r.points.first[0].toStringAsFixed(6)}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    if (!r.demo)
                      TextButton.icon(
                        onPressed: () => openUrl(
                          context,
                          Uri.https('www.google.com', '/maps/search/', {
                            'api': '1',
                            'query':
                                '${r.points.first[1]},${r.points.first[0]}',
                          }),
                        ),
                        icon: const Icon(Icons.directions),
                        label: const Text('Навигатор до начала линии'),
                      ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: () {
                        s.saveRoute(r.id);
                        toast(
                          context,
                          'Карточка и геометрия сохранены локально',
                        );
                      },
                      icon: Icon(
                        s.saved.contains(r.id)
                            ? Icons.offline_pin
                            : Icons.download_outlined,
                      ),
                      label: Text(
                        s.saved.contains(r.id)
                            ? 'Маршрут сохранён'
                            : 'Сохранить для похода',
                      ),
                    ),
                  ],
                ),
              ),
              const SectionTitle('Когда возвращаемся?'),
              Panel(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    ListTile(
                      title: const Text('Время разворота'),
                      subtitle: Text(
                        s.turnAt == null
                            ? 'Не задано'
                            : s.turnAt!.toLocal().toString().substring(0, 16),
                      ),
                      trailing: const Icon(Icons.schedule),
                      onTap: () => pickTime(context, s, true),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      title: const Text('Ожидаемое возвращение'),
                      subtitle: Text(
                        s.returnAt == null
                            ? 'Не задано'
                            : s.returnAt!.toLocal().toString().substring(0, 16),
                      ),
                      trailing: const Icon(Icons.home_outlined),
                      onTap: () => pickTime(context, s, false),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Время устройства: ${DateTime.now().timeZoneName} (UTC${DateTime.now().timeZoneOffset.isNegative ? '' : '+'}${DateTime.now().timeZoneOffset.inHours}).',
                style: const TextStyle(color: muted, fontSize: 11),
              ),
              const SectionTitle('Всё необходимое с собой'),
              Text(
                '${s.checklist.length} из ${checklistItems.length} отмечено',
                style: const TextStyle(color: muted, fontSize: 12),
              ),
              const SizedBox(height: 8),
              Panel(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Column(
                  children: List.generate(
                    checklistItems.length,
                    (i) => CheckboxListTile(
                      value: s.checklist.contains(i),
                      onChanged: (v) => s.toggleCheck(i, v ?? false),
                      title: Text(
                        checklistItems[i],
                        style: const TextStyle(fontSize: 14),
                      ),
                      controlAffinity: ListTileControlAffinity.leading,
                      dense: true,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Ваши отметки помогают собраться, но не гарантируют готовность к условиям маршрута.',
                style: TextStyle(fontSize: 11, color: muted),
              ),
              const SectionTitle('Близкий человек'),
              TextFormField(
                initialValue: s.contact,
                keyboardType: TextInputType.phone,
                onChanged: (v) {
                  s.contact = v;
                  s.changed();
                },
                decoration: const InputDecoration(
                  labelText: 'Телефон контакта (необязательно)',
                  hintText: '+7 …',
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => attempt(context, () async {
                  final text = tripPlanMessage(
                    route: r,
                    profile: s.profile,
                    turnAt: s.turnAt,
                    returnAt: s.returnAt,
                    demo: s.demo || r.demo,
                  );
                  await SharePlus.instance.share(ShareParams(text: text));
                }),
                icon: const Icon(Icons.ios_share),
                label: const Text('Поделиться планом'),
              ),
              if (s.contact.trim().isNotEmpty) ...[
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: s.demo
                      ? null
                      : () => openUrl(
                          context,
                          Uri(
                            scheme: 'sms',
                            path: s.contact.replaceAll(RegExp(r'[^+0-9]'), ''),
                            query:
                                'body=${Uri.encodeComponent(tripPlanMessage(route: r, profile: s.profile, turnAt: s.turnAt, returnAt: s.returnAt, demo: false))}',
                          ),
                        ),
                  icon: const Icon(Icons.sms_outlined),
                  label: const Text('Открыть SMS с планом'),
                ),
              ],
              const SizedBox(height: 10),
              TextButton.icon(
                onPressed: () => context.push('/guide'),
                icon: const Icon(Icons.menu_book_outlined),
                label: const Text('Офлайн-памятка для похода'),
              ),
              const SizedBox(height: 18),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                value: s.demo,
                onChanged: s.session == null ? s.setDemo : null,
                title: const Text('Демонстрационный поход'),
                subtitle: const Text(
                  'Симуляция движения без GPS',
                  style: TextStyle(fontSize: 12),
                ),
              ),
              const SizedBox(height: 10),
              FilledButton.icon(
                onPressed: () => attempt(context, () async {
                  if (s.returnAt != null &&
                      s.turnAt != null &&
                      !s.returnAt!.isAfter(s.turnAt!)) {
                    throw StateError(
                      'Время возвращения должно быть позже времени разворота.',
                    );
                  }
                  if (s.session != null) {
                    context.go('/hike');
                    return;
                  }
                  if (!s.demo && s.readiness.level == 2) {
                    final proceed = await confirm(
                      context,
                      'Есть серьёзные риски',
                      '${s.readiness.reasons.join('\n')}\n\nПроверьте фактические условия на месте перед решением.',
                      action: 'Продолжить после проверки',
                    );
                    if (!proceed) return;
                  }
                  if (!context.mounted) return;
                  if (!s.demo) {
                    final ok = await confirm(
                      context,
                      'Начать запись GPS?',
                      'Трек импортирован и не проверен. Запись работает только при открытом приложении. При сворачивании она приостановится.',
                      action: 'Начать',
                    );
                    if (!ok) return;
                  }
                  await s.start();
                  if (context.mounted) context.go('/hike');
                }),
                icon: const Icon(Icons.hiking),
                label: Text(
                  s.session != null
                      ? 'Открыть текущий поход'
                      : s.demo
                      ? 'Начать демонстрацию'
                      : 'Начать поход',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
