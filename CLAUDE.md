# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Purpose

MCP (Model Context Protocol) skills and setup tooling for Prosperas database integration. Enables AI tools (Claude Desktop, Claude Code, Cursor) to query the Prosperas B2B2C marketplace database through natural language.

## Architecture

- `prosperas-mcp.md` — Skill definition with YAML frontmatter. Instructs Claude on country selection (CO/MX), environment defaulting (production unless explicitly dev), and MCP server name resolution (`prosperas-mcp-{stage}-{country}`).
- `setup.sh` — Interactive bash installer. Registers the MCP server via `claude mcp add` and copies the skill to `~/.claude/skills/`.
- `README.md` — Spanish-language setup guide for end users (C-levels, non-technical).

## MCP Server Naming Convention

Four servers exist, differing only by URL and API key:

| Server Name | URL Pattern |
|---|---|
| `prosperas-mcp-prod-co` | `https://api.col.prod.prosperas.com/mcp` |
| `prosperas-mcp-prod-mx` | `https://api.mx.prod.prosperas.com/mcp` |
| `prosperas-mcp-dev-co` | `https://api.col.dev.prosperas.com/mcp` |
| `prosperas-mcp-dev-mx` | `https://api.mx.dev.prosperas.com/mcp` |

Country URL subdomain: `col` for Colombia, `mx` for Mexico.

## Related Repositories

- **MCP Server** (backend): `../marketplace-fast-api` — FastAPI app with `mcp_servers/prosperas_db/` (tools: db_query, db_list_tables, db_describe_table, db_list_views, db_get_schema_docs, db_ping). Read-only, 500-row limit, 30s timeout.
- **Frontend** (dashboard): `../60segundos-dashboard` — Angular app. The modal that delivers MCP config to users lives in `src/app/modules/private/mcp-api-keys/mcp-api-key-created-dialog/`. MCP name is derived dynamically from `environment.countryCode` and `environment.production`.

## Language

All user-facing content (README, setup script prompts, skill instructions) is in Spanish. The skill definition itself uses English for Claude's internal processing.
