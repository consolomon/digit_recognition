FROM python:3.12

# Add enviroment arguments
WORKDIR /app

# Update container components
RUN apt-get update -y

# Copy all files into container
COPY . .

# Setup require packages
RUN pip install -r requirements.txt

# Set opened port
EXPOSE 8001

CMD ["gunicorn", "--bind", "0.0.0.0:8001", "--workers", "2", "app:app"]