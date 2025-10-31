#!/bin/bash

# GCP Cloud Run VLESS Deployment

set -euo pipefail

# ------------------------------------------------------------------------------
# 1. GLOBAL VARIABLES & STYLES
# ------------------------------------------------------------------------------

# Colors
RED='\033[0;31m'
GREEN='\033[1;32m'
LIGHT_GREEN='\033[1;92m'  # Light Green for bar
YELLOW='\033[1;33m'
ORANGE='\033[0;33m' # Header Color
BLUE='\033[1;34m'
CYAN='\033[1;36m'
WHITE='\033[1;37m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Global Configuration Variables (Defaults) - Hardcoded to VLESS-WS
PROTOCOL="VLESS-WS"
UUID=""
REGION="us-central1"
CPU="2"
MEMORY="2Gi"
SERVICE_NAME="gcp-ahlflk"
HOST_DOMAIN="m.googleapis.com"
VLESS_PATH="/ahlflk"

# Telegram Variables (will be set during selection)
TELEGRAM_DESTINATION="none"
TELEGRAM_BOT_TOKEN=""
TELEGRAM_CHANNEL_ID=""
TELEGRAM_CHAT_ID=""
TELEGRAM_GROUP_ID=""

# Project ID holder (Will be set during auto_deployment_setup after Yes/No)
PROJECT_ID=""

# Time Variables (Initialized later)
START_EPOCH=""
END_EPOCH=""
START_LOCAL=""
END_LOCAL=""


# ------------------------------------------------------------------------------
# 2. UTILITY FUNCTIONS (LOGGING, UI, VALIDATION, TIME)
# ------------------------------------------------------------------------------

# Emoji Function
show_emojis() {
    # Define Emojis
    EMOJI_SUCCESS="✅"
    EMOJI_WARN="⚠️"
    EMOJI_ERROR="❌"
    EMOJI_INFO="💡"
    EMOJI_SELECT="🎯"
    EMOJI_PROC="⚙️"
    EMOJI_DEPLOY="🚀"
    EMOJI_CHECK="📋"
    EMOJI_CLEAN="🧹"
}

