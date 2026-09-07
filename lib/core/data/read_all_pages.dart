/// Continues until an empty page, even when a server caps replies below the
/// requested page size. Callers must use a stable, unique ordering.
Future<List<T>> readAllPages<T>(
    Future<List<T>> Function(int from, int to) fetchPage,
    {int pageSize = 500}) async {
  final result = <T>[];
  while (true) {
    final page = await fetchPage(result.length, result.length + pageSize - 1);
    if (page.isEmpty) return result;
    result.addAll(page);
  }
}
