"""Nix撤去時に失いやすい非対話シェルと端末設定を検証する。"""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


class EnvironmentTest(unittest.TestCase):
    def test_noninteractive_shell_without_nix_or_optional_tools(self):
        with tempfile.TemporaryDirectory() as directory:
            home = Path(directory)
            (home / '.zshenv.d').mkdir()
            for name in ('nix.zsh', 'runtime.zsh', 'tools.zsh'):
                (home / '.zshenv.d' / name).write_text(
                    (ROOT / 'dot_zshenv.d' / name).read_text())
            (home / '.zshenv').write_text((ROOT / 'dot_zshenv').read_text())
            (home / '.zshrc').write_text((ROOT / 'dot_zshrc').read_text())
            env = dict(os.environ, HOME=directory, ZDOTDIR=directory,
                       PATH=f'/nix/store/old/bin:{directory}/.nix-profile/bin:/usr/bin:/bin',
                       JAVA_HOME='/nix/store/old-jdk')
            result = subprocess.run(['zsh', '-c',
                '[[ "$PATH" != *nix* && -z "${JAVA_HOME:-}" ]]'],
                env=env, capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            # システムのzshrcが.zshenvの後でNixを追加する環境も検査する。
            result = subprocess.run(['zsh', '-c',
                'PATH="/nix/store/system/bin:$PATH"; source "$HOME/.zshrc"; '
                '[[ "$PATH" != *nix* ]]'],
                env=env, capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stderr)

    def test_java_and_terminfo_survive_without_home_manager(self):
        with tempfile.TemporaryDirectory() as directory:
            home = Path(directory)
            binaries = home / 'bin'
            binaries.mkdir()
            jdk = home / 'jdk'
            (jdk / 'bin').mkdir(parents=True)
            (jdk / 'bin/java').write_text('#!/bin/sh\nexit 0\n')
            (jdk / 'bin/java').chmod(0o755)
            (binaries / 'mise').write_text(
                '#!/bin/sh\n[ "$1 $2" = "where java" ] || exit 1\n'
                f'printf "%s\\n" "{jdk}"\n')
            (binaries / 'mise').chmod(0o755)
            (home / '.local/share/terminfo').mkdir(parents=True)
            env = dict(os.environ, HOME=directory, ZDOTDIR=directory,
                       PATH=f'{binaries}:/usr/bin:/bin',
                       TERMINFO_DIRS='/nix/store/old/share/terminfo:/custom/terminfo')
            result = subprocess.run(['zsh', '-f', '-c',
                'source "$1"; before=$TERMINFO_DIRS; source "$1"; [[ "$before" == "$TERMINFO_DIRS" &&  "$JAVA_HOME" == "$HOME/jdk" && '
                '"$TERMINFO_DIRS" == "$HOME/.local/share/terminfo:"* && '
                '"$TERMINFO_DIRS" == */custom/terminfo* && '
                '"$TERMINFO_DIRS" != */nix/* ]]',
                'zsh', str(ROOT / 'dot_zshenv.d/runtime.zsh')],
                env=env, capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stderr)


if __name__ == '__main__':
    unittest.main()
