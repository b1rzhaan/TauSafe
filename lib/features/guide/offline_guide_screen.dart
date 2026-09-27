import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/ui.dart';

class OfflineGuideScreen extends StatelessWidget {
  const OfflineGuideScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Офлайн-памятка')),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 32),
          children: [
            const Notice(
              'Карточки сохранены в приложении и открываются без сети. '
              'При угрозе жизни звоните 112; передайте координаты и состояние группы.',
              warning: true,
            ),
            const SizedBox(height: 16),
            _guide(
              'Потеряли маршрут',
              Icons.explore_off_outlined,
              [
                'Остановитесь и оцените обстановку. Не продолжайте идти наугад.',
                'Проверьте последнее известное место, маршрут и заряд телефона.',
                'Если безопасный путь обратно неясен, сообщите координаты 112 и оставайтесь в месте, где вас легче найти.',
              ],
              'МЧС Казахстана · gov.kz; National Park Service · nps.gov',
            ),
            _guide(
              'Гроза',
              Icons.thunderstorm_outlined,
              [
                'При звуке грома прекратите подъём и уходите с гребня к капитальному зданию или закрытому автомобилю.',
                'Не прячьтесь под одиночным деревом или в палатке. Избегайте воды, проводов и открытых мест.',
                'Если безопасного укрытия рядом нет, спускайтесь ниже и уменьшайте время на открытом склоне.',
              ],
              'National Weather Service · weather.gov',
            ),
            _guide('Переохлаждение', Icons.ac_unit_outlined, [
              'Озноб, спутанность, сонливость и невнятная речь — признаки опасности.',
              'Уведите человека в укрытие, снимите мокрую одежду и согревайте под сухими слоями, прежде всего туловище.',
              'При спутанности сознания или сильном ухудшении вызовите 112. Не давайте напитки человеку без сознания.',
            ], 'CDC · cdc.gov'),
            _guide(
              'Травма или сильное кровотечение',
              Icons.healing_outlined,
              [
                'Оцените безопасность места и вызовите 112 при серьёзной травме.',
                'При сильном наружном кровотечении прижмите рану чистой тканью и держите постоянное давление.',
                'При подозрении на перелом не заставляйте пострадавшего идти; сохраняйте тепло и сообщите спасателям координаты.',
              ],
              'American Red Cross · redcross.org',
            ),
            _guide(
              'Ливень и селевой риск',
              Icons.water_damage_outlined,
              [
                'Не заходите в русла и узкие ущелья после сильного дождя.',
                'При предупреждении о селе отложите поход. Если слышен приближающийся поток, уходите со дна ущелья вверх по склону.',
                'Проверяйте официальные предупреждения МЧС, когда связь доступна.',
              ],
              'МЧС Казахстана · gov.kz',
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => context.push('/sos'),
              icon: const Icon(Icons.sos),
              label: const Text('Координаты и SOS'),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _guide(
    String title,
    IconData icon,
    List<String> steps,
    String source,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: 9),
    child: Panel(
      padding: EdgeInsets.zero,
      child: ExpansionTile(
        leading: Icon(icon, color: forest),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        childrenPadding: const EdgeInsets.fromLTRB(18, 2, 18, 16),
        children: [
          ...steps.asMap().entries.map(
            (entry) => Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('${entry.key + 1}. ${entry.value}'),
              ),
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Источник: $source',
              style: const TextStyle(fontSize: 11, color: muted),
            ),
          ),
        ],
      ),
    ),
  );
}
