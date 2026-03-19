#!/usr/bin/env node
// =============================================================
//  Prosperas MCP — Cross-platform setup
//  Works on macOS, Windows, and Linux
// =============================================================

const fs = require('fs');
const path = require('path');
const os = require('os');
const { execFileSync } = require('child_process');
const readline = require('readline');

// --- Colors (ANSI, works in modern terminals including Windows Terminal) ---
const c = {
    blue: '\x1b[34m',
    green: '\x1b[32m',
    yellow: '\x1b[33m',
    red: '\x1b[31m',
    bold: '\x1b[1m',
    reset: '\x1b[0m',
};

function log(msg) { process.stdout.write(msg + '\n'); }
function info(msg) { log(`${c.bold}${msg}${c.reset}`); }
function success(msg) { log(`${c.green}  ${msg}${c.reset}`); }
function warn(msg) { log(`${c.yellow}  ${msg}${c.reset}`); }
function error(msg) { log(`${c.red}${msg}${c.reset}`); }

// --- Config path resolution per OS ---
function getClaudeDesktopConfigPath() {
    if (process.platform === 'win32') {
        return path.join(process.env.APPDATA, 'Claude', 'claude_desktop_config.json');
    }
    if (process.platform === 'darwin') {
        return path.join(os.homedir(), 'Library', 'Application Support', 'Claude', 'claude_desktop_config.json');
    }
    // Linux
    return path.join(os.homedir(), '.config', 'Claude', 'claude_desktop_config.json');
}

function getCursorConfigPath() {
    return path.join(os.homedir(), '.cursor', 'mcp.json');
}

function getSkillDir() {
    return path.join(os.homedir(), '.claude', 'skills');
}

// --- JSON config merge (safe read, merge, write) ---
function mergeJsonConfig(configPath, mcpName, mcpUrl, apiKey) {
    const dir = path.dirname(configPath);
    if (!fs.existsSync(dir)) {
        fs.mkdirSync(dir, { recursive: true });
    }

    let config = {};
    try {
        config = JSON.parse(fs.readFileSync(configPath, 'utf8'));
    } catch (e) {
        // File doesn't exist or invalid JSON
    }

    if (!config.mcpServers) config.mcpServers = {};

    config.mcpServers[mcpName] = {
        command: 'npx',
        args: ['mcp-remote', mcpUrl, '--header', 'X-MCP-API-Key:' + apiKey],
    };

    fs.writeFileSync(configPath, JSON.stringify(config, null, 2));
}

// --- Skill file content ---
const SKILL_CONTENT = `---
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
- Only use \`dev\` if the user **explicitly** says "dev", "desarrollo", "ambiente de desarrollo", or "staging".

## MCP Server Name Resolution

Based on country and environment, use the corresponding MCP server:

| Country   | Environment | MCP Server Name         |
|-----------|-------------|-------------------------|
| Colombia  | Production  | \`prosperas-mcp-prod-co\` |
| Colombia  | Dev         | \`prosperas-mcp-dev-co\`  |
| Mexico    | Production  | \`prosperas-mcp-prod-mx\` |
| Mexico    | Dev         | \`prosperas-mcp-dev-mx\`  |

Use the tools prefixed with \`mcp__<server-name>__\` to call the MCP tools. For example, for Colombia production: \`mcp__prosperas-mcp-prod-co__db_query\`.

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
2. If unfamiliar with the schema, start with \`db_get_schema_docs()\` or \`db_list_tables()\` before writing queries
3. Use \`db_describe_table(table_name)\` to understand column types and see sample data
4. Queries have a **30 second timeout** and return **max 500 rows**
5. Always present query results in a clear, formatted way (tables when appropriate)
`;

// --- Interactive prompt helper ---
function ask(rl, question) {
    return new Promise((resolve) => rl.question(question, resolve));
}

