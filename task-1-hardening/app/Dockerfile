FROM python:3.11-slim

WORKDIR /app

RUN groupadd -g 10001 appgroup && \
    useradd -r -u 10001 -g appgroup -d /app -s /sbin/nologin appuser && \
    chown -R appuser:appgroup /app

COPY requirements.txt .
RUN pip install --no-cache-dir --upgrade pip setuptools wheel && \
    pip install --no-cache-dir -r requirements.txt

COPY app.py .
RUN chown appuser:appgroup app.py

USER 10001:10001

EXPOSE 8080

CMD ["python", "app.py"]
