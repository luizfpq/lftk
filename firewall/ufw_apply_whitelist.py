#!/usr/bin/env python3
"""
ufw_apply_whitelist.py

Uso:
  sudo ./ufw_apply_whitelist.py ips.txt ports.txt

Comportamento:
- Faz backup de /etc/ufw/user.rules e user6.rules
- Remove regras ALLOW existentes que liberem as portas listadas para IPs NÃO presentes no arquivo de ips (modo "exclusivo")
- Adiciona regras "ufw allow from <IP> to any port <PORT> [proto <proto>]" para cada IP x PORT
- Recarrega o ufw e exibe o status

Observações:
- Requer root (sudo).
- Testado em Ubuntu com ufw padrão.
"""
import sys
import os
import re
import subprocess
from datetime import datetime
from ipaddress import ip_address, AddressValueError

def run(cmd, capture=False):
    if capture:
        return subprocess.check_output(cmd, shell=True, stderr=subprocess.STDOUT).decode('utf-8', errors='replace')
    else:
        return subprocess.call(cmd, shell=True)

def fatal(msg):
    print("ERROR:", msg)
    sys.exit(1)

def read_lines(path):
    out = []
    with open(path, 'r', encoding='utf-8') as f:
        for raw in f:
            line = raw.split('#',1)[0].strip()
            if not line:
                continue
            out.append(line)
    return out

def parse_port_spec(spec):
    """
    Aceita: '80', '443/tcp', '53/udp', '1000:2000'
    Retorna (port_literal, proto_or_None)
    """
    spec = spec.strip()
    if '/' in spec:
        port, proto = spec.split('/',1)
        return port, proto.lower()
    else:
        # se range com ':', devolve sem proto
        if ':' in spec:
            return spec, None
        # single port
        return spec, None

def backup_ufw():
    now = datetime.utcnow().strftime('%Y%m%dT%H%M%SZ')
    bak_dir = f"/etc/ufw/backup_{now}"
    try:
        os.makedirs(bak_dir, exist_ok=True)
        for fname in ("user.rules", "user6.rules"):
            src = f"/etc/ufw/{fname}"
            if os.path.exists(src):
                dst = os.path.join(bak_dir, fname)
                subprocess.check_call(f"cp -a '{src}' '{dst}'", shell=True)
        print(f"[+] Backup salvo em {bak_dir}")
    except Exception as e:
        fatal(f"Falha ao criar backup de UFW: {e}")

def ufw_status_numbered():
    try:
        out = run("ufw status numbered", capture=True)
        return out.splitlines()
    except subprocess.CalledProcessError as e:
        return []

def parse_status_numbered_lines(lines):
    """
    Retorna lista de dicts: {num:int, raw:str, rule_text:str}
    Exemplo de linha:
    "[ 1] 22/tcp                   ALLOW IN    Anywhere"
    """
    items = []
    pattern = re.compile(r'^\[\s*(\d+)\]\s+(.*)$')
    for ln in lines:
        m = pattern.match(ln)
        if m:
            num = int(m.group(1))
            rule_text = m.group(2).strip()
            items.append({'num': num, 'raw': ln, 'rule': rule_text})
    return items

def rule_contains_port(rule_text, port_literal):
    # Checks if rule_text contains the port literal in forms like "80/tcp" or "port 80"
    # We do a few heuristics
    if f"{port_literal}/" in rule_text:
        return True
    if re.search(r'\bport\s+' + re.escape(port_literal) + r'\b', rule_text):
        return True
    # bare number (e.g. "80") but ensure not part of IP
    if re.search(r'\b' + re.escape(port_literal) + r'\b', rule_text):
        return True
    return False

def rule_from_ip(rule_text):
    # heuristics: ufw prints the "From" at the end like "Anywhere" or "1.2.3.4"
    # we'll try to find an IPv4/IPv6 in the text
    ip_regex = r'(\b(?:\d{1,3}\.){3}\d{1,3}\b|\b[0-9a-fA-F:]+\b)'
    m = re.search(ip_regex, rule_text)
    if m:
        return m.group(1)
    return None

def delete_rule_by_number(n):
    # Use --force to avoid interactive prompts (ufw supports --force)
    print(f"[+] Deletando regra número {n}")
    rc = run(f"ufw --force delete {n}")
    if rc != 0:
        print(f"[!] Aviso: comando de delete retornou {rc} para regra {n}")

