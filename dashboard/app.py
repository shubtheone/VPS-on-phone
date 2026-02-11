#!/usr/bin/env python3
"""VPS-on-Phone Dashboard Backend - Flask-based API"""

import os
import subprocess
import socket
import json
from datetime import datetime
from flask import Flask, render_template, jsonify, request, send_file

try:
    import psutil
    PSUTIL_AVAILABLE = True
except ImportError:
    PSUTIL_AVAILABLE = False

# Import our new managers
from downloads import DownloadManager
from todos import TodoManager

app = Flask(__name__)
DASHBOARD_PORT = 5000

# Initialize managers
download_mgr = DownloadManager()
todo_mgr = TodoManager()

SERVICES = {
    'ssh': {'port': 22, 'process': 'sshd', 'name': 'SSH Server'},
    'nginx': {'port': 8081, 'process': 'python3 -m http.server', 'name': 'Nginx'},
    'mariadb': {'port': 3307, 'process': 'python3 -c.*3307', 'name': 'MariaDB'},
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

@app.route('/api/service/<sid>/start', methods=['POST'])
def start_service(sid):
    if sid not in SERVICES:
        return jsonify({'success': False}), 404
    
    try:
        if sid == 'ssh':
            # SSH is typically always running on Ubuntu
            pass
        elif sid == 'nginx':
            # Start HTTP server (nginx replacement)
            subprocess.Popen(['python3', '-m', 'http.server', '8081'], 
                           stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, 
                           cwd='/tmp')
        elif sid == 'mariadb':
            # Start database server (MariaDB replacement)
            subprocess.Popen(['python3', '-c', '''
import http.server
import socketserver
class DBHandler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        self.send_response(200)
        self.send_header('Content-type', 'text/html')
        self.end_headers()
        self.wfile.write(b'MariaDB Test Server - OK')
    def log_message(self, format, *args): pass
httpd = socketserver.TCPServer(('', 3307), DBHandler)
httpd.serve_forever()
'''], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        elif sid == 'redis':
            # Check if redis-server exists in our test environment
            try:
                subprocess.run(['./test-services/redis-stable/src/redis-server', '--port', '6379', '--daemonize', 'yes'], 
                             check=True, cwd='/home/vortex/Documents/VPS-on-phone')
            except:
                # Fallback for systems without our compiled Redis
                subprocess.run(['redis-server', '--daemonize', 'yes'], check=False)
        elif sid == 'filebrowser':
            subprocess.Popen(['filebrowser', '--port', '8080', '--database', '/tmp/filebrowser.db',
                            '--baseURL', '/filebrowser', '--root', '/home/vortex/Documents/VPS-on-phone'], 
                           stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        
        # Wait a moment for the service to start
        import time
        time.sleep(0.5)
        return jsonify({'success': True})
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)})

@app.route('/api/service/<sid>/stop', methods=['POST'])
def stop_service(sid):
    if sid not in SERVICES:
        return jsonify({'success': False}), 404
    try:
        result = None
        
        if sid == 'ssh':
            # Don't actually stop SSH in testing
            return jsonify({'success': False, 'error': 'Cannot stop SSH service'})
        elif sid == 'nginx':
            result = subprocess.run(['pkill', '-f', 'python3 -m http.server 8081'], 
                                   capture_output=True, text=True)
        elif sid == 'mariadb':
            result = subprocess.run(['pkill', '-f', 'python3 -c.*3307'], 
                                   capture_output=True, text=True)
        elif sid == 'redis':
            result = subprocess.run(['pkill', '-f', 'redis-server'], 
                                   capture_output=True, text=True)
        elif sid == 'filebrowser':
            result = subprocess.run(['pkill', '-f', 'filebrowser'], 
                                   capture_output=True, text=True)
        
        # Check if the command succeeded
        # If stderr contains "Operation not permitted" or "Permission denied", it's a failure
        if result and result.stderr and ('permission denied' in result.stderr.lower() or 
                                         'operation not permitted' in result.stderr.lower()):
            return jsonify({'success': False, 'error': 'Permission denied - requires sudo or service is owned by another user'})
        
        # Return code 0 = process killed successfully
        # Return code 1 = no matching processes (also success in a way, already stopped)
        # Other return codes = errors
        if result and result.returncode not in [0, 1]:
            return jsonify({'success': False, 'error': f'Failed with exit code {result.returncode}'})
        
        # Wait a moment for the service to stop
        import time
        time.sleep(0.5)
        return jsonify({'success': True})
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)})

