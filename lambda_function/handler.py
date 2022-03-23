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
    # build base json output
    returnJson = {
        'statusCode': None,
        'headers': {
            'Access-Control-Allow-Methods': 'OPTIONS,GET,POST',
            'Access-Control-Allow-Headers': 'Content-Type',
            'Access-Control-Allow-Origin': '*',
            'Content-Type': 'application/json',
        },
        'body': ''
    }
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
                returnJson['statusCode'] = 200
                returnJson['body'] = json.dumps(result, default=str)
            return returnJson
        if event.http_method == 'POST':
            logger.info('request to set appointment')
            request_body = json.loads(event.body)
            with MySQLConnection() as sqlEngine:
                dentist_repo = DentistRepo(sqlEngine)
                result = dentist_repo.set_appointment(username, request_body)
                returnJson['statusCode'] = 201
                returnJson['body'] = json.dumps({'verificationNumber': str(result)})
            return returnJson
    except custom_exceptions.DBException as e:
        print(e.build_error())
        return e.build_error()
    except custom_exceptions.UserNotFound as e:
        print(e.build_error())
        return e.build_error()
    except custom_exceptions.NotAllowed as e:
        print(e.build_error())
        return e.build_error()

