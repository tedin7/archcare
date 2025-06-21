#!/bin/bash
# ArchCare Performance Monitoring & Optimization
# Comprehensive system performance analysis and tuning
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

# Script configuration
SCRIPT_NAME="ArchCare Performance Optimizer"
LOG_DIR="../logs"
PERFORMANCE_LOG="$LOG_DIR/performance.log"

# Performance thresholds
CPU_USAGE_THRESHOLD=80
MEMORY_USAGE_THRESHOLD=85
DISK_USAGE_THRESHOLD=90
SWAP_USAGE_THRESHOLD=50

# Initialize logging
init_logging() {
    mkdir -p "$LOG_DIR"
    echo "=== Performance Analysis Session: $(date) ===" >> "$PERFORMANCE_LOG"
}

# Logging functions
log_info() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [INFO] $1" >> "$PERFORMANCE_LOG"
}

log_warning() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [WARNING] $1" >> "$PERFORMANCE_LOG"
}

log_success() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [SUCCESS] $1" >> "$PERFORMANCE_LOG"
}

# Print colored output
print_header() {
    printf "${PURPLE}=== %s ===${NC}\n" "$1"
}

print_info() {
    printf "${CYAN}%s${NC}\n" "$1"
}

print_step() {
    printf "${WHITE}→${NC} %s\n" "$1"
}

print_good() {
    printf "${GREEN}✅ %s${NC}\n" "$1"
}

print_warning() {
    printf "${YELLOW}⚠️  %s${NC}\n" "$1"
}

print_error() {
    printf "${RED}❌ %s${NC}\n" "$1"
}

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check if running as root (for some optimizations)
check_sudo_available() {
    if sudo -n true 2>/dev/null; then
        return 0
    else
        return 1
    fi
}

# =============================================================================
# CPU OPTIMIZATION & MONITORING
# =============================================================================

analyze_cpu_performance() {
    print_header "CPU Performance Analysis"
    
    # Basic CPU information
    print_step "CPU Information:"
    CPU_MODEL=$(lscpu | grep "Model name" | cut -d: -f2 | xargs)
    CPU_CORES=$(nproc)
    CPU_THREADS=$(lscpu | grep "^CPU(s):" | cut -d: -f2 | xargs)
    
    print_info "Model: $CPU_MODEL"
    print_info "Cores: $CPU_CORES | Threads: $CPU_THREADS"
    
    # Current CPU usage
    print_step "Current CPU Usage:"
    CPU_USAGE=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | sed 's/%us,//')
    print_info "CPU Usage: ${CPU_USAGE}%"
    
    CPU_USAGE_INT=$(echo "$CPU_USAGE" | sed 's/,/./' | cut -d. -f1)
    if [ "$CPU_USAGE_INT" -gt "$CPU_USAGE_THRESHOLD" ]; then
        print_warning "High CPU usage detected: ${CPU_USAGE}%"
        log_warning "High CPU usage: ${CPU_USAGE}%"
    else
        print_good "CPU usage is normal: ${CPU_USAGE}%"
    fi
    
    # Check CPU frequency scaling driver
    print_step "CPU Frequency Scaling:"
    if [ -f /sys/devices/system/cpu/cpu0/cpufreq/scaling_driver ]; then
        SCALING_DRIVER=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_driver)
        print_info "Scaling Driver: $SCALING_DRIVER"
        
        # Handle AMD P-State EPP (modern AMD approach)
        if [[ "$SCALING_DRIVER" == *"amd-pstate"* ]]; then
            print_good "✅ Using modern AMD P-State driver!"
            
            # Check Energy Performance Preference
            if [ -f /sys/devices/system/cpu/cpu0/cpufreq/energy_performance_preference ]; then
                CURRENT_EPP=$(cat /sys/devices/system/cpu/cpu0/cpufreq/energy_performance_preference)
                print_info "Energy Performance Preference (EPP): $CURRENT_EPP"
                
                # Available EPP options
                if [ -f /sys/devices/system/cpu/cpu0/cpufreq/energy_performance_available_preferences ]; then
                    AVAILABLE_EPP=$(cat /sys/devices/system/cpu/cpu0/cpufreq/energy_performance_available_preferences)
                    print_info "Available EPP Options: $AVAILABLE_EPP"
                fi
                
                # EPP recommendations
                case "$CURRENT_EPP" in
                    "performance")
                        print_info "✅ Using performance EPP - maximum performance"
                        print_info "   AMD P-State EPP provides intelligent hardware-level scaling"
                        ;;
                    "balance_performance")
                        print_good "✅ Using balance_performance EPP - optimal choice!"
                        print_info "   Good balance of performance and efficiency"
                        ;;
                    "balance_power"|"balanced")
                        print_info "⚡ Using balanced EPP - efficiency focused"
                        ;;
                    "power")
                        print_warning "⚠️  Using power EPP - maximum power saving"
                        print_info "   Consider balance_performance for better responsiveness"
                        ;;
                    *)
                        print_info "Using $CURRENT_EPP EPP setting"
                        ;;
                esac
            fi
        else
            # Traditional governor-based approach
            if [ -f /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor ]; then
                CURRENT_GOVERNOR=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor)
                print_info "Current Governor: $CURRENT_GOVERNOR"
                
                # Available governors
                if [ -f /sys/devices/system/cpu/cpu0/cpufreq/scaling_available_governors ]; then
                    AVAILABLE_GOVERNORS=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_available_governors)
                    print_info "Available Governors: $AVAILABLE_GOVERNORS"
                fi
                
                # Governor recommendations
                case "$CURRENT_GOVERNOR" in
                    "powersave")
                        print_warning "❌ Using powersave governor - poor performance"
                        print_info "   Recommendation: Switch to 'schedutil' for intelligent scaling"
                        ;;
                    "performance")
                        print_warning "⚠️  Using performance governor - high power consumption"
                        print_info "   Recommendation: Switch to 'schedutil' for efficiency without sacrificing performance"
                        ;;
                    "schedutil")
                        print_good "✅ Using schedutil governor - optimal choice!"
                        print_info "   schedutil provides intelligent performance scaling with energy efficiency"
                        ;;
                    "ondemand")
                        print_info "✅ Using ondemand governor - good dynamic scaling"
                        print_info "   Note: schedutil is more modern and responsive than ondemand"
                        ;;
                    "conservative")
                        print_info "⚠️  Using conservative governor - gradual scaling"
                        print_info "   Recommendation: Consider 'schedutil' for better responsiveness"
                        ;;
                    *)
                        print_info "Using $CURRENT_GOVERNOR governor"
                        print_info "   Recommendation: Switch to 'schedutil' if available"
                        ;;
                esac
            fi
        fi
        
        # CPU frequency information
        if [ -f /sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq ]; then
            CURRENT_FREQ=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq)
            CURRENT_FREQ_MHZ=$((CURRENT_FREQ / 1000))
            print_info "Current Frequency: ${CURRENT_FREQ_MHZ} MHz"
        fi
    else
        print_warning "CPU frequency scaling not available or not accessible"
    fi
    
    # Top CPU consuming processes
    print_step "Top CPU Consuming Processes:"
    ps aux --sort=-%cpu | head -6 | tail -5 | while read line; do
        printf "${YELLOW}  %s${NC}\n" "$line"
    done
    
    echo
}

