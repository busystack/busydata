import sys
import os
import unittest
from unittest.mock import patch
import verify_pipeline


class PipelineRestrictionTest(unittest.TestCase):
    def test_default_and_ordinary_mysql_are_distinct_required_native_workflows(self):
        executed, required = {}, []
        def command(name, arguments, reports, artifacts):
            executed[name] = (arguments, artifacts)
            return 0
        def finish(stages):
            required.extend(stages)
            return {'acceptancePassed': True}
        with patch.object(sys, 'argv', ['verify_pipeline.py', '--scope', 'linux']), \
             patch.object(verify_pipeline, 'start', return_value='fixture-run'), \
             patch.object(verify_pipeline.sys, 'platform', 'linux'), \
             patch.object(verify_pipeline, 'run', side_effect=command), \
             patch.object(verify_pipeline, 'finish_with_archive', side_effect=finish), \
             patch.object(verify_pipeline.shutil, 'which', return_value='/usr/bin/fixture-tool'):
            self.assertEqual(0, verify_pipeline.main())
        default, ordinary = 'native-workflow-mysql', 'native-workflow-mysql-ordinary'
        self.assertIn(default, required)
        self.assertIn(ordinary, required)
        self.assertEqual(['/usr/bin/python3', 'tool/verify_native_accessibility.py', '--engine', 'MYSQL'], executed[default][0])
        self.assertEqual(executed[default][0] + ['--ordinary-mysql'], executed[ordinary][0])
        self.assertEqual(('build/native-accessibility-mysql.json',), executed[default][1])
        self.assertEqual(('build/native-accessibility-mysql-ordinary.json',), executed[ordinary][1])

    def test_official_pub_cache_is_owned_and_restores_the_callers_environment(self):
        with patch.dict(os.environ, {'PUB_CACHE': 'caller-owned', 'TMPDIR': 'caller-temp'}, clear=False):
            with verify_pipeline.official_pub_cache():
                self.assertEqual(str(verify_pipeline.ROOT / 'build/official-dependencies/pub-cache'), os.environ['PUB_CACHE'])
                self.assertEqual(str(verify_pipeline.ROOT / 'build/t'), os.environ['TMPDIR'])
            self.assertEqual('caller-owned', os.environ['PUB_CACHE'])
            self.assertEqual('caller-temp', os.environ['TMPDIR'])
        with patch.dict(os.environ, {}, clear=True):
            with self.assertRaisesRegex(RuntimeError, 'source rejected'):
                with verify_pipeline.official_pub_cache():
                    raise RuntimeError('source rejected')
            self.assertNotIn('PUB_CACHE', os.environ)
            self.assertNotIn('TMPDIR', os.environ)

    def test_gallery_capture_is_scoped_and_preserves_the_callers_environment(self):
        variable = 'BUSYDATA_SCREEN_GALLERY_OUTPUT'
        with patch.dict(os.environ, {variable: 'caller-owned'}, clear=False):
            with verify_pipeline.gallery_capture('/tmp/run-owned-gallery'):
                self.assertEqual('/tmp/run-owned-gallery', os.environ[variable])
            self.assertEqual('caller-owned', os.environ[variable])
        with patch.dict(os.environ, {}, clear=True):
            with self.assertRaisesRegex(RuntimeError, 'capture failed'):
                with verify_pipeline.gallery_capture('/tmp/failed-run-gallery'):
                    raise RuntimeError('capture failed')
            self.assertNotIn(variable, os.environ)

    def test_explicit_restriction_never_invokes_installed_snap_or_removes_required_stage(self):
        executed = []
        unavailable = {}
        required = []
        gallery = {}

        def command(stage, *args, **kwargs):
            executed.append(stage)
            if stage == 'flutter-tests':
                gallery['output'] = os.environ.get('BUSYDATA_SCREEN_GALLERY_OUTPUT')
                gallery['artifacts'] = args[2] if len(args) > 2 else ()
            return 0

        def finish(stages):
            required.extend(stages)
            return {'acceptancePassed': not any(stage in unavailable for stage in stages)}

        # Even an installed package cannot override the operator's restriction.
        # All other stages are mocked orchestration, never product connectivity.
        with patch.object(sys, 'argv', ['verify_pipeline.py', '--scope', 'desktop-full',
                                      '--unavailable-installed-snap', 'User requested no Snap operations']), \
             patch.object(verify_pipeline, 'start', return_value='fixture-run'), \
             patch.object(verify_pipeline.sys, 'platform', 'linux'), \
             patch.object(verify_pipeline, 'run', side_effect=command), \
             patch.object(verify_pipeline, 'unavailable', side_effect=lambda name, reason: unavailable.update({name: reason})), \
             patch.object(verify_pipeline, 'finish_with_archive', side_effect=finish), \
             patch.object(verify_pipeline.shutil, 'which', return_value='/usr/bin/fixture-tool'), \
             patch.object(verify_pipeline.Path, 'exists', return_value=True):
            self.assertEqual(1, verify_pipeline.main())
        self.assertNotIn('installed-snap', executed)
        self.assertIn('installed-snap', required)
        self.assertEqual('User requested no Snap operations', unavailable['installed-snap'])
        self.assertIn('database-matrix', executed)
        self.assertIn('release-performance', executed)
        self.assertIn('linux-release', executed)
        self.assertNotIn('linux-distribution', executed)
        self.assertNotIn('linux-distribution', required)
        expected = verify_pipeline.ROOT / 'build/verification/runs/fixture-run/screen-gallery'
        self.assertEqual(str(expected), gallery['output'])
        self.assertEqual(tuple((expected / theme / 'captions.json').relative_to(verify_pipeline.ROOT).as_posix()
                               for theme in ('dark', 'light')), gallery['artifacts'])

    def test_official_source_verification_precedes_and_gates_editor_and_packaging(self):
        executed, unavailable = [], []
        def command(name, *args, **kwargs):
            executed.append(name)
            return 1 if name == 'official-dependencies' else 0
        with patch.object(sys, 'argv', ['verify_pipeline.py', '--scope', 'linux']), \
             patch.object(verify_pipeline, 'start', return_value='fixture-run'), \
             patch.object(verify_pipeline.sys, 'platform', 'linux'), \
             patch.object(verify_pipeline, 'run', side_effect=command), \
             patch.object(verify_pipeline, 'unavailable', side_effect=lambda name, reason: unavailable.append(name)), \
             patch.object(verify_pipeline, 'finish_with_archive', return_value={'acceptancePassed': False}), \
             patch.object(verify_pipeline.shutil, 'which', return_value='/usr/bin/fixture-tool'):
            self.assertEqual(1, verify_pipeline.main())
        self.assertLess(executed.index('flutter-dependencies'), executed.index('official-dependencies'))
        for name in ('localizations', 'protocol', 'format', 'analyze', 'boundaries',
                     'flutter-tests', 'native-accessibility-component',
                     'inventory', 'lifecycle', 'linux-release'):
            self.assertIn(name, unavailable)
            self.assertNotIn(name, executed)


if __name__ == '__main__':
    unittest.main()
