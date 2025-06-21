#!/bin/sh
# Hardware Monitoring Module for ArchCare
# Monitors CPU/GPU temperatures, disk health, memory usage, and system sensors
# Compatible with all Arch-based distributions
# Version: 1.0.0

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# Thresholds (in Celsius)
CPU_TEMP_WARN=70
CPU_TEMP_CRITICAL=85
GPU_TEMP_WARN=75
GPU_TEMP_CRITICAL=90
DISK_TEMP_WARN=45
DISK_TEMP_CRITICAL=55

# Memory usage thresholds (percentage)
MEMORY_WARN=80
MEMORY_CRITICAL=90

# Print functions
print_header() {
    printf "${PURPLE}=== %s ===${NC}\n" "$1"
}

print_info() {
    printf "${CYAN}%s${NC}\n" "$1"
}

print_warning() {
    printf "${YELLOW}⚠️  %s${NC}\n" "$1"
}

print_critical() {
    printf "${RED}🚨 %s${NC}\n" "$1"
}

print_good() {
    printf "${GREEN}✅ %s${NC}\n" "$1"
}

print_step() {
    printf "${WHITE}→${NC} %s\n" "$1"
}

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Install missing packages if needed
check_dependencies() {
    MISSING_PACKAGES=""
    
    # Check for lm_sensors
    if ! command_exists sensors; then
        MISSING_PACKAGES="$MISSING_PACKAGES lm_sensors"
    fi
    
    # Check for smartmontools
    if ! command_exists smartctl; then
        MISSING_PACKAGES="$MISSING_PACKAGES smartmontools"
    fi
    
    # Check for hdparm
    if ! command_exists hdparm; then
        MISSING_PACKAGES="$MISSING_PACKAGES hdparm"
    fi
    
    if [ -n "$MISSING_PACKAGES" ]; then
        print_warning "Missing packages for full hardware monitoring:$MISSING_PACKAGES"
        printf "${YELLOW}Install with: ${WHITE}sudo pacman -S$MISSING_PACKAGES${NC}\n"
        echo
    fi
}

# Get CPU temperature
get_cpu_temperature() {
    print_step "CPU Temperature Monitoring"
    
    CPU_TEMPS=""
    
    # Method 1: lm_sensors
    if command_exists sensors; then
        CPU_TEMPS=$(sensors 2>/dev/null | grep -E "Core [0-9]+|Tctl|Package id" | grep -oE '[0-9]+\.[0-9]+°C' | grep -oE '[0-9]+\.[0-9]+')
    fi
    
    # Method 2: Direct thermal zone reading
    if [ -z "$CPU_TEMPS" ] && [ -d /sys/class/thermal ]; then
        for thermal_zone in /sys/class/thermal/thermal_zone*/temp; do
            if [ -r "$thermal_zone" ]; then
                temp_millic=$(cat "$thermal_zone")
                temp_c=$((temp_millic / 1000))
                if [ "$temp_c" -gt 30 ] && [ "$temp_c" -lt 150 ]; then
                    CPU_TEMPS="$CPU_TEMPS $temp_c.0"
                fi
            fi
        done
    fi
    
    if [ -n "$CPU_TEMPS" ]; then
        for temp in $CPU_TEMPS; do
            temp_int=$(echo "$temp" | cut -d. -f1)
            if [ "$temp_int" -ge "$CPU_TEMP_CRITICAL" ]; then
                print_critical "CPU Core: ${temp}°C (CRITICAL - Above ${CPU_TEMP_CRITICAL}°C)"
            elif [ "$temp_int" -ge "$CPU_TEMP_WARN" ]; then
                print_warning "CPU Core: ${temp}°C (HIGH - Above ${CPU_TEMP_WARN}°C)"
            else
                print_good "CPU Core: ${temp}°C (Normal)"
            fi
        done
    else
        print_info "CPU temperature: Unable to read (no thermal sensors found)"
    fi
    
    echo
}

