# Происхождение данных

Проверено 27.09.2026. Дата просмотра источника не означает актуальность условий на местности. В приложении есть краткосрочный прогноз Open-Meteo, но нет онлайн-статуса закрытий, транспорта и прохода к объектам. Неподтверждённые длина, набор высоты, время и сложность не приписываются туристическим местам.

| Сведения | Источник | Как используются |
|---|---|---|
| Медеу и территория парка | [Парк «Медеу»](https://parkmedeu.kz/o-nas/obshchaya-informatsiya?id=30&view=category) | Краткое описание; координаты из [Wikipedia](https://en.wikipedia.org/wiki/Medeu), справочно |
| Шымбулак | [Сайт курорта](https://shymbulak.com/info/?contactTab=address) | Описание доступа; координаты из [Wikipedia](https://en.wikipedia.org/wiki/Shymbulak), справочно |
| Бутаковский водопад | [Парк «Медеу»](https://parkmedeu.kz/o-nas/obshchaya-informatsiya?id=30&view=category) | Краткое описание; метка обозначает **точку съёмки фотографии**, записанную в метаданных [Wikimedia Commons](https://commons.wikimedia.org/wiki/File:%D0%91%D2%B1%D1%82%D0%B0%D2%9B%D1%82%D1%8B_%D1%81%D0%B0%D1%80%D2%9B%D1%8B%D1%80%D0%B0%D0%BC%D0%B0%D1%81%D1%8B.jpg), а не старт маршрута |
| Кок-Жайляу | [Visit Almaty](https://visitalmaty.kz/activity/kok-zhajlyau/) | Краткое описание; координаты из [Wikipedia](https://en.wikipedia.org/wiki/Kok_Zhailau), справочно |
| Большое Алматинское озеро | [Visit Almaty](https://mountain.visitalmaty.kz/) | Краткое описание; координаты из [Wikipedia](https://en.wikipedia.org/wiki/Big_Almaty_Lake), справочно |
| DEM гор | [Terrain Tiles on AWS](https://registry.opendata.aws/terrain-tiles/), [Joerd attribution](https://github.com/tilezen/joerd/blob/master/docs/attribution.md) | Terrarium-тайлы уровня 12, выборка 241 × 241, рамка 76.90–77.16° E / 43.025–43.265° N. Локальный файл координат `assets/terrain/almaty.json`; видимый рельеф запечён в GLB |
| 3D-диорама | Создана для TauSafe в Blender 4.2 из DEM и локального снимка OSM | `assets/models/almaty_diorama.glb`: сглаженный рельеф, подставка, упрощённые кварталы Алматы, дороги, реки и декоративные группы деревьев. В приложении подставка скрыта, а край рельефа плавно растворяется в фоне; в редактируемом файле модель сохранена целиком. Для читаемости площадь городского макета показана в масштабе ×1,40, размеры зданий ×1,25, а их высота художественно увеличена. Модель не является точной копией зданий или инвентаризацией леса |
| Город, дороги, реки и канатные линии | [OpenStreetMap contributors](https://www.openstreetmap.org/copyright), [ODbL](https://opendatacommons.org/licenses/odbl/) | Локальный снимок `assets/data/context.json`; статическая геометрия запечена в GLB, линии канаток остаются интерактивными. Движение кабинок условное и не показывает текущий статус работы |
| Контур озера | [OpenStreetMap contributors](https://www.openstreetmap.org/relation/3427772), [ODbL](https://www.openstreetmap.org/copyright) | Геометрия воды в `assets/data/water.json`; прочитана через Overpass API, сохранена локально |
| Экстренный номер 112 | [МЧС Казахстана](https://www.gov.kz/memleket/entities/emer/press/news/details/438709?lang=ru) | Только открытие системного набора номера по действию пользователя |
| Демо-линия похода | Создана для TauSafe 26.09.2026 | Синтетический трек. Не содержит подтверждённой геометрии тропы; недоступен для реального режима |

Высоты в локальном DEM основаны главным образом на SRTM и других глобальных моделях проекта Terrain Tiles. **SRTM terrain data courtesy of the U.S. Geological Survey.** **GMTED2010 terrain data courtesy of the U.S. Geological Survey.** **Global ETOPO1 terrain data U.S. National Oceanic and Atmospheric Administration.** Mapzen / AWS Open Data. Эти данные не сертифицированы для безопасной пешей навигации.

Фотографии хранятся локально, уменьшены без изменения сюжета. У каждой карточки есть ссылка на оригинал и лицензию:

| Место | Автор | Условия | Оригинал |
|---|---|---|---|
| Медеу | Batyrbek.kz | [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/) | [Wikimedia Commons](https://commons.wikimedia.org/wiki/File:%D0%9C%D0%B5%D0%B4%D0%B5%D1%83,_%D0%90%D0%BB%D0%BC%D0%B0%D1%82%D1%8B,_2023_%D0%B6%D1%8B%D0%BB%D2%93%D1%8B_%D2%9B%D0%B0%D2%A3%D1%82%D0%B0%D1%80_(1).jpg) |
| Шымбулак | Girdi at English Wikipedia | Public domain | [Wikimedia Commons](https://commons.wikimedia.org/wiki/File:Shimbulak1.JPG) |
| Бутаковский водопад | Mukhamedzhan | [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/) | [Wikimedia Commons](https://commons.wikimedia.org/wiki/File:%D0%91%D2%B1%D1%82%D0%B0%D2%9B%D1%82%D1%8B_%D1%81%D0%B0%D1%80%D2%9B%D1%8B%D1%80%D0%B0%D0%BC%D0%B0%D1%81%D1%8B.jpg) |
| Кок-Жайляу | Dina Julayeva | [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/) | [Wikimedia Commons](https://commons.wikimedia.org/wiki/File:%D0%9A%D0%BE%D0%BA-%D0%B6%D0%B0%D0%B9%D0%BB%D1%8F%D1%83_2.jpg) |
| Большое Алматинское озеро | МаратД | [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/) | [Wikimedia Commons](https://commons.wikimedia.org/wiki/File:Big_Almaty_Lake_(2511_m)_and_snowy_peak_of_Soviets_(4317_m)_in_September,_2,_2017.jpg) |
| Медеу, вид сверху | User:Vmenkov | [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/) | [Wikimedia Commons](https://commons.wikimedia.org/wiki/File:Medeu-_4.jpg) |
| Гондола Медеу — Шымбулак | Matti Blume | [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/) | [Wikimedia Commons](https://commons.wikimedia.org/wiki/File:Medeu-Shymbulak_Cableway,_Almaty_(P1180177).jpg) |
| Бутаковский водопад, второй ракурс | Sane4o | [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/) | [Wikimedia Commons](https://commons.wikimedia.org/wiki/File:%D0%91%D1%83%D1%82%D0%B0%D0%BA%D0%BE%D0%B2%D1%81%D0%BA%D0%B8%D0%B9_%D0%B2%D0%BE%D0%B4%D0%BE%D0%BF%D0%B0%D0%B4_10.jpg) |
| Кок-Жайляу с хребта Кумбель | Soorette salike | [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/) | [Wikimedia Commons](https://commons.wikimedia.org/wiki/File:Kok_Jailaoo_view_from_Koom-bell_ridge_2.jpg) |
| Большое Алматинское озеро зимой | Amarkiev | [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/) | [Wikimedia Commons](https://commons.wikimedia.org/wiki/File:Big_Almaty_Lake_Winter.jpg) |

Шрифты Manrope и Noto Sans поставляются с лицензиями OFL в `assets/fonts/`. Текст лицензий и список библиотек доступны также из настроек приложения.
