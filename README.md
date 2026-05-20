# Mergado Skills for Claude Code

A collection of Claude Code skills for working with [Mergado](https://www.mergado.com/) — a product feed management platform for e-commerce.

## Skills

| Skill | Description |
|-------|-------------|
| **mergado-asistent** | User-facing assistant that translates e-shop owner problems into Mergado actions (Google Shopping errors, missing data, feed optimization) |
| **mergado-audit** | Workflow for reading Feed Audit results, interpreting issues, and mapping errors to fix rules |
| **mergado-data-import** | Reference for creating `data_import` rules — importing CSV/XML data files into Mergado projects |
| **mergado-element-path** | Expert guide for building and debugging Mergado Element Path expressions used in rules and queries |
| **mergado-elements** | Reference for Mergado elements — the individual product feed fields |
| **mergado-google-shopping** | Reference for Google Shopping feed optimization — required elements, valid values, GMC errors |
| **mergado-mcp** | Knowledge base and workflow guide for working with Mergado via MCP (Model Context Protocol) |
| **mergado-mql** | Mergado MQL query language reference and selection patterns |
| **mergado-products-export** | Patterns for reading product element values from Mergado without overloading context |
| **mergado-rules** | Complete reference for creating and managing rules via API — all rule types, formats, priorities |

## MCP Setup

`mergado-install-prompt-for-client.md` — step-by-step instructions for connecting Mergado to Claude Code via MCP. Start here if you haven't set it up yet.

## Installation

Copy the skill folders into your Claude Code skills directory:

```bash
cp -r mergado-* ~/.claude/skills/
```

Or clone directly into your skills directory:

```bash
git clone https://github.com/radim-zhor/mergado-skills.git ~/.claude/skills/mergado-skills-repo
# then symlink or copy individual skills as needed
```
