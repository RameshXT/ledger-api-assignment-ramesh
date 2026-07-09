FROM python:3.11-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY app.py .

EXPOSE 8080

CMD ["python", "app.py"]  # nosemgrep - Intentionally left vulnerable — reserved as a real finding for Task 4 penetration testing. See task-2-cicd/DEFERRED-FINDINGS.md.
