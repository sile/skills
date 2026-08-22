My coding agent skills
======================

Install
-------

```bash
gh skill install sile/skills --all --scope user --agent <agent>
```

Install one skill by name instead of `--all`:

```bash
gh skill install sile/skills sile-rust --scope user --agent <agent>
```

`<agent>` is a `gh skill install --agent` value (for example `claude-code`,
`cursor`, `codex`, or `opencode`). The default agent is `github-copilot`.

See [gh skill install](https://cli.github.com/manual/gh_skill_install).

References
----------

- [Agent Skills](https://agentskills.io)
- [Specification](https://agentskills.io/specification)
- [gh skill](https://cli.github.com/manual/gh_skill)
