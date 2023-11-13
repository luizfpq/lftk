import subprocess


# Função para executar comandos do terminal e confirmar o sucesso
def run_command_with_confirmation(command, confirmation_message):
    try:
        subprocess.run(command, shell=True, check=True)
        print(f"Sucess: {confirmation_message}")
    except subprocess.CalledProcessError as e:
        print(f"Error: {confirmation_message}")
        print(e)


# Content for disable-lid-suspend.service
content = '''[Unit]
Description=Disable Lid Suspend

[Service]
Type=oneshot
ExecStart=/bin/bash -c 'echo "HandleLidSwitch=ignore" >> /etc/systemd/logind.conf'
ExecStart=/bin/systemctl restart systemd-logind

[Install]
WantedBy=multi-user.target
'''

# Command list
commands = [
    ("echo 'HandleLidSwitch=ignore' | sudo tee -a /etc/systemd/logind.conf",
     "Add:HandleLidSwitch=ignore -> logind.conf"),
    ("sudo touch /etc/systemd/system/disable-lid-suspend.service",
     "Creating: disable-lid-suspend.service"),
    ("echo {} | sudo tee -a /etc/systemd/system/disable-lid-suspend.service",
     "Add: content -> disable-lid-suspend.service".format(content)),
    ("sudo systemctl restart systemd-logind", "Restarting systemd-logind"),
    ("sudo systemctl daemon-reload", "Reloading systemd services"),
    ("sudo systemctl enable disable-lid-suspend.service", "Enabling disable-lig-suspend.service"),
]

# Executar os comandos e confirmar sucesso
for command, message in commands:
    run_command_with_confirmation(command, message)

print("Configuration OK.")