optimize_cpu_performance() {
    print_header "CPU Performance Optimization"
    
    if ! check_sudo_available; then
        print_warning "Sudo access required for CPU optimizations. Skipping..."
        return 1
    fi
    
    print_step "Optimizing CPU governor..."
    
    # Check if schedutil is supported
    if ! echo "$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_available_governors 2>/dev/null)" | grep -q "schedutil"; then
        print_info "💡 schedutil governor not available on this system"
        print_info "   This usually means the kernel doesn't have CONFIG_CPU_FREQ_GOV_SCHEDUTIL=y"
        print_info "   schedutil requires kernel 4.7+ with proper configuration"
        
        # Check current kernel and provide recommendations
        KERNEL_VERSION=$(uname -r)
        if [[ $KERNEL_VERSION == *"zen"* ]]; then
            print_info "   🔧 To enable schedutil on zen kernel:"
            print_info "   1. Check if a newer zen kernel version includes schedutil"
            print_info "   2. Or switch to the standard linux kernel: sudo pacman -S linux"
            print_info "   3. Or compile a custom kernel with CONFIG_CPU_FREQ_GOV_SCHEDUTIL=y"
        elif [[ $KERNEL_VERSION == *"lts"* ]]; then
            print_info "   🔧 LTS kernel detected. Try: sudo pacman -S linux (for latest kernel)"
        else
            print_info "   🔧 Try updating kernel: sudo pacman -Syu"
            print_info "   🔧 Or check kernel config: zcat /proc/config.gz | grep SCHEDUTIL"
        fi
    fi
    
    # Check what scaling driver is being used
    if [ -f /sys/devices/system/cpu/cpu0/cpufreq/scaling_driver ]; then
        SCALING_DRIVER=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_driver)
        
        # Handle AMD P-State EPP systems
        if [[ "$SCALING_DRIVER" == *"amd-pstate"* ]]; then
            print_step "Optimizing AMD P-State Energy Performance Preference..."
            
            if [ -f /sys/devices/system/cpu/cpu0/cpufreq/energy_performance_available_preferences ]; then
                AVAILABLE_EPP=$(cat /sys/devices/system/cpu/cpu0/cpufreq/energy_performance_available_preferences)
                CURRENT_EPP=$(cat /sys/devices/system/cpu/cpu0/cpufreq/energy_performance_preference 2>/dev/null)
                
                # Set optimal EPP (balance_performance is usually best)
                if echo "$AVAILABLE_EPP" | grep -q "balance_performance"; then
                    if echo "balance_performance" | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/energy_performance_preference >/dev/null 2>&1; then
                        print_good "✅ Set AMD EPP to 'balance_performance' - optimal balance"
                        print_info "   Hardware-level intelligent scaling with performance priority"
                        log_success "AMD P-State EPP set to balance_performance"
                    fi
                elif echo "$AVAILABLE_EPP" | grep -q "performance" && [ "$CURRENT_EPP" != "performance" ]; then
                    if echo "performance" | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/energy_performance_preference >/dev/null 2>&1; then
                        print_good "✅ AMD EPP already set to 'performance' - maximum performance"
                        print_info "   AMD P-State provides intelligent hardware-level scaling"
                        log_success "AMD P-State EPP confirmed as performance"
                    fi
                else
                    print_good "✅ AMD P-State EPP already optimally configured"
                    print_info "   Current setting: $CURRENT_EPP"
                fi
            else
                print_info "✅ AMD P-State EPP detected but preferences not configurable"
                print_info "   Hardware automatically manages performance scaling"
            fi
        else
            # Traditional governor-based optimization
            if command_exists cpupower; then
                # First, check available governors
                AVAILABLE_GOVERNORS=""
                if [ -f /sys/devices/system/cpu/cpu0/cpufreq/scaling_available_governors ]; then
                    AVAILABLE_GOVERNORS=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_available_governors)
                fi
                
                # Priority order: schedutil > ondemand > performance > powersave
                if echo "$AVAILABLE_GOVERNORS" | grep -q "schedutil"; then
                    if sudo cpupower frequency-set -g schedutil >/dev/null 2>&1; then
                        print_good "✅ Set CPU governor to 'schedutil' - intelligent performance scaling"
                        print_info "   schedutil provides optimal performance with energy efficiency"
                        log_success "CPU governor set to schedutil (optimal choice)"
                    fi
                elif echo "$AVAILABLE_GOVERNORS" | grep -q "ondemand"; then
                    if sudo cpupower frequency-set -g ondemand >/dev/null 2>&1; then
                        print_good "✅ Set CPU governor to 'ondemand' - dynamic scaling"
                        print_info "   ondemand scales frequency based on CPU load"
                        log_success "CPU governor set to ondemand (good alternative)"
                    fi
                elif echo "$AVAILABLE_GOVERNORS" | grep -q "performance"; then
                    if sudo cpupower frequency-set -g performance >/dev/null 2>&1; then
                        print_good "✅ Set CPU governor to 'performance' - maximum performance"
                        print_warning "   Consider enabling schedutil for better efficiency"
                        log_success "CPU governor set to performance (fallback)"
                    fi
                else
                    print_warning "❌ No suitable CPU governor available"
                    print_info "Available governors: $AVAILABLE_GOVERNORS"
                fi
            else
                print_warning "cpupower not available. Install with: sudo pacman -S cpupower"
            fi
        fi
    else
        print_warning "CPU frequency scaling not available"
    fi
    
    # CPU microcode updates check
    print_step "Checking CPU microcode..."
    if command_exists dmesg; then
        MICROCODE_STATUS=$(dmesg | grep -i microcode | tail -1)
        if [ -n "$MICROCODE_STATUS" ]; then
            print_info "Microcode status: $MICROCODE_STATUS"
        fi
    fi
    
    echo
}

