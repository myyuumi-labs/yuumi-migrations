SELECT 'CREATE DATABASE billerdb'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'billerdb')\gexec
