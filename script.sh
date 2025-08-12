#!/bin/bash
# ============================================================================
# DevSecOps Environment Setup Script
# Works on Ubuntu/Debian-based systems
# ============================================================================
# This script will:
#   1. Update system packages
#   2. Install Java (needed for Jenkins)
#   3. Install Jenkins
#   4. Install Docker
#   5. Install Node.js + npm
#   6. Add Jenkins and your user to Docker group
#   7. Enable and start services
#   8. Install Trivy (container image scanner)
#   9. Install OWASP Dependency-Check (SCA)
#  10. Run OWASP ZAP (DAST) in Docker
#  11. Verify installation
# ============================================================================

# Stop script if any command fails
set -e

# Function to print info messages
log() {
    echo -e "\e[1;32m[INFO]\e[0m $1"
}

# Function to install a package if not already installed
install_package() {
    local pkg="$1"
    if dpkg -s "$pkg" &>/dev/null; then
        log "$pkg is already installed."
    else
        log "Installing $pkg..."
        sudo apt-get install -y "$pkg"
    fi
}

# Function to check if a command works and show its version
check_command() {
    local cmd="$1"
    local name="$2"
    if command -v "$cmd" &>/dev/null; then
        log "$name is installed. Version: $($cmd --version 2>&1 | head -n 1)"
    else
        echo "[ERROR] $name is NOT installed correctly." >&2
        exit 1
    fi
}

# ---------------------------
# Step 1: Update System
# ---------------------------
log "Updating system packages..."
sudo apt-get update -y && sudo apt-get upgrade -y

# ---------------------------
# Step 2: Install Java
# ---------------------------
log "Installing Java (OpenJDK 21)..."
install_package fontconfig
install_package openjdk-21-jre

# ---------------------------
# Step 3: Install Jenkins
# ---------------------------
log "Setting up Jenkins repository..."
sudo mkdir -p /etc/apt/keyrings
sudo wget -q -O /etc/apt/keyrings/jenkins-keyring.asc \
    https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key

echo "deb [signed-by=/etc/apt/keyrings/jenkins-keyring.asc] \
    https://pkg.jenkins.io/debian-stable binary/" | \
    sudo tee /etc/apt/sources.list.d/jenkins.list > /dev/null

sudo apt-get update -y
install_package jenkins

# ---------------------------
# Step 4: Install Docker
# ---------------------------
log "Installing Docker..."
install_package docker.io

# ---------------------------
# Step 5: Install Node.js & npm
# ---------------------------
log "Installing Node.js and npm..."
install_package nodejs
install_package npm

# ---------------------------
# Step 6: Add Users to Docker Group
# ---------------------------
log "Adding $USER and jenkins user to Docker group..."
sudo usermod -aG docker "$USER"
sudo usermod -aG docker jenkins

# ---------------------------
# Step 7: Enable & Restart Services
# ---------------------------
log "Enabling and starting Docker and Jenkins services..."
sudo systemctl enable docker
sudo systemctl restart docker
sudo systemctl enable jenkins
sudo systemctl restart jenkins

# ---------------------------
# Step 8: Install Trivy
# ---------------------------
log "Installing Trivy (container scanning tool)..."
sudo apt-get install -y wget apt-transport-https gnupg lsb-release unzip
wget -qO - https://aquasecurity.github.io/trivy-repo/deb/public.key | sudo apt-key add -
echo "deb https://aquasecurity.github.io/trivy-repo/deb $(lsb_release -sc) main" | \
    sudo tee /etc/apt/sources.list.d/trivy.list
sudo apt-get update
install_package trivy

# ---------------------------
# Step 9: Install OWASP Dependency-Check
# ---------------------------
log "Installing OWASP Dependency-Check..."
wget -qO /tmp/dependency-check.zip \
    https://github.com/jeremylong/DependencyCheck/releases/latest/download/dependency-check-8.3.1-release.zip
sudo unzip -o /tmp/dependency-check.zip -d /opt/
sudo ln -sf /opt/dependency-check/bin/dependency-check.sh /usr/local/bin/dependency-check

# ---------------------------
# Step 10: Run OWASP ZAP in Docker
# ---------------------------
log "Running OWASP ZAP (DAST) in Docker..."
docker run -d --name zap -u zap -p 8080:8080 owasp/zap2docker-stable zap-webswing.sh

# ---------------------------
# Step 11: Verify Installations
# ---------------------------
log "Verifying installed tools..."
check_command java "Java"
check_command jenkins "Jenkins CLI"
check_command docker "Docker"
check_command node "Node.js"
check_command npm "npm"
check_command trivy "Trivy"
check_command dependency-check "OWASP Dependency-Check"

log "✅ All installations completed successfully!"
log "ℹ️  You may need to log out and log back in for Docker group changes to take effect."
log "📌 OWASP ZAP is running at http://localhost:8080 (inside Docker container)."
