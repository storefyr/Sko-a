#!/bin/sh
# Skoðja background daemon wrapper
# Runs the Python daemon directly (no QML needed)
exec /usr/bin/python3 /usr/share/harbour-skodja/python/gitwatch/github_client.py 60
