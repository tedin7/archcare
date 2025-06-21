#!/bin/sh
# Arch Linux Maintenance Script
# Compatible with bash, zsh, fish, dash and other POSIX shells
# Works on all Arch-based distributions (Arch Linux, EndeavourOS, Manjaro, etc.)
# Version: 1.0.0
# Date: June 21, 2025

# Script configuration
SCRIPT_NAME="Arch Maintenance"
SCRIPT_VERSION="1.0.0"
LOG_DIR="logs"
CONFIG_DIR="config"
SCRIPTS_DIR="scripts"

# Color codes for output (POSIX compatible)
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# Default settings
DRY_RUN=false
AUTO_MODE=false
UPDATE_ONLY=false
CLEAN_ONLY=false
HEALTH_CHECK=false
ALL_FEATURES=false
SECURITY_SCAN=false
VERBOSE=false

# Initialize directories and logging
init_environment() {
    # Create necessary directories
    mkdir -p "$LOG_DIR" "$CONFIG_DIR" "$SCRIPTS_DIR"
    
    # Set log files
    MAIN_LOG="$LOG_DIR/maintenance.log"
    ERROR_LOG="$LOG_DIR/errors.log"
    UPDATE_LOG="$LOG_DIR/updates.log"
    
    # Initialize log files with timestamp
    echo "=== Maintenance session started: $(date) ===" >> "$MAIN_LOG"
}

# Logging functions
log_info() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [INFO] $1" >> "$MAIN_LOG"
    if [ "$VERBOSE" = true ]; then
        printf "${GREEN}[INFO]${NC} %s\n" "$1"
    fi
}

log_error() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [ERROR] $1" >> "$ERROR_LOG"
    echo "$(date '+%Y-%m-%d %H:%M:%S') [ERROR] $1" >> "$MAIN_LOG"
    printf "${RED}[ERROR]${NC} %s\n" "$1" >&2
}

log_warning() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [WARNING] $1" >> "$MAIN_LOG"
    printf "${YELLOW}[WARNING]${NC} %s\n" "$1"
}

log_success() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [SUCCESS] $1" >> "$MAIN_LOG"
    printf "${GREEN}[SUCCESS]${NC} %s\n" "$1"
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

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check if running as root
check_root() {
    if [ "$(id -u)" -eq 0 ]; then
        log_error "This script should not be run as root. Use sudo when needed."
        exit 1
    fi
}

# Check distribution compatibility
check_distribution() {
    if ! command_exists pacman; then
        log_error "This script requires pacman package manager (Arch Linux based distribution)"
        exit 1
    fi
    
    # Detect distribution
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        DISTRO_NAME="$NAME"
        log_info "Detected distribution: $DISTRO_NAME"
    else
        DISTRO_NAME="Unknown Arch-based"
        log_warning "Could not detect specific distribution, assuming Arch-based"
    fi
}

# Display system information
show_system_info() {
    print_header "System Information"
    
    print_info "Distribution: $DISTRO_NAME"
    print_info "Kernel: $(uname -r)"
    print_info "Architecture: $(uname -m)"
    print_info "Shell: $SHELL"
    print_info "Date: $(date)"
    
    # Check available space
    AVAILABLE_SPACE=$(df -h / | awk 'NR==2 {print $4}')
    print_info "Available disk space: $AVAILABLE_SPACE"
    
    # Check memory
    if command_exists free; then
        MEMORY_INFO=$(free -h | awk 'NR==2 {print $7}')
        print_info "Available memory: $MEMORY_INFO"
    fi
    
    echo
}

# User confirmation prompt
confirm() {
    if [ "$AUTO_MODE" = true ]; then
        return 0
    fi
    
    printf "${YELLOW}%s [y/N]: ${NC}" "$1"
    read -r response
    case "$response" in
        [yY]|[yY][eE][sS]) return 0 ;;
        *) return 1 ;;
    esac
}

# Update package databases
update_databases() {
    print_step "Updating package databases..."
    
    if [ "$DRY_RUN" = true ]; then
        print_info "[DRY RUN] Would run: sudo pacman -Sy"
        log_info "DRY RUN: Package database update"
        return 0
    fi
    
    if sudo pacman -Sy; then
        log_success "Package databases updated successfully"
        echo "$(date '+%Y-%m-%d %H:%M:%S') Database update successful" >> "$UPDATE_LOG"
    else
        log_error "Failed to update package databases"
        return 1
    fi
}

