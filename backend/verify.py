from passlib.context import CryptContext
pwd = CryptContext(schemes=['bcrypt'], deprecated='auto')
new_hash = pwd.hash('admin123')
print("Hash:", new_hash)
print("Verify:", pwd.verify('admin123', new_hash))

