// Copyright (c) 2018, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:analysis_server/src/computer/computer_folding.dart';
import 'package:analysis_server/src/protocol_server.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:test/test.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

import '../../abstract_context.dart';

main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(FoldingComputerTest);
  });
}

@reflectiveTest
class FoldingComputerTest extends AbstractContextTest {
  String sourcePath;

  setUp() {
    super.setUp();
    sourcePath = convertPath('/home/test/lib/test.dart');
  }

  test_annotations() async {
    String content = """
@myMultilineAnnotation/*1:INC*/(
  "this",
  "is a test"
)/*1:EXC:ANNOTATIONS*/
main() {}

@noFoldNecessary
main2() {}

@multipleAnnotations1/*2:INC*/(
  "this",
  "is a test"
)
@multipleAnnotations2()
@multipleAnnotations3/*2:EXC:ANNOTATIONS*/
main3() {}

@noFoldsForSingleClassAnnotation
class MyClass {}

@folded.classAnnotation1/*3:INC*/()
@foldedClassAnnotation2/*3:EXC:ANNOTATIONS*/
class MyClass2 {/*4:INC*/
  @fieldAnnotation1/*5:INC*/
  @fieldAnnotation2/*5:EXC:ANNOTATIONS*/
  int myField;

  @getterAnnotation1/*6:INC*/
  @getterAnnotation2/*6:EXC:ANNOTATIONS*/
  int get myThing => 1;

  @setterAnnotation1/*7:INC*/
  @setterAnnotation2/*7:EXC:ANNOTATIONS*/
  void set myThing(int value) {}
  
  @methodAnnotation1/*8:INC*/
  @methodAnnotation2/*8:EXC:ANNOTATIONS*/
  void myMethod() {}

  @constructorAnnotation1/*9:INC*/
  @constructorAnnotation1/*9:EXC:ANNOTATIONS*/
  MyClass2() {}
/*4:INC:CLASS_BODY*/}
""";

    final regions = await _computeRegions(content);
    _compareRegions(regions, content);
  }

  test_assertInitializer() async {
    String content = '''
class C {/*1:INC*/
  C() : assert(/*2:INC*/
    true,
    ''
  /*2:INC:INVOCATION*/);
/*1:INC:CLASS_BODY*/}
''';
    final regions = await _computeRegions(content);
    _compareRegions(regions, content);
  }

  test_assertStatement() async {
    String content = '''
main() {/*1:INC*/
  assert(/*2:INC*/
    true,
    ''
  /*2:INC:INVOCATION*/);
/*1:INC:FUNCTION_BODY*/}
''';
    final regions = await _computeRegions(content);
    _compareRegions(regions, content);
  }

  test_class() async {
    String content = """
// Content before

class Person {/*1:INC*/
  Person() {/*2:INC*/
    print("Hello, world!");
  /*2:INC:FUNCTION_BODY*/}

  void sayHello() {/*3:INC*/
    print("Hello, world!");
  /*3:INC:FUNCTION_BODY*/}
/*1:INC:CLASS_BODY*/}

// Content after
""";

    final regions = await _computeRegions(content);
    _compareRegions(regions, content);
  }

  test_comment_is_not_considered_file_header() async {
    String content = """
// This is not the file header
// It's just a comment
main() {}
""";

    // Since there are no region comment markers above
    // just check the length instead of the contents
    final regions = await _computeRegions(content);
    expect(regions, hasLength(0));
  }

  test_constructor_invocations() async {
    String content = """
// Content before

main() {/*1:INC*/
  return new Text(/*2:INC*/
    "Hello, world!",
  /*2:INC:INVOCATION*/);
/*1:INC:FUNCTION_BODY*/}

// Content after
""";

    final regions = await _computeRegions(content);
    _compareRegions(regions, content);
  }

