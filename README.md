# Prosperas MCP Skills

Connect your AI tools to the Prosperas database for natural language queries.

## Prerequisites

- An API key generated from the Prosperas dashboard (MCP API Keys section)
- One of: Claude Desktop, Claude Code, or Cursor

## Setup

### Option A: Claude Desktop (recommended for non-technical users)

1. Generate an API key from the dashboard
2. In the "Key Generated" modal, click **"Add to Claude Desktop"**
3. Open Claude Desktop → **Settings** → **Developer** → **Edit Config**
4. Paste the config inside the `"mcpServers"` key
5. Save and restart Claude Desktop

### Option B: Claude Code (automated setup)

Run the interactive setup script:

```bash
bash setup.sh
```

The script will:
1. Ask for your API key
2. Ask for your country (Colombia / Mexico)
3. Ask for the environment (defaults to Production)
4. Register the MCP server in Claude Code
5. Install the database query skill

### Option C: Cursor

1. Generate an API key from the dashboard
2. In the "Key Generated" modal, click **"Add to Cursor"**
3. Cursor opens automatically with the MCP configured

## What you can do

Once connected, ask questions in natural language:

- "Show me all database tables"
- "How many leads do we have this month?"
- "Show revenue by campaign"
- "Describe the sessions table"
- "What are the active leads in Colombia?"

## MCP Servers

Four servers are available, one per country/environment combination:

| Server | URL |
|--------|-----|
| `prosperas-mcp-prod-co` | `https://api.col.prod.prosperas.com/mcp` |
| `prosperas-mcp-prod-mx` | `https://api.mex.prod.prosperas.com/mcp` |
| `prosperas-mcp-dev-co` | `https://api-col.dev.prosperas.com/mcp` |
| `prosperas-mcp-dev-mx` | `https://api-mex.dev.prosperas.com/mcp` |

## Constraints

- **Read-only** — only SELECT queries are allowed
- **500 row limit** per query
- **30 second timeout** per query
- Each API key is scoped to your organization's permissions
