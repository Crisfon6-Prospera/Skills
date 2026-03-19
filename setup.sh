#!/bin/bash
# =============================================================
#  Prosperas MCP — Setup automatico
#  Configura el MCP server directamente en tus herramientas AI
# =============================================================

set -e

BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'
BOLD='\033[1m'

echo ""
echo -e "${BLUE}${BOLD}=============================================${NC}"
echo -e "${BLUE}${BOLD}  Prosperas MCP — Setup automatico           ${NC}"
echo -e "${BLUE}${BOLD}=============================================${NC}"
echo ""

# --- Check Node.js installed (required for npx mcp-remote) ---
if ! command -v node &> /dev/null; then
    echo -e "${RED}Node.js no esta instalado.${NC}"
    echo "Es necesario para conectar con el MCP server."
    echo "Instala desde: https://nodejs.org"
    exit 1
fi

# --- Support --args mode for pre-filled values from HTML wizard ---
PRESET_COUNTRY=""
PRESET_ENV=""
PRESET_KEY=""
PRESET_TOOLS=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --country) PRESET_COUNTRY="$2"; shift 2 ;;
        --env) PRESET_ENV="$2"; shift 2 ;;
        --key) PRESET_KEY="$2"; shift 2 ;;
        --tools) PRESET_TOOLS="$2"; shift 2 ;;
        *) shift ;;
    esac
done

# --- Country ---
if [ -n "$PRESET_COUNTRY" ]; then
    COUNTRY_CHOICE="$PRESET_COUNTRY"
else
    echo -e "${BOLD}1. Pais${NC}"
    echo "   1) Colombia"
    echo "   2) Mexico"
    echo ""
    read -rp "   Selecciona (1 o 2): " COUNTRY_CHOICE
fi

case $COUNTRY_CHOICE in
    1|co)
        COUNTRY="co"
        COUNTRY_URL="col"
        COUNTRY_LABEL="Colombia"
        ;;
    2|mx)
        COUNTRY="mx"
        COUNTRY_URL="mx"
        COUNTRY_LABEL="Mexico"
        ;;
    *)
        echo -e "${RED}Opcion invalida para pais.${NC}"
        exit 1
        ;;
esac

# --- Environment ---
if [ -n "$PRESET_ENV" ]; then
    ENV_CHOICE="$PRESET_ENV"
else
    echo ""
    echo -e "${BOLD}2. Ambiente${NC}"
    echo "   1) Produccion (recomendado)"
    echo "   2) Desarrollo"
    echo ""
    read -rp "   Selecciona (1 o 2) [default: 1]: " ENV_CHOICE
    ENV_CHOICE=${ENV_CHOICE:-1}
fi

case $ENV_CHOICE in
    1|prod)
        STAGE="prod"
        STAGE_LABEL="Produccion"
        ;;
    2|dev)
        STAGE="dev"
        STAGE_LABEL="Desarrollo"
        ;;
    *)
        echo -e "${RED}Opcion invalida para ambiente.${NC}"
        exit 1
        ;;
esac

# --- API Key ---
if [ -n "$PRESET_KEY" ]; then
    API_KEY="$PRESET_KEY"
else
    echo ""
    echo -e "${BOLD}3. API Key${NC}"
    echo -e "   Pega la API Key de ${YELLOW}${COUNTRY_LABEL} - ${STAGE_LABEL}${NC}"
    echo "   (La obtuviste al generar una llave en el dashboard)"
    echo ""
    read -rp "   API Key: " API_KEY
fi

if [ -z "$API_KEY" ]; then
    echo -e "${RED}API Key es requerida.${NC}"
    exit 1
fi

# --- Build config ---
MCP_NAME="prosperas-mcp-${STAGE}-${COUNTRY}"
MCP_URL="https://api.${COUNTRY_URL}.${STAGE}.prosperas.com/mcp"

echo ""
echo -e "${YELLOW}Configuracion:${NC}"
echo "   Nombre:   $MCP_NAME"
echo "   URL:      $MCP_URL"
echo "   Pais:     $COUNTRY_LABEL"
echo "   Ambiente: $STAGE_LABEL"
echo ""

# --- Tool selection ---
if [ -n "$PRESET_TOOLS" ]; then
    TOOL_CHOICE="$PRESET_TOOLS"