# Get GPU temperature
get_gpu_temperature() {
    print_step "GPU Temperature Monitoring"
    
    # NVIDIA GPU
    if command_exists nvidia-smi; then
        GPU_TEMP=$(nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader,nounits 2>/dev/null)
        if [ -n "$GPU_TEMP" ] && [ "$GPU_TEMP" != "N/A" ]; then
            if [ "$GPU_TEMP" -ge "$GPU_TEMP_CRITICAL" ]; then
                print_critical "NVIDIA GPU: ${GPU_TEMP}°C (CRITICAL - Above ${GPU_TEMP_CRITICAL}°C)"
            elif [ "$GPU_TEMP" -ge "$GPU_TEMP_WARN" ]; then
                print_warning "NVIDIA GPU: ${GPU_TEMP}°C (HIGH - Above ${GPU_TEMP_WARN}°C)"
            else
                print_good "NVIDIA GPU: ${GPU_TEMP}°C (Normal)"
            fi
        fi
    fi
    
    # AMD GPU (through sensors)
    if command_exists sensors; then
        AMD_TEMP=$(sensors 2>/dev/null | grep -i "junction\|edge" | grep -oE '[0-9]+\.[0-9]+°C' | head -1 | grep -oE '[0-9]+\.[0-9]+')
        if [ -n "$AMD_TEMP" ]; then
            temp_int=$(echo "$AMD_TEMP" | cut -d. -f1)
            if [ "$temp_int" -ge "$GPU_TEMP_CRITICAL" ]; then
                print_critical "AMD GPU: ${AMD_TEMP}°C (CRITICAL - Above ${GPU_TEMP_CRITICAL}°C)"
            elif [ "$temp_int" -ge "$GPU_TEMP_WARN" ]; then
                print_warning "AMD GPU: ${AMD_TEMP}°C (HIGH - Above ${GPU_TEMP_WARN}°C)"
            else
                print_good "AMD GPU: ${AMD_TEMP}°C (Normal)"
            fi
        fi
    fi
    
    # Intel integrated graphics
    if [ -f /sys/class/drm/card0/device/hwmon/hwmon*/temp1_input ]; then
        for temp_file in /sys/class/drm/card0/device/hwmon/hwmon*/temp1_input; do
            if [ -r "$temp_file" ]; then
                temp_millic=$(cat "$temp_file")
                temp_c=$((temp_millic / 1000))
                if [ "$temp_c" -gt 20 ] && [ "$temp_c" -lt 150 ]; then
                    if [ "$temp_c" -ge "$GPU_TEMP_CRITICAL" ]; then
                        print_critical "Intel GPU: ${temp_c}°C (CRITICAL - Above ${GPU_TEMP_CRITICAL}°C)"
                    elif [ "$temp_c" -ge "$GPU_TEMP_WARN" ]; then
                        print_warning "Intel GPU: ${temp_c}°C (HIGH - Above ${GPU_TEMP_WARN}°C)"
                    else
                        print_good "Intel GPU: ${temp_c}°C (Normal)"
                    fi
                    break
                fi
            fi
        done
    fi
    
    # If no GPU found
    if ! command_exists nvidia-smi && ! command_exists sensors; then
        print_info "GPU temperature: No supported GPU found or drivers not installed"
    fi
    
    echo
}

