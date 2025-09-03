#!/bin/bash

# Generate self-signed SSL certificate for development
# In production, use certificates from a trusted CA

CERT_DIR="./ssl"
mkdir -p $CERT_DIR

# Generate private key
openssl genrsa -out $CERT_DIR/selfsigned.key 2048

# Generate certificate signing request
openssl req -new -key $CERT_DIR/selfsigned.key -out $CERT_DIR/selfsigned.csr \
  -subj "/C=US/ST=State/L=City/O=Organization/CN=localhost"

# Generate self-signed certificate
openssl x509 -req -days 365 -in $CERT_DIR/selfsigned.csr \
  -signkey $CERT_DIR/selfsigned.key -out $CERT_DIR/selfsigned.crt

echo "SSL certificates generated in $CERT_DIR/"
echo "Certificate: $CERT_DIR/selfsigned.crt"
echo "Private Key: $CERT_DIR/selfsigned.key"