else
    echo -e "${BOLD}4. Que herramientas quieres configurar?${NC}"
    echo "   1) Claude Desktop (recomendado)"
    echo "   2) Claude Code"
    echo "   3) Cursor"
    echo "   4) Todas"
    echo ""
    read -rp "   Selecciona (1, 2, 3 o 4) [default: 4]: " TOOL_CHOICE
    TOOL_CHOICE=${TOOL_CHOICE:-4}
fi

INSTALL_DESKTOP=false
INSTALL_CLAUDE_CODE=false
INSTALL_CURSOR=false

# Handle comma-separated tools (e.g., "desktop,claude") from wizard
IFS=',' read -ra TOOLS_ARRAY <<< "$TOOL_CHOICE"
for tool in "${TOOLS_ARRAY[@]}"; do
    case $tool in
        1|desktop)    INSTALL_DESKTOP=true ;;
        2|claude)     INSTALL_CLAUDE_CODE=true ;;
        3|cursor)     INSTALL_CURSOR=true ;;
        4|all)        INSTALL_DESKTOP=true; INSTALL_CLAUDE_CODE=true; INSTALL_CURSOR=true ;;
        *)
            echo -e "${RED}Opcion invalida: $tool${NC}"
            exit 1
            ;;
    esac
done

# =============================================================
#  CONFIGURE CLAUDE DESKTOP
# =============================================================
if [ "$INSTALL_DESKTOP" = true ]; then
    echo -e "${BOLD}Configurando Claude Desktop...${NC}"

    CLAUDE_CONFIG_DIR="$HOME/Library/Application Support/Claude"
    CLAUDE_CONFIG="$CLAUDE_CONFIG_DIR/claude_desktop_config.json"

    mkdir -p "$CLAUDE_CONFIG_DIR"

    node -e "
const fs = require('fs');
const configPath = process.argv[1];
const mcpName = process.argv[2];
const mcpUrl = process.argv[3];
const apiKey = process.argv[4];

let config = {};
try { config = JSON.parse(fs.readFileSync(configPath, 'utf8')); } catch (e) {}

if (!config.mcpServers) config.mcpServers = {};

config.mcpServers[mcpName] = {
    command: 'npx',
    args: ['mcp-remote', mcpUrl, '--header', 'X-MCP-API-Key:' + apiKey]
};

fs.writeFileSync(configPath, JSON.stringify(config, null, 2));
console.log('OK');
" "$CLAUDE_CONFIG" "$MCP_NAME" "$MCP_URL" "$API_KEY"

    echo -e "${GREEN}  Claude Desktop configurado.${NC}"
    echo -e "  Config: ${CLAUDE_CONFIG}"
    echo -e "  ${YELLOW}Reinicia Claude Desktop para activar los cambios.${NC}"
    echo ""
fi

# =============================================================
#  CONFIGURE CLAUDE CODE
# =============================================================
if [ "$INSTALL_CLAUDE_CODE" = true ]; then
    echo -e "${BOLD}Configurando Claude Code...${NC}"

    if command -v claude &> /dev/null; then
        claude mcp add --transport http "$MCP_NAME" "$MCP_URL" --header "X-MCP-API-Key: ${API_KEY}"
        echo -e "${GREEN}  Claude Code configurado.${NC}"
    else
        echo -e "${YELLOW}  Claude Code no esta instalado. Omitiendo.${NC}"
        echo "  Instala primero: https://docs.anthropic.com/en/docs/claude-code"
    fi
    echo ""
fi

# =============================================================
#  CONFIGURE CURSOR
# =============================================================
if [ "$INSTALL_CURSOR" = true ]; then
    echo -e "${BOLD}Configurando Cursor...${NC}"

    CURSOR_CONFIG_DIR="$HOME/.cursor"
    CURSOR_CONFIG="$CURSOR_CONFIG_DIR/mcp.json"

    mkdir -p "$CURSOR_CONFIG_DIR"

    node -e "
const fs = require('fs');
const configPath = process.argv[1];
const mcpName = process.argv[2];
const mcpUrl = process.argv[3];
const apiKey = process.argv[4];

let config = {};
try { config = JSON.parse(fs.readFileSync(configPath, 'utf8')); } catch (e) {}

if (!config.mcpServers) config.mcpServers = {};

config.mcpServers[mcpName] = {
    command: 'npx',
    args: ['mcp-remote', mcpUrl, '--header', 'X-MCP-API-Key:' + apiKey]
};

