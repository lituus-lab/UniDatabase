# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
import tempfile
from pathlib import Path

import pytest

from unidatabase import Database, abi_version, version


def test_version():
    assert version() == "0.1.0"
    assert __import__("unidatabase").__version__ == "0.1.0"


def test_abi_version_is_a_generation():
    assert isinstance(abi_version(), int)
    assert abi_version() >= 1


def test_statements_run_against_a_real_file():
    with tempfile.TemporaryDirectory() as directory:
        with Database(str(Path(directory) / "consumer.sqlite")) as database:
            database.execute("CREATE TABLE values_table(value TEXT)")
            database.execute("INSERT INTO values_table VALUES ('ok')")
            assert database.is_open
        assert not database.is_open


def test_closing_twice_is_a_no_op():
    with tempfile.TemporaryDirectory() as directory:
        database = Database(str(Path(directory) / "twice.sqlite"))
        database.close()
        database.close()
        assert not database.is_open


def test_a_closed_database_refuses_work():
    with tempfile.TemporaryDirectory() as directory:
        database = Database(str(Path(directory) / "closed.sqlite"))
        database.close()
        with pytest.raises(RuntimeError):
            database.execute("CREATE TABLE t(x TEXT)")


def test_a_refused_statement_raises():
    with tempfile.TemporaryDirectory() as directory:
        with Database(str(Path(directory) / "bad.sqlite")) as database:
            with pytest.raises(RuntimeError):
                database.execute("THIS IS NOT SQL")


def test_the_types_are_checked():
    with pytest.raises(TypeError):
        Database(1)
    with tempfile.TemporaryDirectory() as directory:
        with Database(str(Path(directory) / "types.sqlite")) as database:
            with pytest.raises(TypeError):
                database.execute(2)
