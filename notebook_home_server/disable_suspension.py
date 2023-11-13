import subprocess

# Função para executar comandos do terminal e confirmar o sucesso
def run_command_with_confirmation(command, confirmation_message):
    try:
        subprocess.run(command, shell=True, check=True)
        print(f"Sucess: {confirmation_message}")
    except subprocess.CalledProcessError as e:
        print(f"Error: {confirmation_message}")
        print(e)

# Comandos a serem executados
commands = [
    ("echo 'HandleLidSwitch=ignore' | sudo tee -a /etc/systemd/logind.conf", "Adicionando configuração para ignorar fechamento da tampa"),
    ("sudo systemctl restart systemd-logind", "Restarting systemd-logind"),
    ("sudo systemctl daemon-reload", "Reloading systemd services"),
    ("sudo systemctl enable disable-lid-suspend.service", "Enabling disable-lig-suspend.service"),
]

# Executar os comandos e confirmar sucesso
for command, message in commands:
    run_command_with_confirmation(command, message)

print("Configuration OK.")
