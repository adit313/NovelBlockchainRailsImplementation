MAX_BLOCK_TRANSACTIONS = 10.freeze
BLOCK_DIFFICULTY = 1 #defined as the number of hexadecimal zeros at the begining of the hash
COMMIT_NODE_KEY = OpenSSL::PKey.read File.read "storage/private_key.pem"
COMMIT_NODE_ADDRESS = Digest::SHA256.base64digest(key2.public_key.to_s)
