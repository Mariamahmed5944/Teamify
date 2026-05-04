"""Print a fresh Fernet key. Add the output to your .env as FERNET_KEY=<value>."""
from cryptography.fernet import Fernet

if __name__ == "__main__":
    print(Fernet.generate_key().decode())
