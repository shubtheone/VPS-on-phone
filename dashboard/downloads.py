#!/usr/bin/env python3
"""Download Manager Backend"""

import os
import sqlite3
import uuid
import threading
import time
from datetime import datetime
import requests
from urllib.parse import urlparse, unquote

# Download storage directory
DOWNLOAD_DIR = os.path.expanduser("~/vps-downloads")
DB_PATH = os.path.expanduser("~/.vps-on-phone/downloads.db")

# Ensure directories exist
os.makedirs(DOWNLOAD_DIR, exist_ok=True)
os.makedirs(os.path.dirname(DB_PATH), exist_ok=True)

class DownloadManager:
    def __init__(self):
        self.db = DB_PATH
        self.init_db()
    
    def init_db(self):
        """Initialize database"""
        conn = sqlite3.connect(self.db)
        c = conn.cursor()
        c.execute('''CREATE TABLE IF NOT EXISTS downloads
                     (id TEXT PRIMARY KEY,
                      url TEXT,
                      filename TEXT,
                      filepath TEXT,
                      status TEXT,
                      progress INTEGER,
                      size INTEGER,
                      downloaded INTEGER,
                      error TEXT,
                      created_at TIMESTAMP,
                      completed_at TIMESTAMP)''')
        conn.commit()
        conn.close()
    
    def add_download(self, url):
        """Add a new download"""
        download_id = str(uuid.uuid4())[:8]
        filename = self._get_filename_from_url(url)
        filepath = os.path.join(DOWNLOAD_DIR, filename)
        
        conn = sqlite3.connect(self.db)
        c = conn.cursor()
        c.execute('''INSERT INTO downloads 
                     (id, url, filename, filepath, status, progress, size, downloaded, created_at)
                     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)''',
                  (download_id, url, filename, filepath, 'queued', 0, 0, 0, datetime.now()))
        conn.commit()
        conn.close()
        
        # Start download in background thread
        thread = threading.Thread(target=self._download_file, args=(download_id,))
        thread.daemon = True
        thread.start()
        
        return download_id
    
    def _get_filename_from_url(self, url):
        """Extract filename from URL"""
        parsed = urlparse(url)
        filename = os.path.basename(parsed.path)
        if not filename:
            filename = f"download_{int(time.time())}"
        filename = unquote(filename)
        
        # Avoid duplicates
        base, ext = os.path.splitext(filename)
        counter = 1
        while os.path.exists(os.path.join(DOWNLOAD_DIR, filename)):
            filename = f"{base}_{counter}{ext}"
            counter += 1
        
        return filename
    
    def _download_file(self, download_id):
        """Download file in background"""
        conn = sqlite3.connect(self.db)
        c = conn.cursor()
        
        try:
            # Get download info
            c.execute('SELECT url, filepath FROM downloads WHERE id = ?', (download_id,))
            row = c.fetchone()
            if not row:
                return
            
            url, filepath = row
            
            # Update status to downloading
            c.execute('UPDATE downloads SET status = ? WHERE id = ?', ('downloading', download_id))
            conn.commit()
            
            # Download with progress tracking
            response = requests.get(url, stream=True, timeout=30)
            response.raise_for_status()
            
            total_size = int(response.headers.get('content-length', 0))
            downloaded = 0
            
            c.execute('UPDATE downloads SET size = ? WHERE id = ?', (total_size, download_id))
            conn.commit()
            
            with open(filepath, 'wb') as f:
                for chunk in response.iter_content(chunk_size=8192):
                    if chunk:
                        f.write(chunk)
                        downloaded += len(chunk)
                        
                        # Update progress every 100KB
                        if downloaded % 102400 == 0 or downloaded == total_size:
                            progress = int((downloaded / total_size * 100)) if total_size > 0 else 0
                            c.execute('UPDATE downloads SET progress = ?, downloaded = ? WHERE id = ?',
                                    (progress, downloaded, download_id))
                            conn.commit()
            
            # Mark as completed
            c.execute('UPDATE downloads SET status = ?, progress = 100, completed_at = ? WHERE id = ?',
                     ('completed', datetime.now(), download_id))
            conn.commit()
            
        except Exception as e:
            c.execute('UPDATE downloads SET status = ?, error = ? WHERE id = ?',
                     ('failed', str(e), download_id))
            conn.commit()
        
        finally:
            conn.close()
    
    def get_downloads(self):
        """Get all downloads"""
        conn = sqlite3.connect(self.db)
        c = conn.cursor()
        c.execute('''SELECT id, url, filename, status, progress, size, downloaded, 
                            error, created_at, completed_at 
                     FROM downloads ORDER BY created_at DESC''')
        rows = c.fetchall()
        conn.close()
        
        downloads = []
        for row in rows:
            downloads.append({
                'id': row[0],
                'url': row[1],
                'filename': row[2],
                'status': row[3],
                'progress': row[4],
                'size': row[5],
                'downloaded': row[6],
                'error': row[7],
                'created_at': row[8],
                'completed_at': row[9]
            })
        
        return downloads
    
    def delete_download(self, download_id):
        """Delete a download"""
        conn = sqlite3.connect(self.db)
        c = conn.cursor()
        
        # Get filepath
        c.execute('SELECT filepath FROM downloads WHERE id = ?', (download_id,))
        row = c.fetchone()
        
        if row and os.path.exists(row[0]):
            os.remove(row[0])
        
        c.execute('DELETE FROM downloads WHERE id = ?', (download_id,))
        conn.commit()
        conn.close()
    
    def get_download_path(self, download_id):
        """Get file path for download"""
        conn = sqlite3.connect(self.db)
        c = conn.cursor()
        c.execute('SELECT filepath, status FROM downloads WHERE id = ?', (download_id,))
        row = c.fetchone()
        conn.close()
        
        if row and row[1] == 'completed' and os.path.exists(row[0]):
            return row[0]
        return None
