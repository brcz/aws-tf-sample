FROM python:3.9-slim

WORKDIR /app

COPY . /app

RUN pip install flask

EXPOSE 5000

ENV NAME=World

CMD ["python", "app.py"]
