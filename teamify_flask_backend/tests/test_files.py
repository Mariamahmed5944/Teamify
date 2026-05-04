"""
Tests for Files blueprint (/api/files/*).
Endpoints: POST upload, GET /<id> download
"""
import io
from unittest.mock import patch, MagicMock
import pytest
from tests.conftest import (
    ADMIN_USER_ID, MEMBER_USER_ID, GUEST_USER_ID,
    FILE_ID, NONEXISTENT_ID,
    _make_user,
)


def _make_file_meta(fid=FILE_ID, owner_id=MEMBER_USER_ID):
    fm = MagicMock()
    fm.id = fid
    fm.owner_id = owner_id
    fm.original_filename = "test.txt"
    fm.mime_type = "text/plain"
    fm.size_bytes = 100
    fm.encrypted_path = "/fake/path.enc"
    fm.sha256_hash = "abc123"
    fm.to_dict.return_value = {"id": str(fid), "filename": "test.txt"}
    return fm


class TestUploadFile:
    URL = "/api/files"

    @patch("routes.files.FileMetadata")
    @patch("routes.files.encrypt_bytes")
    @patch("routes.files.sha256_hex")
    @patch("routes.files.os")
    def test_success_201(self, m_os, m_sha, m_enc, m_fm, client, member_headers):
        m_sha.return_value = "deadbeef"
        m_enc.return_value = b"encrypted"
        m_os.path.join.return_value = "/tmp/fake.enc"
        m_os.O_WRONLY = 1; m_os.O_CREAT = 2; m_os.O_EXCL = 4
        m_os.open.return_value = 99
        m_os.fdopen.return_value.__enter__ = MagicMock()
        m_os.fdopen.return_value.__exit__ = MagicMock(return_value=False)
        fm = _make_file_meta()
        m_fm.return_value = fm
        data = {"file": (io.BytesIO(b"hello world"), "test.txt")}
        headers = {"Authorization": member_headers["Authorization"]}
        r = client.post(self.URL, headers=headers, data=data, content_type="multipart/form-data")
        assert r.status_code == 201

    def test_no_file_400(self, client, member_headers):
        headers = {"Authorization": member_headers["Authorization"]}
        r = client.post(self.URL, headers=headers, data={}, content_type="multipart/form-data")
        assert r.status_code == 400

    def test_no_token_401(self, client):
        data = {"file": (io.BytesIO(b"hello"), "test.txt")}
        assert client.post(self.URL, data=data, content_type="multipart/form-data").status_code == 401


class TestDownloadFile:
    URL = f"/api/files/{FILE_ID}"

    @patch("routes.files.verify_hash")
    @patch("routes.files.decrypt_bytes")
    @patch("builtins.open", create=True)
    @patch("routes.files.User")
    @patch("routes.files.FileMetadata")
    def test_owner_200(self, m_fm, m_user, m_open, m_dec, m_verify, client, member_headers):
        fm = _make_file_meta()
        m_fm.query.filter_by.return_value.first.return_value = fm
        m_user.query.filter_by.return_value.first.return_value = _make_user(MEMBER_USER_ID)
        m_open.return_value.__enter__ = MagicMock(return_value=io.BytesIO(b"enc"))
        m_open.return_value.__exit__ = MagicMock(return_value=False)
        m_dec.return_value = b"hello world"
        m_verify.return_value = True
        r = client.get(self.URL, headers=member_headers)
        assert r.status_code == 200

    @patch("routes.files.User")
    @patch("routes.files.FileMetadata")
    def test_non_owner_403(self, m_fm, m_user, client, guest_headers):
        fm = _make_file_meta(owner_id=MEMBER_USER_ID)
        m_fm.query.filter_by.return_value.first.return_value = fm
        m_user.query.filter_by.return_value.first.return_value = _make_user(GUEST_USER_ID, role="guest")
        assert client.get(self.URL, headers=guest_headers).status_code == 403

    @patch("routes.files.FileMetadata")
    def test_not_found_404(self, m_fm, client, member_headers):
        m_fm.query.filter_by.return_value.first.return_value = None
        assert client.get(f"/api/files/{NONEXISTENT_ID}", headers=member_headers).status_code == 404

    def test_invalid_id_400(self, client, member_headers):
        assert client.get("/api/files/bad-id", headers=member_headers).status_code == 400

    def test_no_token_401(self, client):
        assert client.get(self.URL).status_code == 401


# ─── Advanced: File Upload Security ──────────────────────────────────────────

