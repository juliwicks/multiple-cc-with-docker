#!/bin/bash
set -e

# Define color codes
INFO='\033[0;36m'  # Cyan
BANNER='\033[0;35m' # Magenta
WARNING='\033[0;33m'
ERROR='\033[0;31m'
SUCCESS='\033[0;32m'
NC='\033[0m' # No Color

echo -e "${BANNER}=============================${NC}"
echo -e "${BANNER}Script by Nodebot (Juliwicks)${NC}"
echo -e "${BANNER}=============================${NC}"

# Define the base Docker image name
DOCKER_IMAGE="multiple-node-image"

# Define the architecture and URLs
ARCH=$(uname -m)
if [[ "$ARCH" == "x86_64" ]]; then
    CLIENT_URL="https://cdn.app.multiple.cc/client/linux/x64/multipleforlinux.tar"
elif [[ "$ARCH" == "aarch64" ]]; then
    CLIENT_URL="https://cdn.app.multiple.cc/client/linux/arm64/multipleforlinux.tar"
else
    echo -e "Unsupported architecture: $ARCH"
    exit 1
fi

# Function to check if a value is a number
is_number() {
    [[ "$1" =~ ^[0-9]+$ ]]
}

# Prompt and validate IDENTIFIER
while true; do
    read -p "Enter your IDENTIFIER: " IDENTIFIER
    if [[ -n "$IDENTIFIER" ]]; then
        break
    else
        echo "IDENTIFIER cannot be empty. Please try again."
    fi
done

# Prompt and validate PIN
while true; do
    read -p "Enter your PIN (eg. 888888): " PIN
    if [[ "$PIN" =~ ^[0-9]{6}$ ]]; then
        break
    else
        echo "PIN must be exactly 6 digits. Please try again."
    fi
done

# Prompt and validate BANDWIDTH_DOWNLOAD
while true; do
    read -p "Enter BANDWIDTH_DOWNLOAD with KB format (eg. 1000 for 1MB): " BANDWIDTH_DOWNLOAD
    if is_number "$BANDWIDTH_DOWNLOAD"; then
        break
    else
        echo "BANDWIDTH_DOWNLOAD must be a valid number. Please try again."
    fi
done

# Prompt and validate BANDWIDTH_UPLOAD
while true; do
    read -p "Enter BANDWIDTH_UPLOAD with KB format (eg. 1000 for 1MB): " BANDWIDTH_UPLOAD
    if is_number "$BANDWIDTH_UPLOAD"; then
        break
    else
        echo "BANDWIDTH_UPLOAD must be a valid number. Please try again."
    fi
done

# Prompt and validate STORAGE
while true; do
    read -p "Enter STORAGE with KB format (eg. 1000000 for 1GB): " STORAGE
    if is_number "$STORAGE"; then
        break
    else
        echo "STORAGE must be a valid number. Please try again."
    fi
done

# Ask for proxy type
echo "Select the proxy type for all proxies:"
echo "1: HTTP"
echo "2: SOCKS5"
read -p "Enter your choice (1 or 2): " proxy_type_choice

if [[ "$proxy_type_choice" == "1" ]]; then
    proxy_type="http-connect"
elif [[ "$proxy_type_choice" == "2" ]]; then
    proxy_type="socks5"
else
    echo "Invalid choice. Exiting."
    exit 1
fi

# Prompt for proxy list
echo "Enter your proxies (one per line) in the format 'username:password@ip:port' or 'ip:port', followed by an empty line to finish:"
proxies=()
while IFS= read -r proxy; do
    [[ -z "$proxy" ]] && break
    proxies+=("$proxy")
done

