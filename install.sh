#!/usr/bin/env bash

# Color definitions for better UX
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Function to print colored headers
print_header() {
    echo -e "\n${BOLD}${BLUE}===========================================${NC}"
    echo -e "${BOLD}${BLUE}  $1${NC}"
    echo -e "${BOLD}${BLUE}===========================================${NC}\n"
}

# Function to print step messages
print_step() {
    echo -e "${CYAN}[STEP]${NC} $1"
}

# Function to print success messages
print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

# Function to print error messages
print_error() {
    echo -e "${RED}✗${NC} $1"
}

# Function to print warning messages
print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

# Function to print info messages
print_info() {
    echo -e "${MAGENTA}ℹ${NC} $1"
}

print_header "Fork AI Commit Message - Installation"

# Set default configuration values
DEFAULT_CHATGPT_PROMPT="Suggest commit message based on the following diff:\n\n\`\`\`\n{{diff}}\n\`\`\`\n\ncommit messages must be following these rules:\n - follow conventional commits\n - message format must be in this format: \"<TYPE>: <DESCRIPTION>\"\n - <TYPE> must be the prefix of commit message and must be one of the following: feat, fix, docs, style, refactor, test, chore\n - <DESCRIPTION> must be the description of the commit in lowercase and without any special characters\n\nEXAMPLES COMMIT MESSAGE:\n - fix: add password regex pattern\n - feat: add new test cases\n\nNOTE: Response only commit message, no explanation anymore\n\nACTUAL COMMIT MESSAGE: \n"
DEFAULT_MODEL="gpt-4o-mini"
DEFAULT_MAX_TOKENS=128000
DEFAULT_API_ENDPOINT="https://api.openai.com/v1/chat/completions"

print_step "Checking dependencies..."

# Check if jq is installed
if ! command -v jq &> /dev/null; then
    print_warning "jq is not installed. Attempting to install jq..."
    print_step "Installing jq dependency..."

    # Use curl to download and run the webinstall.dev script for jq
    if curl -s https://webinstall.dev/jq | bash; then
        print_success "jq has been installed successfully."

        # Add the installed jq to the current PATH, if it's not already there
        if [ -d "$HOME/.local/bin" ] && [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
            export PATH="$HOME/.local/bin:$PATH"
            print_info "Added jq to PATH for this session."
        fi

        # Reload the shell's environment if possible to recognize jq immediately
        if [ -f "$HOME/.profile" ]; then
            source "$HOME/.profile"
        elif [ -f "$HOME/.bashrc" ]; then
            source "$HOME/.bashrc"
        elif [ -f "$HOME/.bash_profile" ]; then
            source "$HOME/.bash_profile"
        elif [ -f "$HOME/.zshrc" ]; then
            source "$HOME/.zshrc"
        elif [ -f "$HOME/.zprofile" ]; then
            source "$HOME/.zprofile"
        fi
    # Attempt to detect the platform (only works for some common distributions)
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        # Attempt to install for Debian-based or Red Hat-based systems
        if command -v apt-get &> /dev/null; then
            sudo apt-get update && sudo apt-get install -y jq
        elif command -v dnf &> /dev/null; then
            sudo dnf install -y jq
        elif command -v yum &> /dev/null; then
            sudo yum install -y jq
        else
            print_error "Package manager not recognized. Please install jq manually."
            exit 1
        fi
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        # Attempt to install for macOS
        if command -v brew &> /dev/null; then
            brew install jq
        else
            print_error "Homebrew not found. Please install jq manually or install Homebrew."
            exit 1
        fi
    else
        print_error "Operating system not recognized. Please install jq manually."
        exit 1
    fi
fi

# Check if jq was successfully installed
if ! command -v jq &> /dev/null; then
    print_error "Failed to install jq. Please install it manually."
    exit 1
else
    print_success "jq dependency is available."
fi

print_header "Configuration Setup"

# Step 1: API Key Configuration
print_step "Step 1/4: API Key Configuration"
existing_key=$(git config --global --get openai.apikey)

if [ -n "$existing_key" ]; then
    # Mask the key for display (show first 8 and last 4 characters)
    masked_key="${existing_key:0:8}...${existing_key: -4}"
    print_info "You have already set the OpenAI API key: $masked_key"
    echo -e "${YELLOW}Do you want to use the existing key? [Y/n] (press Enter for default: Y):${NC} "
    read -r use_existing_key < /dev/tty

    if [[ $use_existing_key =~ ^([nN][oO]|[nN])$ ]]; then
        echo -e "${YELLOW}Please enter your new OpenAI API key:${NC} "
        read -r openai_api_key < /dev/tty
        git config --global openai.apikey "$openai_api_key"
        print_success "OpenAI API key updated successfully."
    else
        print_success "Using the existing OpenAI API key."
    fi
else
    echo -e "${YELLOW}Please enter your OpenAI API key:${NC} "
    read -r openai_api_key < /dev/tty
    git config --global openai.apikey "$openai_api_key"
    print_success "OpenAI API key saved successfully."
fi

# Step 2: Model Configuration
print_step "Step 2/4: Model Configuration"
existing_model=$(git config --global --get ai.model)
current_model="${existing_model:-$DEFAULT_MODEL}"

echo -e "${CYAN}Available models:${NC}"
echo -e "  ${YELLOW}1.${NC} gpt-4o-mini (fast, cost-effective)"
echo -e "  ${YELLOW}2.${NC} gpt-4o (more capable, higher cost)"
echo -e "  ${YELLOW}3.${NC} gpt-3.5-turbo (legacy, cheaper)"
echo -e "  ${YELLOW}4.${NC} Custom model"
echo -e "${YELLOW}Select model [1-4] (press Enter for default: $current_model):${NC} "
read -r model_choice < /dev/tty

case $model_choice in
    1)
        selected_model="gpt-4o-mini"
        ;;
    2)
        selected_model="gpt-4o"
        ;;
    3)
        selected_model="gpt-3.5-turbo"
        ;;
    4)
        echo -e "${YELLOW}Enter custom model name:${NC} "
        read -r selected_model < /dev/tty
        ;;
    "")
        selected_model="$current_model"
        ;;
    *)
        print_warning "Invalid selection. Using default: $current_model"
        selected_model="$current_model"
        ;;
