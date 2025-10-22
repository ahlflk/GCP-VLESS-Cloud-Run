# Use lightweight Alpine base image
FROM alpine:latest

# Install dependencies: wget for download, ca-certificates for HTTPS
RUN apk add --no-cache wget ca-certificates unzip

# Download and install latest Xray-core (64-bit Linux)
RUN wget https://github.com/XTLS/Xray-core/releases/latest/download/Xray-linux-64.zip \
    && unzip Xray-linux-64.zip \
    && mv xray /usr/local/bin/xray \
    && chmod +x /usr/local/bin/xray \
    && rm Xray-linux-64.zip \
    && mkdir -p /etc/xray

# Copy the config file (UUID will be replaced by the deployment script)
COPY config.json /etc/xray/config.json

# Expose port for Cloud Run (default 8080)
EXPOSE 8080

# Run Xray with the config
CMD ["/usr/local/bin/xray", "run", "-c", "/etc/xray/config.json"]