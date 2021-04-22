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
            
            cursor.execute('SELECT id,name,surname,third_name from employee;')
            employee = cursor.fetchall()
            
    return render_template('jobs.html', jobs=jobs, employee=employee)


@app.route('/contracts', methods=['GET'])
def contracts():
    conn = get_connection('bureau')
    with conn:
        with conn.cursor() as cursor:
            cursor.execute('CALL GET_CONTRACTS()')
            contracts = cursor.fetchall()
    return render_template('contracts.html', contracts=contracts)

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