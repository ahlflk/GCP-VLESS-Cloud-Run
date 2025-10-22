#!/bin/bash

set -euo pipefail

# Enhanced Colors
RED='\033[0;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
ORANGE='\033[0;33m'
CYAN='\033[1;36m'
WHITE='\033[1;37m'
BOLD='\033[1m'
UNDERLINE='\033[4m'
BG_BLUE='\033[44m'
NC='\033[0m'

# Progress bar function for better UX
progress_bar() {
    local duration=${1}
    local bar_length=20
    local elapsed=0
    echo -ne "${CYAN}[${NC}"
    while [ $elapsed -lt $duration ]; do
        local progress=$((elapsed * bar_length / duration))
        local filled=$(printf "#%.0s" $(seq 1 $progress))
        local empty=$(printf " %.0s" $(seq 1 $((bar_length - progress))))
        echo -ne "\r${CYAN}[${GREEN}${filled}${CYAN}${empty}${NC}${NC} ] ${elapsed}s/${duration}s"
        sleep 1
        elapsed=$((elapsed + 1))
    done
    echo -e "\r${GREEN}[${filled}${NC}${NC} ] Complete!${NC}\n"
}

log() {
    echo -e "${GREEN}✅ [$(date +'%Y-%m-%d %H:%M:%S')]${NC} ${WHITE}$1${NC}"
}

warn() {
    echo -e "${YELLOW}⚠️ [WARNING]${NC} ${WHITE}$1${NC}"
}

error() {
    echo -e "${RED}❌ [ERROR]${NC} ${WHITE}$1${NC}"
    exit 1
}

info() {
    echo -e "${BLUE}${BOLD}ℹ️ [INFO]${NC} ${WHITE}$1${NC}"
}

header() {
    echo -e "${ORANGE}${BOLD}══════════════════════════════════════════${NC}"
    echo -e "${BG_BLUE}${WHITE}${BOLD} $1 ${NC}"
    echo -e "${ORANGE}${BOLD}══════════════════════════════════════════${NC}"
}

selected_info() {
    echo -e "${GREEN}${BOLD}🎯 Selected: ${CYAN}${UNDERLINE}$1${NC}${NC}"
}

# Function to validate UUID format
validate_uuid() {
    local uuid_pattern='^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
    if [[ ! $1 =~ $uuid_pattern ]]; then
        error "Invalid UUID format: $1"
        return 1
    fi
    return 0
}

# Function to validate Telegram Bot Token
validate_bot_token() {
    local token_pattern='^[0-9]{8,10}:[a-zA-Z0-9_-]{35}$'
    if [[ ! $1 =~ $token_pattern ]]; then
        error "Invalid Telegram Bot Token format"
        return 1
    fi
    return 0
}

# Function to validate Channel/Group ID
validate_channel_id() {
    if [[ ! $1 =~ ^-?[0-9]+$ ]]; then
        error "Invalid Channel/Group ID format"
        return 1
    fi
    return 0
}

# Function to validate Chat ID (for bot private messages)
validate_chat_id() {
    if [[ ! $1 =~ ^-?[0-9]+$ ]]; then
        error "Invalid Chat ID format"
        return 1
    fi
    return 0
}

# Enhanced CPU selection with default 2 cores (option 2)
select_cpu() {
    header "🖥️ CPU Configuration"
    echo -e "${CYAN}Available Options:${NC}"
    echo -e "${BOLD}1.${NC} 1  CPU Core (Lightweight)"
    echo -e "${BOLD}2.${NC} 2  CPU Cores (Balanced) ${GREEN}[DEFAULT]${NC}"
    echo -e "${BOLD}3.${NC} 4  CPU Cores (Performance)"
    echo -e "${BOLD}4.${NC} 8  CPU Cores (High Performance)"
    echo -e "${BOLD}5.${NC} 16 CPU Cores (Advanced - Requires Dedicated Machine Type)${NC}"
    echo
    
    while true; do
        read -p "Select CPU cores (2): " cpu_choice
        cpu_choice=${cpu_choice:-2}
        case $cpu_choice in
            1) CPU="1"; break ;;
            2) CPU="2"; break ;;
            3) CPU="4"; break ;;
            4) CPU="8"; break ;;
            5) CPU="16"; warn "16 cores requires --machine-type for Cloud Run v2."; break ;;
            *) echo -e "${RED}Invalid selection. Please enter a number between 1-5.${NC}" ;;
        esac
    done
    
    selected_info "CPU: $CPU core(s)"
}

