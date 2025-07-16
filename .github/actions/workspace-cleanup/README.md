# Workspace Cleanup Action

A reusable GitHub Action for cleaning up workspace and Docker environment to ensure fresh pipeline runs.

## Overview

This action performs comprehensive cleanup of:
- Workspace files and directories
- Docker containers, images, and volumes
- Temporary files
- Package manager caches (npm, Maven, pip)

## Usage

### Basic Usage

```yaml
- name: Clean workspace
  uses: ./.github/actions/workspace-cleanup
```

### With Custom Options

```yaml
- name: Clean workspace and Docker
  uses: ./.github/actions/workspace-cleanup
  with:
    cleanup_docker: 'true'
    cleanup_temp: 'true'
```

### Skip Docker Cleanup

```yaml
- name: Clean workspace only
  uses: ./.github/actions/workspace-cleanup
  with:
    cleanup_docker: 'false'
    cleanup_temp: 'true'
```

## Inputs

| Input | Description | Required | Default |
|-------|-------------|----------|---------|
| `cleanup_docker` | Whether to clean Docker environment (images, containers, volumes) | No | `true` |
| `cleanup_temp` | Whether to clean temporary files | No | `true` |

## Outputs

| Output | Description |
|--------|-------------|
| `cleanup_status` | Status of cleanup operation (`success` or `failed`) |

## What Gets Cleaned

### Workspace Files
- All files and directories in `${{ github.workspace }}`
- Hidden files and directories (starting with `.`)

### Docker Environment (when enabled)
- Running containers (stopped first)
- All containers (forcefully removed)
- All images (forcefully removed)
- Networks, volumes, and build cache
- Builder cache

### Temporary Files (when enabled)
- `/tmp/*` directory contents
- `/var/tmp/*` directory contents

### Package Manager Caches
- npm cache (if npm is available)
- Maven repository cache (if Maven is available)
- pip cache (if pip is available)

## Examples

### In Workflow Jobs

```yaml
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      # Clean at start of job
      - name: Clean workspace
        uses: ./.github/actions/workspace-cleanup
        with:
          cleanup_docker: 'true'
          cleanup_temp: 'true'
      
      - name: Checkout
        uses: actions/checkout@v4
      
      # ... other build steps ...

  cleanup:
    runs-on: ubuntu-latest
    needs: [build]
    if: always()
    steps:
      # Final cleanup
      - name: Final cleanup
        uses: ./.github/actions/workspace-cleanup
        with:
          cleanup_docker: 'true'
          cleanup_temp: 'true'
```

### Conditional Usage

```yaml
- name: Clean workspace
  uses: ./.github/actions/workspace-cleanup
  with:
    cleanup_docker: ${{ runner.os == 'Linux' }}
    cleanup_temp: 'true'
```

## Benefits

1. **Consistent State**: Ensures each pipeline run starts with a clean workspace
2. **Resource Management**: Prevents disk space issues from accumulated artifacts
3. **Faster Builds**: Removes cache conflicts and stale dependencies
4. **Security**: Removes potentially sensitive temporary files
5. **Reliability**: Eliminates interference from previous runs

## Best Practices

1. **Use at Job Start**: Clean workspace at the beginning of each job
2. **Final Cleanup**: Always run final cleanup that executes regardless of job success/failure
3. **Docker Cleanup**: Enable Docker cleanup for build jobs, disable for deploy-only jobs
4. **Conditional Logic**: Skip Docker cleanup when Docker isn't available
5. **Monitor Resources**: Check disk space after cleanup in critical workflows

## Performance Impact

- **Workspace cleanup**: Very fast (< 5 seconds)
- **Docker cleanup**: Moderate (10-30 seconds depending on artifacts)
- **Temp file cleanup**: Fast (< 10 seconds)
- **Package cache cleanup**: Fast (< 10 seconds)

Total cleanup time is typically under 1 minute and provides significant benefits for pipeline reliability.

## Error Handling

The action uses `|| true` for all cleanup commands to ensure that:
- Cleanup continues even if some operations fail
- The action never fails the pipeline due to cleanup issues
- Missing tools (Docker, npm, etc.) don't cause errors

## Security Considerations

- Uses `rm -rf` commands safely with specific paths
- Removes temporary files that might contain sensitive data
- Cleans package manager caches that might have credentials
- Docker cleanup removes containers that might have runtime secrets