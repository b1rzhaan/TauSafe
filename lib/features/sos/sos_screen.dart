import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/app_state.dart';
import '../../core/ui.dart';
import '../../core/safety.dart';

class SosScreen extends ConsumerStatefulWidget {
  const SosScreen({super.key});
  @override
  ConsumerState<SosScreen> createState() => _SosScreenState();
}

class _SosScreenState extends ConsumerState<SosScreen> {
  String description = '';
  @override
  Widget build(BuildContext context) {
    final s = ref.watch(appProvider);
    final p = s.position;
    final message = sosMessage(
      route: s.session == null ? 'активный поход не задан' : s.route.name,
      point: p,
      now: DateTime.now(),
      description: description,
      demo: s.demo,
    );
    void preview() => showDialog<void>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('ДЕМО · предпросмотр'),
        content: SingleChildScrollView(child: SelectableText(message)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('Закрыть'),
          ),
        ],
      ),
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Помощь · SOS')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(22, 8, 22, 30),
            children: [
              if (s.demo)
                const Notice(
                  'ДЕМО: звонки и отправка отключены. Координаты смоделированы.',
                  icon: Icons.science_outlined,
                  warning: true,
                ),
              const SizedBox(height: 18),
              Text(
                'Сообщи,\nгде ты находишься.',
                style: Theme.of(context).textTheme.headlineLarge,
              ),
              const SizedBox(height: 18),
              Panel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'КООРДИНАТЫ',
                      style: TextStyle(
                        color: muted,
                        fontSize: 11,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SelectableText(
                      p?.coordinates ?? 'Не определены',
                      style: const TextStyle(
                        fontSize: 25,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      p == null
                          ? 'Нет достоверной позиции'
                          : 'Точность: ±${p.accuracy.round()} м\nВремя: ${p.time.toLocal().toIso8601String()}',
                      style: const TextStyle(color: muted, fontSize: 12),
                    ),
                    if (s.stale) ...[
                      const SizedBox(height: 10),
                      const Notice(
                        'Координаты отсутствуют или устарели. Сообщите об этом при обращении за помощью.',
                        warning: true,
                      ),
                    ],
                    if (!s.demo)
                      TextButton.icon(
                        onPressed: () => attempt(context, s.locate),
                        icon: const Icon(Icons.my_location),
                        label: const Text('Обновить GPS'),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                maxLines: 3,
                onChanged: (v) => setState(() => description = v),
                decoration: const InputDecoration(
                  labelText: 'Что произошло?',
                  hintText: 'Состояние, ориентиры, сколько человек рядом',
                ),
              ),
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: () {
                  if (p == null) {
                    toast(context, 'Координаты пока не определены');
                    return;
                  }
                  Clipboard.setData(
                    ClipboardData(
                      text:
                          '${s.demo ? 'ДЕМО: ' : ''}${p.coordinates} · ${p.time.toLocal()} · ±${p.accuracy.round()} м${s.stale ? ' · УСТАРЕЛИ' : ''}',
                    ),
                  );
                  toast(context, 'Координаты с временем скопированы');
                },
                icon: const Icon(Icons.copy),
                label: const Text('Скопировать координаты'),
              ),
              const SizedBox(height: 10),
              FilledButton.icon(
                onPressed: s.demo
                    ? preview
                    : () => attempt(context, () async {
                        await SharePlus.instance.share(
                          ShareParams(text: message),
                        );
                      }),
                icon: const Icon(Icons.share_outlined),
                label: Text(
                  s.demo ? 'Предпросмотр сообщения' : 'Поделиться сообщением',
                ),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: s.demo
                    ? preview
                    : () => openUrl(
                        context,
                        Uri(
                          scheme: 'sms',
                          path: s.contact.replaceAll(RegExp(r'[^+0-9]'), ''),
                          query: 'body=${Uri.encodeComponent(message)}',
                        ),
                      ),
                icon: const Icon(Icons.sms_outlined),
                label: const Text('Открыть SMS'),
              ),
              const SizedBox(height: 10),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xffa93434),
                ),
                onPressed: s.demo
                    ? preview
                    : () => openUrl(context, Uri(scheme: 'tel', path: '112')),
                icon: const Icon(Icons.phone_outlined),
                label: const Text('Открыть набор 112'),
              ),
              const SizedBox(height: 15),
              const Text(
                'Открытие редактора не означает отправку или доставку. Приложение не уведомляет спасателей автоматически.',
                style: TextStyle(color: muted, fontSize: 12),
              ),
              const SizedBox(height: 14),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: const Text(
                  'Подготовленный текст',
                  style: TextStyle(fontSize: 14),
                ),
                children: [
                  SelectableText(message),
                  TextButton(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: message));
                      toast(context, 'Текст скопирован');
                    },
                    child: const Text('Скопировать текст'),
                  ),
                ],
              ),
              TextButton(
                onPressed: () => openUrl(
                  context,
                  Uri.parse(
                    'https://www.gov.kz/memleket/entities/emer/press/news/details/438709?lang=ru',
                  ),
                ),
                child: const Text('112 в Казахстане · источник МЧС'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
