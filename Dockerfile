# Use a Python 3.6 Base Image.
FROM python:3.6

# Set Maintainer.
LABEL maintainer "rgdevops123@gmail.com"

# Copy Application files.
COPY app.py requirements.txt test.py /

# Install Dependencies.
RUN pip install -r requirements.txt

# Set a Health Check.
HEALTHCHECK --interval=5s \
            --timeout=5s \
            CMD curl -f http://127.0.0.1:5000 || exit 1

# tell docker what port to expose
EXPOSE 5000

# Specify the command to run.
ENTRYPOINT ["python","app.py"]
