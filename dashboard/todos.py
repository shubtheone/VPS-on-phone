#!/usr/bin/env python3
"""Todo App Backend"""

import os
import sqlite3
import uuid
from datetime import datetime

DB_PATH = os.path.expanduser("~/.vps-on-phone/todos.db")
os.makedirs(os.path.dirname(DB_PATH), exist_ok=True)

class TodoManager:
    def __init__(self):
        self.db = DB_PATH
        self.init_db()
    
    def init_db(self):
        """Initialize database"""
        conn = sqlite3.connect(self.db)
        c = conn.cursor()
        c.execute('''CREATE TABLE IF NOT EXISTS todos
                     (id TEXT PRIMARY KEY,
                      title TEXT NOT NULL,
                      description TEXT,
                      completed INTEGER DEFAULT 0,
                      priority TEXT DEFAULT 'medium',
                      category TEXT,
                      due_date TEXT,
                      created_at TIMESTAMP,
                      completed_at TIMESTAMP,
                      position INTEGER)''')
        
        c.execute('''CREATE TABLE IF NOT EXISTS categories
                     (id TEXT PRIMARY KEY,
                      name TEXT UNIQUE,
                      color TEXT,
                      icon TEXT)''')
        
        # Add default categories if they don't exist
        default_categories = [
            ('work', 'Work', '#3b82f6', '💼'),
            ('personal', 'Personal', '#10b981', '👤'),
            ('shopping', 'Shopping', '#f59e0b', '🛒'),
            ('health', 'Health', '#ef4444', '❤️'),
            ('other', 'Other', '#6b7280', '📌')
        ]
        
        for cat_id, name, color, icon in default_categories:
            c.execute('INSERT OR IGNORE INTO categories (id, name, color, icon) VALUES (?, ?, ?, ?)',
                     (cat_id, name, color, icon))
        
        conn.commit()
        conn.close()
    
    def add_todo(self, title, description='', priority='medium', category='other', due_date=None):
        """Add a new todo"""
        todo_id = str(uuid.uuid4())[:8]
        
        conn = sqlite3.connect(self.db)
        c = conn.cursor()
        
        # Get max position
        c.execute('SELECT MAX(position) FROM todos')
        max_pos = c.fetchone()[0]
        position = (max_pos or 0) + 1
        
        c.execute('''INSERT INTO todos 
                     (id, title, description, priority, category, due_date, created_at, position)
                     VALUES (?, ?, ?, ?, ?, ?, ?, ?)''',
                  (todo_id, title, description, priority, category, due_date, datetime.now(), position))
        conn.commit()
        conn.close()
        
        return todo_id
    
    def get_todos(self, filter_by='all'):
        """Get todos with optional filter"""
        conn = sqlite3.connect(self.db)
        c = conn.cursor()
        
        if filter_by == 'active':
            c.execute('''SELECT t.*, cat.name as category_name, cat.color as category_color, cat.icon as category_icon
                        FROM todos t 
                        LEFT JOIN categories cat ON t.category = cat.id
                        WHERE t.completed = 0 
                        ORDER BY t.position, t.created_at DESC''')
        elif filter_by == 'completed':
            c.execute('''SELECT t.*, cat.name as category_name, cat.color as category_color, cat.icon as category_icon
                        FROM todos t 
                        LEFT JOIN categories cat ON t.category = cat.id
                        WHERE t.completed = 1 
                        ORDER BY t.completed_at DESC''')
        else:  # all
            c.execute('''SELECT t.*, cat.name as category_name, cat.color as category_color, cat.icon as category_icon
                        FROM todos t 
                        LEFT JOIN categories cat ON t.category = cat.id
                        ORDER BY t.completed, t.position, t.created_at DESC''')
        
        rows = c.fetchall()
        conn.close()
        
        todos = []
        for row in rows:
            todos.append({
                'id': row[0],
                'title': row[1],
                'description': row[2],
                'completed': bool(row[3]),
                'priority': row[4],
                'category': row[5],
                'due_date': row[6],
                'created_at': row[7],
                'completed_at': row[8],
                'position': row[9],
                'category_name': row[10],
                'category_color': row[11],
                'category_icon': row[12]
            })
        
        return todos
    
    def update_todo(self, todo_id, **kwargs):
        """Update todo fields"""
        conn = sqlite3.connect(self.db)
        c = conn.cursor()
        
        allowed_fields = ['title', 'description', 'completed', 'priority', 'category', 'due_date']
        updates = []
        values = []
        
        for field, value in kwargs.items():
            if field in allowed_fields:
                updates.append(f"{field} = ?")
                values.append(value)
        
        if updates:
            values.append(todo_id)
            query = f"UPDATE todos SET {', '.join(updates)} WHERE id = ?"
            c.execute(query, values)
            conn.commit()
        
        conn.close()
    
    def toggle_todo(self, todo_id):
        """Toggle todo completion status"""
        conn = sqlite3.connect(self.db)
        c = conn.cursor()
        
        c.execute('SELECT completed FROM todos WHERE id = ?', (todo_id,))
        row = c.fetchone()
        
        if row:
            new_status = 0 if row[0] else 1
            completed_at = datetime.now() if new_status else None
            c.execute('UPDATE todos SET completed = ?, completed_at = ? WHERE id = ?',
                     (new_status, completed_at, todo_id))
            conn.commit()
        
        conn.close()
    
    def delete_todo(self, todo_id):
        """Delete a todo"""
        conn = sqlite3.connect(self.db)
        c = conn.cursor()
        c.execute('DELETE FROM todos WHERE id = ?', (todo_id,))
        conn.commit()
        conn.close()
    
    def get_categories(self):
        """Get all categories"""
        conn = sqlite3.connect(self.db)
        c = conn.cursor()
        c.execute('SELECT id, name, color, icon FROM categories')
        rows = c.fetchall()
        conn.close()
        
        categories = []
        for row in rows:
            categories.append({
                'id': row[0],
                'name': row[1],
                'color': row[2],
                'icon': row[3]
            })
        
        return categories
    
    def get_stats(self):
        """Get todo statistics"""
        conn = sqlite3.connect(self.db)
        c = conn.cursor()
        
        c.execute('SELECT COUNT(*) FROM todos WHERE completed = 0')
        active = c.fetchone()[0]
        
        c.execute('SELECT COUNT(*) FROM todos WHERE completed = 1')
        completed = c.fetchone()[0]
        
        c.execute('SELECT COUNT(*) FROM todos')
        total = c.fetchone()[0]
        
        conn.close()
        
        return {
            'active': active,
            'completed': completed,
            'total': total,
            'completion_rate': round((completed / total * 100) if total > 0 else 0, 1)
        }
