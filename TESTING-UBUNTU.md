# Testing VPS-on-Phone on Ubuntu

This guide shows you how to test your VPS-on-Phone project on Ubuntu before deploying to Termux/Android.

## Why Test on Ubuntu First?

✅ **Faster development** - Easier to debug on your PC  
✅ **Same environment** - Ubuntu (proot-distro on Termux)  
✅ **Same code** - Works identically on both platforms  
✅ **Catch bugs early** - Fix issues before phone deployment  

---

## Prerequisites

Make sure you have:
- Ubuntu 20.04+ or any Debian-based Linux
- Python 3.8+
- Git

---

## Quick Start (Test Immediately)

### 1. Install Dependencies

```bash
# Update system
sudo apt update

# Install Python and essential tools
sudo apt install -y python3 python3-pip python3-venv

# Install services (optional, for full testing)
sudo apt install -y nginx openssh-server mariadb-server redis-server
```

### 2. Clone & Setup

```bash
# Navigate to your project
cd ~/Documents/VPS-on-phone

# Create Python virtual environment
python3 -m venv venv

# Activate virtual environment
source venv/bin/activate

# Install Python requirements
cd dashboard
pip install -r requirements.txt
```

### 3. Start the Dashboard

```bash
# Make sure you're in the dashboard directory
cd ~/Documents/VPS-on-phone/dashboard

# Start the Flask app
python3 app.py
```

You should see:
```
 * Running on http://0.0.0.0:5000
 * Running on http://127.0.0.1:5000
```

### 4. Open in Browser

Open your browser and go to:
```
http://localhost:5000
```

🎉 **You should see your dashboard!**

---

## Testing Each Feature

### ✅ Test Dashboard Tab

1. Go to http://localhost:5000
2. Should see:
   - System stats (CPU, Memory, Disk)
   - Service status cards
   - Connection info

### ✅ Test Todo List

1. Click the **"Todo List"** tab
2. Try adding a task:
   - Type "Test task" in the input
   - Select priority (Low/Medium/High)
   - Select category (Work/Personal/etc.)
   - Click "Add Task"
3. Your task should appear below
4. Test checking/unchecking the checkbox
5. Test deleting a task
6. Test filters (All/Active/Completed)

### ✅ Test Downloads

1. Click the **"Downloads"** tab
2. Test with a small file:
   ```
   https://speed.hetzner.de/100MB.bin
   ```
3. Paste URL and click "Start Download"
4. Should see:
   - Download appears in list
   - Progress bar updating
   - Status changes: Queued → Downloading → Completed
5. Click download icon to download the completed file
6. Test deleting a download

### ✅ Test File Manager

1. Click the **"Files"** tab
2. FileBrowser iframe should load
3. If FileBrowser is not installed, you'll see an error (this is normal on Ubuntu without installation)

---

## Common Issues & Solutions

### Issue: `ModuleNotFoundError: No module named 'flask'`

**Solution:**
```bash
# Make sure virtual environment is activated
source venv/bin/activate

# Install requirements again
cd dashboard
pip install -r requirements.txt
```

### Issue: `Address already in use` (Port 5000)

**Solution:**
```bash
# Find what's using port 5000
sudo lsof -i :5000

# Kill that process
kill -9 <PID>

# Or change the port in app.py:
# DASHBOARD_PORT = 5001
```

### Issue: Dashboard loads but shows "Offline"

**Solution:**
- This is normal on Ubuntu if services aren't running
- The core dashboard features (Todo, Downloads) will still work
- System stats might show 0% - this is fine for testing UI

### Issue: Downloads fail with SSL errors

**Solution:**
```bash
# Update CA certificates
sudo apt install ca-certificates
sudo update-ca-certificates
```

### Issue: Database files not found

**Solution:**
```bash
# The app creates these automatically in:
ls ~/.vps-on-phone/

# Should see:
# - todos.db
# - downloads.db

# If not created, check permissions:
chmod +x dashboard/todos.py
chmod +x dashboard/downloads.py
```

---

## Testing vs Production Differences