# System upgrade
system_upgrade() {
    print_step "Checking for system updates..."
    
    # Check for updates
    UPDATES=$(pacman -Qu | wc -l)
    
    if [ "$UPDATES" -eq 0 ]; then
        log_info "System is up to date"
        print_info "No updates available"
        return 0
    fi
    
    print_info "$UPDATES updates available"
    
    if [ "$DRY_RUN" = true ]; then
        print_info "[DRY RUN] Available updates:"
        pacman -Qu
        log_info "DRY RUN: System upgrade ($UPDATES packages)"
        return 0
    fi
    
    if confirm "Proceed with system upgrade ($UPDATES packages)?"; then
        print_step "Upgrading system packages..."
        
        if sudo pacman -Su --noconfirm; then
            log_success "System upgrade completed successfully"
            echo "$(date '+%Y-%m-%d %H:%M:%S') System upgrade: $UPDATES packages" >> "$UPDATE_LOG"
            
            # Check if kernel was updated
            if pacman -Q linux | grep -q "$(uname -r)"; then
                log_info "Kernel update detected - reboot recommended"
                print_info "⚠️  Kernel was updated - please reboot when convenient"
            fi
        else
            log_error "System upgrade failed"
            return 1
        fi
    else
        log_info "System upgrade skipped by user"
    fi
}

# AUR updates (if available)
update_aur_packages() {
    AUR_HELPER=""
    
    # Check for AUR helpers
    if command_exists yay; then
        AUR_HELPER="yay"
    elif command_exists paru; then
        AUR_HELPER="paru"
    elif command_exists pikaur; then
        AUR_HELPER="pikaur"
    fi
    
    if [ -z "$AUR_HELPER" ]; then
        log_info "No AUR helper found, skipping AUR updates"
        return 0
    fi
    
    print_step "Checking AUR packages with $AUR_HELPER..."
    
    if [ "$DRY_RUN" = true ]; then
        print_info "[DRY RUN] Would check AUR updates with $AUR_HELPER"
        log_info "DRY RUN: AUR package check with $AUR_HELPER"
        return 0
    fi
    
    if confirm "Update AUR packages with $AUR_HELPER?"; then
        if $AUR_HELPER -Sua --noconfirm; then
            log_success "AUR packages updated successfully"
        else
            log_error "AUR package update failed"
        fi
    fi
}

# Remove orphaned packages
remove_orphans() {
    print_step "Checking for orphaned packages..."
    
    ORPHANS=$(pacman -Qtdq 2>/dev/null)
    
    if [ -z "$ORPHANS" ]; then
        log_info "No orphaned packages found"
        print_info "No orphaned packages to remove"
        return 0
    fi
    
    ORPHAN_COUNT=$(echo "$ORPHANS" | wc -l)
    print_info "$ORPHAN_COUNT orphaned packages found"
    
    if [ "$DRY_RUN" = true ]; then
        print_info "[DRY RUN] Would remove orphaned packages:"
        echo "$ORPHANS"
        log_info "DRY RUN: Remove $ORPHAN_COUNT orphaned packages"
        return 0
    fi
    
    if confirm "Remove $ORPHAN_COUNT orphaned packages?"; then
        if echo "$ORPHANS" | sudo pacman -Rns --noconfirm -; then
            log_success "Orphaned packages removed successfully"
        else
            log_error "Failed to remove some orphaned packages"
        fi
    fi
}

# Clean package cache
clean_package_cache() {
    print_step "Cleaning package cache..."
    
    # Calculate cache size
    CACHE_SIZE=$(du -sh /var/cache/pacman/pkg/ 2>/dev/null | cut -f1)
    print_info "Current cache size: $CACHE_SIZE"
    
    if [ "$DRY_RUN" = true ]; then
        print_info "[DRY RUN] Would clean package cache"
        log_info "DRY RUN: Package cache cleanup"
        return 0
    fi
    
    if confirm "Clean package cache?"; then
        # Keep only the 3 most recent versions
        if command_exists paccache; then
            if paccache -r; then
                log_success "Package cache cleaned with paccache"
            else
                log_warning "paccache cleanup had issues"
            fi
        else
            # Fallback to pacman cache cleaning
            if sudo pacman -Sc --noconfirm; then
                log_success "Package cache cleaned"
            else
                log_error "Failed to clean package cache"
            fi
        fi
        
        NEW_CACHE_SIZE=$(du -sh /var/cache/pacman/pkg/ 2>/dev/null | cut -f1)
        print_info "New cache size: $NEW_CACHE_SIZE"
    fi
}

