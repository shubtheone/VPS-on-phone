#!/usr/bin/env python3
"""Utility script to clean up database"""
import os
import sqlite3

# Database paths
DOWNLOADS_DB = os.path.expanduser("~/.vps-on-phone/downloads.db")
TODOS_DB = os.path.expanduser("~/.vps-on-phone/todos.db")

def clear_downloads():
    """Clear all downloads"""
    if not os.path.exists(DOWNLOADS_DB):
        print("No downloads database found")
        return
    
    conn = sqlite3.connect(DOWNLOADS_DB)
    c = conn.cursor()
    c.execute("DELETE FROM downloads")
    conn.commit()
    conn.close()
    print("✓ All downloads cleared")

def clear_todos():
    """Clear all todos"""
    if not os.path.exists(TODOS_DB):
        print("No todos database found")
        return
    
    conn = sqlite3.connect(TODOS_DB)
    c = conn.cursor()
    c.execute("DELETE FROM todos")
    conn.commit()
    conn.close()
    print("✓ All todos cleared")

if __name__ == "__main__":
    import sys
    
    if len(sys.argv) < 2:
        print("Usage:")
        print("  python3 cleanup.py downloads  - Clear all downloads")
        print("  python3 cleanup.py todos      - Clear all todos")
        print("  python3 cleanup.py all        - Clear everything")
        sys.exit(1)
    
    action = sys.argv[1]
    
    if action == "downloads":
        clear_downloads()
    elif action == "todos":
        clear_todos()
    elif action == "all":
        clear_downloads()
        clear_todos()
    else:
        print(f"Unknown action: {action}")
        sys.exit(1)
