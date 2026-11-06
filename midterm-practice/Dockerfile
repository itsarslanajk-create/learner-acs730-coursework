# ACS730 midterm practice image.
FROM python:3.11-slim-bookworm

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

RUN useradd --create-home --uid 10001 appuser

WORKDIR /app

# Dependencies first: requirements.txt must be in the image before pip can read it.
COPY requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt

COPY app.py ./

USER appuser

EXPOSE 8000

# The app's port is 8000 everywhere (README, EXPOSE, CI smoke test).
CMD ["gunicorn", "--bind", "0.0.0.0:8000", "--workers", "2", "app:app"]