  test_file_header() async {
    String content = """
// Copyright some year by some people/*1:EXC*/
// See LICENCE etc./*1:INC:FILE_HEADER*/

// This is not the file header
// It's just a comment
main() {}
""";

    final regions = await _computeRegions(content);
    _compareRegions(regions, content);
  }

  test_file_header_does_not_include_block_comments() async {
    String content = """
/*
 * Copyright some year by some people
 * See LICENCE etc.
 */
/* This shouldn't be part of the file header */

main() {}
""";

    final regions = await _computeRegions(content);
    expect(regions, hasLength(0));
  }

  test_file_header_with_no_function_comment() async {
    String content = """
// Copyright some year by some people/*1:EXC*/
// See LICENCE etc./*1:INC:FILE_HEADER*/

main() {}
""";

    final regions = await _computeRegions(content);
    _compareRegions(regions, content);
  }

  test_file_header_with_non_end_of_line_comment() async {
    String content = """
// Copyright some year by some people/*1:EXC*/
// See LICENCE etc./*1:INC:FILE_HEADER*/
/* This shouldn't be part of the file header */

main() {}
""";

    final regions = await _computeRegions(content);
    _compareRegions(regions, content);
  }

  test_file_header_with_script_prefix() async {
    String content = """
#! /usr/bin/dart
// Copyright some year by some people/*1:EXC*/
// See LICENCE etc./*1:INC:FILE_HEADER*/

// This is not the file header
// It's just a comment
main() {}
""";

    final regions = await _computeRegions(content);
    _compareRegions(regions, content);
  }

  test_function() async {
    String content = """
// Content before

main() {/*1:INC*/
  print("Hello, world!");
/*1:INC:FUNCTION_BODY*/}

// Content after
""";

    final regions = await _computeRegions(content);
    _compareRegions(regions, content);
  }

  test_function_expression_invocation() async {
    String content = """
// Content before

getFunc() => (String a, String b) {/*1:INC*/
  print(a);
/*1:INC:FUNCTION_BODY*/};

main2() {/*2:INC*/
  getFunc()(/*3:INC*/
    "one",
    "two"
  /*3:INC:INVOCATION*/);
/*2:INC:FUNCTION_BODY*/}

// Content after
""";

    final regions = await _computeRegions(content);
    _compareRegions(regions, content);
  }

  test_function_with_dart_doc() async {
    String content = """
// Content before

/*1:EXC*//// This is a doc comment
/// that spans lines/*1:INC:DOCUMENTATION_COMMENT*/
main() {/*2:INC*/
  print("Hello, world!");
/*2:INC:FUNCTION_BODY*/}

// Content after
""";

    final regions = await _computeRegions(content);
    _compareRegions(regions, content);
  }

  test_invocations() async {
    String content = """
// Content before

main() {/*1:INC*/
  print(/*2:INC*/
    "Hello, world!",
  /*2:INC:INVOCATION*/);
/*1:INC:FUNCTION_BODY*/}

// Content after
""";

    final regions = await _computeRegions(content);
    _compareRegions(regions, content);
  }

  test_literal_list() async {
    String content = """
// Content before

main() {/*1:INC*/
  final List<String> things = <String>[/*2:INC*/
    "one",
    "two"
  /*2:INC:LITERAL*/];
/*1:INC:FUNCTION_BODY*/}

// Content after
""";

    final regions = await _computeRegions(content);
    _compareRegions(regions, content);
  }

  test_literal_map() async {
    String content = """
// Content before

main2() {/*1:INC*/
  final Map<String, String> things = <String, String>{/*2:INC*/
    "one": "one",
    "two": "two"
    /*2:INC:LITERAL*/};
/*1:INC:FUNCTION_BODY*/}

// Content after
""";

    final regions = await _computeRegions(content);
    _compareRegions(regions, content);
  }

