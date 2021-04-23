import pymysql
import pymysql.cursors
from flask import Flask, render_template, request, jsonify
from pymysql.constants import CLIENT

def get_connection(db_name):
    connection = pymysql.connect(host='127.0.0.1',
                                 user='root',
                                 db=db_name,
                                 charset='utf8mb4',
                                 client_flag=CLIENT.MULTI_STATEMENTS,
                                 cursorclass=pymysql.cursors.DictCursor)
    return connection
    
    
app = Flask(__name__)

@app.route('/', methods=['GET'])
def main():
    return render_template('index.html')
    
@app.route('/jobs', methods=['GET'])
def jobs():
    conn = get_connection('bureau')
    with conn:
        with conn.cursor() as cursor:
            cursor.execute('SELECT * FROM GET_JOBS')
            jobs = cursor.fetchall()
            
            cursor.execute('SELECT id,name from employer;')
            employer = cursor.fetchall()
            
            cursor.execute('SELECT id,name,surname,third_name from employee;')
            employee = cursor.fetchall()
            
    return render_template('jobs.html', jobs=jobs, employer=employer, employee=employee)


@app.route('/contracts', methods=['GET'])
def contracts():
    conn = get_connection('bureau')
    with conn:
        with conn.cursor() as cursor:
            cursor.execute('CALL GET_CONTRACTS()')
            contracts = cursor.fetchall()
    return render_template('contracts.html', contracts=contracts)

@app.route('/postVacancy', methods=['POST'])
def postVacancy():
    if request and request.json:
        emid = request.json['emid']
        jname = request.json['jname']
        exp = request.json['exp']
        sal = request.json['sal']
        
        
        
        conn = get_connection('bureau')
        with conn:
            with conn.cursor() as cursor:
                try:
                    cursor.execute('CALL CREATE_VACANCY_API(%s, %s, %s, %s)', (emid, jname, exp, sal))
                    conn.commit()
                except pymysql.err.OperationalError:
                    return '', 403
    return jsonify('ok')
    
@app.route('/postEmployer', methods=['POST'])
def postEmployer():
    if request and request.json:
        ename = request.json['ename']
        address = request.json['address']
        phone_number = request.json['phone_number']
        
        
        
        conn = get_connection('bureau')
        with conn:
            with conn.cursor() as cursor:
                cursor.execute('INSERT INTO employer (name, address, phone_number) VALUES (%s, %s, %s)', (ename, address, phone_number))
                conn.commit()
    return jsonify('ok')

@app.route('/fileJob', methods=['POST'])
def fileJob():
    if request and request.json:
        ename = request.json['ename']
        id = request.json['id']
        job = request.json['job']
        com = request.json['com']
        
        
        
        conn = get_connection('bureau')
        with conn:
            with conn.cursor() as cursor:
                cursor.execute('CALL CREATE_CONTRACT(%s, %s, %s, %s)', (ename, id, job, com))
                conn.commit()
    return jsonify('ok')
    
@app.route('/delContract', methods=['POST'])
def delContract():
    if request and request.json:
        cid = request.json['id']
        
        conn = get_connection('bureau')
        with conn:
            with conn.cursor() as cursor:
                
                try:
                    cursor.execute('DELETE FROM CONTRACT WHERE id = %s', (cid))
                    conn.commit()
                except pymysql.err.OperationalError:
                    return '', 403
    return jsonify('ok')
    
@app.route('/payContract', methods=['POST'])
def payContract():
    if request and request.json:
        cid = request.json['id']
        
        conn = get_connection('bureau')
        with conn:
            with conn.cursor() as cursor:
                cursor.execute('UPDATE CONTRACT SET payed=TRUE  WHERE id = %s', (cid))
                conn.commit()
    return jsonify('ok')

if __name__ == '__main__':
    app.run(debug=True)