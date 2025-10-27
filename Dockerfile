FROM alpine:latest

RUN apk --no-cache add ca-certificates unzip wget

# Download and install Xray
RUN wget https://github.com/XTLS/Xray-core/releases/latest/download/Xray-linux-64.zip -O /tmp/xray.zip \
    && unzip /tmp/xray.zip -d /usr/local/bin/ \
    && rm /tmp/xray.zip \
    && chmod +x /usr/local/bin/xray

# Copy config
COPY config.json /etc/xray/config.json

# Expose port
EXPOSE 8080

# Run Xray
CMD ["/usr/local/bin/xray", "-config", "/etc/xray/config.json"]