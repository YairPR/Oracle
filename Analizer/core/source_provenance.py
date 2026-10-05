"""Explicit collector provenance, independent of format and database evidence."""

import json
import os


def source_key(path):
    return os.path.normcase(os.path.abspath(path))


def load_manifest(path, case_directory):
    with open(path, encoding="utf-8") as stream:
        document = json.load(stream)
    result = {}
    for source, metadata in document["sources"].items():
        if not isinstance(metadata, dict):
            raise ValueError(f"Invalid provenance for {source}")
        item = {}
        for field in ("collector_version", "collector_evidence"):
            value = metadata.get(field)
            if value is not None and not isinstance(value, str):
                raise ValueError(f"{field} must be a string or null")
            item[field] = value
        if item["collector_version"] and not item["collector_evidence"]:
            raise ValueError(f"Collector version requires evidence: {source}")
        result[source_key(os.path.join(case_directory, source))] = item
    return result
