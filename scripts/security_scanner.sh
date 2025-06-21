#!/bin/sh
# Security Scanner Module for ArchCare
# Scans for vulnerabilities, malware, weak configurations, and security issues
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

# Security thresholds
SSH_PORT_DEFAULT=22
PASSWORD_MIN_LENGTH=8
FAILED_LOGIN_THRESHOLD=5

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

print_security_issue() {
    printf "${RED}🔒 SECURITY ISSUE: %s${NC}\n" "$1"
}

print_security_good() {
    printf "${GREEN}🔒 SECURE: %s${NC}\n" "$1"
}

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check dependencies and suggest installations
check_security_dependencies() {
    print_step "Checking security scanning dependencies..."
    
    MISSING_PACKAGES=""
    OPTIONAL_PACKAGES=""
    AVAILABLE_SCANNERS=""
    
    # Essential security tools
    if ! command_exists lynis; then
        MISSING_PACKAGES="$MISSING_PACKAGES lynis"
    else
        AVAILABLE_SCANNERS="$AVAILABLE_SCANNERS lynis"
    fi
    
    if ! command_exists rkhunter; then
        MISSING_PACKAGES="$MISSING_PACKAGES rkhunter"
    else
        AVAILABLE_SCANNERS="$AVAILABLE_SCANNERS rkhunter"
    fi
    
    # chkrootkit note - known AUR issue
    if ! command_exists chkrootkit; then
        print_warning "chkrootkit not available (AUR package has curl compatibility issues)"
        print_info "Alternative: Use lynis for comprehensive security auditing"
    else
        AVAILABLE_SCANNERS="$AVAILABLE_SCANNERS chkrootkit"
    fi
    
    if ! command_exists nmap; then
        OPTIONAL_PACKAGES="$OPTIONAL_PACKAGES nmap"
    fi
    
    if ! command_exists clamscan; then
        OPTIONAL_PACKAGES="$OPTIONAL_PACKAGES clamav"
    else
        AVAILABLE_SCANNERS="$AVAILABLE_SCANNERS clamav"
    fi
    
    if [ -n "$MISSING_PACKAGES" ]; then
        print_warning "Missing recommended security packages:$MISSING_PACKAGES"
        printf "${YELLOW}Install with: ${WHITE}sudo pacman -S$MISSING_PACKAGES${NC}\n"
    fi
    
    if [ -n "$OPTIONAL_PACKAGES" ]; then
        print_info "Optional security packages:$OPTIONAL_PACKAGES"
        printf "${CYAN}Install with: ${WHITE}sudo pacman -S$OPTIONAL_PACKAGES${NC}\n"
    fi
    
    if [ -n "$AVAILABLE_SCANNERS" ]; then
        print_good "Available security scanners:$AVAILABLE_SCANNERS"
    fi
    
    echo
}

# Check for security updates
check_security_updates() {
    print_step "Checking for security updates..."
    
    # Check for available updates
    UPDATES=$(pacman -Qu 2>/dev/null)
    SECURITY_UPDATES=0
    
    if [ -n "$UPDATES" ]; then
        # Look for security-related packages
        SECURITY_KEYWORDS="kernel|openssl|openssh|glibc|systemd|sudo|polkit|dbus|firefox|chromium"
        SECURITY_UPDATES=$(echo "$UPDATES" | grep -iE "$SECURITY_KEYWORDS" | wc -l)
        TOTAL_UPDATES=$(echo "$UPDATES" | wc -l)
        
        if [ "$SECURITY_UPDATES" -gt 0 ]; then
            print_critical "Security-related updates available: $SECURITY_UPDATES out of $TOTAL_UPDATES total"
            echo "$UPDATES" | grep -iE "$SECURITY_KEYWORDS" | while read -r line; do
                printf "${RED}  🔒 %s${NC}\n" "$line"
            done
            print_info "Run 'sudo pacman -Su' to install security updates immediately"
        else
            print_good "No critical security updates pending ($TOTAL_UPDATES non-security updates available)"
        fi
    else
        print_good "System is up to date - no security updates needed"
    fi
    
    echo
}