# Beautiful Header/Banner (New Design: Fully enclosed box, adjusted to title width)
header() {
    local title="$1"
    local border_color="${ORANGE}"
    local text_color="${YELLOW}"
    
    # Calculate title length
    local title_length=${#title}
    local padding=4 # Space on both sides: " | <space> TITLE <space> | "
    local total_width=$((title_length + padding))
    
    # Create top/bottom border line (using Unicode box drawing characters)
    local top_bottom_fill=$(printf '━%.0s' $(seq 1 $((total_width - 2))))
    local top_bottom="${border_color}┏${top_bottom_fill}┓${NC}"
    local bottom_line="${border_color}┗${top_bottom_fill}┛${NC}"
    
    # Create title line
    local title_line="${border_color}┃${NC} ${text_color}${BOLD}${title}${NC} ${border_color}┃${NC}"
    
    echo -e "${top_bottom}"
    echo -e "${title_line}"
    echo -e "${bottom_line}"
}

# Simple Logs with Emoji
log() {
    echo -e "${GREEN}${BOLD}${EMOJI_SUCCESS} [LOG]${NC} ${WHITE}$1${NC}"
}

warn() {
    echo -e "${YELLOW}${BOLD}${EMOJI_WARN} [WARN]${NC} ${WHITE}$1${NC}"
}

error() {
    echo -e "${RED}${BOLD}${EMOJI_ERROR} [ERROR]${NC} ${WHITE}$1${NC}"
    exit 1
}

info() {
    echo -e "${BLUE}${BOLD}${EMOJI_INFO} [INFO]${NC} ${WHITE}$1${NC}"
}

selected_info() {
    echo -e "${GREEN}${BOLD}${EMOJI_SELECT} Selected:${NC} ${CYAN}$1${NC}"
}

# ------------------------------------------------------------------------------
# PROGRESS BAR
# ------------------------------------------------------------------------------
progress_bar() {
    local label="${1:-Processing}" 
    local duration=${2:-3}  
    local width=30         
    local start=$(date +%s)
    local elapsed=0
    
    # Progress Bar Loop
    while [ $elapsed -lt $duration ]; do
        local percent=$((elapsed * 100 / duration))
        local num_chars=$((percent * width / 100))
        local bar=$(printf '#%.0s' $(seq 1 $num_chars))
        local spaces=$(printf ' %.0s' $(seq 1 $((width - num_chars))))
        
        local remaining=$((duration - elapsed))
        
        # Display label, progress bar, percentage, and ETA
        printf "\r${BOLD}${EMOJI_PROC} ${label}... ${NC}[${LIGHT_GREEN}%s${NC}${ORANGE}%s${NC}] %d%% (ETA: %ds)${NC}" "$bar" "$spaces" "$percent" "$remaining"
        
        sleep 0.1
        elapsed=$(( $(date +%s) - start ))
    done
    
    # Final persistent line
    printf "\r${BOLD}${EMOJI_PROC} ${label}... ${NC}[${LIGHT_GREEN}%s${NC}] 100%% Done! (0s)${NC}\n" "$(printf '#%.0s' $(seq 1 $width))"
}
# ------------------------------------------------------------------------------

# === Time Zone Function ===
# Set the time zone globally for the script
export TZ="Asia/Yangon"

# Helper function to format epoch time to local datetime
fmt_dt(){ 
    # Using 'date' command to format the epoch time in the set TZ (Asia/Yangon)
    date -d @"$1" "+%d.%m.%Y %I:%M %p"; 
}

# Function to calculate and initialize time variables
initialize_time_variables() {
    START_EPOCH="$(date +%s)"
    # Note: 5 hours is only for display/tracking, Cloud Run service is permanent unless deleted
    END_EPOCH="$(( START_EPOCH + 5*3600 ))" 
    START_LOCAL="$(fmt_dt "$START_EPOCH")"
    END_LOCAL="$(fmt_dt "$END_EPOCH")"
    log "Deployment validity times initialized (Asia/Yangon Time)."
}

# Function to validate UUID format
validate_uuid() {
    local uuid_pattern='^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
    if [[ ! $1 =~ $uuid_pattern ]]; then
        warn "Invalid UUID format. Please ensure it is a valid 32-digit hexadecimal number with 4 hyphens."
        return 1
    fi
    return 0
}

# Function to validate Telegram IDs (combined for Channel/Group/Chat)
validate_id() {
    if [[ ! $1 =~ ^-?[0-9]+$ ]]; then
        warn "Invalid Telegram ID format. Must be a number (e.g., -1001234567890 or 123456789)."
        return 1
    fi
    return 0
}

# Function to validate Telegram Bot Token
validate_bot_token() {
    local token_pattern='^[0-9]{8,10}:[a-zA-Z0-9_-]{35}$'
    if [[ ! $1 =~ $token_pattern ]]; then
        warn "Invalid Telegram Bot Token format. Please try again."
        return 1
    fi
    return 0
}

# ------------------------------------------------------------------------------
# 3. USER INPUT FUNCTIONS (IN ORDER)
# ------------------------------------------------------------------------------

# A. Telegram Destination Selection
select_telegram_destination() {
    header "📱 Telegram Notification Settings"
    
    while true; do
        echo -e "${CYAN}Select where to send the deployment link:${NC}"
        echo -e "${BOLD}1.${NC} Don't send to Telegram ${GREEN}[DEFAULT]${NC}"
        echo -e "${BOLD}2.${NC} Send to Channel Only"
        echo -e "${BOLD}3.${NC} Send to Group Only"
        echo -e "${BOLD}4.${NC} Send to Bot Private Message" 
        echo -e "${BOLD}5.${NC} Send to Both Channel and Bot"
        echo
        
        read -p "Select destination (1): " telegram_choice
        telegram_choice=${telegram_choice:-1}
        
        case $telegram_choice in
            1) TELEGRAM_DESTINATION="none"; break ;;
            2) TELEGRAM_DESTINATION="channel"; break ;;
            3) TELEGRAM_DESTINATION="group"; break ;;
            4) TELEGRAM_DESTINATION="bot"; break ;;
            5) TELEGRAM_DESTINATION="both"; break ;;
            *) echo -e "${RED}Invalid selection. Please enter a number between 1-5.${NC}"; continue ;;
        esac
    done

    if [[ "$TELEGRAM_DESTINATION" != "none" ]]; then
        echo
        while true; do
            read -p "Enter Telegram Bot Token: " TELEGRAM_BOT_TOKEN
            if validate_bot_token "$TELEGRAM_BOT_TOKEN"; then break; else continue; fi
        done
        
        if [[ "$TELEGRAM_DESTINATION" == "channel" || "$TELEGRAM_DESTINATION" == "both" ]]; then
            while true; do
                read -p "Enter Telegram Channel ID: " TELEGRAM_CHANNEL_ID
                if validate_id "$TELEGRAM_CHANNEL_ID"; then break; fi
            done
        fi
        
        if [[ "$TELEGRAM_DESTINATION" == "bot" || "$TELEGRAM_DESTINATION" == "both" ]]; then
            while true; do
                read -p "Enter your Chat ID (for bot private message): " TELEGRAM_CHAT_ID
                if validate_id "$TELEGRAM_CHAT_ID"; then break; fi
            done
        fi
        
        if [[ "$TELEGRAM_DESTINATION" == "group" ]]; then
            while true; do
                read -p "Enter Telegram Group ID: " TELEGRAM_GROUP_ID
                if validate_id "$TELEGRAM_GROUP_ID"; then break; fi
            done
        fi
        selected_info "Bot Token: ${TELEGRAM_BOT_TOKEN:0:8}..."
    fi
    
    selected_info "Telegram Destination: $TELEGRAM_DESTINATION"
    echo
}