# Check disk health and temperature
get_disk_health() {
    print_step "Disk Health Monitoring"
    
    if ! command_exists smartctl; then
        print_info "smartctl not available - install smartmontools for disk health monitoring"
        echo
        return
    fi
    
    # Get all disk devices
    for disk in /dev/sd? /dev/nvme?n? /dev/mmcblk?; do
        if [ -e "$disk" ]; then
            DISK_NAME=$(basename "$disk")
            
            # Get SMART health status
            SMART_STATUS=$(sudo smartctl -H "$disk" 2>/dev/null | grep "SMART overall-health" | awk '{print $NF}')
            
            if [ "$SMART_STATUS" = "PASSED" ]; then
                print_good "Disk $DISK_NAME: SMART Status PASSED"
            elif [ -n "$SMART_STATUS" ]; then
                print_critical "Disk $DISK_NAME: SMART Status $SMART_STATUS"
            fi
            
            # Get disk temperature
            DISK_TEMP=$(sudo smartctl -A "$disk" 2>/dev/null | grep -i temperature | head -1 | awk '{print $10}')
            if [ -n "$DISK_TEMP" ] && [ "$DISK_TEMP" -gt 0 ] 2>/dev/null; then
                if [ "$DISK_TEMP" -ge "$DISK_TEMP_CRITICAL" ]; then
                    print_critical "Disk $DISK_NAME: Temperature ${DISK_TEMP}°C (CRITICAL - Above ${DISK_TEMP_CRITICAL}°C)"
                elif [ "$DISK_TEMP" -ge "$DISK_TEMP_WARN" ]; then
                    print_warning "Disk $DISK_NAME: Temperature ${DISK_TEMP}°C (HIGH - Above ${DISK_TEMP_WARN}°C)"
                else
                    print_good "Disk $DISK_NAME: Temperature ${DISK_TEMP}°C (Normal)"
                fi
            fi
            
            # Get disk usage percentage
            DISK_USAGE=$(df -h "$disk"1 2>/dev/null | tail -1 | awk '{print $5}' | sed 's/%//')
            if [ -n "$DISK_USAGE" ] 2>/dev/null; then
                if [ "$DISK_USAGE" -ge 95 ]; then
                    print_critical "Disk $DISK_NAME: Usage ${DISK_USAGE}% (CRITICAL - Nearly full)"
                elif [ "$DISK_USAGE" -ge 85 ]; then
                    print_warning "Disk $DISK_NAME: Usage ${DISK_USAGE}% (HIGH - Consider cleanup)"
                else
                    print_good "Disk $DISK_NAME: Usage ${DISK_USAGE}% (Normal)"
                fi
            fi
        fi
    done
    
    echo
}

# Check memory usage
get_memory_status() {
    print_step "Memory Usage Monitoring"
    
    if command_exists free; then
        # Get memory information
        MEMORY_INFO=$(free | grep '^Mem:')
        TOTAL_MEM=$(echo "$MEMORY_INFO" | awk '{print $2}')
        USED_MEM=$(echo "$MEMORY_INFO" | awk '{print $3}')
        AVAILABLE_MEM=$(echo "$MEMORY_INFO" | awk '{print $7}')
        
        # Calculate percentages
        USED_PERCENT=$((USED_MEM * 100 / TOTAL_MEM))
        AVAILABLE_PERCENT=$((AVAILABLE_MEM * 100 / TOTAL_MEM))
        
        # Convert to human readable
        TOTAL_GB=$(awk "BEGIN {printf \"%.1f\", $TOTAL_MEM/1024/1024}")
        USED_GB=$(awk "BEGIN {printf \"%.1f\", $USED_MEM/1024/1024}")
        AVAILABLE_GB=$(awk "BEGIN {printf \"%.1f\", $AVAILABLE_MEM/1024/1024}")
        
        if [ "$USED_PERCENT" -ge "$MEMORY_CRITICAL" ]; then
            print_critical "Memory: ${USED_GB}GB/${TOTAL_GB}GB used (${USED_PERCENT}%) - CRITICAL"
        elif [ "$USED_PERCENT" -ge "$MEMORY_WARN" ]; then
            print_warning "Memory: ${USED_GB}GB/${TOTAL_GB}GB used (${USED_PERCENT}%) - HIGH"
        else
            print_good "Memory: ${USED_GB}GB/${TOTAL_GB}GB used (${USED_PERCENT}%) - Normal"
        fi
        
        print_info "Available: ${AVAILABLE_GB}GB (${AVAILABLE_PERCENT}%)"
        
        # Check swap usage
        SWAP_INFO=$(free | grep '^Swap:')
        SWAP_TOTAL=$(echo "$SWAP_INFO" | awk '{print $2}')
        SWAP_USED=$(echo "$SWAP_INFO" | awk '{print $3}')
        
        if [ "$SWAP_TOTAL" -gt 0 ]; then
            SWAP_PERCENT=$((SWAP_USED * 100 / SWAP_TOTAL))
            SWAP_USED_GB=$(awk "BEGIN {printf \"%.1f\", $SWAP_USED/1024/1024}")
            SWAP_TOTAL_GB=$(awk "BEGIN {printf \"%.1f\", $SWAP_TOTAL/1024/1024}")
            
            if [ "$SWAP_PERCENT" -ge 50 ]; then
                print_warning "Swap: ${SWAP_USED_GB}GB/${SWAP_TOTAL_GB}GB used (${SWAP_PERCENT}%) - HIGH"
            else
                print_good "Swap: ${SWAP_USED_GB}GB/${SWAP_TOTAL_GB}GB used (${SWAP_PERCENT}%)"
            fi
        else
            print_info "Swap: Not configured"
        fi
    fi
    
    echo
}