# Enhanced Memory selection with default 2Gi (option 2), no recommend
select_memory() {
    header "💾 Memory Configuration"
    
    echo -e "${CYAN}Available Options:${NC}"
    echo -e "${BOLD}1.${NC} 1Gi"
    echo -e "${BOLD}2.${NC} 2Gi ${GREEN}[DEFAULT]${NC}"
    echo -e "${BOLD}3.${NC} 4Gi"
    echo -e "${BOLD}4.${NC} 8Gi"
    echo -e "${BOLD}5.${NC} 16Gi"
    echo -e "${BOLD}6.${NC} 32Gi"
    echo -e "${BOLD}7.${NC} 64Gi"
    echo -e "${BOLD}8.${NC} 128Gi${NC}"
    echo
    
    while true; do
        read -p "Select memory (2): " memory_choice
        memory_choice=${memory_choice:-2}
        case $memory_choice in
            1) MEMORY="1Gi"; break ;;
            2) MEMORY="2Gi"; break ;;
            3) MEMORY="4Gi"; break ;;
            4) MEMORY="8Gi"; break ;;
            5) MEMORY="16Gi"; break ;;
            6) MEMORY="32Gi"; break ;;
            7) MEMORY="64Gi"; break ;;
            8) MEMORY="128Gi"; break ;;
            *) echo -e "${RED}Invalid selection. Please enter a number between 1-8.${NC}" ;;
        esac
    done
    
    # Validate memory configuration
    validate_memory_config
    
    selected_info "Memory: $MEMORY"
}

# Validate memory configuration based on CPU (enhanced with more ranges)
validate_memory_config() {
    local cpu_num=$CPU
    local memory_num=$(echo $MEMORY | sed 's/[^0-9]*//g' | tr -d ' ')
    local memory_unit=$(echo $MEMORY | sed 's/[0-9]*//g' | tr -d ' ')
    
    # Convert everything to Mi for comparison
    if [[ "$memory_unit" == "Gi" ]]; then
        memory_num=$((memory_num * 1024))
    fi
    
    local min_memory=0 max_memory=0
    
    case $cpu_num in
        1) 
            min_memory=512
            max_memory=2048
            ;;
        2) 
            min_memory=1024
            max_memory=4096
            ;;
        4) 
            min_memory=2048
            max_memory=8192
            ;;
        8) 
            min_memory=4096
            max_memory=16384
            ;;
        16) 
            min_memory=8192
            max_memory=32768  # Up to 32Gi
            ;;
    esac
    
    if [[ $memory_num -lt $min_memory ]]; then
        warn "Memory ($MEMORY) might be too low for $CPU CPU core(s). Min: $((min_memory / 1024))Gi"
        read -p "Continue? (y/n): " confirm
        if [[ ! $confirm =~ [Yy] ]]; then
            select_memory
        fi
    elif [[ $memory_num -gt $max_memory ]]; then
        warn "Memory ($MEMORY) might be too high for $CPU CPU core(s). Max: $((max_memory / 1024))Gi"
        read -p "Continue? (y/n): " confirm
        if [[ ! $confirm =~ [Yy] ]]; then
            select_memory
        fi
    fi
}