class TestUploadFileSecurity:
    """Test malicious file upload scenarios: dangerous extensions, MIME spoofing, size."""
    URL = "/api/files"

    @pytest.mark.parametrize("filename", [
        "exploit.sh", "malware.exe", "backdoor.php",
        "payload.jar", "virus.dll", "evil.cgi",
    ])
    def test_dangerous_extension_415(self, client, member_headers, filename):
        """Binary/executable MIME types are rejected by the allowlist."""
        data = {"file": (io.BytesIO(b"#!/bin/bash\nrm -rf /"), filename)}
        headers = {"Authorization": member_headers["Authorization"]}
        r = client.post(self.URL, headers=headers, data=data, content_type="multipart/form-data")
        # The server checks MIME type, not extension. Werkzeug guesses MIME from
        # the extension, so .sh → application/x-sh, .exe → application/x-msdos-program,
        # etc., all of which are NOT in ALLOWED_MIME_PREFIXES → 415.
        assert r.status_code == 415
        assert "Unsupported media type" in r.get_json()["error"]

    def test_mime_spoofing_txt_as_png_415(self, client, member_headers):
        """A .txt payload renamed to .xyz gets guessed as application/octet-stream → 415."""
        data = {"file": (io.BytesIO(b"not an image"), "fake.xyz")}
        headers = {"Authorization": member_headers["Authorization"]}
        r = client.post(self.URL, headers=headers, data=data, content_type="multipart/form-data")
        assert r.status_code == 415

    def test_file_exceeds_10mb_413(self, client, member_headers):
        """Files larger than MAX_UPLOAD_BYTES (10 MB) are rejected with 413."""
        big = b"A" * (10 * 1024 * 1024 + 1)  # 10 MB + 1 byte
        data = {"file": (io.BytesIO(big), "huge.txt")}
        headers = {"Authorization": member_headers["Authorization"]}
        r = client.post(self.URL, headers=headers, data=data, content_type="multipart/form-data")
        assert r.status_code == 413

    def test_empty_file_body_400(self, client, member_headers):
        """Uploading a file with zero-length body is rejected."""
        data = {"file": (io.BytesIO(b""), "empty.txt")}
        headers = {"Authorization": member_headers["Authorization"]}
        r = client.post(self.URL, headers=headers, data=data, content_type="multipart/form-data")
        assert r.status_code == 400
        assert "Empty" in r.get_json()["error"]

    @patch("routes.files.FileMetadata")
    @patch("routes.files.encrypt_bytes")
    @patch("routes.files.sha256_hex")
    @patch("routes.files.os")
    def test_allowed_image_mime_201(self, m_os, m_sha, m_enc, m_fm, client, member_headers):
        """image/* MIME types pass the allowlist."""
        m_sha.return_value = "aabb"
        m_enc.return_value = b"enc"
        m_os.path.join.return_value = "/tmp/f.enc"
        m_os.O_WRONLY = 1; m_os.O_CREAT = 2; m_os.O_EXCL = 4
        m_os.open.return_value = 99
        m_os.fdopen.return_value.__enter__ = MagicMock()
        m_os.fdopen.return_value.__exit__ = MagicMock(return_value=False)
        fm = _make_file_meta()
        m_fm.return_value = fm
        # PNG file signature
        data = {"file": (io.BytesIO(b"\x89PNG\r\n\x1a\n" + b"x" * 100), "photo.png")}
        headers = {"Authorization": member_headers["Authorization"]}
        r = client.post(self.URL, headers=headers, data=data, content_type="multipart/form-data")
        assert r.status_code == 201

    @patch("routes.files.FileMetadata")
    @patch("routes.files.encrypt_bytes")
    @patch("routes.files.sha256_hex")
    @patch("routes.files.os")
    def test_allowed_pdf_mime_201(self, m_os, m_sha, m_enc, m_fm, client, member_headers):
        """application/pdf MIME type passes the allowlist."""
        m_sha.return_value = "ccdd"
        m_enc.return_value = b"enc"
        m_os.path.join.return_value = "/tmp/f.enc"
        m_os.O_WRONLY = 1; m_os.O_CREAT = 2; m_os.O_EXCL = 4
        m_os.open.return_value = 99
        m_os.fdopen.return_value.__enter__ = MagicMock()
        m_os.fdopen.return_value.__exit__ = MagicMock(return_value=False)
        fm = _make_file_meta()
        m_fm.return_value = fm
        data = {"file": (io.BytesIO(b"%PDF-1.4 test"), "doc.pdf")}
        headers = {"Authorization": member_headers["Authorization"]}
        r = client.post(self.URL, headers=headers, data=data, content_type="multipart/form-data")
        assert r.status_code == 201
