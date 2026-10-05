"""Buffered text I/O timings, separated from parser CPU time."""

from time import perf_counter


class TimedText:
    def __init__(self, path, profile, **kwargs):
        self.profile = profile
        start = perf_counter()
        self.file = open(path, **kwargs)
        self.profile["lectura_seg"] = (
            self.profile.get("lectura_seg", 0.0) + perf_counter() - start
        )

    def __enter__(self):
        return self

    def __exit__(self, *args):
        self.file.close()

    def __iter__(self):
        return self

    def __next__(self):
        start = perf_counter()
        try:
            return next(self.file)
        finally:
            self.profile["lectura_seg"] += perf_counter() - start

    def read(self):
        start = perf_counter()
        try:
            return self.file.read()
        finally:
            self.profile["lectura_seg"] += perf_counter() - start
