# Post Explorer (SRS 8)

Flutter-приложение для просмотра, поиска и создания постов. API: [JSONPlaceholder](https://jsonplaceholder.typicode.com).

## Запуск
```bash
flutter pub get
dart run build_runner build      # генерация *.g.dart (Retrofit, json_serializable)
flutter run                      # iPhone 17 simulator / Android
flutter test                     # 10 тестов, без интернета
```

## Архитектура
`Screen → Controller (Provider/ChangeNotifier) → Repository → Retrofit API → Dio → сервер`, рядом локальный кэш (SharedPreferences).

```
lib/
  core/network   dio_client.dart (единый Dio, таймауты, LogInterceptor),
                 api_interceptor.dart (заголовки + централизованная обработка ошибок)
  core/error     app_exception.dart (нет сети, таймаут, 4xx, 5xx, JSON, unknown)
  data/models    Post, Comment, User (json_serializable, nullable, вложенные модели)
  data/remote    post_api.dart (Retrofit)
  data/local     post_cache.dart
  data/repositories  post_repository.dart
  presentation   screens / widgets / state
```

| Слой | Зачем |
|---|---|
| Dio | единый HTTP-клиент: таймауты, логи, заголовки, ошибки |
| Retrofit | описание запросов аннотациями, генерация кода |
| json_serializable | JSON ⇄ модели без ручного парсинга |
| Repository | UI не знает про Dio; ловит ошибки, работает с кэшем |
| Controller | состояния Loading/Success/Error/Cached/Empty, пагинация, фильтры |

## API-запросы (Retrofit)
GET `/posts` (пагинация `_page`/`_limit`), GET `/posts/{id}`, GET `/posts?userId={id}`,
GET `/posts/{id}/comments`, POST `/posts`, + GET `/users`, `/users/{id}`.

## Поведение
- **Первый запуск:** загрузка с сервера, результат кэшируется.
- **Повторное открытие:** сначала кэш (плашка «сохранённые данные»), параллельно запрос.
- **Нет интернета:** кэш не удаляется, показывается ошибка и кэшированные данные.
- **Пагинация:** по 10 постов, защита от повторной загрузки страницы, кнопка «Повторить».
- **Поиск** по заголовку — только среди загруженных постов (указано в UI).
- **Смена фильтра** сбрасывает страницы; устаревшие запросы отменяются (`CancelToken`).
- **POST:** JSONPlaceholder не сохраняет данные, поэтому созданный пост добавляется локально с пометкой «создан локально».