def add_allow(ip, port_literal, proto=None):
    # monta comando ufw
    cmd = f"ufw allow from {ip} to any port {port_literal}"
    if proto:
        cmd += f" proto {proto}"
    print(f"[+] Adicionando: {cmd}")
    rc = run(cmd)
    if rc != 0:
        print(f"[!] Aviso: comando adicionou regra retornou {rc}")

def main():
    if os.geteuid() != 0:
        fatal("Execute este script como root/sudo.")

    if len(sys.argv) < 3:
        print("Uso: sudo ./ufw_apply_whitelist.py ips.txt ports.txt")
        sys.exit(1)

    ips_file = sys.argv[1]
    ports_file = sys.argv[2]

    if not os.path.isfile(ips_file):
        fatal(f"Arquivo de IPs não encontrado: {ips_file}")
    if not os.path.isfile(ports_file):
        fatal(f"Arquivo de portas não encontrado: {ports_file}")

    # verifica ufw instalado
    if run("which ufw", capture=True).strip() == "":
        fatal("ufw não encontrado no PATH. Instale com: sudo apt install ufw")

    # lê arquivos
    raw_ips = read_lines(ips_file)
    raw_ports = read_lines(ports_file)

    # valida IPs
    ips = []
    for line in raw_ips:
        try:
            ip_address(line)  # valida
            ips.append(line)
        except AddressValueError:
            fatal(f"IP inválido no arquivo: {line}")

    # normaliza portas
    ports = []
    for p in raw_ports:
        plit, proto = parse_port_spec(p)
        ports.append((plit, proto))

    print(f"[i] IPs válidos: {len(ips)} entries")
    print(f"[i] Ports válidas: {len(ports)} entries")

    # backup
    backup_ufw()

    # certifica que ufw está ativo (se não, ativa com --force)
    try:
        out = run("ufw status", capture=True)
    except Exception:
        out = ""
    if "Status: inactive" in out:
        print("[i] UFW está inativo — ativando (com --force).")
        rc = run("ufw --force enable")
        if rc != 0:
            fatal("Falha ao ativar UFW.")
    else:
        print("[i] UFW ativo.")

    # 1) Examina regras numeradas e marca para deleção as ALLOW que correspondam às portas listadas
    lines = ufw_status_numbered()
    items = parse_status_numbered_lines(lines)
    # coletar nums a deletar se a regra permitir a porta e o 'from' não estiver na lista de ips permitidos
    nums_to_delete = set()

    # Construir conjunto de ips/string para comparação (inclui 'Anywhere' se for generic)
    ips_set = set(ips)

    for it in items:
        text = it['rule']
        # consider only ALLOW IN rules
        if not re.search(r'\bALLOW\b', text, flags=re.IGNORECASE):
            continue
        # for each port literal, if rule contains it and the 'from' is not in allowed list, we mark
        for port_literal, proto in ports:
            if rule_contains_port(text, port_literal):
                # check if rule 'from' matches any allowed ip (very heuristic)
                from_ip = rule_from_ip(text)
                # if from_ip is None or is "Anywhere", then it's general => delete (we want exclusivity)
                if from_ip is None:
                    nums_to_delete.add(it['num'])
                else:
                    # if from_ip is a single ip and not in our allowed set, delete
                    if from_ip not in ips_set and from_ip not in ("Anywhere", "Anywhere (v6)", "anywhere"):
                        nums_to_delete.add(it['num'])
                # don't double-check same rule for other ports
                break

    # Delete in descending order so indices don't shift
    if nums_to_delete:
        to_delete_sorted = sorted(nums_to_delete, reverse=True)
        print(f"[i] Regras a deletar (por número): {to_delete_sorted}")
        for n in to_delete_sorted:
            delete_rule_by_number(n)
    else:
        print("[i] Nenhuma regra incompatível encontrada para remoção.")

    # 2) Adiciona regras para cada IP x porta (idempotência: ufw não adiciona duplicatas exatamente iguais)
    for ip in ips:
        for port_literal, proto in ports:
            # adicionar
            add_allow(ip, port_literal, proto)

    # 3) reload / status
    print("[i] Recarregando UFW...")
    run("ufw reload")

    print("[i] Status atual do UFW:")
    try:
        print(run("ufw status verbose", capture=True))
    except Exception:
        print("[!] Não foi possível mostrar 'ufw status verbose' via capture.")

    print("[+] Concluído.")

if __name__ == '__main__':
    main()
