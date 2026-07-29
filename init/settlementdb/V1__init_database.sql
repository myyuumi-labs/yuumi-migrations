SELECT 'CREATE DATABASE settlementdb'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'settlementdb')\gexec
