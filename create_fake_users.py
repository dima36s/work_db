import sys
from bootstrap_table import db, User


def create_fake_users(n):
    """Generate fake users."""

    for i in range(n):
        user = User(ip_address='192.168.45.101', wrs_name='WRSWIN5101', MAC='2C:4D:54:50:2B:A6', user='a.mishenin',
                    departments='Shot', mthb='ASUSeKCOMPUTERINC.Z170-K', cpu='Intel(R)Code(TM)i7-6700KCPU', ram='32 GB',
                    video='GrForceCGTX10603GB', displays='unknown', hdd='72%', os_version='Windows 10.0.17132',
                    nomachine='not used', additional_info='')
        db.session.add(user)
    db.session.commit()
    print(f'Added {n} fake users to the database.')


if __name__ == '__main__':
    create_fake_users(4)
    print('Pass the number of users you want to create as an argument.')
    sys.exit(1)
