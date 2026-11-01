#!/usr/bin/env python3
"""Build the Linux product entrypoint with actual complete-bundle evidence."""
from desktop_build_evidence import build
import argparse
if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--no-pub', action='store_true',
                        help='Use dependencies already verified by a separate locked pub get')
    raise SystemExit(build('linux', no_pub=parser.parse_args().no_pub))