if [[ ${#proxies[@]} -eq 0 ]]; then
    echo "No proxies provided. Exiting."
    exit 1
fi

# Create the Dockerfile dynamically
cat > Dockerfile <<EOF
FROM ubuntu:latest

# Disable interactive configuration
ENV DEBIAN_FRONTEND=noninteractive

# Install required packages, including libicu
RUN apt-get update && apt-get install -y \
    curl \\
    wget \\
    tar \\
    redsocks \\
    iptables \\
    jq \\
    screen \\
    libicu-dev

# Add client download and configuration
WORKDIR /app
RUN wget ${CLIENT_URL} -O multipleforlinux.tar
RUN tar -xvf multipleforlinux.tar && chmod +x multipleforlinux/multiple-cli && chmod +x multipleforlinux/multiple-node && chmod -R 777 multipleforlinux

# Copy entrypoint script
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]

CMD ["sh", "-c", "cd /app/multipleforlinux && attempts=0 && while [ \$attempts -lt 3 ]; do   nohup ./multiple-node > output.log 2>&1 &   echo \"Monitor the log file for Node data read exception...\"; timeout 5 tail -f output.log | while read line; do     if echo \"\$line\" | grep -q 'Node data read exception'; then       echo 'Error detected: Node data read exception. Exiting...' &&       exit 1;     fi;   done;   ./multiple-cli bind --bandwidth-download \$BANDWIDTH_DOWNLOAD --storage \$STORAGE --bandwidth-upload \$BANDWIDTH_UPLOAD --identifier \$IDENTIFIER --pin \$PIN && break;   attempts=$((attempts + 1));   echo \"Retrying... attempt \$attempts\";   sleep 5; done; if [ \$attempts -eq 3 ]; then   echo \"multiple-cli failed after 3 attempts.\";   exit 1; fi; ./multiple-cli start; while ps aux | grep -q '[m]ultiple-node'; do echo \"multiple-node is alive...\"; ./multiple-cli status | grep \"NodeRun\"; sleep 10; done; echo \"Process multiple-node not found. Exiting.\""]



EOF

# Create the entrypoint script
cat > entrypoint.sh <<'EOF'
#!/bin/bash

# Generate redsocks.conf dynamically
cat > /etc/redsocks.conf <<EOF2
base {
    log_debug = off;
    log_info = on;
    daemon = on;
    redirector = iptables;
}

redsocks {
    local_ip = 127.0.0.1;
    local_port = 12345;
    ip = $proxy_ip;
    port = $proxy_port;
    type = $proxy_type;
EOF2

if [[ -n "$proxy_username" ]]; then
    echo "    login = \"$proxy_username\";" >> /etc/redsocks.conf
fi

if [[ -n "$proxy_password" ]]; then
    echo "    password = \"$proxy_password\";" >> /etc/redsocks.conf
fi

echo "}" >> /etc/redsocks.conf

echo "Starting redsocks..."
redsocks -c /etc/redsocks.conf &
echo "Redsocks started."

# Give redsocks some time to start
sleep 10
echo "Configuring iptables..."

# Configure iptables to redirect HTTP and HTTPS traffic through redsocks
iptables -t nat -A OUTPUT -p tcp --dport 80 -j REDIRECT --to-ports 12345
iptables -t nat -A OUTPUT -p tcp --dport 443 -j REDIRECT --to-ports 12345
echo "Iptables configured."

exec "$@"
EOF

# Build the Docker image
docker build --no-cache -t $DOCKER_IMAGE .

# Function to get the next available container name
get_next_container_name() {
    local base_name=$1
    local i=1
    while docker ps -a --format '{{.Names}}' | grep -q "^${base_name}-${i}\$"; do
        ((i++))
    done
    echo "${base_name}-${i}"
}

# Run a Docker container for each proxy
for proxy in "${proxies[@]}"; do
    if [[ "$proxy" == *"@"* ]]; then
        # Proxy with authentication
        auth=$(echo "$proxy" | cut -d@ -f1)
        proxy_ip=$(echo "$proxy" | cut -d@ -f2 | cut -d: -f1)
        proxy_port=$(echo "$proxy" | cut -d: -f3)
        proxy_username=$(echo "$auth" | cut -d: -f1)
        proxy_password=$(echo "$auth" | cut -d: -f2)
    else
        # Proxy without authentication
        proxy_ip=$(echo "$proxy" | cut -d: -f1)
        proxy_port=$(echo "$proxy" | cut -d: -f2)
        proxy_username=""
        proxy_password=""
    fi

    # Get the next available container name
    container_name=$(get_next_container_name "multiple-node")

    # Run the Docker container
    docker run -d --name $container_name \
        --cap-add=NET_ADMIN \
        -e proxy_ip="$proxy_ip" \
        -e proxy_port="$proxy_port" \
        -e proxy_username="$proxy_username" \
        -e proxy_password="$proxy_password" \
        -e proxy_type="$proxy_type" \
        -e IDENTIFIER="$IDENTIFIER" \
        -e PIN="$PIN" \
        -e BANDWIDTH_DOWNLOAD="$BANDWIDTH_DOWNLOAD" \
        -e STORAGE="$STORAGE" \
        -e BANDWIDTH_UPLOAD="$BANDWIDTH_UPLOAD" \
        $DOCKER_IMAGE

    echo "Container $container_name is running with proxy $proxy_type at $proxy_ip:$proxy_port."
done

echo "All containers are running."