# Enhanced Region selection with default 1 (us-central1)
select_region() {
    header "🌍 Region Selection"
    echo -e "${CYAN}Available GCP Regions:${NC}"
    echo -e "${BOLD}1.${NC}  🇺🇸 us-central1 (Council Bluffs, Iowa, North America) ${GREEN}[DEFAULT]${NC}"
    echo -e "${BOLD}2.${NC}  🇺🇸 us-east1 (Moncks Corner, South Carolina, North America)" 
    echo -e "${BOLD}3.${NC}  🇺🇸 us-south1 (Dallas, Texas, North America)"
    echo -e "${BOLD}4.${NC}  🇺🇸 southamerica-west1 (Santiago, Chile, South America)"
    echo -e "${BOLD}5.${NC}  🇺🇸 us-west1 (The Dalles, Oregon, North America)"
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
            4) REGION="southamerica-west1"; break ;;
            5) REGION="us-west1"; break ;;
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
}

# Enhanced Telegram destination selection with default 5 (none)
select_telegram_destination() {
    header "📱 Telegram Destination"
    echo -e "${CYAN}Available Options:${NC}"
    echo -e "${BOLD}1.${NC} Send to Channel only"
    echo -e "${BOLD}2.${NC} Send to Bot private message only" 
    echo -e "${BOLD}3.${NC} Send to both Channel and Bot"
    echo -e "${BOLD}4.${NC} Send to Group only"
    echo -e "${BOLD}5.${NC} Don't send to Telegram ${GREEN}[DEFAULT]${NC}"
    echo
    
    while true; do
        read -p "Select destination (5): " telegram_choice
        telegram_choice=${telegram_choice:-5}
        case $telegram_choice in
            1) 
                TELEGRAM_DESTINATION="channel"
                while true; do
                    read -p "Enter Telegram Channel ID: " TELEGRAM_CHANNEL_ID
                    if validate_channel_id "$TELEGRAM_CHANNEL_ID"; then
                        break
                    fi
                done
                break 
                ;;
            2) 
                TELEGRAM_DESTINATION="bot"
                while true; do
                    read -p "Enter your Chat ID (for bot private message): " TELEGRAM_CHAT_ID
                    if validate_chat_id "$TELEGRAM_CHAT_ID"; then
                        break
                    fi
                done
                break 
                ;;
            3) 
                TELEGRAM_DESTINATION="both"
                while true; do
                    read -p "Enter Telegram Channel ID: " TELEGRAM_CHANNEL_ID
                    if validate_channel_id "$TELEGRAM_CHANNEL_ID"; then
                        break
                    fi
                done
                while true; do
                    read -p "Enter your Chat ID (for bot private message): " TELEGRAM_CHAT_ID
                    if validate_chat_id "$TELEGRAM_CHAT_ID"; then
                        break
                    fi
                done
                break 
                ;;
            4) 
                TELEGRAM_DESTINATION="group"
                while true; do
                    read -p "Enter Telegram Group ID: " TELEGRAM_GROUP_ID
                    if validate_channel_id "$TELEGRAM_GROUP_ID"; then
                        break
                    fi
                done
                break 
                ;;
            5) 
                TELEGRAM_DESTINATION="none"
                break 
                ;;
            *) echo -e "${RED}Invalid selection. Please enter a number between 1-5.${NC}" ;;
        esac
    done

    selected_info "Telegram Destination: $TELEGRAM_DESTINATION"
}

