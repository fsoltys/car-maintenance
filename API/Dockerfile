# car-maintenance/API/Dockerfile
FROM python:3.12-slim

ENV PYTHONUNBUFFERED=1

WORKDIR /app

# dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Kod aplikacji
COPY . .

# Zmienna PORT (można nadpisać w docker-compose)
ENV PORT=8000

EXPOSE 8000

# Uvicorn startuje FastAPI (apka w app/main.py -> app)
CMD ["sh", "-c", "uvicorn app.main:app --host 0.0.0.0 --port $PORT --reload"]
