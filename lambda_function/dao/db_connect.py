import json

import botocore
import botocore.session
import pymysql
from aws_secretsmanager_caching import SecretCacheConfig, SecretCache

from utils import custom_exceptions


class MySQLConnection(object):

    def __init__(self):
        client = botocore.session.get_session().create_client('secretsmanager')
        cacheConfig = SecretCacheConfig()
        cache = SecretCache(config=cacheConfig, client=client)
        secret = json.loads(cache.get_secret_string('arn:aws:secretsmanager:us-east-1:138874394754:secret:db_creds-b0KQSg'))
        host = secret['host']
        port = secret['port']
        user = secret['username']
        password = secret['password']
        db = secret['database']

        self.connection = pymysql.connect(host=host, port=port, user=user, password=password, db=db)

    def __enter__(self):
        return self

    def __exit__(self, theType, value, traceback):
        self.connection.close()

    def read_one(self, sql, params):
        cursor = self.connection.cursor(pymysql.cursors.DictCursor)
        try:
            cursor.execute(sql, params)
            result = cursor.fetchone()
            return result
        except Exception as e:
            print('Read error')
            print(cursor._last_executed)
            raise custom_exceptions.DBException(e)

    def read_all(self, sql, params):
        cursor = self.connection.cursor(pymysql.cursors.DictCursor)
        try:
            cursor.execute(sql, params)
            result = cursor.fetchall()
            return result
        except Exception as e:
            print('Read error')
            print(cursor._last_executed)
            raise custom_exceptions.DBException(e)

    def write_and_return_key(self, sql, params):
        cursor = self.connection.cursor()
        try:
            cursor.execute(sql, params)
            entry_key = cursor.lastrowid
            self.connection.commit()
            return entry_key
        except Exception as e:
            print('Write error')
            print(e)
            raise custom_exceptions.DBException(e)

    def update(self, sql, params):
        cursor = self.connection.cursor()
        try:
            cursor.execute(sql, params)
            self.connection.commit()
        except Exception as e:
            print('Update error')
            print(e)
            raise custom_exceptions.DBException(e)

    def delete(self, sql, params):
        cursor = self.connection.cursor()
        try:
            cursor.execute(sql, params)
            self.connection.commit()
        except Exception as e:
            print('Delete error')
            print(e)
            raise custom_exceptions.DBException(e)