# =============================================================================
# MEMORY OPTIMIZATION & MONITORING
# =============================================================================

analyze_memory_performance() {
    print_header "Memory Performance Analysis"
    
    # Basic memory information
    print_step "Memory Information:"
    if command_exists free; then
        MEMORY_INFO=$(free -h | grep "Mem:")
        TOTAL_MEM=$(echo $MEMORY_INFO | awk '{print $2}')
        USED_MEM=$(echo $MEMORY_INFO | awk '{print $3}')
        FREE_MEM=$(echo $MEMORY_INFO | awk '{print $4}')
        AVAILABLE_MEM=$(echo $MEMORY_INFO | awk '{print $7}')
        
        print_info "Total: $TOTAL_MEM | Used: $USED_MEM | Free: $FREE_MEM | Available: $AVAILABLE_MEM"
        
        # Calculate memory usage percentage
        TOTAL_MEM_KB=$(free | grep "Mem:" | awk '{print $2}')
        USED_MEM_KB=$(free | grep "Mem:" | awk '{print $3}')
        MEMORY_USAGE_PERCENT=$((USED_MEM_KB * 100 / TOTAL_MEM_KB))
        
        print_info "Memory Usage: ${MEMORY_USAGE_PERCENT}%"
        
        if [ "$MEMORY_USAGE_PERCENT" -gt "$MEMORY_USAGE_THRESHOLD" ]; then
            print_warning "High memory usage detected: ${MEMORY_USAGE_PERCENT}%"
            log_warning "High memory usage: ${MEMORY_USAGE_PERCENT}%"
        else
            print_good "Memory usage is normal: ${MEMORY_USAGE_PERCENT}%"
        fi
    fi
    
    # Swap information
    print_step "Swap Information:"
    if command_exists free; then
        SWAP_INFO=$(free -h | grep "Swap:")
        TOTAL_SWAP=$(echo $SWAP_INFO | awk '{print $2}')
        USED_SWAP=$(echo $SWAP_INFO | awk '{print $3}')
        FREE_SWAP=$(echo $SWAP_INFO | awk '{print $4}')
        
        if [ "$TOTAL_SWAP" != "0B" ]; then
            print_info "Total Swap: $TOTAL_SWAP | Used: $USED_SWAP | Free: $FREE_SWAP"
            
            # Calculate swap usage percentage
            TOTAL_SWAP_KB=$(free | grep "Swap:" | awk '{print $2}')
            USED_SWAP_KB=$(free | grep "Swap:" | awk '{print $3}')
            
            if [ "$TOTAL_SWAP_KB" -gt 0 ]; then
                SWAP_USAGE_PERCENT=$((USED_SWAP_KB * 100 / TOTAL_SWAP_KB))
                print_info "Swap Usage: ${SWAP_USAGE_PERCENT}%"
                
                if [ "$SWAP_USAGE_PERCENT" -gt "$SWAP_USAGE_THRESHOLD" ]; then
                    print_warning "High swap usage detected: ${SWAP_USAGE_PERCENT}%"
                    log_warning "High swap usage: ${SWAP_USAGE_PERCENT}%"
                else
                    print_good "Swap usage is normal: ${SWAP_USAGE_PERCENT}%"
                fi
            fi
        else
            print_info "No swap configured"
        fi
    fi
    
    # Memory-intensive processes
    print_step "Top Memory Consuming Processes:"
    ps aux --sort=-%mem | head -6 | tail -5 | while read line; do
        printf "${YELLOW}  %s${NC}\n" "$line"
    done
    
    # Check for potential memory leaks
    print_step "Memory Leak Detection:"
    if command_exists ps; then
        # Look for processes with unusually high memory usage
        HIGH_MEM_PROCESSES=$(ps aux --sort=-%mem | awk 'NR>1 && $4>10 {print $11, $4"%"}' | head -3)
        if [ -n "$HIGH_MEM_PROCESSES" ]; then
            print_warning "Processes with high memory usage (>10%):"
            echo "$HIGH_MEM_PROCESSES" | while read line; do
                printf "${YELLOW}  %s${NC}\n" "$line"
            done
        else
            print_good "No processes with excessive memory usage detected"
        fi
    fi
    
    echo
}

