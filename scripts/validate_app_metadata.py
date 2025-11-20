#!/usr/bin/env python3
"""Validate per-app app.yaml metadata files.

Checks (per apps/<dir>/):
  - app.yaml exists
  - required keys present
  - type: helm -> repoURL, chart, version required
  - type omitted (kustomize) -> path required
  - path exists and is a directory (or file if kustomize root)
  - wave (if present) is int-coercible
  - createNamespace (if present) is boolean-y (true/false)
  - enabled (if present) is boolean-y
  - name matches directory unless override allowed (warn if different)
Exits non-zero if any errors found; prints summary.
"""
from __future__ import annotations
import sys, os, yaml, re

APPS_DIR = os.path.join(os.getcwd(), 'apps')
REQUIRED_COMMON = ['name']
HELM_REQUIRED = ['repoURL', 'chart', 'version']

BOOL_VALUES = {'true','false',True,False}

def load_yaml(p):
    with open(p, 'r') as f:
        return yaml.safe_load(f) or {}

def is_booly(v):
    if isinstance(v,bool):
        return True
    if isinstance(v,str) and v.lower() in {'true','false'}:
        return True
    return False

def main():
    errors = []
    warnings = []
    if not os.path.isdir(APPS_DIR):
        print(f"ERROR: apps/ directory not found at {APPS_DIR}")
        return 2

    for entry in sorted(os.listdir(APPS_DIR)):
        if entry.startswith('.'):
            continue
        dpath = os.path.join(APPS_DIR, entry)
        if not os.path.isdir(dpath):
            continue
        app_yaml = os.path.join(dpath, 'app.yaml')
        if not os.path.exists(app_yaml):
            warnings.append(f"WARN: {entry}: missing app.yaml (skipped)")
            continue
        try:
            data = load_yaml(app_yaml)
        except Exception as e:
            errors.append(f"ERROR: {entry}: failed to parse app.yaml: {e}")
            continue
        # basic presence
        for k in REQUIRED_COMMON:
            if k not in data:
                errors.append(f"ERROR: {entry}: missing required key '{k}'")
        name = data.get('name')
        if name and name != entry:
            warnings.append(f"WARN: {entry}: name '{name}' differs from directory name")
        app_type = data.get('type','kustomize')
        path = data.get('path')
        if app_type == 'helm':
            missing = [k for k in HELM_REQUIRED if k not in data]
            if missing:
                errors.append(f"ERROR: {entry}: helm app missing keys: {', '.join(missing)}")
            if not path:
                # allow helm without kustomize overlay; path optional
                pass
            else:
                p_abs = os.path.join(os.getcwd(), path)
                if not os.path.exists(p_abs):
                    errors.append(f"ERROR: {entry}: path '{path}' does not exist")
        else:  # kustomize
            if not path:
                errors.append(f"ERROR: {entry}: kustomize app requires 'path'")
            else:
                p_abs = os.path.join(os.getcwd(), path)
                if not os.path.isdir(p_abs):
                    errors.append(f"ERROR: {entry}: path '{path}' not a directory")
        # wave
        if 'wave' in data:
            try:
                int(str(data['wave']).strip())
            except Exception:
                errors.append(f"ERROR: {entry}: wave '{data['wave']}' not an integer")
        # booleans
        for key in ['createNamespace','enabled']:
            if key in data and not is_booly(data[key]):
                errors.append(f"ERROR: {entry}: {key} must be boolean (true/false)")
        # simple name format
        if name and not re.match(r'^[a-z0-9]([-a-z0-9]*[a-z0-9])?$', name):
            warnings.append(f"WARN: {entry}: name '{name}' not RFC1123 label compliant")

    if errors:
        for e in errors: print(e)
    if warnings:
        for w in warnings: print(w)
    print(f"Validation complete: {len(errors)} errors, {len(warnings)} warnings.")
    return 1 if errors else 0

if __name__ == '__main__':
    sys.exit(main())
