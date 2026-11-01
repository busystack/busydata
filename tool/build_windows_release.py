#!/usr/bin/env python3
"""Build the existing Windows target with actual complete-bundle evidence."""
from desktop_build_evidence import build
if __name__ == '__main__':
    raise SystemExit(build('windows'))
