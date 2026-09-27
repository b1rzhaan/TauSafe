// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get appName => 'TauSafe';

  @override
  String get explore => 'Места';

  @override
  String get map => 'Карта';

  @override
  String get hike => 'Поход';

  @override
  String get saved => 'Сохранённое';

  @override
  String get exploreTitle => 'Открой горы Алматы';

  @override
  String get searchHint => 'Место, которое хочется увидеть';

  @override
  String get demo => 'ДЕМО — координаты смоделированы';

  @override
  String get sos => 'Помощь · SOS';

  @override
  String get prepare => 'Подготовиться';

  @override
  String get view3d => 'Посмотреть в 3D';

  @override
  String get favorites => 'Избранное';

  @override
  String get offline => 'Доступно без интернета';
}
