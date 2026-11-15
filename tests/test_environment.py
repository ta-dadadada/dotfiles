"""Nix撤去時に失いやすい非対話シェルと端末設定を検証する。"""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]


def shell_environment(home, path, **overrides):
    # CIのmise/XDG設定や親シェルのJavaをfixtureへ持ち込まない。
    return dict(HOME=str(home), ZDOTDIR=str(home), PATH=path, **overrides)


class EnvironmentTest(unittest.TestCase):
    def test_nix_jdk_and_certificate_paths_are_cleared_selectively(self):
        variables = ('JAVA_HOME', 'SSL_CERT_FILE', 'SSL_CERT_DIR', 'CURL_CA_BUNDLE',
                     'GIT_SSL_CAINFO', 'REQUESTS_CA_BUNDLE', 'PIP_CERT',
                     'NODE_EXTRA_CA_CERTS', 'AWS_CA_BUNDLE', 'CARGO_HTTP_CAINFO',
                     'GRPC_DEFAULT_SSL_ROOTS_FILE_PATH')
        with tempfile.TemporaryDirectory() as directory:
            home = Path(directory)
            for prefix in ('/nix/store/old', f'{home}/.nix-profile',
                           f'{home}/.local/state/nix/profiles/profile'):
                for value, expected in ((f'{prefix}/cert-or-jdk', 'unset'),
                                        ('/custom/cert-or-jdk', '/custom/cert-or-jdk')):
                    with self.subTest(value=value):
                        env = shell_environment(home, '/usr/bin:/bin',
                            **dict.fromkeys(variables, value), NIX_SSL_CERT_FILE=value)
                        result = subprocess.run(['zsh', '-f', '-c',
                            'source "$1"; shift; '
                            'for name in "$@"; do print -r -- "${(P)name-unset}"; done; '
                            '[[ -z "${NIX_SSL_CERT_FILE:-}" ]]',
                            'zsh', str(ROOT / 'dot_zshenv.d/nix.zsh'), *variables],
                            env=env, capture_output=True, text=True)
                        self.assertEqual(result.returncode, 0, result.stderr)
                        self.assertEqual(result.stdout.splitlines(),
                                         [expected] * len(variables))

    def test_nix_terminfo_is_removed_before_new_terminfo_is_installed(self):
        with tempfile.TemporaryDirectory() as directory:
            home = Path(directory)
            env = shell_environment(home, '/usr/bin:/bin', TERMINFO_DIRS=(
                f'/nix/store/old/terminfo:{home}/.nix-profile/share/terminfo:'
                f'{home}/.local/state/nix/profiles/profile/share/terminfo:'
                '/custom/terminfo::/usr/share/terminfo:'))
            result = subprocess.run(['zsh', '-f', '-c',
                'source "$1"; source "$2"; source "$1"; print -r -- "$TERMINFO_DIRS"',
                'zsh', str(ROOT / 'dot_zshenv.d/nix.zsh'),
                str(ROOT / 'dot_zshenv.d/runtime.zsh')],
                env=env, capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(result.stdout.strip(), '/custom/terminfo::/usr/share/terminfo:')

    def test_noninteractive_shell_without_nix_or_optional_tools(self):
        with tempfile.TemporaryDirectory() as directory:
            home = Path(directory)
            (home / '.zshenv.d').mkdir()
            for name in ('nix.zsh', 'runtime.zsh', 'tools.zsh'):
                (home / '.zshenv.d' / name).write_text(
                    (ROOT / 'dot_zshenv.d' / name).read_text())
            (home / '.zshenv').write_text((ROOT / 'dot_zshenv').read_text())
            (home / '.zshrc').write_text((ROOT / 'dot_zshrc').read_text())
            # Ubuntuのようにmise本体がPATH上にある環境を再現する。
            binaries = home / 'bin'
            binaries.mkdir()
            ci_data = home / 'ci-mise'
            (ci_data / 'jdk/bin').mkdir(parents=True)
            (ci_data / 'jdk/bin/java').write_text('#!/bin/sh\nexit 0\n')
            (ci_data / 'jdk/bin/java').chmod(0o755)
            (binaries / 'mise').write_text(
                '#!/bin/sh\n[ -n "${MISE_DATA_DIR:-}" ] || exit 1\n'
                'printf "%s/jdk\\n" "$MISE_DATA_DIR"\n')
            (binaries / 'mise').chmod(0o755)
            with patch.dict(os.environ, {'MISE_DATA_DIR': str(ci_data)}):
                env = shell_environment(home,
                    f'/nix/store/old/bin:{home}/.nix-profile/bin:{binaries}:/usr/bin:/bin',
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
            env = shell_environment(home, f'{binaries}:/usr/bin:/bin',
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