# Check SSH configuration
check_ssh_security() {
    print_step "Checking SSH security configuration..."
    
    if [ ! -f /etc/ssh/sshd_config ]; then
        print_info "SSH server not configured or not installed"
        echo
        return
    fi
    
    # Check if SSH is running
    if systemctl is-active --quiet sshd; then
        print_info "SSH service is active"
        
        # Check SSH port
        SSH_PORT=$(grep -E "^Port" /etc/ssh/sshd_config | awk '{print $2}' | head -1)
        if [ -z "$SSH_PORT" ]; then
            SSH_PORT=$SSH_PORT_DEFAULT
        fi
        
        if [ "$SSH_PORT" = "$SSH_PORT_DEFAULT" ]; then
            print_warning "SSH running on default port $SSH_PORT (consider changing)"
        else
            print_good "SSH running on non-default port $SSH_PORT"
        fi
        
        # Check root login
        ROOT_LOGIN=$(grep -E "^PermitRootLogin" /etc/ssh/sshd_config | awk '{print $2}' | head -1)
        case "$ROOT_LOGIN" in
            "no") print_good "Root SSH login disabled" ;;
            "yes") print_critical "Root SSH login enabled - SECURITY RISK" ;;
            "prohibit-password") print_warning "Root SSH login with key only (consider disabling completely)" ;;
            *) print_warning "Root SSH login setting unclear: $ROOT_LOGIN" ;;
        esac
        
        # Check password authentication
        PASSWORD_AUTH=$(grep -E "^PasswordAuthentication" /etc/ssh/sshd_config | awk '{print $2}' | head -1)
        case "$PASSWORD_AUTH" in
            "no") print_good "SSH password authentication disabled (key-only)" ;;
            "yes") print_warning "SSH password authentication enabled (consider key-only)" ;;
            *) print_info "SSH password authentication: $PASSWORD_AUTH" ;;
        esac
        
        # Check protocol version
        PROTOCOL=$(grep -E "^Protocol" /etc/ssh/sshd_config | awk '{print $2}' | head -1)
        if [ -n "$PROTOCOL" ] && [ "$PROTOCOL" != "2" ]; then
            print_critical "SSH protocol version $PROTOCOL (should be 2)"
        else
            print_good "SSH using protocol 2"
        fi
        
    else
        print_good "SSH service is not running"
    fi
    
    echo
}

# Check user account security
check_user_security() {
    print_step "Checking user account security..."
    
    # Check for users with empty passwords
    EMPTY_PASSWORDS=$(sudo awk -F: '($2 == "") {print $1}' /etc/shadow 2>/dev/null)
    if [ -n "$EMPTY_PASSWORDS" ]; then
        print_critical "Users with empty passwords found:"
        echo "$EMPTY_PASSWORDS" | while read -r user; do
            printf "${RED}  🔒 User: %s${NC}\n" "$user"
        done
    else
        print_good "No users with empty passwords"
    fi
    
    # Check for users with UID 0 (besides root)
    UID_ZERO=$(awk -F: '($3 == 0) {print $1}' /etc/passwd | grep -v '^root$')
    if [ -n "$UID_ZERO" ]; then
        print_critical "Non-root users with UID 0 found:"
        echo "$UID_ZERO" | while read -r user; do
            printf "${RED}  🔒 User: %s${NC}\n" "$user"
        done
    else
        print_good "Only root has UID 0"
    fi
    
    # Check for users with no password aging
    NO_AGING=$(sudo awk -F: '($5 == "" || $5 == "99999") {print $1}' /etc/shadow 2>/dev/null | head -5)
    if [ -n "$NO_AGING" ]; then
        print_warning "Users without password aging (first 5):"
        echo "$NO_AGING" | while read -r user; do
            printf "${YELLOW}  ⚠️  User: %s${NC}\n" "$user"
        done
    fi
    
    echo
}

# Check file permissions
check_file_permissions() {
    print_step "Checking critical file permissions..."
    
    # Check /etc/passwd permissions
    PASSWD_PERM=$(stat -c "%a" /etc/passwd 2>/dev/null)
    if [ "$PASSWD_PERM" != "644" ]; then
        print_warning "/etc/passwd permissions: $PASSWD_PERM (should be 644)"
    else
        print_good "/etc/passwd permissions: $PASSWD_PERM (correct)"
    fi
    
    # Check /etc/shadow permissions
    SHADOW_PERM=$(stat -c "%a" /etc/shadow 2>/dev/null)
    if [ "$SHADOW_PERM" != "640" ] && [ "$SHADOW_PERM" != "600" ]; then
        print_warning "/etc/shadow permissions: $SHADOW_PERM (should be 640 or 600)"
    else
        print_good "/etc/shadow permissions: $SHADOW_PERM (correct)"
    fi
    
    # Check for world-writable files in critical directories
    print_info "Checking for world-writable files in system directories..."
    WORLD_WRITABLE=$(find /etc /usr/bin /usr/sbin /bin /sbin -type f -perm -002 2>/dev/null | head -5)
    if [ -n "$WORLD_WRITABLE" ]; then
        print_warning "World-writable system files found (first 5):"
        echo "$WORLD_WRITABLE" | while read -r file; do
            printf "${YELLOW}  ⚠️  %s${NC}\n" "$file"
        done
    else
        print_good "No world-writable system files found"
    fi
    
    # Check for SUID/SGID files
    print_info "Checking SUID/SGID files..."
    SUID_COUNT=$(find /usr -type f \( -perm -4000 -o -perm -2000 \) 2>/dev/null | wc -l)
    if [ "$SUID_COUNT" -gt 50 ]; then
        print_warning "High number of SUID/SGID files: $SUID_COUNT (review recommended)"
    else
        print_good "SUID/SGID files: $SUID_COUNT (normal range)"
    fi
    
    echo
}

