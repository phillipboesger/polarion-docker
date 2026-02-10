#!/bin/bash
# Start PostgreSQL database
sudo -u postgres /usr/lib/postgresql/16/bin/pg_ctl -D /opt/polarion/data/postgres-data -l /opt/polarion/data/postgres-data/log.out -o "-p 5433" start