# Check system load
get_system_load() {
    print_step "System Load Monitoring"
    
    # Get load averages
    LOAD_AVG=$(uptime | awk -F'load average:' '{print $2}' | sed 's/^ *//')
    LOAD_1MIN=$(echo "$LOAD_AVG" | awk -F',' '{print $1}' | tr -d ' ')
    LOAD_5MIN=$(echo "$LOAD_AVG" | awk -F',' '{print $2}' | tr -d ' ')
    LOAD_15MIN=$(echo "$LOAD_AVG" | awk -F',' '{print $3}' | tr -d ' ')
    
    # Get CPU count
    CPU_COUNT=$(nproc)
    
    print_info "Load Average: 1min=${LOAD_1MIN}, 5min=${LOAD_5MIN}, 15min=${LOAD_15MIN}"
    print_info "CPU Cores: $CPU_COUNT"
    
    # Check if load is high (load average > CPU count)
    LOAD_1_INT=$(echo "$LOAD_1MIN" | cut -d. -f1)
    if [ "$LOAD_1_INT" -gt "$CPU_COUNT" ]; then
        print_warning "System load is high (${LOAD_1MIN} > ${CPU_COUNT} cores)"
    else
        print_good "System load is normal"
    fi
    
    echo
}

# Check battery status (for laptops)
get_battery_status() {
    print_step "Battery Status Monitoring"
    
    BATTERY_FOUND=false
    
    # Check for battery in /sys/class/power_supply/
    for battery in /sys/class/power_supply/BAT*; do
        if [ -d "$battery" ]; then
            BATTERY_FOUND=true
            BATTERY_NAME=$(basename "$battery")
            
            # Get battery capacity
            if [ -f "$battery/capacity" ]; then
                CAPACITY=$(cat "$battery/capacity")
                if [ "$CAPACITY" -le 15 ]; then
                    print_critical "Battery $BATTERY_NAME: ${CAPACITY}% (CRITICAL - Low battery)"
                elif [ "$CAPACITY" -le 30 ]; then
                    print_warning "Battery $BATTERY_NAME: ${CAPACITY}% (LOW - Consider charging)"
                else
                    print_good "Battery $BATTERY_NAME: ${CAPACITY}%"
                fi
            fi
            
            # Get battery status
            if [ -f "$battery/status" ]; then
                STATUS=$(cat "$battery/status")
                case "$STATUS" in
                    "Charging") print_info "Status: Charging" ;;
                    "Discharging") print_info "Status: Discharging" ;;
                    "Full") print_good "Status: Fully charged" ;;
                    "Not charging") print_warning "Status: Not charging" ;;
                    *) print_info "Status: $STATUS" ;;
                esac
            fi
            
            # Get battery health (if available)
            if [ -f "$battery/health" ]; then
                HEALTH=$(cat "$battery/health")
                print_info "Health: $HEALTH"
            fi
        fi
    done
    
    if [ "$BATTERY_FOUND" = false ]; then
        print_info "No battery detected (desktop system)"
    fi
    
    echo
}

# Main hardware monitoring function
run_hardware_monitor() {
    print_header "Hardware Health Monitoring"
    
    # Check dependencies
    check_dependencies
    
    # Run all monitoring functions
    get_cpu_temperature
    get_gpu_temperature
    get_disk_health
    get_memory_status
    get_system_load
    get_battery_status
    
    print_header "Hardware Monitoring Complete"
}

# If script is run directly
if [ "${0##*/}" = "hardware_monitor.sh" ]; then
    run_hardware_monitor
fi 