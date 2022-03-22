from dao.db_connect import MySQLConnection
import logging

from utils import custom_exceptions

logger = logging.getLogger()
logger.setLevel(logging.INFO)


class DentistRepo:

    def __init__(self, sqlEngine: MySQLConnection = None):
        self.sqlEngine = sqlEngine

    def get_appointments(self, username: str):
        # get the user's id and type to query the appointments
        get_user_data_sql = """
            SELECT user_id, description
            FROM `user`
            JOIN user_type ON `user`.user_type = user_type.user_type_id
            WHERE user_name = %s
        """
        user_data = self.sqlEngine.read_one(get_user_data_sql, username)

        # a user's type should always be defined
        if user_data is None:
            logger.error('%s user not found' % username)
            raise custom_exceptions.UserNotFound
        else:
            # link the type to the field to search on appointments
            if user_data.get('description') == "PATIENT":
                appointment_table_fk = 'patient_id'
            elif user_data.get('description') == "DOCTOR":
                appointment_table_fk = 'doctor_id'
            elif user_data.get('description') == "RECEPTIONIST":
                appointment_table_fk = 'receptionist_id'
            else:
                logger.error('%s user not found' % username)
                raise custom_exceptions.UserNotFound

        # get appointments based on user
        get_appointments_sql = """
            SELECT d_user.user_name AS doctor, r_user.user_name AS receptionist, 
                p_user.user_name AS patient, appointment_date
            FROM appointment
                JOIN `user` d_user ON doctor_id = d_user.user_id
                JOIN `user` r_user ON receptionist_id = r_user.user_id
                JOIN `user` p_user ON patient_id = p_user.user_id
            WHERE """ + appointment_table_fk + """ = %s
        """
        parameters = (user_data.get('user_id'))
        appointment_data = self.sqlEngine.read_all(get_appointments_sql, parameters)
        return appointment_data

    # todo!
    def set_appointment(self):
        logger.info('setting appointment')