esac

git config --global ai.model "$selected_model"
print_success "Model set to: $selected_model"

# Step 3: Max Tokens Configuration
print_step "Step 3/4: Max Tokens Configuration"
existing_tokens=$(git config --global --get ai.maxtokens)
current_tokens="${existing_tokens:-$DEFAULT_MAX_TOKENS}"

echo -e "${CYAN}Max tokens determines the maximum length of the AI response.${NC}"
echo -e "${CYAN}Recommended values:${NC}"
echo -e "  ${YELLOW}•${NC} 100-500 for short commit messages"
echo -e "  ${YELLOW}•${NC} 1000-2000 for detailed messages"
echo -e "  ${YELLOW}•${NC} 128000 for maximum flexibility"
echo -e "${YELLOW}Enter max tokens (press Enter for default: $current_tokens):${NC} "
read -r max_tokens_input < /dev/tty

if [ -z "$max_tokens_input" ]; then
    selected_tokens="$current_tokens"
else
    # Validate input is a number
    if [[ "$max_tokens_input" =~ ^[0-9]+$ ]]; then
        selected_tokens="$max_tokens_input"
    else
        print_warning "Invalid input. Using default: $current_tokens"
        selected_tokens="$current_tokens"
    fi
fi

git config --global ai.maxtokens "$selected_tokens"
print_success "Max tokens set to: $selected_tokens"

# Step 4: API Endpoint Configuration
print_step "Step 4/4: API Endpoint Configuration"
existing_endpoint=$(git config --global --get ai.endpoint)
current_endpoint="${existing_endpoint:-$DEFAULT_API_ENDPOINT}"

echo -e "${CYAN}Available API endpoints:${NC}"
echo -e "  ${YELLOW}1.${NC} OpenAI (https://api.openai.com/v1/chat/completions)"
echo -e "  ${YELLOW}2.${NC} Together AI (https://api.together.xyz/v1/chat/completions)"
echo -e "  ${YELLOW}3.${NC} OpenRouter (https://openrouter.ai/api/v1/chat/completions)"
echo -e "  ${YELLOW}4.${NC} Azure OpenAI (requires custom endpoint)"
echo -e "  ${YELLOW}5.${NC} Custom endpoint"
echo -e "  ${YELLOW}6.${NC} Keep current ($current_endpoint)"
echo -e "${YELLOW}Select endpoint [1-6] (press Enter for default: OpenAI):${NC} "
read -r endpoint_choice < /dev/tty