# Enhanced Service Configuration with menu options
get_user_input() {
    header "⚙️ Service Configuration"
    echo -e "${CYAN}Available Options:${NC}"
    echo -e "${BOLD}1.${NC} Enter custom service name"
    echo -e "${BOLD}2.${NC} Use default service name (gcp-ahlflk) ${GREEN}[DEFAULT]${NC}"
    echo
    
    while true; do
        read -p "Select service name option (2): " service_choice
        service_choice=${service_choice:-2}
        case $service_choice in
            1)
                while true; do
                    read -p "Enter service name: " SERVICE_NAME
                    if [[ -n "$SERVICE_NAME" ]]; then
                        break
                    else
                        error "Service name cannot be empty"
                    fi
                done
                break
                ;;
            2)
                SERVICE_NAME="gcp-ahlflk"
                break
                ;;
            *) echo -e "${RED}Invalid selection. Please enter 1 or 2.${NC}" ;;
        esac
    done
    
    selected_info "Service Name: $SERVICE_NAME"
    echo
    # UUID (try uuidgen if available)
    echo -e "${CYAN}UUID Options:${NC}"
    echo -e "${BOLD}1.${NC} Generate new UUID"
    echo -e "${BOLD}2.${NC} Use default UUID (3675119c-14fc-46a4-b5f3-9a2c91a7d802) ${GREEN}[DEFAULT]${NC}"
    echo -e "${BOLD}3.${NC} Enter custom UUID"
    echo
    
    while true; do
        read -p "Select UUID option (2): " uuid_choice
        uuid_choice=${uuid_choice:-2}
        case $uuid_choice in
            1)
                if command -v uuidgen &> /dev/null; then
                    UUID=$(uuidgen)
                else
                    UUID=$(cat /proc/sys/kernel/random/uuid)
                fi
                echo -e "${GREEN}Generated UUID: $UUID${NC}"
                break
                ;;
            2)
                UUID="3675119c-14fc-46a4-b5f3-9a2c91a7d802"
                echo -e "${GREEN}Using default UUID: $UUID${NC}"
                break
                ;;
            3)
                while true; do
                    read -p "Enter custom UUID [default: 3675119c-14fc-46a4-b5f3-9a2c91a7d802]: " UUID
                    UUID=${UUID:-"3675119c-14fc-46a4-b5f3-9a2c91a7d802"}
                    if validate_uuid "$UUID"; then
                        echo -e "${GREEN}Using custom UUID: $UUID${NC}"
                        break
                    fi
                done
                break
                ;;
            *) echo -e "${RED}Invalid selection. Please enter 1, 2 or 3.${NC}" ;;
        esac
    done
    
    selected_info "UUID: $UUID"
    echo
    # Telegram Bot Token (required for any Telegram option)
    if [[ "$TELEGRAM_DESTINATION" != "none" ]]; then
        echo -e "${CYAN}Bot Token Options:${NC}"
        echo -e "${BOLD}1.${NC} Enter bot token ${GREEN}[REQUIRED]${NC}"
        echo
        
        while true; do
            read -p "Enter Telegram Bot Token: " TELEGRAM_BOT_TOKEN
            if validate_bot_token "$TELEGRAM_BOT_TOKEN"; then
                break
            fi
        done
        
        selected_info "Bot Token: ${TELEGRAM_BOT_TOKEN:0:8}..."
    fi
    echo
    # Host Domain (optional)
    echo -e "${CYAN}Host Domain Options:${NC}"
    echo -e "${BOLD}1.${NC} Use default (m.googleapis.com) ${GREEN}[DEFAULT]${NC}"
    echo -e "${BOLD}2.${NC} Enter custom host domain"
    echo
    
    while true; do
        read -p "Select host domain option (1): " host_choice
        host_choice=${host_choice:-1}
        case $host_choice in
            1)
                HOST_DOMAIN="m.googleapis.com"
                break
                ;;
            2)
                read -p "Enter host domain: " HOST_DOMAIN
                HOST_DOMAIN=${HOST_DOMAIN:-"m.googleapis.com"}
                break
                ;;
            *) echo -e "${RED}Invalid selection. Please enter 1 or 2.${NC}" ;;
        esac
    done
    
    selected_info "Host Domain: $HOST_DOMAIN"
}

