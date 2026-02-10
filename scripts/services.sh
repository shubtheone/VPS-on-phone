#!/data/data/com.termux/files/usr/bin/bash

#==============================================================================
#  Service Management Script
#  Start, stop, and monitor VPS services
#==============================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# Service definitions
declare -A SERVICES=(
    [ssh]="/usr/sbin/sshd"
    [nginx]="nginx"
    [mariadb]="mysqld_safe"
    [redis]="redis-server --daemonize yes"
    [filebrowser]="filebrowser -d /var/lib/filebrowser/filebrowser.db"
    [dashboard]="cd /opt/vps-dashboard && source venv/bin/activate && python3 app.py"
)

run_in_ubuntu() {
    proot-distro login ubuntu -- bash -c "$1"
}

start_service() {
    local service=$1
    echo -e "${CYAN}Starting $service...${NC}"
    
    case $service in
        ssh)
            run_in_ubuntu "/usr/sbin/sshd"
            ;;
        nginx)
            run_in_ubuntu "nginx"
            ;;
        mariadb)
            run_in_ubuntu "mysqld_safe &"
            ;;
        redis)
            run_in_ubuntu "redis-server --daemonize yes"
            ;;
        filebrowser)
            run_in_ubuntu "filebrowser -d /var/lib/filebrowser/filebrowser.db --baseURL /filebrowser &"
            ;;
        dashboard)
            run_in_ubuntu "cd /opt/vps-dashboard && source venv/bin/activate && nohup python3 app.py > /var/log/dashboard.log 2>&1 &"
            ;;
        *)
            echo -e "${RED}Unknown service: $service${NC}"
            return 1
            ;;
    esac
    
    echo -e "${GREEN}$service started${NC}"
}

stop_service() {
    local service=$1
    echo -e "${CYAN}Stopping $service...${NC}"
    
    case $service in
        ssh) run_in_ubuntu "pkill sshd" ;;
        nginx) run_in_ubuntu "nginx -s stop" ;;
        mariadb) run_in_ubuntu "mysqladmin shutdown" ;;
        redis) run_in_ubuntu "redis-cli shutdown" ;;
        filebrowser) run_in_ubuntu "pkill filebrowser" ;;
        dashboard) run_in_ubuntu "pkill -f 'python3 app.py'" ;;
        *) echo -e "${RED}Unknown service: $service${NC}"; return 1 ;;
    esac
    
    echo -e "${GREEN}$service stopped${NC}"
}

status_service() {
    local service=$1
    local running=false
    
    case $service in
        ssh) run_in_ubuntu "pgrep sshd" &>/dev/null && running=true ;;
        nginx) run_in_ubuntu "pgrep nginx" &>/dev/null && running=true ;;
        mariadb) run_in_ubuntu "pgrep mysqld" &>/dev/null && running=true ;;
        redis) run_in_ubuntu "pgrep redis-server" &>/dev/null && running=true ;;
        filebrowser) run_in_ubuntu "pgrep filebrowser" &>/dev/null && running=true ;;
        dashboard) run_in_ubuntu "pgrep -f 'python3 app.py'" &>/dev/null && running=true ;;
    esac
    
    if $running; then
        echo -e "${GREEN}●${NC} $service: ${GREEN}running${NC}"
    else
        echo -e "${RED}○${NC} $service: ${RED}stopped${NC}"
    fi
}

start_all() {
    echo -e "${CYAN}Starting all services...${NC}"
    termux-wake-lock
    for service in ssh nginx dashboard; do
        start_service $service
        sleep 1
    done
}

stop_all() {
    echo -e "${CYAN}Stopping all services...${NC}"
    for service in ssh nginx mariadb redis filebrowser dashboard; do
        stop_service $service 2>/dev/null
    done
    termux-wake-unlock
}

status_all() {
    echo -e "\n${CYAN}Service Status:${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━"
    for service in ssh nginx mariadb redis filebrowser dashboard; do
        status_service $service
    done
    echo ""
}

show_help() {
    echo "Usage: $0 {start|stop|restart|status} [service]"
    echo ""
    echo "Services: ssh, nginx, mariadb, redis, filebrowser, dashboard"
    echo ""
    echo "Examples:"
    echo "  $0 start           - Start all services"
    echo "  $0 start nginx     - Start nginx"
    echo "  $0 stop            - Stop all services"
    echo "  $0 status          - Show all service status"
}

# Main
case "$1" in
    start)
        if [ -z "$2" ]; then
            start_all
        else
            start_service "$2"
        fi
        ;;
    stop)
        if [ -z "$2" ]; then
            stop_all
        else
            stop_service "$2"
        fi
        ;;
    restart)
        if [ -z "$2" ]; then
            stop_all
            sleep 2
            start_all
        else
            stop_service "$2"
            sleep 1
            start_service "$2"
        fi
        ;;
    status)
        status_all
        ;;
    *)
        show_help
        ;;
esac
