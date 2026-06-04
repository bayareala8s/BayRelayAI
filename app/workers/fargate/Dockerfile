FROM python:3.12-slim
WORKDIR /app
COPY worker.py .
ENV PYTHONUNBUFFERED=1
CMD ["python", "worker.py"]
