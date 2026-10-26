FROM python:3.12-slim

WORKDIR /app

# Setup require packages first, so code changes reuse the cached layer
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy the app (.dockerignore keeps the training dataset and caches out)
COPY . .

# Set opened port
EXPOSE __APP_PORT__

CMD ["gunicorn", "--bind", "0.0.0.0:__APP_PORT__", "--workers", "2", "app:app"]