# B. Region Selection
select_region() {
    header "🌍 GCP Region Selection"
    echo -e "${CYAN}Available GCP Regions:${NC}"
    echo -e "${BOLD}1.${NC}  🇺🇸 us-central1 (Council Bluffs, Iowa, North America) ${GREEN}[DEFAULT]${NC}"
    echo -e "${BOLD}2.${NC}  🇺🇸 us-east1 (Moncks Corner, South Carolina, North America)" 
    echo -e "${BOLD}3.${NC}  🇺🇸 us-south1 (Dallas, Texas, North America)"
    echo -e "${BOLD}4.${NC}  🇺🇸 us-west1 (The Dalles, Oregon, North America)"
    echo -e "${BOLD}5.${NC}  🇺🇸 us-west2 (Los Angeles, California, North America)"
    echo -e "${BOLD}6.${NC}  🇨🇦 northamerica-northeast2 (Toronto, Ontario, North America)"
    echo -e "${BOLD}7.${NC}  🇸🇬 asia-southeast1 (Jurong West, Singapore)"
    echo -e "${BOLD}8.${NC}  🇯🇵 asia-northeast1 (Tokyo, Japan)"
    echo -e "${BOLD}9.${NC}  🇹🇼 asia-east1 (Changhua County, Taiwan)"
    echo -e "${BOLD}10.${NC} 🇭🇰 asia-east2 (Hong Kong)"
    echo -e "${BOLD}11.${NC} 🇮🇳 asia-south1 (Mumbai, India)"
    echo -e "${BOLD}12.${NC} 🇮🇩 asia-southeast2 (Jakarta, Indonesia)${NC}"
    echo
    
    while true; do
        read -p "Select region (1): " region_choice
        region_choice=${region_choice:-1}
        case $region_choice in
            1) REGION="us-central1"; break ;;
            2) REGION="us-east1"; break ;;
            3) REGION="us-south1"; break ;;
            4) REGION="us-west1"; break ;;
            5) REGION="us-west2"; break ;;
            6) REGION="northamerica-northeast2"; break ;;
            7) REGION="asia-southeast1"; break ;;
            8) REGION="asia-northeast1"; break ;;
            9) REGION="asia-east1"; break ;;
            10) REGION="asia-east2"; break ;;
            11) REGION="asia-south1"; break ;;
            12) REGION="asia-southeast2"; break ;;
            *) echo -e "${RED}Invalid selection. Please enter a number between 1-12.${NC}" ;;
        esac
    done
    
    selected_info "Region: $REGION"
    echo
}

