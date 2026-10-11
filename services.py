"""Business rules adapted from the supplied ACEest 1.1 baseline.

Calorie factors are assignment sample logic, not medical recommendations.
"""

import math
from datetime import date

PROGRAMS = {
    "Fat Loss": {
        "calorie_factor": 22,
        "workout": "Squats, bike intervals, bench press, deadlifts and recovery cardio",
        "diet": "Egg whites and oats; chicken and brown rice; fish and millet roti",
    },
    "Muscle Gain": {
        "calorie_factor": 35,
        "workout": "Squat, bench press, deadlift, front squat, incline press and rows",
        "diet": "Eggs and peanut butter oats; chicken biryani; mutton curry and rice",
    },
    "Beginner": {
        "calorie_factor": 26,
        "workout": "Air squats, ring rows and push-ups with focus on technique",
        "diet": "Balanced meals including idli, dosa, rice and dal",
    },
}


class ValidationError(ValueError):
    pass


def require_object(data):
    if not isinstance(data, dict):
        raise ValidationError("Request must contain a JSON object")


def calculate_calories(weight, program):
    if not isinstance(program, str) or program not in PROGRAMS:
        raise ValidationError("Choose a valid program")
    if isinstance(weight, bool) or not isinstance(weight, (int, float)):
        raise ValidationError("Weight must be a positive number")
    if not math.isfinite(weight) or weight <= 0:
        raise ValidationError("Weight must be a positive finite number")
    return int(weight * PROGRAMS[program]["calorie_factor"])


def validate_client(data):
    require_object(data)
    name = data.get("name")
    if not isinstance(name, str) or not name.strip():
        raise ValidationError("Name is required")
    if len(name.strip()) > 100:
        raise ValidationError("Name must be at most 100 characters")
    age = data.get("age")
    if isinstance(age, bool) or not isinstance(age, int) or not 1 <= age <= 120:
        raise ValidationError("Age must be an integer from 1 to 120")
    weight = data.get("weight")
    program = data.get("program")
    calories = calculate_calories(weight, program)
    return dict(name=name.strip(), age=age, weight=weight, program=program, calories=calories)


def validate_progress(data):
    require_object(data)
    week = data.get("week")
    if not isinstance(week, str):
        raise ValidationError("Week must be a date in YYYY-MM-DD format")
    try:
        parsed = date.fromisoformat(week)
    except ValueError as error:
        raise ValidationError("Week must be a valid date in YYYY-MM-DD format") from error
    if parsed.isoformat() != week:
        raise ValidationError("Week must use YYYY-MM-DD format")
    adherence = data.get("adherence")
    if isinstance(adherence, bool) or not isinstance(adherence, int) or not 0 <= adherence <= 100:
        raise ValidationError("Adherence must be an integer from 0 to 100")
    return dict(week=week, adherence=adherence)
