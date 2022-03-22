import json


# Base class for custom exceptions, call super() to create custom error response
class CustomError(Exception):
    def __init__(self, status_code, error_message):
        self.status_code = status_code
        self.error_message = error_message

    def build_error(self):
        error = {
            'statusCode': self.status_code,
            'headers': {
                'Access-Control-Allow-Methods': 'OPTIONS,GET,POST,PUT,DELETE',
                'Access-Control-Allow-Headers': 'Content-Type',
                'Access-Control-Allow-Origin': '*',
                'Content-Type': 'application/json',
            },
            'body': json.dumps({
                'statusCode': self.status_code,
                'error': self.error_message
            })
        }
        return error


class DBException(CustomError):
    def __init__(self, i):
        super().__init__(500, 'Internal exception %s' % i)


class UserNotFound(CustomError):
    def __init__(self):
        super().__init__(404, 'User not found')