# Display configuration summary (enhanced formatting)
show_config_summary() {
    header "📋 Configuration Summary"
    echo -e "${CYAN}${BOLD}Project ID:${NC} $(gcloud config get-value project)"
    echo -e "${CYAN}${BOLD}Region:${NC}        $REGION"
    echo -e "${CYAN}${BOLD}Service Name:${NC}  $SERVICE_NAME"
    echo -e "${CYAN}${BOLD}Host Domain:${NC}   $HOST_DOMAIN"
    echo -e "${CYAN}${BOLD}UUID:${NC}          $UUID"
    echo -e "${CYAN}${BOLD}CPU:${NC}           $CPU core(s)"
    echo -e "${CYAN}${BOLD}Memory:${NC}        $MEMORY"
    
    if [[ "$TELEGRAM_DESTINATION" != "none" ]]; then
        echo -e "${CYAN}${BOLD}Bot Token:${NC}     ${TELEGRAM_BOT_TOKEN:0:8}..."
        echo -e "${CYAN}${BOLD}Destination:${NC}   $TELEGRAM_DESTINATION"
        if [[ "$TELEGRAM_DESTINATION" == "channel" || "$TELEGRAM_DESTINATION" == "both" ]]; then
            echo -e "${CYAN}${BOLD}Channel ID:${NC}    $TELEGRAM_CHANNEL_ID"
        fi
        if [[ "$TELEGRAM_DESTINATION" == "bot" || "$TELEGRAM_DESTINATION" == "both" ]]; then
            echo -e "${CYAN}${BOLD}Chat ID:${NC}       $TELEGRAM_CHAT_ID"
        fi
        if [[ "$TELEGRAM_DESTINATION" == "group" ]]; then
            echo -e "${CYAN}${BOLD}Group ID:${NC}      $TELEGRAM_GROUP_ID"
        fi
    else
        echo -e "${CYAN}${BOLD}Telegram:${NC} Not configured"
    fi
    echo
    
    while true; do
        read -p "Proceed with deployment? (y/n): " confirm
        case $confirm in
            [Yy]* ) break;;
            [Nn]* ) 
                info "Deployment cancelled by user"
                exit 0
                ;;
            * ) echo -e "${RED}Please answer yes (y) or no (n).${NC}";;
        esac
    done
}

# Validation functions
validate_prerequisites() {
    log "Validating prerequisites..."
    
    if ! command -v gcloud &> /dev/null; then
        error "gcloud CLI is not installed. Please install Google Cloud SDK."
    fi
    
    if ! command -v git &> /dev/null; then
        error "git is not installed. Please install git."
    fi
    
    local PROJECT_ID=$(gcloud config get-value project)
    if [[ -z "$PROJECT_ID" || "$PROJECT_ID" == "(unset)" ]]; then
        error "No project configured. Run: gcloud config set project PROJECT_ID"
    fi
}

cleanup() {
    log "Cleaning up temporary files..."
    if [[ -d "GCP-VLESS-Cloud-Run" ]]; then
        rm -rf GCP-VLESS-Cloud-Run
    fi
    # Clean up temporary cloudbuild.yaml
    if [[ -f "cloudbuild.yaml" ]]; then
        rm -f cloudbuild.yaml
    fi
}

# Enhanced send_to_telegram with escape for special chars
send_to_telegram() {
    local chat_id="$1"
    local message="$2"
    # Escape special Markdown chars
    message=$(echo "$message" | sed 's/\*/\\*/g; s/_/\\_/g; s/`/\\`/g; s/\[/\\[/g')
    local response
    
    response=$(curl -s -w "%{http_code}" -X POST \
        -H "Content-Type: application/json" \
        -d "{
            \"chat_id\": \"${chat_id}\",
            \"text\": \"$message\",
            \"parse_mode\": \"MARKDOWN\",
            \"disable_web_page_preview\": true
        }" \
        https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage)
    
    local http_code="${response: -3}"
    local content="${response%???}"
    
    if [[ "$http_code" == "200" ]]; then
        return 0
    else
        error "Failed to send to Telegram (HTTP $http_code): $content"
        return 1
    fi
}

