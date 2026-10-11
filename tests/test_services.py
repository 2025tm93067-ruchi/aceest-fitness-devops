import pytest

from services import ValidationError, calculate_calories, validate_client, validate_progress


@pytest.mark.parametrize("program,expected", [("Fat Loss", 1540), ("Muscle Gain", 2450), ("Beginner", 1820)])
def test_calorie_factors(program, expected):
    assert calculate_calories(70, program) == expected


def test_fractional_calories_are_truncated():
    assert calculate_calories(70.15, "Fat Loss") == 1543


@pytest.mark.parametrize("weight", [0, -1, "70", None, True, float("inf"), float("nan")])
def test_invalid_weight(weight):
    with pytest.raises(ValidationError):
        calculate_calories(weight, "Fat Loss")


@pytest.mark.parametrize("program", ["Unknown", None, [], 1])
def test_invalid_program(program):
    with pytest.raises(ValidationError):
        calculate_calories(70, program)


@pytest.mark.parametrize("data", [None, [], "bad"])
def test_client_requires_object(data):
    with pytest.raises(ValidationError):
        validate_client(data)


@pytest.mark.parametrize("field,value", [
    ("name", ""), ("name", "   "), ("name", 7), ("name", "x" * 101),
    ("age", 0), ("age", 121), ("age", True), ("age", 25.5), ("age", "25"),
])
def test_invalid_client_fields(valid_client, field, value):
    valid_client[field] = value
    with pytest.raises(ValidationError):
        validate_client(valid_client)


def test_name_is_trimmed(valid_client):
    valid_client["name"] = "  Student  "
    assert validate_client(valid_client)["name"] == "Student"


@pytest.mark.parametrize("adherence", [0, 100])
def test_progress_boundaries(adherence):
    assert validate_progress({"week": "2026-10-05", "adherence": adherence})["adherence"] == adherence


@pytest.mark.parametrize("week", [None, "2026-02-30", "05-10-2026", "20261005", "2026-W41-1"])
def test_invalid_progress_date(week):
    with pytest.raises(ValidationError):
        validate_progress({"week": week, "adherence": 80})


@pytest.mark.parametrize("adherence", [-1, 101, True, "80", 80.5, None])
def test_invalid_adherence(adherence):
    with pytest.raises(ValidationError):
        validate_progress({"week": "2026-10-05", "adherence": adherence})
