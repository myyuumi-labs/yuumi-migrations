SELECT 'CREATE DATABASE accountsdb'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'accountsdb')\gexec
