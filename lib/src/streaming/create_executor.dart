// Native platforms generate on a worker isolate. The web has no isolates, so
// it generates on the main isolate within a per-frame budget.
export 'create_executor_web.dart'
    if (dart.library.io) 'create_executor_native.dart';