optimize_memory_performance() {
    print_header "Memory Performance Optimization"
    
    if ! check_sudo_available; then
        print_warning "Sudo access required for memory optimizations. Skipping..."
        return 1
    fi
    
    # VM swappiness optimization
    print_step "Optimizing VM swappiness..."
    CURRENT_SWAPPINESS=$(cat /proc/sys/vm/swappiness)
    print_info "Current swappiness: $CURRENT_SWAPPINESS"
    
    # Optimal swappiness depends on system type
    TOTAL_MEM_GB=$(free -g | grep "Mem:" | awk '{print $2}')
    if [ "$TOTAL_MEM_GB" -ge 8 ]; then
        OPTIMAL_SWAPPINESS=10
    else
        OPTIMAL_SWAPPINESS=30
    fi
    
    if [ "$CURRENT_SWAPPINESS" -ne "$OPTIMAL_SWAPPINESS" ]; then
        if sudo sysctl vm.swappiness=$OPTIMAL_SWAPPINESS >/dev/null 2>&1; then
            print_good "Set swappiness to $OPTIMAL_SWAPPINESS (optimized for ${TOTAL_MEM_GB}GB RAM)"
            log_success "VM swappiness optimized to $OPTIMAL_SWAPPINESS"
            
            # Make it persistent
            if ! grep -q "vm.swappiness" /etc/sysctl.d/99-performance.conf 2>/dev/null; then
                echo "vm.swappiness=$OPTIMAL_SWAPPINESS" | sudo tee -a /etc/sysctl.d/99-performance.conf >/dev/null
                print_info "Made swappiness setting persistent"
            fi
        fi
    else
        print_good "Swappiness already optimally configured"
    fi
    
    # Memory cache optimization
    print_step "Optimizing memory cache settings..."
    
    # VFS cache pressure
    CURRENT_VFS_PRESSURE=$(cat /proc/sys/vm/vfs_cache_pressure)
    OPTIMAL_VFS_PRESSURE=50
    
    if [ "$CURRENT_VFS_PRESSURE" -ne "$OPTIMAL_VFS_PRESSURE" ]; then
        if sudo sysctl vm.vfs_cache_pressure=$OPTIMAL_VFS_PRESSURE >/dev/null 2>&1; then
            print_good "Optimized VFS cache pressure to $OPTIMAL_VFS_PRESSURE"
            echo "vm.vfs_cache_pressure=$OPTIMAL_VFS_PRESSURE" | sudo tee -a /etc/sysctl.d/99-performance.conf >/dev/null
        fi
    fi
    
    # Drop caches if memory usage is high
    MEMORY_USAGE_PERCENT=$(free | grep "Mem:" | awk '{printf "%.0f", $3/$2 * 100}')
    if [ "$MEMORY_USAGE_PERCENT" -gt 80 ]; then
        print_step "High memory usage detected, dropping caches..."
        if sudo sync && sudo sysctl vm.drop_caches=3 >/dev/null 2>&1; then
            print_good "Memory caches dropped to free up RAM"
            log_success "Memory caches dropped due to high usage"
        fi
    fi
    
    echo
}

# =============================================================================
# DISK OPTIMIZATION & MONITORING
# =============================================================================

