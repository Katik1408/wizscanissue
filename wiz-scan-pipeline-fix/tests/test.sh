#!/bin/bash
set -e

cd /app
python -m pytest tests/test_outputs.py -v
