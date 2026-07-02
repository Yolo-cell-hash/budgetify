/// Dependency-free delimited-text reading shared by the import services.
///
/// Bank statement exports are messier than spec CSV: semicolon- or
/// tab-delimited files, quoted narrations containing commas *and* newlines,
/// Excel-style escaped quotes (""), and a UTF-8 BOM from some netbanking
/// portals. This reader handles all of that in a single pass.
class CsvReader {
  CsvReader._();

  /// Parse delimited [content] into rows of fields.
  ///
  /// RFC-4180 quoting is honoured: a quoted field may contain the delimiter,
  /// escaped quotes ("") and embedded newlines. Rows that are entirely empty
  /// are dropped. When [delimiter] is null it is sniffed from the content.
  static List<List<String>> parse(String content, {String? delimiter}) {
    if (content.startsWith('\u{FEFF}')) content = content.substring(1);
    final d = delimiter ?? sniffDelimiter(content);

    final rows = <List<String>>[];
    var fields = <String>[];
    final buffer = StringBuffer();
    var inQuotes = false;

    void endField() {
      fields.add(buffer.toString());
      buffer.clear();
    }

    void endRow() {
      endField();
      final isEmpty =
          fields.length == 1 && fields.first.trim().isEmpty;
      if (!isEmpty) rows.add(fields);
      fields = <String>[];
    }

    for (var i = 0; i < content.length; i++) {
      final char = content[i];
      if (inQuotes) {
        if (char == '"') {
          if (i + 1 < content.length && content[i + 1] == '"') {
            buffer.write('"');
            i++; // consume the escaped quote
          } else {
            inQuotes = false;
          }
        } else {
          buffer.write(char);
        }
      } else if (char == '"') {
        inQuotes = true;
      } else if (char == d) {
        endField();
      } else if (char == '\r') {
        if (i + 1 < content.length && content[i + 1] == '\n') i++;
        endRow();
      } else if (char == '\n') {
        endRow();
      } else {
        buffer.write(char);
      }
    }
    if (buffer.isNotEmpty || fields.isNotEmpty) endRow();
    return rows;
  }

  /// Parse a single line (no embedded newlines) with comma delimiting —
  /// the shape Axio exports use.
  static List<String> parseLine(String line, {String delimiter = ','}) {
    final rows = parse(line, delimiter: delimiter);
    return rows.isEmpty ? <String>[''] : rows.first;
  }

  /// Guess the delimiter by counting candidates outside quoted regions in the
  /// first ~20 lines. Falls back to comma.
  static String sniffDelimiter(String content) {
    const candidates = [',', ';', '\t'];
    final counts = {for (final c in candidates) c: 0};
    var inQuotes = false;
    var lines = 0;
    for (var i = 0; i < content.length && lines < 20; i++) {
      final char = content[i];
      if (char == '"') {
        inQuotes = !inQuotes;
      } else if (!inQuotes) {
        if (char == '\n') {
          lines++;
        } else if (counts.containsKey(char)) {
          counts[char] = counts[char]! + 1;
        }
      }
    }
    String best = ',';
    var bestCount = 0;
    for (final c in candidates) {
      if (counts[c]! > bestCount) {
        best = c;
        bestCount = counts[c]!;
      }
    }
    return best;
  }
}
