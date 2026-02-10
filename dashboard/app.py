#!/usr/bin/env python3
"""VPS-on-Phone Dashboard Backend - Flask-based API"""

import os
import subprocess
import socket
import json
from datetime import datetime
from flask import Flask, render_template, jsonify, request

try:
    import psutil
    PSUTIL_AVAILABLE = True
except ImportError:
    PSUTIL_AVAILABLE = False

app = Flask(__name__)
DASHBOARD_PORT = 5000

SERVICES = {
    'ssh': {'port': 22, 'process': 'sshd', 'name': 'SSH Server'},
    'nginx': {'port': 80, 'process': 'nginx', 'name': 'Nginx'},
    'mariadb': {'port': 3306, 'process': 'mysqld', 'name': 'MariaDB'},
    'redis': {'port': 6379, 'process': 'redis-server', 'name': 'Redis'},
    'filebrowser': {'port': 8080, 'process': 'filebrowser', 'name': 'File Browser'},
}

def get_uptime():
    try:
        with open('/proc/uptime', 'r') as f:
            secs = float(f.readline().split()[0])
        h, m = int((secs % 86400) // 3600), int((secs % 3600) // 60)
        return f"{h}h {m}m"
    except:
        return "Unknown"

def get_battery_info():
    try:
        r = subprocess.run(['termux-battery-status'], capture_output=True, text=True, timeout=5)
        if r.returncode == 0:
            d = json.loads(r.stdout)
            return {'percentage': d.get('percentage', 0), 'status': d.get('status', 'Unknown')}
    except:
        pass
    return {'percentage': None, 'status': 'Unknown'}

def get_system_stats():
    stats = {'cpu_percent': 0, 'memory_percent': 0, 'disk_percent': 0}
    if PSUTIL_AVAILABLE:
        stats['cpu_percent'] = psutil.cpu_percent(interval=0.5)
        stats['memory_percent'] = psutil.virtual_memory().percent
        stats['disk_percent'] = psutil.disk_usage('/').percent
    return stats

def is_port_open(port):
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        s.settimeout(1)
        r = s.connect_ex(('127.0.0.1', port))
        s.close()
        return r == 0
    except:
        return False

def get_service_status(sid):
    if sid not in SERVICES:
        return {'running': False}
    svc = SERVICES[sid]
    return {'id': sid, 'name': svc['name'], 'port': svc['port'], 'running': is_port_open(svc['port'])}

@app.route('/')
def index():
    return render_template('index.html')

@app.route('/api/status')
def api_status():
    return jsonify({
        'uptime': get_uptime(),
        'battery': get_battery_info(),
        'system': get_system_stats(),
        'services': [get_service_status(s) for s in SERVICES]
    })

@app.route('/api/service/<sid>/restart', methods=['POST'])
def restart(sid):
    if sid not in SERVICES:
        return jsonify({'success': False}), 404
    subprocess.run(['pkill', '-f', SERVICES[sid]['process']])
    return jsonify({'success': True})

@app.route('/filebrowser/', methods=['GET', 'POST', 'PUT', 'DELETE', 'PATCH', 'HEAD', 'OPTIONS'])
@app.route('/filebrowser/<path:path>', methods=['GET', 'POST', 'PUT', 'DELETE', 'PATCH', 'HEAD', 'OPTIONS'])
def filebrowser_proxy(path=''):
    """Proxy requests to FileBrowser on port 8080"""
    import requests
    
    # Build target URL
    target_url = f'http://localhost:8080/{path}'
    
    # Forward query parameters
    if request.query_string:
        target_url += f'?{request.query_string.decode()}'
    
    try:
        # Forward the request to FileBrowser
        resp = requests.request(
            method=request.method,
            url=target_url,
            headers={k: v for k, v in request.headers if k.lower() != 'host'},
            data=request.get_data(),
            cookies=request.cookies,
            allow_redirects=False
        )
        
        # Build response
        excluded_headers = ['content-encoding', 'content-length', 'transfer-encoding', 'connection', 'x-frame-options']
        headers = [(k, v) for k, v in resp.raw.headers.items() if k.lower() not in excluded_headers]
        
        response = app.make_response((resp.content, resp.status_code, headers))
        
        # Allow iframe embedding
        response.headers['X-Frame-Options'] = 'SAMEORIGIN'
        response.headers['Content-Security-Policy'] = "frame-ancestors 'self'"
        
        return response
    except requests.exceptions.ConnectionError:
        return jsonify({'error': 'FileBrowser service not running'}), 503

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=DASHBOARD_PORT)
