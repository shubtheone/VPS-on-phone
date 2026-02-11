/**
 * VPS-on-Phone Dashboard JavaScript
 * Handles real-time updates and service controls
 */

// Configuration
const API_BASE = '';
const UPDATE_INTERVAL = 30000; // 30 seconds - much less frequent

// Service Icons (minimal)
const SERVICE_ICONS = {
    ssh: 'SSH',
    nginx: 'NGINX',
    mariadb: 'MariaDB',
    postgresql: 'PostgreSQL',
    redis: 'Redis',
    filebrowser: 'Files',
    default: 'Service'
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
            <div class="service-port">:${service.port}</div>
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
    
    // Load data for specific tabs
    if (tabName === 'todos') {
        loadTodos();
        loadTodoStats();
    } else if (tabName === 'downloads') {
        loadDownloads();
    }
}

// ============================================================================
// Todo Functions
// ============================================================================

let currentFilter = 'all';
let lastTodosSignature = '';

async function loadTodos() {
    try {
        const response = await fetch(`${API_BASE}/api/todos?filter=${currentFilter}`);
        const todos = await response.json();
        
        // Simple signature to check for changes
        const signature = JSON.stringify(todos);
        if (signature === lastTodosSignature) return;
        lastTodosSignature = signature;

        displayTodos(todos);
    } catch (error) {
        console.error('Failed to load todos:', error);
    }
}

function displayTodos(todos) {
    const todosList = document.getElementById('todos-list');
    const todosEmpty = document.getElementById('todos-empty');
    
    if (todos.length === 0) {
        todosList.style.display = 'none';
        todosEmpty.style.display = 'flex';
        return;
    }
    
    todosList.style.display = 'block';
    todosEmpty.style.display = 'none';
    
    todosList.innerHTML = todos.map(todo => {
        const priorityColors = {
            low: '#10b981',
            medium: '#f59e0b',
            high: '#ef4444'
        };
        
        return `
            <div class="todo-item ${todo.completed ? 'completed' : ''}" data-id="${todo.id}">
                <div class="todo-check">
                    <input type="checkbox" ${todo.completed ? 'checked' : ''} 
                           onchange="toggleTodo('${todo.id}')">
                </div>
                <div class="todo-content">
                    <div class="todo-title">${escapeHtml(todo.title)}</div>
                    ${todo.description ? `<div class="todo-desc">${escapeHtml(todo.description)}</div>` : ''}
                    <div class="todo-meta">
                        <span class="todo-category" style="background: ${todo.category_color}20; color: ${todo.category_color}">
                            ${todo.category_name}
                        </span>
                        <span class="todo-priority" style="color: ${priorityColors[todo.priority]}">
                            ${todo.priority.toUpperCase()}
                        </span>
                    </div>
                </div>
                <div class="todo-actions">
                    <button class="icon-btn" onclick="deleteTodo('${todo.id}')" title="Delete">
                        Delete
                    </button>
                </div>
            </div>
        `;
    }).join('');
}

async function addTodo(event) {
    event.preventDefault();
    
    const title = document.getElementById('todo-title').value;
    const priority = document.getElementById('todo-priority').value;
    const category = document.getElementById('todo-category').value;
    
    try {
        const response = await fetch(`${API_BASE}/api/todos`, {
            method: 'POST',
            headers: {'Content-Type': 'application/json'},
            body: JSON.stringify({ title, priority, category })
        });
        
        const result = await response.json();
        
        if (result.success) {
            document.getElementById('todo-title').value = '';
            loadTodos();
            loadTodoStats();
            showToast('Task added!', 'success');
        }
    } catch (error) {
        showToast('Failed to add task', 'error');
    }
}

async function toggleTodo(todoId) {
    // Optimistic UI Update
    const item = document.querySelector(`.todo-item[data-id="${todoId}"]`);
    const checkbox = item ? item.querySelector('input[type="checkbox"]') : null;
    if (item) {
        item.classList.toggle('completed');
        if (checkbox) checkbox.checked = !checkbox.checked;
    }

    try {
        await fetch(`${API_BASE}/api/todos/${todoId}/toggle`, {
            method: 'POST'
        });
        loadTodoStats();
    } catch (error) {
        showToast('Failed to update task', 'error');
        // Revert on error
        if (item) {
            item.classList.toggle('completed');
            if (checkbox) checkbox.checked = !checkbox.checked;
        }
    }
}

async function deleteTodo(todoId) {
    if (!confirm('Delete this task?')) return;
    
    // Optimistic UI Remove
    const item = document.querySelector(`.todo-item[data-id="${todoId}"]`);
    if (item) item.style.display = 'none';

    try {
        await fetch(`${API_BASE}/api/todos/${todoId}`, {
            method: 'DELETE'
        });
        loadTodoStats();
        
        // Force reload in background to update internal state/signature
        const response = await fetch(`${API_BASE}/api/todos?filter=${currentFilter}`);
        const todos = await response.json();
        lastTodosSignature = JSON.stringify(todos);
        // We don't call displayTodos if we can help it, or we do to actully clean up DOM
        if (item) item.remove();
        
        showToast('Task deleted', 'success');
    } catch (error) {
        showToast('Failed to delete task', 'error');
        if (item) item.style.display = '';
    }
}

async function loadTodoStats() {
    try {
        const response = await fetch(`${API_BASE}/api/todos/stats`);
        const stats = await response.json();
        
        document.getElementById('todo-active').textContent = stats.active;
        document.getElementById('todo-completed').textContent = stats.completed;
        document.getElementById('todo-total').textContent = stats.total;
        document.getElementById('todo-completion-rate').textContent = stats.completion_rate + '%';
    } catch (error) {
        console.error('Failed to load todo stats:', error);
    }
}

