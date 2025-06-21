# ArchCare

A comprehensive maintenance application for Arch Linux and Arch-based distributions (EndeavourOS, Manjaro, Artix, etc.).

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Shell Script](https://img.shields.io/badge/language-Shell-green.svg)](https://github.com/tedin7/archcare)
[![Arch Linux](https://img.shields.io/badge/platform-Arch%20Linux-blue.svg)](https://archlinux.org/)

## Overview

This application provides automated maintenance tasks for Arch Linux systems, including system updates, package management, cache cleaning, orphan removal, and system optimization.

## Features

- **Cross-shell compatibility**: Works with bash, zsh, fish, and other POSIX-compliant shells
- **Distribution agnostic**: Works on Arch Linux and all Arch-based distributions
- **Automated maintenance**: System updates, cache cleaning, orphan package removal
- **Security updates**: Prioritizes security updates and system integrity
- **Logging**: Comprehensive logging of all maintenance activities
- **Interactive mode**: User prompts for critical operations
- **Dry-run mode**: Preview changes before applying them

## Project Structure

```
archcare/
├── README.md                 # This documentation
├── arch_maintenance.sh       # Main maintenance script
├── scripts/                  # Additional utility scripts
│   ├── system_info.sh       # System information gathering
│   ├── package_manager.sh   # Package management utilities
│   └── cleanup.sh           # System cleanup utilities
├── config/                   # Configuration files
│   └── maintenance.conf     # Main configuration
├── logs/                    # Log files directory
└── tests/                   # Test scripts
```

## Installation

1. Clone the repository:
```bash
git clone https://github.com/tedin7/archcare.git
cd archcare
```

Or using SSH:
```bash
git clone git@github.com:tedin7/archcare.git
cd archcare
```

2. Make the script executable:
```bash
chmod +x arch_maintenance.sh
```

3. Run the maintenance script:
```bash
./arch_maintenance.sh
```

## Usage

### Basic Usage
```bash
# Complete maintenance (hardware + security + full maintenance)
./arch_maintenance.sh

# Complete maintenance (non-interactive)
./arch_maintenance.sh --auto

# Complete maintenance (explicit all features)
./arch_maintenance.sh --all

# Dry run (preview all changes)
./arch_maintenance.sh --dry-run

# Specific tasks only
./arch_maintenance.sh --health-check     # Hardware monitoring only
./arch_maintenance.sh --security-scan    # Security scanning only
./arch_maintenance.sh --update-only      # Updates only
./arch_maintenance.sh --clean-only       # Cleanup only
```

### Command Line Options

- `--auto`: Run in automatic mode (no user prompts)
- `--dry-run`: Preview changes without applying them
- `--all`: Run all features (same as default, explicit)
- `--update-only`: Only perform system updates
- `--clean-only`: Only perform cleanup tasks
- `--health-check`: Monitor hardware health only
- `--security-scan`: Security scanning only
- `--verbose`: Enable verbose output
- `--help`: Show help information
- `--version`: Show version information

## Maintenance Tasks

### 1. System Updates
- Updates package databases
- Upgrades all installed packages
- Handles AUR packages (if yay/paru is installed)
- Kernel updates with reboot notifications

### 2. Package Management
- Removes orphaned packages
- Cleans package cache
- Removes old cached packages
- Validates package integrity

### 3. System Cleanup
- Clears system logs (keeps recent entries)
- Cleans temporary files
- Removes broken symlinks
- Cleans user cache directories

### 4. Security & Optimization
- Updates system databases (locate, man pages)
- Checks for failed systemd services
- Validates file system integrity
- Updates font cache

### 5. Hardware Health Monitoring
- CPU temperature monitoring with smart thresholds
- GPU temperature detection (NVIDIA, AMD, Intel)
- Disk health and SMART status checking
- Memory and swap usage analysis
- System load monitoring
- Battery status (for laptops)

### 6. Security Scanning
- Security update detection and prioritization
- SSH configuration security analysis
- User account security validation
- File permission verification
- Network security assessment
- Rootkit and malware detection
- System integrity checking
- Failed login attempt monitoring

## Configuration

The `config/maintenance.conf` file allows customization of maintenance behavior:

```ini
# Automatic mode settings
AUTO_UPDATE=true
AUTO_CLEAN=true
AUTO_REBOOT=false

# Package cache settings
KEEP_CACHE_VERSIONS=3
MAX_CACHE_SIZE_GB=5

# Logging settings
LOG_LEVEL=INFO
LOG_RETENTION_DAYS=30
```

## Supported Distributions

- **Arch Linux** (official)
- **EndeavourOS** ✓ (tested)
- **Manjaro**
- **Artix Linux**
- **ArcoLinux**
- **Garuda Linux**
- **BlackArch**

## Requirements

- Arch Linux or Arch-based distribution
- `pacman` package manager
- `sudo` privileges for system operations
- Optional: `yay` or `paru` for AUR support

## Logging

All maintenance activities are logged to:
- `logs/maintenance.log` - Main log file
- `logs/errors.log` - Error-specific log
- `logs/updates.log` - Package update history

## Safety Features

- **Confirmation prompts** for critical operations
- **Dry-run mode** to preview changes
- **Backup creation** before major changes
- **Rollback support** for package operations
- **Error handling** with detailed logging

## Development

### Testing

Run the test suite:
```bash
cd tests
./run_tests.sh
```

### Contributing

1. Fork the repository
2. Create a feature branch
3. Test on multiple Arch distributions
4. Submit a pull request

## Changelog

### Version 1.0.0 (Initial Release)
- Basic maintenance script with cross-shell compatibility
- Support for all major Arch-based distributions
- Interactive and automatic modes
- Comprehensive logging system
- Safety features and error handling

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Support

For issues, questions, or contributions:
- Create an issue on the repository
- Check the logs directory for detailed error information
- Test with `--dry-run` first for troubleshooting

## Security Hardening Implementation

The ArchCare system has been significantly hardened with comprehensive security measures:

### 🔒 **Security Features Implemented**

#### **1. Kernel Security Hardening**
- **File**: `/etc/sysctl.d/99-security-hardening.conf`
- **Features**: 
  - Kernel message restrictions (`kernel.dmesg_restrict = 1`)
  - Pointer protection (`kernel.kptr_restrict = 2`)
  - SysRq disabled (`kernel.sysrq = 0`)
  - Unprivileged BPF disabled (`kernel.unprivileged_bpf_disabled = 1`)
  - Ptrace scope protection (`kernel.yama.ptrace_scope = 1`)
  - Network security hardening (redirects, source routing, etc.)

#### **2. Password Security Policies**
- **File**: `/etc/login.defs` (enhanced)
- **Features**:
  - Maximum password age: 90 days
  - Minimum password age: 1 day
  - Password warning: 14 days
  - Secure umask: 027
  - Strong password hashing: SHA-256/512 with high rounds

#### **3. Security Logging & Monitoring**
- **auditd**: Comprehensive security event logging
- **File Integrity**: AIDE with 566k+ file database
- **Malware Detection**: Linux Malware Detect (maldet)
- **Intrusion Prevention**: fail2ban

#### **4. Network Security**
- **Firewall**: firewalld with hardened rules
- **SSH**: Service disabled and removed from firewall
- **Network hardening**: Comprehensive sysctl network protections

#### **5. Access Control**
- **AppArmor**: Mandatory access control (requires reboot)
- **File Permissions**: Hardened default umask (027)
- **User Security**: Enhanced login controls

### 📊 **Current Security Score: 8/12 (66%)**

#### **✅ Active Security Measures:**
1. ✓ Kernel hardening enabled
2. ✓ Security logging (auditd) active
3. ✓ File integrity monitoring (AIDE) installed
4. ✓ Malware detection (maldet) installed
5. ✓ Intrusion prevention (fail2ban) running
6. ✓ Firewall hardened (SSH removed)
7. ✓ Secure file permissions (umask 027)
8. ✓ Network security hardening applied

#### **⚠️ Requires Attention:**
- **AppArmor**: Needs kernel parameter `apparmor=1 security=apparmor` 
- **System Reboot**: Required for kernel updates and AppArmor activation
- **Password Policy**: May need manual verification

### 🚀 **Security Scanner Usage**

The enhanced security scanner now includes hardening verification:

```bash
# Run complete security scan with hardening verification
./arch_maintenance.sh --security-scan

# Run security scanner directly
bash scripts/security_scanner.sh
```

### 📖 **Security Recommendations**

1. **Immediate**: Reboot system to activate kernel updates and AppArmor
2. **Regular**: Run security scans weekly with `--security-scan`
3. **Monitoring**: Check `/var/log/aide.log` for file integrity alerts
4. **Updates**: Keep security tools updated with automatic signature updates

### 🔧 **Manual Security Commands**

```bash
# Check AIDE file integrity
sudo aide --check

# Update AIDE database
sudo aide --update

# Check AppArmor status
sudo aa-status

# View security logs
sudo journalctl -u auditd

# Check fail2ban status
sudo fail2ban-client status
```

---

**Last Updated**: June 21, 2025
**Tested On**: EndeavourOS (Arch Linux based)
**Shell Compatibility**: bash, zsh, fish, dash 