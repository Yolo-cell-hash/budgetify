import 'package:budget_tracker/services/csv_reader.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CsvReader.parse', () {
    test('splits simple comma-separated rows', () {
      final rows = CsvReader.parse('a,b,c\n1,2,3');
      expect(rows, [
        ['a', 'b', 'c'],
        ['1', '2', '3'],
      ]);
    });

    test('honours quoted fields containing the delimiter', () {
      final rows = CsvReader.parse('"UPI-SWIGGY, BLR",100');
      expect(rows.single, ['UPI-SWIGGY, BLR', '100']);
    });

    test('unescapes doubled quotes inside quoted fields', () {
      final rows = CsvReader.parse('"He said ""hi""",2');
      expect(rows.single, ['He said "hi"', '2']);
    });

    test('keeps embedded newlines inside quoted fields', () {
      final rows = CsvReader.parse('"line one\nline two",5\nnext,6');
      expect(rows, [
        ['line one\nline two', '5'],
        ['next', '6'],
      ]);
    });

    test('handles CRLF line endings and drops empty lines', () {
      final rows = CsvReader.parse('a,b\r\n\r\n1,2\r\n');
      expect(rows, [
        ['a', 'b'],
        ['1', '2'],
      ]);
    });

    test('strips a UTF-8 BOM', () {
      final rows = CsvReader.parse('\u{FEFF}Date,Amount\n01/01/26,5');
      expect(rows.first, ['Date', 'Amount']);
    });

    test('sniffs semicolon and tab delimiters', () {
      expect(CsvReader.parse('a;b;c\n1;2;3').first, ['a', 'b', 'c']);
      expect(CsvReader.parse('a\tb\tc\n1\t2\t3').first, ['a', 'b', 'c']);
    });

    test('sniffing ignores delimiters inside quotes', () {
      // Commas only appear inside quotes; semicolons are the real delimiter.
      final rows = CsvReader.parse('"a,x";b\n"c,y";d');
      expect(rows.first, ['a,x', 'b']);
    });
  });

  group('CsvReader.parseLine', () {
    test('parses one line to fields (Axio shape)', () {
      expect(
        CsvReader.parseLine('"PLACE","5,000","DR"'),
        ['PLACE', '5,000', 'DR'],
      );
    });

    test('returns a single empty field for an empty line', () {
      expect(CsvReader.parseLine(''), ['']);
    });
  });
}