analyze_disk_performance() {
    print_header "Disk Performance Analysis"
    
    # Disk usage information
    print_step "Disk Usage Information:"
    df -h | grep -E "^/dev/" | grep -v "/snap/" | while read line; do
        USAGE_PERCENT=$(echo $line | awk '{print $5}' | sed 's/%//')
        MOUNT_POINT=$(echo $line | awk '{print $6}')
        
        if [ "$USAGE_PERCENT" -gt "$DISK_USAGE_THRESHOLD" ]; then
            printf "${RED}  %s${NC}\n" "$line"
            print_warning "High disk usage on $MOUNT_POINT: ${USAGE_PERCENT}%"
            log_warning "High disk usage on $MOUNT_POINT: ${USAGE_PERCENT}%"
        else
            printf "${GREEN}  %s${NC}\n" "$line"
        fi
    done
    
    # Check for SSD drives
    print_step "Storage Device Information:"
    if command_exists lsblk; then
        lsblk -d -o NAME,SIZE,TYPE,ROTA | grep -E "disk" | while read line; do
            DEVICE=$(echo $line | awk '{print $1}')
            ROTA=$(echo $line | awk '{print $4}')
            
            if [ "$ROTA" = "0" ]; then
                print_info "SSD detected: $line"
                # Check TRIM support
                if sudo fstrim -v / >/dev/null 2>&1; then
                    print_good "TRIM is supported and working"
                else
                    print_warning "TRIM may not be properly configured"
                fi
            else
                print_info "HDD detected: $line"
            fi
        done
    fi
    
    # I/O statistics
    print_step "Disk I/O Statistics:"
    if command_exists iostat; then
        iostat -x 1 1 | grep -E "^(Device|[a-z])" | tail -n +2 | while read line; do
            if [[ ! $line =~ ^Device ]]; then
                printf "${CYAN}  %s${NC}\n" "$line"
            fi
        done
    else
        print_warning "iostat not available. Install with: sudo pacman -S sysstat"
    fi
    
    # Check filesystem types
    print_step "Filesystem Information:"
    df -T | grep -E "^/dev/" | while read line; do
        FS_TYPE=$(echo $line | awk '{print $2}')
        MOUNT_POINT=$(echo $line | awk '{print $7}')
        print_info "$MOUNT_POINT: $FS_TYPE"
    done
    
    echo
}

