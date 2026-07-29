SELECT 'CREATE DATABASE customerdb'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'customerdb')\gexec
