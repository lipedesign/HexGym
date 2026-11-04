#!/usr/bin/env python3
"""Roda os testes do gerador de regiões (os test_*.py desta pasta) com o unittest.

    python3 -I scripts/hexbody/regions/run_tests.py

Com HEXGYM_CHECK_COUNT_FILE no ambiente, grava nele quantos testes passaram, no formato do fim
do tap (# pass <n>), que o scripts/hexgym/check.mjs lê: os que passaram, sem os pulados. Sai com
1 se algum teste falhou ou deu erro, ou se nenhum teste rodou. Só biblioteca padrão.
"""
import os
import sys
import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parent
COUNT_FILE = 'HEXGYM_CHECK_COUNT_FILE'


def main():
    suite = unittest.defaultTestLoader.discover(str(HERE), pattern='test_*.py', top_level_dir=str(HERE))
    result = unittest.TextTestRunner(verbosity=2).run(suite)
    failed = len(result.failures) + len(result.errors) + len(result.unexpectedSuccesses)
    passed = result.testsRun - failed - len(result.skipped) - len(result.expectedFailures)
    count = os.environ.get(COUNT_FILE)
    if count:
        Path(count).write_text(f'# tests {result.testsRun}\n# pass {passed}\n# fail {failed}\n', encoding='utf-8')
    if result.testsRun == 0:   # como uma parte vazia do check.mjs (issue #44): sem teste, não passa
        print('nenhum teste rodou', file=sys.stderr)
        return 1
    return 0 if result.wasSuccessful() and failed == 0 else 1


if __name__ == '__main__':
    sys.exit(main())
