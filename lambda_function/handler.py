import json
import logging

from utils import custom_exceptions

logger = logging.getLogger()
logger.setLevel(logging.INFO)

from dao.db_connect import MySQLConnection
from dao.repos.dentist_repo import DentistRepo
from aws_lambda_powertools.utilities.data_classes import event_source, APIGatewayProxyEvent


@event_source(data_class=APIGatewayProxyEvent)
def lambda_handler(event: APIGatewayProxyEvent, context):
    try:
        logger.info(json.dumps(event.__dict__))
        # get the user making the api call
        request_context = event.request_context
        authorizer = request_context.authorizer
        claims = authorizer.claims
        username = claims.get('username')
        # route based on http method
        if event.http_method == 'GET':
            logger.info('getting appointments for %s' % username)
            with MySQLConnection() as sqlEngine:
                dentist_repo = DentistRepo(sqlEngine)
                result = dentist_repo.get_appointments(username)
            return {
                'statusCode': 200,
                'headers': {
                    'Access-Control-Allow-Methods': 'OPTIONS,POST',
                    'Access-Control-Allow-Headers': 'Content-Type',
                    'Access-Control-Allow-Origin': '*',
                    'Content-Type': 'application/json',
                },
                'body': json.dumps(result, default=str)
            }
        if event.http_method == 'POST':
            return {
                'statusCode': 201,
                'headers': {
                    'Access-Control-Allow-Methods': 'OPTIONS,POST',
                    'Access-Control-Allow-Headers': 'Content-Type',
                    'Access-Control-Allow-Origin': '*',
                    'Content-Type': 'application/json',
                },
                'body': json.dumps({'code': username})
            }
    except custom_exceptions.DBException as e:
        print(e.build_error())
        return e.build_error()
    except custom_exceptions.UserNotFound as e:
        print(e.build_error())
        return e.build_error()

