#!/usr/bin/env python3
"""Download Manager Backend"""

import os
import sqlite3
import uuid
import threading
import time
import re
import subprocess
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
                      format TEXT,
                      created_at TIMESTAMP,
                      completed_at TIMESTAMP)''')
        
        # Migration: Add format column if it doesn't exist
        try:
            c.execute("SELECT format FROM downloads LIMIT 1")
        except sqlite3.OperationalError:
            # Column doesn't exist, add it
            c.execute("ALTER TABLE downloads ADD COLUMN format TEXT DEFAULT 'auto'")
        
        conn.commit()
        conn.close()
    
    def _is_youtube_url(self, url):
        """Check if URL is a YouTube video"""
        youtube_patterns = [
            r'(https?://)?(www\.)?(youtube|youtu|youtube-nocookie)\.(com|be)/',
            r'(https?://)?(www\.)?youtu\.be/',
        ]
        return any(re.match(pattern, url) for pattern in youtube_patterns)
    
    def _get_youtube_title(self, url):
        """Get YouTube video title before downloading"""
        try:
            result = subprocess.run(
                ['python3', '-m', 'yt_dlp', '--get-title', '--no-playlist', url],
                capture_output=True,
                text=True,
                timeout=10
            )
            if result.returncode == 0 and result.stdout.strip():
                # Clean the title for use as filename
                title = result.stdout.strip()
                # Remove invalid filename characters
                title = re.sub(r'[<>:"/\\|?*]', '', title)
                return title
        except:
            pass
        return None
    
    def add_download(self, url, format_type=None):
        """Add a new download with auto-detection"""
        download_id = str(uuid.uuid4())[:8]
        
        # Auto-detect format based on URL if not specified
        if self._is_youtube_url(url):
            if not format_type:
                format_type = 'mp4'  # Default to video for YouTube
            # Get video title for proper filename
            title = self._get_youtube_title(url)
            if title:
                filename = f'{title}.{format_type}'
            else:
                filename = f'youtube_video_{download_id}.{format_type}'
        else:
            format_type = 'file'  # Regular file download
            filename = self._get_filename_from_url(url)
        
        filepath = os.path.join(DOWNLOAD_DIR, filename)
        
        conn = sqlite3.connect(self.db)
        c = conn.cursor()
        c.execute('''INSERT INTO downloads 
                     (id, url, filename, filepath, status, progress, size, downloaded, format, created_at)
                     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)''',
                  (download_id, url, filename, filepath, 'queued', 0, 0, 0, format_type, datetime.now()))
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
            c.execute('SELECT url, filepath, format FROM downloads WHERE id = ?', (download_id,))
            row = c.fetchone()
            if not row:
                return
            
            url, filepath, format_type = row
            
            # Update status to downloading
            c.execute('UPDATE downloads SET status = ? WHERE id = ?', ('downloading', download_id))
            conn.commit()
            
            # Check if it's a YouTube URL
            if format_type in ['mp3', 'mp4']:
                self._download_youtube(download_id, url, filepath, format_type, conn, c)
                return
            
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
    
    def _download_youtube(self, download_id, url, filepath, format_type, conn, c):
        """Download YouTube video using yt-dlp"""
        try:
            base_dir = os.path.dirname(filepath)
            # Use video title in filename
            output_template = os.path.join(base_dir, '%(title)s.%(ext)s')
            
            # Set yt-dlp options based on format
            if format_type == 'mp3':
                cmd = [
                    'python3', '-m', 'yt_dlp',
                    '-x',  # Extract audio
                    '--audio-format', 'mp3',
                    '--audio-quality', '0',  # Best quality
                    '-o', output_template,
                    '--no-playlist',
                    '--progress',
                    url
                ]
            else:  # mp4
                cmd = [
                    'python3', '-m', 'yt_dlp',
                    '-f', 'bestvideo[ext=mp4]+bestaudio[ext=m4a]/best[ext=mp4]/best',
                    '--merge-output-format', 'mp4',
                    '-o', output_template,
                    '--no-playlist',
                    '--progress',
                    url
                ]
            
            # Run yt-dlp
            process = subprocess.Popen(
                cmd,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                universal_newlines=True
            )
            
            # Monitor progress
            for line in process.stdout:
                # Parse progress from yt-dlp output
                if '[download]' in line and '%' in line:
                    try:
                        match = re.search(r'(\d+\.?\d*)%', line)
                        if match:
                            progress = int(float(match.group(1)))
                            c.execute('UPDATE downloads SET progress = ? WHERE id = ?',
                                    (progress, download_id))
                            conn.commit()
                    except:
                        pass
            
            process.wait()
            
            if process.returncode == 0:
                # Find the most recently created file in the download directory
                base_dir = os.path.dirname(filepath)
                extension = format_type if format_type in ['mp3', 'mp4'] else '*'
                
                downloaded_file = None
                latest_time = 0
                
                for file in os.listdir(base_dir):
                    if file.endswith(f'.{extension}') or extension == '*':
                        file_path = os.path.join(base_dir, file)
                        file_time = os.path.getmtime(file_path)
                        if file_time > latest_time:
                            latest_time = file_time
                            downloaded_file = file_path
                
                if downloaded_file and os.path.exists(downloaded_file):
                    file_size = os.path.getsize(downloaded_file)
                    c.execute('''UPDATE downloads SET status = ?, progress = 100, 
                                size = ?, downloaded = ?, filepath = ?, 
                                filename = ?, completed_at = ? WHERE id = ?''',
                            ('completed', file_size, file_size, downloaded_file,
                             os.path.basename(downloaded_file), datetime.now(), download_id))
                else:
                    c.execute('UPDATE downloads SET status = ?, error = ? WHERE id = ?',
                            ('failed', 'File not found after download', download_id))
            else:
                c.execute('UPDATE downloads SET status = ?, error = ? WHERE id = ?',
                        ('failed', f'yt-dlp exited with code {process.returncode}', download_id))
            
            conn.commit()
            
        except Exception as e:
            c.execute('UPDATE downloads SET status = ?, error = ? WHERE id = ?',
                     ('failed', str(e), download_id))
            conn.commit()
    
    def get_downloads(self):
        """Get all downloads"""
        conn = sqlite3.connect(self.db)
        c = conn.cursor()
        c.execute('''SELECT id, url, filename, status, progress, size, downloaded, 
                            error, format, created_at, completed_at 
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
                'format': row[8] if len(row) > 8 else 'auto',
                'created_at': row[9] if len(row) > 9 else row[8],
                'completed_at': row[10] if len(row) > 10 else row[9]
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