# Enhanced send_deployment_notification with group support
send_deployment_notification() {
    local message="$1"
    local success_count=0
    
    case $TELEGRAM_DESTINATION in
        "channel")
            log "Sending to Telegram Channel..."
            if send_to_telegram "$TELEGRAM_CHANNEL_ID" "$message"; then
                log "✅ Successfully sent to Telegram Channel"
                success_count=$((success_count + 1))
            else
                error "❌ Failed to send to Telegram Channel"
            fi
            ;;
            
        "bot")
            log "Sending to Bot private message..."
            if send_to_telegram "$TELEGRAM_CHAT_ID" "$message"; then
                log "✅ Successfully sent to Bot private message"
                success_count=$((success_count + 1))
            else
                error "❌ Failed to send to Bot private message"
            fi
            ;;
            
        "both")
            log "Sending to both Channel and Bot..."
            if send_to_telegram "$TELEGRAM_CHANNEL_ID" "$message"; then
                success_count=$((success_count + 1))
            fi
            if send_to_telegram "$TELEGRAM_CHAT_ID" "$message"; then
                success_count=$((success_count + 1))
            fi
            ;;
            
        "group")
            log "Sending to Telegram Group..."
            if send_to_telegram "$TELEGRAM_GROUP_ID" "$message"; then
                log "✅ Successfully sent to Telegram Group"
                success_count=$((success_count + 1))
            else
                error "❌ Failed to send to Telegram Group"
            fi
            ;;
            
        "none")
            log "Skipping Telegram notification as configured"
            return 0
            ;;
    esac
    
    if [[ $success_count -gt 0 ]]; then
        log "Telegram notification completed ($success_count successful)"
        return 0
    else
        warn "All Telegram notifications failed, but deployment was successful"
        return 1
    fi
}

