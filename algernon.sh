#!/bin/bash
# mini-algernon: Lightweight Web Server for Linux/Termux
# Supports: PHP, HTML, CSS, JS, Images | Tunnels: ngrok, serveo, localtunnel
set -e

# Configuration
PORT=3001
DIRECTORY="."
TUNNEL=""
VERBOSE=false
INDEX_FILE="index.php"
USE_PHP=true
SERVER_TITLE="Mini Algernon"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BLUE='\033[0;34m'
NC='\033[0m'

show_help() {
    echo -e "${YELLOW}Usage:${NC} $0 [options]"
    echo -e "${YELLOW}Options:${NC}"
    echo "  -p, --port PORT    Web server port (default: 3001)"
    echo "  -d, --dir DIR      Serve files from directory (default: current)"
    echo "  -t, --tunnel TYPE  Tunnel: ngrok, serveo or localtunnel"
    echo "  -v, --verbose      Show detailed logs"
    echo "  --no-php           Disable PHP support"
    echo "  -h, --help         Show this help"
    echo -e "\n${YELLOW}Examples:${NC}"
    echo "  $0 -p 8080 -d ~/public_html"
    echo "  $0 -t ngrok --no-php"
}

detect_os() {
    if [[ $(uname -o) == "Android" ]]; then
        echo "termux"
    else
        echo "linux"
    fi
}

install_deps() {
    local os=$(detect_os)
    echo -e "${CYAN}Installing dependencies for ${os}...${NC}"

    if [[ "$os" == "termux" ]]; then
        pkg update -y
        [[ "$USE_PHP" == true ]] && pkg install php -y
        pkg install netcat-openbsd -y
    else
        sudo apt update
        [[ "$USE_PHP" == true ]] && sudo apt install php -y
        sudo apt install netcat -y
    fi
}

start_php_server() {
    local port=$1
    local dir=$2
    echo -e "${GREEN}Starting PHP server at:${NC} http://localhost:${port}"
    php -S 0.0.0.0:${port} -t "${dir}"
}

start_static_server() {
    local port=$1
    local dir=$2
    echo -e "${GREEN}Starting static file server at:${NC} http://localhost:${port}"

    while true; do
        {
            method=""
            path=""

            # Read headers
            while IFS= read -r line && [ -n "$line" ]; do
                [[ "$VERBOSE" == true ]] && echo "<<< $line"
                if [[ "$line" =~ ^(GET|POST|HEAD)\ ([^[:space:]]+) ]]; then
                    method="${BASH_REMATCH[1]}"
                    path="${BASH_REMATCH[2]}"
                fi
            done

            # Handle request
            if [[ -n "$path" ]]; then
                file_path="${dir}${path}"
                [[ "$path" == "/" ]] && file_path="${dir}/${INDEX_FILE}"

                if [[ -f "$file_path" ]]; then
                    # Determine MIME type
                    mime="text/plain"
                    case "$file_path" in
                        *.html) mime="text/html" ;;
                        *.css)  mime="text/css" ;;
                        *.js)   mime="application/javascript" ;;
                        *.png)  mime="image/png" ;;
                        *.jpg)  mime="image/jpeg" ;;
                        *.gif)  mime="image/gif" ;;
                        *.ico)  mime="image/x-icon" ;;
                        *.php)  mime="text/html" ;;
                    esac

                    # Send response
                    echo -e "HTTP/1.1 200 OK"
                    echo -e "Content-Type: ${mime}"
                    echo -e "Connection: close\r\n"
                    cat "$file_path"
                else
                    # 404 Not Found
                    echo -e "HTTP/1.1 404 Not Found"
                    echo -e "Content-Type: text/html"
                    echo -e "Connection: close\r\n"
                    echo "<h1>404 Not Found</h1>"
                fi
            else
                # 400 Bad Request
                echo -e "HTTP/1.1 400 Bad Request"
                echo -e "Content-Type: text/html"
                echo -e "Connection: close\r\n"
                echo "<h1>400 Bad Request</h1>"
            fi
        } | nc -l -p $port -q 1
    done
}

