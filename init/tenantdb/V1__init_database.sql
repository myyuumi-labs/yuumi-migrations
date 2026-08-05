SELECT 'CREATE DATABASE tenantdb'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'tenantdb')\gexec