optimize_disk_performance() {
    print_header "Disk Performance Optimization"
    
    if ! check_sudo_available; then
        print_warning "Sudo access required for disk optimizations. Skipping..."
        return 1
    fi
    
    # SSD TRIM optimization
    print_step "Optimizing SSD TRIM..."
    if command_exists fstrim; then
        # Enable periodic TRIM
        if sudo systemctl is-enabled fstrim.timer >/dev/null 2>&1; then
            print_good "Periodic TRIM already enabled"
        else
            if sudo systemctl enable fstrim.timer >/dev/null 2>&1; then
                print_good "Enabled periodic TRIM service"
                log_success "Enabled periodic TRIM for SSDs"
            fi
        fi
        
        # Run TRIM now for all supported filesystems
        print_step "Running TRIM on supported filesystems..."
        sudo fstrim -av 2>/dev/null | while read line; do
            if [[ $line == *"trimmed"* ]]; then
                print_good "$line"
            fi
        done
    fi
    
    # I/O scheduler optimization
    print_step "Optimizing I/O schedulers..."
    for device in /sys/block/*/queue/scheduler; do
        if [ -r "$device" ]; then
            DEVICE_NAME=$(echo $device | cut -d'/' -f4)
            CURRENT_SCHEDULER=$(cat $device | grep -o '\[.*\]' | tr -d '[]')
            
            # Check if it's an SSD (rotational = 0)
            ROTA_FILE="/sys/block/$DEVICE_NAME/queue/rotational"
            if [ -r "$ROTA_FILE" ]; then
                IS_SSD=$(cat "$ROTA_FILE")
                
                if [ "$IS_SSD" = "0" ]; then
                    # SSD - use mq-deadline or none/noop
                    if [[ $(cat $device) == *"none"* ]]; then
                        OPTIMAL_SCHEDULER="none"
                    elif [[ $(cat $device) == *"mq-deadline"* ]]; then
                        OPTIMAL_SCHEDULER="mq-deadline"
                    else
                        OPTIMAL_SCHEDULER="$CURRENT_SCHEDULER"
                    fi
                else
                    # HDD - use mq-deadline or bfq
                    if [[ $(cat $device) == *"bfq"* ]]; then
                        OPTIMAL_SCHEDULER="bfq"
                    elif [[ $(cat $device) == *"mq-deadline"* ]]; then
                        OPTIMAL_SCHEDULER="mq-deadline"
                    else
                        OPTIMAL_SCHEDULER="$CURRENT_SCHEDULER"
                    fi
                fi
                
                if [ "$CURRENT_SCHEDULER" != "$OPTIMAL_SCHEDULER" ] && [[ $(cat $device) == *"$OPTIMAL_SCHEDULER"* ]]; then
                    if echo "$OPTIMAL_SCHEDULER" | sudo tee /sys/block/$DEVICE_NAME/queue/scheduler >/dev/null 2>&1; then
                        print_good "Set $DEVICE_NAME scheduler to $OPTIMAL_SCHEDULER"
                        log_success "I/O scheduler for $DEVICE_NAME set to $OPTIMAL_SCHEDULER"
                    fi
                else
                    print_info "$DEVICE_NAME: Using $CURRENT_SCHEDULER scheduler"
                fi
            fi
        fi
    done
    
    # Filesystem optimization
    print_step "Checking filesystem optimization..."
    
    # Check for ext4 filesystems and optimize
    mount | grep ext4 | while read line; do
        MOUNT_POINT=$(echo $line | awk '{print $3}')
        DEVICE=$(echo $line | awk '{print $1}')
        
        # Check if noatime is set
        if [[ $line == *"noatime"* ]]; then
            print_good "$MOUNT_POINT: noatime is enabled (good for performance)"
        else
            print_warning "$MOUNT_POINT: Consider adding 'noatime' mount option for better performance"
        fi
    done
    
    echo
}

# =============================================================================
# NETWORK OPTIMIZATION & MONITORING
# =============================================================================

analyze_network_performance() {
    print_header "Network Performance Analysis"
    
    # Network interface information
    print_step "Network Interface Information:"
    if command_exists ip; then
        ip link show | grep -E "^[0-9]" | while read line; do
            INTERFACE=$(echo $line | awk -F': ' '{print $2}' | awk '{print $1}')
            STATE=$(echo $line | grep -o "state [A-Z]*" | awk '{print $2}')
            print_info "Interface: $INTERFACE | State: $STATE"
        done
    fi
    
    # Network statistics
    print_step "Network Statistics:"
    if [ -f /proc/net/dev ]; then
        cat /proc/net/dev | grep -E "(eth|wlan|enp|wlp)" | while read line; do
            INTERFACE=$(echo $line | awk -F':' '{print $1}' | xargs)
            RX_BYTES=$(echo $line | awk '{print $2}')
            TX_BYTES=$(echo $line | awk '{print $10}')
            
            if [ "$RX_BYTES" -gt 0 ] || [ "$TX_BYTES" -gt 0 ]; then
                RX_MB=$((RX_BYTES / 1024 / 1024))
                TX_MB=$((TX_BYTES / 1024 / 1024))
                print_info "$INTERFACE: RX: ${RX_MB}MB | TX: ${TX_MB}MB"
            fi
        done
    fi
    
    # TCP settings analysis
    print_step "TCP Configuration Analysis:"
    if [ -f /proc/sys/net/ipv4/tcp_congestion_control ]; then
        TCP_CONGESTION=$(cat /proc/sys/net/ipv4/tcp_congestion_control)
        print_info "TCP Congestion Control: $TCP_CONGESTION"
        
        case "$TCP_CONGESTION" in
            "bbr")
                print_good "Using BBR congestion control (optimal for modern networks)"
                ;;
            "cubic")
                print_info "Using CUBIC congestion control (default, good performance)"
                ;;
            *)
                print_info "Using $TCP_CONGESTION congestion control"
                ;;
        esac
    fi
    
    # Network buffer sizes
    if [ -f /proc/sys/net/core/rmem_max ]; then
        RMEM_MAX=$(cat /proc/sys/net/core/rmem_max)
        WMEM_MAX=$(cat /proc/sys/net/core/wmem_max)
        print_info "Max receive buffer: $RMEM_MAX bytes"
        print_info "Max send buffer: $WMEM_MAX bytes"
    fi
    
    echo
}

optimize_network_performance() {
    print_header "Network Performance Optimization"
    
    if ! check_sudo_available; then
        print_warning "Sudo access required for network optimizations. Skipping..."
        return 1
    fi
    
    # TCP congestion control optimization
    print_step "Optimizing TCP congestion control..."
    
    # Check if BBR is available
    if modprobe tcp_bbr >/dev/null 2>&1; then
        if echo "tcp_bbr" | sudo tee /etc/modules-load.d/bbr.conf >/dev/null 2>&1; then
            print_good "BBR congestion control module loaded"
        fi
        
        if sudo sysctl net.ipv4.tcp_congestion_control=bbr >/dev/null 2>&1; then
            print_good "Set TCP congestion control to BBR"
            echo "net.ipv4.tcp_congestion_control=bbr" | sudo tee -a /etc/sysctl.d/99-performance.conf >/dev/null
            log_success "TCP congestion control set to BBR"
        fi
    else
        print_warning "BBR not available, keeping current congestion control"
    fi
    
    # Network buffer optimization
    print_step "Optimizing network buffers..."
    
    # Increase network buffer sizes for better throughput
    sudo sysctl net.core.rmem_max=134217728 >/dev/null 2>&1  # 128MB
    sudo sysctl net.core.wmem_max=134217728 >/dev/null 2>&1  # 128MB
    sudo sysctl net.core.rmem_default=262144 >/dev/null 2>&1 # 256KB
    sudo sysctl net.core.wmem_default=262144 >/dev/null 2>&1 # 256KB
    
    print_good "Optimized network buffer sizes"
    
    # Make network optimizations persistent
    cat << EOF | sudo tee -a /etc/sysctl.d/99-performance.conf >/dev/null
# Network performance optimizations
net.core.rmem_max=134217728
net.core.wmem_max=134217728
net.core.rmem_default=262144
net.core.wmem_default=262144
net.ipv4.tcp_rmem=4096 262144 134217728
net.ipv4.tcp_wmem=4096 262144 134217728
EOF
    
    log_success "Network optimizations applied and made persistent"
    
    echo
}

# =============================================================================
# BOOT TIME ANALYSIS
# =============================================================================

analyze_boot_performance() {
    print_header "Boot Time Analysis"
    
    # systemd-analyze boot time
    print_step "Boot Time Analysis:"
    if command_exists systemd-analyze; then
        BOOT_TIME=$(systemd-analyze | head -1)
        print_info "$BOOT_TIME"
        
        # Extract total boot time in seconds
        TOTAL_TIME=$(echo "$BOOT_TIME" | grep -o '[0-9.]*s' | tail -1 | sed 's/s//')
        if [ -n "$TOTAL_TIME" ]; then
            TOTAL_SECONDS=$(echo "$TOTAL_TIME" | cut -d. -f1)
            
            if [ "$TOTAL_SECONDS" -lt 30 ]; then
                print_good "Boot time is excellent (< 30 seconds)"
            elif [ "$TOTAL_SECONDS" -lt 60 ]; then
                print_info "Boot time is good (< 1 minute)"
            else
                print_warning "Boot time could be improved (> 1 minute)"
            fi
        fi
        
        # Critical chain analysis
        print_step "Critical Chain Analysis:"
        systemd-analyze critical-chain | head -10 | while read line; do
            if [[ $line == *"@"* ]]; then
                printf "${YELLOW}  %s${NC}\n" "$line"
            else
                printf "${CYAN}  %s${NC}\n" "$line"
            fi
        done
        
        # Top 5 slowest services
        print_step "Slowest Services:"
        systemd-analyze blame | head -5 | while read line; do
            TIME=$(echo $line | awk '{print $1}')
            SERVICE=$(echo $line | awk '{print $2}')
            
            # Extract time in milliseconds for comparison
            if [[ $TIME == *"ms" ]]; then
                TIME_MS=$(echo $TIME | sed 's/ms//')
            elif [[ $TIME == *"s" ]]; then
                TIME_S=$(echo $TIME | sed 's/s//')
                TIME_MS=$(echo "$TIME_S * 1000" | bc -l 2>/dev/null | cut -d. -f1)
                [ -z "$TIME_MS" ] && TIME_MS=0
            else
                TIME_MS=0
            fi
            
            if [ -n "$TIME_MS" ] && [ "$TIME_MS" -gt 5000 ]; then  # More than 5 seconds
                printf "${RED}  %s %s${NC}\n" "$TIME" "$SERVICE"
            elif [ "$TIME_MS" -gt 2000 ]; then  # More than 2 seconds
                printf "${YELLOW}  %s %s${NC}\n" "$TIME" "$SERVICE"
            else
                printf "${GREEN}  %s %s${NC}\n" "$TIME" "$SERVICE"
            fi
        done
    else
        print_warning "systemd-analyze not available"
    fi
    
    echo
}

optimize_boot_performance() {
    print_header "Boot Performance Optimization"
    
    if ! check_sudo_available; then
        print_warning "Sudo access required for boot optimizations. Skipping..."
        return 1
    fi
    
    print_step "Analyzing services for optimization..."
    
    # Disable unnecessary services that slow down boot
    SERVICES_TO_CHECK=(
        "bluetooth.service"
        "cups.service"
        "NetworkManager-wait-online.service"
    )
    
    for service in "${SERVICES_TO_CHECK[@]}"; do
        if systemctl is-enabled "$service" >/dev/null 2>&1; then
            print_info "Found enabled service: $service"
            
            case "$service" in
                "NetworkManager-wait-online.service")
                    print_warning "NetworkManager-wait-online can slow boot. Consider disabling if not needed."
                    ;;
                "bluetooth.service")
                    print_info "Bluetooth service is enabled. Disable if not using Bluetooth."
                    ;;
                "cups.service")
                    print_info "CUPS printing service is enabled. Disable if not printing."
                    ;;
            esac
        fi
    done
    
    # Check for plymouth (boot splash) which can slow boot
    if systemctl is-enabled plymouth-start.service >/dev/null 2>&1; then
        print_info "Plymouth boot splash is enabled. Consider disabling for faster boot."
    fi
    
    # Optimize systemd timeout settings
    print_step "Optimizing systemd timeout settings..."
    
    # Check current default timeout
    DEFAULT_TIMEOUT=$(systemctl show -p DefaultTimeoutStartUSec | cut -d= -f2)
    print_info "Current default timeout: $DEFAULT_TIMEOUT"
    
    if [[ $DEFAULT_TIMEOUT == *"1min"* ]]; then
        print_info "Consider reducing DefaultTimeoutStartSec in /etc/systemd/system.conf for faster boot"
    fi
    
    print_good "Boot analysis complete. Review recommendations above."
    log_success "Boot performance analysis completed"
    
    echo
}

# =============================================================================
# MAIN PERFORMANCE MONITORING FUNCTION
# =============================================================================

run_performance_monitor() {
    print_header "ArchCare Performance Monitor"
    print_info "Comprehensive system performance analysis and optimization"
    print_info "Detected system: $(uname -o) $(uname -r)"
    echo
    
    # Run all analysis modules
    analyze_cpu_performance
    analyze_memory_performance
    analyze_disk_performance
    analyze_network_performance
    analyze_boot_performance
}

run_performance_optimizer() {
    print_header "ArchCare Performance Optimizer"
    print_info "Applying system performance optimizations"
    echo
    
    # Run all optimization modules
    optimize_cpu_performance
    optimize_memory_performance
    optimize_disk_performance
    optimize_network_performance
    optimize_boot_performance
    
    print_header "Performance Optimization Complete"
    print_info "System optimizations have been applied."
    print_info "Some changes may require a reboot to take full effect."
    print_info "Check $PERFORMANCE_LOG for detailed logs."
}

# Performance summary
generate_performance_summary() {
    print_header "Performance Summary"
    
    # Calculate overall performance score
    local score=0
    local max_score=10
    
    # CPU score (2 points)
    CPU_USAGE=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | sed 's/%us,//' | sed 's/,/./' | cut -d. -f1)
    if [ -n "$CPU_USAGE" ] && [ "$CPU_USAGE" -lt 50 ]; then
        score=$((score + 2))
        print_good "CPU Performance: Excellent"
    elif [ -n "$CPU_USAGE" ] && [ "$CPU_USAGE" -lt 80 ]; then
        score=$((score + 1))
        print_info "CPU Performance: Good"
    else
        print_warning "CPU Performance: Needs attention"
    fi
    
    # Memory score (2 points)
    MEMORY_USAGE=$(free | grep "Mem:" | awk '{printf "%.0f", $3/$2 * 100}')
    if [ "$MEMORY_USAGE" -lt 70 ]; then
        score=$((score + 2))
        print_good "Memory Performance: Excellent"
    elif [ "$MEMORY_USAGE" -lt 85 ]; then
        score=$((score + 1))
        print_info "Memory Performance: Good"
    else
        print_warning "Memory Performance: Needs attention"
    fi
    
    # Disk score (2 points)
    DISK_USAGE=$(df / | grep "/" | awk '{print $5}' | sed 's/%//')
    if [ "$DISK_USAGE" -lt 70 ]; then
        score=$((score + 2))
        print_good "Disk Performance: Excellent"
    elif [ "$DISK_USAGE" -lt 90 ]; then
        score=$((score + 1))
        print_info "Disk Performance: Good"
    else
        print_warning "Disk Performance: Needs attention"
    fi
    
    # Network score (2 points) - simplified check
    if command_exists ping && ping -c 1 8.8.8.8 >/dev/null 2>&1; then
        score=$((score + 2))
        print_good "Network Performance: Excellent"
    else
        print_warning "Network Performance: Check connectivity"
    fi
    
    # Boot time score (2 points)
    if command_exists systemd-analyze; then
        BOOT_TIME=$(systemd-analyze | grep -o '[0-9.]*s' | tail -1 | sed 's/s//' | cut -d. -f1)
        BOOT_TIME_INT=$(echo "$BOOT_TIME" | cut -d. -f1)
    if [ -n "$BOOT_TIME_INT" ] && [ "$BOOT_TIME_INT" -lt 30 ]; then
            score=$((score + 2))
            print_good "Boot Performance: Excellent"
        elif [ -n "$BOOT_TIME_INT" ] && [ "$BOOT_TIME_INT" -lt 60 ]; then
            score=$((score + 1))
            print_info "Boot Performance: Good"
        else
            print_warning "Boot Performance: Could be improved"
        fi
    else
        score=$((score + 1))
        print_info "Boot Performance: Cannot analyze"
    fi
    
    # Calculate percentage
    local percentage=$((score * 100 / max_score))
    
    echo
    print_step "Overall Performance Score: $score/$max_score ($percentage%)"
    
    if [ "$percentage" -ge 90 ]; then
        print_good "Excellent system performance!"
    elif [ "$percentage" -ge 70 ]; then
        print_info "Good system performance with minor optimizations possible"
    elif [ "$percentage" -ge 50 ]; then
        print_warning "Average system performance - optimizations recommended"
    else
        print_error "Poor system performance - immediate optimization needed"
    fi
    
    echo
}

# Help function
show_help() {
    cat << EOF
$SCRIPT_NAME

USAGE:
    $0 [OPTIONS]

OPTIONS:
    --analyze       Run performance analysis only
    --optimize      Run performance optimizations only
    --summary       Show performance summary only
    --help          Show this help message

EXAMPLES:
    $0              # Run full analysis and optimization
    $0 --analyze    # Analysis only
    $0 --optimize   # Optimization only
    $0 --summary    # Summary only

This script provides comprehensive system performance monitoring and optimization
including CPU, memory, disk, network, and boot time analysis.

EOF
}

# Main execution logic
main() {
    init_logging
    
    case "${1:-}" in
        --analyze)
            run_performance_monitor
            generate_performance_summary
            ;;
        --optimize)
            run_performance_optimizer
            ;;
        --summary)
            generate_performance_summary
            ;;
        --help)
            show_help
            ;;
        *)
            run_performance_monitor
            run_performance_optimizer
            generate_performance_summary
            ;;
    esac
}

# Run main function with all arguments
main "$@" 