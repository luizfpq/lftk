#!/usr/bin/env python3

import subprocess
import re
import socket
import os
import sys
import json

# Verifica se está rodando como root
if os.geteuid() != 0:
    print("Este script precisa ser executado como root (sudo).")
    sys.exit(1)

def obter_hostname():
    """Obtém o nome da máquina."""
    try:
        hostname = socket.gethostname().strip()
        print(f"Hostname detectado: {hostname}")
        return hostname
    except Exception as e:
        print(f"Erro ao obter hostname: {e}")
        sys.exit(1)

def extrair_numero_hostname(hostname):
    """
    Verifica se o hostname segue o padrão 'ironqui-<numero>'
    e extrai o número.
    """
    match = re.match(r"^ironqui-(\d+)$", hostname)
    if match:
        numero = int(match.group(1))
        print(f"Número extraído do hostname: {numero}")
        return numero
    else:
        print("Hostname não segue o padrão 'ironqui-<numero>'. Nada será feito.")
        sys.exit(0)

def obter_interface_padrao():
    """Obtém a interface de rede padrão (com rota para internet)."""
    try:
        result = subprocess.run(["ip", "route"], capture_output=True, text=True, check=True)
        for line in result.stdout.splitlines():
            if "default" in line:
                interface = re.search(r"dev\s+(\w+)", line)
                if interface:
                    iface = interface.group(1)
                    print(f"Interface de rede padrão: {iface}")
                    return iface
        print("Nenhuma interface padrão encontrada.")
        sys.exit(1)
    except Exception as e:
        print(f"Erro ao obter interface padrão: {e}")
        sys.exit(1)

def obter_info_interface(interface):
    """Obtém IP, máscara e gateway da interface atual."""
    try:
        result = subprocess.run(["ip", "addr", "show", interface], capture_output=True, text=True, check=True)
        lines = result.stdout.splitlines()

        ip_info = None
        for line in lines:
            # Procura por IP no formato IPv4
            match = re.search(r"inet (\d+\.\d+\.\d+\.\d+)/(\d+)", line)
            if match:
                ip_atual = match.group(1)
                mascara = match.group(2)
                # Extrai os primeiros 3 octetos
                rede_base = ".".join(ip_atual.split(".")[:3])
                ip_info = {
                    "ip": ip_atual,
                    "mask": mascara,
                    "network": rede_base
                }
                break

        if not ip_info:
            print(f"Não foi possível obter IP para a interface {interface}.")
            sys.exit(1)

        # Gateway
        try:
            gw_result = subprocess.run(["ip", "route"], capture_output=True, text=True, check=True)
            for line in gw_result.stdout.splitlines():
                if "default" in line and f"dev {interface}" in line:
                    gateway_match = re.search(r"via (\d+\.\d+\.\d+\.\d+)", line)
                    if gateway_match:
                        ip_info["gateway"] = gateway_match.group(1)
                        break
            else:
                ip_info["gateway"] = None
        except:
            ip_info["gateway"] = None

        # DNS - tenta obter via systemd-resolve ou /etc/resolv.conf
        dns_list = []
        try:
            # Tenta usar resolvectl
            resolve_result = subprocess.run(["resolvectl", "dns", interface], capture_output=True, text=True)
            if resolve_result.returncode == 0:
                dns_line = resolve_result.stdout.strip()
                dns_ips = re.findall(r"\b(?:\d{1,3}\.){3}\d{1,3}\b", dns_line)
                dns_list.extend(dns_ips)
        except FileNotFoundError:
            pass  # resolvectl não disponível

        # Fallback: ler /etc/resolv.conf
        if not dns_list:
            try:
                with open("/etc/resolv.conf", "r") as f:
                    for line in f:
                        if line.startswith("nameserver"):
                            dns_ip = line.split()[1]
                            dns_list.append(dns_ip)
            except:
                pass

        ip_info["dns"] = dns_list if dns_list else ["8.8.8.8", "8.8.4.4"]  # fallback

        return ip_info

    except Exception as e:
        print(f"Erro ao obter informações da interface: {e}")
        sys.exit(1)

def detectar_metodo_rede():
    """
    Detecta se o sistema usa netplan, ifupdown (/etc/network/interfaces) ou outro.
    """
    if os.path.exists("/etc/netplan"):
        netplan_files = [f for f in os.listdir("/etc/netplan") if f.endswith(".yaml") or f.endswith(".yml")]
        if netplan_files:
            return "netplan", netplan_files[0]
    if os.path.exists("/etc/network/interfaces"):
        return "interfaces", None
    print("Não foi possível detectar o método de rede (netplan ou interfaces).")
    sys.exit(1)