fs.writeFileSync(configPath, JSON.stringify(config, null, 2));
console.log('OK');
" "$CURSOR_CONFIG" "$MCP_NAME" "$MCP_URL" "$API_KEY"

    echo -e "${GREEN}  Cursor configurado.${NC}"
    echo -e "  Config: ${CURSOR_CONFIG}"
    echo ""
fi

# =============================================================
#  INSTALL SKILL (for Claude Code users)
# =============================================================
if [ "$INSTALL_CLAUDE_CODE" = true ]; then
    echo -e "${BOLD}Instalando skill de consultas...${NC}"

    SKILL_DIR="$HOME/.claude/skills"
    mkdir -p "$SKILL_DIR"

    cat > "$SKILL_DIR/prosperas-mcp.md" << 'SKILL_EOF'
---
name: prosperas-mcp
description: Use when the user wants to query, explore, or get data from the Prosperas database. Triggers on keywords like "consulta", "query", "datos", "base de datos", "tabla", "registros", "leads", "conversiones", "revenue", "MCP", "prosperas-mcp".
---

# Prosperas MCP - Database Query Skill

## When to use

Use this skill whenever the user wants to query, explore, or get data from the Prosperas database using the MCP server.

## Country Selection (required)

Before executing any query, ask the user:

**"Para cual pais necesitas esta consulta? Colombia (CO) o Mexico (MX)?"**

Wait for their answer before proceeding.

## Environment Selection

- **Always default to production** — do NOT ask the user about the environment.
- Only use `dev` if the user **explicitly** says "dev", "desarrollo", "ambiente de desarrollo", or "staging".

## MCP Server Name Resolution

Based on country and environment, use the corresponding MCP server:

| Country   | Environment | MCP Server Name         |
|-----------|-------------|-------------------------|
| Colombia  | Production  | `prosperas-mcp-prod-co` |
| Colombia  | Dev         | `prosperas-mcp-dev-co`  |
| Mexico    | Production  | `prosperas-mcp-prod-mx` |
| Mexico    | Dev         | `prosperas-mcp-dev-mx`  |

Use the tools prefixed with `mcp__<server-name>__` to call the MCP tools. For example, for Colombia production: `mcp__prosperas-mcp-prod-co__db_query`.

## Available MCP Tools

Once you know the server name, these tools are available:

- **db_query(sql)** — Execute SELECT queries (max 500 rows, 30s timeout)
- **db_list_tables(schema)** — List all tables/views with row counts
- **db_describe_table(table_name)** — Show columns, types, constraints, and 5 sample rows
- **db_list_views()** — List QuickSight materialized views with descriptions
- **db_get_schema_docs(table_name)** — Get markdown documentation from the knowledge base
- **db_ping()** — Health check

## Important Rules

1. **Only SELECT queries** — INSERT, UPDATE, DELETE, DROP are blocked by the server
2. If unfamiliar with the schema, start with `db_get_schema_docs()` or `db_list_tables()` before writing queries
3. Use `db_describe_table(table_name)` to understand column types and see sample data
4. Queries have a **30 second timeout** and return **max 500 rows**
5. Always present query results in a clear, formatted way (tables when appropriate)
SKILL_EOF

    echo -e "${GREEN}  Skill instalada en $SKILL_DIR/prosperas-mcp.md${NC}"
    echo ""
fi

# =============================================================
#  DONE
# =============================================================
echo -e "${GREEN}${BOLD}=============================================${NC}"
echo -e "${GREEN}${BOLD}  Setup completado!${NC}"
echo -e "${GREEN}${BOLD}=============================================${NC}"
echo ""
echo "  Herramientas configuradas:"
[ "$INSTALL_DESKTOP" = true ] && echo -e "    ${GREEN}✓${NC} Claude Desktop ${YELLOW}(reinicia la app)${NC}"
[ "$INSTALL_CLAUDE_CODE" = true ] && echo -e "    ${GREEN}✓${NC} Claude Code + Skill"
[ "$INSTALL_CURSOR" = true ] && echo -e "    ${GREEN}✓${NC} Cursor"
echo ""
echo "  Ahora puedes preguntar:"
echo ""
echo -e "  ${BLUE}\"Muestrame las tablas de la base de datos\"${NC}"
echo -e "  ${BLUE}\"Cuantos leads hay este mes?\"${NC}"
echo -e "  ${BLUE}\"Dame el revenue por campana\"${NC}"
echo ""