  test_mixin() async {
    String content = """
// Content before

mixin M {/*1:INC*/
  void m() {/*3:INC*/
    print("Got to m");
  /*3:INC:FUNCTION_BODY*/}
/*1:INC:CLASS_BODY*/}

// Content after
""";

    final regions = await _computeRegions(content);
    _compareRegions(regions, content);
  }

  test_multiple_directive_types() async {
    String content = """
import/*1:INC*/ 'dart:async';

// We can have comments
import 'package:a/b.dart';
import 'package:b/c.dart';

export '../a.dart';/*1:EXC:DIRECTIVES*/

main() {}
""";

    final regions = await _computeRegions(content);
    _compareRegions(regions, content);
  }

  test_multiple_import_directives() async {
    String content = """
import/*1:INC*/ 'dart:async';

// We can have comments
import 'package:a/b.dart';
import 'package:b/c.dart';

import '../a.dart';/*1:EXC:DIRECTIVES*/

main() {}
""";

    final regions = await _computeRegions(content);
    _compareRegions(regions, content);
  }

  test_nested_function() async {
    String content = """
// Content before

main() {/*1:INC*/
  doPrint() {/*2:INC*/
    print("Hello, world!");
  /*2:INC:FUNCTION_BODY*/}
  doPrint();
/*1:INC:FUNCTION_BODY*/}

// Content after
""";

    final regions = await _computeRegions(content);
    _compareRegions(regions, content);
  }

  test_nested_invocations() async {
    String content = """
// Content before

main() {/*1:INC*/
  a(/*2:INC*/
    b(/*3:INC*/
      c(/*4:INC*/
        d()
      /*4:INC:INVOCATION*/),
    /*3:INC:INVOCATION*/),
  /*2:INC:INVOCATION*/);
/*1:INC:FUNCTION_BODY*/}

// Content after
""";

    final regions = await _computeRegions(content);
    _compareRegions(regions, content);
  }

  test_single_import_directives() async {
    String content = """
import 'dart:async';

main() {}
""";

    // Since there are no region comment markers above
    // just check the length instead of the contents
    final regions = await _computeRegions(content);
    expect(regions, hasLength(0));
  }

  /// Compares provided folding regions with expected
  /// regions extracted from the comments in the provided content.
  void _compareRegions(List<FoldingRegion> regions, String content) {
    // Find all numeric markers for region starts.
    final regex = new RegExp(r'/\*(\d+):(INC|EXC)\*/');
    final expectedRegions = regex.allMatches(content);

    // Check we didn't get more than expected, since the loop below only
    // checks for the presence of matches, not absence.
    expect(regions, hasLength(expectedRegions.length));

    // Go through each marker, find the expected region start/end and
    // ensure it's in the results.
    expectedRegions.forEach((m) {
      final i = m.group(1);
      final inclusiveStart = m.group(2) == "INC";
      // Find the end marker.
      final endMatch =
          new RegExp('/\\*$i:(INC|EXC):(.+?)\\*/').firstMatch(content);

      final inclusiveEnd = endMatch.group(1) == "INC";
      final expectedKindString = endMatch.group(2);
      final expectedKind = FoldingKind.VALUES.firstWhere(
          (f) => f.toString() == 'FoldingKind.$expectedKindString',
          orElse: () => throw new Exception(
              "Annotated test code references $expectedKindString but "
              "this does not exist in FoldingKind"));

      final expectedStart = inclusiveStart ? m.start : m.end;
      final expectedLength =
          (inclusiveEnd ? endMatch.end : endMatch.start) - expectedStart;

      expect(
          regions,
          contains(
              new FoldingRegion(expectedKind, expectedStart, expectedLength)));
    });
  }

  Future<List<FoldingRegion>> _computeRegions(String sourceContent) async {
    newFile(sourcePath, content: sourceContent);
    ResolvedUnitResult result = await session.getResolvedUnit(sourcePath);
    DartUnitFoldingComputer computer =
        new DartUnitFoldingComputer(result.lineInfo, result.unit);
    return computer.compute();
  }
}
