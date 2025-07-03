# Dockerfile
FROM python:3.9-slim

# work directory 
WORKDIR /app

# copy source 
COPY app.py .

# Flask install 
RUN pip install flask

# Flask start when container runs
CMD ["python", "app.py"]
