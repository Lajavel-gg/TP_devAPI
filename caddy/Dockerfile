FROM caddy:2-alpine

# Copy Caddyfile configuration
COPY Caddyfile /etc/caddy/Caddyfile

# Copy TLS certificates
COPY certs/ /etc/caddy/certs/

EXPOSE 8443

CMD ["caddy", "run", "--config", "/etc/caddy/Caddyfile"]