# Check network security
check_network_security() {
    print_step "Checking network security..."
    
    # Check listening ports
    if command_exists ss; then
        LISTENING_PORTS=$(ss -tuln | grep LISTEN | wc -l)
        print_info "Open listening ports: $LISTENING_PORTS"
        
        # Check for suspicious ports
        SUSPICIOUS=$(ss -tuln | grep -E ":23|:513|:514|:1080|:3128|:8080" | wc -l)
        if [ "$SUSPICIOUS" -gt 0 ]; then
            print_warning "Potentially suspicious ports detected:"
            ss -tuln | grep -E ":23|:513|:514|:1080|:3128|:8080" | while read -r line; do
                printf "${YELLOW}  ⚠️  %s${NC}\n" "$line"
            done
        fi
    fi
    
    # Check firewall status
    if command_exists firewall-cmd && systemctl is-active --quiet firewalld; then
        print_good "firewalld is active and running"
        FIREWALL_ZONE=$(firewall-cmd --get-default-zone 2>/dev/null)
        print_info "Default zone: $FIREWALL_ZONE"
    elif command_exists ufw; then
        UFW_STATUS=$(ufw status | head -1 | awk '{print $2}')
        case "$UFW_STATUS" in
            "active") print_good "UFW firewall is active" ;;
            "inactive") print_warning "UFW firewall is inactive" ;;
            *) print_info "UFW firewall status: $UFW_STATUS" ;;
        esac
    elif command_exists iptables; then
        IPTABLES_RULES=$(sudo iptables -L 2>/dev/null | wc -l)
        if [ "$IPTABLES_RULES" -gt 10 ]; then
            print_good "iptables firewall rules configured ($IPTABLES_RULES rules)"
        else
            print_warning "Few or no iptables rules configured"
        fi
    else
        print_warning "No firewall detected (firewalld, ufw, or iptables)"
    fi
    
    echo
}

# Basic rootkit detection
check_rootkits() {
    print_step "Checking for rootkits and malware..."
    
    # Check with rkhunter if available
    if command_exists rkhunter; then
        print_info "Running rkhunter scan..."
        # Update rkhunter database quietly
        sudo rkhunter --update --quiet >/dev/null 2>&1
        
        # Run quick scan
        RKHUNTER_RESULT=$(sudo rkhunter --check --skip-keypress --report-warnings-only 2>/dev/null)
        if [ -n "$RKHUNTER_RESULT" ]; then
            print_warning "rkhunter found potential issues:"
            echo "$RKHUNTER_RESULT" | head -10 | while read -r line; do
                printf "${YELLOW}  ⚠️  %s${NC}\n" "$line"
            done
        else
            print_good "rkhunter: No rootkits detected"
        fi
    fi
    
    # Check with chkrootkit if available
    if command_exists chkrootkit; then
        print_info "Running chkrootkit scan..."
        CHKROOTKIT_RESULT=$(sudo chkrootkit 2>/dev/null | grep INFECTED)
        if [ -n "$CHKROOTKIT_RESULT" ]; then
            print_critical "chkrootkit found infections:"
            echo "$CHKROOTKIT_RESULT" | while read -r line; do
                printf "${RED}  🚨 %s${NC}\n" "$line"
            done
        else
            print_good "chkrootkit: No infections detected"
        fi
    fi
    
    # Basic suspicious process check
    print_info "Checking for suspicious processes..."
    SUSPICIOUS_PROCS=$(ps aux | grep -iE "cryptominer|coinminer|xmrig|minerd" | grep -v grep)
    if [ -n "$SUSPICIOUS_PROCS" ]; then
        print_critical "Suspicious mining processes detected:"
        echo "$SUSPICIOUS_PROCS" | while read -r line; do
            printf "${RED}  🚨 %s${NC}\n" "$line"
        done
    else
        print_good "No suspicious mining processes detected"
    fi
    
    # Check for unusual network connections
    if command_exists ss; then
        EXTERNAL_CONNECTIONS=$(ss -tn | grep ESTAB | grep -v "127.0.0.1\|::1" | wc -l)
        if [ "$EXTERNAL_CONNECTIONS" -gt 20 ]; then
            print_warning "High number of external connections: $EXTERNAL_CONNECTIONS"
        else
            print_good "External connections: $EXTERNAL_CONNECTIONS (normal)"
        fi
    fi
    
    if ! command_exists rkhunter && ! command_exists chkrootkit; then
        print_info "Install rkhunter and chkrootkit for comprehensive rootkit scanning"
    fi
    
    echo
}

