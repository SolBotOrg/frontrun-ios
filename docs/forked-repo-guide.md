# Working with a Forked Repository

This guide covers best practices for maintaining and developing on a forked codebase.

## Initial Setup

Add the original repository as an upstream remote:

```bash
git remote add upstream https://github.com/TelegramMessenger/Telegram-iOS.git
git remote -v  # Verify remotes
```

## Keeping Your Fork in Sync

Regularly pull changes from upstream to avoid large merge conflicts:

```bash
git fetch upstream
git checkout master
git merge upstream/master
git push origin master
```

For a cleaner history, use rebase instead:

```bash
git fetch upstream
git rebase upstream/master
git push origin master --force-with-lease
```

## Branch Strategy

- **master**: Keep in sync with upstream; contains your stable customizations
- **feature/\***: New features specific to your fork
- **upstream-sync**: Optional branch for testing upstream merges before applying to master

## Making Changes

1. Create a feature branch from master
2. Make your changes
3. Test thoroughly before merging
4. Use descriptive commit messages

```bash
git checkout -b feature/my-change
# ... make changes ...
git commit -m "Add feature X for Y reason"
git push origin feature/my-change
```

## Handling Upstream Updates

When upstream has updates you want:

1. Fetch and review upstream changes
2. Merge or rebase onto your branch
3. Resolve conflicts carefully—your customizations take priority
4. Test the merged result

```bash
git fetch upstream
git log master..upstream/master --oneline  # Review incoming changes
git merge upstream/master
```

## Conflict Resolution Tips

- Keep your custom changes isolated in separate files when possible
- Document why you diverged from upstream in commit messages
- Consider maintaining a `FORK_CHANGES.md` documenting your modifications
- Use `git diff upstream/master..master` to review your fork's divergence

## When to Sync

- Before starting new feature work
- When upstream releases security fixes
- Periodically (weekly/monthly) to minimize drift