case $endpoint_choice in
    1|"")
        selected_endpoint="https://api.openai.com/v1/chat/completions"
        ;;
    2)
        selected_endpoint="https://api.together.xyz/v1/chat/completions"
        ;;
    3)
        selected_endpoint="https://openrouter.ai/api/v1/chat/completions"
        ;;
    4)
        echo -e "${YELLOW}Enter your Azure OpenAI endpoint:${NC} "
        echo -e "${CYAN}Format: https://your-resource.openai.azure.com/openai/deployments/your-model/chat/completions?api-version=2023-05-15${NC}"
        read -r selected_endpoint < /dev/tty
        ;;
    5)
        echo -e "${YELLOW}Enter custom API endpoint:${NC} "
        read -r selected_endpoint < /dev/tty
        ;;
    6)
        selected_endpoint="$current_endpoint"
        ;;
    *)
        print_warning "Invalid selection. Using default: OpenAI"
        selected_endpoint="https://api.openai.com/v1/chat/completions"
        ;;
esac

git config --global ai.endpoint "$selected_endpoint"
print_success "API endpoint set to: $selected_endpoint"

# Set the default prompt (not interactive as it's complex)
git config --global ai.prompt "$DEFAULT_CHATGPT_PROMPT"

print_success "Configuration completed successfully!"
print_header "Git Hook Installation"

print_step "Verifying git repository..."

# Check if we're inside a git repository
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    print_error "Error: this script must be run from within a git repository."
    exit 1
fi

print_success "Git repository verified."

# Define the path to the git hooks folder
HOOKS_DIR="$(git rev-parse --git-dir)/hooks"

# Check if the hooks directory exists, create if not
if [ ! -d "$HOOKS_DIR" ]; then
    print_step "Creating hooks directory..."
    mkdir -p "$HOOKS_DIR"
    print_success "Hooks directory created."
fi

# Define the URL of the raw gist containing the prepare-commit-msg hook
GIST_URL="https://raw.githubusercontent.com/peerasak-u/fork-ai-commit-msg/main/prepare-commit-msg"

# Define the path to the git hooks folder
HOOKS_DIR="$(git rev-parse --git-dir)/hooks"

# Define the path to the prepare-commit-msg hook within the hooks directory
HOOK_FILE="$HOOKS_DIR/prepare-commit-msg"

# Download the prepare-commit-msg hook from the Gist
print_step "Downloading prepare-commit-msg hook..."
curl -L -o "$HOOK_FILE" "$GIST_URL"

# Check if the download was successful
if [ ! -f "$HOOK_FILE" ]; then
    print_error "Failed to download the prepare-commit-msg hook."
    exit 1
fi

# Make the prepare-commit-msg hook executable
chmod +x "$HOOK_FILE"

print_success "The prepare-commit-msg hook has been installed successfully."

print_header "Installation Complete!"

print_success "Fork AI Commit Message has been installed successfully!"

echo -e "${BOLD}${GREEN}Configuration Summary:${NC}"
echo -e "${CYAN}Git Config Location:${NC} ~/.gitconfig"
echo -e "${CYAN}Hook Location:${NC} $HOOK_FILE"
echo ""

echo -e "${BOLD}${YELLOW}Current Configuration:${NC}"
echo -e "${CYAN}• API Key:${NC} $(git config --global --get openai.apikey | sed 's/.*\(....\)/***...\1/')"
echo -e "${CYAN}• Model:${NC} $(git config --global --get ai.model)"
echo -e "${CYAN}• Max Tokens:${NC} $(git config --global --get ai.maxtokens)"
echo -e "${CYAN}• API Endpoint:${NC} $(git config --global --get ai.endpoint)"
echo ""

echo -e "${BOLD}${MAGENTA}How to Use:${NC}"
echo -e "${CYAN}1.${NC} Go to 'Local Changes' menu in Fork"
echo -e "${CYAN}2.${NC} Click on 'Run prepare-commit-msg hook'"
echo -e "${CYAN}3.${NC} The AI will generate a commit message for you!"
echo ""

echo -e "${BOLD}${MAGENTA}Manual Configuration (if needed):${NC}"
echo -e "You can modify these settings anytime using git config:"
echo -e "${YELLOW}git config --global openai.apikey 'your-api-key'${NC}"
echo -e "${YELLOW}git config --global ai.model 'gpt-4o-mini'${NC}"
echo -e "${YELLOW}git config --global ai.maxtokens 128000${NC}"
echo -e "${YELLOW}git config --global ai.endpoint 'https://api.openai.com/v1/chat/completions'${NC}"
echo -e "${YELLOW}git config --global ai.prompt 'your-custom-prompt'${NC}"
echo ""

print_info "For more information, visit: https://github.com/peerasak-u/fork-ai-commit-msg"
echo -e "${BOLD}${GREEN}Happy committing! 🚀${NC}"