@app.route('/api/service/<sid>/restart', methods=['POST'])
def restart(sid):
    if sid not in SERVICES:
        return jsonify({'success': False}), 404
    try:
        # Stop first
        stop_service(sid)
        # Wait a moment
        import time
        time.sleep(1)
        # Then start
        start_service(sid)
        return jsonify({'success': True})
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)})

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

# ============================================================================
# Download Manager API Routes
# ============================================================================

@app.route('/api/downloads', methods=['GET'])
def get_downloads():
    """Get all downloads"""
    downloads = download_mgr.get_downloads()
    return jsonify(downloads)

@app.route('/api/downloads', methods=['POST'])
def add_download():
    """Add a new download"""
    data = request.get_json()
    url = data.get('url')
    format_type = data.get('format')
    
    if not url:
        return jsonify({'success': False, 'error': 'URL required'}), 400
    
    try:
        download_id = download_mgr.add_download(url, format_type)
        return jsonify({'success': True, 'id': download_id})
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500

@app.route('/api/downloads/<download_id>', methods=['DELETE'])
def delete_download(download_id):
    """Delete a download"""
    try:
        download_mgr.delete_download(download_id)
        return jsonify({'success': True})
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500

@app.route('/api/downloads/<download_id>/file', methods=['GET'])
def get_download_file(download_id):
    """Download the completed file"""
    filepath = download_mgr.get_download_path(download_id)
    
    if filepath:
        return send_file(filepath, as_attachment=True)
    else:
        return jsonify({'error': 'File not found or not ready'}), 404

# ============================================================================
# Todo App API Routes
# ============================================================================

@app.route('/api/todos', methods=['GET'])
def get_todos():
    """Get todos with optional filter"""
    filter_by = request.args.get('filter', 'all')
    todos = todo_mgr.get_todos(filter_by)
    return jsonify(todos)

@app.route('/api/todos', methods=['POST'])
def add_todo():
    """Add a new todo"""
    data = request.get_json()
    title = data.get('title')
    
    if not title:
        return jsonify({'success': False, 'error': 'Title required'}), 400
    
    try:
        todo_id = todo_mgr.add_todo(
            title=title,
            description=data.get('description', ''),
            priority=data.get('priority', 'medium'),
            category=data.get('category', 'other'),
            due_date=data.get('due_date')
        )
        return jsonify({'success': True, 'id': todo_id})
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500

@app.route('/api/todos/<todo_id>', methods=['PUT'])
def update_todo(todo_id):
    """Update a todo"""
    data = request.get_json()
    
    try:
        todo_mgr.update_todo(todo_id, **data)
        return jsonify({'success': True})
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500

@app.route('/api/todos/<todo_id>/toggle', methods=['POST'])
def toggle_todo(todo_id):
    """Toggle todo completion"""
    try:
        todo_mgr.toggle_todo(todo_id)
        return jsonify({'success': True})
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500

@app.route('/api/todos/<todo_id>', methods=['DELETE'])
def delete_todo(todo_id):
    """Delete a todo"""
    try:
        todo_mgr.delete_todo(todo_id)
        return jsonify({'success': True})
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500

@app.route('/api/todos/stats', methods=['GET'])
def get_todo_stats():
    """Get todo statistics"""
    stats = todo_mgr.get_stats()
    return jsonify(stats)

@app.route('/api/todos/categories', methods=['GET'])
def get_categories():
    """Get all categories"""
    categories = todo_mgr.get_categories()
    return jsonify(categories)

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=DASHBOARD_PORT)
