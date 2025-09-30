#!/usr/bin/env python3
# map_ports.py
# Requer Python 3.6+. Executar com sudo para informação completa.
# Não depende de bibliotecas externas — usa ss + /proc para coletar dados.

import subprocess
import json
import shlex
from pathlib import Path

def run(cmd):
    try:
        out = subprocess.check_output(cmd, shell=True, stderr=subprocess.DEVNULL)
        return out.decode('utf-8', errors='replace')
    except subprocess.CalledProcessError:
        return ''

def parse_ss():
    # ss -tunlp listing; we'll parse lines containing "pid="
    out = run('ss -tunlp')
    lines = out.splitlines()
    results = []
    header_skipped = False
    for line in lines:
        if not header_skipped:
            # skip the header line(s)
            header_skipped = True
            continue
        if 'pid=' in line:
            # normalize whitespace then split
            parts = line.strip().split()
            # protocol is first column sometimes (tcp, udp)
            proto = parts[0]
            # find local address column (usually 4th)
            # fallback: search for "LISTEN" etc.
            local_index = None
            # try to find the column that contains ':' (ip:port)
            for i,p in enumerate(parts):
                if ':' in p and not p.startswith('pid='):
                    # crude but works in most ss outputs
                    local_index = i
                    break
            local_addr = parts[local_index] if local_index is not None else ''
            # find pid=... substring
            pid_part = next((p for p in parts if p.startswith('pid=')), '')
            if pid_part:
                # pid=1234,fd=7
                pid = pid_part.split('=')[1].split(',')[0]
            else:
                pid = ''
            results.append({
                'proto': proto,
                'local': local_addr,
                'raw': line.strip(),
                'pid': pid
            })
    return results

def pid_info(pid):
    info = {'pid': pid, 'cmdline': None, 'exe': None, 'service': None}
    p_proc = Path(f'/proc/{pid}')
    if p_proc.exists():
        try:
            cmd = p_proc.joinpath('cmdline').read_bytes().replace(b'\0', b' ').decode('utf-8', errors='replace').strip()
            info['cmdline'] = cmd or None
        except Exception:
            info['cmdline'] = None
        try:
            if p_proc.joinpath('exe').exists():
                info['exe'] = str(p_proc.joinpath('exe').resolve())
        except Exception:
            info['exe'] = None
        # cgroup -> try to find service name
        try:
            cg = p_proc.joinpath('cgroup').read_text()
            svc = None
            for l in cg.splitlines():
                if 'system.slice' in l:
                    # something like: 1:name=systemd:/system.slice/ssh.service
                    parts = l.split('/')
                    if parts:
                        candidate = parts[-1]
                        if candidate.endswith('.service'):
                            svc = candidate
                            break
            info['service'] = svc
        except Exception:
            info['service'] = None
    return info

def main():
    sockets = parse_ss()
    # enrich with pid info
    pid_cache = {}
    enriched = []
    for s in sockets:
        pid = s.get('pid')
        if not pid:
            enriched.append({**s, 'pid_info': None})
            continue
        if pid not in pid_cache:
            pid_cache[pid] = pid_info(pid)
        enriched.append({**s, 'pid_info': pid_cache[pid]})
    print(json.dumps(enriched, indent=2, ensure_ascii=False))

if __name__ == '__main__':
    main()
