import sys
import os
from pathlib import Path
from fastapi.testclient import TestClient

# Add the 'brain' directory to sys.path
# Current file is in deploy/tests/, brain.py is in deploy/brain/
current_dir = Path(__file__).resolve().parent
brain_dir = current_dir.parent / "brain"
sys.path.append(str(brain_dir))

from brain import app

client = TestClient(app)

def test_read_root_unauthorized():
    """Test that the root endpoint requires authentication."""
    response = client.get("/")
    assert response.status_code == 401
    assert "WWW-Authenticate" in response.headers

def test_read_root_authorized():
    """Test that the root endpoint works with correct credentials."""
    response = client.get("/", auth=("admin", "admin"))
    assert response.status_code == 200
    assert "text/html" in response.headers["content-type"]

def test_read_root_bad_password():
    """Test that the root endpoint rejects bad passwords."""
    response = client.get("/", auth=("admin", "wrongpassword"))
    assert response.status_code == 401

def test_boot_ipxe_public():
    """Test that the boot script is public and accessible."""
    response = client.get("/boot.ipxe")
    assert response.status_code == 200
    assert "#!ipxe" in response.text

def test_api_config_protected():
    """Test that the config API is protected."""
    response = client.get("/api/config")
    assert response.status_code == 401
    
    response = client.get("/api/config", auth=("admin", "admin"))
    assert response.status_code == 200
    data = response.json()
    assert "server_ip" in data
    # Ensure password is part of the model (or hidden? API returns what load_config returns)
    # The default config now has admin_password, so it might be returned.
    # In a real app we might hide it, but for now we check it matches default or loaded.

def test_api_assets_protected():
    """Test that the assets API is protected."""
    response = client.get("/api/assets")
    assert response.status_code == 401
    
    response = client.get("/api/assets", auth=("admin", "admin"))
    assert response.status_code == 200
    data = response.json()
    assert "isos" in data
    assert "vhds" in data