// --- Parse CLI args ---
function parseArgs() {
    const args = {};
    const argv = process.argv.slice(2);
    for (let i = 0; i < argv.length; i++) {
        if (argv[i] === '--country' && argv[i + 1]) { args.country = argv[++i]; }
        else if (argv[i] === '--env' && argv[i + 1]) { args.env = argv[++i]; }
        else if (argv[i] === '--key' && argv[i + 1]) { args.key = argv[++i]; }
        else if (argv[i] === '--tools' && argv[i + 1]) { args.tools = argv[++i]; }
    }
    return args;
}

// --- Country map ---
const COUNTRIES = {
    co: { label: 'Colombia' },
    mx: { label: 'Mexico' },
};

// --- URL map (hardcoded, patterns differ between prod and dev) ---
const MCP_URLS = {
    'prod-co': 'https://api.col.prod.prosperas.com/mcp',
    'prod-mx': 'https://api.mex.prod.prosperas.com/mcp',
    'dev-co': 'https://api-col.dev.prosperas.com/mcp',
    'dev-mx': 'https://api-mex.dev.prosperas.com/mcp',
};

// --- Main ---
async function main() {
    const preset = parseArgs();

    log('');
    log(`${c.blue}${c.bold}=============================================${c.reset}`);
    log(`${c.blue}${c.bold}  Prosperas MCP — Setup                      ${c.reset}`);
    log(`${c.blue}${c.bold}=============================================${c.reset}`);
    log('');

    const rl = readline.createInterface({ input: process.stdin, output: process.stdout });

    // --- Country ---
    let country;
    if (preset.country && COUNTRIES[preset.country]) {
        country = preset.country;
    } else {
        info('1. Pais');
        log('   1) Colombia');
        log('   2) Mexico');
        log('');
        const choice = await ask(rl, '   Selecciona (1 o 2): ');
        country = choice === '1' ? 'co' : choice === '2' ? 'mx' : null;
        if (!country) { error('Opcion invalida.'); process.exit(1); }
    }

    // --- Environment ---
    let stage;
    if (preset.env === 'prod' || preset.env === 'dev') {
        stage = preset.env;
    } else {
        log('');
        info('2. Ambiente');
        log('   1) Produccion (recomendado)');
        log('   2) Desarrollo');
        log('');
        const choice = await ask(rl, '   Selecciona (1 o 2) [default: 1]: ');
        stage = (choice === '2') ? 'dev' : 'prod';
    }

    // --- API Key ---
    let apiKey;
    if (preset.key) {
        apiKey = preset.key;
    } else {
        const countryInfo = COUNTRIES[country];
        const stageLabel = stage === 'prod' ? 'Produccion' : 'Desarrollo';
        log('');
        info('3. API Key');
        log(`   ${c.yellow}Pega la API Key de ${countryInfo.label} - ${stageLabel}${c.reset}`);
        log('   (La obtuviste al generar una llave en el dashboard)');
        log('');
        apiKey = await ask(rl, '   API Key: ');
    }

    if (!apiKey || apiKey.trim().length < 10) {
        error('API Key es requerida.'); process.exit(1);
    }
    apiKey = apiKey.trim();

    // --- Build config ---
    const mcpName = `prosperas-mcp-${stage}-${country}`;
    const mcpUrl = MCP_URLS[`${stage}-${country}`];
    const stageLabel = stage === 'prod' ? 'Produccion' : 'Desarrollo';

    log('');
    log(`${c.yellow}Configuracion:${c.reset}`);
    log(`   Nombre:   ${mcpName}`);
    log(`   URL:      ${mcpUrl}`);
    log(`   Pais:     ${COUNTRIES[country].label}`);
    log(`   Ambiente: ${stageLabel}`);
    log('');

    // --- Tool selection ---
    let toolsStr;
    if (preset.tools) {
        toolsStr = preset.tools;
    } else {
        info('4. Que herramientas quieres configurar?');
        log('   1) Claude Desktop (recomendado)');
        log('   2) Claude Code');
        log('   3) Cursor');
        log('   4) Todas');
        log('');
        toolsStr = await ask(rl, '   Selecciona (1, 2, 3 o 4) [default: 4]: ');
        toolsStr = toolsStr.trim() || '4';
    }

    rl.close();

    const installDesktop = toolsStr.includes('desktop') || toolsStr.includes('1') || toolsStr.includes('all') || toolsStr.includes('4');
    const installClaude = toolsStr.includes('claude') || toolsStr.includes('2') || toolsStr.includes('all') || toolsStr.includes('4');
    const installCursor = toolsStr.includes('cursor') || toolsStr.includes('3') || toolsStr.includes('all') || toolsStr.includes('4');

    // =============================================================
    //  CONFIGURE CLAUDE DESKTOP
    // =============================================================
    if (installDesktop) {
        info('Configurando Claude Desktop...');
        const configPath = getClaudeDesktopConfigPath();
        mergeJsonConfig(configPath, mcpName, mcpUrl, apiKey);
        success('Claude Desktop configurado.');
        log(`  Config: ${configPath}`);
        warn('Reinicia Claude Desktop para activar los cambios.');
        log('');
    }

    // =============================================================
    //  CONFIGURE CLAUDE CODE
    // =============================================================
    if (installClaude) {
        info('Configurando Claude Code...');
        try {
            execFileSync('claude', [
                'mcp', 'add',
                '--transport', 'http',
                mcpName,
                mcpUrl,
                '--header', `X-MCP-API-Key: ${apiKey}`,
            ], { stdio: 'pipe' });
            success('Claude Code configurado.');
        } catch (e) {
            warn('Claude Code no esta instalado. Omitiendo.');
            log('  Instala primero: https://docs.anthropic.com/en/docs/claude-code');
        }
        log('');
    }

    // =============================================================
    //  CONFIGURE CURSOR
    // =============================================================
    if (installCursor) {
        info('Configurando Cursor...');
        const configPath = getCursorConfigPath();
        mergeJsonConfig(configPath, mcpName, mcpUrl, apiKey);
        success('Cursor configurado.');
        log(`  Config: ${configPath}`);
        log('');
    }

    // =============================================================
    //  INSTALL SKILL (for Claude Code users)
    // =============================================================
    if (installClaude) {
        info('Instalando skill de consultas...');
        const skillDir = getSkillDir();
        if (!fs.existsSync(skillDir)) {
            fs.mkdirSync(skillDir, { recursive: true });
        }
        fs.writeFileSync(path.join(skillDir, 'prosperas-mcp.md'), SKILL_CONTENT);
        success(`Skill instalada en ${path.join(skillDir, 'prosperas-mcp.md')}`);
        log('');
    }

    // =============================================================
    //  DONE
    // =============================================================
    log(`${c.green}${c.bold}=============================================${c.reset}`);
    log(`${c.green}${c.bold}  Setup completado!${c.reset}`);
    log(`${c.green}${c.bold}=============================================${c.reset}`);
    log('');
    log('  Herramientas configuradas:');
    if (installDesktop) log(`    ${c.green}\u2713${c.reset} Claude Desktop ${c.yellow}(reinicia la app)${c.reset}`);
    if (installClaude) log(`    ${c.green}\u2713${c.reset} Claude Code + Skill`);
    if (installCursor) log(`    ${c.green}\u2713${c.reset} Cursor`);
    log('');
    log('  Ahora puedes preguntar:');
    log('');
    log(`  ${c.blue}"Muestrame las tablas de la base de datos"${c.reset}`);
    log(`  ${c.blue}"Cuantos leads hay este mes?"${c.reset}`);
    log(`  ${c.blue}"Dame el revenue por campana"${c.reset}`);
    log('');
}

main().catch((err) => {
    error('Error: ' + err.message);
    process.exit(1);
});
