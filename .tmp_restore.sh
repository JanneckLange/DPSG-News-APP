#!/usr/bin/env bash
set -e
cd '/Users/lange/Documents/dpsgnews/DPSG News APP'
if git ls-files --error-unmatch app/coverage/lcov.info >/dev/null 2>&1; then
  git checkout -- app/coverage/lcov.info
else
  rm -f app/coverage/lcov.info
fi
