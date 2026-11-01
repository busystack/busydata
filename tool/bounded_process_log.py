"""Drain an owned child continuously while bounding retained diagnostic bytes."""
import threading


class BoundedProcessLog:
    def __init__(self, process, destination, limit=8 * 1024 * 1024):
        self.process = process
        self.destination = destination
        self.limit = limit
        self.received = 0
        self.retained = 0
        self.failure = None
        self.thread = threading.Thread(target=self._drain, daemon=True)
        self.thread.start()

    def _drain(self):
        try:
            with self.destination.open('wb') as output:
                # BufferedReader.read(size) can hide all progress until a full
                # block or EOF. Drain bytes that are actually available.
                read = getattr(self.process.stdout, 'read1', self.process.stdout.read)
                while chunk := read(65536):
                    self.received += len(chunk)
                    count = min(len(chunk), self.limit - self.retained)
                    if count > 0:
                        output.write(chunk[:count])
                        self.retained += count
                        output.flush()
        except Exception as failure:
            self.failure = type(failure).__name__
        finally:
            self.process.stdout.close()

    def finish(self):
        self.thread.join(timeout=10)
        return {'file': str(self.destination), 'receivedBytes': self.received,
                'retainedBytes': self.retained, 'limitBytes': self.limit,
                'complete': not self.thread.is_alive() and self.failure is None
                            and self.received <= self.limit,
                'failureType': self.failure}
