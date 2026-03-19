#!/bin/bash
# =============================================================
#  Prosperas MCP — Setup para Claude Code
#  Instala el MCP server y la skill de consultas a base de datos
# =============================================================

set -e

BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'
BOLD='\033[1m'

echo ""
echo -e "${BLUE}${BOLD}=========================================${NC}"
echo -e "${BLUE}${BOLD}  Prosperas MCP — Setup para Claude Code ${NC}"
echo -e "${BLUE}${BOLD}=========================================${NC}"
echo ""

# --- Check Claude Code installed ---
if ! command -v claude &> /dev/null; then
    echo -e "${RED}Claude Code no esta instalado.${NC}"
    echo "Instala primero: https://docs.anthropic.com/en/docs/claude-code"
    exit 1
fi

# --- API Key ---
echo -e "${BOLD}1. API Key${NC}"
echo "   (La obtuviste al generar una llave en el dashboard)"
echo ""
read -rp "   Pega tu API Key: " API_KEY

if [ -z "$API_KEY" ]; then
    echo -e "${RED}API Key es requerida.${NC}"
    exit 1
fi

# --- Country ---
echo ""
echo -e "${BOLD}2. Pais${NC}"
echo "   1) Colombia"
echo "   2) Mexico"
echo ""
read -rp "   Selecciona (1 o 2): " COUNTRY_CHOICE

case $COUNTRY_CHOICE in
    1)
        COUNTRY="co"
        COUNTRY_URL="col"
        ;;
    2)
        COUNTRY="mx"
        COUNTRY_URL="mx"
        ;;
    *)
        echo -e "${RED}Opcion invalida. Selecciona 1 o 2.${NC}"
        exit 1
        ;;
esac

# --- Environment ---
echo ""
echo -e "${BOLD}3. Ambiente${NC}"
echo "   1) Produccion (recomendado)"
echo "   2) Desarrollo"
echo ""
read -rp "   Selecciona (1 o 2) [default: 1]: " ENV_CHOICE
ENV_CHOICE=${ENV_CHOICE:-1}

case $ENV_CHOICE in
    1)
        STAGE="prod"
        ;;
    2)
        STAGE="dev"
        ;;
    *)
        echo -e "${RED}Opcion invalida.${NC}"
        exit 1
        ;;
esac

# --- Build config ---
MCP_NAME="prosperas-mcp-${STAGE}-${COUNTRY}"
MCP_URL="https://api.${COUNTRY_URL}.${STAGE}.prosperas.com/mcp"

echo ""
echo -e "${YELLOW}Configuracion:${NC}"
echo "   Nombre:   $MCP_NAME"
echo "   URL:      $MCP_URL"
echo ""

# --- Step 1: Add MCP server to Claude Code ---
echo -e "${BOLD}Agregando MCP server a Claude Code...${NC}"
claude mcp add --transport http "$MCP_NAME" "$MCP_URL" --header "X-MCP-API-Key: ${API_KEY}"
echo -e "${GREEN}MCP server agregado.${NC}"

# --- Step 2: Install skill ---
echo ""
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

echo -e "${GREEN}Skill instalada en $SKILL_DIR/prosperas-mcp.md${NC}"

# --- Done ---
echo ""
echo -e "${GREEN}${BOLD}=========================================${NC}"
echo -e "${GREEN}${BOLD}  Setup completado!${NC}"
echo -e "${GREEN}${BOLD}=========================================${NC}"
echo ""
echo "  Ahora puedes abrir Claude Code y preguntar:"
echo ""
echo -e "  ${BLUE}\"Muestrame las tablas de la base de datos\"${NC}"
echo -e "  ${BLUE}\"Cuantos leads hay este mes?\"${NC}"
echo -e "  ${BLUE}\"Dame el revenue por campana\"${NC}"
echo ""