function filterTodos(filter) {
    currentFilter = filter;
    
    // Update active filter button
    document.querySelectorAll('.filter-btn').forEach(btn => {
        btn.classList.remove('active');
    });
    event.target.classList.add('active');
    
    loadTodos();
}

// ============================================================================
// Download Functions
// ============================================================================

let downloadInterval = null;

async function loadDownloads() {
    try {
        const response = await fetch(`${API_BASE}/api/downloads`);
        const downloads = await response.json();
        
        displayDownloads(downloads);
        
        // Auto-refresh if there are active downloads
        const hasActive = downloads.some(d => d.status === 'downloading' || d.status === 'queued');
        
        if (hasActive && !downloadInterval) {
            downloadInterval = setInterval(loadDownloads, 5000); // 5 seconds for active downloads
        } else if (!hasActive && downloadInterval) {
            clearInterval(downloadInterval);
            downloadInterval = null;
        }
    } catch (error) {
        console.error('Failed to load downloads:', error);
    }
}

function displayDownloads(downloads) {
    const downloadsList = document.getElementById('downloads-list');
    const downloadsEmpty = document.getElementById('downloads-empty');
    
    if (downloads.length === 0) {
        downloadsList.style.display = 'none';
        downloadsEmpty.style.display = 'flex';
        return;
    }
    
    downloadsList.style.display = 'block';
    downloadsEmpty.style.display = 'none';
    
    downloadsList.innerHTML = downloads.map(download => {
        const statusColors = {
            queued: '#6b7280',
            downloading: '#3b82f6',
            completed: '#10b981',
            failed: '#ef4444'
        };
        
        const statusLabels = {
            queued: 'Queued',
            downloading: 'Downloading',
            completed: 'Completed',
            failed: 'Failed'
        };
        
        return `
            <div class="download-item ${download.status}" data-id="${download.id}">
                <div class="download-status-badge" style="background: ${statusColors[download.status]}">
                    ${statusLabels[download.status]}
                </div>
                <div class="download-content">
                    <div class="download-filename">${escapeHtml(download.filename)}</div>
                    <div class="download-url">${escapeHtml(download.url.substring(0, 60))}...</div>
                    
                    ${download.status === 'downloading' ? `
                        <div class="download-progress">
                            <div class="progress-bar">
                                <div class="progress-fill" style="width: ${download.progress}%; background: ${statusColors[download.status]}"></div>
                            </div>
                            <div class="progress-text">${download.progress}% - ${formatBytes(download.downloaded)} / ${formatBytes(download.size)}</div>
                        </div>
                    ` : ''}
                    
                    ${download.status === 'completed' ? `
                        <div class="download-size">${formatBytes(download.size)}</div>
                    ` : ''}
                    
                    ${download.status === 'failed' ? `
                        <div class="download-error">Error: ${escapeHtml(download.error)}</div>
                    ` : ''}
                </div>
                <div class="download-actions">
                    ${download.status === 'completed' ? `
                        <a href="${API_BASE}/api/downloads/${download.id}/file" 
                           class="icon-btn" download title="Download File">
                            Download
                        </a>
                    ` : ''}
                    <button class="icon-btn" onclick="deleteDownload('${download.id}')" title="Delete">
                        Delete
                    </button>
                </div>
            </div>
        `;
    }).join('');
}

async function addDownload(event) {
    event.preventDefault();
    
    const url = document.getElementById('download-url').value;
    
    try {
        const response = await fetch(`${API_BASE}/api/downloads`, {
            method: 'POST',
            headers: {'Content-Type': 'application/json'},
            body: JSON.stringify({ url })
        });
        
        const result = await response.json();
        
        if (result.success) {
            document.getElementById('download-url').value = '';
            loadDownloads();
            showToast('Download started!', 'success');
        } else {
            showToast(result.error || 'Failed to start download', 'error');
        }
    } catch (error) {
        showToast('Failed to start download', 'error');
    }
}

async function deleteDownload(downloadId) {
    if (!confirm('Delete this download?')) return;
    
    try {
        await fetch(`${API_BASE}/api/downloads/${downloadId}`, {
            method: 'DELETE'
        });
        loadDownloads();
        showToast('Download deleted', 'success');
    } catch (error) {
        showToast('Failed to delete download', 'error');
    }
}

// Utility functions
function escapeHtml(text) {
    if (!text) return '';
    return text.toString()
        .replace(/&/g, "&amp;")
        .replace(/</g, "&lt;")
        .replace(/>/g, "&gt;")
        .replace(/"/g, "&quot;")
        .replace(/'/g, "&#039;");
}

function formatBytes(bytes) {
    if (bytes === 0) return '0 B';
    const k = 1024;
    const sizes = ['B', 'KB', 'MB', 'GB'];
    const i = Math.floor(Math.log(bytes) / Math.log(k));
    return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i];
}

// Initialize
document.addEventListener('DOMContentLoaded', () => {
    // Restore last active tab
    const lastTab = localStorage.getItem('activeTab') || 'dashboard';
    switchTab(lastTab);

    // Only auto-update dashboard tab
    updateDashboard();
    
    // Slower, less frequent updates
    setInterval(() => {
        const activeTab = document.querySelector('.tab-btn.active')?.dataset.tab;
        if (activeTab === 'dashboard') {
            updateDashboard();
        }
    }, UPDATE_INTERVAL);
});
