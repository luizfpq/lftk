#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import psutil
import socket  # <-- Importante para SOCK_DGRAM e SOCK_STREAM
import os
import sys
from collections import defaultdict

def get_listening_connections():
    """Obtém todas as conexões de rede em estado LISTEN (ou equivalentes)."""
    connections = []
    try:
        conns = psutil.net_connections(kind='inet')
        for conn in conns:
            # TCP: verifica se está escutando
            if conn.status == psutil.CONN_LISTEN:
                connections.append(conn)
            # UDP: não tem estado, mas se tem laddr, está "escutando"
            elif conn.type == socket.SOCK_DGRAM and conn.laddr:
                connections.append(conn)
    except psutil.AccessDenied:
        print("[!] Acesso negado ao tentar listar conexões. Execute como administrador/root.")
        sys.exit(1)
    return connections

def get_process_name(pid):
    """Obtém o nome do processo a partir do PID."""
    try:
        proc = psutil.Process(pid)
        return proc.name()
    except (psutil.NoSuchProcess, psutil.AccessDenied):
        return "Desconhecido"

def format_address(addr):
    """Formata o endereço IP e porta de forma legível."""
    if addr:
        ip, port = addr
        if ip == "0.0.0.0":
            ip = "*"
        elif ip == "::":
            ip = "*"
        return f"{ip}:{port}"
    return "N/A"

def main():
    print("🔍 Auditoria de Portas em Uso – Serviços Expondo Portas")
    print("=" * 70)

    connections = get_listening_connections()
    grouped = defaultdict(list)

    for conn in connections:
        pid = conn.pid if conn.pid else "N/A"
        proto = "UDP" if conn.type == socket.SOCK_DGRAM else "TCP"
        local_addr = format_address(conn.laddr)
        status = conn.status if proto == "TCP" else "N/A"
        process_name = get_process_name(pid) if pid != "N/A" else "N/A"
        grouped[(pid, process_name)].append((proto, local_addr, status))

    if not grouped:
        print("Nenhum serviço escutando portas foi encontrado.")
        return

    # Ordena por PID (ou por nome se PID for N/A)
    def sort_key(item):
        pid = item[0][0]
        return (pid if isinstance(pid, int) else float('inf'))

    sorted_items = sorted(grouped.items(), key=sort_key)

    for (pid, proc_name), conns in sorted_items:
        print(f"\nPID: {pid:<8} | Processo: {proc_name}")
        print("-" * 60)
        for proto, addr, status in conns:
            if proto == "TCP":
                print(f"  {proto:<4} {addr:<20} → Estado: {status}")
            else:
                print(f"  {proto:<4} {addr:<20}")

    print("\n" + "=" * 70)
    print("💡 Dica de segurança: Verifique se todos os serviços listados são necessários.")
    print("   Portas expostas publicamente (especialmente 0.0.0.0 ou *) devem ser revisadas!")

if __name__ == "__main__":
    if os.name == 'nt':
        print("⚠️  Aviso: No Windows, alguns detalhes podem estar incompletos sem privilégios elevados.")
    main()