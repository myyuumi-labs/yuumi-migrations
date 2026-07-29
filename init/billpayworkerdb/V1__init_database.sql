SELECT 'CREATE DATABASE billpayworkerdb'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'billpayworkerdb')\gexec