# C. CPU Configuration
select_cpu() {
    header "🖥️  CPU Configuration"
    echo -e "${CYAN}Available Options:${NC}"
    echo -e "${BOLD}1.${NC} 1  CPU Core (Lightweight traffic)"
    echo -e "${BOLD}2.${NC} 2  CPU Cores (Balanced) ${GREEN}[DEFAULT]${NC}"
    echo -e "${BOLD}3.${NC} 4  CPU Cores (Performance)"
    echo -e "${BOLD}4.${NC} 8  CPU Cores (High Performance)"
    echo -e "${BOLD}5.${NC} 16 CPU Cores (Extreme Load)" 
    echo
    
    while true; do
        read -p "Select CPU cores (2): " cpu_choice
        cpu_choice=${cpu_choice:-2}
        case $cpu_choice in
            1) CPU="1"; break ;;
            2) CPU="2"; break ;;
            3) CPU="4"; break ;;
            4) CPU="8"; break ;;
            5) CPU="16"; break ;;
            *) echo -e "${RED}Invalid selection. Please enter a number between 1-5.${NC}" ;;
        esac
    done
    
    selected_info "CPU: $CPU core(s)"
    echo
}

# D. Memory Configuration
select_memory() {
    header "💾 Memory Configuration"
    
    echo -e "${CYAN}Available Options:${NC}"
    echo -e "${BOLD}1.${NC} 512Mi (Minimum requirement)"
    echo -e "${BOLD}2.${NC} 1Gi (Basic usage)"
    echo -e "${BOLD}3.${NC} 2Gi (Balanced usage) ${GREEN}[DEFAULT]${NC}"
    echo -e "${BOLD}4.${NC} 4Gi (Moderate performance)"
    echo -e "${BOLD}5.${NC} 8Gi (High load/many connections)"
    echo -e "${BOLD}6.${NC} 16Gi (Advanced/Extreme load)"
    echo -e "${BOLD}7.${NC} 32Gi (Maximum limit for Cloud Run)"
    echo
    
    while true; do
        read -p "Select memory (3): " memory_choice
        memory_choice=${memory_choice:-3}
        case $memory_choice in
            1) MEMORY="512Mi"; break ;;
            2) MEMORY="1Gi"; break ;;
            3) MEMORY="2Gi"; break ;;
            4) MEMORY="4Gi"; break ;;
            5) MEMORY="8Gi"; break ;;
            6) MEMORY="16Gi"; break ;;
            7) MEMORY="32Gi"; break ;;
            *) echo -e "${RED}Invalid selection. Please enter a number between 1-7.${NC}" ;;
        esac
    done
    
    selected_info "Memory: $MEMORY"
    echo
}

# E. Service Name Configuration
select_service_name() {
    header "${EMOJI_PROC} Service Name Configuration"
    
    echo -e "${CYAN}Deployment Service Name (Default: gcp-ahlflk):${NC}"
    
    read -p "Enter custom name or press Enter to use default: " custom_name
    SERVICE_NAME=${custom_name:-$SERVICE_NAME}
    
    if [[ -z "$SERVICE_NAME" ]]; then
        warn "Service name cannot be empty. Using default: gcp-ahlflk."
        SERVICE_NAME="gcp-ahlflk"
    fi
    
    selected_info "Service Name: $SERVICE_NAME"
    echo
}

