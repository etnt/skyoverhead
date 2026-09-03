import 'package:auto_upgrade/auto_upgrade.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skyoverhead/src/data/update_service.dart';
import 'package:skyoverhead/src/ui/update_prompt.dart';

/// A [ReleaseChecker] that never touches the network: it resolves [check]
/// with a canned [result] and counts calls.
class _FakeChecker extends ReleaseChecker {
  final UpdateCheckResult result;
  int calls = 0;

  _FakeChecker(this.result)
      : super(owner: 'etnt', repo: 'skyoverhead', currentVersion: '1.0.0');

  @override
  Future<UpdateCheckResult> check() async {
    calls++;
    return result;
  }
}

/// Pumps a minimal app that runs the update check after its first frame,
/// mirroring the HomeScreen hook, and records "Update now" launches.
class _Harness extends StatelessWidget {
  final List<UpdateInfo> launched;

  const _Harness(this.launched);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: _TriggerPage(launched: launched),
    );
  }
}

/// The page that triggers the check from *inside* the MaterialApp, matching
/// where the real HomeScreen calls it from — including reading the checker
/// from [releaseCheckerProvider] rather than taking it directly.
class _TriggerPage extends ConsumerStatefulWidget {
  final List<UpdateInfo> launched;

  const _TriggerPage({required this.launched});

  @override
  ConsumerState<_TriggerPage> createState() => _TriggerPageState();
}

class _TriggerPageState extends ConsumerState<_TriggerPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      maybeShowUpdateDialog(
        context,
        checker: ref.read(releaseCheckerProvider),
        onUpdate: (info) async => widget.launched.add(info),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: SizedBox());
  }
}

/// Pumps the harness with [checker] injected through the same provider the
/// real HomeScreen reads, and returns the list that records "Update now"
/// launches so tests can assert on the strategy.
Future<List<UpdateInfo>> _pumpHarness(
  WidgetTester tester,
  _FakeChecker checker,
) async {
  final launched = <UpdateInfo>[];
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        releaseCheckerProvider.overrideWithValue(checker),
      ],
      child: _Harness(launched),
    ),
  );
  await tester.pumpAndSettle();
  return launched;
}

UpdateInfo get _updateInfo => const UpdateInfo(
      latestVersion: '1.2.0',
      currentVersion: '1.0.0',
      releasePageUrl: 'https://github.com/etnt/skyoverhead/releases/tag/v1.2.0',
      releaseNotes: 'Faster scans.',
    );

void main() {
  testWidgets('UpdateAvailable shows the dialog with versions and notes',
      (tester) async {
    await _pumpHarness(tester, _FakeChecker(UpdateAvailable(_updateInfo)));

    expect(find.text('Update available'), findsOneWidget);
    expect(find.textContaining('1.2.0 is available'), findsOneWidget);
    expect(find.textContaining('you have 1.0.0'), findsOneWidget);
    expect(find.textContaining('Faster scans.'), findsOneWidget);
  });

  testWidgets('"Update now" invokes the strategy with the right UpdateInfo',
      (tester) async {
    final launched =
        await _pumpHarness(tester, _FakeChecker(UpdateAvailable(_updateInfo)));

    await tester.tap(find.text('Update now'));
    await tester.pumpAndSettle();

    expect(launched, hasLength(1));
    expect(launched.single.latestVersion, '1.2.0');
    expect(
      launched.single.releasePageUrl,
      'https://github.com/etnt/skyoverhead/releases/tag/v1.2.0',
    );
    // The dialog is gone.
    expect(find.text('Update available'), findsNothing);
  });

  testWidgets('"Later" pops without launching anything', (tester) async {
    final launched =
        await _pumpHarness(tester, _FakeChecker(UpdateAvailable(_updateInfo)));

    await tester.tap(find.text('Later'));
    await tester.pumpAndSettle();

    expect(launched, isEmpty);
    expect(find.text('Update available'), findsNothing);
  });

  for (final entry in {
    'UpToDate': const UpToDate(),
    'CheckSkipped': const CheckSkipped(),
    'CheckError': CheckError(Exception('offline')),
  }.entries) {
    testWidgets('${entry.key} shows nothing', (tester) async {
      await _pumpHarness(tester, _FakeChecker(entry.value));

      expect(find.text('Update available'), findsNothing);
      expect(find.text('Later'), findsNothing);
      expect(find.text('Update now'), findsNothing);
    });
  }
}
