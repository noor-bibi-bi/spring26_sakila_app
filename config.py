
# Name: Noor Bibi + Ahmad Khan
# Date: 2026-04-24
# Feature:  Combined Configurations (Update + Health Check)

import os

class Config:
    # Configuration refined after PR review feedback
    MYSQL_HOST = os.environ.get('MYSQL_HOST', 'sakila-db-server')
    CONNECTION_TIMEOUT = int(os.environ.get('CONNECTION_TIMEOUT', '30'))
    HEALTH_CHECK_INTERVAL = int(os.environ.get('HEALTH_CHECK_INTERVAL', '10'))
    MYSQL_USER = os.environ.get('MYSQL_USER', 'root')
    MYSQL_PASSWORD = os.environ.get('MYSQL_PASSWORD', 'admin')
    MYSQL_DB = os.environ.get('MYSQL_DB', 'sakila')
    SECRET_KEY = os.environ.get('SECRET_KEY', 'your-secret-key-here-change-this-in-production')
        