# Check system integrity
check_system_integrity() {
    print_step "Checking system integrity..."
    
    # Check if system files have been modified
    if command_exists pacman; then
        print_info "Checking package integrity with pacman..."
        MODIFIED_FILES=$(pacman -Qk 2>/dev/null | grep -v "0 missing files" | head -5)
        if [ -n "$MODIFIED_FILES" ]; then
            print_warning "Modified system files detected (first 5):"
            echo "$MODIFIED_FILES" | while read -r line; do
                printf "${YELLOW}  ⚠️  %s${NC}\n" "$line"
            done
        else
            print_good "All system packages have intact files"
        fi
    fi
    
    # Check for core dumps (improved to avoid false positives)
    CORE_DUMPS=$(find /var/crash /tmp /home -name "core.*" -o -name "*.core" 2>/dev/null | grep -v "\.nuget" | grep -v "packages" | wc -l)
    if [ "$CORE_DUMPS" -gt 0 ]; then
        print_warning "Core dump files found: $CORE_DUMPS (investigate crashes)"
    else
        print_good "No core dump files found"
    fi
    
    # Check system log for security events (improved filtering)
    if command_exists journalctl; then
        print_info "Checking system logs for security events..."
        # Filter for actual authentication failures, not system service errors
        FAILED_LOGINS=$(journalctl --since "1 day ago" | grep -E "authentication failure|password check failed" | grep -v "systemd\|gdm\|Failed to" | wc -l)
        if [ "$FAILED_LOGINS" -gt "$FAILED_LOGIN_THRESHOLD" ]; then
            print_warning "High number of failed login attempts: $FAILED_LOGINS in last 24h"
            print_info "Recent authentication failures:"
            journalctl --since "1 day ago" | grep -E "authentication failure|password check failed" | grep -v "systemd\|gdm\|Failed to" | tail -3 | while read -r line; do
                printf "${YELLOW}  ⚠️  %s${NC}\n" "$line"
            done
        else
            print_good "Failed login attempts: $FAILED_LOGINS in last 24h (normal)"
        fi
        
        # Check for sudo usage
        SUDO_USAGE=$(journalctl --since "1 day ago" | grep -i "sudo:" | grep -E "COMMAND|authentication failure" | wc -l)
        print_info "Sudo usage in last 24h: $SUDO_USAGE commands"
    fi
    
    echo
}

# Generate security summary
generate_security_summary() {
    print_header "Security Scan Summary"
    
    print_info "Security scan completed. Key findings:"
    
    # Count issues found (this is a simplified summary)
    if command_exists rkhunter; then
        print_info "✓ Rootkit scan completed"
    fi
    
    if systemctl is-active --quiet sshd; then
        print_info "ℹ SSH service is running - review configuration"
    fi
    
    print_info "📋 Recommendations:"
    print_info "  1. Keep system updated with 'sudo pacman -Su'"
    print_info "  2. Enable firewall if not already active"
    print_info "  3. Review SSH configuration for hardening"
    print_info "  4. Consider installing missing security tools"
    print_info "  5. Regular security scans with --security-scan"
    
    print_info "📚 Learn more about Arch Linux security:"
    print_info "  https://wiki.archlinux.org/title/Security"
    
    echo
}

# Main security scanning function
run_security_scanner() {
    print_header "Security Scanner"
    
    # Check dependencies
    check_security_dependencies
    
    # Run all security checks
    check_security_updates
    check_ssh_security
    check_user_security
    check_file_permissions
    check_network_security
    check_rootkits
    check_system_integrity
    
    # Verify security hardening
    verify_security_hardening
    
    # Generate summary
    generate_security_summary
    
    print_header "Security Scan Complete"
}

