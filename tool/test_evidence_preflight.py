import gzip
from pathlib import Path
import tarfile
import tempfile
import unittest
from unittest.mock import patch

from package_verification_evidence import verify_evidence_archive, preflight_evidence_tar


class EvidencePreflightTest(unittest.TestCase):
    def archive(self, directory, header, payload=b''):
        path = Path(directory) / 'untrusted-evidence.tar.gz'
        with gzip.open(path, 'wb') as stream:
            stream.write(header.tobuf())
            stream.write(payload)
            stream.write(b'\0' * 1024)
        return path

    def test_huge_pax_record_is_rejected_before_tarfile_metadata_read(self):
        with tempfile.TemporaryDirectory() as directory:
            header = tarfile.TarInfo('pax')
            header.type, header.size = tarfile.XHDTYPE, 1024 ** 3
            path = self.archive(directory, header)
            with self.assertRaisesRegex(ValueError, 'metadata byte budget'):
                verify_evidence_archive(path)

    def test_oversized_regular_member_is_rejected_before_payload_read(self):
        with tempfile.TemporaryDirectory() as directory:
            header = tarfile.TarInfo('oversized.log')
            header.size = 32 * 1024 * 1024 + 1
            path = self.archive(directory, header)
            with self.assertRaisesRegex(ValueError, 'member byte budget'):
                verify_evidence_archive(path)

    def test_pax_size_override_cannot_bypass_raw_header_limits(self):
        with tempfile.TemporaryDirectory() as directory:
            record = b'19 size=1073741824\n'
            header = tarfile.TarInfo('pax')
            header.type, header.size = tarfile.XHDTYPE, len(record)
            path = self.archive(directory, header, record + b'\0' * (512 - len(record)))
            with self.assertRaisesRegex(ValueError, 'PAX'):
                verify_evidence_archive(path)

    def test_member_count_is_rejected_before_tarfile_constructs_inventory(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'too-many.tar.gz'
            with gzip.open(path, 'wb') as stream:
                for index in range(32769):
                    stream.write(tarfile.TarInfo('member-' + str(index)).tobuf())
                stream.write(b'\0' * 1024)
            with patch('package_verification_evidence.tarfile.open', side_effect=AssertionError('Unbounded TarFile inventory read')):
                with self.assertRaisesRegex(ValueError, 'member-count budget'):
                    verify_evidence_archive(path)

    def test_metadata_recursion_and_hidden_trailing_members_are_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'metadata-depth.tar.gz'
            header = tarfile.TarInfo('pax');header.type = tarfile.XHDTYPE
            with gzip.open(path, 'wb') as stream:
                for _ in range(3):
                    stream.write(header.tobuf())
                stream.write(b'\0' * 1024)
            with self.assertRaisesRegex(ValueError, 'count/depth budget'):
                preflight_evidence_tar(path)
            with gzip.open(path, 'wb') as stream:
                stream.write(tarfile.TarInfo('file').tobuf())
                stream.write(b'\0' * 1024)
                stream.write(tarfile.TarInfo('hidden-member').tobuf())
            with self.assertRaisesRegex(ValueError, 'trailing data'):
                preflight_evidence_tar(path)


if __name__ == '__main__':
    unittest.main()