# F. Host Domain Configuration
select_host_domain() {
    header "🌐 Host Domain Configuration"
    
    echo -e "${CYAN}SNI/Host Domain (Default: m.googleapis.com):${NC}"
    
    read -p "Enter custom domain or press Enter to use default: " custom_domain
    HOST_DOMAIN=${custom_domain:-$HOST_DOMAIN}
    
    if [[ -z "$HOST_DOMAIN" ]]; then
        warn "Host Domain cannot be empty. Using default: m.googleapis.com."
        HOST_DOMAIN="m.googleapis.com"
    fi
    
    selected_info "Host Domain: $HOST_DOMAIN"
    echo
}

# G. UUID Configuration (VLESS only)
select_uuid() {
    header "🔑 UUID Configuration"
    
    local default_uuid="3675119c-14fc-46a4-b5f3-9a2c91a7d802"
        
    while true; do
        echo -e "${CYAN}UUID Options:${NC}"
        echo -e "${BOLD}1.${NC} Use Default UUID (3675...802) ${GREEN}[DEFAULT]${NC}"
        echo -e "${BOLD}2.${NC} Generate New UUID"
        echo -e "${CYAN}You can also paste a custom UUID directly, or press Enter for default.${NC}"
        echo

        read -p "Enter 1, 2, or Paste Custom UUID: " uuid_input
        uuid_input=${uuid_input:-1}

        if [[ "$uuid_input" == "1" ]]; then
            UUID="$default_uuid"
            log "Using Default UUID."
            break
        elif [[ "$uuid_input" == "2" ]]; then
            if command -v uuidgen &> /dev/null; then
                UUID=$(uuidgen)
            else
                # Fallback for systems without uuidgen
                UUID=$(cat /proc/sys/kernel/random/uuid 2>/dev/null || echo "3675119c-14fc-46a4-b5f3-9a2c91a7d802")
                if [[ "$UUID" == "3675119c-14fc-46a4-b5f3-9a2c91a7d802" ]]; then
                     warn "uuidgen not found and /proc/sys/kernel/random/uuid is inaccessible. Using default UUID."
                fi
            fi
            log "Generated New UUID: $UUID"
            break
        elif validate_uuid "$uuid_input"; then
            # Custom UUID validation successful
            UUID="$uuid_input"
            log "Using Custom UUID: $UUID"
            break
        else
            echo -e "${RED}Invalid input. Please enter 1, 2, or a valid custom UUID.${NC}" 
        fi
    done
    
    selected_info "UUID: $UUID"
    echo
}


