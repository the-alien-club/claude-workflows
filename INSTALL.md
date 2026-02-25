# Installation Guide
## For Team Members
### Quick Install
Open a new terminal (outside of Claude Code) and run:

```bash
/plugin install https://github.com/the-alien-club/claude-workflows.git
```

That's it! All commands will be available with the `alien-intelligence-workflows:` prefix.

### Verify Installation
```bash
/help
# Look for alien-intelligence-workflows commands in the list
```

### Test a Command
```bash
/alien-intelligence-workflows:commit
```

## Testing Locally (Developers)
If you're developing or testing changes to the plugin:

1. **Clone the repo** (if not already):
   ```bash
   git clone git@github.com:the-alien-club/claude-workflows.git
   cd claude-workflows
   ```
2. **Test locally** with `--plugin-dir`:
   ```bash
   # From a NEW terminal (not inside Claude Code)
   cd /path/to/your/project
   claude --plugin-dir /path/to/claude-workflows
   ```
3. **Make changes** to skills or agents
4. **Test changes**:
   ```bash
   # Restart Claude Code with the plugin
   claude --plugin-dir /path/to/claude-workflows

   # Try your modified command
   /alien-intelligence-workflows:your-command
   ```
5. **Submit changes**:
   ```bash
   git add .
   git commit -m "feat: describe your change"
   git push origin main
   ```
6. **Team updates**:
   ```bash
   /plugin update alien-intelligence-workflows
   ```

## Command Namespacing
After installation, all commands use the plugin namespace:
| Old (Project)     | New (Plugin)                                   |
|-------------------|------------------------------------------------|
| `/commit`         | `/alien-intelligence-workflows:commit`         |
| `/merge_request`  | `/alien-intelligence-workflows:merge_request`  |
| `/create_plan_nt` | `/alien-intelligence-workflows:create_plan_nt` |

**Tip**: Use tab completion! Type `/alien` and press TAB to see all commands.

## Troubleshooting
### Plugin not found
```bash
# Reinstall
/plugin uninstall alien-intelligence-workflows
/plugin install https://github.com/the-alien-club/claude-workflows.git
```

### Commands not showing
```bash
# Check installed plugins
/plugin list

# Restart Claude Code
exit
claude
```

### Git authentication issues
```bash
# Verify SSH access
ssh -T git@github.com

# Or use HTTPS
/plugin install https://github.com/the-alien-club/claude-workflows.git
```

## Updating
When we release new versions:

```bash
/plugin update alien-intelligence-workflows
```

Or reinstall:

```bash
/plugin uninstall alien-intelligence-workflows
/plugin install https://github.com/the-alien-club/claude-workflows.git
```

## Support
- **GitHub Issues**: https://github.com/the-alien-club/claude-workflows/issues
- **Team Slack**: #engineering or #ai-development
- **Documentation**: See [README.md](README.md)

**Happy coding!**