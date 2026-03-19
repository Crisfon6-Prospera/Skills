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
