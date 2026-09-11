"""Exercise make.bat control flow without touching real build outputs."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


@unittest.skipUnless(os.name == 'nt', 'Windows batch build')
class BuildTest(unittest.TestCase):
    def run_build(self, failure='', mode='', design=False):
        with tempfile.TemporaryDirectory(prefix='tetris build ') as folder:
            root = Path(folder)
            source = Path(__file__).resolve().parents[1]
            if design:
                source /= 'design'
            shutil.copyfile(source / 'make.bat', root / 'make.bat')
            (root / 'mads.cmd').write_text(
                '@echo off\n'
                'echo %~1>>"%TETRIS_BUILD_LOG%"\n'
                'if "%~1"=="%TETRIS_FAIL_TARGET%" exit /b 7\n'
                'exit /b 0\n', encoding='ascii')
            log = root / 'calls.txt'
            env = dict(os.environ, TETRIS_BUILD_LOG=str(log), TETRIS_FAIL_TARGET=failure)
            # cmd.exe needs its own quoting, not Python's CRT list quoting.
            result = subprocess.run(
                f'cmd.exe /d /s /c ""{root / "make.bat"}" {mode}"',
                env=env, capture_output=True, text=True)
            self.assertTrue(log.exists(), result.stdout + result.stderr)
            return result.returncode, log.read_text().splitlines()

    def test_stops_after_each_failure(self):
        for design, targets in [(False, ['tetris.asm']), (True, ['design.asm', 'design2.asm', 'design3.asm', 'design4.asm'])]:
            for index, target in enumerate(targets):
                with self.subTest(target=target):
                    code, calls = self.run_build(failure=target, design=design)
                    self.assertNotEqual(code, 0)
                    self.assertEqual(calls, targets[:index+1])

    def test_full_build(self):
        self.assertEqual(self.run_build(), (0, ['tetris.asm']))

    def test_design_build(self):
        self.assertEqual(self.run_build(design=True), (0, ['design.asm', 'design2.asm', 'design3.asm', 'design4.asm']))

    def test_game_only(self):
        self.assertEqual(self.run_build(mode='game'), (0, ['tetris.asm']))

    def test_game_only_failure(self):
        self.assertEqual(self.run_build(failure='tetris.asm', mode='game'), (1, ['tetris.asm']))


if __name__ == '__main__':
    unittest.main()
