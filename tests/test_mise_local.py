"""マシン固有設定の保持と、導入時の設定結合を実際のmise/chezmoiで確認する。"""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


class MiseLocalTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.work = Path(self.temp.name)
        self.home = self.work / 'home'
        self.source = self.work / 'source'
        self.project = self.work / 'project'
        for directory in (self.home / '.config/mise', self.source / 'dot_config/mise',
                          self.source / 'scripts', self.project, self.work / 'bin'):
            directory.mkdir(parents=True, exist_ok=True)
        self.mise = os.environ.get('MISE_TEST_BIN') or shutil.which('mise')
        self.chezmoi = os.environ.get('CHEZMOI_BIN') or shutil.which('chezmoi')
        if not self.mise or not self.chezmoi:
            self.skipTest('mise and chezmoi are required')
        # CIではchezmoiがshimの場合がある。fixtureの設定に切り替える前に実体を得る。
        if Path(self.chezmoi).parent.name == 'shims':
            resolved = subprocess.run([self.mise, 'which', 'chezmoi'],
                                      capture_output=True, text=True)
            if resolved.returncode == 0:
                self.chezmoi = resolved.stdout.strip()
            else:
                # 移行途中では未選択のshimがPATH上の旧chezmoiへフォールバックする。
                search_path = os.pathsep.join(
                    entry for entry in os.environ.get('PATH', '').split(os.pathsep)
                    if Path(entry).resolve() != Path(self.chezmoi).parent.resolve())
                fallback = shutil.which('chezmoi', path=search_path)
                if not fallback:
                    resolved.check_returncode()
                self.chezmoi = fallback
        (self.work / 'bin/mise').symlink_to(self.mise)
        self.env = dict(HOME=str(self.home), ZDOTDIR=str(self.home),
                        PATH=f'{self.work}/bin:/opt/homebrew/bin:/usr/bin:/bin',
                        MISE_DATA_DIR=str(self.work / 'data'),
                        MISE_CACHE_DIR=str(self.work / 'cache'),
                        MISE_STATE_DIR=str(self.work / 'state'),
                        MISE_TRUSTED_CONFIG_PATHS=str(self.work))
        terminfo = self.home / '.local/share/terminfo'
        terminfo.mkdir(parents=True)
        subprocess.run(['tic', '-x', '-o', str(terminfo),
                        str(ROOT / 'assets/terminfo/ghostty.terminfo')],
                       check=True, capture_output=True)
        self.env['TERMINFO_DIRS'] = str(terminfo) + ':'
        self.local = self.home / '.config/mise/config.local.toml'
        self.base_node = self.tool('base-node', 'node')
        self.local_node = self.tool('local-node', 'node')
        self.python = self.tool('local-python', 'python')
        self.project_node = self.tool('project-node', 'node')
        (self.source / 'dot_config/mise/config.toml').write_text(
            f'[tools]\nnode = "path:{self.base_node}"\n')
        self.local.write_text(
            f'[tools]\nnode = "path:{self.local_node}"\npython = "path:{self.python}"\n')
        (self.project / 'mise.toml').write_text(
            f'[tools]\nnode = "path:{self.project_node}"\n')
        for name in ('.chezmoiignore', 'run_onchange_after_25-install-mise-tools.sh.tmpl',
                     'scripts/mise-global.sh', 'run_onchange_after_27-retire-volta.sh.tmpl'):
            shutil.copyfile(ROOT / name, self.source / name)

    def tool(self, name, command):
        directory = self.work / name
        (directory / 'bin').mkdir(parents=True)
        binary = directory / 'bin' / command
        binary.write_text(f'#!/bin/sh\nprintf "%s\\n" "{name}"\n')
        binary.chmod(0o755)
        return directory

    def chezmoi_command(self, *args):
        data = json.dumps({'chezmoi': {'homeDir': str(self.home)}})
        return subprocess.run(
            [self.chezmoi, '--source', str(self.source), '--destination', str(self.home),
             '--config', '/dev/null', '--config-format', 'toml',
             '--persistent-state', str(self.work / 'chezmoi.boltdb'),
             '--override-data', data, '--no-tty', *args],
            env=self.env, capture_output=True, text=True, check=True)

    def global_command(self, *args):
        return subprocess.check_output(
            ['sh', str(ROOT / 'scripts/mise-global.sh'), *args],
            cwd=self.project, env=self.env, text=True).strip()

    def test_apply_keeps_local_file_and_install_uses_merged_global_config(self):
        before = self.local.read_bytes()
        for _ in range(2):
            self.chezmoi_command('apply', '--exclude', 'scripts')
            self.assertEqual(before, self.local.read_bytes())
        rendered = self.chezmoi_command('execute-template', '-f',
            str(self.source / 'run_onchange_after_25-install-mise-tools.sh.tmpl')).stdout
        result = subprocess.run(['sh'], input=rendered, text=True, env=self.env,
                                cwd=self.project, capture_output=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.global_command('where', 'node'), str(self.local_node))
        self.assertEqual(self.global_command('where', 'python'), str(self.python))
        # ローカル設定の変更がrun_onchangeの再実行条件になることも確認する。
        self.local.write_text(self.local.read_text() + '\n# machine change\n')
        changed = self.chezmoi_command('execute-template', '-f',
            str(self.source / 'run_onchange_after_25-install-mise-tools.sh.tmpl')).stdout
        self.assertNotEqual(rendered, changed)

    def test_disabled_tool_is_not_required(self):
        self.chezmoi_command('apply', '--exclude', 'scripts')
        self.local.write_text(self.local.read_text() + '\n[settings]\ndisable_tools = ["python"]\n')
        selected = json.loads(self.global_command('ls', '--current', '--json'))
        self.assertIn('node', selected)
        self.assertNotIn('python', selected)

    def test_environment_check_requires_only_selected_installed_tools(self):
        self.chezmoi_command('apply', '--exclude', 'scripts')
        # OSパッケージは検査対象の存在だけを提供し、miseの選択は実体で検証する。
        for command in ('git', 'tmux', 'rg', 'direnv', 'gh', 'eza', 'zoxide'):
            binary = self.work / 'bin' / command
            binary.write_text('#!/bin/sh\nexit 0\n')
            binary.chmod(0o755)
        uname = self.work / 'bin/uname'
        uname.write_text('#!/bin/sh\nprintf "Linux\\n"\n')
        uname.chmod(0o755)
        def check():
            return subprocess.run(['sh', str(ROOT / 'scripts/check-environment.sh')],
                                  cwd=self.project, env=self.env,
                                  text=True, capture_output=True)
        result = check()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        shutil.rmtree(self.python)
        result = check()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('FAIL configured tool is not installed: python', result.stdout)
        self.local.write_text(self.local.read_text() + '\n[settings]\ndisable_tools = ["python"]\n')
        result = check()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_volta_is_kept_when_optional_node_tools_are_not_selected(self):
        self.chezmoi_command('apply', '--exclude', 'scripts')
        (self.home / '.volta').mkdir()
        rendered = self.chezmoi_command('execute-template', '-f',
            str(self.source / 'run_onchange_after_27-retire-volta.sh.tmpl')).stdout
        result = subprocess.run(['sh'], input=rendered, text=True,
                                env=self.env, capture_output=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue((self.home / '.volta').is_dir())
        self.assertFalse((self.home / '.volta.retired').exists())


if __name__ == '__main__':
    unittest.main()
