/**
 * VPS-on-Phone Dashboard JavaScript
 * Handles real-time updates and service controls
 */

// Configuration
const API_BASE = '';
const UPDATE_INTERVAL = 5000; // 5 seconds

// Service Icons
const SERVICE_ICONS = {
    ssh: '🔐',
    nginx: '🌐',
    mariadb: '🗄️',
    postgresql: '🐘',
    redis: '⚡',
    filebrowser: '📁',
    default: '⚙️'
};

// State
let isUpdating = false;

/**
 * Fetch status from API
 */
async function fetchStatus() {
    try {
        const response = await fetch(`${API_BASE}/api/status`);
        if (!response.ok) throw new Error('API request failed');
        return await response.json();
    } catch (error) {
        console.error('Failed to fetch status:', error);
        return null;
    }
}

/**
 * Update dashboard with new data
 */
async function updateDashboard() {
    if (isUpdating) return;
    isUpdating = true;

    const data = await fetchStatus();

    if (data) {
        updateSystemStats(data.system);
        updateServices(data.services);
        updateHeader(data);
        updateLastUpdate();
    } else {
        setOfflineState();
    }

    isUpdating = false;
}

/**
 * Update system statistics
 */
function updateSystemStats(stats) {
    if (!stats) return;

    // CPU
    const cpuValue = document.getElementById('cpu-value');
    const cpuBar = document.getElementById('cpu-bar');
    if (cpuValue && cpuBar) {
        cpuValue.textContent = `${Math.round(stats.cpu_percent)}%`;
        cpuBar.style.width = `${stats.cpu_percent}%`;
    }

    // Memory
    const memValue = document.getElementById('memory-value');
    const memBar = document.getElementById('memory-bar');
    if (memValue && memBar) {
        memValue.textContent = `${Math.round(stats.memory_percent)}%`;
        memBar.style.width = `${stats.memory_percent}%`;
    }

    // Disk
    const diskValue = document.getElementById('disk-value');
    const diskBar = document.getElementById('disk-bar');
    if (diskValue && diskBar) {
        diskValue.textContent = `${Math.round(stats.disk_percent)}%`;
        diskBar.style.width = `${stats.disk_percent}%`;
    }
}

/**
 * Update services grid
 */
function updateServices(services) {
    const grid = document.getElementById('services-grid');
    if (!grid || !services) return;

    grid.innerHTML = services.map(service => `
        <div class="service-card" data-service="${service.id}">
            <div class="service-icon">${SERVICE_ICONS[service.id] || SERVICE_ICONS.default}</div>
            <div class="service-name">${service.name}</div>
            <div class="service-status ${service.running ? 'running' : 'stopped'}">
                <span class="dot"></span>
                ${service.running ? 'Running' : 'Stopped'}
            </div>
            <div class="service-port">Port ${service.port}</div>
            <div class="service-actions">
                ${service.running
            ? `<button class="service-btn stop" onclick="controlService('${service.id}', 'stop')">Stop</button>`
            : `<button class="service-btn start" onclick="controlService('${service.id}', 'start')">Start</button>`
        }
                <button class="service-btn" onclick="controlService('${service.id}', 'restart')">↻</button>
            </div>
        </div>
    `).join('');
}

/**
 * Update header stats
 */
function updateHeader(data) {
    // Battery
    const batteryPercent = document.getElementById('battery-percent');
    if (batteryPercent && data.battery) {
        batteryPercent.textContent = data.battery.percentage ?? '--';
    }

    // Uptime
    const uptime = document.getElementById('uptime');
    if (uptime) {
        uptime.textContent = data.uptime || '--';
    }

    // Connection status
    const status = document.getElementById('connection-status');
    if (status) {
        status.className = 'status-indicator online';
        status.innerHTML = '<span class="dot"></span><span>Online</span>';
    }
}

/**
 * Update last update timestamp
 */
function updateLastUpdate() {
    const el = document.getElementById('last-update');
    if (el) {
        el.textContent = new Date().toLocaleTimeString();
    }
}

/**
 * Set offline state
 */
function setOfflineState() {
    const status = document.getElementById('connection-status');
    if (status) {
        status.className = 'status-indicator offline';
        status.innerHTML = '<span class="dot"></span><span>Offline</span>';
        status.style.background = 'rgba(255, 68, 102, 0.1)';
        status.style.color = '#ff4466';
        status.style.borderColor = 'rgba(255, 68, 102, 0.3)';
    }
}

/**
 * Control a service (start/stop/restart)
 */
async function controlService(serviceId, action) {
    showToast(`${action.charAt(0).toUpperCase() + action.slice(1)}ing ${serviceId}...`);

    try {
        const response = await fetch(`${API_BASE}/api/service/${serviceId}/${action}`, {
            method: 'POST'
        });

        const result = await response.json();

        if (result.success) {
            showToast(`${serviceId} ${action}ed successfully`, 'success');
            setTimeout(updateDashboard, 1000);
        } else {
            showToast(`Failed to ${action} ${serviceId}`, 'error');
        }
    } catch (error) {
        showToast(`Error: ${error.message}`, 'error');
    }
}

/**
 * Copy text to clipboard
 */
function copyToClipboard(elementId) {
    const el = document.getElementById(elementId);
    if (!el) return;

    const text = el.textContent;
    navigator.clipboard.writeText(text).then(() => {
        showToast('Copied to clipboard!', 'success');
    }).catch(() => {
        showToast('Failed to copy', 'error');
    });
}

/**
 * Manual refresh
 */
function refreshStatus() {
    showToast('Refreshing...');
    updateDashboard();
}

/**
 * Show toast notification
 */
function showToast(message, type = 'info') {
    // Remove existing toasts
    document.querySelectorAll('.toast').forEach(t => t.remove());

    const toast = document.createElement('div');
    toast.className = 'toast';
    toast.textContent = message;

    if (type === 'success') {
        toast.style.borderColor = 'var(--status-success)';
    } else if (type === 'error') {
        toast.style.borderColor = 'var(--status-error)';
    }

    document.body.appendChild(toast);

    setTimeout(() => {
        toast.style.animation = 'slideIn 0.3s ease reverse';
        setTimeout(() => toast.remove(), 300);
    }, 3000);
}

/**
 * Switch between Dashboard and File Manager tabs
 */
function switchTab(tabName) {
    // Update tab buttons
    document.querySelectorAll('.tab-btn').forEach(btn => {
        if (btn.dataset.tab === tabName) {
            btn.classList.add('active');
        } else {
            btn.classList.remove('active');
        }
    });

    // Update tab content
    document.querySelectorAll('.tab-content').forEach(content => {
        if (content.id === `${tabName}-tab`) {
            content.classList.add('active');
        } else {
            content.classList.remove('active');
        }
    });

    // Lazy load FileBrowser iframe
    if (tabName === 'files') {
        const iframe = document.getElementById('filebrowser-iframe');
        if (iframe.getAttribute('src') === '') {
            iframe.src = '/filebrowser/';
        }
    }

    // Save active tab to localStorage
    localStorage.setItem('activeTab', tabName);
}

// Initialize
document.addEventListener('DOMContentLoaded', () => {
    // Restore last active tab
    const lastTab = localStorage.getItem('activeTab') || 'dashboard';
    switchTab(lastTab);

    updateDashboard();
    setInterval(updateDashboard, UPDATE_INTERVAL);
});
