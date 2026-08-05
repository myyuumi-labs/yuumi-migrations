SELECT 'CREATE DATABASE accountdb'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'accountdb')\gexec