# Clean system logs
clean_system_logs() {
    print_step "Cleaning system logs..."
    
    if [ "$DRY_RUN" = true ]; then
        print_info "[DRY RUN] Would clean system logs (keep last 2 weeks)"
        log_info "DRY RUN: System log cleanup"
        return 0
    fi
    
    if command_exists journalctl; then
        if confirm "Clean system logs (keep last 2 weeks)?"; then
            if sudo journalctl --vacuum-time=2weeks; then
                log_success "System logs cleaned"
            else
                log_warning "System log cleanup had issues"
            fi
        fi
    fi
}

# Clean temporary files
clean_temp_files() {
    print_step "Cleaning temporary files..."
    
    if [ "$DRY_RUN" = true ]; then
        print_info "[DRY RUN] Would clean /tmp and ~/.cache"
        log_info "DRY RUN: Temporary files cleanup"
        return 0
    fi
    
    if confirm "Clean temporary files?"; then
        # Clean user cache
        if [ -d "$HOME/.cache" ]; then
            find "$HOME/.cache" -type f -atime +7 -delete 2>/dev/null
            log_info "User cache files cleaned"
        fi
        
        # Clean thumbnails
        if [ -d "$HOME/.thumbnails" ]; then
            rm -rf "$HOME/.thumbnails"
            log_info "Thumbnails cleaned"
        fi
        
        log_success "Temporary files cleaned"
    fi
}

# Update system databases
update_system_databases() {
    print_step "Updating system databases..."
    
    if [ "$DRY_RUN" = true ]; then
        print_info "[DRY RUN] Would update locate/man databases"
        log_info "DRY RUN: System database updates"
        return 0
    fi
    
    # Update locate database
    if command_exists updatedb; then
        if confirm "Update locate database?"; then
            if sudo updatedb; then
                log_success "Locate database updated"
            else
                log_warning "Locate database update failed"
            fi
        fi
    fi
    
    # Update man database
    if command_exists mandb; then
        print_step "Updating man database..."
        if sudo mandb --quiet; then
            log_success "Man database updated"
        else
            log_warning "Man database update failed"
        fi
    fi
}

# Check failed services
check_failed_services() {
    print_step "Checking for failed systemd services..."
    
    if command_exists systemctl; then
        FAILED_SERVICES=$(systemctl --failed --no-legend | wc -l)
        
        if [ "$FAILED_SERVICES" -eq 0 ]; then
            log_info "No failed services found"
            print_info "All systemd services are running normally"
        else
            log_warning "$FAILED_SERVICES failed services detected"
            print_info "⚠️  $FAILED_SERVICES failed services detected:"
            systemctl --failed --no-legend
            print_info "Use 'systemctl status <service>' to investigate"
        fi
    fi
}

# Run hardware monitoring
run_hardware_monitoring() {
    if [ -f "$SCRIPTS_DIR/hardware_monitor.sh" ]; then
        log_info "Running hardware health monitoring..."
        . "$SCRIPTS_DIR/hardware_monitor.sh"
        run_hardware_monitor
    else
        log_warning "Hardware monitoring script not found at $SCRIPTS_DIR/hardware_monitor.sh"
        print_info "Skipping hardware monitoring"
    fi
}

# Run security scanning
run_security_scanning() {
    if [ -f "$SCRIPTS_DIR/security_scanner.sh" ]; then
        log_info "Running security scanning..."
        . "$SCRIPTS_DIR/security_scanner.sh"
        run_security_scanner
    else
        log_warning "Security scanner script not found at $SCRIPTS_DIR/security_scanner.sh"
        print_info "Skipping security scanning"
    fi
}

# Display help
show_help() {
    cat << EOF
$SCRIPT_NAME v$SCRIPT_VERSION

Usage: $0 [OPTIONS]

OPTIONS:
    --auto          Run in automatic mode (no prompts)
    --dry-run       Preview changes without applying them
    --update-only   Only perform system updates
    --clean-only    Only perform cleanup tasks
    --health-check  Monitor hardware health (temperature, disk, memory)
    --security-scan Security scanning (vulnerabilities, malware, config)
    --all           Run full maintenance + hardware monitoring + all features
    --verbose       Enable verbose output
    --help          Show this help message
    --version       Show version information

EXAMPLES:
    $0                    # Interactive mode (includes hardware monitoring)
    $0 --auto             # Automatic maintenance + hardware monitoring
    $0 --all              # All features (maintenance + hardware monitoring)
    $0 --dry-run          # Preview mode
    $0 --update-only      # Updates only
    $0 --clean-only       # Cleanup only
    $0 --health-check     # Hardware health monitoring only
    $0 --security-scan    # Security scanning only

This script performs comprehensive maintenance on Arch Linux systems including:
- Hardware health monitoring (temperature, disk, memory)
- Security scanning (vulnerabilities, malware, configuration)
- System updates and AUR packages
- Orphaned package removal
- Cache cleaning
- System log cleanup
- Database updates
- Service status checks

EOF
}