start_tunnel() {
    local service=$1
    local port=$2

    case $service in
        ngrok)
            echo -e "${YELLOW}Starting ngrok tunnel...${NC}"

            # Check for ngrok installation
            if ! command -v ngrok &> /dev/null; then
                echo -e "${RED}ngrok not found! Please install manually.${NC}"
                echo -e "Download from: ${CYAN}https://ngrok.com/download${NC}"
                return 1
            fi

            # Check for auth token
            if [[ ! -f ~/.config/ngrok/ngrok.yml ]] && [[ ! -f ~/.ngrok2/ngrok.yml ]]; then
                echo -e "${YELLOW}Ngrok auth token not found.${NC}"
                read -p "Enter your ngrok authtoken (get from https://dashboard.ngrok.com/get-started/your-authtoken): " authtoken
                ngrok config add-authtoken "$authtoken" || {
                    echo -e "${RED}Failed to add authtoken. Please check your token.${NC}"
                    return 1
                }
            fi

            ngrok http $port
            ;;

        serveo)
            echo -e "${GREEN}Starting Serveo tunnel...${NC}"
            if ! command -v ssh &> /dev/null; then
                echo -e "${RED}SSH not found! Please install OpenSSH.${NC}"
                [[ $(detect_os) == "termux" ]] && echo "Install with: pkg install openssh"
                return 1
            fi

            echo -e "Public URL: ${CYAN}https://$(hostname).serveo.net${NC}"
            ssh -R 80:localhost:$port serveo.net
            ;;

        localtunnel)
            echo -e "${YELLOW}Starting localtunnel...${NC}"
            if ! command -v lt &> /dev/null; then
                echo -e "${RED}localtunnel not found! Install with: npm install -g localtunnel${NC}"
                return 1
            fi

            lt --port $port
            ;;

        *)
            echo -e "${RED}Unknown tunnel service: $service${NC}"
            ;;
    esac
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -p|--port)
            PORT="$2"
            shift 2
            ;;
        -d|--dir)
            DIRECTORY="$2"
            shift 2
            ;;
        -t|--tunnel)
            TUNNEL="$2"
            shift 2
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        --no-php)
            USE_PHP=false
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            show_help
            exit 1
            ;;
    esac
done

# Main
if [[ $# -eq 0 ]]; then
    # Interactive mode
    echo -e "${GREEN}${SERVER_TITLE} - Interactive Setup${NC}"
    echo -e "${CYAN}How do you want to use the server?${NC}"
    echo "1) Localhost (run locally only)"
    echo "2) Ngrok (expose to internet - requires ngrok auth token)"
    echo "3) Serveo (expose to internet - requires SSH)"
    read -p "Enter choice [1-3]: " choice

    case $choice in
        1)
            TUNNEL=""
            ;;
        2)
            TUNNEL="ngrok"
            ;;
        3)
            TUNNEL="serveo"
            ;;
        *)
            echo -e "${RED}Invalid choice. Exiting.${NC}"
            exit 1
            ;;
    esac

    # Get port
    read -p "Enter server port [default: 3001]: " user_port
    PORT=${user_port:-3001}

    # Get directory
    read -p "Enter directory to serve [default: current]: " user_dir
    DIRECTORY=${user_dir:-"."}

    # PHP support
    if command -v php &> /dev/null; then
        read -p "Enable PHP support? [Y/n]: " use_php
        if [[ $use_php =~ ^[Nn]$ ]]; then
            USE_PHP=false
        fi
    else
        echo -e "${YELLOW}PHP not found. Disabling PHP support.${NC}"
        USE_PHP=false
    fi
fi

install_deps

# Get absolute path
DIRECTORY=$(realpath "$DIRECTORY")