main() {
    header "🚀 GCP Cloud Run VLESS Deployment (Quiet Logs Edition)"
    
    # Get user input
    select_region
    select_cpu
    select_memory
    select_telegram_destination
    get_user_input
    show_config_summary
    
    PROJECT_ID=$(gcloud config get-value project)
    
    log "Starting Cloud Run deployment..."
    log "Project: $PROJECT_ID | Region: $REGION | Service: $SERVICE_NAME | CPU: $CPU | Memory: $MEMORY"
    
    validate_prerequisites
    
    # Set trap for cleanup
    trap cleanup EXIT
    
    log "Enabling required APIs..."
    progress_bar 3
    gcloud services enable \
        cloudbuild.googleapis.com \
        run.googleapis.com \
        iam.googleapis.com \
        --quiet
    
    # Clean up any existing directory
    cleanup
    
    log "Cloning repository..."
    progress_bar 5
    if ! git clone https://github.com/ahlflk/GCP-VLESS-Cloud-Run.git; then
        error "Failed to clone repository - using local files if available"
        # Fallback: Assume local Dockerfile and config.json
        mkdir -p GCP-VLESS-Cloud-Run
        # Here you can copy local files, but for now assume clone works
        exit 1
    fi
    
    cd GCP-VLESS-Cloud-Run
    
    # Replace UUID in config.json if exists
    if [[ -f "config.json" ]]; then
        sed -i "s/PLACEHOLDER_UUID/$UUID/g" config.json
        log "Updated UUID in config.json"
    fi
    
    # Quiet the Dockerfile: Add -q to unzip, -qq to apt-get, etc. to suppress verbose output
    if [[ -f "Dockerfile" ]]; then
        sed -i 's/unzip Xray-linux-64.zip/unzip -q Xray-linux-64.zip/g' Dockerfile
        sed -i 's/apt-get update -y/apt-get update -qq -y/g' Dockerfile
        sed -i 's/apt-get install -y/apt-get install -qq -y/g' Dockerfile
        log "Quietened Dockerfile (unzip -q and apt -qq added to reduce logs)"
    fi
    
    # Create temporary cloudbuild.yaml to disable colors and reduce verbosity
    cat > cloudbuild.yaml << EOF
steps:
- name: 'gcr.io/cloud-builders/docker'
  args: ['build', '-t', 'gcr.io/$PROJECT_ID/gcp-v2ray-image', '.']
  env:
  - 'NO_COLOR=1'
  - 'DOCKER_BUILDKIT=1'  # Use BuildKit for quieter progress
- name: 'gcr.io/cloud-builders/docker'
  args: ['push', 'gcr.io/$PROJECT_ID/gcp-v2ray-image']
  env:
  - 'NO_COLOR=1'
images:
- 'gcr.io/$PROJECT_ID/gcp-v2ray-image'
EOF
    log "Created cloudbuild.yaml for clean, quiet build logs"
    
    log "Building container image (quiet mode)..."
progress_bar 10
if ! gcloud builds submit --config cloudbuild.yaml --quiet > /dev/null 2>&1; then
    error "Build failed. Check Dockerfile for issues with geo files download."
fi
    
    log "Deploying to Cloud Run..."
    progress_bar 8
    # For 16 CPU, add machine-type if needed (simplified)
    local deploy_cmd="gcloud run deploy ${SERVICE_NAME} \
        --image gcr.io/${PROJECT_ID}/gcp-v2ray-image \
        --platform managed \
        --region ${REGION} \
        --allow-unauthenticated \
        --cpu ${CPU} \
        --memory ${MEMORY} \
        --quiet"
    if [[ $CPU == "16" ]]; then
        deploy_cmd="$deploy_cmd --machine-type e2-standard-16"  # Example for dedicated
    fi
    if ! eval "$deploy_cmd"; then
        error "Deployment failed"
        exit 1
    fi
    
    # Get the service URL
    SERVICE_URL=$(gcloud run services describe ${SERVICE_NAME} \
        --region ${REGION} \
        --format 'value(status.url)' \
        --quiet)
    
    DOMAIN=$(echo $SERVICE_URL | sed 's|https://||')
    
    # Create Vless share link
    VLESS_LINK="vless://${UUID}@${HOST_DOMAIN}:443?path=%2Fvless&security=tls&encryption=none&host=${DOMAIN}&fp=randomized&type=ws&sni=${DOMAIN}#${SERVICE_NAME}"
    
    # Create telegram message (enhanced)
    MESSAGE="*🚀 Cloud Run VLESS Deploy → Successful ✅*
━━━━━━━━━━━━━━━━━━━━
*Project:* \`${PROJECT_ID}\`
*Service:* \`${SERVICE_NAME}\`
*Region:* \`${REGION}\`
*CPU:* \`${CPU} core(s)\`
*Memory:* \`${MEMORY}\`
*URL:* \`${SERVICE_URL}\`

\`\`\`
${VLESS_LINK}
\`\`\`
━━━━━━━━━━━━━━━━━━━━
*Usage:* Copy the link and import to your V2Ray/Xray client."

    # Create console message
    CONSOLE_MESSAGE="🚀 Cloud Run VLESS Deploy Success ✅
━━━━━━━━━━━━━━━━━━━━
Project: ${PROJECT_ID}
Service: ${SERVICE_NAME}
Region: ${REGION}
CPU: ${CPU} core(s)
Memory: ${MEMORY}
URL: ${SERVICE_URL}

${VLESS_LINK}

Usage: Copy the above link and import to your V2Ray/Xray client.
━━━━━━━━━━━━━━━━━━━━"
    
    # Save to file
    echo "$CONSOLE_MESSAGE" > deployment-info.txt
    log "Deployment info saved to deployment-info.txt"
    
    # Display locally
    echo
    info "=== Deployment Information ==="
    echo "$CONSOLE_MESSAGE"
    echo
    
    # Send to Telegram based on user selection
    if [[ "$TELEGRAM_DESTINATION" != "none" ]]; then
        log "Sending deployment info to Telegram..."
        send_deployment_notification "$MESSAGE"
    else
        log "Skipping Telegram notification as per user selection"
    fi
    
    log "Deployment completed successfully! 🎉"
    log "Service URL: $SERVICE_URL"
    log "Configuration saved to: deployment-info.txt"
}

# Run main function
main "$@"