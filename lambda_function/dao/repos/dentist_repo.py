from dao.db_connect import MySQLConnection


class DentistRepo:

    def __init__(self, sqlEngine: MySQLConnection = None):
        self.sqlEngine = sqlEngine

    def get_user(self):
        get_user_sql = """
            SELECT user_name FROM `user` WHERE user_id = 1
        """
        return self.sqlEngine.read_one(get_user_sql, None)