# H. Summary and Confirmation
show_config_summary() {
    # Get current configured project ID for display
    local temp_project_id=$(gcloud config get-value project 2>/dev/null || echo "Not Configured (Deployment will fail)")
    
    header "${EMOJI_CHECK} Configuration Summary"
    
    # Using printf for alignment
    printf "${CYAN}${BOLD}%-20s${NC} %s\n" "Project ID:"             "$temp_project_id"
    printf "${CYAN}${BOLD}%-20s${NC} %s\n" "Protocol:"               "$PROTOCOL"
    printf "${CYAN}${BOLD}%-20s${NC} %s\n" "Region:"                 "$REGION"
    printf "${CYAN}${BOLD}%-20s${NC} %s\n" "Service Name:"           "$SERVICE_NAME"
    printf "${CYAN}${BOLD}%-20s${NC} %s\n" "Host Domain:"            "$HOST_DOMAIN"
    printf "${CYAN}${BOLD}%-20s${NC} %s\n" "UUID:"                   "$UUID"
    printf "${CYAN}${BOLD}%-20s${NC} %s\n" "Path:"                   "$VLESS_PATH"
    printf "${CYAN}${BOLD}%-20s${NC} %s\n" "CPU/Memory:"             "$CPU core(s) / $MEMORY"
    
    if [[ "$TELEGRAM_DESTINATION" != "none" ]]; then
        printf "${CYAN}${BOLD}%-20s${NC} %s\n" "Telegram:" "$TELEGRAM_DESTINATION (Token: ${TELEGRAM_BOT_TOKEN:0:8}...)"
    else
        printf "${CYAN}${BOLD}%-20s${NC} %s\n" "Telegram:" "Not configured"
    fi
    echo

    # --- Timeframe Summary ---
    header "⏳ Deployment Timeframe (Asia/Yangon)"
    printf "${CYAN}${BOLD}%-20s${NC} %s\n" "Deployment Start:"       "$START_LOCAL"
    printf "${CYAN}${BOLD}%-20s${NC} %s\n" "Estimated End Time:"     "$END_LOCAL (5 hours)"
    echo
    # -------------------------
    
    while true; do
        read -p "$(echo -e "${ORANGE}${BOLD}Proceed with deployment? (y/n): ${NC}")" confirm
        case $confirm in
            [Yy]* ) 
                # After confirmation, start the auto-setup immediately
                auto_deployment_setup
                break
                ;;
            [Nn]* ) 
                info "Deployment cancelled by user"
                exit 0
                ;;
            * ) echo -e "${RED}Please answer yes (y) or no (n).${NC}";;
        esac
    done
}

# ------------------------------------------------------------------------------
# MODIFIED: AUTO DEPLOYMENT SETUP (Project ID CLI & API Enablement) - FULLY AUTOMATIC
# ------------------------------------------------------------------------------
auto_deployment_setup() {
    log "Starting initial GCP setup..."
    
    # 1. Check and Set Project ID CLI Configuration
    info "Fetching Project ID for CLI configuration." 
    PROJECT_ID=$(gcloud config get-value project 2>/dev/null)
    
    if [[ -z "$PROJECT_ID" ]]; then
        error "GCP Project ID is not configured in gcloud CLI. Please run 'gcloud config set project [PROJECT_ID]' and try again."
    fi
    
    selected_info "Using configured Project ID: $PROJECT_ID"

    # Set Project ID CLI Configuration (redundant but ensures the current context)
    log "Verifying gcloud CLI active project to: ${PROJECT_ID}"
    gcloud config set project "$PROJECT_ID" --quiet > /dev/null 2>&1
    progress_bar "Setting Project ID CLI" 3 # Time: 3s

    # 2. Enable Required APIs
    log "Enabling required APIs (Cloud Run, Container Registry, Cloud Build)..."
    gcloud services enable run.googleapis.com containerregistry.googleapis.com cloudbuild.googleapis.com --project "$PROJECT_ID" --quiet > /dev/null 2>&1
    progress_bar "Enabling APIs" 3 # Time: 3s (Increased for accuracy)

    log "Initial GCP setup complete. Proceeding with deployment..."
    progress_bar "GCP Setup" 3 # Time: 3s
}

# ------------------------------------------------------------------------------
# 4. CORE DEPLOYMENT FUNCTIONS 
# ------------------------------------------------------------------------------

# Clone Repo and Extract Files
clone_and_extract() {
    log "Cloning repository from https://github.com/ahlflk/GCP-VLESS-Cloud-Run.git..."
    git clone https://github.com/ahlflk/GCP-VLESS-Cloud-Run.git temp-repo > /dev/null 2>&1
    progress_bar "Cloning Repository" 5 # Time: 5s (Adjusted)

    if [ ! -d "temp-repo" ]; then
        error "Failed to clone repository. Check your network or permissions."
    fi
    
    cd temp-repo

    if [ ! -f "Dockerfile" ]; then
        error "Dockerfile not found in repo."
    fi
    if [ ! -f "config.json" ]; then
        error "config.json not found in repo."
    fi

    cp Dockerfile ../Dockerfile > /dev/null 2>&1
    cp config.json ../config.json > /dev/null 2>&1
    cd ..
    rm -rf temp-repo > /dev/null 2>&1
}

