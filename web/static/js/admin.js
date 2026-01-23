// Admin JavaScript utilities

// Format number with commas
function formatNumber(num) {
    return num.toLocaleString();
}

// Format duration string
function formatDuration(duration) {
    // Parse duration string like "2h30m15s"
    const match = duration.match(/(\d+h)?(\d+m)?(\d+s)?/);
    if (!match) return duration;
    
    let result = [];
    if (match[1]) result.push(match[1]);
    if (match[2]) result.push(match[2]);
    if (match[3]) result.push(match[3]);
    
    return result.join(' ') || duration;
}

// Get API key from query parameter or localStorage
function getApiKey() {
    const urlParams = new URLSearchParams(window.location.search);
    const apiKey = urlParams.get('api_key');
    if (apiKey) {
        localStorage.setItem('admin_api_key', apiKey);
        return apiKey;
    }
    return localStorage.getItem('admin_api_key');
}

// Add API key to fetch requests
function fetchWithAuth(url, options = {}) {
    const apiKey = getApiKey();
    if (apiKey) {
        if (!options.headers) {
            options.headers = {};
        }
        options.headers['X-API-Key'] = apiKey;
    }
    return fetch(url, options);
}

// Show notification
function showNotification(message, type = 'info') {
    const notification = document.createElement('div');
    notification.className = `notification notification-${type}`;
    notification.textContent = message;
    document.body.appendChild(notification);
    
    setTimeout(() => {
        notification.classList.add('show');
    }, 10);
    
    setTimeout(() => {
        notification.classList.remove('show');
        setTimeout(() => {
            document.body.removeChild(notification);
        }, 300);
    }, 3000);
}

// Add notification styles if not already present
if (!document.getElementById('notification-styles')) {
    const style = document.createElement('style');
    style.id = 'notification-styles';
    style.textContent = `
        .notification {
            position: fixed;
            top: 20px;
            right: 20px;
            padding: 1rem 1.5rem;
            border-radius: 4px;
            box-shadow: 0 2px 8px rgba(0,0,0,0.2);
            z-index: 1000;
            opacity: 0;
            transform: translateX(100%);
            transition: all 0.3s ease;
        }
        .notification.show {
            opacity: 1;
            transform: translateX(0);
        }
        .notification-info {
            background-color: #3498db;
            color: white;
        }
        .notification-success {
            background-color: #27ae60;
            color: white;
        }
        .notification-error {
            background-color: #e74c3c;
            color: white;
        }
    `;
    document.head.appendChild(style);
}