# Parse command line arguments
parse_arguments() {
    while [ $# -gt 0 ]; do
        case $1 in
            --auto)
                AUTO_MODE=true
                ;;
            --dry-run)
                DRY_RUN=true
                ;;
            --update-only)
                UPDATE_ONLY=true
                ;;
            --clean-only)
                CLEAN_ONLY=true
                ;;
            --health-check)
                HEALTH_CHECK=true
                ;;
            --all)
                ALL_FEATURES=true
                ;;
            --security-scan)
                SECURITY_SCAN=true
                ;;
            --verbose)
                VERBOSE=true
                ;;
            --help)
                show_help
                exit 0
                ;;
            --version)
                echo "$SCRIPT_NAME v$SCRIPT_VERSION"
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
        shift
    done
}

# Main maintenance function
run_maintenance() {
    if [ "$HEALTH_CHECK" = true ]; then
        print_header "Hardware Health Check Only"
        run_hardware_monitoring
    elif [ "$SECURITY_SCAN" = true ]; then
        print_header "Security Scan Only"
        run_security_scanning
    elif [ "$UPDATE_ONLY" = true ]; then
        print_header "System Updates Only"
        update_databases
        system_upgrade
        update_aur_packages
    elif [ "$CLEAN_ONLY" = true ]; then
        print_header "Cleanup Tasks Only"
        remove_orphans
        clean_package_cache
        clean_system_logs
        clean_temp_files
    elif [ "$ALL_FEATURES" = true ]; then
        print_header "Complete System Maintenance + Hardware Monitoring + Security Scan"
        
        # Hardware monitoring first
        run_hardware_monitoring
        
        # Security scanning
        run_security_scanning
        
        # Update tasks
        update_databases
        system_upgrade
        update_aur_packages
        
        # Cleanup tasks
        remove_orphans
        clean_package_cache
        clean_system_logs
        clean_temp_files
        
        # System optimization
        update_system_databases
        check_failed_services
    else
        print_header "Full System Maintenance + Hardware Monitoring + Security Scan"
        
        # Hardware monitoring first (now included by default)
        run_hardware_monitoring
        
        # Security scanning (now included by default)
        run_security_scanning
        
        # Update tasks
        update_databases
        system_upgrade
        update_aur_packages
        
        # Cleanup tasks
        remove_orphans
        clean_package_cache
        clean_system_logs
        clean_temp_files
        
        # System optimization
        update_system_databases
        check_failed_services
    fi
}

# Main script execution
main() {
    # Parse command line arguments
    parse_arguments "$@"
    
    # Initialize environment
    init_environment
    
    # Preliminary checks
    check_root
    check_distribution
    
    # Show system information
    show_system_info
    
    # Show mode information
    if [ "$DRY_RUN" = true ]; then
        print_header "DRY RUN MODE - No changes will be made"
    elif [ "$AUTO_MODE" = true ]; then
        print_header "AUTOMATIC MODE - No user prompts"
    else
        print_header "INTERACTIVE MODE"
    fi
    
    # Start maintenance
    START_TIME=$(date +%s)
    
    print_header "Starting Maintenance Tasks"
    run_maintenance
    
    # Calculate execution time
    END_TIME=$(date +%s)
    DURATION=$((END_TIME - START_TIME))
    
    print_header "Maintenance Complete"
    print_info "Total execution time: ${DURATION} seconds"
    log_info "Maintenance session completed in ${DURATION} seconds"
    
    if [ "$DRY_RUN" = false ]; then
        print_info "Logs saved to: $LOG_DIR/"
        print_info "Check $ERROR_LOG for any errors"
    fi
    
    echo "=== Maintenance session ended: $(date) ===" >> "$MAIN_LOG"
}

# Run main function with all arguments
main "$@" 