# Config File Preparation
prepare_config_files() {
    log "Preparing Xray config file for $PROTOCOL..."
    if [[ ! -f "config.json" ]]; then
        error "config.json not found."
    fi
    sed -i "s/PLACEHOLDER_UUID/$UUID/g" config.json
    sed -i "s|/vless|$VLESS_PATH|g" config.json
    progress_bar "Preparing Config" 10 # Time: 10s
}

# Share Link Creation (VLESS-WS only)
create_share_link() {
    local SERVICE_NAME="$1"
    local DOMAIN="$2"
    local UUID="$3"
    
    # URL Encode path
    local PATH_ENCODED=$(echo "$VLESS_PATH" | sed 's/\//%2F/g')
    
    # Remove https:// from DOMAIN if present
    DOMAIN="${DOMAIN#https://}"
    DOMAIN="${DOMAIN%/}"
    
    local LINK="vless://${UUID}@${HOST_DOMAIN}:443?path=${PATH_ENCODED}&security=tls&encryption=none&host=${DOMAIN}&fp=randomized&type=ws&sni=${DOMAIN}#${SERVICE_NAME}_VLESS-WS_${END_LOCAL}"
    
    echo "$LINK"
}

# Telegram Notification Function (Simplified)
send_to_telegram() {
    local chat_id="$1"
    local message="$2"
    # Escape special Markdown chars, but specifically keep the [link](url) format
    message=$(echo "$message" | sed 's/\*/\\*/g; s/_/\\_/g; s/`/\\`/g; s/\[🔗 Xray Link\]([^)]*)/[&](/g; s/\[/\\\[/g; s/\]/\\\]/g')
    # Re-enable the specific link format
    message=$(echo "$message" | sed 's/\\\[🔗 Xray Link\\\]/\[🔗 Xray Link\]/g')
    
    curl -s -o /dev/null -w "%{http_code}" -X POST \
        -H "Content-Type: application/json" \
        -d "{\"chat_id\": \"${chat_id}\", \"text\": \"$message\", \"parse_mode\": \"MARKDOWN\", \"disable_web_page_preview\": true}" \
        https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage
}

send_deployment_notification() {
    local message="$1"
    
    case $TELEGRAM_DESTINATION in
        "channel")
            send_to_telegram "$TELEGRAM_CHANNEL_ID" "$message" > /dev/null 2>&1
            log "Notification sent to Telegram Channel."
            ;;
        "bot")
            send_to_telegram "$TELEGRAM_CHAT_ID" "$message" > /dev/null 2>&1
            log "Notification sent to Bot private message."
            ;;
        "group")
            send_to_telegram "$TELEGRAM_GROUP_ID" "$message" > /dev/null 2>&1
            log "Notification sent to Telegram Group."
            ;;
        "both")
            send_to_telegram "$TELEGRAM_CHANNEL_ID" "$message" > /dev/null 2>&1
            send_to_telegram "$TELEGRAM_CHAT_ID" "$message" > /dev/null 2>&1
            log "Notification sent to both Channel and Bot."
            ;;
        "none")
            log "Skipping Telegram notification."
            ;;
    esac
}

