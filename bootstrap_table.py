import csv
import subprocess
import paramiko
import re
from flask import Flask, render_template, send_file, request, flash
from flask_sqlalchemy import SQLAlchemy
from waitress import serve
from datetime import datetime as dt, datetime
from sqlalchemy import DateTime

app = Flask(__name__)
app.config['SQLALCHEMY_DATABASE_URI'] = 'sqlite:///db.sqlite'
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False
db = SQLAlchemy(app)


class User(db.Model):
    id = db.Column(db.INTEGER, primary_key=True)
    ip_address = db.Column(db.TEXT)
    wrs_name = db.Column(db.TEXT)
    MAC = db.Column(db.TEXT)
    user = db.Column(db.TEXT)
    departments = db.Column(db.TEXT)
    mthb = db.Column(db.TEXT)
    cpu = db.Column(db.TEXT)
    ram = db.Column(db.TEXT)
    video = db.Column(db.TEXT)
    displays = db.Column(db.TEXT)
    hdd = db.Column(db.INTEGER)
    os_version = db.Column(db.TEXT)
    nomachine = db.Column(db.TEXT)
    date_time = db.Column(db.TEXT, default=datetime.utcnow)
    additional_info = db.Column(db.TEXT)


db.create_all()


@app.route('/')
def index():
    users = User.query
    return render_template('bootstrap_table.html', title='CGF',
                           users=users)


with open('data.csv', 'w', newline='') as file:
    writer = csv.writer(file)
    writer.writerow(['ip', 'ip_address', 'wrs_name', 'MAC', 'user', 'departments', 'mthb', 'cpu', 'ram', 'video',
                     'displays', 'hdd', 'os_version', 'nomachine', 'date_time', 'additional_info'])
    for i in User.query:
        writer.writerow(
            [i.id, i.ip_address, i.wrs_name, i.MAC, i.user, i.departments, i.mthb, i.cpu, i.ram, i.video, i.displays,
             i.hdd, i.os_version, i.nomachine, i.date_time, i.additional_info])


@app.route('/download_file')
def download_file():
    p = 'data.csv'
    return send_file(p, as_attachment=True)


@app.route('/update/<int:_id>', methods=['POST', 'GET'])
def update(_id):
    users = User.query
    form = User()
    name_update = User.query.get_or_404(_id)
    if request.method == 'POST':
        name_update.add_information = request.form['add_information']
        try:
            db.session.commit()
            return render_template('bootstrap_table.html', form=form, name_update=name_update, users=users)
        except:
            flash('ERROR! Try again')
            return render_template('bootstrap_table.html', form=form, name_update=name_update, users=users)
    else:
        return render_template('bootstrap_table.html', form=form, name_update=name_update, users=users)


# command = ["df", "-h"]
# res = subprocess.check_output(command)
# output = str(res)
# my_file = open("otus.txt", "w")
# my_file.write(output)
# my_file.close()
# print(output, sep='\n')
def pars():
    client = paramiko.SSHClient()
    client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    client.connect(hostname="192.168.46.128", username="d.samojlov", password="Asuuqb08")
    stdin, stout, stderr = client.exec_command("/home/users/d.samojlov/sandbox/whi_2.0/inspect_hw.sh")
    res = stout.read().decode("UTF-8")
    result = res.replace("\t", "").replace("\r", "").split("\n")
    client.close()
    d = {key: value for key, value in re.findall(r'(.*)\t(.*)', res)}
    
    print(d)

pars()


class Riteuser():
    def __init__(self, Wrs, user, Mthb, CPU, RAM, Video, Display, HDD, MAC, Displays, OS, NOMACHINE):
        self.Wrs = Wrs
        self.user = user
        self.Mthb = Mthb
        self.CPU = CPU
        self.RAM = RAM
        self.Video = Video
        self.Display = Display
        self.HDD = HDD
        self.MAC = MAC
        self.Displays = Displays
        self.OS = OS
        self.NOMACHINE = NOMACHINE


if __name__ == "__main__":
    # app.run('0.0.0.0',port=server_port)

    serve(app, host='0.0.0.0', port=5000)
    test_user = Riteuser(Wrs='wrslnx128', user='d.samojlov', Mthb='', CPU=' 8 x Intel Core i7-4790K @ 4.00GHz',
                         RAM=' 0  GB', Video=' GeForce GTX 960', Display=' N/A', HDD='1: internal hard drive Hitachi '
                                                                                     'HUA722020ALA330 (2000 GB) '
                                                                                     'SmartFailing: false 1403 bad '
                                                                                     'sectors 3520.5 days',
                         MAC='02:42:44:63:dc:c7 02:42:55:2b:e7:2c 02:42:d1:76:3d:f2 02:42:31:bb:f0:7e',
                         Displays='PSU_EMULATOR', OS=' Debian GNU/Linux_10', NOMACHINE='└─10597 /usr/NX/bin/nxserver'
                                                                                       '.bin -c /etc/NX/nxserver '
                                                                                       '--login -H 5')
