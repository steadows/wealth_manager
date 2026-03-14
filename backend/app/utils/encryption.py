"""Fernet-based encryption for sensitive data at rest."""

from cryptography.fernet import Fernet, InvalidToken

__all__ = ["decrypt_value", "encrypt_value", "InvalidToken"]


def encrypt_value(plaintext: str, key: str) -> str:
    """Encrypt a string value. Returns base64-encoded ciphertext.

    Args:
        plaintext: The value to encrypt.
        key: A Fernet key (base64-encoded 32-byte key).

    Returns:
        Base64-encoded ciphertext string.
    """
    f = Fernet(key.encode() if isinstance(key, str) else key)
    return f.encrypt(plaintext.encode()).decode()


def decrypt_value(ciphertext: str, key: str) -> str:
    """Decrypt a Fernet-encrypted value.

    Args:
        ciphertext: The base64-encoded ciphertext to decrypt.
        key: The Fernet key used for encryption.

    Returns:
        The original plaintext string.

    Raises:
        InvalidToken: If the key is wrong or the ciphertext is corrupted.
    """
    f = Fernet(key.encode() if isinstance(key, str) else key)
    return f.decrypt(ciphertext.encode()).decode()