def configurar_netplan(interface, nova_config):
    """
    Atualiza o arquivo netplan com o IP estático.
    """
    netplan_dir = "/etc/netplan"
    netplan_file = None
    for f in os.listdir(netplan_dir):
        if f.endswith(".yaml") or f.endswith(".yml"):
            netplan_file = os.path.join(netplan_dir, f)
            break

    if not netplan_file:
        print("Arquivo netplan .yaml não encontrado.")
        sys.exit(1)

    print(f"Editando netplan: {netplan_file}")

    try:
        with open(netplan_file, "r") as f:
            conteudo = f.read()

        # Faz backup
        backup = netplan_file + ".backup"
        subprocess.run(["cp", netplan_file, backup])
        print(f"Backup do netplan salvo em: {backup}")

        # Usamos regex para modificar a seção da interface
        # Procuramos algo como: eth0:, ou ens33:, etc.
        pattern = rf"(\s+{re.escape(interface)}:\s*\n(?:\s+.+\n)*)"
        match = re.search(pattern, conteudo)

        if not match:
            print(f"Interface {interface} não encontrada no netplan.")
            sys.exit(1)

        # Nova configuração para a interface
        nova_secao = f'''{interface}:
          dhcp4: false
          addresses:
            - {nova_config['ip']}/{nova_config['mask']}
          routes:
            - to: default
              via: {nova_config['gateway']}
          nameservers:
            addresses: {nova_config['dns']}'''

        # Substitui a seção antiga
        conteudo_mod = re.sub(
            rf"(\s+{re.escape(interface)}:\s*\n(?:\s+.+\n)*)",
            f"      {nova_secao}\n",
            conteudo
        )

        # Escreve o novo arquivo
        with open(netplan_file, "w") as f:
            f.write(conteudo_mod)

        print("Arquivo netplan atualizado com sucesso.")
        print("Aplicando configuração com 'netplan apply'...")
        subprocess.run(["netplan", "apply"], check=True)
        print("Configuração de rede aplicada com sucesso.")

    except Exception as e:
        print(f"Erro ao configurar netplan: {e}")
        sys.exit(1)

def configurar_interfaces(interface, nova_config):
    """
    Configura /etc/network/interfaces (para sistemas com ifupdown).
    """
    interfaces_file = "/etc/network/interfaces"
    backup_file = interfaces_file + ".backup"

    try:
        subprocess.run(["cp", interfaces_file, backup_file], check=True)
        print(f"Backup de /etc/network/interfaces salvo em: {backup_file}")

        with open(interfaces_file, "r") as f:
            linhas = f.readlines()

        # Procurar pela interface
        idx = None
        for i, linha in enumerate(linhas):
            if linha.strip().startswith(f"iface {interface}"):
                idx = i
                break

        if idx is None:
            print(f"Interface {interface} não configurada em /etc/network/interfaces. Adicionando...")
            linhas.append(f"\nauto {interface}\n")
            linhas.append(f"iface {interface} inet static\n")
            linhas.append(f"    address {nova_config['ip']}\n")
            linhas.append(f"    netmask {'/'.join(['255.255.255.0', '24'][int(nova_config['mask'])])}\n")
            if nova_config['gateway']:
                linhas.append(f"    gateway {nova_config['gateway']}\n")
            dns_str = ", ".join(nova_config['dns'])
            linhas.append(f"    dns-nameservers {dns_str}\n")
        else:
            # Substituir configuração existente
            novas_linhas = [
                f"auto {interface}\n",
                f"iface {interface} inet static\n",
                f"    address {nova_config['ip']}\n",
                f"    netmask {'255.255.255.0' if nova_config['mask'] == '24' else '/'.join(['255.255.255.0', '24'][int(nova_config['mask'])])}\n"
            ]
            if nova_config['gateway']:
                novas_linhas.append(f"    gateway {nova_config['gateway']}\n")
            dns_str = ", ".join(nova_config['dns'])
            novas_linhas.append(f"    dns-nameservers {dns_str}\n")

            # Encontra o fim da configuração atual
            end_idx = idx + 1
            while end_idx < len(linhas) and linhas[end_idx].startswith("    "):
                end_idx += 1

            linhas[idx:end_idx] = novas_linhas

        with open(interfaces_file, "w") as f:
            f.writelines(linhas)

        print("/etc/network/interfaces atualizado.")
        print("Reiniciando rede...")
        subprocess.run(["systemctl", "restart", "networking"], check=True)
        print("Rede reiniciada com sucesso.")

    except Exception as e:
        print(f"Erro ao configurar /etc/network/interfaces: {e}")
        sys.exit(1)

def main():
    hostname = obter_hostname()
    numero = extrair_numero_hostname(hostname)

    interface = obter_interface_padrao()
    info_atual = obter_info_interface(interface)

    # Novo IP: manter os 3 primeiros octetos + número do hostname
    novo_ip = f"{info_atual['network']}.{numero}"
    print(f"Novo IP calculado: {novo_ip}")

    # Evita mudar se já estiver correto
    if info_atual['ip'] == novo_ip:
        print("O IP já está configurado corretamente. Nada a fazer.")
        sys.exit(0)

    # Nova configuração
    nova_config = {
        "ip": novo_ip,
        "mask": info_atual["mask"],
        "gateway": info_atual["gateway"],
        "dns": info_atual["dns"]
    }

    print(f"Nova configuração de rede: {nova_config}")

    metodo, arquivo = detectar_metodo_rede()
    print(f"Método de rede detectado: {metodo}")

    if metodo == "netplan":
        configurar_netplan(interface, nova_config)
    elif metodo == "interfaces":
        configurar_interfaces(interface, nova_config)

if __name__ == "__main__":
    main()
