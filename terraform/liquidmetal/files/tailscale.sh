#!/bin/bash

curl -fsSL https://tailscale.com/install.sh | sh

tailscale up --advertise-routes=192.168.1.0/25 --authkey "$AUTH_KEY"
