import json
import pymysql
from dao.db_connect import MySQLConnection
from dao.repos.dentist_repo import DentistRepo


def lambda_handler(event, context):
    print(event)
    with MySQLConnection() as sqlEngine:
        dentist_repo = DentistRepo(sqlEngine)
        result = dentist_repo.get_user()
        return {
            'statusCode': 200,
            'headers': {
                'Access-Control-Allow-Methods': 'OPTIONS,POST',
                'Access-Control-Allow-Headers': 'Content-Type',
                'Access-Control-Allow-Origin': '*',
                'Content-Type': 'application/json',
            },
            'body': json.dumps({'code': str(result)})
        }