| Feature | Ubuntu Testing | Termux/Android Production |
|---------|---------------|--------------------------|
| **Dashboard** | ✅ Works identically | ✅ Works identically |
| **Todo List** | ✅ Works identically | ✅ Works identically |
| **Downloads** | ✅ Works identically | ✅ Works identically |
| **Battery Info** | ❌ Not available (no termux-api) | ✅ Shows % and status |
| **Services** | ⚠️ Ubuntu services | ⚠️ Termux services |
| **File Paths** | `/home/user/` | `/data/data/com.termux/` |

---

## Development Workflow

### Recommended workflow:

1. **Develop on Ubuntu**
   ```bash
   # Edit files on Ubuntu
   vim dashboard/app.py
   
   # Test immediately
   python3 app.py
   
   # Open browser, test changes
   # Ctrl+C to stop, edit, restart
   ```

2. **Version Control**
   ```bash
   git add .
   git commit -m "Added new feature"
   git push
   ```

3. **Deploy to Phone**
   ```bash
   # On your phone in Termux:
   cd vps-on-phone
   git pull
   ./vps-start.sh
   ```

---

## Advanced Testing

### Test with multiple devices

1. Find your Ubuntu PC's IP:
   ```bash
   ip addr show | grep inet
   # Look for: 192.168.x.x
   ```

2. On another device (phone/tablet), open:
   ```
   http://192.168.x.x:5000
   ```

3. Test the Todo list syncing across devices!

### Test with actual services running

```bash
# Start Nginx
sudo systemctl start nginx

# Start SSH
sudo systemctl start ssh

# Start Redis
sudo systemctl start redis

# Refresh dashboard - should show all services running
```

### Test downloads with various URLs

```bash
# Small file (fast test)
https://speed.hetzner.de/1MB.bin

# Medium file
https://speed.hetzner.de/100MB.bin

# Image
https://picsum.photos/1920/1080

# PDF
https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf
```

---

## Auto-reload During Development

For faster development, use Flask's debug mode:

```python
# In dashboard/app.py, change last line to:
if __name__ == '__main__':
    app.run(host='0.0.0.0', port=DASHBOARD_PORT, debug=True)
```

Now the server auto-reloads when you edit files!

---

## Performance Testing

### Test with many todos

```python
# Quick script to add 100 todos
python3 << EOF
from todos import TodoManager
tm = TodoManager()
for i in range(100):
    tm.add_todo(f"Task {i}", priority=['low','medium','high'][i%3], category=['work','personal'][i%2])
print("Added 100 todos!")
EOF
```

### Test with concurrent downloads

1. Add 5 different download URLs quickly
2. All should download in parallel
3. Watch progress bars update

---

## Debugging Tips

### View Python errors in detail

```bash
# Run with verbose output
python3 app.py 2>&1 | tee debug.log
```

### Check database contents

```bash
# Install sqlite3
sudo apt install sqlite3

# View todos
sqlite3 ~/.vps-on-phone/todos.db "SELECT * FROM todos;"

# View downloads
sqlite3 ~/.vps-on-phone/downloads.db "SELECT * FROM downloads;"
```

### Monitor network requests

Open browser DevTools (F12) → Network tab to see all API calls

---

## Ready for Production?

Once everything works on Ubuntu:

### Checklist:
- ✅ Dashboard loads correctly
- ✅ Todos can be added/completed/deleted
- ✅ Downloads work and show progress
- ✅ No console errors (check browser F12)
- ✅ UI looks good on mobile (use browser responsive mode)

### Deploy to Termux:

```bash
# On Android/Termux:
cd ~/vps-on-phone
git pull origin main

# Restart services
./vps-stop.sh
./vps-start.sh

# Open in browser (on phone or remotely)
# http://localhost:5000
```

---

## Next Steps

After successful testing:

1. **Customize** - Change colors, icons, add features
2. **Extend** - Add more download protocols (YouTube, torrents)
3. **Secure** - Add authentication (username/password)
4. **Share** - Set up Cloudflare tunnel for remote access

---

## Need Help?

- Check browser console (F12) for JavaScript errors
- Check terminal for Python errors
- Make sure venv is activated (`source venv/bin/activate`)
- Database files are in `~/.vps-on-phone/`
- Downloaded files are in `~/vps-downloads/`

Happy testing! 🚀
