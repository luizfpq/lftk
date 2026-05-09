import subprocess

def install_ldmtool():
    subprocess.run(['sudo', 'apt-get', 'install', 'ldmtool'])

def create_ldmtool_service():
    service_content = '''
[Unit]
Description=Windows Dynamic Disk Mount
Before=local-fs-pre.target
DefaultDependencies=no

[Service]
Type=simple
User=root
ExecStart=/usr/bin/ldmtool create all

[Install]
WantedBy=local-fs-pre.target
'''
    with open('/etc/systemd/system/ldmtool.service', 'w') as service_file:
        service_file.write(service_content)

def enable_ldmtool_service():
    subprocess.run(['sudo', 'systemctl', 'enable', 'ldmtool'])

def get_uuid():
    blkid_output = subprocess.run(['sudo', 'blkid'], capture_output=True, text=True)
    lines = blkid_output.stdout.splitlines()
    for line in lines:
        if '/dev/mapper/ldm_vol' in line:
            parts = line.split()
            for part in parts:
                if part.startswith('UUID='):
                    return part.split('=')[-1].strip('"')

def add_to_fstab(uuid):
    fstab_line = f'UUID={uuid} /media/main_data ntfs-3g auto,users,uid=1000,gid=100,dmask=027,fmask=137,utf8 0 0\n'
    with open('/etc/fstab', 'a') as fstab_file:
        fstab_file.write(fstab_line)

# Executando as etapas
install_ldmtool()
create_ldmtool_service()
enable_ldmtool_service()
uuid = get_uuid()
if uuid:
    add_to_fstab(uuid)