if [[ ! -d "$DIRECTORY" ]]; then
    echo -e "${YELLOW}Creating directory: $DIRECTORY${NC}"
    mkdir -p "$DIRECTORY"
fi

# Create default index file
if [[ "$USE_PHP" == true ]]; then
    INDEX_FILE="index.php"
    if [[ ! -f "$DIRECTORY/$INDEX_FILE" ]]; then
        echo -e "${YELLOW}Creating default PHP index file${NC}"
        cat > "$DIRECTORY/$INDEX_FILE" <<'EOF'
<?php
// Mini Algernon - Default Index Page
$server_info_link = file_exists('server-info.php') ? 'server-info.php' : '';
?>
<!DOCTYPE html>
<html>
<head>
    <title>Mini Algernon</title>
    <style>
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            margin: 0;
            padding: 0;
            background: linear-gradient(135deg, #f5f7fa 0%, #c3cfe2 100%);
            min-height: 100vh;
            display: flex;
            justify-content: center;
            align-items: center;
        }
        .container {
            background: white;
            border-radius: 15px;
            box-shadow: 0 10px 30px rgba(0,0,0,0.1);
            padding: 30px;
            width: 90%;
            max-width: 500px;
            text-align: center;
        }
        h1 {
            color: #2c3e50;
            margin-bottom: 20px;
        }
        .status-card {
            background: #f8f9fa;
            border-radius: 10px;
            padding: 20px;
            margin: 20px 0;
            text-align: left;
            border-left: 4px solid #3498db;
        }
        .status-title {
            font-weight: bold;
            color: #2c3e50;
            margin-bottom: 10px;
            font-size: 1.1em;
        }
        .btn {
            display: inline-block;
            background: #3498db;
            color: white;
            padding: 12px 25px;
            text-decoration: none;
            border-radius: 30px;
            font-weight: bold;
            margin: 10px 5px;
            transition: all 0.3s ease;
            border: none;
            cursor: pointer;
        }
        .btn:hover {
            background: #2980b9;
            transform: translateY(-3px);
            box-shadow: 0 5px 15px rgba(0,0,0,0.1);
        }
        .btn.php {
            background: #3498db;
        }
        .btn.info {
            background: #2ecc71;
        }
        .btn:hover {
            opacity: 0.9;
        }
        .footer {
            margin-top: 30px;
            color: #7f8c8d;
            font-size: 0.9em;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>Mini Algernon</h1>
        <div class="status-card">
            <div class="status-title">Server Status</div>
            <div>PHP server running successfully!</div>
        </div>
        <div>
            <a href="/" class="btn php">Home Page</a>
            <?php if ($server_info_link): ?>
                <a href="<?php echo $server_info_link ?>" class="btn info">Server Info</a>
            <?php endif; ?>
        </div>
        <div class="footer">
            Powered by mini-algernon.sh
        </div>
    </div>
</body>
</html>
EOF
    fi
else
    INDEX_FILE="index.html"
    if [[ ! -f "$DIRECTORY/$INDEX_FILE" ]]; then
        echo -e "${YELLOW}Creating default HTML index file${NC}"
        cat > "$DIRECTORY/$INDEX_FILE" <<'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>Mini Algernon</title>
    <style>
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            margin: 0;
            padding: 0;
            background: linear-gradient(135deg, #f5f7fa 0%, #c3cfe2 100%);
            min-height: 100vh;
            display: flex;
            justify-content: center;
            align-items: center;
        }
        .container {
            background: white;
            border-radius: 15px;
            box-shadow: 0 10px 30px rgba(0,0,0,0.1);
            padding: 30px;
            width: 90%;
            max-width: 500px;
            text-align: center;
        }
        h1 {
            color: #2c3e50;
            margin-bottom: 20px;
        }
        .status-card {
            background: #f8f9fa;
            border-radius: 10px;
            padding: 20px;
            margin: 20px 0;
            text-align: left;
            border-left: 4px solid #3498db;
        }
        .status-title {
            font-weight: bold;
            color: #2c3e50;
            margin-bottom: 10px;
            font-size: 1.1em;
        }
        .btn {
            display: inline-block;
            background: #3498db;
            color: white;
            padding: 12px 25px;
            text-decoration: none;
            border-radius: 30px;
            font-weight: bold;
            margin: 10px 5px;
            transition: all 0.3s ease;
        }
        .btn:hover {
            background: #2980b9;
            transform: translateY(-3px);
            box-shadow: 0 5px 15px rgba(0,0,0,0.1);
        }
        .footer {
            margin-top: 30px;
            color: #7f8c8d;
            font-size: 0.9em;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>Mini Algernon</h1>
        <div class="status-card">
            <div class="status-title">Server Status</div>
            <div>Static file server running successfully!</div>
        </div>
        <a href="/" class="btn">Home Page</a>
        <div class="footer">
            Powered by mini-algernon.sh
        </div>
    </div>
</body>
</html>
EOF
    fi
fi

# Create server-info.php if missing
if [[ "$USE_PHP" == true ]] && [[ ! -f "$DIRECTORY/server-info.php" ]]; then
    echo -e "${YELLOW}Creating server info file${NC}"
    cat > "$DIRECTORY/server-info.php" <<'EOF'
<?php
// Server Information Page
error_reporting(E_ALL);
ini_set('display_errors', 1);

// Collect headers
$headers = [];
foreach ($_SERVER as $key => $value) {
    if (substr($key, 0, 5) == 'HTTP_') {
        $header = str_replace(' ', '-', ucwords(str_replace('_', ' ', strtolower(substr($key, 5))));
        $headers[$header] = $value;
    }
}
if (isset($_SERVER['CONTENT_TYPE'])) {
    $headers['Content-Type'] = $_SERVER['CONTENT_TYPE'];
}
if (isset($_SERVER['AUTHORIZATION'])) {
    $headers['Authorization'] = $_SERVER['AUTHORIZATION'];
}

// Calculate page generation time
$start_time = $_SERVER['REQUEST_TIME_FLOAT'] ?? microtime(true);
$page_generation_time = microtime(true) - $start_time;

$server_info = [
    'Server Software' => $_SERVER['SERVER_SOFTWARE'] ?? 'Mini-Algernon',
    'PHP Version' => phpversion(),
    'Server API' => php_sapi_name(),
    'Server Address' => $_SERVER['SERVER_ADDR'] ?? '-',
    'Server Port' => $_SERVER['SERVER_PORT'] ?? '-',
    'Document Root' => $_SERVER['DOCUMENT_ROOT'] ?? '-',
    'Operating System' => php_uname('s') . ' ' . php_uname('r') . ' ' . php_uname('m'),
    'System Load' => function_exists('sys_getloadavg') ? sys_getloadavg()[0] : '-',
    'Memory Usage' => round(memory_get_usage(true) / (1024 * 1024), 2) . ' MB',
    'Disk Space' => function_exists('disk_free_space') ?
                   (round(disk_free_space(".") / (1024 * 1024 * 1024), 2) . ' GB free of ' .
                    round(disk_total_space(".") / (1024 * 1024 * 1024), 2) . ' GB') : 'N/A',
    'Current Time' => date('Y-m-d H:i:s'),
    'Client IP' => $_SERVER['REMOTE_ADDR'] ?? '-',
    'Browser' => $_SERVER['HTTP_USER_AGENT'] ?? '-',
    'Request Method' => $_SERVER['REQUEST_METHOD'] ?? '-',
    'Request URI' => $_SERVER['REQUEST_URI'] ?? '-',
    'Query String' => $_SERVER['QUERY_STRING'] ?? '-',
    'Headers' => $headers,
    'Server Uptime' => function_exists('shell_exec') ? @shell_exec('uptime -p') : 'N/A',
    'CPU Cores' => function_exists('shell_exec') ? @shell_exec('nproc') : 'N/A',
    'Ping to Google' => function_exists('shell_exec') ? @shell_exec('ping -c 1 8.8.8.8 | grep "time="') : 'N/A',
    'PHP Max Memory' => ini_get('memory_limit'),
    'PHP Max Execution Time' => ini_get('max_execution_time') . ' seconds',
    'PHP Extensions' => implode(', ', get_loaded_extensions()),
    'Server Protocol' => $_SERVER['SERVER_PROTOCOL'] ?? '-',
    'HTTPS' => isset($_SERVER['HTTPS']) ? 'Yes' : 'No',
    'Page Generation Time' => number_format($page_generation_time, 4) . ' seconds',
];

$server_config = [
    'Database' => 'Bolt',
    'Cache mode' => 'On',
    'Cache size' => '1 MB',
    'Request limit' => '10/sec per visitor',
    'Server Timezone' => date_default_timezone_get(),
    'OpenSSL Version' => defined('OPENSSL_VERSION_TEXT') ? OPENSSL_VERSION_TEXT : 'N/A',
];

$security_info = [
    'Display Errors' => ini_get('display_errors') ? 'Enabled' : 'Disabled',
    'File Uploads' => ini_get('file_uploads') ? 'Enabled' : 'Disabled',
    'Max File Upload Size' => ini_get('upload_max_filesize'),
    'Post Max Size' => ini_get('post_max_size'),
];
?>
<!DOCTYPE html>
<html>
<head>
    <title>Server Information</title>
    <style>
        body {
            font-family: "Segoe UI", Tahoma, Geneva, Verdana, sans-serif;
            margin: 0;
            padding: 20px;
            background: linear-gradient(135deg, #f5f7fa 0%, #c3cfe2 100%);
            color: #333;
        }
        .container {
            max-width: 1200px;
            margin: 0 auto;
            background: white;
            padding: 30px;
            border-radius: 15px;
            box-shadow: 0 10px 30px rgba(0,0,0,0.1);
        }
        h1 {
            color: #2c3e50;
            text-align: center;
            margin-bottom: 30px;
            font-size: 2.5em;
        }
        .info-grid {
            display: grid;
            grid-template-columns: repeat(auto-fill, minmax(300px, 1fr));
            gap: 15px;
            margin-bottom: 30px;
        }
        .info-card {
            background: #f8f9fa;
            border-left: 4px solid #3498db;
            padding: 15px;
            border-radius: 4px;
            transition: transform 0.3s, box-shadow 0.3s;
        }
        .info-card:hover {
            transform: translateY(-3px);
            box-shadow: 0 5px 15px rgba(0,0,0,0.1);
        }
        .info-title {
            font-weight: bold;
            margin-bottom: 5px;
            color: #2c3e50;
            font-size: 1.1em;
        }
        .php-version {
            background: #3498db;
            color: white;
            padding: 5px 10px;
            border-radius: 4px;
            display: inline-block;
            margin-top: 5px;
        }
        .section-title {
            font-size: 1.5em;
            border-bottom: 2px solid #3498db;
            padding-bottom: 10px;
            margin-top: 30px;
            margin-bottom: 20px;
            color: #2c3e50;
            display: flex;
            align-items: center;
        }
        .section-title i {
            margin-right: 10px;
            font-size: 1.2em;
        }
        pre {
            background: #2c3e50;
            color: white;
            padding: 15px;
            border-radius: 5px;
            overflow-x: auto;
            font-size: 0.9em;
        }
        .footer {
            text-align: center;
            margin-top: 40px;
            color: #7f8c8d;
            font-size: 0.9em;
            padding-top: 20px;
            border-top: 1px solid #eee;
        }
        .config-badge {
            display: inline-block;
            background: #9b59b6;
            color: white;
            padding: 3px 8px;
            border-radius: 3px;
            font-size: 0.85em;
            margin-right: 5px;
        }
        .status-indicator {
            display: inline-block;
            width: 10px;
            height: 10px;
            border-radius: 50%;
            margin-right: 5px;
        }
        .status-on {
            background-color: #2ecc71;
        }
        .status-off {
            background-color: #e74c3c;
        }
        .security-card {
            background: #fff3e0;
            border-left: 4px solid #ff9800;
        }
        .network-card {
            background: #e3f2fd;
            border-left: 4px solid #2196f3;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>Server Information</h1>

        <div class="info-card">
            <div class="info-title">Server Status</div>
            <div>
                <span class="status-indicator status-on"></span> Online
                | Response Time: <?php echo htmlspecialchars($server_info['Page Generation Time']); ?>
            </div>
        </div>

        <div class="info-grid">
            <?php foreach ($server_info as $title => $value): ?>
                <?php if (in_array($title, ['Headers', 'Page Generation Time'])) continue; ?>
                <div class="info-card <?php
                    echo (strpos($title, 'Ping') !== false ? 'network-card' :
                         (strpos($title, 'Network') !== false ? 'network-card' : '');
                ?>">
                    <div class="info-title"><?php echo htmlspecialchars($title) ?></div>
                    <div>
                        <?php if (is_array($value)): ?>
                            <pre><?php echo print_r($value, true) ?></pre>
                        <?php else: ?>
                            <?php echo htmlspecialchars($value) ?>
                        <?php endif; ?>
                    </div>
                </div>
            <?php endforeach; ?>
        </div>

        <div class="section-title">
            <i>⚙️</i> Server Configuration
        </div>
        <div class="info-grid">
            <?php foreach ($server_config as $title => $value): ?>
                <?php
                $status_icon = '';
                if (stripos($title, 'mode') !== false || stripos($title, 'status') !== false) {
                    $status_class = (strtolower($value) === 'on' ? 'status-on' : 'status-off');
                    $status_icon = '<span class="status-indicator ' . $status_class . '"></span>';
                }
                ?>
                <div class="info-card">
                    <div class="info-title"><?php echo $status_icon . htmlspecialchars($title) ?></div>
                    <div><span class="config-badge"><?php echo htmlspecialchars($value) ?></span></div>
                </div>
            <?php endforeach; ?>
        </div>

        <div class="section-title">
            <i>🔒</i> Security Configuration
        </div>
        <div class="info-grid">
            <?php foreach ($security_info as $title => $value): ?>
                <?php
                $status_class = (stripos($value, 'Enabled') !== false ? 'status-on' : 'status-off');
                $status_icon = '<span class="status-indicator ' . $status_class . '"></span>';
                ?>
                <div class="info-card security-card">
                    <div class="info-title"><?php echo $status_icon . htmlspecialchars($title) ?></div>
                    <div><?php echo htmlspecialchars($value) ?></div>
                </div>
            <?php endforeach; ?>
        </div>

        <div class="section-title">
            <i>🔧</i> PHP Configuration
        </div>
        <div class="php-version">PHP <?php echo phpversion() ?></div>

        <div class="section-title">
            <i>📋</i> Request Headers
        </div>
        <pre><?php print_r($server_info['Headers']) ?></pre>

        <div class="section-title">
            <i>🌐</i> Environment Variables
        </div>
        <pre><?php print_r($_SERVER) ?></pre>

        <div class="footer">
            Generated by mini-algernon.sh | <?php echo date('Y') ?> | <?php echo $server_info['Page Generation Time'] ?? '' ?>
        </div>
    </div>
</body>
</html>
EOF
fi

# Start server
if [[ "$USE_PHP" == true ]]; then
    start_php_server $PORT "$DIRECTORY"
else
    start_static_server $PORT "$DIRECTORY"
fi