# Verify security hardening implementation
verify_security_hardening() {
    print_step "Verifying security hardening implementation..."
    
    local score=0
    local total=12
    
    # 1. Check kernel hardening
    if sysctl kernel.dmesg_restrict 2>/dev/null | grep -q "= 1"; then
        print_good "✓ Kernel hardening: dmesg_restrict enabled"
        score=$((score + 1))
    else
        print_warning "✗ Kernel hardening: dmesg_restrict not enabled"
    fi
    
    # 2. Check password policies
    if grep -q "PASS_MAX_DAYS.*90" /etc/login.defs 2>/dev/null; then
        print_good "✓ Password policy: Maximum age configured (90 days)"
        score=$((score + 1))
    else
        print_warning "✗ Password policy: Maximum age not configured"
    fi
    
    # 3. Check audit daemon
    if systemctl is-active auditd >/dev/null 2>&1; then
        print_good "✓ Security logging: auditd is running"
        score=$((score + 1))
    else
        print_warning "✗ Security logging: auditd not running"
    fi
    
    # 4. Check AIDE
    if command_exists aide; then
        print_good "✓ File integrity: AIDE installed"
        score=$((score + 1))
        if [ -f /var/lib/aide/aide.db.gz ] || [ -f /var/lib/aide/aide.db.new.gz ]; then
            print_good "✓ File integrity: AIDE database exists"
            score=$((score + 1))
        else
            print_warning "✗ File integrity: AIDE database not initialized"
        fi
    else
        print_warning "✗ File integrity: AIDE not installed"
    fi
    
    # 5. Check maldet
    if command_exists maldet; then
        print_good "✓ Malware detection: maldet installed"
        score=$((score + 1))
    else
        print_warning "✗ Malware detection: maldet not installed"
    fi
    
    # 6. Check fail2ban
    if systemctl is-active fail2ban >/dev/null 2>&1; then
        print_good "✓ Intrusion prevention: fail2ban running"
        score=$((score + 1))
    else
        print_warning "✗ Intrusion prevention: fail2ban not running"
    fi
    
    # 7. Check AppArmor
    if command_exists aa-status && systemctl is-active apparmor >/dev/null 2>&1; then
        print_good "✓ Mandatory access control: AppArmor running"
        score=$((score + 1))
    else
        print_warning "✗ Mandatory access control: AppArmor not active"
    fi
    
    # 8. Check firewall hardening
    if firewall-cmd --list-services 2>/dev/null | grep -q ssh; then
        print_warning "⚠ Firewall: SSH service still enabled (should be removed if not used)"
    else
        print_good "✓ Firewall: SSH service properly removed"
        score=$((score + 1))
    fi
    
    # 9. Check umask setting
    if grep -q "UMASK.*027" /etc/login.defs 2>/dev/null; then
        print_good "✓ File permissions: Secure umask (027) configured"
        score=$((score + 1))
    else
        print_warning "✗ File permissions: Secure umask not configured"
    fi
    
    # 10. Check sysctl hardening
    if [ -f /etc/sysctl.d/99-security-hardening.conf ]; then
        print_good "✓ Network security: Kernel hardening applied"
        score=$((score + 1))
    else
        print_warning "✗ Network security: Kernel hardening not applied"
    fi
    
    # 11. Check if reboot is needed
    RUNNING_KERNEL=$(uname -r)
    INSTALLED_KERNEL=$(pacman -Q linux 2>/dev/null | awk '{print $2}' | sed 's/\.arch/-arch/g')
    if echo "$RUNNING_KERNEL" | grep -q "$(echo "$INSTALLED_KERNEL" | cut -d- -f1-2)"; then
        print_good "✓ System state: Kernel up to date"
        score=$((score + 1))
    else
        print_warning "⚠ System state: Reboot needed for kernel update"
    fi
    
    # Calculate percentage
    local percentage=$((score * 100 / total))
    
    echo
    print_step "Security Hardening Summary:"
    printf "${WHITE}Score: %d/%d (%d%%)${NC}\\n" "$score" "$total" "$percentage"
    
    if [ "$percentage" -ge 90 ]; then
        print_good "Excellent security posture!"
    elif [ "$percentage" -ge 75 ]; then
        print_info "Good security posture with room for improvement"
    elif [ "$percentage" -ge 50 ]; then
        print_warning "Moderate security - additional hardening recommended"
    else
        print_error "Poor security posture - immediate hardening required"
    fi
    
    echo
}

# If script is run directly
if [ "${0##*/}" = "security_scanner.sh" ]; then
    run_security_scanner
fi 