# Deploy to Cloud Run
deploy_to_cloud_run() {
    local project_id="$PROJECT_ID"
    # Project ID is now guaranteed to be set by auto_deployment_setup()

    log "Building and pushing Docker image..."
    gcloud builds submit --tag gcr.io/$project_id/$SERVICE_NAME:v1 . --quiet > /dev/null 2>&1
    progress_bar "Building Docker Image" 15 # Time: 15s (Increased for accuracy)

    log "Deploying to Cloud Run service..."
    gcloud run deploy $SERVICE_NAME \
      --image gcr.io/$project_id/$SERVICE_NAME:v1 \
      --platform managed \
      --region $REGION \
      --allow-unauthenticated \
      --port 8080 \
      --memory $MEMORY \
      --cpu $CPU \
      --quiet > /dev/null 2>&1
    progress_bar "Deploying Service" 20 # Time: 20s (Increased for accuracy)

    local service_url=$(gcloud run services describe $SERVICE_NAME --region $REGION --format='value(status.url)' --quiet 2>/dev/null)
    if [[ -z "$service_url" ]]; then
        error "Failed to retrieve service URL after deployment."
    fi

    local share_link=$(create_share_link "$SERVICE_NAME" "$service_url" "$UUID")

    log "Deployment completed!"
    selected_info "Service URL: $service_url"
    selected_info "VLESS Share Link: $share_link"

    local telegram_message="🚀 *GCP VLESS Deployment Complete!*\n\n📋 *Details:*\n• Protocol: $PROTOCOL\n• Region: $REGION\n• Service: $SERVICE_NAME\n• UUID: $UUID\n• Start Time: $START_LOCAL\n• End Time: $END_LOCAL\n\n🔗 [VLESS Link]($share_link)"
    
    send_deployment_notification "$telegram_message"
}

# Create Folder with deployment-info.txt
create_project_folder() {
    local project_id="$PROJECT_ID"
    local service_url=$(gcloud run services describe $SERVICE_NAME --region $REGION --format='value(status.url)' --quiet 2>/dev/null)
    local share_link=$(create_share_link "$SERVICE_NAME" "$service_url" "$UUID")

    log "Saving project files and info to folder: GCP-VLESS-Cloud-Run/"
    mkdir -p GCP-VLESS-Cloud-Run
    # Move/Copy the generated files into the new folder
    mv Dockerfile GCP-VLESS-Cloud-Run/ > /dev/null 2>&1
    mv config.json GCP-VLESS-Cloud-Run/ > /dev/null 2>&1
    
    cat > GCP-VLESS-Cloud-Run/deployment-info.txt << EOF
GCP VLESS Cloud Run Deployment Info
===================================

Project ID: $project_id
Region: $REGION
Service Name: $SERVICE_NAME
UUID: $UUID
Path: $VLESS_PATH
Host Domain: $HOST_DOMAIN
CPU: $CPU
Memory: $MEMORY
Service URL: $service_url
VLESS Share Link: $share_link

Deployment Date (Asia/Yangon): $START_LOCAL
Estimated End Time (Asia/Yangon): $END_LOCAL (5 hours)
Protocol: $PROTOCOL

For more details, check GCP Console: https://console.cloud.google.com/run?project=$project_id
EOF
    
    log "Project files and info saved successfully in: GCP-VLESS-Cloud-Run/"
    info "Check the 'GCP-VLESS-Cloud-Run' folder for your deployment files and details."
}

# ------------------------------------------------------------------------------
# 5. MAIN EXECUTION BLOCK
# ------------------------------------------------------------------------------

# Initialize emojis
show_emojis

# Initialize Time Variables BEFORE asking for inputs
initialize_time_variables

# Run user input functions in specified order
run_user_inputs() {
    # Display main header
    header "${EMOJI_DEPLOY} GCP Cloud Run VLESS Deployment"
    select_telegram_destination
    select_region
    select_cpu
    select_memory
    select_service_name
    select_host_domain
    select_uuid
    # show_config_summary will call auto_deployment_setup() upon 'Yes'
    show_config_summary 
}

# Main execution
run_user_inputs

# Core Deployment Steps run automatically after auto_deployment_setup completes
clone_and_extract
prepare_config_files
deploy_to_cloud_run
create_project_folder 

info "All done! Check your GCP Console for the deployed service."

